# DeleteCheapestItem Reloaded

## 7.0.0

- Continued maintenance by Sander Vispoel (sandervspl), with credit to original author
  <Night Shift> Suey and previous CurseForge maintainer CriitzLeFleur.
- Support Classic Era 1.15.9, Anniversary 2.5.6, Mists 5.5.4, and Forever 1.60.1.
- Use current item APIs, handle delayed item data, and open Settings by category ID.
- Support Forever's ScrollBox loot UI and use actual loot slot IDs in Classic.
- Recheck stacks before deleting or selling; wait for confirmation before retrying loot.
- Exclude locked items and specialty bag capacity from general inventory decisions.
- Retain existing character settings, ignore lists, translations, and `/dci`.
- Add Lua 5.1/Busted tests, Mechanic integration, tested local deployment, and releases
  built only after the test suite passes.
