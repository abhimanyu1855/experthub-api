## graphify

ExpertHub uses [graphify](https://github.com/Graphify-Labs/graphify) for codebase navigation.

When the user types `/graphify`, follow the installed graphify skill before doing anything else.

Rules:

- For codebase questions, first run `graphify query "<question>"` when `graphify-out/graph.json` exists (project root or `~/Desktop/graphify-out/` after a merged build).
- Use `graphify path "A" "B"` for relationships and `graphify explain "X"` for focused concepts.
- If `graphify-out/wiki/index.md` exists, navigate it instead of raw source browsing.
- Read `graphify-out/GRAPH_REPORT.md` only for broad architecture review or when query/path/explain lack context.
- After modifying code, run `graphify update .` to keep the graph current (AST-only, no API cost).

Merged graph (API + web):

```bash
cd ~/Desktop && /graphify experthub-api experthub-web --wiki
```
