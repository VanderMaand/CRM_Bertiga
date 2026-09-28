-- ============================================================
-- Triggers & Functions - Komputasi Terintegrasi
-- Jalankan setelah 02_rls_policies.sql
-- ============================================================

-- ========== 1. Kurangi stok otomatis setelah transaksi penjualan ==========
create or replace function fn_update_stok_after_penjualan()
returns trigger as $$
begin
  update bahan_baku bb
  set stok_saat_ini = bb.stok_saat_ini - (rp.jumlah_dibutuhkan * new.jumlah),
      updated_at = now()
  from resep_produk rp
  where rp.produk_id = new.produk_id
    and rp.bahan_baku_id = bb.id;
  return new;
end;
$$ language plpgsql security definer;

create trigger trg_update_stok_after_penjualan
after insert on detail_penjualan
for each row execute function fn_update_stok_after_penjualan();

-- ========== 2. Tambah stok otomatis saat pembelian disetujui ==========
create or replace function fn_update_stok_after_pembelian()
returns trigger as $$
begin
  if new.status = 'disetujui' and old.status <> 'disetujui' then
    update bahan_baku bb
    set stok_saat_ini = bb.stok_saat_ini + dp.jumlah_beli,
        updated_at = now()
    from detail_pembelian dp
    where dp.pembelian_id = new.id
      and dp.bahan_baku_id = bb.id;
  end if;
  return new;
end;
$$ language plpgsql security definer;

create trigger trg_update_stok_after_pembelian
after update on pembelian_bahan_baku
for each row execute function fn_update_stok_after_pembelian();

-- ========== 3. Notifikasi otomatis saat stok di bawah minimum ==========
create or replace function fn_notif_stok_minimum()
returns trigger as $$
begin
  if new.stok_saat_ini < new.stok_minimum
     and (old.stok_saat_ini is null or old.stok_saat_ini >= old.stok_minimum) then
    insert into notifications (user_id, title, body)
    select id,
           'Stok Menipis',
           'Stok ' || new.nama_bahan || ' tersisa ' || new.stok_saat_ini || ' ' || new.satuan || ', di bawah batas minimum.'
    from profiles
    where role = 'manajer';
  end if;
  return new;
end;
$$ language plpgsql security definer;

create trigger trg_notif_stok_minimum
after update on bahan_baku
for each row execute function fn_notif_stok_minimum();

-- ========== 4. Notifikasi otomatis ke owner saat ada pengajuan pembelian baru ==========
create or replace function fn_notif_pengajuan_pembelian()
returns trigger as $$
begin
  insert into notifications (user_id, title, body)
  select id,
         'Pengajuan Pembelian Baru',
         'Ada pengajuan pembelian bahan baku baru menunggu persetujuan Anda.'
  from profiles
  where role = 'owner';
  return new;
end;
$$ language plpgsql security definer;

create trigger trg_notif_pengajuan_pembelian
after insert on pembelian_bahan_baku
for each row execute function fn_notif_pengajuan_pembelian();

-- ========== 5. Notifikasi ke manajer saat owner approve/reject ==========
create or replace function fn_notif_hasil_persetujuan()
returns trigger as $$
begin
  if new.status <> old.status and new.status in ('disetujui','ditolak') then
    insert into notifications (user_id, title, body)
    values (
      new.manajer_id,
      'Hasil Persetujuan Pembelian',
      'Pengajuan pembelian Anda telah ' || new.status ||
      case when new.status = 'ditolak' then '. Alasan: ' || coalesce(new.alasan_penolakan, '-') else '.' end
    );
  end if;
  return new;
end;
$$ language plpgsql security definer;

create trigger trg_notif_hasil_persetujuan
after update on pembelian_bahan_baku
for each row execute function fn_notif_hasil_persetujuan();

-- ========== 6. Update total pembelian otomatis dari detail_pembelian ==========
create or replace function fn_update_total_pembelian()
returns trigger as $$
begin
  update pembelian_bahan_baku
  set total_pembelian = (
    select coalesce(sum(subtotal), 0) from detail_pembelian where pembelian_id = new.pembelian_id
  )
  where id = new.pembelian_id;
  return new;
end;
$$ language plpgsql security definer;

create trigger trg_update_total_pembelian
after insert on detail_pembelian
for each row execute function fn_update_total_pembelian();

-- ========== 7. Update total penjualan otomatis dari detail_penjualan ==========
create or replace function fn_update_total_penjualan()
returns trigger as $$
begin
  update penjualan
  set total = (
    select coalesce(sum(subtotal), 0) from detail_penjualan where penjualan_id = new.penjualan_id
  )
  where id = new.penjualan_id;
  return new;
end;
$$ language plpgsql security definer;

create trigger trg_update_total_penjualan
after insert on detail_penjualan
for each row execute function fn_update_total_penjualan();

-- ========== 8. Notifikasi saat payroll final ==========
create or replace function fn_notif_payroll_final()
returns trigger as $$
begin
  if new.status_payroll = 'final' and old.status_payroll <> 'final' then
    insert into notifications (user_id, title, body)
    values (
      new.karyawan_id,
      'Slip Gaji Tersedia',
      'Slip gaji periode ' || new.periode || ' sudah tersedia. Total: Rp ' || new.total_gaji
    );
  end if;
  return new;
end;
$$ language plpgsql security definer;

create trigger trg_notif_payroll_final
after update on payroll
for each row execute function fn_notif_payroll_final();

-- ========== 9. Fungsi: Cek apakah keuntungan harian melebihi target (untuk trigger spin wheel di sisi app) ==========
create or replace function fn_get_keuntungan_harian(p_tanggal date default current_date)
returns numeric as $$
declare
  v_pendapatan numeric;
  v_target numeric;
begin
  select coalesce(sum(total), 0) into v_pendapatan
  from penjualan
  where tanggal_transaksi::date = p_tanggal;

  select target_keuntungan_harian into v_target from store_config where id = 1;

  return v_pendapatan; -- app layer yang bandingkan dengan v_target untuk trigger spin wheel eligibility
end;
$$ language plpgsql security definer stable;

-- ========== 10. Fungsi: Rekomendasi produk terlaris bulanan (untuk Intelligent System) ==========
create or replace function fn_produk_terlaris_bulanan(p_bulan text default to_char(current_date, 'YYYY-MM'))
returns table(produk_id uuid, nama_produk text, total_unit_terjual bigint) as $$
begin
  return query
  select p.id, p.nama_produk, sum(dp.jumlah)::bigint as total_unit_terjual
  from detail_penjualan dp
  join produk p on p.id = dp.produk_id
  join penjualan pj on pj.id = dp.penjualan_id
  where to_char(pj.tanggal_transaksi, 'YYYY-MM') = p_bulan
  group by p.id, p.nama_produk
  order by total_unit_terjual desc
  limit 10;
end;
$$ language plpgsql security definer stable;
