# Third-Party Notices

## Radix Colors

`lib/ui/design_system/radix_palette.dart` reproduces the exact sRGB values of
the Sand light and dark scales and steps 3, 11, and 12 of the Blue, Green,
Amber, Orange, and Red light and dark scales from `@radix-ui/colors` version
3.0.0.

Official package:
https://www.npmjs.com/package/@radix-ui/colors/v/3.0.0

Package integrity:
`sha512-FUOsGBkHrYJwCSEtWRCIfQbZG7q1e6DgxCIOe1SUQzDe/7rXXeA47s8yCn6fuTNQAj1Zq4oTFi9Yjp3wzElcxg==`

MIT License

Copyright (c) 2021-2022 Modulz

Copyright (c) 2022-Present WorkOS

## Primer Primitives

`lib/ui/design_system/skills_color_tokens.dart` and
`lib/ui/design_system/skills_theme.dart` adapt the functional token vocabulary
documented by `@primer/primitives` version 11.9.0, including
`bgColor-default`, `bgColor-muted`, `bgColor-inset`, `fgColor-default`,
`fgColor-muted`, `borderColor-default`, and `borderColor-muted`. SkillsGo does
not copy GitHub's theme values; it maps these semantic roles onto its Radix
Sand spatial foundation and adds Folder-specific roles.

The component-state mapping in `skills_component_tokens.dart` is grounded in
the package's `component/button.json5`, `functional/color/control.json5`,
`component/card.json5`, `component/overlay.json5`,
`component/sideNav.json5`, and `component/focus.json5` token sources.

Official package:
https://www.npmjs.com/package/@primer/primitives/v/11.9.0

Package integrity:
`sha512-yESOalhd7s7S3unV1V32v3Z0RszXiiz6pzy6hVI9xpdTh1q1Gt8vyDFxRlqIvuwc5ZaO1+gYQTDbjxb4nWBzMw==`

MIT License

Copyright (c) 2018 GitHub Inc.

## Lobe Icons

The Agent logo assets in `assets/agent-logos/` are adapted from Lobe Icons,
Copyright (c) 2023 LobeHub, and used under the MIT License:
https://github.com/lobehub/lobe-icons

## Atlassian Rovo

`assets/agent-logos/rovo.svg` is the official Rovo app icon distributed by
Atlassian Design:
https://atlassian.design/foundations/logos

## Portal Labs

`lib/ui/primary_folder_shell.dart` is derived from the Folder Tabs component,
`lib/ui/bloom_color_picker/` vendors and modifies Bloom Color Picker, and
`lib/ui/discrete_tabs/` vendors and modifies Discrete Tabs. The
`lib/ui/install_location_island/` component is derived from and substantially
adapts Todo List Interaction for installation location selection. These
components originate from
[lportals/portal_labs](https://github.com/lportals/portal_labs).

MIT License

Copyright (c) 2026 Luis Portal

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
the Software, and to permit persons to whom the Software is furnished to do so,
subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
