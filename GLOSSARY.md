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

**Soul Shard limit**:
The most Soul Shards a player wants to keep outside soul bags.
_Avoid_: Shard cap, shard threshold (threshold already means the free-slot count for automatic display)

**Extra shards**:
Soul Shards outside soul bags beyond the Soul Shard limit; shards in soul bags and ignored shards are never extra.
_Avoid_: Surplus shards, excess shards

**Soul bag**:
A specialty bag that holds only Soul Shards; freeing space in it never makes room for ordinary loot.
_Avoid_: Shard bag
