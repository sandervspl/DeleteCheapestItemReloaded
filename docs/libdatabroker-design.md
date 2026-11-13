# LibDataBroker support design

Status: Interview in progress. Implementation awaits confirmation of shared understanding.

## Request

A user requested LDB support because they like buttons and panels.

## Settled decisions

- Provide a launcher for broker displays such as Titan Panel, without live bag or item statistics.
- Also provide an optional minimap button for the same launcher, with a setting to hide it.
- Share the icon, click behavior, and tooltip between the panel entry and minimap button.
- Support all four existing clients: Era, Anniversary, Mists, and Forever.
- Bundle LibDataBroker, LibDBIcon, and their required libraries. Users supply a broker display if they want a panel entry.

## Open decisions

- Determine click actions and tooltip content.
- Determine the minimap button's default visibility and position persistence.
- Agree on verification and acceptance criteria before implementation.

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
