# M6 — Package as an installable `.app`

> User request (2026-07-04): make an app installed in `/Applications` so it can be launched quickly
> whenever needed (Spotlight / Launchpad). Menu-bar agent, no dock icon. Follows `../AGENTS.md`.

## Approach — a repeatable packaging script `tools/build_app.sh`
1. `swift build -c release` (release binary + the `SplitForge_SplitForgeCore` resource bundle).
2. Assemble `SplitForge.app`:
   - `Contents/MacOS/SplitForge` ← the release binary.
   - **`Contents/Resources/SplitForge_SplitForgeCore.bundle`** ← the SwiftPM resource bundle. This is
     where `Bundle.module` resolves it (`Bundle.main.resourceURL` = `Contents/Resources/`), so
     `DefinitionLoader.loadBundled("totem")` finds `totem.json`. **No app code change.**
   - `Contents/Info.plist` with: `CFBundleIdentifier=com.splitforge.app`, `CFBundleName=SplitForge`,
     `CFBundleExecutable=SplitForge`, `CFBundlePackageType=APPL`, `CFBundleInfoDictionaryVersion=6.0`,
     `CFBundleShortVersionString=0.1`, `CFBundleVersion=1`, `CFBundleDevelopmentRegion=en`,
     **`LSUIElement=true`** (agent — no dock icon, matches `.accessory`), `LSMinimumSystemVersion=13.0`.
3. **Code sign the app** (ad-hoc). The `SplitForge_SplitForgeCore` resource bundle is **data only**
   (no Mach-O), so it can't be independently code-signed (`codesign` rejects it: "bundle format
   unrecognized") — it's sealed as a resource by the app's signature. Sign after assembly is final
   (any later file change invalidates it); `--deep` is deprecated so we sign explicitly, and keep the
   verify as its own statement (an `&&` list is exempt from `set -e`, so a bad signature would slip through):
   - `codesign --force -s - SplitForge.app`
   - `codesign --verify --strict SplitForge.app`  (own line → aborts on failure)
4. Install: **quit any running instance** (the dev binary and any installed app), then copy to
   `/Applications/SplitForge.app`. The script checks `/Applications` is writable at runtime and falls
   back to `~/Applications` if not (no sudo).

## Verification (packaging has no unit-testable logic → verify by running)
- Launch `/Applications/SplitForge.app` from Spotlight → menu bar item + overlay appear.
- **Hard requirement:** the overlay renders the *keyboard* (not a stuck "Reading keymap…"), proving
  `Bundle.module` found `totem.json`. A `resourceNotFound` / no-keyboard render = FAIL → move the
  `.bundle` and re-verify. (I'll confirm the bundle path resolves before declaring done.)
- After granting Input Monitoring: switching layers glows the overlay.
- `swift test` stays green (core unchanged).

## First-launch notes (documented in README)
- macOS prompts for **Input Monitoring** for the new app (TCC keys on the new bundle id/signature — the
  dev-binary grant doesn't carry over). Grant it once.
- Ad-hoc signatures change per rebuild; if a reinstall doesn't re-prompt and the app can't read the
  keymap, reset TCC: **`tccutil reset ListenEvent com.splitforge.app`**, then relaunch and re-grant.
- Launch by name "SplitForge" from Spotlight/Launchpad. No dock icon (menu-bar agent).

## Definition of done
`tools/build_app.sh` builds + installs `SplitForge.app`; it launches from Spotlight and renders the
keyboard (resource resolves); README documents build/install + Input-Monitoring + the tccutil recovery;
fresh-critic approves the script + Info.plist; `PLAN.md` M6 → ✅.

## Simplicity guardrails
- One script; no DMG/notarization (overkill for a personal local install — ad-hoc sign suffices).
- Resource bundle in `Contents/Resources/` (Bundle.module's standard location) — no app code changes.
- Launch-at-login (`SMAppService`) stays an optional M5 follow-up; M6 is only "installable + launchable".

## Decision for the user
- Install to **`/Applications`** (recommended; writable, standard, in Spotlight/Launchpad) vs
  `~/Applications` (user-only). Default: `/Applications`.
