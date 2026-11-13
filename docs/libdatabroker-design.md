# LibDataBroker support design

Status: Confirmed by the user and implemented. In-game verification remains manual.

## Request

A user requested LDB support because they like buttons and panels.

## Settled decisions

- Provide a launcher for broker displays such as Titan Panel, without live bag or item statistics.
- Also provide an optional minimap button for the same launcher, with a setting to hide it.
- Share the icon, click behavior, and tooltip between the panel entry and minimap button.
- Support all four existing clients: Era, Anniversary, Mists, and Forever.
- Bundle LibDataBroker, LibDBIcon, and their required libraries. Users supply a broker display if they want a panel entry.
- Plain left-click toggles the main addon window.
- Right-click opens settings.
- Ctrl+left-click opens the ignored-items window instead of toggling the main window.
- Neither entry point performs item deletion.
- The minimap button starts visible and can be dragged. Its position and hidden state persist across logins.
- The tooltip shows the addon name and instructions for all three click actions.

## Implementation and verification

- Reuse the existing main-window, settings, and ignored-items entry points.
- Use the existing addon icon for both entry points.
- Include bundled libraries in the TOC, release packaging, and local installation helper; update source-install instructions.
- Verify registration, each click action, tooltip instructions, minimap visibility and saved position, and compatibility with the supported clients using the repository's Lua test harness where possible.
- Include a repeatable in-game check for Titan Panel and minimap integration. Automated mocks alone cannot establish that the real display works.
- Check changed user-visible text for encoding corruption before delivery.

## Confirmation

The user confirmed the complete design, including Ctrl+left-click for ignored
items, and requested implementation and a PR.

## Repeatable verification

Run `busted --lua=lua5.1` and `./Tests/copy_to_wow_spec.ps1` from the repository root.
The broker specs load the shipped TOC and real bundled libraries for all four
client environments. They exercise panel and minimap click dispatch, tooltip
content, drag persistence, hidden state before and after login, and rebinding
saved settings after a reset.

For each supported client, perform the following in-game checks:

1. Install the addon with its `Libs` folder and log in without a broker display.
   Confirm the minimap button appears and its tooltip explains all three actions.
2. With eligible bag items and an ignored item, left-click to open and close the
   main window, right-click for Settings, and Ctrl+left-click for Ignored Items.
   Confirm these clicks do not delete or sell anything.
3. Drag the button, reload, and confirm its position persists. Hide it in Settings,
   reload again, and confirm it stays hidden. Show it again from `/dci` Settings.
4. Enable a Titan Panel version compatible with the client and enable the launcher
   in its plugin controls. Repeat all three click actions and check the tooltip.
   Hide the minimap button and confirm the panel launcher still works.
5. Reset Default Settings. Confirm the minimap button is shown, the hide checkbox
   is cleared, and newly dragged positions survive a reload.

Record the client build, broker display version, results, and screenshots for
these manual checks. They have not been performed by the implementation agent.

## References

- [LibDataBroker data specifications](https://github.com/tekkub/libdatabroker-1-1/wiki/Data-Specifications)
- [Providing a data object](https://github.com/tekkub/libdatabroker-1-1/wiki/How-to-provide-a-dataobject)
- [LibDBIcon](https://www.curseforge.com/wow/addons/libdbicon-1-0)

Initial read-only WoW source inspection covered the following branches sequentially:

- `classic_era` at `4192ac60067f`
- `classic_anniversary` at `68e0a2ec559d`
- `classic` at `e5d9b3a22c3f`
- `forever` at `bebcb6bf309c`

Consulted `Blizzard_APIDocumentationGenerated/ContainerDocumentation.lua` on each
branch, `Blizzard_Minimap/Classic/Minimap.lua` on the first three, and
`Blizzard_Minimap/Blizzard_Minimap.toc` plus
`Blizzard_Minimap/Camelot/Minimap.lua` on Forever.
Implementation also consulted `Blizzard_SharedXML/BindingUtil.lua` on all four
branches and `Blizzard_APIDocumentationGenerated/InputDocumentation.lua` for
cursor input and Forever's generated `IsControlKeyDown` definition.
