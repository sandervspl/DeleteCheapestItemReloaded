# Profile verification

## Automated checks

Run the existing suite with `busted --lua=lua5.1`, then run
`./Tests/copy_to_wow_spec.ps1` in PowerShell. The shipped TOC loads the real
AceDB, LibDataBroker and LibDBIcon sources in the WoW mock.

`Tests/profiles_spec.lua` exercises two characters migrating different settings,
deliberate shared edits, independent copies, ignored-item isolation, resets,
deletion references, reloads, both windows' presentation state, minimap rebinding,
interrupted resizing, stale deletion callbacks, event subscriptions and cache
invalidation on each of the four supported client fixtures. Empty copy/delete
actions are disabled with explanations, then re-enabled when eligible profiles
become available; referenced profiles remain copyable but cannot be deleted.

Local results: 244 passed, 0 failed using Lua 5.1 through Lupa plus the existing
luassert synchronous runner (`python .cache/run-specs.py`); Lua 5.1 syntax passed.
The standard Busted command delegates to unavailable WSL on this machine, so the
local run used that alternate runner. CI runs Busted directly on Ubuntu.
The PowerShell deployment fixture also passed, including the new runtime files,
all bundled libraries, saved-file preservation, beta/PTR discovery and WhatIf.
These mock checks do not establish in-game rendering or client compatibility.

## Repeatable in-game check

Perform on Classic Era, Anniversary, Mists and Forever. Use two characters with
different existing settings and different ignored lists. Back up their saved
variables before installation.

1. Log into character A and open Settings. Verify its original filters, ignored
   items, sizes and minimap settings survived. Record the migrated profile name.
2. Create `Shared inventory`, change the quality filter and automatic display
   settings, move/resize both windows and move/hide the minimap button. Reload
   and verify the entire setup survived.
3. Log into character B. Verify its own legacy settings migrated independently.
   Select `Shared inventory`; verify A's settings and layout appear while B's
   ignored list stays unchanged. Edit the shared profile and reload.
4. Return to A and confirm B's shared edit appears. Create `Independent copy`,
   use Copy from on the shared profile and accept the replacement. Move a window
   and change its size/minimap visibility. Switch back and verify the shared
   profile's layout was not changed by editing the copy.
5. Open a deletion confirmation for an eligible stack and leave it unanswered.
   Switch profiles. Verify the confirmation closes and no item is deleted.
   Change automatic display settings through a profile switch while bags/loot
   are open; verify stale queued work does not reopen an unwanted window.
6. Reset the copy and verify defaults and both window sizes return while the
   character's ignored list remains. Cancel a second reset and verify no change.
7. With only one profile, verify Copy from and Delete unused profile are disabled
   with small explanations below them. Create another profile and verify both
   controls enable and the explanations disappear. Verify a profile selected by
   either character cannot be deleted. Select away
   from the independent copy, delete it through confirmation and reload to
   verify it stays deleted. Verify the broker launcher still works with the
   minimap button hidden.

Record the client build, migrated profile names, each step's result and screenshots
of the Profiles controls, distinct layouts and ignored lists. Keep this record as
the repeatable verification artifact. No in-game checks have been performed yet.

## Blizzard reference inspected before implementation

Inspected sequentially using `scripts/sync-wow-ui-source.sh`:

- `classic_era` at `4192ac60067f`
- `classic_anniversary` at `68e0a2ec559d`
- `classic` (Mists) at `e5d9b3a22c3f`
- `forever` (Camelot) at `bebcb6bf309c`

Under `Interface/AddOns`, consulted
`Blizzard_Settings_Shared/Blizzard_Settings.lua` and `Blizzard_SettingsPanel.lua`
for canvas registration and refresh/default callbacks;
`Blizzard_StaticPopup/StaticPopup.lua` for show/hide and confirmation lifecycle;
and generated `LocaleDocumentation.lua` and `ExpansionDocumentation.lua` for
region APIs. Existing research also covers generated AddOns/System event
definitions. Forever's generated `UnitDocumentation.lua` and menu implementation
guide were additionally consulted for naming and dropdown behavior.

The empty-action follow-up re-inspected the same four branch commits sequentially,
consulting `Blizzard_Menu/DropdownButton.lua` (`OpenMenu` rejects disabled buttons)
and `Blizzard_Menu/MenuTemplates.lua` (dropdown button-state handling). The Classic
and Mainline menu templates were also inspected on Forever for native styling.
