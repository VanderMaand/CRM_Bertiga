-- ============================================================
-- CATATAN: Membuat user Supabase Auth TIDAK bisa lewat SQL Editor biasa
-- karena auth.users dikelola khusus oleh Supabase Auth service.
--
-- Cara membuat akun demo (lakukan di Dashboard, bukan SQL Editor):
-- 1. Buka menu Authentication > Users > Add User (invite tanpa email confirmation)
-- 2. Isi email & password untuk masing-masing akun demo, misal:
--      owner@coffeestreet.com    / password bebas (min 6 karakter)
--      manajer@coffeestreet.com  / password bebas
--      kasir1@coffeestreet.com   / password bebas
-- 3. Setelah user dibuat, copy UUID masing-masing user dari kolom "UID"
-- 4. Jalankan script di bawah ini di SQL Editor, GANTI uuid-nya sesuai hasil copy
-- ============================================================

-- Contoh (ganti UUID sesuai user yang baru dibuat di dashboard):
insert into profiles (id, nama, role, jabatan) values
  ('GANTI-DENGAN-UUID-OWNER', 'Budi Santoso', 'owner', 'Pemilik'),
  ('GANTI-DENGAN-UUID-MANAJER', 'Siti Aminah', 'manajer', 'Manajer Operasional'),
  ('GANTI-DENGAN-UUID-KARYAWAN', 'Andi Wijaya', 'karyawan', 'Barista');

-- Tambahkan beberapa data awal produk & bahan baku untuk testing Modul 2
insert into bahan_baku (nama_bahan, satuan, stok_saat_ini, stok_minimum) values
  ('Biji Kopi Arabika', 'gram', 5000, 1000),
  ('Susu UHT', 'ml', 10000, 2000),
  ('Gula Aren', 'gram', 3000, 500);

insert into produk (nama_produk, kategori, harga_satuan, satuan) values
  ('Kopi Susu Gula Aren', 'Minuman', 18000, 'cup'),
  ('Americano', 'Minuman', 15000, 'cup'),
  ('Cappuccino', 'Minuman', 20000, 'cup');
