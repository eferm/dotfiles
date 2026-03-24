# Module & Package Organization

This reference covers how to structure Python projects at different scales, following the
principles in the software-architect skill.

## Scope

This reference is **not** a general guide to project layout, packaging, testing, or
tooling — every language ecosystem has its own conventions for those (e.g., for Python:
PEP 8, PEP 517, PEP 621, and the uv documentation). Consult the best-practice guidelines
for your language first.

What this file covers is narrower: how to organize modules and packages **in support of
the architectural boundaries** described in the main skill — the core/shell split,
dependency inversion, and separation of infrastructure from logic. The layouts below
show where those boundaries should be visible in the directory tree.

---

## Guiding Principle

File structure should mirror architectural boundaries. The core/shell split, the separation
of infrastructure from logic, and the one-level-of-abstraction-per-module principle should
all be visible in the directory tree. A new reader should be able to look at the file listing
and understand where business logic lives, where infrastructure lives, and where the boundary
between them is.

---

## Applications (1-5 files)

For a small service, script, or tool — use a flat application layout. Don't create
packages for the sake of it. In Python, this corresponds to `uv init` (no `--package`).

```
data-ingest/
├── pyproject.toml               # Project metadata and dependencies
├── main.py                      # Shell: entry point, config loading, wiring
├── transform.py                 # Core: cleaning rules, validation, schema mapping
├── source.py                    # Infrastructure: reads from external API
└── sink.py                      # Infrastructure: writes to data warehouse
```

**Rules at this scale:**
- `transform.py` imports nothing from `source.py` or `sink.py` (core doesn't import shell)
- `main.py` is the only file that reads environment variables or creates concrete instances
- If `transform.py` needs to describe what reading or writing capabilities it expects,
  it defines Protocols — but the implementations live in the infrastructure files

---

## Packaged Applications (5-20 files)

When a flat layout gets crowded — typically once you have internal packages — switch to
src layout. Organize by layer: core logic as its own module, infrastructure and
interface files alongside it at the package root. In Python, this corresponds to `uv init --package`.

```
data-ingest/
├── pyproject.toml
└── src/
    └── data_ingest/
        ├── __init__.py
        ├── main.py              # Entry point: config, wiring, startup
        ├── config.py            # Config loading
        ├── transform.py         # Core: cleaning, validation, mapping (pure)
        ├── sink.py              # Infrastructure: writes to data warehouse
        │
        └── source/              # Infrastructure: source connectors
            ├── __init__.py
            ├── api.py           # HTTP API source
            └── csv.py           # CSV file source
```

**Rules at this scale:**
- `transform.py` never imports from `source/`, `sink.py`, or other infrastructure modules
- `main.py` is the composition root — it creates instances and wires them together
- Only `config.py` reads environment variables
- As infrastructure files multiply, group by what they do — e.g., `source/` for
  connectors — not into a generic `infra/` bucket

### Why layer-first, not feature-first?

At this scale, layer-first is simpler because the dependency rule (core doesn't import
shell) maps directly to the directory structure. Feature-first organization works at larger
scales but adds complexity here for no benefit.

---

## Large Packaged Applications (20+ files)

At this scale, feature-first (also called "vertical slice") organization starts to earn its
keep. Each feature or domain area is self-contained, with its own core, shell, and boundary.
Still src layout.

```
data-ingest/
├── pyproject.toml
└── src/
    └── data_ingest/
        ├── __init__.py
        ├── main.py
        ├── config.py
        │
        ├── shared/                  # Cross-cutting types and protocols
        │   ├── __init__.py
        │   ├── types.py             # Record, Schema, ValidationResult
        │   └── protocols.py         # SourceReader, SinkWriter protocols
        │
        ├── source/
        │   ├── __init__.py
        │   ├── paginate.py          # Pagination, retry rules (pure)
        │   ├── api.py               # HTTP API source
        │   └── csv.py               # CSV file source
        │
        ├── transform/
        │   ├── __init__.py
        │   ├── clean.py             # Cleaning, validation, schema mapping (pure)
        │   └── schema.py            # Schema inference and enforcement (pure)
        │
        ├── sink/
        │   ├── __init__.py
        │   ├── batch.py             # Batching, dedup logic (pure)
        │   ├── warehouse.py         # Data warehouse writer
        │   └── lake.py              # Data lake writer
        │
        └── infra/                   # Cross-cutting infrastructure
            ├── __init__.py
            ├── database.py          # Connection management
            └── monitor.py           # Health checks, metrics
```

**Rules at this scale:**
- Each feature's pure-logic files (`clean.py`, `paginate.py`, `batch.py`) have
  no infrastructure imports
- Features communicate through shared types, not by importing each other's internals
- If `transform/clean.py` needs source capabilities, it receives a Protocol as a
  dependency — it doesn't import from `source/`
- `shared/` is for types and Protocols that genuinely span features, not a dumping ground.
  Heuristic: if a type would need to be independently defined in 3+ features without
  `shared/`, it belongs there. If only 2 features use it, one should own it and the other
  should depend on it directly
- `infra/` is for truly cross-cutting concerns (connection management, monitoring),
  not for per-feature infrastructure

### When to use workspaces

When a large project grows into multiple independently deployable services or publishable
libraries that share code, consider a workspace. In Python with uv, each member gets its
own `pyproject.toml` and package, while the workspace shares a single lockfile for
consistent dependency resolution (`tool.uv.workspace.members` in the root
`pyproject.toml`). Use workspace members for genuine deployment or publication
boundaries — not as a substitute for internal packages within a single service.

---

## When to Use Which Layout

**Flat layout** (source files at project root) is for applications without internal
package structure — scripts, small services, simple CLIs. In Python, this is what
`uv init` produces. See "Applications" above.

**Src layout** (`src/my_package/`) is for any project with internal packages — packaged
applications, libraries, anything with subdirectory modules. In Python, this is what
`uv init --package` and `uv init --lib` produce. See "Packaged Applications" above.

The reason src layout matters: without it, the language runtime may resolve imports from
the working directory instead of the installed package, creating a class of bugs where
code works in development but breaks once installed. Src layout prevents this entirely.

---

## File Naming Conventions

- **One module, one responsibility.** If a file has 500+ lines, it's probably doing too much.
  Split by concept, not arbitrarily.
- **Name files for what they contain, not what layer they're in.** `clean.py` is better
  than `service.py` when the file contains data cleaning logic.
- **Consider active verbs over gerunds for module names.** `clean.py` over `cleaning.py`,
  `batch.py` over `batching.py`. Active verbs are shorter and match how functions inside
  them read: `from .clean import remove_nulls`. This is a style preference — Python's
  stdlib uses both (`logging`, `inspect`) — but worth adopting consistently within a project.
- **Avoid generic names:** `utils.py`, `helpers.py`, `common.py`, `misc.py`. These become
  dumping grounds. Find the domain concept the code belongs to.
- **Package entry points should ideally be empty for applications.** An empty `__init__.py`
  is the simplest default. For libraries, a curated `__init__.py` that re-exports the
  public API is standard practice (e.g., `from .types import Record, Schema`) — this IS
  the public interface. In either case, business logic in entry points is not OK.

---

## Import Rules (Enforceable)

These rules make the architectural boundaries machine-checkable:

1. **Pure-logic modules (e.g., `transform.py`, `clean.py`, `paginate.py`) never
   import from infrastructure, interfaces, or external frameworks.** Allowed imports:
   stdlib, the `shared/` package, and other pure modules.

2. **Infrastructure modules import core types but core never imports infrastructure.**
   The dependency arrow points inward.

3. **Only the config module reads environment variables.** Everything else receives
   configuration as constructor arguments.

4. **Feature modules don't import each other's internals.** They communicate through
   `shared/` types or through Protocols passed at construction.

These rules should be enforced automatically in CI. The specific tooling varies by
ecosystem (e.g., `import-linter` for Python, ESLint rules for TypeScript), but even
a simple grep in CI is better than nothing:

```bash
# Example (Python): fail if transform/ imports from infra/
grep -rn "from.*infra" transform/ && echo "VIOLATION: core imports infra" && exit 1
```

---

## The Composition Root

Every project has exactly one place where all the pieces are wired together — typically
`main.py` or an `app.py`. This is the only place that:

- Reads environment variables (via `load_config()`)
- Creates concrete infrastructure instances (database connections, HTTP clients)
- Injects them into core services and pipeline components
- Starts the application (runs the server, starts the event loop, etc.)

```python
# main.py — the composition root
def main():
    config = load_config()

    # Create infrastructure
    source = ApiReader(config.source_url, config.api_key)
    sink = WarehouseWriter(config.warehouse_dsn)

    # Wire pipeline
    pipeline = IngestPipeline(
        reader=source,
        transformer=RecordTransformer(config.schema_path),
        writer=sink,
    )
    pipeline.run()
```

The composition root is the only "god function" in the system — it knows about everything,
but it does almost nothing. It just connects the pieces and starts the engine.

---

## Review Checklist

**Dependency direction (Import Rules 1–2)**
- [ ] Does any core module import from infrastructure or interface modules? Quick check: `grep -rn "from.*infra" transform/`. Move the dependency to a Protocol in the core package; implement it in infrastructure.
- [ ] Does infrastructure import domain types only inward, never the reverse? The dependency arrow must point from shell to core, never outward.

**Environment and config (Import Rule 3, Composition Root)**
- [ ] Does any module other than the config module read environment variables? Quick check: `grep -rn "os\.environ\|os\.getenv" --include="*.py" | grep -v config.py`. Move reads to `config.py`; pass config as constructor arguments.
- [ ] Is there exactly one composition root? If wiring logic is scattered across multiple files, consolidate into `main.py` or `app.py`.

**Feature isolation (Import Rule 4, Large Packaged Applications)**
- [ ] Do feature modules import each other's internals? Quick check: `grep -rn "from source\." sink/`. Communicate through `shared/` types or Protocols injected at construction.
- [ ] Has `shared/` accumulated feature-specific types? Move them back to the owning feature; `shared/` is only for types that genuinely span multiple features.

**File naming (File Naming Conventions)**
- [ ] Are there files named `utils.py`, `helpers.py`, `common.py`, or `misc.py`? Find the domain concept the code belongs to and rename accordingly.
- [ ] Are files named for their layer (`service.py`, `handler.py`) rather than their content? Rename to reflect what they contain: `clean.py`, `schema.py`.
- [ ] Do package entry points (`__init__.py`, `index.ts`) contain business logic? Extract logic into a named module; keep entry points to re-exports only.

**Scale and structure (Applications / Packaged / Large Packaged)**
- [ ] Has the project outgrown its organizational style? Flat layout with 15 files needs layer-first; layer-first with 30+ files across many domains needs feature-first. Restructure when navigating the directory tree becomes harder than the code itself.
- [ ] Can a new reader see the core/shell boundary from the directory listing alone? If not, restructure so that domain, infrastructure, and interface code live in clearly separated directories or files.

**CI enforcement (Import Rules, Enforceable)**
- [ ] Are architectural boundary rules enforced automatically? Add a CI check (e.g., `import-linter` for Python, ESLint rules for TypeScript, or a grep-based script) that fails on boundary violations.
