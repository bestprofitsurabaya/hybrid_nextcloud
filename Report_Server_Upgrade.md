# Laporan Audit & Upgrade NAS BPF — Dell PowerEdge R210 II

| | |
|---|---|
| **Dokumen** | Audit hardware, rekomendasi upgrade, dan log pelaksanaan |
| **Objek** | `NAS` — Dell PowerEdge R210 II, Service Tag `9B6HC2S` |
| **Akses** | `192.168.2.31:22` (LAN kantor), alternatif `nasbpfsby.duckdns.org:2211` |
| **Audit awal** | 3 November 2026, 16:29–16:5x WIB (read-only) |
| **Pelaksanaan** | 5 November 2026 — BIOS **selesai**; BMC/iDRAC6 **dalam proses** |
| **Status server** | Produksi aktif, 25 container berjalan, 0 `unhealthy` |
| **Revisi dokumen** | v3 — 5 November 2026 (restrukturisasi + bagian BMC/iDRAC6) |

## Daftar Isi

1. [Ringkasan Eksekutif](#1-ringkasan-eksekutif)
2. [Konteks, Lingkup & Metode](#2-konteks-lingkup--metode)
3. [Inventaris Hardware](#3-inventaris-hardware)
4. [Diagnosis](#4-diagnosis)
5. [Rekomendasi](#5-rekomendasi)
6. [Rencana Migrasi](#6-rencana-migrasi)
7. [Log Pelaksanaan](#7-log-pelaksanaan)
8. [Daftar Tindakan Berprioritas](#8-daftar-tindakan-berprioritas)
9. [Risiko, Catatan & Asumsi](#9-risiko-catatan--asumsi)
10. [Lampiran](#10-lampiran)

---

## 1. Ringkasan Eksekutif

### 1.1 Kondisi saat ini

| Aspek | Kondisi | Status |
|---|---|---|
| Platform | Dell PowerEdge R210 II, BIOS **2.10.0 (2018)** — terpasang 5-Nov-2026 | 🔴 EOL, tidak bisa dikembangkan |
| Manajemen OOB | BMC/iDRAC6 **1.80**, Express (shared NIC), **NIC tidak aktif di jaringan** | 🟡 Target ≥ 1.85; butuh akses konsol |
| CPU | Xeon E3-1220 4C/4T (2011) | 🟡 Cukup untuk beban sekarang, tanpa HT |
| RAM | 3,9 GB untuk 25 container | 🔴 **Bottleneck utama** — swap terpakai 1,78 GB |
| Storage | 3 disk tunggal, **tanpa RAID** | 🔴 **Nol redundansi** |
| Umur disk | 1 disk 5,9 tahun; 1 disk 4,2 tahun | 🔴 Melewati/akan melewati umur desain 5 tahun |
| Kelas disk | Semua surveillance/video, bukan NAS | 🔴 Tidak layak RAID (tanpa TLER/ERC) |
| Backup | Tidak ada untuk Nextcloud & karaoke | 🔴 **Risiko terbesar** |
| Jaringan | 1× GbE aktif, 1× degradasi ke 100 M | 🟡 Butuh perbaikan kabel/port |
| Kapasitas | Karaoke 84% penuh (1,6 T dari 1,9 T) | 🟡 Butuh tambahan ruang |

### 1.2 Kesimpulan

Hanya **RAM** yang layak di-upgrade di dalam R210 II. Sisanya sudah mentok secara platform
(DDR3, 2 bay, tanpa NVMe, tanpa 2,5 GbE, BIOS 2011). Rekomendasi utama: pindah ke **NAS 4-bay
x86** (TerraMaster F4-424 Pro atau UGREEN DXP4800 Plus) dengan **Debian 13 + Docker** yang sudah
dipakai sekarang, ditambah **4× 8 TB RAIDZ1**. Anggaran ±**Rp33–37 juta**.

**Sebelum membeli apa pun: buat backup dulu** — saat ini tidak ada salinan data sama sekali.

### 1.3 Status pekerjaan

| Pekerjaan | Status | Bukti / catatan |
|---|---|---|
| Upgrade BIOS 1.3.1 → 2.8.0 → 2.10.0 | ✅ Selesai 5-Nov-2026 | §7.1 — `dmidecode` 2.10.0, microcode `0x2f` |
| Pemeriksaan & persiapan BMC/iDRAC6 → ≥ 1.85 | 🟡 Berjalan | §7.2 — firmware 1.80 terkonfirmasi, paket siap, NIC iDRAC belum hidup |
| Flash BMC 1.85 → 2.92 | ⏳ Dijadwalkan 6-Nov-2026 | Menunggu akses konsol (Ctrl-E) |
| RAM 32 GB, backup, NAS baru | ⏳ Belum dimulai | §5, §6 |

---

## 2. Konteks, Lingkup & Metode

### 2.1 Lingkup

- Inventaris hardware dan kondisi kesehatan disk/CPU/RAM.
- Diagnosis bottleneck berdasarkan bukti (`/proc`, `smartctl`, `docker`, `ip`).
- Rekomendasi jalur upgrade beserta perkiraan biaya pasar Indonesia.
- Pelaksanaan upgrade firmware yang aman untuk server produksi (BIOS, lalu BMC).

Di luar lingkup: perubahan konfigurasi layanan, migrasi data, dan pembelian hardware.

### 2.2 Metode

SSH langsung ke host; pembacaan `dmidecode`, `/proc`, `smartctl`, `docker`, `ip`, `lsscsi`;
pembacaan BMC in-band lewat `ipmitool` + `/dev/ipmi0` (KCS). Seluruh audit awal bersifat
**read-only**; satu-satunya perubahan pada 3-Nov adalah dokumentasi.

### 2.3 Batasan

- Tidak ada akses ke switch/jaringan kantor, sehingga uji sisi jaringan terbatas dari host NAS.
- BMC tidak punya jalur out-of-band, jadi diagnosa iDRAC hanya bisa in-band + bukti lalu lintas.
- Harga adalah estimasi listing pasar, bukan penawaran resmi.

---

## 3. Inventaris Hardware

### 3.1 Sistem & identitas

| Item | Nilai |
|---|---|
| Hostname | `NAS` |
| OS | Debian GNU/Linux 13 (trixie), kernel `6.12.48+deb13-amd64` |
| Uptime saat audit | 3 hari 7 jam |
| Load average | 0,33 / 0,38 / 0,35 (≈1% dari 4 core) |
| Pengguna aktif | 2 |
| Seri | Dell PowerEdge R210 II, 1U rack |
| Service Tag | `9B6HC2S` |
| Mainboard | Dell `09T7VV`, rev `A05` |
| BIOS | **2.10.0, rilis 24 Mei 2018** — di-flash 5-Nov-2026 via DUP Dell `69VFP` (sebelumnya 1.3.1, 10-Nov-2011). Bukti: `dmidecode` `2.10.0` / `05/24/2018`, microcode `0x2f` |
| BMC / iDRAC6 | **iDRAC6 Express, firmware 1.80**, IPMI 2.0, Device ID 32, MAC `d0:67:e5:f4:0a:66`. NIC mode `shared` (LOM1), **tidak menjawab di jaringan** (§7.2) |

### 3.2 Prosesor

| Item | Nilai |
|---|---|
| Model | Intel Xeon **E3-1220** @ 3,10 GHz |
| Arsitektur | Sandy Bridge, x86_64, LGA1155 |
| Core / Thread | **4 core / 4 thread** (tanpa HyperThreading) |
| Cache L3 | 8 MB |
| Frekuensi | 1,6 GHz (idle, scaling 51%) – 3,4 GHz (turbo) |
| TDP | 80 W |
| Fitur | AES-NI ✅, AVX ✅ |
| Socket terpakai | 1 dari 1 |

E3-1220 adalah seri paling bawah E3-1200 v1 — tanpa HT dan tanpa GPU. Setara skor multi-core
±4.300 (PassMark), sudah di bawah N100/N95 modern.

### 3.3 Memori

| Item | Nilai |
|---|---|
| Total terpasang | **3.911 MB (≈3,9 GB)** |
| Terpakai | 2.528 MB |
| Available | **1.383 MB** |
| Cache/buffer | 1.473 MB |
| Swap total | 9.167 MB (partisi `/dev/sdb6`) |
| **Swap terpakai** | **1.781 MB** |
| Slot total | 4 (DIMM A1, A2, B1, B2) |
| Slot terisi | **2** (A1 dan B1) — 2 slot kosong |
| Tipe | DDR3 ECC UDIMM, 1333 MT/s |
| Kapasitas maksimum | **32 GB** (menurut `dmidecode` tipe 16, 4 device) |

| Slot | Kapasitas | P/N | Vendor (kode JEDEC) |
|---|---|---|---|
| DIMM A1 | 2 GB, 1333 MT/s | `HMT325U7BFR8A-H9` | SK Hynix (`80AD`) |
| DIMM B1 | 2 GB, 1333 MT/s | `M391B5773DH0-YH9` | Samsung (`80CE`) |
| DIMM A2 | — | kosong | — |
| DIMM B2 | — | kosong | — |

**Konsekuensi:** 25 container berbagi 3,9 GB. Tekanan memori terbukti nyata (lihat §4.1).

### 3.4 Storage

Semua disk internal SATA (bukan USB), 7.200 rpm kelas surveillance/video:

| Disk | Model | Kapasitas | Jam nyala | SMART | Reallocated | Pending | Suhu | Peran |
|---|---|---|---|---|---|---|---|---|
| `sda` | WDC **WD20PURX**-64P6ZY0 | 2 TB (5.400 rpm) | **2.958 h** | PASSED | 0 | 0 | 27 °C | `/mnt/karaoke_master` (NTFS) |
| `sdb` | Seagate **ST2000VX008**-2E3164 | 2 TB (5.900 rpm) | **51.459 h** (≈5,9 th) | PASSED | 0 | 0 | 24 °C | `/`, `/var`, swap, `/srv` |
| `sdc` | Seagate **ST2000VM003**-1ET164 | 2 TB (5.900 rpm) | **36.541 h** (≈4,2 th) | PASSED | 0 | 0 | 24 °C | `/mnt/nextcloud_data` |
| `sr0` | TSSTcorp DVD±RW TS-L633J | — | — | — | — | — | — | Slim ODD |

Semua disk sehat secara SMART (0 reallocated, 0 pending, 0 offline uncorrectable) — **belum ada
tanda kegagalan fisik**, tetapi:

- **Tidak ada RAID**: `mdadm --detail --scan` tidak mengembalikan apa pun. Tidak ada ZFS/LVM mirror.
- **Kelas drive salah untuk NAS**: WD Purple (surveillance), SkyHawk (surveillance), Seagate Video
  — ketiganya **tidak punya TLER/ERC**, rawan di-*drop* dari array RAID dan tidak dijamin untuk
  beban 24/7 multi-stream.
- **`sdb` 51.459 jam** sudah melewati umur desain konsumen/NAS (5 tahun / 43.800 jam).
- Chassis R210 II hanya punya **2 bay 3,5"**, tetapi terpasang **3 disk** → satu disk berada di
  luar bay standar (area ODD), berisiko getaran dan aliran udara buruk.

### 3.5 Kapasitas & pemakaian

| Mount | Device | FS | Ukuran | Terpakai | Sisa | % |
|---|---|---|---|---|---|---|
| `/` | sdb1 | ext4 | 92 G | 25 G | 63 G | 28% |
| `/var` | sdb5 | ext4 | 37 G | 18 G | 18 G | 51% |
| `/srv` | sdb7 | ext4 | 1,7 T | 39 G | 1,7 T | 3% |
| `/mnt/nextcloud_data` | sdc1 | ext4 | 1,8 T | 516 G | 1,2 T | 30% |
| `/mnt/karaoke_master` | sda1 | **fuSEBLK / NTFS** | 1,9 T | **1,6 T** | 304 G | **84%** |
| swap | sdb6 | swap | 8,9 G | 1,7 G | 7,2 G | 19% |

Docker: 26 image (14,21 GB, 6,59 GB reclaimable), 13 volume (1,25 GB), build cache 495,6 MB.
**Total data unik saat ini ≈ 2,2 TB.** Karaoke menuju penuh (304 GB sisa).

### 3.6 Jaringan

| Interface | IP | Speed | Keterangan |
|---|---|---|---|
| `eno1` | 192.168.2.31/23 | **1000 Mb/s** | Jalur utama (LAN kantor) |
| `eno2` | 172.60.199.23/24 | **100 Mb/s** | **Degradasi** — seharusnya 1000 Mb/s |
| `docker0` | 172.17.0.1/16 | DOWN | — |
| `br-*` (3 bridge) | 172.18/172.20/172.21 | UP | Jaringan container |

NIC: **Broadcom NetXtreme II BCM5716** (2 port GbE). Tidak ada 2,5 GbE / 10 GbE / WiFi.
`eno2` di 100 Mb/s → indikasi kabel Cat5 rusak (satu pair putus) atau port switch 100 M.

Port publik terbuka: 22, 80, 443, 3478 (TURN), 5000, 8443, 8444, 8445, 8446.
Port lokal: 3001, 3307, 5001, 43741, 49374.

> Catatan BMC: iDRAC6 **Express** memakai NIC *shared* di LOM1 — tidak ada port dedicated.
> MAC `d0:67:e5:f4:0a:66` saat ini tidak terlihat di segmen mana pun (§7.2).

### 3.7 Beban kerja (25 container)

| Kelompok | Container |
|---|---|
| Nextcloud | `nextcloud_app` (35), `nextcloud_nginx`, `nextcloud_db` (MariaDB 10.11), `nextcloud_redis`, `nextcloud_cron`, `nextcloud_notify_push`, `nextcloud_collabora` (CODE 26.04), `nextcloud_talk_hpb` (AIO Talk), `nextcloud_turn` (coturn 4.7), `nextcloud_certbot` |
| Karaoke | `karaoke_backend`, `karaoke_frontend`, `karaoke_db` (Postgres 16), `karaoke_redis`, `karaoke_celery`, `karaoke_celery_beat`, `karaoke_celery_control` |
| BPF Workhub | `bpf-workhub-web`, `bpf-workhub-db` (MariaDB 10.11), `bpf-workhub-redis`, `bpf-workhub-backup` |
| Lain-lain | `bpf-calendar`, `uptime_kuma`, `chart-trader-pro` |

Proses host tambahan: `mariadbd`, `apache2`, `python3.11` (uvicorn), `dockerd`, serta **`opencode`
dan 2× Chrome** di host (±170 MB RAM di mesin 4 GB — sebaiknya dijalankan di mesin lain).

Tidak ada Jellyfin/Plex → **tidak butuh QuickSync/transcode video**; kebutuhan CPU lebih ke banyak
proses ringan + database, bukan media encoding.

Cron aktif:

```
15 6 * * *   /home/it-ef/bpf-workhub/.../daily_sync.sh
@reboot      node .../otp_supervisor.mjs
*/15 * * * * talk-hpb-check.sh
```

→ **Tidak ada job backup untuk `/mnt/nextcloud_data` maupun `/mnt/karaoke_master`.**

---

## 4. Diagnosis

### 4.1 Bottleneck #1 — RAM (paling mendesak)

| Bukti | Nilai | Arti |
|---|---|---|
| MemAvailable | 1.383 MB dari 3.911 MB | Sisa < 36% |
| Swap terpakai | 1.781 MB dari 9.167 MB | Aktif swapping |
| `mariadbd` di swap | 252 MB + 160 MB | Dua instance MariaDB terdorong keluar |
| `uvicorn` di swap | 122 MB | API workhub |
| `coolwsd` di swap | 79 MB | Collabora |
| `celery` di swap | 57 MB + 57 MB | Worker karaoke |

Beban CPU justru rendah (load 0,35 = 9% dari 4 core). Jadi kelambatan yang dirasakan pengguna
kemungkinan besar berasal dari **page fault ke disk**, bukan dari CPU. Disk yang dipakai untuk swap
adalah `sdb` — justru disk tertua (51.459 jam).

**Perbaikan:** 32 GB (4× 8 GB) DDR3 ECC UDIMM → menghapus swap sepenuhnya.

### 4.2 Bottleneck #2 — Tidak ada redundansi & tidak ada backup

- 3 filesystem tunggal, 0 mirror. Kegagalan 1 disk = kehilangan seluruh data di disk itu.
- Data karaoke 1,6 TB hanya ada di `sda` (disk termuda, 2.958 jam — masih aman, tapi NTFS/fuSEBLK).
- Data Nextcloud 516 GB hanya ada di `sdc` (36.541 jam).
- **Tidak ada salinan di mana pun.** Ini risiko bisnis, bukan risiko teknis.

### 4.3 Bottleneck #3 — Umur & kelas disk

`sdb` (51.459 jam) menampung **OS, `/var`, swap, dan `/srv`** — sekaligus disk paling tua dan paling
kritis secara sistematis. Ditambah ketiga drive bukan kelas NAS, membangun RAID di atas drive ini
bukan solusi yang benar.

### 4.4 Bottleneck #4 — Platform sudah mentok

| Keterbatasan | Dampak |
|---|---|
| BIOS **2.10.0** (2018, sudah terpasang) | Microcode Spectre/Meltdown sudah masuk, tapi platform tetap EOL dan **tanpa recovery BIOS** |
| DDR3-1333, maks 32 GB | Jalur memori lambat, tidak bisa dilanjutkan |
| Hanya 2 bay 3,5" | Tidak bisa menampung 4+ disk untuk RAID yang layak |
| Tanpa M.2/NVMe | Docker & database selalu berebut IOPS dengan HDD |
| GbE saja | Bottleneck jaringan untuk file besar (karaoke, backup) |
| 1U, fan 40 mm | Berisik, tidak cocok di ruang kerja |
| Konsumsi ±80–100 W | ±57–72 kWh/bulan ≈ Rp98–125 rb (@Rp1.700/kWh) |

Catatan jujur: penghematan listrik dengan N100 hanya ±Rp50–75 rb/bulan — **bukan** alasan utama
upgrade. Alasan utamanya adalah RAM, redundansi, dan kapasitas.

### 4.5 Bottleneck #5 — Manajemen out-of-band tidak siap

- BMC/iDRAC6 masih **1.80** (syarat CPU E3-1200 v2: ≥ 1.85).
- NIC iDRAC tidak muncul di jaringan meski kanal LAN sudah diaktifkan (§7.2) → belum bisa dipakai
  untuk flashing jarak jauh maupun pemantauan hardware.
- `racadm`/OMSA tidak terpasang; manajemen hanya bisa in-band lewat `ipmitool` (KCS).

---

## 5. Rekomendasi

### 5.1 Skenario A — Stopgap: RAM 32 GB (Rp2–3,5 juta)

| Item | Spesifikasi | Perkiraan harga |
|---|---|---|
| 4× 8 GB DDR3 **ECC UDIMM 2Rx8** PC3-12800E/10600E | Samsung `M391B1G73BH0-YH9`, SK Hynix `HMT41GU7AFR8A-PB`, Kingmax/KVR16E11/8 | Rp500.000–955.000/stick → **Rp2,0–3,8 jt** |

Penting:

- **Wajib UDIMM (unbuffered) ECC** — R210 II **tidak** menerima RDIMM/Registered.
- E3-1220 v1 secara resmi DDR3-1333; stick 1600 akan downclock otomatis (aman, dan bisa dipindah
  ke mesin lain kelak).
- ~~Update BIOS ke rilis 2.x terakhir~~ → **selesai 5-Nov-2026 (2.10.0, §7.1)**; sisa: perbaiki
  `eno2` (kabel Cat5e/port switch), pindahkan `opencode`/Chrome keluar dari host.

Hasil: swap hilang, 25 container lega. **Tetap tanpa redundansi, tanpa backup, kapasitas 84%.**

### 5.2 Skenario B — REKOMENDASI UTAMA: NAS 4-bay x86 (Rp33–37 juta)

Tetap pakai **Debian 13 + Docker** (tanpa ganti OS; image & compose jalan apa adanya).

**Pilihan 1 — paling pas: TerraMaster F4-424 Pro (±Rp16.320.000)**

| Spesifikasi | Detail |
|---|---|
| CPU | Intel Core **i3-N305**, 8C/8T, hingga 3,8 GHz, UHD Graphics |
| RAM | **32 GB DDR5-4800** (terpasang, non-upgradable — sudah lebih dari cukup) |
| Bay | 4× 3,5" hot-swap + 2× M.2 NVMe |
| Jaringan | 2× 2,5 GbE |
| Lain | HDMI, cocok untuk Debian bare-metal |

**Pilihan 2 — nilai I/O terbaik: UGREEN DXP4800 Plus (±Rp13.599.000–13.999.000)**

| Spesifikasi | Detail |
|---|---|
| CPU | Intel **Pentium Gold 8505**, 5C/6T |
| RAM | 8 GB DDR5 (bisa sampai 64 GB → tambah 1× 32 GB) |
| Bay | 4× 3,5" + 2× M.2 NVMe |
| Jaringan | **2,5 GbE + 10 GbE** |

**Pilihan 3 — hemat: TerraMaster F4-424 (±Rp9.785.000)**
N95 4C, 8 GB DDR5 (naikkan ke 16–32 GB), 2× 2,5 GbE, 2× M.2.

**Tidak direkomendasikan:** Synology DS925+ (Rp14,5–19,5 jt; Ryzen V1500B tanpa QuickSync, GbE
bawaan, DSM tidak dipakai karena sudah pakai Docker langsung) dan DS1525+ (Rp19,7–26,5 jt).

**Storage**

| Item | Pilihan | Harga |
|---|---|---|
| 4× 8 TB CMR kelas NAS | **WD Red Plus 8 TB (WD80EFZZ)** | Rp4.080.000–4.620.000/buah → **Rp16,3–18,5 jt** |
| Alternatif | Seagate IronWolf 8 TB `ST8000VN004` | Rp7.232.000–7.659.700/buah |
| Hemat | 4× 4 TB kelas NAS | ±Rp2–2,5 jt/buah (estimasi) → ±10,9 TB usable |
| Cache/OS | **2× NVMe 1 TB** | untuk OS + `/var/lib/docker` + DB |

Susunan RAIDZ1 4× 8 TB → **±21,8 TB usable** (kebutuhan sekarang 2,2 TB; lega 5+ tahun).
RAIDZ1 4× 4 TB → ±10,9 TB usable, masih cukup. **Total Skenario B ≈ Rp33–37 juta.**

### 5.3 Skenario C — Bangun sendiri, 8 bay (Rp13–16 juta + disk)

i3-14100 / i5-14500 + B760M-ITX (2× 2,5 GbE) + 32 GB DDR5 + **Jonsbo N3 (8 bay)** + PSU 500 W +
TrueNAS SCALE atau Debian. Lebih murah per bay dan paling fleksibel, tetapi tanpa garansi sistem dan
perlu rakit/tuning sendiri.

### 5.4 Skenario D — "Mentok": upgrade maksimal TANPA ganti motherboard (Rp2,6–6,5 jt tanpa disk)

Skenario ini menjawab: *sejauh mana R210 II bisa didorong bila board `09T7VV` (C202, LGA1155) tetap
dipakai?* Semua angka di bawah adalah **plafon keras platform**, bukan pilihan bebas.

| Komponen | Sekarang | Maksimum yang mungkin | Part konkret | Perkiraan biaya | Batas yang tak bisa dilewati |
|---|---|---|---|---|---|
| **BIOS** | **2.10.0 (24-Mei-2018)** ✅ di-flash 5-Nov-2026 | **2.10.0** — versi terakhir yang ada | Dell DUP `69VFP` (Linux) | Rp0 — **selesai** | Syarat CPU v2 (≥ 2.0.5) sudah terpenuhi; **tanpa dual-BIOS** — gagal flash = board mati |
| **BMC/iDRAC6** | **1.80** (Express, shared NIC) | **2.92** (terakhir, 2019) — minimum praktis 1.85 | `iDRAC6_1.85_A00_FW_IMG.exe` (`3VM7N`), `iDRAC6_2.92_A00_FW_IMG.exe` (`KPCCC`) | Rp0 | Firmware saja tidak menghidupkan NIC yang tak terhubung; tanpa upgrade, CPU v2 **tidak didukung resmi** |
| **CPU** | Xeon E3-1220 (4C/**4T**, 3,1–3,4 GHz, 80 W) | **Xeon E3-1290 v2** (4C/**8T**, 3,7 GHz, 80 W) | atau **E3-1270 v2** (4C/8T, 3,5 GHz, **69 W**) — nilai terbaik | E3-1270 v2: **Rp550 rb–880 rb** (bekas); Rp2,1 jt unit bergaransi toko | 1 socket, LGA1155; resmi hanya sampai E3-1200 **v2** (Ivy Bridge) |
| **RAM** | 3,9 GB (2×2 GB DDR3-1333) | **32 GB** (4× 8 GB DDR3-**1600** ECC UDIMM) | Samsung `M391B1G73BH0-YH9`, Hynix `HMT41GU7AFR8A-PB` | Rp2,0–3,8 jt (Rp500–955 rb/stick) | Hanya **UDIMM** (bukan RDIMM); 4 slot, 32 GB |
| **Storage internal** | 3 disk 3,5" (1 di luar bay) | **2× 3,5" di bay + 1–2 SSD SATA** di area ODD | 2× 8 TB WD Red Plus + SSD 500 GB | Rp8,2–9,2 jt + Rp0,6 jt | Chassis 1U: hanya **2 bay 3,5"**; **tidak ada M.2/NVMe boot** |
| **Ekspansi** | slot PCIe kosong | **1× PCIe x16 Gen2, half-length, maks 25 W** | HBA SATA ASM1166/JMB585 **atau** NIC 2,5 GbE i226 — **pilih satu** | Rp250–600 rb | Satu slot saja; tidak bisa HBA + NIC sekaligus |
| **Jaringan** | 1× GbE (eno1), 1× 100 Mb (eno2) | tetap **2× GbE** (BCM5716 onboard) | — | Rp0 | Tanpa 2,5/10 GbE kecuali slot PCIe dikorbankan |
| **Manajemen** | iDRAC6 Express (Matrox G200eW/WPCM450) | sama, + firmware terbaru | — | Rp0 | Generasi iDRAC6 (Java/legacy) |

**Total jalur mentok:** CPU + RAM = **Rp2,6–5,9 jt** (tanpa disk) — atau **Rp11,4–15,7 jt** bila
sekalian 2× 8 TB RAID1 + SSD.

**Perolehan realistis:**

- Multi-thread naik **+60–80%** (4 thread → 8 thread, IPC Ivy Bridge, DDR3-1600).
- **Swap hilang total** (32 GB) — perbaikan terbesar dan sama persis dengan Skenario B.
- Redundansi **RAID1 hanya 2 disk**; kapasitas usable 8 TB (vs 21,8 TB RAIDZ1 di Skenario B).

**Yang tetap tidak bisa dikejar, sekeras apa pun diupgrade:**

| Keterbatasan | Konsekuensi nyata |
|---|---|
| Maks 2 bay 3,5" | RAIDZ1 4 disk mustahil; maksimum RAID1 |
| Tanpa NVMe boot | Docker/DB selalu di HDD atau SATA SSD |
| 1 slot PCIe 25 W | HBA **atau** NIC 2,5 GbE, tidak keduanya |
| DDR3-1600 | Bandwidth & efisiensi daya era 2012 |
| BIOS 2.10.0 (2018) | Spectre/Meltdown sudah dipatch, tapi tetap EOL |
| 80 W TDP, fan 40 mm | Konsumsi & kebisingan tidak turun |

**Putusan:** Skenario D **masuk akal hanya** sebagai jembatan bila anggaran < Rp7 jt dan pembelian
disk ditunda — dan sudah 40–45% dari biaya Skenario B tanpa keunggulan platform apa pun. Bila R210 II
dipakai ulang sebagai **server backup** (§6 langkah 5), cukup RAM 32 GB saja; CPU v2 tidak diperlukan
karena beban backup ringan.

> ✅ **Update 5-Nov-2026:** langkah BIOS sudah dieksekusi — 1.3.1 → 2.8.0 → 2.10.0 lewat DUP Linux,
> dua reboot terkontrol, board kembali normal (§7.1). Risiko yang sama tetap berlaku untuk setiap
> flash berikutnya: board ini **tidak punya BIOS cadangan** (`BIOS recovery after bad flash: not
> supported`, *R210 II Technical Guide* §9). Siapkan UPS dan catat Service Tag `9B6HC2S`.

### 5.5 Perbandingan singkat

| | Biaya | RAM | Redundansi | Kapasitas | Umur pakai |
|---|---|---|---|---|---|
| A — RAM 32 GB | Rp2–3,8 jt | 32 GB | Tidak ada | 84% penuh | 1–2 th |
| B — NAS 4-bay | Rp33–37 jt | 32 GB | RAIDZ1 | ±21,8 TB | 5+ th |
| C — Rakit 8 bay | Rp13–16 jt + disk | 32 GB | RAIDZ1/Z2 | 8+ bay | 5+ th |
| D — Mentok | Rp2,6–15,7 jt | 32 GB | RAID1 | 8 TB usable | 2–3 th |

---

## 6. Rencana Migrasi (urutan wajib)

1. **Backup sekarang, sebelum beli hardware.** Salin `/srv`, `/mnt/nextcloud_data`,
   `/mnt/karaoke_master`, dan `/home/it-ef` (compose + volume + `.env`) ke HDD eksternal.
   Verifikasi dengan checksum. Ini menutup risiko terbesar.
2. Siapkan box baru: Debian 13 minimal, Docker + compose plugin, user `it-ef`, SSH key.
3. Salin stack (`docker-compose.yml`, volume, config Nextcloud/Collabora/Talk, DB dump
   `mariadb-dump`/`pg_dump`), nyalakan bertahap; uji Nextcloud, Talk HPB, karaoke.
4. Jadwalkan downtime singkat: matikan container di R210 II → sinkronkan delta terakhir →
   arahkan DNS/IP 192.168.2.31 ke box baru → uji ulang port 80/443/3478/8443-8446.
5. **Jadikan R210 II sebagai server backup** (restic/borg target, 4× 4 TB) — jangan dibuang;
   ini yang menutup celah "tidak ada backup" secara permanen.
6. Setelah stabil: konversi `/mnt/karaoke_master` dari **NTFS → ext4/XFS** (fuSEBLK lambat dan
   tidak menyimpan permission dengan benar), pasang **UPS**, dan aktifkan monitoring disk
   (`smartd` + notifikasi Uptime-Kuma).

---

## 7. Log Pelaksanaan

### 7.1 BIOS 1.3.1 → 2.10.0 (5 November 2026)

**Target:** Dell `69VFP` — *PowerEdge R210 II BIOS 2.10.0*, rilis 16 Jul 2018, status **Urgent /
Latest / Recommended** (CVE-2018-3639 & CVE-2018-3640, microcode E3-1200 v2 E1 `0x20`, E3-1200 D2
`0x2E`).

#### Hasil

| Item | Sebelum | Sesudah |
|---|---|---|
| BIOS | 1.3.1 (10-11-2011) | **2.10.0 (24-05-2018)** |
| Microcode CPU (E3-1220, D2 stepping) | patch lama | **`0x2f`** |
| Reboot | uptime 5 hari 7 jam | 2× reboot terkontrol (±2–4 menit) |
| Container | 25 berjalan | 25 berjalan, semua `healthy` |
| Lock DUP | ada sisa `/var/lock/.spsetup` | bersih, tidak ada proses menggantung |
| Layanan | — | `:443` → 302, `:8443` → 200, `:80` → 301 |

```
$ sudo dmidecode -s bios-version        → 2.10.0
$ sudo dmidecode -s bios-release-date   → 05/24/2018
$ sudo dmidecode -s system-product-name → PowerEdge R210 II
$ grep -m1 microcode /proc/cpuinfo      → 0x2f
```

#### Integritas paket

Diunduh dari CDN Dell asli, checksum diverifikasi **dua kali** (lokal + di NAS) dan sama persis
dengan nilai di halaman driver:

| Paket | Driver ID | SHA-256 |
|---|---|---|
| `R210-II_BIOS_69VFP_LN_2.10.0.BIN` | `69VFP` | `2a3affecba3cd10fcfc91d181688f892a8f2efc339393b4f6489639e9d9f6d10` |
| `R210-II_BIOS_VXJ66_LN_2.8.0.BIN` | `VXJ66` | `6ad0cc13a0115c0db399c1aa99a355a8eb09601bd65498f1470bd906b8b8d9f5` |

Keduanya disimpan di `~/bios/` pada NAS beserta `.sign`. Tarik ulang dengan `curl` biasa akan kena
blokir Akamai (403); sertakan header browser lengkap (`-A`, `Accept`, `Sec-Fetch-*`) atau unduh lewat
browser.

#### Mengapa bertahap lewat 2.8.0, bukan 2.1.2

- Release notes Dell (2.4.3 & 2.8.0) menyebut prasyarat "harus lewat 2.1.2" **hanya untuk jalur USC**:
  *"In order to flash to BIOS version 2.2.3 or newer using USC, you must first flash to BIOS version
  2.1.2 … Other BIOS update methods do not have this prerequisite."* → DUP Linux tidak wajib lewat 2.1.2.
- Walau begitu, paket 2.1.2 hanya tersedia sebagai **`LN32` (32-bit)** dan menuntut `rpm` + loader
  i386 — tidak ada di Debian 13 dan sengaja **tidak** dipasang di server produksi.
- Jembatan yang dipakai: **2.8.0 (`VXJ66`, 64-bit, 2014)** — terekstrak bersih dan lolos validasi DUP
  di Debian 13.

#### Prosedur yang dipakai

```bash
# dari ~/bios di NAS, sesi harus punya TTY (ssh -tt)
sudo ./R210-II_BIOS_VXJ66_LN_2.8.0.BIN -q     # 1.3.1 → 2.8.0, FLASH_RC=2
sudo reboot                                    # verifikasi: BIOS 2.8.0
sudo ./R210-II_BIOS_69VFP_LN_2.10.0.BIN -q     # 2.8.0 → 2.10.0, FLASH_RC=2
sudo reboot                                    # verifikasi: BIOS 2.10.0
```

Catatan operasional:

- DUP generasi 11G akan `exec xterm` bila dijalankan tanpa TTY — pakai `ssh -tt`.
- `FLASH_RC=2` = **sukses, perlu restart**; BIOS baru aktif setelah reboot.
- `-q` tanpa `-r` = flash tanpa reboot otomatis, sehingga downtime bisa dijadwalkan terpisah.
- Bila DUP terhenti di tengah jalan, hapus `/var/lock/.spsetup` sebelum mengulang.
- Flash butuh **memori fisik bebas** ≥ ukuran image (8 MB) — saat eksekusi tersedia ±1,5 GB.

### 7.2 BMC/iDRAC6 — pemeriksaan & persiapan upgrade ke ≥ 1.85 (5 November 2026)

**Sasaran:** BMC **1.80 → 1.85 → 2.92**. Untuk memasang Xeon E3-1200 **v2**, Dell mensyaratkan
BIOS ≥ 2.0.5 (✅ 2.10.0) **dan BMC ≥ 1.85** (belum). Jalur dipilih **bertahap** karena rilis Dell
hanya mendokumentasikan upgrade dari versi tepat sebelumnya, dan unit ini memakai eMMC.

**Status akhir hari ini: firmware BELUM di-flash.** Pemeriksaan dan persiapan selesai; flashing
menunggu akses konsol karena NIC iDRAC tidak hidup.

#### a. Temuan firmware & paket

| Item | Nilai |
|---|---|
| Versi terpasang | **1.80** — `ipmitool mc info`: Device ID 32, Dell Inc., IPMI 2.0 |
| Target minimum | **1.85** (driver Dell `3VM7N`, 21-Feb-2012) |
| Target akhir | **2.92** (driver `KPCCC`, 31-Jan-2019) |
| Metode | Upload `firmimg.d6` via web UI iDRAC (bukan DUP `LN32` 32-bit yang butuh i386 + rpm) |
| Berkas siap di NAS | `/home/it-ef/idrac/` (lihat §10.3) |

Checksum terverifikasi (exe dibandingkan dengan halaman driver Dell, lalu `firmimg.d6` hasil ekstraksi
dihitung ulang di NAS):

| Berkas | Ukuran | SHA-256 |
|---|---|---|
| `firmimg_1.85.d6` | 55.020.600 B | `64a6620b46cca180e1f9425c7f239200d3f3e6a3c813e5982d00a4926a43d347` |
| `firmimg_2.92.d6` | 56.831.032 B | `f3c0ef5f2cf522841922334dca9b3fe92066d9dca621984c6e213aa151a38093` |

Catatan teknis: `iDRAC6_*_FW_IMG.exe` adalah PE dengan payload ZIP; `firmimg.d6` diambil dari offset
`PK\x03\x04` pertama. Firmware 1.80 hanya mendukung TLS 1.0, sehingga akses web butuh
`curl --ciphers 'DEFAULT@SECLEVEL=0' --tls-max 1.0` (OpenSSL 3 menolak `--tlsv1.0`).

#### b. Yang dikerjakan

1. `ipmitool` dipasang di NAS; modul `ipmi_si`/`ipmi_devintf` dimuat, `/dev/ipmi0` tersedia → BMC
   terbaca in-band.
2. Ditemukan **kanal LAN BMC dalam keadaan `Access Mode: disabled`** → diaktifkan:
   `ipmitool lan set 1 access on` → kini `always available` (bertahan setelah `mc reset cold`).
3. Mode NIC diperiksa: `delloem lan get` → `shared`; `delloem lan set dedicated` dijawab
   *"Command not supported in present state"* → **iDRAC6 Express**, tidak ada port dedicated.
   Satu-satunya jalur adalah NIC shared di LOM1 (`eno1`).
4. Alamat diuji di dua segmen, mode DHCP maupun statis, dengan `mc reset cold` di antaranya.

#### c. Hasil uji — semuanya negatif

| Uji | Hasil |
|---|---|
| Ping/ARP `192.168.2.27` via `eno1` (LAN, link 1 Gb) | 100% loss, ARP `INCOMPLETE` |
| Statis `172.60.199.27/24` via `eno2` (uji apakah BMC nyangkut di LOM2) | 100% loss |
| HTTP/HTTPS (termasuk TLS 1.0 + `SECLEVEL=0`) | timeout, port tertutup |
| `ipmitool lan set 1 arp respond/generate` | `rc=1` — tidak didukung firmware 1.80 |
| `tcpdump -i eno1 ether host d0:67:e5:f4:0a:66`, 45 detik setelah reset | **0 paket** |

**Kesimpulan:** masalahnya bukan IP, routing, atau VLAN — **NIC BMC tidak mengirim satu frame pun**.
Kandidat penyebab yang tersisa: kartu iDRAC6 Express tidak terpasang, opsi LAN dimatikan di BIOS
(Ctrl-E), atau sideband NC-SI LOM1 tidak berjalan. Semuanya butuh akses konsol.

#### d. Kondisi yang ditinggalkan

| Setelan | Nilai akhir |
|---|---|
| Kanal LAN | `always available` (perubahan disengaja, dibutuhkan untuk OOB) |
| NIC selection | `shared` (seperti semula) |
| IP | DHCP `192.168.2.27/23`, gw `192.168.2.1` (seperti semula) |
| Firmware | tetap **1.80** |

Dampak ke produksi: **nol**. `mc reset cold` hanya mereset iDRAC, bukan host — uptime host tetap,
25 container berjalan, 0 `unhealthy`.

### 7.3 Rencana lanjutan (6 November 2026)

**Langkah 1 — konsol, ±2 menit.** Reboot, tekan **Ctrl-E** saat POST masuk ke *iDRAC6 configuration*:

1. **LAN** = On/Enabled.
2. **NIC Selection** = Shared; bila LOM1 tetap bisu, coba *Shared with Failover LOM2* (`eno2` aktif).
3. Pastikan kartu **iDRAC6 Express** benar-benar terpasang di slotnya — tanpa kartu ini web UI dan
   IPMI-over-LAN tidak ada, walau IPMI in-band tetap jalan.
4. Bila tetap mati: *Reset to Defaults* dari Ctrl-E, konfigurasi ulang, lalu `ipmitool mc reset cold`.

**Langkah 2 — flashing (setelah web UI hidup).**

1. Buka `https://192.168.2.27` (browser lama/IE mode atau `curl` TLS 1.0), login `root`.
2. *iDRAC Settings → Update* → unggah `firmimg_1.85.d6` → tunggu reboot iDRAC (±5–10 menit, host
   tidak reboot).
3. Verifikasi: `sudo ipmitool mc info | grep Firmware` → **1.85**.
4. Ulangi untuk `firmimg_2.92.d6` → verifikasi **2.92**.
5. Jangan pernah downgrade di bawah 1.80 (unit eMMC); jangan cabut daya saat flashing.

**Langkah 3 — bila NIC tetap tidak bisa dihidupkan.** Upgrade tetap mungkin tanpa jaringan:

- DUP `ESM_Firmware_*_LN32_*` (32-bit) — perlu `rpm` + loader i386 di NAS, atau
- media DOS/USB (jalur paling aman, butuh akses fisik + monitor).

**Langkah 4 — penutup.** Catat hasil akhir di §7.2 dan perbarui tabel status §1.3.

---

## 8. Daftar Tindakan Berprioritas

| # | Tindakan | Biaya | Dampak | Status |
|---|---|---|---|---|
| 1 | Backup Nextcloud + karaoke ke HDD eksternal | Rp0 (pakai disk yang ada) | 🔴 Kritis | ⏳ Belum |
| 2 | Naikkan RAM ke 32 GB (4× 8 GB ECC UDIMM) | Rp2–3,8 jt | 🔴 Menghapus swap | ⏳ Belum |
| 3 | Perbaiki link `eno2` 100 Mb/s | Rp0–50 rb (kabel) | 🟡 Throughput | ⏳ Belum |
| 4 | Beli NAS 4-bay + 4× 8 TB RAIDZ1 + 2 NVMe | Rp33–37 jt | 🔴 Redundansi + kapasitas | ⏳ Belum |
| 5 | Migrasi data & jadikan R210 II backup server | Rp0 | 🔴 Menutup celah backup | ⏳ Belum |
| 6 | Konversi karaoke NTFS → ext4/XFS, pasang UPS | Rp0–1,5 jt | 🟡 Keandalan | ⏳ Belum |
| 7 | Pindahkan `opencode`/Chrome dari host NAS | Rp0 | 🟡 ±170 MB RAM | ⏳ Belum |
| 8 | ~~Upgrade BIOS 1.3.1 → 2.10.0~~ | Rp0 | ✅ Selesai 5-Nov-2026 | ✅ **Selesai** |
| 9 | Upgrade BMC/iDRAC6 1.80 → 1.85 → 2.92 | Rp0 | 🟡 Syarat CPU v2 + OOB | 🟡 **Berjalan** (§7.2) |

---

## 9. Risiko, Catatan & Asumsi

- Harga adalah **listing pasar Indonesia (Tokopedia/Blibli/Lazada/DimensiData), November 2026** dan
  berfluktuasi; konfirmasi ulang sebelum pembelian.
- Harga komponen rakitan Skenario C dan HDD 4 TB bersifat **estimasi**.
- Kapasitas RAM maksimum 32 GB mengikuti `dmidecode` tipe 16 (4 device); sebagian forum melaporkan
  R210 II bisa 32 GB dengan 4× 8 GB — tidak diuji di mesin ini.
- Dukungan CPU E3-1200 **v2** (Ivy Bridge) mengacu pada *Dell R210 II Technical Guide* serta halaman
  driver Dell; **belum diuji pada unit ini** (CPU masih E3-1220 v1).
- Audit awal (3-Nov-2026) bersifat **read-only**. Perubahan susulan yang dieksekusi:
  BIOS → 2.10.0 (§7.1) dan pengaturan kanal LAN iDRAC (§7.2) — tidak ada data pengguna maupun
  konfigurasi layanan yang diubah.
- Flash BIOS/BMC **tanpa cadangan**: board R210 II tidak mendukung recovery setelah flash gagal.
  Siapkan UPS; hentikan pekerjaan bila tegangan tidak stabil.
- `ipmitool sel list` pada firmware 1.80 bisa menggantung → selalu bungkus dengan `timeout`.

---

## 10. Lampiran

### 10.1 Perintah audit yang digunakan

```bash
# Identitas & platform
hostname; uname -a; cat /etc/os-release; uptime
sudo dmidecode -t 0,1,2,3,16,17,39
lscpu; lspci; lsusb

# Memori & tekanan
free -m; grep MemTotal /proc/meminfo
cat /proc/pressure/memory
vmstat 1 3
for f in /proc/*/status; do awk '/VmSwap|^Name/{print $2}' $f; done

# Storage
lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT,ROTA,MODEL,SERIAL
lsblk -S -o NAME,HCTL,TRAN,MODEL,SIZE
df -hT
sudo mdadm --detail --scan
for d in sda sdb sdc; do sudo smartctl -H -A -i /dev/$d; done

# Jaringan
ip -br a
cat /sys/class/net/eno1/speed; cat /sys/class/net/eno2/speed
sudo ss -tlnp

# Beban kerja
docker ps --format "{{.Names}}\t{{.Image}}\t{{.Status}}"
sudo docker system df
ps aux --sort=-%mem | head -8
crontab -l

# BMC / iDRAC6 (in-band)
sudo ipmitool mc info
sudo ipmitool lan print 1
sudo ipmitool channel info 1
sudo ipmitool delloem lan get
sudo ipmitool fru print
sudo tcpdump -i eno1 -n -e ether host d0:67:e5:f4:0a:66
```

### 10.2 Ringkasan checksum

| Berkas | Driver ID | SHA-256 |
|---|---|---|
| `R210-II_BIOS_69VFP_LN_2.10.0.BIN` | `69VFP` | `2a3affecba3cd10fcfc91d181688f892a8f2efc339393b4f6489639e9d9f6d10` |
| `R210-II_BIOS_VXJ66_LN_2.8.0.BIN` | `VXJ66` | `6ad0cc13a0115c0db399c1aa99a355a8eb09601bd65498f1470bd906b8b8d9f5` |
| `firmimg_1.85.d6` | `3VM7N` | `64a6620b46cca180e1f9425c7f239200d3f3e6a3c813e5982d00a4926a43d347` |
| `firmimg_2.92.d6` | `KPCCC` | `f3c0ef5f2cf522841922334dca9b3fe92066d9dca621984c6e213aa151a38093` |

### 10.3 Berkas di NAS

| Path | Isi |
|---|---|
| `~/bios/` | DUP BIOS 2.8.0 & 2.10.0 + `.sign` |
| `/home/it-ef/idrac/firmimg_1.85.d6` | Firmware iDRAC6 1.85 (untuk web UI) |
| `/home/it-ef/idrac/firmimg_2.92.d6` | Firmware iDRAC6 2.92 |
| `/home/it-ef/idrac/iDRAC6_*_FW_IMG.exe` | Paket asli Dell + release notes |
| `/home/it-ef/idrac/README-bmc-upgrade.md` | Runbook prosedur web/RACADM/DOS, risiko, hasil diagnosis jaringan |

### 10.4 Riwayat revisi

| Versi | Tanggal | Perubahan |
|---|---|---|
| v1 | 3-Nov-2026 | Audit hardware & rekomendasi awal |
| v2 | 5-Nov-2026 | Tambah bagian log upgrade BIOS 1.3.1 → 2.10.0 |
| v3 | 5-Nov-2026 | Restrukturisasi dokumen (10 bagian, daftar isi, tabel status); tambah §7.2–7.3 BMC/iDRAC6; perbarui inventaris, diagnosis OOB, tabel tindakan, lampiran |
