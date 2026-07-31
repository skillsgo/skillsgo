<p align="center">
  <img src="../../assets/readme/hero.svg" width="100%" alt="SkillsGo — temukan, verifikasi, dan kelola Agent Skills">
</p>

<!-- README-I18N:START -->

  <p>
    <a href="../../README.md">English</a> ·
    <a href="./README.zh-CN.md">简体中文</a> ·
    <a href="./README.zh-TW.md">繁體中文（台灣）</a> ·
    <a href="./README.zh-HK.md">繁體中文（香港）</a> ·
    <a href="./README.ja.md">日本語</a> ·
    <a href="./README.ko.md">한국어</a> ·
    <a href="./README.fr.md">Français</a> ·
    <a href="./README.de.md">Deutsch</a> ·
    <a href="./README.it.md">Italiano</a> ·
    <a href="./README.es.md">Español</a> ·
    <a href="./README.pt-BR.md">Português (Brasil)</a> ·
    <a href="./README.ru.md">Русский</a> ·
    <a href="./README.ar.md">العربية</a> ·
    <a href="./README.hi.md">हिन्दी</a> ·
    <strong>Bahasa Indonesia</strong> ·
    <a href="./README.tr.md">Türkçe</a> ·
    <a href="./README.nl.md">Nederlands</a> ·
    <a href="./README.pl.md">Polski</a> ·
    <a href="./README.th.md">ไทย</a> ·
    <a href="./README.vi.md">Tiếng Việt</a> ·
    <a href="./README.ms.md">Bahasa Melayu</a> ·
    <a href="./README.sv.md">Svenska</a> ·
    <a href="./README.uk.md">Українська</a>
  </p>
<!-- README-I18N:END -->

SkillsGo adalah ekosistem terbuka untuk menemukan dan mengelola Agent Skills. App desktop memberi pengguna cara visual untuk menemukan dan mengelola Skills, sedangkan CLI menghadirkan katalog Hub yang sama ke CI/CD dan alur lingkungan yang dapat direproduksi.

## Lihat SkillsGo beraksi

<p align="center">
  <img src="../../assets/readme/discover-ranking.png" width="100%" alt="App desktop SkillsGo menampilkan Agent Skills dari peringkat langsung Hub publik">
</p>

App desktop menyatukan penemuan, bukti sumber, target instalasi, dan inventaris lokal dalam satu alur yang mudah dipahami. Penggunaan pribadi tidak memerlukan akun.

### Temukan melalui Hub

Cari berdasarkan Skill atau repositori sumber, jelajahi peringkat langsung, lalu instal satu Skill atau seluruh koleksi.

<p align="center">
  <img src="../../assets/readme/discover-find.png" width="100%" alt="Pencarian Discover SkillsGo menampilkan repositori sumber dan Agent Skills yang tersedia">
</p>

### Periksa sebelum menginstal

Sebelum membuat perubahan lokal, tinjau repositori sumber, rilis yang tidak dapat diubah, Agents yang didukung, ringkasan terjemahan, dan `SKILL.md` yang telah dirender.

<p align="center">
  <img src="../../assets/readme/discover-skill-detail.png" width="100%" alt="Detail Skill menampilkan bukti sumber, versi, Agents yang didukung, dan petunjuk yang telah dirender">
</p>

### Pilih dengan tepat lokasi pemasangan Skills

Instal secara global atau ke proyek yang dipilih, lalu tentukan Agents yang harus menerima rilis Skill yang sama.

<p align="center">
  <img src="../../assets/readme/discover-install-skill.png" width="100%" alt="Pemilih target instalasi SkillsGo menampilkan proyek terpilih dan beberapa Agents">
</p>

### Kelola satu Library lokal

Jelajahi Skills yang terinstal berdasarkan cakupan global atau proyek, cari inventaris, dan filter berdasarkan Agent.

<p align="center">
  <img src="../../assets/readme/library-global-skills.png" width="100%" alt="Library SkillsGo menampilkan Skills yang terinstal secara global dan target Agent-nya">
</p>

### Lihat dampaknya sebelum memperbarui

Lihat perpindahan versi dan Skills yang akan dihapus sebelum menerapkan pembaruan repositori.

<p align="center">
  <img src="../../assets/readme/library-update-skills.png" width="100%" alt="Pratinjau pembaruan Library menampilkan perpindahan versi dan Skills yang akan dihapus">
</p>

<details>
  <summary><strong>Lihat Library dalam cakupan proyek</strong></summary>
  <br>
  <p align="center">
    <img src="../../assets/readme/library-project.png" width="100%" alt="Library SkillsGo menampilkan Skills yang terinstal pada proyek terpilih">
  </p>
</details>

## Mengapa SkillsGo

- **Bukti sumber yang nyata** — periksa identitas repositori, versi, `SKILL.md`, berkas, dan risiko sebelum instalasi.
- **Target Agent yang jelas** — instal Skills secara global atau dalam cakupan proyek untuk Agents terpilih tanpa menyalin berkas secara manual.
- **Distribusi yang dapat diverifikasi** — perlakukan rilis repositori sumber sebagai unit distribusi yang tidak dapat diubah.
- **Pengelolaan yang mengutamakan lokal** — periksa dan kelola inventaris lokal dengan aman bahkan saat Hub tidak tersedia.
- **Dua antarmuka untuk kebutuhan berbeda** — gunakan App untuk alur pribadi yang interaktif dan CLI untuk CI/CD, otomatisasi, serta lingkungan Skill yang konsisten.

## Cara kerja

<p align="center">
  <img src="../../assets/readme/workflow.svg" width="100%" alt="Alur SkillsGo: temukan, periksa, pilih target, instal, dan kelola">
</p>

Hub publik adalah sumber bersama untuk identitas Skills, rilis yang tidak dapat diubah, metadata, pencarian, dan penemuan. App menghubungkan pengguna ke Hub melalui alur visual; CLI menghubungkan otomatisasi dan CI/CD ke Hub yang sama agar pilihan Skills tetap konsisten di berbagai lingkungan.

## Jelajahi monorepo

```text
skillsgo/
├── app/       Flutter desktop client and user experience
├── cli/       Go CLI and local Skill execution engine
├── hub/       Public Skill Hub service and reusable runtime
├── protocol/  Shared executable contracts used by CLI and Hub
├── web/       Public product, Hub, and documentation surface
└── e2e/       Cross-product CLI/Hub and desktop journeys
```

Baca [`CONTEXT-MAP.md`](../../CONTEXT-MAP.md) untuk batas produk dan bahasa domain.

## Jalankan secara lokal

Topologi pengembangan terpadu saat ini menargetkan macOS dan memerlukan Flutter, Go, Docker, [Process Compose](https://github.com/F1bonacc1/process-compose), dan [Air](https://github.com/air-verse/air).

```bash
make dev
```

Perintah ini menjalankan PostgreSQL, Hub lokal, CLI yang baru dibangun, dan App desktop Flutter dalam satu sesi terawasi. Untuk memvalidasi semua workspace yang dikonfigurasi:

```bash
make test
```

Setiap workspace juga memiliki titik masuk tersendiri:

| Workspace | Pengembangan atau validasi |
| --- | --- |
| App | `cd app && flutter run -d macos` |
| CLI | `cd cli && go test ./...` |
| Hub | `cd hub && go test ./...` |
| Protocol | `cd protocol && go test ./...` |
| Web | `cd web && pnpm install && pnpm dev` |

Baca [CONTRIBUTING.md](../../CONTRIBUTING.md) sebelum mengubah perilaku produk.

## Status proyek

SkillsGo sedang mempersiapkan rilis pertamanya. Pipeline rilis Hub ditetapkan lebih dahulu; rilis App yang ditandatangani dan dinotarisasi serta distribusi CLI mandiri mengikuti kriteria kesiapan masing-masing. Lihat [desain rilis](../release-design.md) untuk unit rilis yang didukung, integritas artefak, dan persyaratan rantai pasok.

## Komunitas

- Gunakan [GitHub Discussions](https://github.com/skillsgo/skillsgo/discussions) untuk pertanyaan, pemecahan masalah, dan gagasan awal.
- Gunakan [formulir issue](https://github.com/skillsgo/skillsgo/issues/new/choose) khusus untuk bug yang dapat direproduksi, permintaan fitur yang konkret, dan masalah dokumentasi.
- Ikuti [SECURITY.md](../../SECURITY.md) untuk melaporkan kerentanan secara privat.
- Partisipasi diatur oleh [Kode Etik](../../CODE_OF_CONDUCT.md) dan [model tata kelola](../../GOVERNANCE.md).

## Lisensi

SkillsGo dilisensikan berdasarkan [Apache License 2.0](../../LICENSE).

Hub berisi kode turunan dari [Athens](https://github.com/gomods/athens), yang tetap tunduk pada Athens MIT License dan pemberitahuan atribusinya. Lihat [`NOTICE`](../../NOTICE) dan [`THIRD_PARTY_LICENSES/ATHENS-LICENSE`](../../THIRD_PARTY_LICENSES/ATHENS-LICENSE).
