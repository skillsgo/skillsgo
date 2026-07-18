# Discover Leaderboard Design QA

## Comparison Target

- Source visual truth: `/var/folders/71/_sx7yq7932b3nsf8dxhxwkdr0000gn/T/codex-clipboard-4bb92f77-cc38-43a0-9240-5f84af176128.png`
- Rendered implementation: `/Users/freeman/Documents/Codes/skillsgo/.codex-artifacts/discover-leaderboard-ranking.png`
- Focused implementation crop: `/Users/freeman/Documents/Codes/skillsgo/.codex-artifacts/discover-leaderboard-header.png`
- Combined comparison evidence: `/Users/freeman/Documents/Codes/skillsgo/.codex-artifacts/discover-leaderboard-comparison.png`
- Viewport: Flutter logical size 1120 × 776; macOS Retina capture 3024 × 1964.
- State: Simplified Chinese, light theme, Discover destination, Ranking tab selected, search empty and focused.
- Intentional product constraint: the source is a dark standalone web section, while the implementation preserves SkillsGo's light semantic theme, localized copy, Folder desktop shell, and existing result-card system. Fidelity is judged on component geometry, hierarchy, iconography, state behavior, and motion rather than literal source colors or English content.

## Evidence Reviewed

The combined image was opened and reviewed as one comparison input. The focused crop was required because the target is the leaderboard header rather than the surrounding app shell or result cards.

- Full view: the leaderboard header remains the first content region inside the existing Folder shell; results begin immediately below it without the former nested side rail.
- Focused region: title, 45 px flat search control, 1 px bottom rule, 24 px search-to-tabs gap, 16 px tab gaps, and 2 px selected underline preserve the source hierarchy and rhythm.
- Typography: the title, search copy, and tabs use SF Mono at 14 px with 20 px line rhythm. The localized Chinese title is intentionally shorter than the English source.
- Colors and tokens: foreground, muted text, divider, focus, and selected states are mapped to existing Material 3 semantic roles. No fixed source black or white was introduced.
- Images and assets: the target header contains no raster imagery. Search, sparkles, clear, link, alert, and empty-state icons all use HugeIcons `strokeRounded`, matching the primary navigation icon system; no handcrafted SVG or text-glyph substitute is used.
- Copy and content: labels are localized through ARB resources. Dynamic skill cards retain live Hub content.
- Responsive behavior: the header is constrained to the existing 1152 px content width, the `/` shortcut is hidden below 640 px, and the result grid retains its 1/2/3-column breakpoints.

## Primary Interactions Tested

- Entered `flutter ui`: tabs hid immediately, the search icon cross-faded to sparkles, and the debounced search state rendered.
- Entered a query: the leaderboard title and tab regions collapsed with a 200 ms ease-out layout reveal, moving the search field from logical y=138 to y=102 without a jump.
- Activated the clear control: the query cleared, the search field reversed from logical y=102 to y=138, tabs and the prior collection returned, and the field retained primary focus. The measured 100 ms midpoint was y=136.21, matching the source's front-loaded ease-out movement.
- Activated Ranking: selected semantics moved from Hot to Ranking and the 2 px underline completed its 150 ms transition without shifting layout.
- Keyboard and reduced-motion paths are covered by widget tests; reduced motion collapses tab, border, and icon durations to zero.
- Runtime console was checked through the active `flutter run` session. No Flutter exceptions were emitted; only a macOS input-method system warning appeared.

## Findings

No actionable P0, P1, or P2 mismatch remains.

- Accepted difference: source colors and English strings are not copied because SkillsGo's current semantic theme and i18n system are explicit product constraints.
- Accepted difference: result cards remain SkillsGo cards instead of cloning the source leaderboard rows; the requested fidelity scope is the search-and-tab discovery header within the current desktop system.
- P3 follow-up: a future compact leaderboard result presentation could reduce the density jump between the minimal header and the current cards, but it is outside this request and does not affect the replicated flow.

## Comparison History

### Pass 1

- Earlier finding: empty, link, and error states in the touched Discover screen still used Material icons, creating an icon-family inconsistency with the left navigation.
- Fix: replaced those icons with HugeIcons `strokeRounded` equivalents at 1.8 stroke width.
- Post-fix evidence: the final running capture and focused comparison show one consistent icon language; search and shortcut alignment remain unchanged.

### Pass 2

- No P0/P1/P2 findings. No further visual fixes were required.

### Pass 3

- Earlier finding: the first implementation hid and restored tabs immediately but kept the search field fixed, omitting the source's query-mode layout displacement.
- Source verification: the live source collapses the leaderboard heading from 20 px to 0 with opacity loss while the surrounding home content collapses; the input moves between its home and query positions over roughly 175–250 ms. The X and `/` controls themselves swap immediately and only their foreground color has a 150 ms transition.
- Fix: added a clipped height-and-opacity reveal for the title and tab regions using 200 ms `cubic-bezier(0, 0, 0.2, 1)`, with zero duration under reduced motion.
- Post-fix evidence: Marionette measured the Flutter input at y=138 before search, y=102 in query mode, y=136.21 after 100 ms of clearing, and y=138 at completion. A widget test covers both directions and focus restoration.

## Implementation Checklist

- [x] Preserve the existing Folder desktop shell and semantic theme.
- [x] Reproduce flat search geometry and keyboard shortcut affordance.
- [x] Implement search, clear, focus restoration, and collection restoration.
- [x] Implement non-sliding tab selection with 150 ms color/underline motion.
- [x] Cross-fade search and sparkles icons over 200 ms.
- [x] Use HugeIcons `strokeRounded` consistently.
- [x] Respect reduced motion and accessibility selection semantics.
- [x] Pass `flutter analyze` and the complete Flutter test suite.

final result: passed
