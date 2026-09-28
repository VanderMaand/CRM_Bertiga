# Spesifikasi Teknis — Coffee Street Mobile App
Adaptasi dari SRS "Sistem Informasi Pengelolaan Bisnis Coffee Street" (Web) ke Mobile (Flutter + Supabase)

---

## 1. Ringkasan Perubahan dari SRS Asli

| Aspek | SRS Asli (Web) | Versi Mobile |
|---|---|---|
| Platform | Web browser (Bootstrap) | Flutter — Android (prioritas), iOS menyusul |
| Backend | PHP + MySQL/MariaDB | Supabase (PostgreSQL + Auth + Realtime + Storage + Edge Functions) |
| State Management | — | Provider |
| Autentikasi | password_hash/verify | Supabase Auth (email/password) + Biometric (lapisan tambahan) |
| Absensi | GPS saja (dokumen asli) | GPS + Foto Wajah + Biometric (3 faktor) |
| Notifikasi | Email (opsional) | Push Notification (FCM) + Local Notification |
| Konektivitas | Selalu online | Offline-first untuk **Input Transaksi** & **Absensi**, modul lain online-only |

---

## 2. Fitur Tambahan — Spesifikasi Final

### 2.1 Notification Pop-Up
- **Engine:** Firebase Cloud Messaging (gratis, unlimited) dipicu via Supabase Edge Function saat event tertentu terjadi di database (trigger on insert/update).
- **Skenario notifikasi:**
  | Trigger | Penerima | Isi |
  |---|---|---|
  | Stok bahan baku < batas minimum | Manajer | "Stok [nama bahan] tersisa X, di bawah batas minimum" |
  | Manajer ajukan pembelian bahan baku | Owner | "Ada pengajuan pembelian baru menunggu persetujuan" |
  | Owner approve/reject pembelian | Manajer | "Pengajuan pembelian [ID] telah disetujui/ditolak" |
  | Payroll periode selesai diproses | Karyawan terkait | "Slip gaji periode [X] sudah tersedia" |

### 2.2 Minigame — Spin Wheel Bonus
- **Trigger:** Muncul otomatis ke karyawan di akhir shift **hanya jika** keuntungan harian toko melebihi target harian (threshold ditentukan Owner/Manajer, disimpan sebagai konfigurasi).
- **Mekanisme:** Setiap karyawan yang bertugas shift tersebut spin **sendiri-sendiri** (bukan diwakilkan).
- **Hasil spin:** Persentase bonus 1%–10% (random, weighted — bisa diatur probabilitasnya agar tidak selalu maksimal).
- **Perhitungan bonus per karyawan:**
  ```
  Pool Bonus Harian = Keuntungan Harian × (rata-rata % hasil spin seluruh karyawan shift tsb)
  Bonus per Karyawan = Pool Bonus Harian ÷ Jumlah Karyawan Shift
  ```
  *(Dibagi rata sesuai instruksi — hasil spin individual tetap dicatat untuk transparansi, tapi nominal final dibagi rata ke seluruh karyawan shift hari itu)*
- **Integrasi Payroll:** Bonus ini otomatis (tanpa approval manual) masuk sebagai komponen "Bonus Spin Wheel" di perhitungan payroll periode berjalan.
- **Tabel terkait:** `spin_wheel_log` (siapa spin, kapan, hasil %) → agregasi harian → masuk ke `payroll_components`.

### 2.3 Sensor Usage (Hardware)
- **GPS (Geolocation):** Validasi lokasi absensi harus dalam radius tertentu dari koordinat toko (disimpan di tabel `store_config`).
- **Kamera:** Ambil foto wajah saat absensi masuk/keluar, disimpan di Supabase Storage, sebagai bukti kehadiran.
- **Biometric (Fingerprint/Face ID via `local_auth` package):** Lapisan tambahan **di atas** GPS+foto — setelah foto & lokasi tervalidasi, karyawan konfirmasi ulang dengan biometric device sebelum absensi final tersimpan. Juga dipakai sebagai opsi cepat re-login (bukan pengganti password pertama kali).

### 2.4 Searching
Pencarian real-time (debounced) untuk 4 domain data:
- **Menu/Produk** — cari by nama produk/kategori (untuk kasir saat transaksi & manajer saat kelola menu)
- **Riwayat Transaksi** — cari by nomor transaksi, tanggal, atau nama kasir
- **Data Karyawan** — cari by nama/jabatan (untuk manajer)
- **Laporan** — filter/cari by rentang tanggal

### 2.5 Intelligent System — Rekomendasi Produk Terlaris
- **Periode:** Bulanan (agregasi otomatis per bulan berjalan)
- **Metrik:** Total unit terjual (bukan revenue)
- **Tampilan:** Dashboard Owner & Manajer — top 5-10 produk dalam bentuk chart/list
- **Pendekatan:** Rule-based aggregation query (SUM + GROUP BY + ORDER BY dari tabel `detail_penjualan`), bukan ML — cukup akurat untuk kebutuhan ini dan tidak perlu infrastruktur model terpisah.

### 2.6 Komputasi Terintegrasi
Mengikuti alur yang sudah tersirat di Class Diagram SRS asli, diperkuat dengan Supabase Database Triggers/Functions agar konsisten meski multi-device:
- Transaksi tersimpan → **trigger otomatis** kurangi stok bahan baku sesuai komposisi resep
- Pembelian bahan baku disetujui → **trigger otomatis** tambah stok
- Data Penjualan + Pembelian + Payroll → **agregasi otomatis** ke Laporan Periodik
- Keuntungan harian → **feed otomatis** ke logika threshold Spin Wheel

---

## 3. Modul Pengerjaan (Roadmap)

| Modul | Cakupan |
|---|---|
| **Modul 1 — Fondasi** | Setup Supabase, skema DB awal, Supabase Auth, role-based navigation (Owner/Manajer/Karyawan), struktur Provider |
| **Modul 2 — Operasional Kasir** | Input Transaksi (+offline mode), Cetak Struk, Update Stok otomatis (trigger), Absensi (GPS+Kamera+Biometric, +offline mode) |
| **Modul 3 — Manajemen** | Kelola Bahan Baku, Pembelian Bahan Baku, Input Data Karyawan, Lihat Stok, Persetujuan Owner |
| **Modul 4 — Keuangan & Payroll** | Mengatur Payroll, Paycheck, Spin Wheel + integrasi bonus payroll |
| **Modul 5 — Laporan & Analitik** | Rekapitulasi Penjualan, Generate/Lihat Laporan, Audit Keuangan, Rekomendasi Produk Terlaris |
| **Modul 6 — Fitur Tambahan (finishing)** | Notification (FCM), Search global, penghalusan Komputasi Terintegrasi antar modul |

---

## 4. Skema Database (Supabase / PostgreSQL)

```sql
-- ========== USERS & AUTH ==========
-- Menggunakan Supabase Auth (auth.users) + tabel profil tambahan
create table profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  nama text not null,
  role text not null check (role in ('owner','manajer','karyawan')),
  jabatan text,
  no_hp text,
  status_keaktifan text default 'aktif',
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
  check (id = 1) -- single row config
);

-- ========== ABSENSI ==========
create table absensi (
  id uuid primary key default gen_random_uuid(),
  karyawan_id uuid references profiles(id),
  tanggal date not null,
  waktu_masuk timestamptz,
  waktu_keluar timestamptz,
  foto_masuk_url text,
  foto_keluar_url text,
  lokasi_masuk point,
  lokasi_keluar point,
  biometric_verified boolean default false,
  status text default 'hadir',
  synced boolean default true, -- untuk offline-first tracking
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

create table resep_produk ( -- komposisi bahan baku per produk
  id uuid primary key default gen_random_uuid(),
  produk_id uuid references produk(id),
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
  total_pembelian numeric,
  status text default 'menunggu' check (status in ('menunggu','disetujui','ditolak')),
  alasan_penolakan text,
  created_at timestamptz default now()
);

create table detail_pembelian (
  id uuid primary key default gen_random_uuid(),
  pembelian_id uuid references pembelian_bahan_baku(id),
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
  total numeric,
  metode_bayar text,
  synced boolean default true, -- untuk offline-first tracking
  local_uuid text -- id sementara saat dibuat offline, untuk dedup saat sync
);

create table detail_penjualan (
  id uuid primary key default gen_random_uuid(),
  penjualan_id uuid references penjualan(id),
  produk_id uuid references produk(id),
  jumlah int,
  subtotal numeric
);

-- ========== PAYROLL & SPIN WHEEL ==========
create table payroll (
  id uuid primary key default gen_random_uuid(),
  karyawan_id uuid references profiles(id),
  periode text, -- format 'YYYY-MM'
  gaji_pokok numeric,
  total_bonus_spin numeric default 0,
  potongan numeric default 0,
  total_gaji numeric,
  status_payroll text default 'draft' check (status_payroll in ('draft','final')),
  created_at timestamptz default now()
);

create table spin_wheel_log (
  id uuid primary key default gen_random_uuid(),
  karyawan_id uuid references profiles(id),
  tanggal date default current_date,
  hasil_persen numeric, -- 1 - 10
  keuntungan_harian_saat_itu numeric,
  created_at timestamptz default now()
);

-- ========== LAPORAN ==========
create table laporan_periodik (
  id uuid primary key default gen_random_uuid(),
  periode text,
  jenis_laporan text, -- 'harian','mingguan','bulanan'
  pendapatan_total numeric,
  pengeluaran_total numeric,
  laba_bersih numeric,
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
```

### Trigger Kunci (Komputasi Terintegrasi)
- `trg_update_stok_after_penjualan` — AFTER INSERT ON `detail_penjualan` → kurangi `bahan_baku.stok_saat_ini` sesuai `resep_produk`
- `trg_update_stok_after_pembelian` — AFTER UPDATE ON `pembelian_bahan_baku` (status → 'disetujui') → tambah `bahan_baku.stok_saat_ini`
- `trg_cek_stok_minimum` — AFTER UPDATE ON `bahan_baku` → jika `stok_saat_ini < stok_minimum`, insert ke `notifications` untuk role manajer
- `trg_notif_pengajuan_pembelian` — AFTER INSERT ON `pembelian_bahan_baku` → notifikasi ke owner

---

## 5. Struktur Folder Project Flutter

```
lib/
├── main.dart
├── app.dart                        # MaterialApp + Provider setup
├── core/
│   ├── constants/                  # warna (#6F4E37 dll), style guide
│   ├── supabase_client.dart
│   ├── services/
│   │   ├── auth_service.dart
│   │   ├── biometric_service.dart
│   │   ├── location_service.dart
│   │   ├── camera_service.dart
│   │   ├── notification_service.dart   # FCM + local notification
│   │   ├── connectivity_service.dart   # deteksi online/offline
│   │   └── local_db_service.dart       # SQLite/Hive untuk offline queue
│   └── utils/
├── models/
│   ├── profile_model.dart
│   ├── produk_model.dart
│   ├── bahan_baku_model.dart
│   ├── penjualan_model.dart
│   ├── payroll_model.dart
│   └── ...
├── providers/
│   ├── auth_provider.dart
│   ├── transaksi_provider.dart
│   ├── stok_provider.dart
│   ├── payroll_provider.dart
│   ├── laporan_provider.dart
│   └── spin_wheel_provider.dart
├── screens/
│   ├── auth/
│   │   └── login_screen.dart
│   ├── owner/
│   │   ├── dashboard_owner_screen.dart
│   │   ├── persetujuan_screen.dart
│   │   ├── laporan_screen.dart
│   │   └── audit_keuangan_screen.dart
│   ├── manajer/
│   │   ├── dashboard_manajer_screen.dart
│   │   ├── kelola_bahan_baku_screen.dart
│   │   ├── pembelian_screen.dart
│   │   ├── input_karyawan_screen.dart
│   │   └── payroll_screen.dart
│   ├── karyawan/
│   │   ├── dashboard_karyawan_screen.dart
│   │   ├── absensi_screen.dart
│   │   ├── input_transaksi_screen.dart
│   │   ├── cetak_struk_screen.dart
│   │   ├── paycheck_screen.dart
│   │   └── spin_wheel_screen.dart
│   └── shared/
│       ├── search_screen.dart
│       └── notification_screen.dart
└── widgets/
    ├── common/
    └── spin_wheel/
        └── spin_wheel_widget.dart
```

---

## 6. Dependency Utama (pubspec.yaml)

```yaml
dependencies:
  supabase_flutter: ^latest
  provider: ^latest
  local_auth: ^latest          # biometric
  geolocator: ^latest          # GPS
  camera: ^latest              # foto wajah absensi
  firebase_core: ^latest
  firebase_messaging: ^latest  # push notification
  flutter_local_notifications: ^latest
  connectivity_plus: ^latest   # deteksi online/offline
  sqflite: ^latest             # local storage offline queue
  fl_chart: ^latest            # chart rekomendasi produk terlaris
```

---

## 7. Catatan Penting Sebelum Coding

1. **Row Level Security (RLS)** di Supabase wajib diaktifkan per tabel sesuai role — ini akan disiapkan bersamaan dengan skema di Modul 1.
2. **Offline queue** untuk Input Transaksi & Absensi akan pakai pola: simpan ke SQLite lokal dulu → background sync worker cek konektivitas → push ke Supabase saat online → tandai `synced = true`.
3. **Firebase project** perlu dibuat terpisah dari Supabase (khusus untuk FCM), tapi ini gratis dan hanya perlu `google-services.json` untuk Android.
4. Desain UI mengikuti style guide asli (Coffee Brown #6F4E37, Latte Beige #C19A6B, Golden Yellow #FFD700) sambil menunggu Figma mobile Anda selesai — bisa disesuaikan begitu mockup siap.
