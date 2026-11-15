# Profiling API research

Researched on 2026-11-15 for DeleteCheapestItem Reloaded. Research only; no addon
implementation or in-client execution was performed. Read `AGENTS.md` and
`DeleteCheapestItem.toc` at repository revision
`02dd1ee3b04a46bb05678344bb97909b41a47f0a`. The manifest supports interfaces
11509, 20506, 50504, and 16001, so shared instrumentation must cover all four.

## Revisions and method

Ran `bash scripts/sync-wow-ui-source.sh <branch>` sequentially in the order below,
searched `Interface/AddOns`, and inspected the generated documentation and Blizzard
call sites before switching branches. WSL was unavailable (no distribution), so
the script ran through Git Bash. The cache was treated as read-only apart from
the helper's fetch/checkout operations and is left on `forever`, clean.

| Client | Branch | Inspected commit | Upstream build commit subject |
| --- | --- | --- | --- |
| Era, 11509 | `classic_era` | `4192ac60067f` | 1.15.9 (70576) |
| Anniversary, 20506 | `classic_anniversary` | `68e0a2ec559d` | 2.5.6 (70577) |
| Mists, 50504 | `classic` | `e5d9b3a22c3f` | 5.5.4 (70631) |
| Forever/camelot, 16001 | `forever` | `bebcb6bf309c` | 1.60.1 (70938) |

Exact-revision source inventory for EACH branch follows. Paths are under upstream
`Interface/AddOns/`; links contain full commit IDs. These are Blizzard UI source
and generated API contracts mirrored by Gethe, not the native client engine.

### `classic_era` at `4192ac60067f`

- [FrameScriptDocumentation.lua](https://github.com/Gethe/wow-ui-source/blob/4192ac60067fc55566182291bc67c85dd9b6794d/Interface/AddOns/Blizzard_APIDocumentationGenerated/FrameScriptDocumentation.lua)
- [OsDocumentation.lua](https://github.com/Gethe/wow-ui-source/blob/4192ac60067fc55566182291bc67c85dd9b6794d/Interface/AddOns/Blizzard_APIDocumentationGenerated/OsDocumentation.lua)
- [PerformanceDocumentation.lua](https://github.com/Gethe/wow-ui-source/blob/4192ac60067fc55566182291bc67c85dd9b6794d/Interface/AddOns/Blizzard_APIDocumentationGenerated/PerformanceDocumentation.lua)
- [AddOnProfilerDocumentation.lua](https://github.com/Gethe/wow-ui-source/blob/4192ac60067fc55566182291bc67c85dd9b6794d/Interface/AddOns/Blizzard_APIDocumentationGenerated/AddOnProfilerDocumentation.lua)
- [AddOnProfilerConstantsDocumentation.lua](https://github.com/Gethe/wow-ui-source/blob/4192ac60067fc55566182291bc67c85dd9b6794d/Interface/AddOns/Blizzard_APIDocumentationGenerated/AddOnProfilerConstantsDocumentation.lua)
- [CVarDocumentation.lua](https://github.com/Gethe/wow-ui-source/blob/4192ac60067fc55566182291bc67c85dd9b6794d/Interface/AddOns/Blizzard_APIDocumentationGenerated/CVarDocumentation.lua)
- [Generated documentation TOC](https://github.com/Gethe/wow-ui-source/blob/4192ac60067fc55566182291bc67c85dd9b6794d/Interface/AddOns/Blizzard_APIDocumentationGenerated/Blizzard_APIDocumentationGenerated.toc)
- [AddonList.lua](https://github.com/Gethe/wow-ui-source/blob/4192ac60067fc55566182291bc67c85dd9b6794d/Interface/AddOns/Blizzard_AddOnList/AddonList.lua)
- [PerformanceBar.lua](https://github.com/Gethe/wow-ui-source/blob/4192ac60067fc55566182291bc67c85dd9b6794d/Interface/AddOns/Blizzard_PerformanceBar/PerformanceBar.lua)
- [BenchmarkUtil.lua](https://github.com/Gethe/wow-ui-source/blob/4192ac60067fc55566182291bc67c85dd9b6794d/Interface/AddOns/Blizzard_SharedXML/BenchmarkUtil.lua)
- [Console autocomplete clock usage](https://github.com/Gethe/wow-ui-source/blob/4192ac60067fc55566182291bc67c85dd9b6794d/Interface/AddOns/Blizzard_Console/Blizzard_Console_AutoComplete.lua)
- [AddOnPerformance.lua](https://github.com/Gethe/wow-ui-source/blob/4192ac60067fc55566182291bc67c85dd9b6794d/Interface/AddOns/Blizzard_AddOnPerformance/AddOnPerformance.lua)
- [Shared XML load manifest](https://github.com/Gethe/wow-ui-source/blob/4192ac60067fc55566182291bc67c85dd9b6794d/Interface/AddOns/Blizzard_SharedXML/Blizzard_SharedXML_Vanilla.toc)

### `classic_anniversary` at `68e0a2ec559d`

- [FrameScriptDocumentation.lua](https://github.com/Gethe/wow-ui-source/blob/68e0a2ec559d9761dfc4e7f864c3944f9d758a49/Interface/AddOns/Blizzard_APIDocumentationGenerated/FrameScriptDocumentation.lua)
- [OsDocumentation.lua](https://github.com/Gethe/wow-ui-source/blob/68e0a2ec559d9761dfc4e7f864c3944f9d758a49/Interface/AddOns/Blizzard_APIDocumentationGenerated/OsDocumentation.lua)
- [PerformanceDocumentation.lua](https://github.com/Gethe/wow-ui-source/blob/68e0a2ec559d9761dfc4e7f864c3944f9d758a49/Interface/AddOns/Blizzard_APIDocumentationGenerated/PerformanceDocumentation.lua)
- [AddOnProfilerDocumentation.lua](https://github.com/Gethe/wow-ui-source/blob/68e0a2ec559d9761dfc4e7f864c3944f9d758a49/Interface/AddOns/Blizzard_APIDocumentationGenerated/AddOnProfilerDocumentation.lua)
- [AddOnProfilerConstantsDocumentation.lua](https://github.com/Gethe/wow-ui-source/blob/68e0a2ec559d9761dfc4e7f864c3944f9d758a49/Interface/AddOns/Blizzard_APIDocumentationGenerated/AddOnProfilerConstantsDocumentation.lua)
- [CVarDocumentation.lua](https://github.com/Gethe/wow-ui-source/blob/68e0a2ec559d9761dfc4e7f864c3944f9d758a49/Interface/AddOns/Blizzard_APIDocumentationGenerated/CVarDocumentation.lua)
- [Generated documentation TOC](https://github.com/Gethe/wow-ui-source/blob/68e0a2ec559d9761dfc4e7f864c3944f9d758a49/Interface/AddOns/Blizzard_APIDocumentationGenerated/Blizzard_APIDocumentationGenerated.toc)
- [AddonList.lua](https://github.com/Gethe/wow-ui-source/blob/68e0a2ec559d9761dfc4e7f864c3944f9d758a49/Interface/AddOns/Blizzard_AddOnList/AddonList.lua)
- [PerformanceBar.lua](https://github.com/Gethe/wow-ui-source/blob/68e0a2ec559d9761dfc4e7f864c3944f9d758a49/Interface/AddOns/Blizzard_PerformanceBar/PerformanceBar.lua)
- [BenchmarkUtil.lua](https://github.com/Gethe/wow-ui-source/blob/68e0a2ec559d9761dfc4e7f864c3944f9d758a49/Interface/AddOns/Blizzard_SharedXML/BenchmarkUtil.lua)
- [Console autocomplete clock usage](https://github.com/Gethe/wow-ui-source/blob/68e0a2ec559d9761dfc4e7f864c3944f9d758a49/Interface/AddOns/Blizzard_Console/Blizzard_Console_AutoComplete.lua)
- [AddOnPerformance.lua](https://github.com/Gethe/wow-ui-source/blob/68e0a2ec559d9761dfc4e7f864c3944f9d758a49/Interface/AddOns/Blizzard_AddOnPerformance/AddOnPerformance.lua)
- [Shared XML load manifest](https://github.com/Gethe/wow-ui-source/blob/68e0a2ec559d9761dfc4e7f864c3944f9d758a49/Interface/AddOns/Blizzard_SharedXML/Blizzard_SharedXML_TBC.toc)

### `classic` at `e5d9b3a22c3f`

- [FrameScriptDocumentation.lua](https://github.com/Gethe/wow-ui-source/blob/e5d9b3a22c3f0f6f41ebac0e454f4969594261cf/Interface/AddOns/Blizzard_APIDocumentationGenerated/FrameScriptDocumentation.lua)
- [OsDocumentation.lua](https://github.com/Gethe/wow-ui-source/blob/e5d9b3a22c3f0f6f41ebac0e454f4969594261cf/Interface/AddOns/Blizzard_APIDocumentationGenerated/OsDocumentation.lua)
- [PerformanceDocumentation.lua](https://github.com/Gethe/wow-ui-source/blob/e5d9b3a22c3f0f6f41ebac0e454f4969594261cf/Interface/AddOns/Blizzard_APIDocumentationGenerated/PerformanceDocumentation.lua)
- [AddOnProfilerDocumentation.lua](https://github.com/Gethe/wow-ui-source/blob/e5d9b3a22c3f0f6f41ebac0e454f4969594261cf/Interface/AddOns/Blizzard_APIDocumentationGenerated/AddOnProfilerDocumentation.lua)
- [AddOnProfilerConstantsDocumentation.lua](https://github.com/Gethe/wow-ui-source/blob/e5d9b3a22c3f0f6f41ebac0e454f4969594261cf/Interface/AddOns/Blizzard_APIDocumentationGenerated/AddOnProfilerConstantsDocumentation.lua)
- [CVarDocumentation.lua](https://github.com/Gethe/wow-ui-source/blob/e5d9b3a22c3f0f6f41ebac0e454f4969594261cf/Interface/AddOns/Blizzard_APIDocumentationGenerated/CVarDocumentation.lua)
- [Generated documentation TOC](https://github.com/Gethe/wow-ui-source/blob/e5d9b3a22c3f0f6f41ebac0e454f4969594261cf/Interface/AddOns/Blizzard_APIDocumentationGenerated/Blizzard_APIDocumentationGenerated.toc)
- [AddonList.lua](https://github.com/Gethe/wow-ui-source/blob/e5d9b3a22c3f0f6f41ebac0e454f4969594261cf/Interface/AddOns/Blizzard_AddOnList/AddonList.lua)
- [PerformanceBar.lua](https://github.com/Gethe/wow-ui-source/blob/e5d9b3a22c3f0f6f41ebac0e454f4969594261cf/Interface/AddOns/Blizzard_PerformanceBar/PerformanceBar.lua)
- [BenchmarkUtil.lua](https://github.com/Gethe/wow-ui-source/blob/e5d9b3a22c3f0f6f41ebac0e454f4969594261cf/Interface/AddOns/Blizzard_SharedXML/BenchmarkUtil.lua)
- [Console autocomplete clock usage](https://github.com/Gethe/wow-ui-source/blob/e5d9b3a22c3f0f6f41ebac0e454f4969594261cf/Interface/AddOns/Blizzard_Console/Blizzard_Console_AutoComplete.lua)
- [AddOnPerformance.lua](https://github.com/Gethe/wow-ui-source/blob/e5d9b3a22c3f0f6f41ebac0e454f4969594261cf/Interface/AddOns/Blizzard_AddOnPerformance/AddOnPerformance.lua)
- [Shared XML load manifest](https://github.com/Gethe/wow-ui-source/blob/e5d9b3a22c3f0f6f41ebac0e454f4969594261cf/Interface/AddOns/Blizzard_SharedXML/Blizzard_SharedXML_Mists.toc)

### `forever` at `bebcb6bf309c`

- [FrameScriptDocumentation.lua](https://github.com/Gethe/wow-ui-source/blob/bebcb6bf309cf41b41bd74f8ca651e6a105b2676/Interface/AddOns/Blizzard_APIDocumentationGenerated/FrameScriptDocumentation.lua)
- [OsDocumentation.lua](https://github.com/Gethe/wow-ui-source/blob/bebcb6bf309cf41b41bd74f8ca651e6a105b2676/Interface/AddOns/Blizzard_APIDocumentationGenerated/OsDocumentation.lua)
- [PerformanceDocumentation.lua](https://github.com/Gethe/wow-ui-source/blob/bebcb6bf309cf41b41bd74f8ca651e6a105b2676/Interface/AddOns/Blizzard_APIDocumentationGenerated/PerformanceDocumentation.lua)
- [AddOnProfilerDocumentation.lua](https://github.com/Gethe/wow-ui-source/blob/bebcb6bf309cf41b41bd74f8ca651e6a105b2676/Interface/AddOns/Blizzard_APIDocumentationGenerated/AddOnProfilerDocumentation.lua)
- [AddOnProfilerConstantsDocumentation.lua](https://github.com/Gethe/wow-ui-source/blob/bebcb6bf309cf41b41bd74f8ca651e6a105b2676/Interface/AddOns/Blizzard_APIDocumentationGenerated/AddOnProfilerConstantsDocumentation.lua)
- [CVarDocumentation.lua](https://github.com/Gethe/wow-ui-source/blob/bebcb6bf309cf41b41bd74f8ca651e6a105b2676/Interface/AddOns/Blizzard_APIDocumentationGenerated/CVarDocumentation.lua)
- [Generated documentation TOC](https://github.com/Gethe/wow-ui-source/blob/bebcb6bf309cf41b41bd74f8ca651e6a105b2676/Interface/AddOns/Blizzard_APIDocumentationGenerated/Blizzard_APIDocumentationGenerated.toc)
- [AddonList.lua](https://github.com/Gethe/wow-ui-source/blob/bebcb6bf309cf41b41bd74f8ca651e6a105b2676/Interface/AddOns/Blizzard_AddOnList/AddonList.lua)
- [PerformanceBar.lua](https://github.com/Gethe/wow-ui-source/blob/bebcb6bf309cf41b41bd74f8ca651e6a105b2676/Interface/AddOns/Blizzard_PerformanceBar/PerformanceBar.lua)
- [BenchmarkUtil.lua](https://github.com/Gethe/wow-ui-source/blob/bebcb6bf309cf41b41bd74f8ca651e6a105b2676/Interface/AddOns/Blizzard_SharedXML/BenchmarkUtil.lua)
- [Console autocomplete clock usage](https://github.com/Gethe/wow-ui-source/blob/bebcb6bf309cf41b41bd74f8ca651e6a105b2676/Interface/AddOns/Blizzard_Console/Blizzard_Console_AutoComplete.lua)
- [AddOnPerformance.lua](https://github.com/Gethe/wow-ui-source/blob/bebcb6bf309cf41b41bd74f8ca651e6a105b2676/Interface/AddOns/Blizzard_AddOnPerformance/AddOnPerformance.lua)
- [Shared XML load manifest](https://github.com/Gethe/wow-ui-source/blob/bebcb6bf309cf41b41bd74f8ca651e6a105b2676/Interface/AddOns/Blizzard_SharedXML/Blizzard_SharedXML.toc)


## What the evidence establishes

All four branches declare `debugprofilestart`, `debugprofilestop`,
`GetTimePreciseSec`, the legacy CPU/memory functions, and `C_AddOnProfiler`.
All four also contain actual Blizzard Lua calls to `GetTimePreciseSec`, addon
memory APIs, modern addon metrics, and `C_AddOnProfiler.MeasureCall` (see each
branch's source inventory). Era, Anniversary, and Mists have identical relevant
API and implementation files after ignoring line-ending differences, including
`FrameScriptDocumentation.lua`, `OsDocumentation.lua`, `PerformanceDocumentation.lua`,
the two profiler documentation files, `AddonList.lua`, `PerformanceBar.lua`, and
`BenchmarkUtil.lua`. Forever differences relevant to the APIs are described below.

This is stronger evidence than a generated declaration alone, but it is not an
in-client availability test. The generated documentation addon is load-on-demand;
loading its Lua tables documents native functions rather than implementing them.
Its `Environment = "All"` metadata does not prove that every supported executable
exports every API, that the profiler is enabled, or that a call works in every
security context. Native implementations are absent from this repository.

### Small-scope timing

`FrameScriptDocumentation.lua` declares that `debugprofilestart()` starts the
profiling timer and `debugprofilestop()` returns elapsed milliseconds since the
last start. No timer handle or per-addon timer is declared. Neither function's
entry mentions `scriptProfile`. There are no Blizzard runtime call sites for
these two globals in the inspected `Interface/AddOns` trees; their presence is
therefore declaration evidence, not demonstrated execution.

Recommendation/inference: prefer two reads of a supported clock instead of
calling `debugprofilestart()` around every operation. A nested measurement or
another caller starting the same handle-less timer can change the baseline. Even
two `debugprofilestop()` reads can be invalidated by an intervening start; discard
negative/invalid deltas and avoid long-lived measurements using that clock.
Do not claim the documentation proves reset-free or monotonic behavior.

`OsDocumentation.lua` declares `GetTimePreciseSec()` returning a number.
Blizzard's console provides direct usage evidence: `ResumeWork` sets a deadline
to the current value plus `TIME_PER_FRAME_SEC = 0.015`, and `CheckYield` reads it
again to decide when to yield. This supports seconds-based interval timing
within a frame, without calling a reset API. See `Blizzard_Console_AutoComplete.lua`
lines 345-365 on each inspected revision. The declaration does not specify clock
origin, resolution, suspend behavior, or a formal monotonicity guarantee.

Recommended common timing primitive: feature-detect `GetTimePreciseSec` and use
`(finish - start) * 1000` for elapsed milliseconds. If unavailable, feature-detect
`debugprofilestop` and use its millisecond difference with the reset caveat. If
neither exists, report timing unavailable rather than inventing precision using
frame time. Label these intervals elapsed time, not exclusive function CPU time.
Time each synchronous work slice separately; waiting for an event, timer, or
coroutine resumption measures latency rather than just execution cost.

### Legacy CPU accounting and scriptProfile

`PerformanceDocumentation.lua` declares:

| API | Documented contract | Important gap |
| --- | --- | --- |
| `GetAddOnCPUUsage(name)` | `uiAddon` argument; numeric result | No units, refresh semantics, or enablement text |
| `GetFrameCPUUsage(frame, includeChildren)` | frame plus boolean default false; returns `call_time`, `call_count` | No attribution or reset semantics |
| `GetFunctionCPUUsage` | Returns `call_time`, `call_count` | Arguments are absent from the generated entry |
| `UpdateAddOnCPUUsage()` | Declared function | No explanation of caching or cost |
| `GetScriptCPUUsage()` | Numeric result | No explanation of aggregation |
| `ResetCPUUsage()` | Declared function | No documented scope |

None of the inspected Blizzard runtime Lua uses `GetAddOnCPUUsage`,
`GetFunctionCPUUsage`, `GetFrameCPUUsage`, or `UpdateAddOnCPUUsage`. A
case-insensitive repository search for `scriptProfile` returned no matches on
each of the four checkouts. Consequently these primary sources do NOT establish
that `scriptProfile` is registered on these clients, its default, whether reload
is required after changing it, overhead, the usual legacy function argument
conventions, or the exact CPU-counter units/attribution. Do not interpret a zero
counter as proof of zero work, and do not infer native API removal from missing
Lua call sites. Both conclusions would overstate this evidence.

Recommendation: keep legacy cumulative CPU accounting out of the required
cross-client path. If offered as an expert diagnostic, feature-detect every
function and separately verify the client's `scriptProfile` CVar, enabled state,
reload behavior, units, update timing, and known-work counter increments. Never
silently change the user's CVar or call a global CPU reset just to collect an
addon-local sample. `CVarDocumentation.lua` declares `C_CVar.GetCVarBool` with a
nullable result; a missing/unknown CVar must not be treated as an enabled profiler.
Its declaration does not itself establish any particular CVar's registration.

### Memory

`PerformanceDocumentation.lua` declares `UpdateAddOnMemoryUsage()` and
`GetAddOnMemoryUsage(name)`. Blizzard's actual implementation calls the update
function before reading addon values in `PerformanceBar.lua` lines 145-149.
`AddonListMixin:UpdateAddOnMemoryUsage` explicitly describes the update as
expensive and limits it to once per 15 seconds when shown, outside glue screens
(Era/Anniversary/Mists lines 761-772; Forever lines 775-786). Its tooltip formats
the returned value as KB, or divides by 1024 to display MB. This establishes the
UI's units convention even though the generated API entry only says `number`.

Recommendation: update and read addon memory on an explicit snapshot request or
at a coarse cadence, outside the region being timed. Use the folder/addon name
`DeleteCheapestItem`, not its display title, and feature-detect both functions.
Treat differences as reported addon memory snapshots, not allocation counts,
proof of a leak, or ownership of every object created by a particular function.
The source does not document attribution rules or GC timing.

`BenchmarkUtil.lua` contains a separate garbage-collector-control mixin that
collects, stops GC before an iteration, and restarts it afterwards. This is
Blizzard benchmark code, not a reason to stop GC in ordinary addon diagnostics.
Recommendation: leave GC policy untouched in normal gameplay; document whether
a controlled benchmark includes GC. Whole-heap deltas from `collectgarbage` or
`gcinfo` would not establish addon-local allocations; no generated contracts for
those functions were found in the inspected documentation trees.

### Modern C_AddOnProfiler

Availability evidence is present on EVERY supported branch, including Forever's
own camelot tree. This API must not be described as Retail-only based on the
client family. `AddOnProfilerDocumentation.lua` declares `IsEnabled()` and says
it is intended to be enabled for users, while explicitly allowing false.
Blizzard's Addon List and performance tooltip check `IsEnabled()` before showing
metrics. For compatibility, guard namespace, method, enum table, and enabled
state individually; a namespace existing is insufficient evidence for every method.

`GetAddOnMetric(name, metric)` returns a numeric value; time-valued metrics use
milliseconds. `GetApplicationMetric` covers the application, `GetOverallMetric`
covers addons, and `GetTopKAddOnsForMetric` returns name/value entries. The enum
contract distinguishes session average, last 60 ticks average, encounter average,
most recent tick, session peak, and threshold-exceedance tick counts. Recent does
not mean 60 seconds. Threshold metrics are counts, not milliseconds. Session
averages and peaks are not counters to subtract for an arbitrary test interval.

`AddonListMixin:GetAddonMetricPercent` uses
`addon / (application - overallAddons + addon)`, with a non-positive denominator
guard. `GetOverallMetric` uses `overallAddons / application`. Consequently those
Blizzard percentages are not simply addon/overallAddons, nor an operating-system
CPU percentage. Avoid promising apples-to-apples percentages across metrics.

`MeasureCall(func, ...)` executes a single function call and returns a results
structure BEFORE that function's own return values. The structure includes
elapsed milliseconds, clock ticks, allocated bytes, deallocated bytes, and
measured events. `GetTicksPerSecond` supplies clock frequency. `BenchmarkUtil`
actually uses `MeasureCall` once per iteration, retains results, and summarizes
the four numeric columns. This is direct Blizzard usage evidence on all four
branches, not merely a declared experimental name.

`AddMeasuredCallEvent(name)` records snapshots during active measured calls and
does nothing outside them; its name guidance recommends fewer than 48 bytes to
avoid allocations. `AddPerformanceMessageShown` is explicitly restricted internal
telemetry, not a public instrumentation primitive. Blizzard's performance-message
implementation polls every 10 seconds and suppresses dialogs in combat; this is
a UI policy, not proof that metric getters are forbidden in combat.

Forever adds `SecretArguments = "AllowedWhenUntainted"` to several profiler
entries, including `MeasureCall`, and marks its variadic argument/return contents
nullable. It adds the same secret-argument annotation to legacy addon/frame
accounting entries. These annotations are constraints concerning secret arguments,
not a blanket declaration that ordinary addon calls are unavailable. No native
error, yield, recursion, or asynchronous measurement behavior is implemented in
the Lua reference. Do not wrap arbitrary asynchronous jobs or assume error paths
and nil-valued returns are transparent without testing.

Recommendation: use modern metrics only as an optional addon-wide overview, and
`MeasureCall` only for explicit synchronous benchmark mode after capability checks.
Do not require either for basic DCI diagnostics. Keep measurement results separate
from function return values; preserve nil slots if forwarding returns. Do not
substitute allocated-minus-deallocated bytes for retained addon memory. Avoid
measuring expensive memory refreshes, printing, formatting, or result-table growth
inside the work region unless they are intentionally part of the workload.

## Runtime verification still required

For each of the four actual clients, record build/interface, exported functions,
modern enabled state and enum members, and any legacy CVar state without mutating
it. Run a known synchronous workload with repeated samples; verify nonnegative
elapsed intervals and the `MeasureCall` return ordering, nil slots, and error
behavior before using a generic wrapper. Verify legacy accounting separately
with profiling off/on and a reload only in an explicitly controlled experiment.
Capture memory before/after an explicit refresh and label its units. Keep test
configuration and workload fixed across comparisons; retain the capability report
and raw samples as repeatable evidence. This research does not claim those
in-client checks have passed.
