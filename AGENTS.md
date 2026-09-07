# Local Agent Instructions

## Mandatory Installed-App Handoff

Every completed WinMux code change must end with the edited build installed at `/Applications/WinMux.app`. A change is not complete while it exists only in the source tree or build artifacts.

Follow this sequence after editing and testing:

1. Build and sign the replacement app before stopping the currently installed instance. Use the repository's configured persistent signing identity and keep the bundle identifier `com.zimengxiong.winmux` unchanged.
2. Before touching `/Applications/WinMux.app`, prove that the candidate still satisfies the existing Accessibility permission's code requirement:

  ```bash
  ALLOW_TCC_REAUTH=0 /bin/bash script/assert-accessibility-grant-will-survive.sh \
    <candidate-app>/Contents/MacOS/WinMux \
    com.zimengxiong.winmux \
    /Applications/WinMux.app
  ```

   A failure is a hard stop. Do not replace the installed app, use ad-hoc signing, reset TCC, or ask the user to re-authorize. Fix the candidate's signing configuration instead.
3. Record the existing WinMux PID, quit it cleanly, and wait until that PID has exited. Do not copy over the app bundle or open the candidate while the old process is still alive.
4. Replace `/Applications/WinMux.app` with the verified candidate, clear quarantine if necessary, and verify the installed bundle's signature.
5. Open `/Applications/WinMux.app` only after replacement is complete. Confirm that a new WinMux PID is running from `/Applications/WinMux.app/Contents/MacOS/WinMux` and that the old PID is gone.

The canonical repository workflow is `make install`, which builds the release archive, signs it using the configured identity, runs the Accessibility-grant compatibility check, quits the existing app, installs the new bundle, and reopens it. After the command finishes, independently verify the old PID exited and the new installed executable is running. If the workflow cannot guarantee those checks, stop and fix the install workflow rather than performing an unsafe manual replacement.

Never finish a WinMux implementation task without completing this installed-app handoff, unless the user explicitly tells you not to install or relaunch it.

## UI Design Tokens

- Use `GeistColorTokens` and the `WinMuxOverlayPalette`/`winMuxOverlay*` helpers for every rendered UI colour. Do not introduce literal `Color` or `NSColor` values outside the token definitions, dynamic user-configured colours, or explicit transparency/mask tokens in `DesignTokens.swift`.
- Prefer the named `WinMuxSpacing` roles for UI spacing, padding, insets, and fixed visual offsets. If no role fits, use a clear `standardGap` multiple (including half-step multiples); do not introduce raw numeric layout spacing values.

## Version Control

- After every completed code, configuration, or documentation change, commit the scoped changes and push the current branch to `origin` before handing off.
- Do not include unrelated pre-existing worktree changes in a commit. If a push fails, report it immediately and resolve it before continuing with additional changes.

## UI Terminology

- **Tab bar**: top left; switches workspaces.
- **Widget bar**: top right; displays widgets.
- **Window stack**: a group of windows stacked together.
- **Stack tabs**: tabs for switching windows within a stack.

Use these names in UI copy, documentation, and discussions. Existing internal `WorkspaceSidebar` and configuration identifiers remain compatible.

The tab bar is horizontal and is not expandable. Do not restore a vertical sidebar or an expansion control. Keep both bars within the system menu-bar area, including any visual top inset.
