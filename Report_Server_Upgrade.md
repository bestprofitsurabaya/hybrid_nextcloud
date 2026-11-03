# Laporan Audit Hardware & Rekomendasi Upgrade NAS BPF

**Tanggal audit:** 3 November 2026, 16:29–16:5x WIB
**Objek:** `NAS` — 192.168.2.31:22 (path kantor), alt `nasbpfsby.duckdns.org:2211`
**Metode:** SSH langsung ke host, pembacaan `dmidecode`, `/proc`, `smartctl`, `docker`, `ip`, `lsscsi`
**Status:** Server produksi aktif, uptime 3 hari 7 jam, 24 container berjalan

---

## 0. Ringkasan Eksekutif

| Aspek | Kondisi | Status |
|---|---|---|
| Platform | Dell PowerEdge R210 II, BIOS 2011 | 🔴 Habis masa, tidak bisa dikembangkan |
| CPU | Xeon E3-1220 4C/4T (2011) | 🟡 Cukup untuk beban sekarang, tapi tanpa HT |
| RAM | 3,9 GB untuk 24 container | 🔴 **Bottleneck utama** — swap terpakai 1,78 GB |
| Storage | 3 disk tunggal, **tanpa RAID** | 🔴 **Nol redundansi** |
| Umur disk | 1 disk 5,9 tahun; 1 disk 4,2 tahun | 🔴 Melewati/akan melewati umur desain 5 tahun |
| Kelas disk | Semua surveillance/video, bukan NAS | 🔴 Tidak layak RAID (tanpa TLER/ERC) |
| Backup | Tidak ada untuk Nextcloud & karaoke | 🔴 **Risiko terbesar** |
| Jaringan | 1× GbE aktif, 1× degradasi ke 100 M | 🟡 Butuh perbaikan kabel/port |
| Kapasitas | Karaoke 84% penuh (1,6 T dari 1,9 T) | 🟡 Butuh tambahan ruang |

**Kesimpulan:** hanya **RAM** yang layak di-upgrade di dalam R210 II. Sisanya sudah mentok secara
platform (DDR3, 2 bay, tanpa NVMe, tanpa 2,5 GbE, BIOS 2011). Rekomendasi utama: pindah ke
**NAS 4-bay x86** (TerraMaster F4-424 Pro atau UGREEN DXP4800 Plus) dengan **Debian 13 + Docker**
yang sudah dipakai sekarang, ditambah **4× 8 TB RAIDZ1**. Anggaran ±**Rp33–37 juta**.
**Sebelum membeli apa pun: buat backup dulu** — saat ini tidak ada salinan data sama sekali.

---

## 1. Inventaris Hardware (terverifikasi)

### 1.1 Sistem & Identitas

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
| Chassis | Dell PowerEdge R210 II |
| BIOS | **Versi 1.3.1, rilis 10 November 2011** (belum pernah di-update) |

### 1.2 Prosesor

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

Catatan: E3-1220 adalah seri paling bawah E3-1200 v1 — tanpa HT dan tanpa GPU. Setara
skor multi-core ±4.300 (PassMark), sudah di bawah N100/N95 modern.

### 1.3 Memori

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

Modul terpasang:

| Slot | Kapasitas | P/N | Vendor (kode JEDEC) |
|---|---|---|---|
| DIMM A1 | 2 GB, 1333 MT/s | `HMT325U7BFR8A-H9` | SK Hynix (`80AD`) |
| DIMM B1 | 2 GB, 1333 MT/s | `M391B5773DH0-YH9` | Samsung (`80CE`) |
| DIMM A2 | — | kosong | — |
| DIMM B2 | — | kosong | — |

**Konsekuensi:** 24 container berbagi 3,9 GB. Tekanan memori terbukti nyata (lihat §2.1).

### 1.4 Storage

Semua disk internal SATA (bukan USB), 7.200 rpm kelas surveillance/video:

| Disk | Model | Kapasitas | Jam nyala | SMART | Reallocated | Pending | Suhu | Peran |
|---|---|---|---|---|---|---|---|---|
| `sda` | WDC **WD20PURX**-64P6ZY0 | 2 TB (5.400 rpm) | **2.958 h** | PASSED | 0 | 0 | 27 °C | `/mnt/karaoke_master` (NTFS) |
| `sdb` | Seagate **ST2000VX008**-2E3164 | 2 TB (5.900 rpm) | **51.459 h** (≈5,9 th) | PASSED | 0 | 0 | 24 °C | `/`, `/var`, swap, `/srv` |
| `sdc` | Seagate **ST2000VM003**-1ET164 | 2 TB (5.900 rpm) | **36.541 h** (≈4,2 th) | PASSED | 0 | 0 | 24 °C | `/mnt/nextcloud_data` |
| `sr0` | TSSTcorp DVD±RW TS-L633J | — | — | — | — | — | — | Slim ODD |

Semua disk sehat secara SMART (0 reallocated, 0 pending, 0 offline uncorrectable) — jadi
**belum ada tanda kegagalan fisik**, tetapi:

- **Tidak ada RAID**: `mdadm --detail --scan` tidak mengembalikan apa pun. Tidak ada ZFS/LVM mirror.
- **Kelas drive salah untuk NAS**: WD Purple (surveillance), SkyHawk (surveillance), Seagate Video
  — ketiganya **tidak punya TLER/ERC**, sehingga rawan di-*drop* dari array RAID dan tidak
  dijamin untuk beban 24/7 multi-stream.
- **`sdb` 51.459 jam** sudah melewati umur desain konsumen/NAS (5 tahun / 43.800 jam).
- Chassis R210 II hanya punya **2 bay 3,5"**, tetapi terpasang **3 disk** → satu disk berada di luar
  bay standar (area ODD), berisiko getaran dan aliran udara buruk.

### 1.5 Kapasitas & Pemakaian

| Mount | Device | FS | Ukuran | Terpakai | Sisa | % |
|---|---|---|---|---|---|---|
| `/` | sdb1 | ext4 | 92 G | 25 G | 63 G | 28% |
| `/var` | sdb5 | ext4 | 37 G | 18 G | 18 G | 51% |
| `/srv` | sdb7 | ext4 | 1,7 T | 39 G | 1,7 T | 3% |
| `/mnt/nextcloud_data` | sdc1 | ext4 | 1,8 T | 516 G | 1,2 T | 30% |
| `/mnt/karaoke_master` | sda1 | **fuSEBLK / NTFS** | 1,9 T | **1,6 T** | 304 G | **84%** |
| swap | sdb6 | swap | 8,9 G | 1,7 G | 7,2 G | 19% |

Docker: 26 image (14,21 GB, 6,59 GB reclaimable), 24 container, 13 volume (1,25 GB),
build cache 495,6 MB.

**Total data unik saat ini ≈ 2,2 TB.** Karaoke menuju penuh (304 GB sisa).

### 1.6 Jaringan

| Interface | IP | Speed | Keterangan |
|---|---|---|---|
| `eno1` | 192.168.2.31/23 | **1000 Mb/s** | Jalur utama (LAN kantor) |
| `eno2` | 172.60.199.23/24 | **100 Mb/s** | **Degradasi** — seharusnya 1000 Mb/s |
| `docker0` | 172.17.0.1/16 | DOWN | — |
| `br-*` (3 bridge) | 172.18/172.20/172.21 | UP | Jaringan container |

NIC: **Broadcom NetXtreme II BCM5716** (2 port GbE). Tidak ada 2,5 GbE / 10 GbE / WiFi.
`eno2` di 100 Mb/s → indikasi kabel Cat5 rusak (satu pair putus) atau port switch 100 M.

Port publik yang terbuka: 22, 80, 443, 3478 (TURN), 5000, 8443, 8444, 8445, 8446.
Port lokal: 3001, 3307, 5001, 43741, 49374.

### 1.7 Beban Kerja (24 container)

| Kelompok | Container |
|---|---|
| Nextcloud | `nextcloud_app` (35), `nextcloud_nginx`, `nextcloud_db` (MariaDB 10.11), `nextcloud_redis`, `nextcloud_cron`, `nextcloud_notify_push`, `nextcloud_collabora` (CODE 26.04), `nextcloud_talk_hpb` (AIO Talk), `nextcloud_turn` (coturn 4.7), `nextcloud_certbot` |
| Karaoke | `karaoke_backend`, `karaoke_frontend`, `karaoke_db` (Postgres 16), `karaoke_redis`, `karaoke_celery`, `karaoke_celery_beat`, `karaoke_celery_control` |
| BPF Workhub | `bpf-workhub-web`, `bpf-workhub-db` (MariaDB 10.11), `bpf-workhub-redis`, `bpf-workhub-backup` |
| Lain-lain | `bpf-calendar`, `uptime_kuma`, `chart-trader-pro` |

Proses host tambahan: `mariadbd`, `apache2`, `python3.11` (uvicorn), `dockerd`,
serta **`opencode` dan 2× Chrome** yang berjalan di host (memakan ±170 MB RAM di mesin 4 GB —
sebaiknya dijalankan di mesin lain).

Tidak ada Jellyfin/Plex → **tidak butuh QuickSync/transcode video**; kebutuhan CPU lebih ke
banyak proses ringan + database, bukan media encoding.

Cron aktif:
```
15 6 * * *   /home/it-ef/bpf-workhub/.../daily_sync.sh
@reboot      node .../otp_supervisor.mjs
*/15 * * * * talk-hpb-check.sh
```
→ **Tidak ada job backup untuk `/mnt/nextcloud_data` maupun `/mnt/karaoke_master`.**

---

## 2. Diagnosis

### 2.1 Bottleneck #1 — RAM (paling mendesak)

Bukti objektif:

| Bukti | Nilai | Arti |
|---|---|---|
| MemAvailable | 1.383 MB dari 3.911 MB | Sisa < 36% |
| Swap terpakai | 1.781 MB dari 9.167 MB | Aktif swapping |
| `mariadbd` di swap | 252 MB + 160 MB | Dua instance MariaDB terdorong keluar |
| `uvicorn` di swap | 122 MB | API workhub |
| `coolwsd` di swap | 79 MB | Collabora |
| `celery` di swap | 57 MB + 57 MB | Worker karaoke |

Beban CPU justru rendah (load 0,35 = 9% dari 4 core). Jadi kelambatan yang dirasakan pengguna
kemungkinan besar berasal dari **page fault ke disk**, bukan dari CPU. Disk yang dipakai untuk
swap adalah `sdb` — yang justru disk tertua (51.459 jam).

**Perbaikan:** 32 GB (4× 8 GB) DDR3 ECC UDIMM → menghapus swap sepenuhnya.

### 2.2 Bottleneck #2 — Tidak ada redundansi & tidak ada backup

- 3 filesystem tunggal, 0 mirror. Kegagalan 1 disk = kehilangan seluruh data di disk itu.
- Data karaoke 1,6 TB hanya ada di `sda` (disk termuda, 2.958 jam — masih aman, tapi NTFS/fuSEBLK).
- Data Nextcloud 516 GB hanya ada di `sdc` (36.541 jam).
- **Tidak ada salinan di mana pun.** Ini risiko bisnis, bukan risiko teknis.

### 2.3 Bottleneck #3 — Umur & kelas disk

`sdb` (51.459 jam) menampung **OS, `/var`, swap, dan `/srv`**. Ini sekaligus disk paling tua
dan paling kritis secara sistematis. Ditambah ketiga drive bukan kelas NAS, maka membangun RAID
di atas drive ini bukan solusi yang benar.

### 2.4 Bottleneck #4 — Platform sudah mentok

| Keterbatasan | Dampak |
|---|---|
| BIOS 1.3.1 (2011) | Tanpa microcode keamanan modern; upgrade CPU v2 butuh update BIOS |
| DDR3-1333, maks 32 GB | Jalur memori lambat, tidak bisa dilanjutkan |
| Hanya 2 bay 3,5" | Tidak bisa menampung 4+ disk untuk RAID yang layak |
| Tanpa M.2/NVMe | Docker & database selalu berebut IOPS dengan HDD |
| GbE saja | Bottleneck jaringan untuk file besar (karaoke, backup) |
| 1U, fan 40 mm | Berisik, tidak cocok di ruang kerja |
| Konsumsi ±80–100 W | ±57–72 kWh/bulan ≈ Rp98–125 rb (@Rp1.700/kWh) |

Catatan jujur: penghematan listrik dengan N100 hanya ±Rp50–75 rb/bulan — **bukan** alasan
utama upgrade. Alasan utamanya adalah RAM, redundansi, dan kapasitas.

---

## 3. Rekomendasi

### Skenario A — Stopgap: RAM 32 GB (Rp2–3,5 juta)

| Item | Spesifikasi | Perkiraan harga |
|---|---|---|
| 4× 8 GB DDR3 **ECC UDIMM 2Rx8** PC3-12800E/10600E | Samsung `M391B1G73BH0-YH9`, SK Hynix `HMT41GU7AFR8A-PB`, Kingmax/KVR16E11/8 | Rp500.000–955.000/stick → **Rp2,0–3,8 jt** |

Penting:
- **Wajib UDIMM (unbuffered) ECC** — R210 II **tidak** menerima RDIMM/Registered.
- E3-1220 v1 secara resmi DDR3-1333; stick 1600 akan downclock otomatis (aman, dan bisa
  dipindah ke mesin lain kelak).
- Sekalian: update BIOS ke rilis 2.x terakhir, perbaiki `eno2` (kabel Cat5e/port switch),
  pindahkan `opencode`/Chrome keluar dari host.

Hasil: swap hilang, 24 container lega. **Tetap tanpa redundansi, tanpa backup, kapasitas 84%.**

### Skenario B — REKOMENDASI UTAMA: NAS 4-bay x86 (Rp33–37 juta)

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

**Tidak direkomendasikan:** Synology DS925+ (Rp14,5–19,5 jt; Ryzen V1500B tanpa QuickSync,
GbE bawaan, DSM tidak dipakai karena sudah pakai Docker langsung) dan DS1525+ (Rp19,7–26,5 jt).

**Storage**

| Item | Pilihan | Harga |
|---|---|---|
| 4× 8 TB CMR kelas NAS | **WD Red Plus 8 TB (WD80EFZZ)** | Rp4.080.000–4.620.000/buah → **Rp16,3–18,5 jt** |
| Alternatif | Seagate IronWolf 8 TB `ST8000VN004` | Rp7.232.000–7.659.700/buah |
| Hemat | 4× 4 TB kelas NAS | ±Rp2–2,5 jt/buah (estimasi) → ±10,9 TB usable |
| Cache/OS | **2× NVMe 1 TB** | untuk OS + `/var/lib/docker` + DB |

Susunan RAIDZ1 4× 8 TB → **±21,8 TB usable** (kebutuhan sekarang 2,2 TB; lega 5+ tahun).
RAIDZ1 4× 4 TB → ±10,9 TB usable, masih cukup.

**Total Skenario B ≈ Rp33–37 juta** (unit + 4 HDD + 2 NVMe).

### Skenario C — Bangun sendiri, 8 bay (Rp13–16 juta + disk)

i3-14100 / i5-14500 + B760M-ITX (2× 2,5 GbE) + 32 GB DDR5 + **Jonsbo N3 (8 bay)** + PSU 500 W
+ TrueNAS SCALE atau Debian. Lebih murah per bay dan paling fleksibel, tetapi tanpa garansi
sistem dan perlu rakit/tuning sendiri.

---

### Skenario D — "Mentok": upgrade maksimal TANPA ganti motherboard (Rp2,6–6,5 jt tanpa disk)

Skenario ini menjawab: *sejauh mana R210 II bisa didorong bila board `09T7VV` (C202, LGA1155)
tetap dipakai?* Semua angka di bawah adalah **plafon keras platform**, bukan pilihan bebas.

| Komponen | Sekarang | Maksimum yang mungkin | Part konkret | Perkiraan biaya | Batas yang tak bisa dilewati |
|---|---|---|---|---|---|
| **BIOS** | **1.3.1 (10-Nov-2011)** | **2.10.0 (16 Jul 2018)** | Dell DUP `69vfp` / ISO bootable | Rp0 | Wajib naik sebelum CPU v2; **tanpa dual-BIOS** — gagal flash = board mati |
| **CPU** | Xeon E3-1220 (4C/**4T**, 3,1–3,4 GHz, 80 W) | **Xeon E3-1290 v2** (4C/**8T**, 3,7 GHz, 80 W) | atau **E3-1270 v2** (4C/8T, 3,5 GHz, **69 W**) — nilai terbaik | E3-1270 v2: **Rp550 rb–880 rb** (bekas Lazada/Shopee); Rp2,1 jt untuk unit bergaransi toko | 1 socket, LGA1155; resmi hanya sampai E3-1200 **v2** (Ivy Bridge) |
| **RAM** | 3,9 GB (2×2 GB DDR3-1333) | **32 GB** (4× 8 GB DDR3-**1600** ECC UDIMM) | Samsung `M391B1G73BH0-YH9`, Hynix `HMT41GU7AFR8A-PB` | Rp2,0–3,8 jt (Rp500–955 rb/stick) | Hanya **UDIMM** (bukan RDIMM); 4 slot, 32 GB |
| **Storage internal** | 3 disk 3,5" (1 di luar bay) | **2× 3,5" di bay + 1–2 SSD SATA** di area ODD | 2× 8 TB WD Red Plus + SSD 500 GB | Rp8,2–9,2 jt + Rp0,6 jt | Chassis 1U: hanya **2 bay 3,5"**; **tidak ada M.2/NVMe boot** |
| **Ekspansi** | slot PCIe kosong | **1× PCIe x16 Gen2, half-length, maks 25 W** | HBA SATA ASM1166/JMB585 **atau** NIC 2,5 GbE i226 — **pilih satu** | Rp250–600 rb | Satu slot saja; tidak bisa HBA + NIC sekaligus |
| **Jaringan** | 1× GbE (eno1), 1× 100 Mb (eno2) | tetap **2× GbE** (BCM5716 onboard) | — | Rp0 | Tanpa 2,5/10 GbE kecuali slot PCIe dikorbankan |
| **Manajemen** | iDRAC6 Express (Matrox G200eW/WPCM450) | sama, + firmware terbaru | — | Rp0 | Generasi iDRAC6 (Java/legacy) |

**Total jalur mentok:** CPU + RAM = **Rp2,6–5,9 jt** (tanpa disk) — atau **Rp11,4–15,7 jt** bila
sekalian 2× 8 TB RAID1 + SSD.

**Perolehan realistis:**
- Multi-thread naik **+60–80%** (4 thread → 8 thread, IPC Ivy Bridge, DDR3-1600).
- **Swap hilang total** (32 GB) — ini perbaikan terbesar dan sama persis dengan Skenario B.
- Redundansi **RAID1 hanya 2 disk**; kapasitas usable 8 TB (vs 21,8 TB RAIDZ1 di Skenario B).

**Yang tetap tidak bisa dikejar, sekeras apa pun diupgrade:**

| Keterbatasan | Konsekuensi nyata |
|---|---|
| Maks 2 bay 3,5" | RAIDZ1 4 disk mustahil; maksimum RAID1 |
| Tanpa NVMe boot | Docker/DB selalu di HDD atau SATA SSD |
| 1 slot PCIe 25 W | HBA **atau** NIC 2,5 GbE, tidak keduanya |
| DDR3-1600 | Bandwidth & efisiensi daya era 2012 |
| BIOS 2011 → 2.10.0 | Patch Spectre/Meltdown, tapi tetap EOL |
| 80 W TDP, fan 40 mm | Konsumsi & kebisingan tidak turun |

**Putusan:** Skenario D **masuk akal hanya** sebagai jembatan bila anggaran < Rp7 jt dan pembelian
disk ditunda — dan sudah 40–45% dari biaya Skenario B tanpa keunggulan platform apa pun.
Bila R210 II dipakai ulang sebagai **server backup** (§4 langkah 5), cukup RAM 32 GB saja;
CPU v2 tidak diperlukan karena beban backup ringan.

> ⚠️ Risiko flashing BIOS: 1.3.1 → 2.10.0 harus lewat DUP Linux atau ISO bootable, dan board ini
> tidak punya BIOS cadangan. Siapkan UPS dan catat Service Tag `9B6HC2S`. Bila hanya ingin
> perbaikan memori, **lewati langkah BIOS + CPU** dan cukup pasang 32 GB RAM.

## 4. Rencana Migrasi (urutan wajib)

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

## 5. Daftar Tindakan Berprioritas

| # | Tindakan | Biaya | Dampak |
|---|---|---|---|
| 1 | Backup Nextcloud + karaoke ke HDD eksternal | Rp0 (pakai disk yang ada) | 🔴 Kritis |
| 2 | Naikkan RAM ke 32 GB (4× 8 GB ECC UDIMM) | Rp2–3,8 jt | 🔴 Menghapus swap |
| 3 | Perbaiki link `eno2` 100 Mb/s | Rp0–50 rb (kabel) | 🟡 Throughput |
| 4 | Beli NAS 4-bay + 4× 8 TB RAIDZ1 + 2 NVMe | Rp33–37 jt | 🔴 Redundansi + kapasitas |
| 5 | Migrasi data & jadikan R210 II backup server | Rp0 | 🔴 Menutup celah backup |
| 6 | Konversi karaoke NTFS → ext4/XFS, pasang UPS | Rp0–1,5 jt | 🟡 Keandalan |
| 7 | Pindahkan `opencode`/Chrome dari host NAS | Rp0 | 🟡 ±170 MB RAM |

---

## 6. Lampiran — Perintah Audit yang Digunakan

```bash
# Identitas & platform
hostname; uname -a; cat /etc/os-release; uptime
sudo dmidecode -t 0,1,2,3,16,17,39
lscpu
lspci
lsusb

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
```

---

## 7. Catatan & Batasan

- Harga adalah **listing pasar Indonesia (Tokopedia/Blibli/Lazada/DimensiData), November 2026**
  dan berfluktuasi; konfirmasi ulang sebelum pembelian.
- Harga komponen rakitan Skenario C dan HDD 4 TB bersifat **estimasi**.
- Kapasitas RAM maksimum 32 GB mengikuti `dmidecode` tipe 16 (4 device); sebagian forum
  melaporkan R210 II bisa 32 GB dengan 4× 8 GB — tidak diuji di mesin ini.
- Dukungan CPU E3-1200 **v2** (Ivy Bridge) dan BIOS **2.10.0** mengacu pada *Dell R210 II Technical Guide* serta halaman driver Dell; **belum diuji pada unit ini** (BIOS masih 1.3.1).
- Audit bersifat read-only: **tidak ada perubahan konfigurasi atau data pada NAS.**
