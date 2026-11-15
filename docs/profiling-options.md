# Profiling system options

Research completed by three parallel researchers on 2026-11-15. No addon code
was changed and no in-game benchmarks were run. Effort and overhead descriptions
below are engineering judgments, not measured results.

## Recommendation

Build a small, opt-in named-span profiler with refresh-reason counters first.
Use an external profiler to establish an addon-wide baseline. Add a bounded
event/request timeline only when aggregate results cannot explain repeated work.
Modern engine metrics can be an optional overview; legacy CPU accounting should
remain a separate expert tool.

This combines WeakAuras' explicit capture lifecycle and report export with
Details' simple operation aggregates. It avoids taking on a general-purpose
function profiler or a continuously updating performance dashboard.

## Options

| Option | Answers | Relative scope | Main limitation |
| --- | --- | --- | --- |
| External tool only | Is DCI a significant contributor? | Smallest DCI change: none | Limited DCI-specific explanation of why work ran; tool compatibility needs checking |
| Named operation timings | Which DCI phase is expensive, and how often? | Low to medium | Elapsed synchronous intervals are not engine CPU attribution; nested scopes overlap |
| Event/request timeline | Why did several refreshes run, and in which order? | Medium | More collection/storage overhead; needs a hard capacity and overwrite reporting |
| Engine addon metrics | What are addon-wide average, peak, and spike metrics? | Medium | Does not identify internal phases; session metrics do not define arbitrary capture-window deltas |
| Legacy CPU counters | What do legacy addon/function CPU counters attribute? | Medium to high | Enablement, reload behavior, units and attribution require client verification |
| Staged hybrid | Is work slow, too frequent, or both? | Medium initially; higher with trace | More modes to verify; keep each mode independently optional |

## What other addons demonstrate

- **WeakAuras:** explicit start/stop/timed capture, same-key nesting protection,
  disabled no-op instrumentation, and a copyable support report. Best overall
  reference for capture lifecycle. Its internal nesting count is not a call count.
- **Details:** named elapsed totals and run counts with replaceable enabled/no-op
  functions. Useful simplicity, but same-key nesting overwrites its start time,
  and the inspected report has a unit-label issue. Borrow the pattern carefully.
- **Numy AddonProfiler:** modern engine metrics, peaks and history; collection
  modes trade detail for background work. Useful optional external baseline.
- **Numy FunctionProfiler:** wrapped-call elapsed timing and call/tick history.
  More machinery than DCI initially needs; wrapping introduces return/error-path
  concerns and its heap deltas are not addon-local allocation counts.
- **AddonUsage:** legacy cumulative CPU rate with an explicit `scriptProfile`
  toggle/reload and overhead warning. Useful expert workflow, not the default
  DCI capture backend.

These observations refer to pinned implementations, not claims that all tool
versions run on every DCI client. BigWigs/DBM source searches did not establish a
timing-profiler implementation in the inspected revisions. Their settings
profiles must not be confused with performance profiling. Exact revisions,
source links, caveats, and AddonUsage archive checksums are in the
[external-addon research](profiling-addon-research.md).

## Suggested first implementation

Proposed commands, which do not exist yet: `/dci profile start`, `stop`, `status`,
`report`, `export`, and `reset`. Start a fresh, duration-limited capture; stop
freezes results. Export formats a frozen copyable report outside measured work.
Leave collection off after reload and retain session data in memory by default.

Initially collect calls, inclusive total/mean/maximum elapsed milliseconds,
refresh reasons, and workload counts for:

1. Whole window refresh (`UpdateDCIFrame`).
2. Bag collection/valuation/sort (`GetSortedBagItems`).
3. Auction provider lookups (`GetAuctionPriceByItemID`).
4. Loot and quest reward collection.
5. Row rendering and summary/layout work.
6. Events and queued callbacks: requested, scheduled, superseded/skipped,
   executed, and refresh-producing counts.

Use a feature-detected `GetTimePreciseSec` difference, converted to milliseconds,
for elapsed intervals; optionally fall back to `debugprofilestop` differences
with its reset caveat. Do not reset the shared profiling timer. Do not sum nested
phase totals into an addon total, time human confirmation waits as execution, or
keep execution spans open while waiting for deferred callbacks.

Basic capture should not print per item, query providers a second time, refresh
memory accounting per scan, change global CPU settings, or alter scheduling and
filtering. Add a separate trace mode later if needed, for example a 1,024-record
ring with capture/request IDs and explicit overwritten-record counts. These caps
are proposed defaults, not tuned limits.

Record addon/build/client, timing backend, capture mode, relevant settings,
provider, debug flags, workload counts and retention limits in the export.
Existing verbose/window debug changes the workload, so keep it off for baseline
captures. See the [DCI design research](profiling-design-research.md) for exact
source boundaries and repeatable medium/hard in-game verification scenarios.

## Supported-client evidence and remaining checks

The API researcher ran `scripts/sync-wow-ui-source.sh` sequentially, inspecting:

| Supported client | Upstream branch | Short commit |
| --- | --- | --- |
| Era, 11509 | `classic_era` | `4192ac60067f` |
| Anniversary, 20506 | `classic_anniversary` | `68e0a2ec559d` |
| Mists, 50504 | `classic` | `e5d9b3a22c3f` |
| Forever/camelot, 16001 | `forever` | `bebcb6bf309c` |

Main upstream files: generated `FrameScriptDocumentation.lua`,
`OsDocumentation.lua`, `PerformanceDocumentation.lua`,
`AddOnProfilerDocumentation.lua`, `AddOnProfilerConstantsDocumentation.lua`,
and Blizzard's `AddonList.lua`, `PerformanceBar.lua`, `BenchmarkUtil.lua`, and
console autocomplete clock usage. [API research with exact-revision links](profiling-api-research.md).

All four branches contain modern profiler declarations and Blizzard usage;
modern profiling is therefore not safely dismissed as Retail-only. Guard methods,
enums and `IsEnabled()` at runtime. Optional `MeasureCall` benchmarks can provide
elapsed time and allocation/deallocation metrics, with their own return contract.
They should not be generic production wrappers without verification.

The source-only API review resolves the design research's pending upstream
inspection, but native runtime support and behavior remain unverified. In-client
checks are still required for every supported executable, especially legacy
`scriptProfile` registration/reload behavior, counter attribution, timing error
paths, wrapper returns, and external-tool compatibility. No numerical overhead or
performance improvement is claimed.
