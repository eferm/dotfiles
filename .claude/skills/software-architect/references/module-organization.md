# Module & Package Organization

This reference covers how to structure Python projects at different scales, following the
principles in the software-architect skill.

## Scope

This reference is **not** a general guide to project layout, packaging, testing, or
tooling — every language ecosystem has its own conventions for those (e.g., for Python:
PEP 8, PEP 517, PEP 621, etc). Consult the best-practice guidelines for your language first.

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

## Small Projects (1-5 files)

For a small service, script, or tool — keep it flat. Don't create packages for the sake of it.

```
my_service/
├── pyproject.toml               # Project metadata and dependencies
├── main.py                      # Shell: entry point, config loading, wiring
├── domain.py                    # Core: data types, pure logic
├── storage.py                   # Infrastructure: database, file I/O
└── notifications.py             # Infrastructure: email, SMS, webhooks
```

**Rules at this scale:**
- `domain.py` imports nothing from `storage.py` or `notifications.py` (core doesn't import shell)
- `main.py` is the only file that reads environment variables or creates concrete instances
- If `domain.py` needs to describe what storage or notification capabilities it expects,
  it defines Protocols — but the implementations live in the infrastructure files

---

## Medium Projects (5-20 files)

When a flat layout gets crowded, organize by architectural layer first, then by domain concept
within each layer.

```
my_service/
├── pyproject.toml       # Project metadata and dependencies
├── main.py              # Entry point: config, wiring, startup
├── config.py            # Config dataclass + load_config()
│
├── domain/              # Core: pure logic, no infrastructure imports
│   ├── __init__.py
│   ├── types.py         # Shared data types (dataclasses, enums)
│   ├── orders.py        # Order-related business logic
│   ├── pricing.py       # Pricing calculations
│   └── validation.py    # Validation rules
│
├── infra/               # Shell: infrastructure implementations
│   ├── __init__.py
│   ├── database.py      # Database access
│   ├── http_client.py   # External API calls
│   └── email.py         # Email sending
│
├── interfaces/          # Shell: inbound interfaces (API routes, CLI, etc.)
│   ├── __init__.py
│   ├── api.py           # HTTP route handlers
│   └── cli.py           # CLI commands
│
└── protocols.py         # Protocol definitions (or in domain/protocols.py)
```

**Rules at this scale:**
- `domain/` never imports from `infra/` or `interfaces/`
- `interfaces/` converts external types to domain types at the boundary
- `infra/` implements Protocols defined in `domain/` or `protocols.py`
- `main.py` is the composition root — it creates instances and wires them together
- `config.py` is the only file that reads environment variables

### Why layer-first, not feature-first?

At this scale, layer-first is simpler because the dependency rule (core doesn't import shell)
maps directly to the import rule (domain/ doesn't import from infra/). You can verify this
with a linter or a grep. Feature-first organization (grouping orders/, pricing/, etc. each
with their own domain + infra) works at larger scales but adds complexity here for no benefit.

---

## Large Projects (20+ files)

At this scale, feature-first (also called "vertical slice") organization starts to earn its
keep. Each feature or domain area is self-contained, with its own core, shell, and boundary.

```
my_service/
├── pyproject.toml
├── main.py
├── config.py
│
├── shared/                  # Cross-cutting domain types and utilities
│   ├── __init__.py
│   ├── types.py             # Shared value objects (Money, Address, etc.)
│   └── protocols.py         # Shared Protocol definitions
│
├── orders/
│   ├── __init__.py
│   ├── domain.py            # Order business logic (pure)
│   ├── types.py             # Order-specific types
│   ├── storage.py           # Order persistence
│   └── api.py               # Order HTTP routes
│
├── pricing/
│   ├── __init__.py
│   ├── domain.py            # Pricing rules (pure)
│   ├── types.py
│   └── external.py          # External pricing API client
│
├── notifications/
│   ├── __init__.py
│   ├── domain.py            # Notification logic (which events trigger which alerts)
│   ├── types.py
│   ├── email.py             # Email implementation
│   └── sms.py               # SMS implementation
│
├── infra/                   # Truly cross-cutting infrastructure
│   ├── __init__.py
│   ├── database.py          # Connection management, base classes
│   └── middleware.py         # HTTP middleware, error handling
```

**Rules at this scale:**
- Each feature's `domain.py` is still pure — no infrastructure imports
- Features communicate through shared types, not by importing each other's internals
- If `orders/domain.py` needs pricing, it receives a pricing function or Protocol as a
  dependency — it doesn't import from `pricing/`
- `shared/` is for types and Protocols that genuinely span features, not a dumping ground
- `infra/` at the root is for truly cross-cutting concerns (database connection pools,
  HTTP middleware), not for per-feature infrastructure

---

## Flat Layout vs Src Layout

The examples above use flat layout — source packages sit at the project root alongside
the project manifest (e.g., `pyproject.toml`, `package.json`). This is the simpler choice
for applications and services.

For installable libraries, consider src layout (`src/my_package/`). It prevents the
working directory from shadowing the installed package during testing, ensuring tests
always run against the installed version. The tradeoff is a slightly deeper directory
tree and requiring an install step during development.

---

## File Naming Conventions

- **One module, one responsibility.** If a file has 500+ lines, it's probably doing too much.
  Split by concept, not arbitrarily.
- **Name files for what they contain, not what layer they're in.** `pricing.py` is better
  than `service.py` when the file contains pricing logic.
- **Avoid generic names:** `utils.py`, `helpers.py`, `common.py`, `misc.py`. These become
  dumping grounds. Find the domain concept the code belongs to.
- **Package entry points should ideally be empty.** An empty `__init__.py` (or no entry
  point at all, in languages that support it) is the simplest default. Re-exporting a
  curated public API (e.g., `from .types import Order, OrderItem`) is a more advanced
  pattern and also fine — but business logic in entry points is not.

---

## Import Rules (Enforceable)

These rules make the architectural boundaries machine-checkable:

1. **`domain/` (or any feature's `domain.py`) never imports from `infra/`, `interfaces/`,
   or external frameworks.** Allowed imports: stdlib, the `shared/` package, and other
   domain modules.

2. **Infrastructure modules import domain types but domain never imports infrastructure.**
   The dependency arrow points inward.

3. **Only the config module reads environment variables.** Everything else receives
   configuration as constructor arguments.

4. **Feature modules don't import each other's internals.** They communicate through
   `shared/` types or through Protocols passed at construction.

These rules should be enforced automatically in CI. The specific tooling varies by
ecosystem (e.g., `import-linter` for Python, ESLint rules for TypeScript), but even
a simple grep in CI is better than nothing:

```bash
# Example (Python): fail if domain/ imports from infra/
grep -rn "from.*infra" domain/ && echo "VIOLATION: domain imports infra" && exit 1
```

---

## The Composition Root

Every project has exactly one place where all the pieces are wired together — typically
`main.py` or an `app.py`. This is the only place that:

- Reads environment variables (via `load_config()`)
- Creates concrete infrastructure instances (database connections, HTTP clients)
- Injects them into domain services and handlers
- Starts the application (runs the server, starts the event loop, etc.)

```python
# main.py — the composition root
def main():
    config = load_config()

    # Create infrastructure
    db = PostgresDatabase(config.db_url)
    mailer = SmtpMailer(config.email)
    pricing_client = HttpPricingClient(config.pricing_api_url)

    # Wire domain services
    order_service = OrderService(db, mailer)
    pricing_service = PricingService(pricing_client)

    # Create and start the app
    app = create_api(order_service, pricing_service)
    app.run(host="0.0.0.0", port=config.port)
```

The composition root is the only "god function" in the system — it knows about everything,
but it does almost nothing. It just connects the pieces and starts the engine.

---

## Review Checklist

**Dependency direction (Import Rules 1–2)**
- [ ] Does any domain module import from `infra/`, `interfaces/`, or external frameworks? Quick check: `grep -rn "from.*infra\|from.*interfaces" domain/`. Move the dependency to a Protocol in `domain/`; implement it in `infra/`.
- [ ] Does infrastructure import domain types only inward, never the reverse? The dependency arrow must point from shell to core, never outward.

**Environment and config (Import Rule 3, Composition Root)**
- [ ] Does any module other than the config module read environment variables? Quick check: `grep -rn "os\.environ\|os\.getenv" --include="*.py" | grep -v config.py`. Move reads to `config.py`; pass config as constructor arguments.
- [ ] Is there exactly one composition root? If wiring logic is scattered across multiple files, consolidate into `main.py` or `app.py`.

**Feature isolation (Import Rule 4, Large Projects)**
- [ ] Do feature modules import each other's internals? Quick check: `grep -rn "from orders\." pricing/`. Communicate through `shared/` types or Protocols injected at construction.
- [ ] Has `shared/` accumulated feature-specific types? Move them back to the owning feature; `shared/` is only for types that genuinely span multiple features.

**File naming (File Naming Conventions 1–4)**
- [ ] Are there files named `utils.py`, `helpers.py`, `common.py`, or `misc.py`? Find the domain concept the code belongs to and rename accordingly.
- [ ] Are files named for their layer (`service.py`, `handler.py`) rather than their content? Rename to reflect what they contain: `pricing.py`, `reconciliation.py`.
- [ ] Do package entry points (`__init__.py`, `index.ts`) contain business logic? Extract logic into a named module; keep entry points to re-exports only.

**Scale and structure (Small / Medium / Large Projects)**
- [ ] Has the project outgrown its organizational style? Flat layout with 15 files needs layer-first; layer-first with 30+ files across many domains needs feature-first. Restructure when navigating the directory tree becomes harder than the code itself.
- [ ] Can a new reader see the core/shell boundary from the directory listing alone? If not, restructure so that domain, infrastructure, and interface code live in clearly separated directories or files.

**CI enforcement (Import Rules, Enforceable)**
- [ ] Are architectural boundary rules enforced automatically? Add a CI check (e.g., `import-linter` for Python, ESLint rules for TypeScript, or a grep-based script) that fails on boundary violations.
