<p align="center">
  <img src="../../assets/readme/hero.svg" width="100%" alt="SkillsGo — ค้นหา ตรวจสอบ และจัดการ Agent Skills">
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
    <a href="./README.id.md">Bahasa Indonesia</a> ·
    <a href="./README.tr.md">Türkçe</a> ·
    <a href="./README.nl.md">Nederlands</a> ·
    <a href="./README.pl.md">Polski</a> ·
    <strong>ไทย</strong> ·
    <a href="./README.vi.md">Tiếng Việt</a> ·
    <a href="./README.ms.md">Bahasa Melayu</a> ·
    <a href="./README.sv.md">Svenska</a> ·
    <a href="./README.uk.md">Українська</a>
  </p>
<!-- README-I18N:END -->

SkillsGo คือระบบนิเวศแบบเปิดสำหรับค้นหาและจัดการ Agent Skills โดย App เดสก์ท็อปมอบวิธีแบบภาพให้ผู้ใช้ค้นหาและจัดการ Skills ส่วน CLI เชื่อมแค็ตตาล็อก Hub เดียวกันเข้ากับ CI/CD และขั้นตอนการทำงานของสภาพแวดล้อมที่ทำซ้ำได้

## ดู SkillsGo ขณะทำงาน

<p align="center">
  <img src="../../assets/readme/discover-ranking.png" width="100%" alt="App เดสก์ท็อป SkillsGo แสดง Agent Skills จากอันดับแบบสดของ Hub สาธารณะ">
</p>

App เดสก์ท็อปรวมการค้นหา หลักฐานแหล่งที่มา เป้าหมายการติดตั้ง และรายการในเครื่องไว้ในเส้นทางเดียวที่เข้าใจง่าย การใช้งานส่วนบุคคลไม่ต้องมีบัญชี

### ค้นหาจาก Hub

ค้นหาด้วย Skill หรือที่เก็บต้นทาง สำรวจอันดับแบบสด และติดตั้ง Skill รายการเดียวหรือทั้งคอลเลกชัน

<p align="center">
  <img src="../../assets/readme/discover-find.png" width="100%" alt="การค้นหา Discover ของ SkillsGo แสดงที่เก็บต้นทางและ Agent Skills ที่พร้อมใช้งาน">
</p>

### ตรวจสอบก่อนติดตั้ง

ก่อนเปลี่ยนแปลงข้อมูลในเครื่อง ให้ตรวจสอบที่เก็บต้นทาง รุ่นเผยแพร่ที่เปลี่ยนไม่ได้ Agents ที่รองรับ บทสรุปที่แปลแล้ว และ `SKILL.md` ที่แสดงผลแล้ว

<p align="center">
  <img src="../../assets/readme/discover-skill-detail.png" width="100%" alt="รายละเอียด Skill แสดงหลักฐานต้นทาง รุ่น Agents ที่รองรับ และคำแนะนำที่แสดงผลแล้ว">
</p>

### เลือกตำแหน่งติดตั้ง Skills อย่างแม่นยำ

ติดตั้งแบบส่วนกลางหรือในโครงการที่เลือก แล้วเลือก Agents ที่ควรได้รับ Skill รุ่นเดียวกัน

<p align="center">
  <img src="../../assets/readme/discover-install-skill.png" width="100%" alt="ตัวเลือกเป้าหมายการติดตั้ง SkillsGo แสดงโครงการที่เลือกและ Agents หลายรายการ">
</p>

### จัดการ Library ในเครื่องเพียงแห่งเดียว

เรียกดู Skills ที่ติดตั้งตามขอบเขตส่วนกลางหรือโครงการ ค้นหาในรายการ และกรองตาม Agent

<p align="center">
  <img src="../../assets/readme/library-global-skills.png" width="100%" alt="Library ของ SkillsGo แสดง Skills ที่ติดตั้งแบบส่วนกลางและเป้าหมาย Agent">
</p>

### ดูผลกระทบก่อนอัปเดต

ตรวจสอบการเปลี่ยนรุ่นและ Skills ที่จะถูกลบก่อนใช้การอัปเดตที่เก็บ

<p align="center">
  <img src="../../assets/readme/library-update-skills.png" width="100%" alt="ตัวอย่างการอัปเดต Library แสดงการเปลี่ยนรุ่นและ Skills ที่จะถูกลบ">
</p>

<details>
  <summary><strong>ดู Library ที่จำกัดเฉพาะโครงการ</strong></summary>
  <br>
  <p align="center">
    <img src="../../assets/readme/library-project.png" width="100%" alt="Library ของ SkillsGo แสดง Skills ที่ติดตั้งในโครงการที่เลือก">
  </p>
</details>

## เหตุผลที่เลือก SkillsGo

- **หลักฐานจากแหล่งที่มาจริง** — ตรวจสอบตัวตนที่เก็บ รุ่น `SKILL.md` ไฟล์ และความเสี่ยงก่อนติดตั้ง
- **เป้าหมาย Agent ที่ชัดเจน** — ติดตั้ง Skills แบบส่วนกลางหรือระดับโครงการให้ Agents ที่เลือก โดยไม่ต้องคัดลอกไฟล์ด้วยตนเอง
- **การเผยแพร่ที่ตรวจสอบได้** — ปฏิบัติต่อรุ่นเผยแพร่ของที่เก็บต้นทางเป็นหน่วยเผยแพร่ที่เปลี่ยนไม่ได้
- **จัดการในเครื่องเป็นอันดับแรก** — ตรวจสอบและจัดการรายการในเครื่องอย่างปลอดภัยแม้ Hub จะใช้งานไม่ได้
- **สองอินเทอร์เฟซสำหรับสองวัตถุประสงค์** — ใช้ App สำหรับขั้นตอนส่วนบุคคลแบบโต้ตอบ และ CLI สำหรับ CI/CD ระบบอัตโนมัติ และสภาพแวดล้อม Skill ที่สอดคล้องกัน

## วิธีการทำงาน

<p align="center">
  <img src="../../assets/readme/workflow.svg" width="100%" alt="ขั้นตอน SkillsGo: ค้นหา ตรวจสอบ เลือกเป้าหมาย ติดตั้ง และจัดการ">
</p>

Hub สาธารณะเป็นแหล่งร่วมสำหรับตัวตน Skills รุ่นที่เปลี่ยนไม่ได้ ข้อมูลกำกับ การค้นหา และการค้นพบ App เชื่อมผู้ใช้กับ Hub ผ่านขั้นตอนแบบภาพ ส่วน CLI เชื่อมระบบอัตโนมัติและ CI/CD เข้ากับ Hub เดียวกัน เพื่อให้การเลือก Skills สอดคล้องกันในทุกสภาพแวดล้อม

## สำรวจ monorepo

```text
skillsgo/
├── app/       Flutter desktop client and user experience
├── cli/       Go CLI and local Skill execution engine
├── hub/       Public Skill Hub service and reusable runtime
├── protocol/  Shared executable contracts used by CLI and Hub
├── web/       Public product, Hub, and documentation surface
└── e2e/       Cross-product CLI/Hub and desktop journeys
```

อ่าน [`CONTEXT-MAP.md`](../../CONTEXT-MAP.md) สำหรับขอบเขตผลิตภัณฑ์และภาษาของโดเมน

## เรียกใช้ในเครื่อง

โครงสร้างการพัฒนาแบบรวมมุ่งเป้าไปที่ macOS ในขณะนี้ และต้องใช้ Flutter, Go, Docker, [Process Compose](https://github.com/F1bonacc1/process-compose) และ [Air](https://github.com/air-verse/air)

```bash
make dev
```

คำสั่งนี้เริ่ม PostgreSQL, Hub ในเครื่อง, CLI ที่สร้างใหม่ และ App เดสก์ท็อป Flutter ในเซสชันที่มีการควบคุมเดียวกัน หากต้องการตรวจสอบพื้นที่ทำงานที่กำหนดค่าทั้งหมด:

```bash
make test
```

แต่ละพื้นที่ทำงานมีจุดเริ่มต้นแยกต่างหากด้วย:

| พื้นที่ทำงาน | การพัฒนาหรือการตรวจสอบ |
| --- | --- |
| App | `cd app && flutter run -d macos` |
| CLI | `cd cli && go test ./...` |
| Hub | `cd hub && go test ./...` |
| Protocol | `cd protocol && go test ./...` |
| Web | `cd web && pnpm install && pnpm dev` |

อ่าน [CONTRIBUTING.md](../../CONTRIBUTING.md) ก่อนเปลี่ยนพฤติกรรมผลิตภัณฑ์

## สถานะโครงการ

SkillsGo กำลังเตรียมรุ่นเผยแพร่ชุดแรก โดยกำหนดสายงานเผยแพร่ของ Hub ก่อน ส่วนรุ่น App ที่ลงนามและรับรอง รวมถึงการเผยแพร่ CLI แบบแยกต่างหาก จะผ่านเกณฑ์ความพร้อมของตนเอง ดู[การออกแบบรุ่นเผยแพร่](../release-design.md)สำหรับหน่วยรุ่นที่รองรับ ความสมบูรณ์ของอาร์ติแฟกต์ และข้อกำหนดห่วงโซ่อุปทาน

## ชุมชน

- ใช้ [GitHub Discussions](https://github.com/skillsgo/skillsgo/discussions) สำหรับคำถาม การแก้ปัญหา และแนวคิดระยะแรก
- ใช้[แบบฟอร์ม issue](https://github.com/skillsgo/skillsgo/issues/new/choose)เฉพาะสำหรับข้อผิดพลาดที่ทำซ้ำได้ คำขอฟีเจอร์ที่ชัดเจน และปัญหาเอกสาร
- ปฏิบัติตาม [SECURITY.md](../../SECURITY.md) เพื่อรายงานช่องโหว่เป็นการส่วนตัว
- การมีส่วนร่วมอยู่ภายใต้[หลักปฏิบัติ](../../CODE_OF_CONDUCT.md)และ[รูปแบบการกำกับดูแล](../../GOVERNANCE.md)

## ใบอนุญาต

SkillsGo ใช้ [Apache License 2.0](../../LICENSE)

Hub มีโค้ดที่ต่อยอดจาก [Athens](https://github.com/gomods/athens) ซึ่งยังอยู่ภายใต้ Athens MIT License และประกาศการระบุแหล่งที่มา ดู [`NOTICE`](../../NOTICE) และ [`THIRD_PARTY_LICENSES/ATHENS-LICENSE`](../../THIRD_PARTY_LICENSES/ATHENS-LICENSE)
