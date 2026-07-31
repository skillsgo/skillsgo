<p align="center">
  <img src="../../assets/readme/hero.svg" width="100%" alt="SkillsGo — descubre, verifica y gestiona Agent Skills">
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
    <strong>Español</strong> ·
    <a href="./README.pt-BR.md">Português (Brasil)</a> ·
    <a href="./README.ru.md">Русский</a> ·
    <a href="./README.ar.md">العربية</a> ·
    <a href="./README.hi.md">हिन्दी</a> ·
    <a href="./README.id.md">Bahasa Indonesia</a> ·
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

SkillsGo es un ecosistema abierto para descubrir y gestionar Agent Skills. La App de escritorio ofrece a las personas una forma visual de descubrir y gestionar Skills, mientras que la CLI lleva el mismo catálogo del Hub a CI/CD y a flujos de entornos reproducibles.

## SkillsGo en acción

<p align="center">
  <img src="../../assets/readme/discover-ranking.png" width="100%" alt="La App de escritorio SkillsGo muestra Agent Skills de la clasificación en vivo del Hub público">
</p>

La App de escritorio reúne descubrimiento, pruebas del origen, destinos de instalación e inventario local en un recorrido sencillo. El uso personal no requiere una cuenta.

### Descubre desde el Hub

Busca por Skill o repositorio de origen, explora la clasificación en vivo e instala un Skill o una colección completa.

<p align="center">
  <img src="../../assets/readme/discover-find.png" width="100%" alt="La búsqueda Discover de SkillsGo muestra un repositorio de origen y sus Agent Skills disponibles">
</p>

### Verifica antes de instalar

Antes de realizar cambios locales, revisa el repositorio de origen, la versión inmutable, los Agents compatibles, el resumen traducido y el archivo `SKILL.md` renderizado.

<p align="center">
  <img src="../../assets/readme/discover-skill-detail.png" width="100%" alt="El detalle de un Skill muestra el origen, la versión, los Agents compatibles y las instrucciones renderizadas">
</p>

### Elige exactamente dónde instalar los Skills

Instala de forma global o en proyectos seleccionados y, después, elige los Agents que deben recibir la misma versión del Skill.

<p align="center">
  <img src="../../assets/readme/discover-install-skill.png" width="100%" alt="El selector de destinos de SkillsGo muestra proyectos seleccionados y varios Agents">
</p>

### Gestiona una única Library local

Explora los Skills instalados por ámbito global o de proyecto, busca en el inventario y filtra por Agent.

<p align="center">
  <img src="../../assets/readme/library-global-skills.png" width="100%" alt="La Library de SkillsGo muestra los Skills instalados globalmente y sus Agents de destino">
</p>

### Conoce las consecuencias antes de actualizar

Consulta el cambio de versión y los Skills que se eliminarán antes de aplicar una actualización del repositorio.

<p align="center">
  <img src="../../assets/readme/library-update-skills.png" width="100%" alt="La vista previa de actualización de la Library muestra el cambio de versión y los Skills que se eliminarán">
</p>

<details>
  <summary><strong>Ver una Library limitada a un proyecto</strong></summary>
  <br>
  <p align="center">
    <img src="../../assets/readme/library-project.png" width="100%" alt="La Library de SkillsGo muestra los Skills instalados en un proyecto seleccionado">
  </p>
</details>

## Por qué SkillsGo

- **Pruebas reales del origen** — revisa la identidad del repositorio, la versión, `SKILL.md`, los archivos y los riesgos antes de instalar.
- **Destinos Agent explícitos** — instala Skills de forma global o por proyecto para los Agents seleccionados, sin copiar archivos manualmente.
- **Distribución verificable** — trata una versión del repositorio de origen como una unidad de distribución inmutable.
- **Gestión local prioritaria** — revisa y gestiona el inventario local de forma segura incluso cuando el Hub no esté disponible.
- **Dos interfaces para fines distintos** — usa la App para flujos personales interactivos y la CLI para CI/CD, automatización y entornos Skill coherentes.

## Cómo funciona

<p align="center">
  <img src="../../assets/readme/workflow.svg" width="100%" alt="Flujo de SkillsGo: descubrir, verificar, elegir destinos, instalar y gestionar">
</p>

El Hub público es la fuente compartida de identidad de Skills, versiones inmutables, metadatos, búsqueda y descubrimiento. La App conecta a las personas con el Hub mediante un flujo visual; la CLI conecta la automatización y CI/CD con el mismo Hub para mantener coherentes las selecciones de Skills entre entornos.

## Explora el monorepo

```text
skillsgo/
├── app/       Flutter desktop client and user experience
├── cli/       Go CLI and local Skill execution engine
├── hub/       Public Skill Hub service and reusable runtime
├── protocol/  Shared executable contracts used by CLI and Hub
├── web/       Public product, Hub, and documentation surface
└── e2e/       Cross-product CLI/Hub and desktop journeys
```

Consulta [`CONTEXT-MAP.md`](../../CONTEXT-MAP.md) para conocer los límites del producto y el lenguaje del dominio.

## Ejecución local

La topología de desarrollo unificada está orientada actualmente a macOS y requiere Flutter, Go, Docker, [Process Compose](https://github.com/F1bonacc1/process-compose) y [Air](https://github.com/air-verse/air).

```bash
make dev
```

Este comando inicia PostgreSQL, el Hub local, una CLI recién compilada y la App de escritorio Flutter en una única sesión supervisada. Para validar todos los espacios de trabajo configurados:

```bash
make test
```

Cada espacio de trabajo también ofrece su propio punto de entrada:

| Espacio de trabajo | Desarrollo o validación |
| --- | --- |
| App | `cd app && flutter run -d macos` |
| CLI | `cd cli && go test ./...` |
| Hub | `cd hub && go test ./...` |
| Protocol | `cd protocol && go test ./...` |
| Web | `cd web && pnpm install && pnpm dev` |

Consulta [CONTRIBUTING.md](../../CONTRIBUTING.md) antes de modificar el comportamiento del producto.

## Estado del proyecto

SkillsGo está preparando sus primeras versiones. La canalización de publicación del Hub se define primero; las versiones firmadas y notarizadas de la App y la distribución independiente de la CLI siguen sus propios criterios de preparación. Consulta el [diseño de versiones](../release-design.md) para conocer las unidades compatibles, la integridad de los artefactos y los requisitos de la cadena de suministro.

## Comunidad

- Usa [GitHub Discussions](https://github.com/skillsgo/skillsgo/discussions) para preguntas, resolución de problemas e ideas iniciales.
- Usa los [formularios de issue](https://github.com/skillsgo/skillsgo/issues/new/choose) específicos para errores reproducibles, solicitudes concretas de funciones y problemas de documentación.
- Sigue [SECURITY.md](../../SECURITY.md) para informar vulnerabilidades de forma privada.
- La participación se rige por el [Código de conducta](../../CODE_OF_CONDUCT.md) y el [modelo de gobernanza](../../GOVERNANCE.md).

## Licencia

SkillsGo se distribuye bajo [Apache License 2.0](../../LICENSE).

El Hub contiene código derivado de [Athens](https://github.com/gomods/athens), que sigue sujeto a Athens MIT License y a sus avisos de atribución. Consulta [`NOTICE`](../../NOTICE) y [`THIRD_PARTY_LICENSES/ATHENS-LICENSE`](../../THIRD_PARTY_LICENSES/ATHENS-LICENSE).
