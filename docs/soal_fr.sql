-- ======================================================
-- PHYSICAL DATA MODEL (PDM) - APLIKASI PEMBAYARAN LISTRIK PASCABAYAR
-- ======================================================

-- 1. STRUKTUR TABEL YANG SUDAH ADA (BERDASARKAN DDL)
-- (Tabel sudah dibuat sesuai DDL yang diberikan)

-- 2. INPUT DATA MENGGUNAKAN DML

-- Data untuk tabel level (sudah ada)
INSERT INTO `level` (`id_level`, `level`) VALUES
											  ('LVL001', 'ADMIN'),
											  ('LVL002', 'PETUGAS');

-- Data untuk tabel user
INSERT INTO `user` (`id_user`, `username`, `password`, `nama_admin`, `id_level`) VALUES
																					 ('ADM0000', 'superadmin', 'superadmin', 'superadmin', 'LVL001'),
																					 ('USR0001', 'Admin', '$2y$10$yuL.WbMZOTxtTZRMoi19k.k3okzdhsut81wKd6k0B2.hDWGyHue/y', 'Admin', 'LVL001'),
																					 ('USR0002', 'petugas_admin', '$2y$10$r/0R1J98IlE5wFil6gsuZOgAkfDZ.grlfk33r2mR/At9nAuq1iF3y', 'Petugas', 'LVL002'),
																					 ('USR0003', 'petugas001', '$2y$10$F0cY/xyS0rBXDObRZNLaYuEjlmbONHamVZPCWiKIDyilKnki3q83G', 'Petugas001 UP', 'LVL002');

-- Data untuk tabel pelanggan
INSERT INTO `pelanggan` (`id_pelanggan`, `nama_pelanggan`, `username`, `password`, `nomor_kwh`, `alamat`, `id_tarif`) VALUES
																														  ('PLG2209010001', 'unit zero', 'unit.zero', '$2y$10$tPA60JV0Obr6nBktdQ98AOXorcKWIOdYP17Qw5xJFzUCq1IIv.JiC', '00000000000', 'Jln 000', 'TRF20230205002'),
																														  ('PLG2209120003', 'Manjaro', 'Manjaro', '$2y$10$Sk5hTXYQtGtBrvs0JfLx0u65HhYh1HZ.kmY58f41/PGzEqZpDXdKi', '888888888', 'Jln XCFE', 'TRF20230205007'),
																														  ('PLG2210060004', 'pax', 'pax', '$2y$10$pMLeth.kT9ISPrmDWQZAFu/qwFlwGvrW3K5jxEZeyCEm.758DkASO', '0251823230800', 'Bandung', 'TRF20230205009'),
																														  ('PLG2210100001', 'KKKKKKK', 'kkkkkkk', '$2y$10$uBS4h11n2oE5CYAA7czaoOWD7gS1n2m8lKO..Myi8N75B0Rt4PPeW', '025180150800', 'JL. KKK RT.22/RW.22', 'TRF20230205009');

-- Data untuk tabel penggunaan
INSERT INTO `penggunaan` (`id_penggunaan`, `id_pelanggan`, `bulan`, `tahun`, `meter_awal`, `meter_akhir`) VALUES
																											  ('PN220101002', 'PLG2302080001', 1, 2023, 0, 100),
																											  ('PN220910005', 'PLG2210100001', 9, 2022, 0, 100),
																											  ('PN221012001', 'PLG2210060004', 10, 2022, 0, 125),
																											  ('PN221016005', 'PLG2210100001', 10, 2022, 100, 230),
																											  ('PN221101001', 'PLG2210060004', 11, 2022, 125, 400),
																											  ('PN221201001', 'PLG2210060004', 12, 2022, 400, 515);

-- 3. VIEW TABEL UNTUK MENAMPILKAN INFORMASI PENGGUNAAN LISTRIK

CREATE VIEW `view_penggunaan_listrik` AS
SELECT
	p.id_penggunaan,
	p.id_pelanggan,
	pel.nama_pelanggan,
	pel.nomor_kwh,
	pel.alamat,
	p.bulan,
	p.tahun,
	p.meter_awal,
	p.meter_akhir,
	(p.meter_akhir - p.meter_awal) AS jumlah_penggunaan,
	t.daya,
	t.tarif_perkwh,
	((p.meter_akhir - p.meter_awal) * t.tarif_perkwh) AS total_biaya
FROM penggunaan p
		 JOIN pelanggan pel ON p.id_pelanggan = pel.id_pelanggan
		 JOIN tarif t ON pel.id_tarif = t.id_tarif;

-- Test view
SELECT * FROM view_penggunaan_listrik;

-- 4. STORED PROCEDURE UNTUK MENAMPILKAN PELANGGAN DENGAN DAYA 900 WATT

DELIMITER //

CREATE PROCEDURE `tampilkan_pelanggan_900watt`()
BEGIN
SELECT
	p.id_pelanggan,
	p.nama_pelanggan,
	p.username,
	p.nomor_kwh,
	p.alamat,
	t.daya,
	t.tarif_perkwh
FROM pelanggan p
		 JOIN tarif t ON p.id_tarif = t.id_tarif
WHERE t.daya = '900VA';
END //

DELIMITER ;

-- Test stored procedure
CALL tampilkan_pelanggan_900watt();

-- 5. FUNCTION UNTUK MENGHITUNG TOTAL PENGGUNAAN LISTRIK PER BULAN

DELIMITER //

CREATE FUNCTION `hitung_total_penggunaan_perbulan`(p_bulan INT, p_tahun INT)
	RETURNS INT
	DETERMINISTIC
	READS SQL DATA
BEGIN
    DECLARE total_penggunaan INT DEFAULT 0;

SELECT SUM(meter_akhir - meter_awal)
INTO total_penggunaan
FROM penggunaan
WHERE bulan = p_bulan AND tahun = p_tahun;

RETURN IFNULL(total_penggunaan, 0);
END //

DELIMITER ;

-- Test function
SELECT hitung_total_penggunaan_perbulan(1, 2023) AS total_penggunaan_jan_2023;

-- 6. TRIGGER UNTUK MENYIMPAN DATA TAGIHAN SETELAH INSERT PENGGUNAAN LISTRIK

DELIMITER //

CREATE TRIGGER `auto_generate_tagihan`
	AFTER INSERT ON `penggunaan`
	FOR EACH ROW
BEGIN
	DECLARE v_id_tagihan VARCHAR(128);

    -- Generate ID tagihan dengan format TG + YYYYMMDD + nomor urut
    SET v_id_tagihan = CONCAT('TG', DATE_FORMAT(NOW(), '%Y%m%d'),
                             LPAD((SELECT COUNT(*) + 1 FROM tagihan
                                   WHERE DATE(NOW()) = DATE(NOW())), 3, '0'));

    -- Insert ke tabel tagihan
	INSERT INTO tagihan (
		id_tagihan,
		id_penggunaan,
		id_pelanggan,
		bulan,
		tahun,
		jumlah_meter,
		status
	) VALUES (
				 v_id_tagihan,
				 NEW.id_penggunaan,
				 NEW.id_pelanggan,
				 NEW.bulan,
				 NEW.tahun,
				 (NEW.meter_akhir - NEW.meter_awal),
				 'UNPAID'
			 );
END //

DELIMITER ;

-- Test trigger dengan insert data penggunaan baru
INSERT INTO `penggunaan` (`id_penggunaan`, `id_pelanggan`, `bulan`, `tahun`, `meter_awal`, `meter_akhir`)
VALUES ('PN230301001', 'PLG2209010001', 3, 2023, 100, 200);

-- Cek hasil trigger
SELECT * FROM tagihan WHERE id_pelanggan = 'PLG2209010001' AND bulan = 3 AND tahun = 2023;

-- 7. COMMIT DAN ROLLBACK OPERATIONS

-- COMMIT setelah insert data tarif
START TRANSACTION;
INSERT INTO `tarif` (`id_tarif`, `daya`, `tarif_perkwh`) VALUES
	('TRF20230301001', '2200VA', 1500);
COMMIT;

-- Verify insert tarif
SELECT * FROM tarif WHERE id_tarif = 'TRF20230301001';

-- ROLLBACK setelah hapus data pelanggan
START TRANSACTION;
DELETE FROM pelanggan WHERE id_pelanggan = 'PLG2209010001';
-- Cek apakah data terhapus
SELECT * FROM pelanggan WHERE id_pelanggan = 'PLG2209010001';
ROLLBACK;

-- Verify rollback - data pelanggan harus kembali
SELECT * FROM pelanggan WHERE id_pelanggan = 'PLG2209010001';

-- ======================================================
-- TAMBAHAN: QUERY UNTUK TESTING DAN VERIFIKASI
-- ======================================================

-- Test semua komponen yang dibuat
SELECT '=== VIEW PENGGUNAAN LISTRIK ===' AS info;
SELECT * FROM view_penggunaan_listrik LIMIT 5;

SELECT '=== STORED PROCEDURE PELANGGAN 900WATT ===' AS info;
CALL tampilkan_pelanggan_900watt();

SELECT '=== FUNCTION TOTAL PENGGUNAAN ===' AS info;
SELECT hitung_total_penggunaan_perbulan(1, 2023) AS total_jan_2023;
SELECT hitung_total_penggunaan_perbulan(2, 2023) AS total_feb_2023;

SELECT '=== TRIGGER TEST RESULT ===' AS info;
SELECT * FROM tagihan WHERE id_penggunaan = 'PN230301001';

-- ======================================================
-- RELASI ANTAR TABEL (FOREIGN KEY CONSTRAINTS)
-- ======================================================

-- Foreign Key untuk tabel pelanggan
ALTER TABLE pelanggan
	ADD CONSTRAINT fk_pelanggan_tarif
		FOREIGN KEY (id_tarif) REFERENCES tarif(id_tarif) ON DELETE SET NULL ON UPDATE CASCADE;

-- Foreign Key untuk tabel user
ALTER TABLE user
	ADD CONSTRAINT fk_user_level
		FOREIGN KEY (id_level) REFERENCES level(id_level) ON DELETE RESTRICT ON UPDATE CASCADE;

-- Foreign Key untuk tabel penggunaan
ALTER TABLE penggunaan
	ADD CONSTRAINT fk_penggunaan_pelanggan
		FOREIGN KEY (id_pelanggan) REFERENCES pelanggan(id_pelanggan) ON DELETE CASCADE ON UPDATE CASCADE;

-- Foreign Key untuk tabel tagihan
ALTER TABLE tagihan
	ADD CONSTRAINT fk_tagihan_penggunaan
		FOREIGN KEY (id_penggunaan) REFERENCES penggunaan(id_penggunaan) ON DELETE CASCADE ON UPDATE CASCADE,
ADD CONSTRAINT fk_tagihan_pelanggan
FOREIGN KEY (id_pelanggan) REFERENCES pelanggan(id_pelanggan) ON DELETE CASCADE ON UPDATE CASCADE;

-- Foreign Key untuk tabel pembayaran
ALTER TABLE pembayaran
	ADD CONSTRAINT fk_pembayaran_tagihan
		FOREIGN KEY (id_tagihan) REFERENCES tagihan(id_tagihan) ON DELETE CASCADE ON UPDATE CASCADE,
ADD CONSTRAINT fk_pembayaran_pelanggan
FOREIGN KEY (id_pelanggan) REFERENCES pelanggan(id_pelanggan) ON DELETE CASCADE ON UPDATE CASCADE,
ADD CONSTRAINT fk_pembayaran_user
FOREIGN KEY (id_user) REFERENCES user(id_user) ON DELETE RESTRICT ON UPDATE CASCADE;

-- ======================================================
-- INDEXES UNTUK OPTIMASI PERFORMA
-- ======================================================

-- Index untuk pencarian berdasarkan bulan dan tahun
CREATE INDEX idx_penggunaan_bulan_tahun ON penggunaan(bulan, tahun);
CREATE INDEX idx_tagihan_bulan_tahun ON tagihan(bulan, tahun);

-- Index untuk pencarian berdasarkan status tagihan
CREATE INDEX idx_tagihan_status ON tagihan(status);

-- Index untuk pencarian berdasarkan tanggal bayar
CREATE INDEX idx_pembayaran_tgl_bayar ON pembayaran(tgl_bayar);

-- ======================================================
-- DOKUMENTASI STRUKTUR DATABASE
-- ======================================================

/*
STRUKTUR DATABASE APLIKASI PEMBAYARAN LISTRIK PASCABAYAR

1. TABEL MASTER:
   - level: Data level user (Admin, Petugas)
   - tarif: Data tarif listrik berdasarkan daya
   - user: Data admin dan petugas sistem
   - pelanggan: Data pelanggan listrik

2. TABEL TRANSAKSI:
   - penggunaan: Data penggunaan listrik bulanan
   - tagihan: Data tagihan yang dihasilkan dari penggunaan
   - pembayaran: Data pembayaran tagihan

3. VIEW:
   - view_penggunaan_listrik: Menampilkan detail penggunaan dengan info pelanggan dan tarif

4. STORED PROCEDURE:
   - tampilkan_pelanggan_900watt(): Menampilkan pelanggan dengan daya 900VA

5. FUNCTION:
   - hitung_total_penggunaan_perbulan(): Menghitung total penggunaan per bulan

6. TRIGGER:
   - auto_generate_tagihan: Otomatis membuat tagihan setelah input penggunaan

7. CONSTRAINTS:
   - Foreign Key relationships untuk integritas data
   - Indexes untuk optimasi performa
*/
