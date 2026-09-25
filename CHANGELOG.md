# DeleteCheapestItem Reloaded

## 7.0.0

- Enable **Allow window in combat** by default for new or reset settings; preserve
  existing saved choices.
- Continued maintenance by Sander Vispoel (sandervspl), with credit to original author
  <Night Shift> Suey and previous CurseForge maintainer CriitzLeFleur.
- Support Classic Era 1.15.9, Anniversary 2.5.6, Mists 5.5.4, and Forever 1.60.1.
- Match Forever's native bronze loot-window border and flat background on Forever only.
- Add `/dci debug on`, `/dci debug off`, and `/dci status` for window visibility diagnostics.
- Preserve the first full-bags opening request during combat, retry when the loot
  frame becomes visible, and cancel pending requests when looting ends.
- Only close the loot-context window on loot closure; ignore the lingering frame
  visibility during Forever's closing animation.
- Use current item APIs, handle delayed item data, and open Settings by category ID.
- Support Forever's ScrollBox loot UI and use actual loot slot IDs in Classic.
- Recheck stacks before deleting or selling; wait for confirmation before retrying loot.
- Exclude locked items and specialty bag capacity from general inventory decisions.
- Retain existing character settings, ignore lists, translations, and `/dci`.
- Add Lua 5.1/Busted tests, Mechanic integration, tested local deployment, and releases
  built only after the test suite passes.
