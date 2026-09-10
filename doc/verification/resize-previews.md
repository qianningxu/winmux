# Native resize previews — 2026-09-10

## Behavior

Based on upstream WinMux `e0ad328e109cb6d2f86b1bdbc3aea9bf7bc5935e`, specifically `mouse/resize/resizeWithMouse.swift` and `mouse/driver/WindowMouseInteractionOpacity.swift`: park neighboring native windows off screen while presenting their proposed layout, then restore native windows after release. Opacity alone does not reliably hide foreign-window edges.

The user requested shading on **both** sides with app icons and without preview bars. Both previews are committed in the same compositor transaction. The opaque backing uses the existing workspace canvas color, covers the divider and outer margins, and stops below the project tabs. Final native writes finish beneath the preview before reveal; parked windows are not restored to obsolete pre-drag frames.

The existing minimum-layout calculation still includes inactive tabs. The initial pointer offset is preserved. Resize sessions have unique identities; stale calibration callbacks are rejected, queued AX writes are canceled on stop, and the event constraint expires and clears on mouse-up or a disabled event tap.

## Verification

Installed signed app, Built-in Retina Display, 1728 × 1117 logical points:

- Fast 120-point Figma resize, including reversal before release.
- Fast 100-point ChatGPT resize from the opposite side.
- Slow and fast 500-point attempts beyond the Figma minimum, hold, and reversal.
- Slow Safari resize with Figma inactive.
- Fast limit attempt with Safari active and Figma inactive.
- Fast 80-point resize of unfocused Safari; native width reached 980 then returned to 900.
- Every completed scripted round trip returned to the same native 900/810 widths and 6-point gap.
- 737 final two-pane preview trace samples: gap minimum/maximum **6/6**, Figma/Safari stack minimum **900**.
- Inspected screenshots during drag and after release: both shaded panes; no preview bars; workspace-colored gaps; no native corner slivers; native windows and normal chrome restored.

During a drag, native-neighbor coordinates intentionally describe parked windows. Gap measurements above use the shared preview geometry, not those hidden native frames.

Pure-source checks passed for event-gate expiry, negative-origin bounds, immutable pointer offsets, reversal after correction, and native minimum learning. Focused XCTest cases were added for expired constraints and distinct same-window resize sessions. Full XCTest execution is unavailable in this machine's CommandLineTools environment (`no such module XCTest`).

Only one physical monitor was available, so cross-monitor live testing remains unverified. The final automated suite did not separately exercise tab reordering or native move gestures; their existing presentation paths retain the default detailed preview.

## Installed handoff

`make install` built and signed the combined source snapshot, passed the Accessibility code-requirement preflight, and replaced PID 97298 with PID 99972 at `/Applications/WinMux.app/Contents/MacOS/WinMux`. Independently verified the old PID exited, the installed signature, and identical installed/candidate SHA-256:

`e29852e8ed2ba56cfa817d05868da6e6d908b13c8f95b12f9b39dd563dcdb5a2`

Local evidence: `/tmp/winmux-final-*.json`, `/tmp/winmux-final-shade-drag.png`, `/tmp/winmux-final-shade-release.png`, `/tmp/winmux-resize-trace.log`, and `/tmp/winmux-gap-match-install.log`.
