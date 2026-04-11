# Future Considerations

## AutoEdit: Diff Algorithm Upgrade

The current `myers_diff` in `lua/ai.lua` is actually an LCS (Wagner-Fischer) algorithm — O(n×m) time and space. For typical C files this is fine, but it will be noticeably slow on files over ~2000 lines.

### Recommended upgrade: real Myers algorithm

- **Complexity:** O(n×d) time, O(d) space — where `d` is the number of edits
- **Why it's fast in practice:** for typical code edits (changing a few lines out of hundreds), `d` is small, so it stays fast even on large files
- **What Git uses:** `git diff` is based on Myers

### Other options

- **Patience diff** — used by newer Git versions by default. Groups unique lines as anchors before running Myers. Produces more human-readable diffs (hunks align on function boundaries). Harder to implement.
- **Hash-based preprocessing** — not a different algorithm, but a speedup: hash each line before comparing to avoid string comparisons in the inner loop. Easy to layer on top of any algorithm.

### Drop-in replacement

The function signature `myers_diff(a, b)` returns the same `{op="keep"|"delete"|"insert", text=string}` list regardless of algorithm. A real Myers implementation is a drop-in replacement — nothing else in the codebase needs to change.

Implement only if you notice actual slowness. The O(nd) Myers paper is short and readable.
