# DeleteCheapestItem Reloaded

Continued maintenance by **Sander Vispoel (sandervspl)** of Delete Cheapest Item.
Shows inexpensive bag stacks when your inventory fills up, so you can choose what
to delete, sell at a vendor, or add to your ignore list.

## Supported clients

| Client | Version | Interface |
| --- | --- | --- |
| Classic Era (including Hardcore and Season of Discovery) | 1.15.9 | 11509 |
| Burning Crusade Classic Anniversary | 2.5.6 | 20506 |
| Mists of Pandaria Classic | 5.5.4 | 50504 |
| Forever | 1.60.1 | 16001 |

These versions were checked against Blizzard's UI sources on September 24, 2026.
See [the compatibility reference](docs/compatibility.md) for exact upstream commits,
API changes, and the in-game verification checklist. Retail and Cataclysm are not
part of this release's support matrix.

## Install and use

Extract the release ZIP into the selected client's `Interface/AddOns` directory.
The resulting manifest must be `Interface/AddOns/DeleteCheapestItem/DeleteCheapestItem.toc`.
For a source checkout, copy the two runtime Lua files and the TOC into that same folder.

The installed addon is named **DeleteCheapestItem Reloaded**. Its folder remains
`DeleteCheapestItem` so WoW continues to load your existing per-character `DCI_DB`
settings and ignored items. Replace the original installation rather than loading
two copies. Keep your `WTF` saved-variable files when upgrading.

- `/dci` toggles the window.
- Click the information button for Settings.
- Click an item icon to ignore it; use **Reset Ignored Items** to clear the list.
- Delete a displayed stack or sell it while a merchant is open.
- Configure quality filters, soulbound filtering, confirmation, automatic display,
  combat visibility, and optional auction prices in Settings.

**Allow window in combat** is enabled for new characters and when resetting
settings. Existing saved choices are preserved; if it is currently off, enable it
under **Window Behavior** to keep the window visible during combat.

The inherited auction integrations are Auctionator, AuctionLite, Auctioneer,
AuctionMaster, and TradeSkillMaster. Without one, the addon uses vendor values.
Existing translations are retained; the new product name is the same in every locale.

## Debugging a missing or disappearing window

After installing the updated files and running `/reload`, use `/dci debug on`,
then reproduce the problem. Chat will show timestamped loot/error/combat events,
window show/hide reasons, pending opening requests, free bag slots, and the current
combat/automatic-loot settings. This focused trace does not dump item prices.

Use `/dci status` immediately after a disappearance for the current state and last
visibility change; this command does not open or close the window. Share the chat
lines from the inventory-full error through the disappearance. `/dci debug off`
stops the focused trace, and `/reload` also turns it off. The existing **Show Debug
Output** setting independently enables the more verbose diagnostics.

`hidden: LOOT_CLOSED` means the game reported that looting ended; `hidden: combat`
means the combat visibility setting hid the window. `close button or external hide`
means the hide did not come from one of the addon's automatic closing decisions.
`shown=yes visible=no` can indicate that a parent frame, such as the main UI, is hidden.

## Development and tests

The test setup follows [BuffTimers](https://github.com/sandervspl/BuffTimers):
Lua 5.1, Busted, and an optional Mechanic entry point. Tests load the actual TOC and
runtime in an isolated WoW API mock, exercise both Classic buttons and Forever's
ScrollBox loot events, and cover item sorting, filters, item-cache events, settings,
saved variables, and deletion/selling safeguards.

On Ubuntu or WSL:

```sh
sudo apt-get install lua5.1 lua-busted
busted --lua=lua5.1
luac5.1 -p DeleteCheapestItem.lua Localization.lua Tests/*.lua
```

To use the same Mechanic version as BuffTimers:

```sh
git clone --branch v1.4.2 --depth 1 https://github.com/Falkicon/Mechanic.git ../Mechanic
python -m pip install --editable ../Mechanic/desktop
mech call addon.test '{"addon":"DeleteCheapestItem","path":"."}'
```

On Windows, run Busted through WSL (or the `busted.bat` wrapper installed by Mechanic).
Mechanic must be able to find a working Busted executable. CI also runs Busted
directly so a wrapper cannot hide a failing test exit status.

PowerShell deployment tests run without a WoW installation:

```powershell
./Tests/copy_to_wow_spec.ps1
```

## Local deployment

The PowerShell helper uses BuffTimers' installation discovery. It copies the three
runtime files into installed clients, including Classic beta and PTR, and leaves
`WTF` and unrelated addon files alone. Preview the detected destinations before copying:

```powershell
./scripts/copy-to-wow.ps1 -WhatIf
./scripts/copy-to-wow.ps1
```

For a nonstandard location or just one client:

```powershell
./scripts/copy-to-wow.ps1 -WowRoot 'D:\Games\World of Warcraft\_anniversary_' -WhatIf
./scripts/copy-to-wow.ps1 -WowRoot 'D:\Games\World of Warcraft\_anniversary_'
```

Client discovery recognizes folders named `_..._` containing `.flavor.info` or a
`Wow*.exe` file, without filtering product names or executable versions. Like
BuffTimers, this also copies to installed Retail clients; the supported runtime
versions remain listed above. Use `-WowRoot` with a client directory to target just
that installation. Exit WoW before installing files, then launch it and check the
addon in the character selection AddOns list.

## Releases

Push a version tag such as `v0.0.2` to run `.github/workflows/release.yml`. It runs
the tests first, then uses the BigWigs packager to build and publish one ZIP for all
four clients. The archive is named `DeleteCheapestItem-Reloaded-v0.0.2.zip`; the
packager substitutes the tag for `@project-version@`. Unpackaged checkouts display
`7.0.0-dev`.

The TOC identifies the [Reloaded CurseForge project](https://www.curseforge.com/wow/addons/delete-cheapest-item-reloaded)
with `## X-Curse-Project-ID: 1710300`. The release workflow passes the repository's
`CF_API_KEY` secret to the packager. This must be a CurseForge author API token
with access to that project; manage it in GitHub **Settings > Secrets and variables
> Actions**. GitHub releases use the automatic `GITHUB_TOKEN` with `contents: write`.
The packager requires both the project ID and token for a CurseForge upload; a
successful GitHub release alone does not confirm that CurseForge received a file.

To publish the next version:

1. Review and commit the intended changes, including the TOC's project ID and the
   changelog. Local uncommitted changes are not included in a release.
2. Push the commit, then create and push a new version tag on that commit. For
   example, after committing on `main` (choose an unused version each time):

   ```sh
   git push origin main
   git tag -a v0.0.2 -m "Release v0.0.2"
   git push origin v0.0.2
   ```

3. Open **Actions > Package and publish addon** and check the packaging step for
   an upload to CurseForge project `1710300` and its success result.
4. Check the CurseForge project's Files page or author dashboard. New projects
   and files may need moderation before appearing publicly.

Re-running the old `v0.0.1` workflow still checks out that old tag, which has no
CurseForge project ID. Publish a new tag containing the metadata change instead.
For a manual upload of an existing version, use the packaged
`DeleteCheapestItem-Reloaded-<version>.zip` from GitHub Releases, not GitHub's
automatically generated source-code archives.

Wago publishing additionally needs this addon's `X-Wago-ID` in the TOC and the
`WAGO_API_TOKEN` repository secret. No original-author or BuffTimers project IDs
are reused.

## Credits

- **Sander Vispoel (sandervspl):** Reloaded maintenance and compatibility work.
- **&lt;Night Shift&gt; Suey:** original author, as credited in the original 6.21 TOCs.
- **CriitzLeFleur:** previous [CurseForge project](https://www.curseforge.com/wow/addons/delete-cheapest-item) maintainer.
- **BuffTimers:** reference for tests, deployment, and packaging conventions.

The original project's **All Rights Reserved** license designation is retained.
Authorship and credits do not change the original code's license.
