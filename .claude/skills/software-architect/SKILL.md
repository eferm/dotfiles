---
name: software-architect
description: >
  Applies deep software design principles when writing or reviewing substantial Python code.
  Covers: deep modules, minimal/no optional parameters, functional core with imperative shell,
  dependency inversion, separation of infrastructure from logic, branch reduction, error handling
  at boundaries, typed configuration, structured module organization, naming conventions, and
  async patterns. Use this skill whenever Claude is asked to build, refactor, design, or review
  classes, modules, services, or multi-file systems — even if the user doesn't mention
  "design principles" or "architecture." Trigger for any task involving code with real structure:
  designing a class, building a service, refactoring a module, reviewing architecture, organizing
  a package, or writing anything beyond a throwaway script. Do NOT trigger for one-liners,
  quick shell commands, data exploration, or simple scripts where architectural overhead would
  be absurd.
---

# Software Architect

This skill encodes software design principles drawn from *A Philosophy of Software Design*
(Ousterhout), *Clean Code* and *Clean Architecture* (Martin), *Grokking Simplicity* (Normand),
*99 Bottles of OOP* (Metz), and Gary Bernhardt's "Functional Core, Imperative Shell" pattern.

The goal is not to lecture about these ideas but to have them show up naturally in the code
you write and the changes you suggest. These principles are Python-focused in their idioms but
universal in their reasoning. Apply them with judgment — they are heuristics, not laws. The
point is always clarity and reduced complexity, not dogmatic compliance.

**For extensive before/after examples of each principle, read `references/anti-patterns.md`.**
**For module and package organization patterns, read `references/module-organization.md`.**

---

## Part 1: Architecture

### Functional core, imperative shell

This is the single most important structural pattern. It governs how entire systems are organized.

Structure every system as two distinct zones:

- A **core** of pure logic — functions and classes that take data, make decisions, and return
  results. No I/O, no infrastructure imports, no dependency on the outside world. The core is
  where all interesting logic lives. It is trivially testable with fast unit tests.

- A **shell** that handles real-world interaction — reading config, querying databases, calling
  APIs, writing files. The shell gathers input from the world, feeds it to the core, and acts
  on the results. The shell is thin, boring, and mostly plumbing.

The core never calls the shell. Data flows inward, results flow outward. The shell orchestrates;
the core decides.

```python
# Core: pure, testable, no infrastructure imports
def compute_invoice(line_items: list[LineItem], tax_rate: Decimal) -> Invoice:
    subtotal = sum(item.price * item.quantity for item in line_items)
    tax = subtotal * tax_rate
    return Invoice(subtotal=subtotal, tax=tax, total=subtotal + tax)

# Shell: thin, does I/O, calls the core
def handle_invoice_request(request: Request, db: Database, mailer: Mailer):
    line_items = db.get_line_items(request.order_id)
    tax_rate = db.get_tax_rate(request.region)
    invoice = compute_invoice(line_items, tax_rate)
    db.save_invoice(invoice)
    mailer.send_invoice(request.email, invoice)
```

### Don't mix infrastructure with logic

Business logic should have no idea it runs in a web server, that config comes from env vars,
or that data lives in Postgres. It receives parsed data, makes decisions, returns results.

Concretely:
- Never import `os`, `dotenv`, `requests`, or framework modules inside core logic.
- Never pass raw HTTP request/response objects into domain functions.
- Never let domain objects know about ORM models or serialization formats.
- Config values arrive as constructor arguments or function parameters — never by foraging
  from the environment.

### Clear boundaries between layers

The interface between layers is a deliberate translation point, not a casual function call.
The outer layer converts infrastructure types (HTTP requests, ORM rows, raw JSON) into domain
types. The inner layer works exclusively with domain types. Neither side knows the other's
representation.

Define your own domain types (dataclasses, Protocols) and convert at the boundary. Don't let
framework types leak inward or domain types leak outward.

### One level of abstraction per class

A class should operate at a consistent altitude. If one method handles HTTP headers and another
evaluates business eligibility rules, the class straddles two layers. Split it. Each class
belongs in one ring of the architecture, and crossing rings always happens through explicit
interfaces.

---

## Part 2: Interfaces & APIs

### Deep modules, simple interfaces

A class or module should do a lot while asking very little of its caller. The interface
(constructor params, public methods, function signatures) should be narrow relative to the
complexity hidden behind it. If a caller needs to understand the internals to use the thing
correctly, the abstraction isn't earning its keep.

The test: does this dramatically simplify life for the person using it? If the interface is
almost as complex as the implementation, reconsider the abstraction boundary.

### Constructors capture identity, not behavior

`__init__` receives the things that define what an object *is*: its long-lived dependencies
and configuration. It never does work — no I/O, no network calls, no mutations to external
state. Creating an instance should be free of surprises.

Dependencies are passed in, not created internally. This is dependency inversion: the object
declares what it needs; the caller decides where those things come from. Use Protocols to
define what the dependency looks like — structural typing means the caller doesn't need to
inherit from anything.

```python
class WeatherSource(Protocol):
    def fetch(self, location: str) -> WeatherReading: ...

class AlertSink(Protocol):
    def send(self, alert: Alert) -> None: ...

# Dependencies passed in as Protocols — no concrete coupling
class WeatherMonitor:
    def __init__(self, source: WeatherSource, sink: AlertSink):
        self.source = source
        self.sink = sink
```

### Distinguish identity state from operational data

What goes in `__init__` (stable, long-lived context) is fundamentally different from what goes
in method arguments (per-call data that varies each invocation).

- If the same arguments appear on every method call, they probably belong on the instance.
- If an `__init__` param is only used by one method, it probably should be a method argument.
- Instance variables should form a cohesive set that most methods actually use.

When `self` becomes a grab bag of loosely related state, the class is doing too much.

### Methods are honest about what they need

If a method can operate on its arguments alone, it should. Reaching into `self` for a value
that could have been a parameter creates hidden coupling.

The guiding question: could this be a standalone function? If yes, either make it one, or at
least write the method so it behaves like a pure function that lives on the class for
organizational reasons.

This does not mean methods shouldn't use `self`. A well-designed class has instance state that
most methods genuinely need — that shared context is the whole reason the class exists. The
smell is when `self` is used as a covert argument-passing channel between methods, or when a
method touches `self` once for one incidental value and otherwise operates purely on its args.

### Minimize parameters

Every parameter multiplies cognitive load and testing surface. The ideal function takes zero
to two arguments. Three is a yellow flag. Four or more means either the function does too much
or several params are a concept that deserves its own name (a dataclass, a named tuple).

When you see a long parameter list:
- Are some of these always passed together? Bundle them into a dataclass.
- Is this function operating at mixed levels of abstraction? Split it.
- Would a configuration object simplify construction?

### No optional parameters

This deserves its own principle because it is the most commonly violated one.

Every `Optional`, every default value, is a hidden branch. It silently forks the function's
behavior in ways the caller may not realize. A function with three optional booleans has eight
behavioral paths. **Prefer having no optional parameters at all.**

If a parameter is optional, ask: is this second behavior actually a separate function? Almost
always the answer is yes. Drop the optionality and split the responsibility. A function that
does one thing with a clear, required signature is worth more than a flexible function that
quietly does several things depending on which arguments you pass.

```python
# No: optional params create hidden branches
def process_order(order: Order, notify: bool = True, validate: bool = True,
                  format: str = "json") -> dict: ...

# Yes: separate functions, each with a clear purpose
def validate_order(order: Order) -> ValidationResult: ...
def format_order_json(order: Order) -> dict: ...
def format_order_summary(order: Order) -> str: ...
```

If you genuinely cannot avoid a default, it should be for a value that is truly universal and
whose absence would be surprising (e.g., `encoding="utf-8"`), not for toggling behavior.

---

## Part 3: Code Structure

### Reduce branches

Every conditional is a fork the reader must track. Aim for functions with a single path through
them where possible.

Strategies:
- **Early returns for guard clauses.** Handle edge cases at the top and let the main logic
  flow without nesting.
- **Polymorphism over type-checking.** Instead of `if isinstance(x, A) ... elif isinstance(x, B)`,
  give A and B a common Protocol and call the same method.
- **Dictionaries over elif chains.** Map keys to behaviors rather than checking each one.
- **Decompose compound conditions.** Give boolean expressions meaningful names via intermediate
  variables or small functions.

A function with one `if` is readable. A function with nested `if/elif/else` three levels deep
is a maintenance hazard.

### Separate pure from impure (actions, calculations, data)

A function should either compute a result (pure) or perform an effect (impure), and its name
should make clear which.

Pure functions — same inputs always produce same output, no side effects — are trivially
testable, cacheable, composable, and safe to call from anywhere. Maximize the amount of code
in this category.

Side effects (I/O, mutation, network calls, logging, time-dependent behavior) are necessary
but should be explicit and confined. A function called `calculate_total` that also writes to a
database is lying about what it does.

The *Grokking Simplicity* vocabulary:
- **Data**: inert values (dicts, dataclasses, strings). No behavior, no effects.
- **Calculations**: pure functions. Data in, data out.
- **Actions**: anything that depends on *when* or *how many times* it runs.

Push actions to the edges. Let the bulk of your code be calculations operating on data.

### Avoid accumulating state between calls

Objects whose behavior depends on the history of prior method calls impose heavy cognitive
load — the caller must know what order to call things in, and bugs emerge from unexpected
sequences. Each method invocation should be as self-contained as possible.

When sequencing genuinely matters, make it explicit in the API: a pipeline, a builder with a
terminal method, a state machine with named states. Don't rely on callers intuitively
discovering the right order.

### Abstract only when earned

Don't extract a base class, Protocol, or shared utility until you've seen the concrete pattern
at least three times (the Rule of Three). Premature abstraction locks you into a structure that
may not fit future cases. Duplication is cheaper than the wrong abstraction — duplication is
just tedious, while a wrong abstraction actively fights you when requirements change.

The test: does it make the caller's life *dramatically* simpler? If it just adds a layer of
indirection without hiding meaningful complexity, it's not earning its keep.

---

## Part 4: Error Handling

### Let exceptions propagate; catch at boundaries

Follow Python's natural exception model. Don't defensively catch exceptions inside core logic.
Let them propagate upward to the shell, where they can be handled in context — logged, mapped
to HTTP responses, retried, or reported.

**In core logic:** Raise exceptions when invariants are violated. Don't catch exceptions from
operations you call unless you can genuinely handle them (not just log and re-raise). Don't
return None as a substitute for raising — it forces every caller to check and turns a clear
failure into a silent one.

**At boundaries (the shell):** Catch specific exceptions from infrastructure (network errors,
database failures, file-not-found). Translate them into appropriate responses for the caller.
This is the only place try/except blocks should be common.

**Custom exceptions** should be domain-meaningful. Prefer `OrderNotFound` over a bare
`ValueError`. Name them after what went wrong in domain terms, not in infrastructure terms.

```python
# Core: raise when invariants fail, no defensive catching
def activate_user(user: User) -> User:
    if user.status == "banned":
        raise UserBanned(user.id)
    return User(id=user.id, name=user.name, status="active")

# Shell: catch at the boundary, translate to response
def handle_activation(request: Request, db: Database) -> Response:
    try:
        user = db.get_user(request.user_id)
        activated = activate_user(user)
        db.save_user(activated)
        return Response(200, activated)
    except UserNotFound:
        return Response(404, "User not found")
    except UserBanned:
        return Response(403, "User is banned")
    except DatabaseError:
        return Response(500, "Internal error")
```

---

## Part 5: Configuration

### Read environment once at the edge, pass typed config

The environment is infrastructure. Core logic never touches it. Read environment variables,
config files, or secrets exactly once — at application startup — and parse them into a typed,
frozen dataclass. Pass that config object into everything that needs it.

```python
@dataclass(frozen=True)
class AppConfig:
    db_url: str
    api_timeout_seconds: int
    max_retries: int

def load_config() -> AppConfig:
    return AppConfig(
        db_url=os.environ["DB_URL"],
        api_timeout_seconds=int(os.environ["API_TIMEOUT"]),
        max_retries=int(os.environ["MAX_RETRIES"]),
    )

# At the edge — the only place that touches os.environ
config = load_config()
db = Database(config.db_url)
service = OrderService(db, config.api_timeout_seconds)
```

The config dataclass is frozen because configuration should not change after startup. If a
component only needs one value from the config, pass that value directly — don't pass the
whole config object and let the component rummage through it.

---

## Part 6: Logging

### Logging is a side effect — push it to the shell

Logging depends on *when* it runs, which makes it an action, not a calculation. Core logic
should not import logging or decide what gets logged.

Instead, have core functions return rich result types that carry all the information the shell
needs to decide what to log. The shell — which already handles all other side effects — also
handles logging.

```python
# Core: returns data, doesn't log
def reconcile(expected: list[Entry], actual: list[Entry]) -> ReconciliationResult:
    missing = [e for e in expected if e not in actual]
    extra = [e for e in actual if e not in expected]
    return ReconciliationResult(missing=missing, extra=extra, balanced=not missing and not extra)

# Shell: logs based on the result
result = reconcile(expected, actual)
if not result.balanced:
    logger.warning("Reconciliation mismatch", missing=len(result.missing), extra=len(result.extra))
```

When logging in the shell, use structured logging (key-value pairs) rather than format strings.
This makes logs searchable and parseable by observability tools.

---

## Part 7: Naming Conventions

### Names reveal intent and abstraction level

- **Functions**: verb phrases that say what the function does. `validate_order`, `compute_tax`,
  `send_alert`. If the function is pure, the verb should describe a computation
  (`compute_`, `determine_`, `evaluate_`). If it's an action, the verb should describe the
  effect (`send_`, `save_`, `fetch_`).

- **Classes**: noun phrases for what the object *is*. `OrderProcessor`, `TaxCalculator`,
  `WeatherMonitor`. Avoid vague suffixes like `Manager`, `Handler`, `Helper`, `Utils` — these
  signal that the class has no clear responsibility. If you can't name it precisely, it
  probably does too much.

- **Variables**: describe the content, not the type. `user_count` not `user_count_int`.
  `active_orders` not `order_list`. Use plural nouns for collections and singular for items.

- **Boolean variables and functions**: phrase as assertions. `is_valid`, `has_permission`,
  `can_retry`. The name should read naturally in an `if` statement.

- **Constants**: `UPPER_SNAKE_CASE`. Name them for what they mean, not what they are:
  `MAX_RETRY_ATTEMPTS` not `THREE`.

- **Private methods**: use a single leading underscore. If you need a double underscore, the
  class is probably too large and should be split.

- **Modules**: short, lowercase, descriptive. `orders.py`, `tax.py`, `notifications.py`.
  Avoid `utils.py` and `helpers.py` — they become dumping grounds. If something is utility-like,
  find the domain concept it actually belongs to.

---

## Part 8: Async Patterns

### Async follows the same principles — don't let it erode structure

Async code is especially prone to mixing infrastructure with logic because the `async`/`await`
keywords propagate virally. Resist the temptation to make core logic async just because its
caller is.

- **Keep core logic synchronous.** Pure functions don't need to be async — they don't do I/O.
  Only the shell (which performs actual I/O) should be async.

- **Don't let async infect your domain.** If your domain function needs data that requires an
  async call, have the shell await the data first and pass it in. Don't make the domain
  function async just to fetch its own dependencies.

```python
# No: async has infected the core
async def compute_discount(user_id: str, db: Database) -> Decimal:
    user = await db.get_user(user_id)
    if user.tier == "premium":
        return Decimal("0.20")
    return Decimal("0.0")

# Yes: shell fetches, core computes
def compute_discount(user_tier: str) -> Decimal:
    if user_tier == "premium":
        return Decimal("0.20")
    return Decimal("0.0")

async def handle_discount_request(user_id: str, db: Database) -> Decimal:
    user = await db.get_user(user_id)
    return compute_discount(user.tier)
```

- **Gather concurrent work in the shell.** Use `asyncio.gather` or `TaskGroup` at the shell
  level to parallelize I/O, then feed all results into synchronous core logic at once.

- **Protocols work with async too.** Define async Protocols for infrastructure boundaries:

```python
class AsyncUserStore(Protocol):
    async def get(self, user_id: str) -> User: ...
    async def save(self, user: User) -> None: ...
```

---

## Applying These Principles

When writing new code, let these principles guide structure from the start. The code should
embody them without inline commentary explaining each decision.

When reviewing or refactoring existing code, apply the principles that address the most
significant sources of complexity first. Not every principle applies to every codebase.
Prioritize the changes that yield the most clarity per line changed.

Use judgment. A four-parameter function that reads clearly is better than a forced refactor
that adds a config dataclass nobody understands. The goal is always reduced complexity and
honest interfaces, not checklist compliance.

**After presenting code, include a brief summary of the key design decisions and which
principles drove them.** Keep it concise — a few sentences or a short list. Focus on the
structural choices: what was separated, what was pushed to the boundary, what was kept pure.
If refactoring, call out specifically what changed and why. This helps the reader understand
architectural intent without reverse-engineering it from the code.

---

## Reference Files

- **`references/anti-patterns.md`** — Extensive before/after examples for every principle.
  Read this when you need concrete illustrations of what bad looks like and how to fix it.
- **`references/module-organization.md`** — Package structure patterns for different project
  sizes. Read this when organizing or restructuring a project.
