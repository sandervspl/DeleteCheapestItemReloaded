# DeleteCheapestItem Reloaded

Language for the addon's inventory tools and entry points.

## Language

**Broker display**:
A separate addon that presents LibDataBroker entries as panel buttons or other controls.
_Avoid_: LibDataBroker panel (LibDataBroker itself is not a panel)

**Launcher**:
A clickable entry for accessing the addon through a broker display or minimap button.
_Avoid_: Data source (an entry intended to display changing information)

**Minimap button**:
A button attached to the minimap that provides access to an addon.
_Avoid_: Broker button (a broker display can present buttons elsewhere)
