-- ============================================================
-- Coffee Street Mobile - Database Schema
-- Jalankan file ini di Supabase SQL Editor (sekali saja)
-- ============================================================

-- Extension untuk gen_random_uuid()
create extension if not exists pgcrypto;

-- ========== PROFILES (extends auth.users) ==========
create table profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  nama text not null,
  role text not null check (role in ('owner','manajer','karyawan')),
  jabatan text,
  no_hp text,
  status_keaktifan text default 'aktif',
  fcm_token text,
  created_at timestamptz default now()
);

-- ========== KONFIGURASI TOKO ==========
create table store_config (
  id int primary key default 1,
  nama_toko text,
  latitude double precision,
  longitude double precision,
  radius_meter int default 50,
  target_keuntungan_harian numeric default 0,
  check (id = 1)
);
insert into store_config (id, nama_toko, latitude, longitude, radius_meter, target_keuntungan_harian)
values (1, 'Coffee Street', 0, 0, 50, 500000);

-- ========== ABSENSI ==========
create table absensi (
  id uuid primary key default gen_random_uuid(),
  karyawan_id uuid references profiles(id),
  tanggal date not null default current_date,
  waktu_masuk timestamptz,
  waktu_keluar timestamptz,
  foto_masuk_url text,
  foto_keluar_url text,
  lat_masuk double precision,
  lng_masuk double precision,
  lat_keluar double precision,
  lng_keluar double precision,
  biometric_verified boolean default false,
  status text default 'hadir',
  synced boolean default true,
  created_at timestamptz default now()
);

-- ========== PRODUK & BAHAN BAKU ==========
create table bahan_baku (
  id uuid primary key default gen_random_uuid(),
  nama_bahan text not null,
  satuan text,
  stok_saat_ini numeric default 0,
  stok_minimum numeric default 0,
  updated_at timestamptz default now()
);

create table produk (
  id uuid primary key default gen_random_uuid(),
  nama_produk text not null,
  kategori text,
  harga_satuan numeric not null,
  satuan text,
  status_aktif boolean default true
);

create table resep_produk (
  id uuid primary key default gen_random_uuid(),
  produk_id uuid references produk(id) on delete cascade,
  bahan_baku_id uuid references bahan_baku(id),
  jumlah_dibutuhkan numeric not null
);

-- ========== SUPPLIER & PEMBELIAN ==========
create table supplier (
  id uuid primary key default gen_random_uuid(),
  nama_supplier text not null,
  alamat text,
  no_hp text,
  status text default 'aktif'
);

create table pembelian_bahan_baku (
  id uuid primary key default gen_random_uuid(),
  manajer_id uuid references profiles(id),
  supplier_id uuid references supplier(id),
  tanggal date default current_date,
  total_pembelian numeric default 0,
  status text default 'menunggu' check (status in ('menunggu','disetujui','ditolak')),
  alasan_penolakan text,
  created_at timestamptz default now()
);

create table detail_pembelian (
  id uuid primary key default gen_random_uuid(),
  pembelian_id uuid references pembelian_bahan_baku(id) on delete cascade,
  bahan_baku_id uuid references bahan_baku(id),
  jumlah_beli numeric,
  harga_satuan numeric,
  subtotal numeric generated always as (jumlah_beli * harga_satuan) stored
);

-- ========== TRANSAKSI PENJUALAN ==========
create table penjualan (
  id uuid primary key default gen_random_uuid(),
  karyawan_id uuid references profiles(id),
  tanggal_transaksi timestamptz default now(),
  total numeric default 0,
  metode_bayar text,
  synced boolean default true,
  local_uuid text
);

create table detail_penjualan (
  id uuid primary key default gen_random_uuid(),
  penjualan_id uuid references penjualan(id) on delete cascade,
  produk_id uuid references produk(id),
  jumlah int,
  subtotal numeric
);

-- ========== PAYROLL & SPIN WHEEL ==========
create table payroll (
  id uuid primary key default gen_random_uuid(),
  karyawan_id uuid references profiles(id),
  periode text,
  gaji_pokok numeric default 0,
  total_bonus_spin numeric default 0,
  potongan numeric default 0,
  total_gaji numeric generated always as (gaji_pokok + total_bonus_spin - potongan) stored,
  status_payroll text default 'draft' check (status_payroll in ('draft','final')),
  created_at timestamptz default now()
);

create table spin_wheel_log (
  id uuid primary key default gen_random_uuid(),
  karyawan_id uuid references profiles(id),
  tanggal date default current_date,
  hasil_persen numeric check (hasil_persen between 1 and 10),
  keuntungan_harian_saat_itu numeric,
  created_at timestamptz default now()
);

-- ========== LAPORAN ==========
create table laporan_periodik (
  id uuid primary key default gen_random_uuid(),
  periode text,
  jenis_laporan text,
  pendapatan_total numeric default 0,
  pengeluaran_total numeric default 0,
  laba_bersih numeric default 0,
  generated_by uuid references profiles(id),
  created_at timestamptz default now()
);

-- ========== NOTIFIKASI ==========
create table notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references profiles(id),
  title text,
  body text,
  is_read boolean default false,
  created_at timestamptz default now()
);

-- ============================================================
-- INDEXES
-- ============================================================
create index idx_absensi_karyawan on absensi(karyawan_id);
create index idx_penjualan_karyawan on penjualan(karyawan_id);
create index idx_detail_penjualan_penjualan on detail_penjualan(penjualan_id);
create index idx_detail_penjualan_produk on detail_penjualan(produk_id);
create index idx_payroll_karyawan on payroll(karyawan_id, periode);
create index idx_notifications_user on notifications(user_id, is_read);
