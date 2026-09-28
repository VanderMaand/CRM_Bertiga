-- ============================================================
-- Row Level Security (RLS) Policies
-- Jalankan setelah 01_schema.sql
-- ============================================================

-- Helper function: ambil role user yang sedang login
create or replace function get_my_role()
returns text as $$
  select role from profiles where id = auth.uid();
$$ language sql security definer stable;

-- ========== PROFILES ==========
alter table profiles enable row level security;

create policy "Semua user login bisa lihat semua profile"
  on profiles for select
  using (auth.role() = 'authenticated');

create policy "User bisa update profile sendiri"
  on profiles for update
  using (id = auth.uid());

create policy "Manajer bisa insert profile karyawan baru"
  on profiles for insert
  with check (get_my_role() in ('manajer','owner'));

-- ========== ABSENSI ==========
alter table absensi enable row level security;

create policy "Karyawan lihat absensi sendiri, manajer/owner lihat semua"
  on absensi for select
  using (karyawan_id = auth.uid() or get_my_role() in ('manajer','owner'));

create policy "Karyawan bisa insert absensi sendiri"
  on absensi for insert
  with check (karyawan_id = auth.uid());

create policy "Karyawan bisa update absensi sendiri (absen keluar)"
  on absensi for update
  using (karyawan_id = auth.uid());

-- ========== BAHAN BAKU ==========
alter table bahan_baku enable row level security;

create policy "Semua user login bisa lihat bahan baku"
  on bahan_baku for select
  using (auth.role() = 'authenticated');

create policy "Manajer bisa kelola bahan baku"
  on bahan_baku for all
  using (get_my_role() in ('manajer','owner'));

-- ========== PRODUK & RESEP ==========
alter table produk enable row level security;
alter table resep_produk enable row level security;

create policy "Semua user login bisa lihat produk"
  on produk for select using (auth.role() = 'authenticated');

create policy "Manajer kelola produk"
  on produk for all using (get_my_role() in ('manajer','owner'));

create policy "Semua user login bisa lihat resep"
  on resep_produk for select using (auth.role() = 'authenticated');

create policy "Manajer kelola resep"
  on resep_produk for all using (get_my_role() in ('manajer','owner'));

-- ========== SUPPLIER & PEMBELIAN ==========
alter table supplier enable row level security;
alter table pembelian_bahan_baku enable row level security;
alter table detail_pembelian enable row level security;

create policy "Manajer & owner lihat supplier"
  on supplier for select using (get_my_role() in ('manajer','owner'));

create policy "Manajer kelola supplier"
  on supplier for all using (get_my_role() in ('manajer','owner'));

create policy "Manajer & owner lihat pembelian"
  on pembelian_bahan_baku for select using (get_my_role() in ('manajer','owner'));

create policy "Manajer insert pembelian"
  on pembelian_bahan_baku for insert with check (get_my_role() = 'manajer');

create policy "Owner update status pembelian (approve/reject)"
  on pembelian_bahan_baku for update using (get_my_role() in ('owner','manajer'));

create policy "Manajer & owner lihat detail pembelian"
  on detail_pembelian for select using (get_my_role() in ('manajer','owner'));

create policy "Manajer insert detail pembelian"
  on detail_pembelian for insert with check (get_my_role() = 'manajer');

-- ========== PENJUALAN ==========
alter table penjualan enable row level security;
alter table detail_penjualan enable row level security;

create policy "Karyawan lihat transaksi sendiri, manajer/owner semua"
  on penjualan for select
  using (karyawan_id = auth.uid() or get_my_role() in ('manajer','owner'));

create policy "Karyawan insert transaksi sendiri"
  on penjualan for insert with check (karyawan_id = auth.uid());

create policy "Lihat detail penjualan sesuai akses penjualan induk"
  on detail_penjualan for select
  using (
    exists (
      select 1 from penjualan p
      where p.id = penjualan_id
      and (p.karyawan_id = auth.uid() or get_my_role() in ('manajer','owner'))
    )
  );

create policy "Insert detail penjualan oleh karyawan pemilik transaksi"
  on detail_penjualan for insert
  with check (
    exists (select 1 from penjualan p where p.id = penjualan_id and p.karyawan_id = auth.uid())
  );

-- ========== PAYROLL & SPIN WHEEL ==========
alter table payroll enable row level security;
alter table spin_wheel_log enable row level security;

create policy "Karyawan lihat payroll sendiri, manajer/owner semua"
  on payroll for select
  using (karyawan_id = auth.uid() or get_my_role() in ('manajer','owner'));

create policy "Manajer kelola payroll"
  on payroll for all using (get_my_role() = 'manajer');

create policy "Karyawan lihat riwayat spin sendiri, manajer/owner semua"
  on spin_wheel_log for select
  using (karyawan_id = auth.uid() or get_my_role() in ('manajer','owner'));

create policy "Karyawan insert hasil spin sendiri"
  on spin_wheel_log for insert with check (karyawan_id = auth.uid());

-- ========== LAPORAN ==========
alter table laporan_periodik enable row level security;

create policy "Manajer & owner lihat laporan"
  on laporan_periodik for select using (get_my_role() in ('manajer','owner'));

create policy "Manajer generate laporan"
  on laporan_periodik for insert with check (get_my_role() = 'manajer');

-- ========== NOTIFICATIONS ==========
alter table notifications enable row level security;

create policy "User lihat notifikasi sendiri"
  on notifications for select using (user_id = auth.uid());

create policy "User update status baca notifikasi sendiri"
  on notifications for update using (user_id = auth.uid());

create policy "System bisa insert notifikasi ke siapapun"
  on notifications for insert with check (true);

-- ========== STORE CONFIG ==========
alter table store_config enable row level security;

create policy "Semua user login bisa lihat store config"
  on store_config for select using (auth.role() = 'authenticated');

create policy "Owner update store config"
  on store_config for update using (get_my_role() = 'owner');
