# Mastercraft Forever auction price research

**Finding.** Mastercraft v2.0.7 has no documented or exported auction-price
API that I could find. It does expose its account-wide SavedVariables as
`MastercraftDB`. A separate addon could read an existing scan from that table
as a version-specific fallback. That would provide Mastercraft's own observed
prices, with less information than Mastercraft's internal price resolver.
[Official project page][project] · [Release ZIP, `Mastercraft.toc` and `Prices.lua`][zip]

## Evidence and scope

I inspected Shadowblade's [CurseForge release 9689205][release], uploaded on
November 18, 2026 for WoW Forever 1.60.1. The [official ZIP][zip] is
`Mastercraft-v2.0.7.zip` with SHA-256
`6be7bd0694ced92d153e609386641834a163e55043d8f683f739e3b7f4a670fb`.
`Mastercraft/Mastercraft.toc` lines 1–13 declare interface `16001`, version
`2.0.7`, and the `MastercraftDB` SavedVariables. These findings are from
static inspection of that release. Cross-addon reads and in-game behavior
were not tested.

## Public API and private functions

- The project page, bundled README, and author's integration credits describe
  how Mastercraft consumes prices from Auctionator and TradeSkillMaster. I
  found no published contract for other addons to request Mastercraft prices.
  The author's site describes Mastercraft Sync as uploading a player's local
  SavedVariables to their web ledger. [Project page][project] · [Credits][credits] ·
  [Sync documentation][sync] · [Release ZIP, `README.md`][zip]
- The section titled `Public` in `Prices.lua` defines `ns.Price(itemID)` and
  `ns.PriceForLink(link)` on `local ADDON, ns = ...`, the namespace shared by
  Mastercraft's own files. I found no global price export or versioned pricing
  library in the archive. The update notification `PRICES_UPDATED` also
  travels through Mastercraft's own `ns.Listen`/`ns.Fire` dispatcher. The public
  section label indicates which functions other Mastercraft modules can use.
  [Release ZIP, `Prices.lua` lines 1–16, 125–283, 324–333 and 900–905, `Core.lua`
  lines 501–523][zip]
- For item IDs, the internal resolver can prefer Mastercraft or Auctionator,
  or compare their ages, with a same-day scan-time tie-break when available.
  TSM can be configured first and can also fill missing or older prices in
  some modes. TSM itself tries `DBMinBuyout` before `DBMarket` using
  `i:<itemID>`. A Mastercraft entry can use the lowest unit buyout or, if
  configured and tiers exist, an average of up to five cheapest units with
  low outliers filtered. The auction cut is calculated separately. Reading
  `p` directly returns the stored minimum in copper per item, before cut,
  and bypasses these settings and external providers.
  [Release ZIP, `Prices.lua` lines 48–84 and 128–218][zip]

## Saved scan data

- `Core.lua` assigns `MastercraftDB` to its local namespace during
  `ADDON_LOADED`. The observed base-price path is
  `MastercraftDB.prices[market].items[itemID]`, with a numeric item ID.
  `market` comes from Mastercraft's `ServerFaction()`, which normalizes
  recognized Forever realm labels to region and ruleset, then appends the
  player's faction, for example `eu-pvp-Horde`. Unrecognized realm labels
  retain their original name. Its private `Book()` function migrates past
  realm books to normalized server keys and resets legacy price data if
  `pricesUnitFixed` is unset. A direct reader sees the current tables and
  depends on Mastercraft having performed any needed migration.
  [Release ZIP, `Core.lua` lines 3–63 and 552–602, `Prices.lua` lines 7–46][zip]
- An entry has `p` (unit buyout in copper) and `t` (observation time).
  Depending on how it was collected, it can also have `n` (listed quantity)
  or `tiers` (unit price and quantity pairs). A completed full scan stores a
  market-wide `lastScan`, marks previously priced items that are no longer
  listed as `gone`, and removes such entries when their last observation is
  over 30 days old. `gone` retains a historical price, and the age of an
  individual price comes from `t`. An empty market, missing record, or
  unusable price leaves the value unknown. Full scans and ordinary searches
  at the auction house can both populate the table.
  [Release ZIP, `Prices.lua` lines 48–58, 852–905, 1125–1163 and 1185–1280][zip]

## Item keys and fallback behavior

- The scanner deduplicates browse results by a four-part key of item ID,
  item level, suffix, and battle pet species ID. It then stores the lowest
  price across those keys in `items[itemID]`. This can assign one gear
  variant's price to a different variant if a consumer uses the base ID
  alone. For groups with a nonzero random suffix, Mastercraft also stores
  `versions[itemID]` as a list keyed within the list by suffix `s` and
  item level `l`, with `p`, `n`, `t`, and an optional localized `name`
  resolved through the auction house item key. This saved variant list does
  not retain the full four-part scan key. Full scans replace current variant
  lists, while ordinary browse updates merge the variants they see.
  [Release ZIP, `Prices.lua` lines 749–824, 853–883 and 1246–1256][zip]
- The internal link resolver first gets the item ID. For known versions it
  compares the hyperlink's displayed item name to stored version names and
  chooses the lowest-priced matching name. The link suffix helps identify a
  generic external quote, and is not used as the main variant lookup key.
  The resolver can prefer a Mastercraft version over an external ID-only
  quote even when Auctionator is configured first. Its return metadata
  distinguishes `version` (matched), `any` (generic or unresolved), and
  `others` (another version's price, for display). Mastercraft's loot
  advisor excludes `others` from the item's own auction value.
  [Release ZIP, `Prices.lua` lines 234–283, `Loot.lua` lines 90–109][zip]

## Implications for a separate addon

A supported provider is blocked on an upstream contract. If Shadowblade
publishes or confirms one, the important details are link and item ID
support, gross unit copper before commission, market scope, observation time,
how it reports missing and unlisted items, and which addon supplied the quote.
A synchronous, read-only lookup for Mastercraft's own quotes would fit
DeleteCheapestItem's existing provider model. [Author contact][credits]

A read-only fallback for v2.0.7 is technically plausible for observed native
prices, with checks for a loaded database, matching market, positive unit
price, and timestamp. Treat unlisted or stale values as historical and a
missing matching variant as an unknown price. Direct
Auctionator or TSM lookups can still be attributed to their own provider when
Mastercraft is unable to supply a usable observation. Tooltip scraping would
depend on UI settings, localized text, variant hints, and whether the
displayed price has already had the cut applied. The addon source and data
are all rights reserved under the bundled license. [Release ZIP, `Prices.lua`,
`Loot.lua`, `Tooltip.lua` and `LICENSE.txt`][zip] · [Author's terms][terms]

ForeverTrading provides a precedent for an in-game, read-only bridge. Its
adapter reads the same global saved price book, checks the current server and
faction, and rejects entries flagged as no longer listed. It uses the base item
ID and reads the stored low price. That demonstrates a viable integration
technique, with compatibility tied to Mastercraft's internal schema.
[ForeverTrading's Mastercraft adapter](https://github.com/thewoolfi/ForeverTrading/blob/2f490447a12af05e6ebba41b889fd9bf93285b6e/Sources/Mastercraft.lua#L54-L86)

## DeleteCheapestItem integration

Scope the provider to Forever (`16001`), the only client listed in the
inspected Mastercraft release. Once Mastercraft publishes a supported lookup,
detect that function in `DCI.UseAuctionPrices` and add the corresponding
dispatch in `DCI.GetAuctionPriceByItemID`. Use `Mastercraft`, the folder and
TOC name, if optional load ordering is needed. Keep the existing provider order
and put Mastercraft after auxForever as a conservative initial default.
DeleteCheapestItem currently selects by provider availability, so that order
means Auctionator wins when both are enabled, even when its price for an
individual item is missing. A provider selector or per-item fallback would be a
separate behavior decision. The existing Settings and tooltip source labels
already use the selected provider's name.
[DeleteCheapestItem auction detection and lookup](../DeleteCheapestItem.lua#L464) · [Settings source label](../DeleteCheapestItem.lua#L2431)

Pass the actual bag, loot, or quest item link through
`DCI.GetAuctionPriceForItem`, as it already does for auxForever. Avoid the
session-long item-ID cache for these lookups so separate gear suffixes can have
distinct prices and newer scans can affect the next refresh. If gear variants
are supported, also use a variant-aware key when deduplicating bag rows. Feed
only positive finite values into the existing comparison and apply
DeleteCheapestItem's optional 5% cut once. Missing quotes should leave the
vendor comparison available.
[Item cache](../DeleteCheapestItem.lua#L245) · [Link-aware dispatch](../DeleteCheapestItem.lua#L742) · [Bag comparison and deduplication](../DeleteCheapestItem.lua#L1005)

Once there is an API to exercise, verify on Forever with a scanned commodity
stack, two gear variants sharing a base ID, an item without a quote, an updated
scan in the same session, and the existing auction-cut toggle. Check that
enabling Auctionator alongside Mastercraft preserves the agreed source
priority. Use the same cases to check bag ranking and loot or quest reward
values where applicable.

## Blizzard reference

The `forever` branch at `3d8abb1da73a` documents `C_AddOns.IsAddOnLoaded` and
`ADDON_LOADED` for provider readiness, and `C_Item.GetItemInfoInstant` for
resolving the item ID from a link. `AuctionHouseDocumentation.lua` defines the
browse and search calls Mastercraft uses and the `itemSuffix` member of the
auction item key. The Blizzard auction house TOC selects the Camelot auction
data override. The proposed adapter would read Mastercraft's cached quotes in
game.
[AddOnsDocumentation.lua](https://github.com/Gethe/wow-ui-source/blob/3d8abb1da73acd38e412e24fb3f99454a6392346/Interface/AddOns/Blizzard_APIDocumentationGenerated/AddOnsDocumentation.lua) · [ItemDocumentation.lua](https://github.com/Gethe/wow-ui-source/blob/3d8abb1da73acd38e412e24fb3f99454a6392346/Interface/AddOns/Blizzard_APIDocumentationGenerated/ItemDocumentation.lua) · [AuctionHouseDocumentation.lua](https://github.com/Gethe/wow-ui-source/blob/3d8abb1da73acd38e412e24fb3f99454a6392346/Interface/AddOns/Blizzard_APIDocumentationGenerated/AuctionHouseDocumentation.lua) · [Blizzard_AuctionHouseUI.toc](https://github.com/Gethe/wow-ui-source/blob/3d8abb1da73acd38e412e24fb3f99454a6392346/Interface/AddOns/Blizzard_AuctionHouseUI/Blizzard_AuctionHouseUI.toc)

[project]: https://www.curseforge.com/wow/addons/mastercraft-forever
[release]: https://www.curseforge.com/wow/addons/mastercraft-forever/files/9689205
[zip]: https://mediafilez.forgecdn.net/files/9689/205/Mastercraft-v2.0.7.zip
[credits]: https://getmastercraft.com/credits/
[sync]: https://getmastercraft.com/how-it-works/
[terms]: https://getmastercraft.com/terms/
