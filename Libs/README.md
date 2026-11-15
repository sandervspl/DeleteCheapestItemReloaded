# Bundled libraries

Vendored upstream source, loaded in TOC order. Source files retain upstream headers.

| File | Source | SHA-256 |
| --- | --- | --- |
| `Libs/LibStub/LibStub.lua` | [Upstream](https://repos.wowace.com/wow/libstub/trunk/LibStub.lua) | `7ba7300471327c0de1b3e42a4edfd62cbad79bd30100d6377736d2c1080e9b96` |
| `Libs/CallbackHandler-1.0/CallbackHandler-1.0.lua` | [Upstream](https://repos.wowace.com/wow/callbackhandler/trunk/CallbackHandler-1.0/CallbackHandler-1.0.lua) | `8ab5d51799e8c67b6d17b523b3c191ff63ad24e081134ab8ac7d188ce69701b9` |
| `Libs/LibDataBroker-1.1/LibDataBroker-1.1.lua` | [Upstream](https://raw.githubusercontent.com/tekkub/libdatabroker-1-1/1a63ede0248c11aa1ee415187c1f9c9489ce3e02/LibDataBroker-1.1.lua) | `f3d4758f2060215492c9764b1d7dc2a336826d4cd253cd54ff9ff7c6d78f04e2` |
| `Libs/LibDBIcon-1.0/LibDBIcon-1.0.lua` | [Upstream](https://repos.wowace.com/wow/libdbicon-1-0/trunk/LibDBIcon-1.0/LibDBIcon-1.0.lua) | `cafa823dfb9f216eb476af4bcd2fad4c25c718f39b7565fa1c924dbebac41f91` |

LibStub declares public-domain status in its source header. The included license notices for [LibDBIcon](https://www.curseforge.com/wow/addons/libdbicon-1-0/license) and [CallbackHandler](https://www.curseforge.com/wow/addons/callbackhandler/license) reproduce their published project notices (including CallbackHandler's placeholder names). LibDataBroker is retained unchanged from the pinned upstream source.

## AceDB profile storage

`AceDB-3.0/AceDB-3.0.lua` is pinned to
[WoWUIDev/Ace3 ac3d1225037e0dc74e025a72342c0f7824aae147](https://github.com/WoWUIDev/Ace3/blob/ac3d1225037e0dc74e025a72342c0f7824aae147/AceDB-3.0/AceDB-3.0.lua).
Its upstream license is included in `AceDB-3.0/LICENSE.txt`.

One local compatibility change guards the optional `GetCurrentRegionName` call
with a function-existence check. Older supported clients document
`GetCurrentRegion`, but do not document the region-name function. The existing
region-ID mapping remains the fallback. No global API shim is installed.
The library includes Forever's regional names and ruleset keys. Packaged SHA-256:
`94c5a30dce41778890b815e6ed1d5d30a3d8a836882759e0593f00e0965ed452`.

AceDB uses the LibStub and CallbackHandler dependencies already bundled here.
AceConfig, AceGUI, AceAddon and AceDBOptions are not bundled or required.
