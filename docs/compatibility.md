# Client compatibility reference

Checked on 2026-09-24 using `scripts/sync-wow-ui-source.sh`, one branch at a time.
The source checkout is a read-only reference. Versions are taken from each branch's
`version.txt` and agree with the corresponding entries in BuffTimers' manifest.

| Client | Upstream branch | Commit | Build | Interface |
| --- | --- | --- | --- | --- |
| Classic Era | `classic_era` | [`33e177d9bf38`](https://github.com/Gethe/wow-ui-source/tree/33e177d9bf38) | 1.15.9.69722 | 11509 |
| Anniversary | `classic_anniversary` | [`1463c686270b`](https://github.com/Gethe/wow-ui-source/tree/1463c686270b) | 2.5.6.69795 | 20506 |
| Mists | `classic` | [`cde55d0033e8`](https://github.com/Gethe/wow-ui-source/tree/cde55d0033e8) | 5.5.4.69934 | 50504 |
| Forever | `forever` | [`c6e89983189e`](https://github.com/Gethe/wow-ui-source/tree/c6e89983189e) | 1.60.1.69977 | 16001 |

## Files consulted

All paths below are relative to upstream `Interface/AddOns/`.

On all four branches:

- `Blizzard_APIDocumentationGenerated/ItemDocumentation.lua`: `C_Item.GetItemInfo`,
  `GetItemIconByID`, `GetItemQualityColor`, and `GET_ITEM_INFO_RECEIVED`. Item data
  can be unavailable on the initial lookup.
- `Blizzard_APIDocumentationGenerated/ContainerDocumentation.lua`: container item
  records, nullable quality, bound/locked flags, quest info, free slots and bag
  families, pickup, and use APIs.
- `Blizzard_Settings_Shared/Blizzard_Settings.lua`: registering a canvas category
  and opening it by ID without reaching into `SettingsPanel` internals.
- `Blizzard_SharedXML/SecureScrollTemplates.xml`: the existing scroll-frame
  template and its `ScrollBar` child remain available.

On Era, Anniversary, and Mists:

- `Blizzard_DeprecatedItemScript/Deprecated_ItemScript.lua`: the old item globals
  are conditional on `loadDeprecationFallbacks`; use the `C_Item` APIs directly.
- `Blizzard_UIPanels_Game/Classic/LootFrame.lua`: `LootButton_OnClick` uses
  `self.slot`, which can differ from the button number after paging.
- `Blizzard_UIPanels_Game/Vanilla/QuestInfo.lua` (Era), `TBC/QuestInfo.lua`
  (Anniversary), and `Wrath/QuestInfo.lua` (Mists): reward selection is stored in
  `QuestInfoFrame.itemChoice` by `QuestInfoItem_OnClick`.
- Era's `Blizzard_StaticPopup_Game/Classic/GameDialogDefs.lua`: cursor item
  deletion and confirmation behavior.

On Forever specifically:

- `Blizzard_UIPanels_Game/Blizzard_UIPanels_Game.toc`: `camelot` uses the Mainline
  UI family with Camelot overrides; it is not the Classic Era layout.
- `Blizzard_UIPanels_Game/Mainline/LootFrame.lua`: recycled ScrollBox rows expose
  the selected slot through `LootFrame.selectedSlot` and emit `LootFrame.ItemLooted`.
- `Blizzard_UIPanels_Game/Mainline/QuestInfo.lua`: the shared quest-selection hook
  and item-choice field still exist.
- `Blizzard_UIPanels_Game/Mainline/GroupLootFrame.xml`: the group loot container
  and first roll frame still exist.
- `Blizzard_UIPanels_Game/Mainline/ContainerFrame.lua`,
  `Blizzard_UIPanels_Game/Camelot/ContainerFrame.lua`, and
  `Blizzard_FrameXMLBase/Constants.lua`: equipped bag enumeration includes
  `NUM_TOTAL_EQUIPPED_BAG_SLOTS`.
- `Blizzard_CatalogShop/Blizzard_CatalogShop.lua`: Blizzard counts space for
  arbitrary items only when `GetContainerNumFreeSlots` returns `bagFamily == 0`.
- `Blizzard_APIDocumentationGenerated/GameCursorDocumentation.lua`: cursor
  inspection, clearing, and restricted deletion (performed from user clicks).
- `Blizzard_APIDocumentationGenerated/AddOnsDocumentation.lua`: metadata lookup
  through `C_AddOns.GetAddOnMetadata`.

## Forever window styling

Checked against `forever` commit `c6e89983189e`. The addon uses
`DefaultPanelFlatTemplate` only for the `16xxx` client family, detected using the
interface return value documented in `Blizzard_APIDocumentationGenerated/BuildDocumentation.lua`.
Era, Anniversary, and Mists retain `BasicFrameTemplate`.

The native template chain is defined in
`Blizzard_UIPanels_Game/Mainline/LootFrame.xml`,
`Blizzard_UIPanels_Game/Mainline/ScrollingFlatPanel.xml`, and
`Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.xml`. The flat panel uses the
`ButtonFrameTemplateNoPortrait` layout from
`Blizzard_SharedXML/Mainline/NineSliceLayouts.lua`, with Forever's artwork offsets
from `Blizzard_SharedXML/Camelot/NineSliceLayoutOverrides.lua`.

The addon adds the same `UIPanelCloseButtonDefaultAnchors` used by the native loot
panel; `Blizzard_SharedXML/Camelot/SharedUIPanelTemplates.lua` supplies its Forever
position. Title controls are parented to the template's title container so they
remain above the native NineSlice border. No border textures or global Blizzard
layouts are modified.

The client-matrix tests exercise the close button, Settings button, and title
layering. In-game verification should also check the bronze border, title dragging,
and scrolling with a full list of items.

## Packaging reference

The release workflow uses BigWigsMods/packager commit
[`e50a250f8705041e40f2fa1ddcb280a686d65aa0`](https://github.com/BigWigsMods/packager/tree/e50a250f8705041e40f2fa1ddcb280a686d65aa0).
Its `release.sh` maps `115xx` to Classic, `205xx` to BCC (Anniversary), `505xx` to
Mists, and `160xx` to Forever. A single comma-separated manifest supports all four
in one archive. This pin includes the Forever mapping, unlike older packager
revisions that may classify it as Retail.

## Verification limits and in-game checks

Automated tests use Lua 5.1 and explicit WoW API/frame mocks. They do not run the
game, simulate its security/taint system, or verify third-party auction addons.
Before publishing, perform these checks in each client:

1. Enable Lua errors with `/console scriptErrors 1`; load the addon and open `/dci`.
2. Check Settings, localized labels, saved options after `/reload`, and the ignore list.
3. Fill normal bags (including a specialty bag with spare slots); trigger the
   inventory-full window from loot, mail, trade, and a quest reward.
4. Test missing item-cache data and switching quest reward choices.
5. Delete disposable grey stacks and confirm a higher-quality disposable stack.
   Cancel confirmation, move a stack while confirmation is open, and try with an
   item on the cursor. Only the intended, unchanged stack should be deleted.
6. Sell a disposable stack at a merchant; verify a stale button cannot use an item
   after the merchant closes.
7. Select loot beyond the first page in Classic or a recycled row in Forever;
   verify the selected slot is retried after deletion is accepted.
8. Check combat visibility and auction comparisons with the auction addon you use.
