# Desktop Startup Experience Research

## Question and conclusion

SkillsGo currently exposes its native window before Flutter has rendered the product surface. The visible sequence—white window, then wallpaper, then components—is therefore expected from the current startup ordering rather than an unavoidable Flutter desktop behavior.

The strongest cross-platform pattern is:

1. create and configure the native window without mapping/showing it;
2. start Flutter and render a deliberately complete first surface;
3. show the native window only after that surface has been rasterized; and
4. move non-visual initialization behind that first surface.

For SkillsGo, “complete” must include the selected wallpaper being decoded. Merely waiting for Flutter's first frame is insufficient because `Image.asset` may initially paint nothing while its image is loaded and decoded.

This should be implemented as a short hidden-window launch gate, not as a decorative splash screen. If measured cold startup remains long enough that the absence of a window feels unresponsive, the fallback should be a small native launch surface whose color and geometry match the first Flutter surface, followed by a single replacement with the real App. It should not animate a fake progress indicator or reproduce the full Flutter UI natively.

## Evidence hierarchy

This research uses only first-party sources: Flutter framework/embedder API documentation and templates, the `window_manager` plugin's own repository, and Apple/GTK platform documentation. The recommendations below distinguish sourced platform behavior from project-specific inference.

## What the official startup primitives provide

### Flutter framework

Flutter exposes two useful but different gates:

- [`WidgetsBinding.deferFirstFrame`](https://api.flutter.dev/flutter/widgets/WidgetsBinding/deferFirstFrame.html) prevents produced frames from being sent to the engine until `allowFirstFrame` is called. Flutter documents it specifically for asynchronous initialization that must finish before the first rendered frame takes down a splash surface.
- [`WidgetsBinding.waitUntilFirstFrameRasterized`](https://api.flutter.dev/flutter/widgets/WidgetsBinding/waitUntilFirstFrameRasterized.html) completes after the engine has rasterized the first frame. Flutter notes that rasterization is normally very close to presentation and is the last expensive frame phase under Flutter's control.

`addPostFrameCallback` is not equivalent to either gate: it runs after the framework pipeline is flushed, not after rasterization/presentation. Flutter's own discussion of first-visible-frame instrumentation explicitly calls out this distinction ([Flutter issue 111628](https://github.com/flutter/flutter/issues/111628)).

`deferFirstFrame` is appropriate only when a real readiness condition exists. It should not be used to hold a hidden window while arbitrary network, Hub, or CLI work completes. Those dependencies need an immediately renderable loading/empty/error state under the App's asynchronous interaction policy.

### Official Flutter Windows runner

The current Flutter Windows application template creates the native window hidden, installs `FlutterEngine::SetNextFrameCallback`, shows the window from that callback, and calls `ForceRedraw` to cover the race where the first frame completed before callback registration ([official template](https://github.com/flutter/flutter/blob/master/packages/flutter_tools/templates/app/windows.tmpl/runner/flutter_window.cpp)). The public Windows embedder API documents [`SetNextFrameCallback`](https://api.flutter.dev/windows-embedder/classflutter_1_1_flutter_engine.html).

This is direct first-party evidence that the normal Flutter Windows design is “show on a Flutter frame,” not “show an empty host immediately.” SkillsGo's Windows runner still contains this template logic.

### Official Flutter Linux embedder and runner pattern

Flutter's Linux `FlView` has a `first-frame` signal and tracks whether the first frame has arrived ([Flutter Linux embedder source/API](https://api.flutter.dev/linux-embedder/fl__view_8cc.html)). Its public API also documents that the view background defaults to black and can be changed through [`fl_view_set_background_color`](https://api.flutter.dev/linux-embedder/fl__view_8h.html).

GTK distinguishes realization from visibility: realization creates the GDK resources, while mapping makes the window visible on screen ([GTK `realize`](https://docs.gtk.org/gtk3/vfunc.Widget.realize.html), [GTK `map-event`](https://docs.gtk.org/gtk3/signal.Widget.map-event.html)). This permits the Flutter view to be realized and render-capable while the top-level window remains unmapped. SkillsGo's Linux runner already follows this structure by realizing the view and showing the top-level window from `first-frame`.

### Flutter macOS embedder and AppKit

The standard Flutter macOS runner immediately installs a `FlutterViewController` in the storyboard-owned window; unlike the Windows and Linux templates, it does not expose a public first-frame show callback ([official macOS template](https://github.com/flutter/flutter/blob/master/packages/flutter_tools/templates/app/macos.tmpl/Runner/MainFlutterWindow.swift)). The macOS embedder does expose native background color control. Flutter documents that both the containing `NSWindow` and `FlutterViewController` have independent backgrounds, and that the Flutter view defaults to black unless explicitly changed ([Flutter macOS `FlutterViewController.backgroundColor`](https://api.flutter.dev/macos-embedder/interface_flutter_view_controller.html)).

AppKit can remove a window from the screen list with `orderOut` and later place it back with `orderFront`; Apple documents these window ordering operations under [`NSWindow`](https://developer.apple.com/documentation/appkit/nswindow) and [`orderFrontRegardless`](https://developer.apple.com/documentation/appkit/nswindow/orderfrontregardless%28%29). A project-specific macOS launch gate can therefore keep the storyboard window ordered out, then let Dart show it after `waitUntilFirstFrameRasterized`. The ordinary `orderFront`/key-window path should be preferred over `orderFrontRegardless`; Apple says the latter should rarely be needed.

### `window_manager`

The plugin's own quick-start example initializes the plugin, applies `WindowOptions`, and calls `show` from `waitUntilReadyToShow` ([official `window_manager` repository](https://github.com/leanflutter/window_manager)). That API means native window configuration is ready; it does not claim that the Flutter product frame or image assets have rasterized. Combining its callback with an immediate `show` before `runApp`, as SkillsGo currently does, defeats the official Windows/Linux runner first-frame gates.

## Repository diagnosis

### Current launch ordering

`app/lib/main.dart` currently performs the following work before `runApp`:

1. await logger initialization;
2. initialize Flutter bindings and error handlers;
3. initialize macOS window utilities where applicable;
4. await `windowManager.ensureInitialized`;
5. call `windowManager.waitUntilReadyToShow`;
6. call `windowManager.show` and `focus`; and only then
7. call `runApp`.

The white host is therefore intentionally visible while no Flutter widget tree exists. On Windows and Linux, Dart's explicit `show` races ahead of the native runner's existing first-frame show callback. On macOS, the transparent native window/background configuration makes any mismatch between the native host, the Flutter view's default background, and the first product pixels especially visible.

### The later wallpaper transition is a separate problem

`SkillsBackground` paints the wallpaper with `Image.asset`. The eleven wallpaper PNGs in `app/assets/backgrounds/` are approximately 665–801 KB each. `Image.asset` resolves and decodes through Flutter's image pipeline, so an uncached image is not guaranteed to contribute pixels to the same frame that first builds the widget.

The App also loads the persisted appearance asynchronously. Until that finishes, `AppShell` uses the default `AppearanceState`, including the default solar wallpaper. A returning user with a different persisted wallpaper can therefore see a default-wallpaper-to-selected-wallpaper swap even after the native blank-window issue is fixed.

Consequently, these are three distinct visual discontinuities:

| Discontinuity | Cause | Correct gate |
| --- | --- | --- |
| Native white/black host to Flutter | Window shown before Flutter pixels | Native window visibility / first rasterized frame |
| Flat Flutter background to wallpaper | Asset not decoded for the first visible frame | Selected wallpaper precache before releasing first frame |
| Default wallpaper to persisted wallpaper | Appearance preference resolves after initial build | Resolve the small local appearance snapshot before releasing first frame |

### Existing runner assessment

| Platform | Current native behavior | Assessment |
| --- | --- | --- |
| Windows | Hidden create; `SetNextFrameCallback` calls `Show`; `ForceRedraw` covers callback timing | Already aligned with Flutter's official template. Dart's early `windowManager.show` bypasses it. |
| Linux | Flutter view is realized; top-level GTK window is shown from the `first-frame` signal | Already aligned with the embedder/GTK model. Dart's early `windowManager.show` bypasses it. The hard-coded black view background also mismatches Dart's white `WindowOptions` background. |
| macOS | Storyboard window receives `FlutterViewController` immediately; no first-frame visibility gate | Needs an explicit project-owned hidden/show lifecycle or, as a weaker fallback, exactly matched native and Flutter backgrounds. Both `NSWindow` and `FlutterViewController.backgroundColor` must be considered. |

## Recommended SkillsGo design

### Preferred launch contract

Define one observable contract: **the main window may become visible only after the engine has rasterized a frame containing the resolved theme, resolved wallpaper choice, decoded wallpaper pixels, and a stable startup shell**.

The stable shell may contain the existing geometry-preserving onboarding skeleton. It must not wait for the CLI handshake, Hub availability, Cloud ranking, Library inventory, or onboarding I/O beyond the minimum local flag needed to select the first route. Product data continues loading after the window is visible and renders through the App's explicit asynchronous states.

Recommended sequence:

1. initialize the binding and install synchronous error capture;
2. keep the native main window hidden;
3. apply final size, minimum size, centering, and titlebar configuration without showing/focusing;
4. call `deferFirstFrame`;
5. run a minimal startup root immediately;
6. load the local appearance snapshot and the minimum local route/onboarding state in parallel;
7. precache only the selected wallpaper (not all eleven assets);
8. build the stable startup/product shell with those resolved values;
9. call `allowFirstFrame`;
10. await `waitUntilFirstFrameRasterized`;
11. show and focus the window once; and
12. continue CLI, Hub, Cloud, and other data work inside visible asynchronous surfaces.

The implementation must have a bounded fallback for corrupted preferences or failed asset decoding: log the failure, use the default appearance and a semantic solid background, release the first frame, and show the window. A launch gate must never leave a headless process running indefinitely.

### Platform ownership

Use one authority for visibility:

- Windows and Linux should preferably retain their existing native first-frame callbacks and stop Dart from showing the window early. If Dart must wait beyond the engine's literal first frame to include a decoded wallpaper, defer that first engine frame until the launch surface is complete.
- macOS should order the main window out before it becomes visible and use the Dart rasterized-frame signal to show it. Configure the `NSWindow` and `FlutterViewController` to the same semantic launch background as a safety net.
- `window_manager` should own geometry/titlebar operations that genuinely require it, but `waitUntilReadyToShow` should not be treated as content readiness.

This avoids two independent show callbacks competing. The launch path should also be idempotent so integration tests and hot restart do not repeatedly hide a window that is already presenting valid Flutter content.

### Native splash fallback

A native launch surface is justified only if measurement shows that a hidden-window launch feels broken on supported hardware. If used, keep it deliberately modest:

- same initial geometry and semantic background as the Flutter shell;
- product mark plus an optional static loading label;
- no fake determinate progress;
- no duplicate navigation or controls; and
- remove it only when Flutter reports a rasterized, content-ready frame.

This is a fallback for latency communication, not the primary fix. Showing a branded native surface and then separately assembling wallpaper and components would merely replace one multi-stage flash with another.

## What not to do

- Do not call `windowManager.show` before `runApp`.
- Do not equate `waitUntilReadyToShow` with Flutter content readiness.
- Do not use only `addPostFrameCallback` to decide that the user can see the frame.
- Do not wait for remote services or the long-lived CLI session before releasing the first visible shell.
- Do not precache every wallpaper; only the persisted selection is needed for first paint.
- Do not use transparency as a substitute for a launch contract. Transparent layers can expose the desktop, default black Flutter view, or compositor differences and make flashes more obvious.
- Do not add an animated splash whose own shader/image/font warm-up creates another first-frame transition.

## Validation plan

Evaluate profile and release builds; debug/JIT startup is not representative. Capture cold launches on macOS arm64 and x64, Windows x64, Linux X11, and Linux Wayland where available.

Required assertions:

1. no top-level window is mapped before the content-ready Flutter frame;
2. the first captured visible frame already contains either the selected wallpaper or the documented solid-color fallback;
3. a non-default persisted wallpaper never flashes the default wallpaper first;
4. corrupted preference and missing/failed image paths still show a usable window within a bounded duration;
5. Windows and Linux show exactly once despite their native first-frame callbacks;
6. macOS never exposes the Flutter view's default black layer or an unmatched transparent host;
7. startup remains correct under hot restart and the integration-test-safe `runSkillsGoApp` path; and
8. time-to-first-window and time-to-interactive-shell are logged separately.

For visual verification, record the window region at display refresh rate and inspect every frame from process launch through stable shell. Logs alone cannot prove the absence of a one-frame flash.

## Decision summary

SkillsGo does not need a more elaborate loading animation. It needs a single, explicit presentation boundary. Preserve the native Windows/Linux first-frame behavior, add an equivalent macOS lifecycle, resolve the small local appearance state, decode the selected wallpaper before releasing the first engine frame, and move all non-visual startup work behind the visible shell. This produces the desktop convention users perceive as polished: the window appears once, already composed, and then its data states evolve without reconstructing the surface.
