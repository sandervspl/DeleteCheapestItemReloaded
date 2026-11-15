# Profiles system research

Status: Implemented with AceDB and native profile controls. Ignored items remain
per character; window positions/sizes and minimap position/visibility are per
profile. In-game verification remains outstanding. The research below records
the alternatives and implementation rationale.

## Recommendation

Use AceDB-3.0 for profile storage and operations, with a small Profiles section in
the existing settings UI. A custom manager is a reasonable alternative if avoiding
another library matters more than reusing established profile machinery. Copy-only
presets are a smaller feature if sharing subsequent edits is undesirable.

These are design recommendations, not claims that any implementation has been
validated in-game. Pin and verify the selected library revision on all four clients
before shipping, especially Forever.

## Implementation options

| Option | What it provides | Cost and limitations |
| --- | --- | --- |
| AceDB backend, existing UI | Named shared profiles, character selection, defaults, copy/reset/delete operations and callbacks | New vendored library; addon still owns migration and applying changes |
| AceDB plus AceDBOptions | Same backend with a standard profile options table | AceDBOptions targets AceConfig; this addon currently uses hand-built controls, so rendering that table introduces more UI infrastructure |
| Custom manager | Account-wide profiles table, per-character selection and purpose-built controls | Fits current code, but we own copying, validation, deletion references, defaults, migration and schema upgrades |
| Copy-only presets | Save named snapshots and apply a deep copy to character settings | Simple semantics and no live sharing; applying a preset does not keep characters linked |

AceDB explicitly supports separate profile, character and global scopes. Its
default profile can be character-specific or a shared named profile. [API][ace-api]
The library need not replace the current settings UI. AceDBOptions returns an
AceConfig options table; using that UI helper is a separate decision. [Options API][ace-options]

## Popular addon references

- **Bartender4:** initializes AceDB and wires profile changed/copied/reset callbacks
  to `UpdateModuleConfigs`, which refreshes modules and the minimap settings
  reference. Optional LibDualSpec adds specialization switching, excluding Classic
  Era. This is the closest reference for a small addon. [Source][bartender]
- **ElvUI:** uses AceDB and AceDBOptions with separate profile, private and global
  data. Its export UI exposes those scopes. A custom distribution layer filters
  nonportable data and adds versioned encoding. The lesson is to separate data
  scopes before implementing sharing; its full distribution stack is unnecessary
  for a first DCI release. [Initialization][elv-init], [distribution][elv-export],
  [official export guide][elv-guide]
- **Details:** uses its own `__profiles` collection and character `active_profile`
  selection, with create/list/erase/reset/apply operations. Its deletion logic has
  a fallback for the active profile; imports take a destination and overwrite
  choice. This is a concrete example of the custom-manager option. [Source][details]
- **WeakAuras:** useful as an import/export reference rather than a whole-addon
  profile model. Transmission uses LibSerialize, LibDeflate, printable encoding and
  a version prefix, with older decoding paths retained. Portable strings should
  be a separate feature with validation and a versioned envelope. [Source][wa]

These are source-level observations from the linked upstream branches, not
claims about testing those addons on DCI's supported clients.

## Current addon fit

The [TOC](../DeleteCheapestItem.toc) declares `DCI_DB` as
`SavedVariablesPerCharacter`. The flat settings table and defaults live in
`DCI.InitializeSavedVariables` in [DeleteCheapestItem.lua](../DeleteCheapestItem.lua).
There is no profile abstraction today. Existing dependencies are documented in
[Libs/README.md](../Libs/README.md); neither AceDB nor AceConfig is bundled.

Most settings handlers access `DCI_DB` dynamically. That reduces the migration
surface, but simply rebinding the global is insufficient: persistence and
character-only data must be separated first. Keep the old variable as migration
input and introduce a distinct account-wide root, for example `DCI_ProfilesDB`.
Do not use one persisted variable simultaneously as the legacy character database
and the selected shared profile.

Confirmed scope decisions:

- Ignored items remain per character, independent of the selected profile.
- Window positions and sizes, and minimap position and visibility, belong to the selected profile.

Proposed remaining scope:

- Profile: auction valuation, sorting, quality/soulbound filters, confirmation
  threshold, automatic window triggers, low-slot threshold and display preferences.
- Character: selected profile.
- Session: debug mode, pending work, bag/item caches, dismissal flags and current
  quest/loot context.

Selecting, copying or resetting a profile must preserve the current character's
ignored items. Position edits affect all characters using the same profile;
copying a profile must make independent copies of its position tables. Window sizes and minimap visibility also belong to the profile, as confirmed
by the user.

## Suggested first release

- Show the active profile and provide create, select, copy from, reset and delete.
  Add rename only with explicit reference-update semantics.
- Explain that selecting shares future edits, while copying creates independent
  settings. Confirm destructive replacement/reset and identify shared impact.
- Preserve each existing character's settings in its own uniquely named profile
  on first login. Never let every migrating character overwrite one shared Default.
- Keep ignored-item protections per character and window/minimap positions per
  profile, as confirmed by the user. Define defaults for new characters separately.
- Defer spec switching, cross-account export/import and layered inheritance until
  requested. None is necessary to solve sharing settings between alts.

## Migration and applying a switch

1. Initialize after this addon's saved data loads; the existing handler runs on
   `ADDON_LOADED`. AceDB's tutorial also requires initialization after that event.
   [Tutorial][ace-tutorial]
2. Version the new schema and make migration idempotent. Retain a legacy snapshot
   and per-character migration marker. Migrate other characters when they log in;
   do not promise automatic reading of every alt's unloaded per-character table.
3. Deep-copy nested data when copying or migrating. Existing nested fields include
   `IgnoredItems`, `Minimap`, `WindowPosition`, `WindowSize` and `IgnoredWindowSize`.
4. Centralize applying settings. Cancel pending loot/bag work and stale deletion
   confirmation; finish/cancel dragging or resizing before rebinding storage.
5. Refresh event subscriptions, cached auction values, item rows, ignored rows,
   settings controls, theme and applicable geometry. The existing auction-cut
   checkbox clears `DCI.ItemInfo`, demonstrating that a table swap alone misses
   derived values. Profile switching should perform the equivalent invalidation.
6. Refresh borrowed references: [Broker.lua](../Broker.lua) already calls
   `LibDBIcon:Refresh` when settings are replaced. Reset currently replaces the
   whole `DCI_DB`; profile reset must instead target the selected scope.
7. Keep load-only behavior separate: the current initializer also disables debug
   output, so it is not an unchanged reusable switch handler.

AceDB provides change/copy/reset callbacks, but addon code must apply the changes.
Its delete operation rejects the active profile and clears other characters'
references to a deleted profile. Copy resets the target before copying; it is a
replacement operation rather than a merge. A custom UI must describe these
semantics accurately. [Implementation][ace-source]

## Verification needed before implementation is considered complete

Use the existing Lua harness for meaningful behavior checks, followed by in-game
checks on all four clients. Cover two characters migrating different settings;
shared edits versus independent copies; character-local ignored items surviving
profile operations; profile-owned positions switching and copying independently;
nested-table isolation; deleting a profile
referenced by another character; switching with a pending popup/timer; auction
cache invalidation; minimap rebinding; and reload persistence. Record client builds,
repeatable steps and observed results. Automated implementation checks and manual verification steps are recorded in
[profile verification](profiles-verification.md).

## Blizzard client reference

The helper was run for each supported branch and the checkout inspected
sequentially. Forever was inspected directly as Camelot.

| Client branch | Inspected commit | Representative source |
| --- | --- | --- |
| `classic_era` | `4192ac60067f` | [Settings registration][era-settings] |
| `classic_anniversary` | `68e0a2ec559d` | [Canvas callbacks][ann-settings] |
| `classic` (Mists) | `e5d9b3a22c3f` | [Settings implementation guide][mists-settings] |
| `forever` | `bebcb6bf309c` | [Region API definitions][forever-region] |

On all four branches, consulted files under `Interface/AddOns/` include:

- `Blizzard_Settings_Shared/Blizzard_Settings.lua`: canvas category and addon
  category registration.
- `Blizzard_Settings_Shared/Blizzard_SettingsPanel.lua`: `OnDefault` and
  `OnRefresh` canvas hooks.
- `Blizzard_Settings_Shared/Blizzard_ImplementationReadme.lua`: addon-defined
  canvas frames and optional lifecycle hooks.
- `Blizzard_APIDocumentationGenerated/AddOnsDocumentation.lua` and
  `SystemDocumentation.lua`: `ADDON_LOADED` and `PLAYER_LOGIN` definitions.
- `Blizzard_APIDocumentationGenerated/LocaleDocumentation.lua` and
  `ExpansionDocumentation.lua`: region API definitions.

The shared canvas APIs support keeping the current settings UI and adding custom
profile controls. They do not provide DCI's profile model or migration logic.
Preserve existing registration timing; the Settings registrar also has its own
startup prerequisites (`Blizzard_SettingsRegistrar.lua`, inspected on Era, Mists
and Forever).

One concrete compatibility check remains: the AceDB source reviewed calls
`GetCurrentRegionName`. Generated documentation lists that API on Forever, but
not in the other three inspected branches' expansion documentation. That absence
does not establish runtime absence. Test a pinned library version on every
supported client before choosing it for release.

## Sources

[ace-api]: https://www.wowace.com/projects/ace3/pages/api/ace-db-3-0
[ace-tutorial]: https://www.wowace.com/projects/ace3/pages/ace-db-3-0-tutorial
[ace-options]: https://www.wowace.com/projects/ace3/pages/api/ace-dboptions-3-0
[ace-source]: https://github.com/WoWUIDev/Ace3/blob/master/AceDB-3.0/AceDB-3.0.lua
[bartender]: https://github.com/Nevcairiel/Bartender4/blob/master/Bartender4.lua
[elv-init]: https://github.com/tukui-org/ElvUI/blob/main/ElvUI/Game/Shared/General/Initialize.lua
[elv-export]: https://github.com/tukui-org/ElvUI/blob/main/ElvUI/Game/Shared/General/Distributor.lua
[elv-guide]: https://github.com/tukui-org/ElvUI/wiki/export
[details]: https://github.com/Tercioo/Details-Damage-Meter/blob/master/functions/profiles.lua
[wa]: https://github.com/WeakAuras/WeakAuras2/blob/main/WeakAuras/Transmission.lua
[era-settings]: https://github.com/Gethe/wow-ui-source/blob/4192ac60067f/Interface/AddOns/Blizzard_Settings_Shared/Blizzard_Settings.lua
[ann-settings]: https://github.com/Gethe/wow-ui-source/blob/68e0a2ec559d/Interface/AddOns/Blizzard_Settings_Shared/Blizzard_SettingsPanel.lua
[mists-settings]: https://github.com/Gethe/wow-ui-source/blob/e5d9b3a22c3f/Interface/AddOns/Blizzard_Settings_Shared/Blizzard_ImplementationReadme.lua
[forever-region]: https://github.com/Gethe/wow-ui-source/blob/bebcb6bf309c/Interface/AddOns/Blizzard_APIDocumentationGenerated/ExpansionDocumentation.lua
