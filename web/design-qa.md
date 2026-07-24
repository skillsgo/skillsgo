# Mole landing clone design QA

## Comparison target

- Source visual truth: `design-qa-assets/mole-source-desktop.png` and `design-qa-assets/mole-source-mobile.png`, captured from the authorized `https://mole.fit/zh/` page.
- Implementation: `http://localhost:3100/zh-CN`.
- Browser-rendered implementation evidence: `design-qa-assets/skillsgo-mole-implementation-desktop-verified.png` and `design-qa-assets/skillsgo-mole-implementation-mobile-verified.png`.
- Combined evidence: `design-qa-assets/desktop-comparison-verified.png` and `design-qa-assets/mobile-comparison-verified.png`.
- Focused evidence: `design-qa-assets/desktop-focus-hero-gallery.png` and `design-qa-assets/desktop-focus-voices-pricing.png`.
- State: light theme, Chinese locale, gallery on the responsive default item, testimonials collapsed, FAQ items closed.

## Normalization

| Surface | CSS viewport | Density | Source pixels | Implementation pixels |
| --- | ---: | ---: | ---: | ---: |
| Desktop | 1440 × 1000 | 1 | 1440 × 6233 | 1440 × 6320 |
| Mobile | 390 × 844 | 1 | 390 × 6695 | 390 × 6988 |

The remaining full-page height difference is expected: the user explicitly required the existing SkillsGo header and footer, so those regions intentionally differ from Mole. Body comparison uses the same content width, state, and density.

## Required fidelity surfaces

- Fonts and typography: matched the source serif, UI, mono, size, weight, line-height, tracking, wrapping, and Chinese font fallbacks. Local authorized font files are served from `/mole/fonts`.
- Spacing and layout rhythm: desktop uses the source 1120 px outer frame and 992 px content width. Mobile uses the source 20 px gutters and 350 px content width. Hero, section gaps, gallery, alternating feature rows, price card, FAQ, contacts, and blog align in the combined captures.
- Colors and tokens: source parchment, ivory, navy, warm gray, borders, gradients, radii, and shadows are preserved in a route-scoped stylesheet.
- Image quality and asset fidelity: all visible gallery, planet, avatar, GitHub, YouTube, logo, poster, and video assets are local copies from the authorized snapshot or source. No hotlinked visual assets or placeholder images remain.
- Copy and content: Mole hero, gallery, feature, testimonial, pricing, FAQ, contact, and blog copy matches the authorized Chinese source. The shared SkillsGo header and footer intentionally retain SkillsGo copy.

## Interaction verification

- Gallery tab selection changed the caption from `清理` to `软件`.
- Testimonial control changed `aria-expanded` to `true` and returned to the collapsed state.
- FAQ summary opened its native `details` element.
- Mobile collapsed testimonials render the same four featured cards and approximately the same 571 px wall height as the source.
- Browser console: no warnings or errors.

## Comparison history

1. P1 — The scoped source `.page` selector did not initially size the scope root, producing a full-width layout.
   - Fix: added an explicit 1120 px route root with source desktop and responsive gutters.
   - Post-fix evidence: `desktop-comparison-v3.png`.
2. P1 — Mobile testimonials initially retained three desktop DOM columns, producing unreadably narrow cards.
   - Fix: implemented the source responsive content model in React.
3. P1 — The first mobile fix still rendered all testimonials while collapsed, adding roughly 650 px of body height.
   - Fix: matched the source mobile featured set and expanded-state behavior.
   - Post-fix evidence: `mobile-comparison-v4.png` and `mobile-comparison-verified.png`.
4. P1 — SkillsGo's global anchor color overrode the primary-button foreground, hiding its label on navy.
   - Fix: added a scoped primary-button foreground rule with sufficient specificity.
   - Post-fix evidence: `skillsgo-mole-implementation-desktop-verified.png` and `mobile-comparison-verified.png`.

## Findings

No actionable P0, P1, or P2 differences remain in the cloned body. The header and footer differences are intentional requirements, not fidelity defects.

## Follow-up polish

- P3: The copied source stylesheet retains rules for additional Mole locales that are not currently routed by SkillsGo. They are harmless and preserve future source fidelity.

## Final result

final result: passed
