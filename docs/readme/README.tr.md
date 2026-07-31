<p align="center">
  <img src="../../assets/readme/hero.svg" width="100%" alt="SkillsGo — Agent Skills keşfedin, doğrulayın ve yönetin">
</p>

<!-- README-I18N:START -->

<details>
  <summary><strong>Türkçe</strong> · Diller</summary>
  <br>
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
    <a href="./README.id.md">Bahasa Indonesia</a> ·
    <strong>Türkçe</strong> ·
    <a href="./README.nl.md">Nederlands</a> ·
    <a href="./README.pl.md">Polski</a> ·
    <a href="./README.th.md">ไทย</a> ·
    <a href="./README.vi.md">Tiếng Việt</a> ·
    <a href="./README.ms.md">Bahasa Melayu</a> ·
    <a href="./README.sv.md">Svenska</a> ·
    <a href="./README.uk.md">Українська</a>
  </p>
</details>

<!-- README-I18N:END -->

SkillsGo, Agent Skills keşfetmek ve yönetmek için açık bir ekosistemdir. Masaüstü App, insanların Skills keşfedip yönetmesi için görsel bir yol sunarken CLI, aynı Hub kataloğunu CI/CD ve tekrarlanabilir ortam iş akışlarına taşır.

> [!IMPORTANT]
> SkillsGo, ilk kararlı sürümünden önce etkin biçimde geliştirilmektedir. Genel protokoller, kalıcı biçimler ve kurulum davranışı değişebilir.

## SkillsGo’yu çalışırken görün

<p align="center">
  <img src="../../assets/readme/discover-ranking.png" width="100%" alt="SkillsGo masaüstü App, genel Hub canlı sıralamasındaki Agent Skills öğelerini gösteriyor">
</p>

Masaüstü App; keşif, kaynak kanıtı, kurulum hedefleri ve yerel envanteri anlaşılır tek bir akışta birleştirir. Kişisel kullanım için hesap gerekmez.

### Hub üzerinden keşfedin

Skill veya kaynak deposuna göre arama yapın, canlı sıralamayı inceleyin ve tek bir Skill ya da koleksiyonun tamamını kurun.

<p align="center">
  <img src="../../assets/readme/discover-find.png" width="100%" alt="SkillsGo Discover araması bir kaynak deposunu ve kullanılabilir Agent Skills öğelerini gösteriyor">
</p>

### Kurmadan önce inceleyin

Yerel bir değişiklik yapmadan önce kaynak deposunu, değişmez sürümü, desteklenen Agents listesini, çevrilmiş özeti ve işlenmiş `SKILL.md` dosyasını inceleyin.

<p align="center">
  <img src="../../assets/readme/discover-skill-detail.png" width="100%" alt="SkillsGo Skill ayrıntısı kaynak kanıtını, sürümü, desteklenen Agents listesini ve işlenmiş yönergeleri gösteriyor">
</p>

### Skills öğelerinin nereye kurulacağını tam olarak seçin

Genel kapsamda veya seçili projelere kurun, ardından aynı Skill sürümünü alacak Agents hedeflerini seçin.

<p align="center">
  <img src="../../assets/readme/discover-install-skill.png" width="100%" alt="SkillsGo kurulum hedefi seçici, seçili projeleri ve birden çok Agent hedefini gösteriyor">
</p>

### Tek bir yerel Library yönetin

Kurulu Skills öğelerini genel veya proje kapsamına göre görüntüleyin, envanterde arayın ve Agent’a göre filtreleyin.

<p align="center">
  <img src="../../assets/readme/library-global-skills.png" width="100%" alt="SkillsGo Library, genel kapsamda kurulu Skills öğelerini ve Agent hedeflerini gösteriyor">
</p>

### Güncellemeden önce sonuçlarını görün

Depo güncellemesini uygulamadan önce sürüm geçişini ve kaldırılacak Skills öğelerini görün.

<p align="center">
  <img src="../../assets/readme/library-update-skills.png" width="100%" alt="SkillsGo Library güncelleme önizlemesi sürüm geçişini ve kaldırılacak Skills öğelerini gösteriyor">
</p>

<details>
  <summary><strong>Proje kapsamındaki Library’yi görün</strong></summary>
  <br>
  <p align="center">
    <img src="../../assets/readme/library-project.png" width="100%" alt="SkillsGo Library, seçili projeye kurulan Skills öğelerini gösteriyor">
  </p>
</details>

## Neden SkillsGo

- **Gerçek kaynak kanıtı** — kurulumdan önce depo kimliğini, sürümü, `SKILL.md` dosyasını, dosyaları ve riskleri inceleyin.
- **Açık Agent hedefleri** — dosyaları elle kopyalamak yerine Skills öğelerini seçili Agents için genel veya proje kapsamında kurun.
- **Doğrulanabilir dağıtım** — kaynak depo sürümünü değişmez bir dağıtım birimi olarak ele alın.
- **Önce yerel yönetim** — Hub kullanılamadığında bile yerel envanteri güvenle inceleyip yönetin.
- **Amaca özel iki arayüz** — etkileşimli kişisel akışlar için App, CI/CD, otomasyon ve tutarlı Skill ortamları için CLI kullanın.

## Nasıl çalışır

<p align="center">
  <img src="../../assets/readme/workflow.svg" width="100%" alt="SkillsGo akışı: keşfet, incele, hedefleri seç, kur ve yönet">
</p>

Genel Hub; Skill kimliği, değişmez sürümler, meta veriler, arama ve keşif için ortak kaynaktır. App, insanları görsel bir akışla Hub’a bağlar; CLI ise otomasyon ve CI/CD’yi aynı Hub’a bağlayarak Skill seçimlerinin ortamlar arasında tutarlı kalmasını sağlar.

## Monorepo’yu keşfedin

```text
skillsgo/
├── app/       Flutter desktop client and user experience
├── cli/       Go CLI and local Skill execution engine
├── hub/       Public Skill Hub service and reusable runtime
├── protocol/  Shared executable contracts used by CLI and Hub
├── web/       Public product, Hub, and documentation surface
└── e2e/       Cross-product CLI/Hub and desktop journeys
```

Ürün sınırları ve alan dili için [`CONTEXT-MAP.md`](../../CONTEXT-MAP.md) dosyasını okuyun.

## Yerel olarak çalıştırın

Birleşik geliştirme topolojisi şu anda macOS’u hedefler ve Flutter, Go, Docker, [Process Compose](https://github.com/F1bonacc1/process-compose) ile [Air](https://github.com/air-verse/air) gerektirir.

```bash
make dev
```

Bu komut PostgreSQL’i, yerel Hub’ı, yeni derlenmiş CLI’yi ve Flutter masaüstü App’i tek bir denetimli oturumda başlatır. Yapılandırılmış tüm çalışma alanlarını doğrulamak için:

```bash
make test
```

Her çalışma alanının ayrı bir giriş noktası da vardır:

| Çalışma alanı | Geliştirme veya doğrulama |
| --- | --- |
| App | `cd app && flutter run -d macos` |
| CLI | `cd cli && go test ./...` |
| Hub | `cd hub && go test ./...` |
| Protocol | `cd protocol && go test ./...` |
| Web | `cd web && pnpm install && pnpm dev` |

Ürün davranışını değiştirmeden önce [CONTRIBUTING.md](../../CONTRIBUTING.md) dosyasını okuyun.

## Proje durumu

SkillsGo ilk sürümlerine hazırlanmaktadır. Önce Hub sürüm işlem hattı tanımlanır; imzalı ve noter onaylı App sürümleri ile bağımsız CLI dağıtımı kendi hazırlık ölçütlerini izler. Desteklenen sürüm birimleri, yapıt bütünlüğü ve tedarik zinciri gereksinimleri için [sürüm tasarımına](../release-design.md) bakın.

## Topluluk

- Sorular, sorun giderme ve erken aşamadaki fikirler için [GitHub Discussions](https://github.com/skillsgo/skillsgo/discussions) kullanın.
- Yeniden üretilebilir hatalar, somut özellik istekleri ve dokümantasyon sorunları için amaca yönelik [issue formlarını](https://github.com/skillsgo/skillsgo/issues/new/choose) kullanın.
- Güvenlik açıklarını özel olarak bildirmek için [SECURITY.md](../../SECURITY.md) yönergelerini izleyin.
- Katılım, [Davranış Kuralları](../../CODE_OF_CONDUCT.md) ve [yönetişim modeli](../../GOVERNANCE.md) tarafından düzenlenir.

## Lisans

SkillsGo, [Apache License 2.0](../../LICENSE) ile lisanslanmıştır.

Hub, [Athens](https://github.com/gomods/athens) kaynaklı kod içerir; bu kod Athens MIT License ve atıf bildirimlerine tabi olmaya devam eder. [`NOTICE`](../../NOTICE) ve [`THIRD_PARTY_LICENSES/ATHENS-LICENSE`](../../THIRD_PARTY_LICENSES/ATHENS-LICENSE) dosyalarına bakın.
