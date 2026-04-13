# Anti-Patterns: Before & After

This reference contains extensive before/after examples for each principle in the
software-architect skill. Each section shows what bad looks like, explains why it's
bad, and shows the corrected version.

## Table of Contents

1. [Functional Core / Imperative Shell Violations](#1-functional-core--imperative-shell)
2. [Infrastructure Mixed with Logic](#2-infrastructure-mixed-with-logic)
3. [Boundary Violations](#3-boundary-violations)
4. [Shallow Modules](#4-shallow-modules)
5. [Constructor Side Effects](#5-constructor-side-effects)
6. [Identity vs. Operational Data Confusion](#6-identity-vs-operational-data)
7. [Dishonest Methods](#7-dishonest-methods)
8. [Too Many Parameters](#8-too-many-parameters)
9. [Optional Parameter Abuse](#9-optional-parameter-abuse)
10. [Branch Accumulation](#10-branch-accumulation) (includes: nested conditionals, wide-model-with-defaults)
11. [Mixed Pure and Impure](#11-mixed-pure-and-impure)
12. [Accumulated State Between Calls](#12-accumulated-state)
13. [Premature Abstraction](#13-premature-abstraction)
14. [Defensive Exception Handling](#14-defensive-exception-handling)
15. [Config Foraging](#15-config-foraging)
16. [Logging in Core Logic](#16-logging-in-core-logic)
17. [Async Infecting the Core](#17-async-infecting-the-core)
18. [Naming Violations](#18-naming-violations)
19. [Cached Flags (Derive, Don't Store)](#19-cached-flags)
20. [Optional Bags (Discriminated Unions)](#20-optional-bags)
21. [Sentinel Values](#21-sentinel-values)
22. [Grab-Bag Models (Phased Composition)](#22-grab-bag-models)
23. [Unbranded Primitives](#23-unbranded-primitives)
24. [Ambiguous Mutation Contract](#24-ambiguous-mutation-contract)
25. [Unscoped Mutable State](#25-unscoped-mutable-state)

---

## 1. Functional Core / Imperative Shell

### Before: Logic entangled with I/O

The entire function is untestable without mocking the database, HTTP client, and filesystem.
There is no way to verify the discount logic in isolation.

```python
class ReportGenerator:
    def __init__(self):
        self.db = psycopg2.connect(os.environ["DB_URL"])
        self.s3 = boto3.client("s3")

    def generate_monthly_report(self, month: int, year: int):
        cursor = self.db.cursor()
        cursor.execute("SELECT * FROM orders WHERE month=%s AND year=%s", (month, year))
        orders = cursor.fetchall()

        total = sum(row[3] for row in orders)
        avg = total / len(orders) if orders else 0
        top_products = Counter(row[2] for row in orders).most_common(5)

        html = f"<h1>Report {month}/{year}</h1>"
        html += f"<p>Total: ${total:.2f}, Avg: ${avg:.2f}</p>"
        html += "<ul>" + "".join(f"<li>{p}</li>" for p, _ in top_products) + "</ul>"

        with open(f"/tmp/report_{month}_{year}.html", "w") as f:
            f.write(html)

        self.s3.upload_file(f"/tmp/report_{month}_{year}.html", "reports-bucket",
                           f"reports/{year}/{month}.html")
```

### After: Pure core, thin shell

The report computation is fully testable with plain data. The shell handles all I/O.

```python
# --- Data ---

@dataclass(frozen=True)
class Order:
    product: str
    amount: Decimal

@dataclass(frozen=True)
class MonthlyReport:
    month: int
    year: int
    total: Decimal
    average: Decimal
    top_products: list[tuple[str, int]]

# --- Core: pure ---

def compile_report(orders: list[Order], month: int, year: int) -> MonthlyReport:
    total = sum(o.amount for o in orders)
    average = total / len(orders) if orders else Decimal("0")
    product_counts = Counter(o.product for o in orders)
    return MonthlyReport(
        month=month, year=year, total=total,
        average=average, top_products=product_counts.most_common(5),
    )

def render_report_html(report: MonthlyReport) -> str:
    products = "".join(f"<li>{p}</li>" for p, _ in report.top_products)
    return (f"<h1>Report {report.month}/{report.year}</h1>"
            f"<p>Total: ${report.total:.2f}, Avg: ${report.average:.2f}</p>"
            f"<ul>{products}</ul>")

# --- Shell: I/O ---

def generate_and_upload_report(month: int, year: int, db: Database, storage: Storage):
    orders = db.get_orders(month, year)
    report = compile_report(orders, month, year)
    html = render_report_html(report)
    storage.upload(f"reports/{year}/{month}.html", html)
```

---

## 2. Infrastructure Mixed with Logic

### Before: Business rule buried under infrastructure

The pricing logic is impossible to test without an HTTP server and environment variables.

```python
import os
import requests
from dotenv import load_dotenv

def get_pricing(product_id: str, region: str, user_tier: str) -> dict:
    load_dotenv()
    api_url = os.environ["PRICING_API"]
    api_key = os.environ["PRICING_KEY"]

    resp = requests.get(f"{api_url}/products/{product_id}",
                        headers={"X-API-Key": api_key})
    base_price = resp.json()["price"]

    if region == "EU":
        base_price *= 1.20  # VAT
    if user_tier == "premium":
        base_price *= 0.85  # discount

    return {"product_id": product_id, "final_price": round(base_price, 2)}
```

### After: Logic is pure, infrastructure is separate

```python
# --- Core ---

def apply_pricing_rules(base_price: Decimal, region: str, user_tier: str) -> Decimal:
    price = base_price
    if region == "EU":
        price *= Decimal("1.20")
    if user_tier == "premium":
        price *= Decimal("0.85")
    return price.quantize(Decimal("0.01"))

# --- Shell ---

def fetch_and_price(product_id: str, region: str, user_tier: str,
                    catalog: ProductCatalog) -> PricedProduct:
    base_price = catalog.get_price(product_id)
    final = apply_pricing_rules(base_price, region, user_tier)
    return PricedProduct(product_id=product_id, final_price=final)
```

---

## 3. Boundary Violations

### Before: Framework types leak into domain

The domain logic is coupled to Flask. It cannot run without a web server.

```python
from flask import request, jsonify

class OrderService:
    def create_order(self):
        data = request.get_json()
        user_id = data["user_id"]
        items = data["items"]
        # ... 50 lines of order logic ...
        return jsonify({"order_id": order.id, "total": str(order.total)})
```

### After: Domain types at the boundary

```python
# --- Domain types ---

@dataclass(frozen=True)
class CreateOrderRequest:
    user_id: str
    items: list[OrderItem]

@dataclass(frozen=True)
class OrderConfirmation:
    order_id: str
    total: Decimal

# --- Core ---

def create_order(request: CreateOrderRequest, catalog: ProductCatalog) -> OrderConfirmation:
    # pure logic, no Flask, no JSON, no HTTP
    ...

# --- Shell (Flask route) ---

@app.route("/orders", methods=["POST"])
def create_order_route():
    data = request.get_json()
    req = CreateOrderRequest(
        user_id=data["user_id"],
        items=[OrderItem(**i) for i in data["items"]],
    )
    confirmation = create_order(req, catalog)
    return jsonify({"order_id": confirmation.order_id, "total": str(confirmation.total)})
```

---

## 4. Shallow Modules

### Before: Wrapper that adds no value

The class is just indirection. The caller still needs to know everything about the underlying
operation — the interface is as complex as the implementation.

```python
class UserValidator:
    def validate_email(self, email: str) -> bool:
        return "@" in email

    def validate_name(self, name: str) -> bool:
        return len(name) > 0

    def validate_age(self, age: int) -> bool:
        return 0 < age < 150

    def validate_user(self, email: str, name: str, age: int) -> list[str]:
        errors = []
        if not self.validate_email(email):
            errors.append("invalid email")
        if not self.validate_name(name):
            errors.append("invalid name")
        if not self.validate_age(age):
            errors.append("invalid age")
        return errors
```

### After: Deep module that hides complexity

```python
@dataclass(frozen=True)
class ValidationResult:
    errors: list[str]

    @property
    def is_valid(self) -> bool:
        return len(self.errors) == 0

def validate_user(user: UserInput) -> ValidationResult:
    errors: list[str] = []
    if not _is_valid_email(user.email):
        errors.append(f"Invalid email: {user.email!r}")
    if not user.name.strip():
        errors.append("Name is required")
    if not (0 < user.age < 150):
        errors.append(f"Age out of range: {user.age}")
    return ValidationResult(errors)
```

The caller just calls `validate_user(input)` and checks `result.is_valid`. The individual
validation rules are private implementation details that don't surface in the interface.

---

## 5. Constructor Side Effects

### Before: Construction does work

Creating this object triggers network calls and reads the environment. You can't instantiate
it in a test without a live database and populated env vars.

```python
class AnalyticsClient:
    def __init__(self):
        self.api_key = os.environ["ANALYTICS_KEY"]
        self.session = requests.Session()
        self.session.headers["Authorization"] = f"Bearer {self.api_key}"
        # Verify connection on creation
        resp = self.session.get("https://analytics.example.com/health")
        resp.raise_for_status()
        self.base_url = "https://analytics.example.com"
```

### After: Construction captures identity

```python
class AnalyticsClient(Protocol):
    def track(self, event: str, properties: dict[str, str]) -> None: ...

class HttpAnalyticsClient:
    def __init__(self, base_url: str, api_key: str):
        self.base_url = base_url
        self.api_key = api_key

    def track(self, event: str, properties: dict[str, str]) -> None:
        # I/O happens here, at call time, not at construction
        ...
```

---

## 6. Identity vs. Operational Data

### Before: Everything crammed into `__init__`

```python
class EmailSender:
    def __init__(self, smtp_host: str, smtp_port: int, from_address: str,
                 to_address: str, subject: str, body: str):
        self.smtp_host = smtp_host
        self.smtp_port = smtp_port
        self.from_address = from_address
        self.to_address = to_address
        self.subject = subject
        self.body = body

    def send(self):
        # uses all six fields
        ...
```

`to_address`, `subject`, and `body` change with every email. They're operational data, not
identity. This class can only ever send one email.

### After: Identity in constructor, operational data in method

```python
class EmailSender:
    def __init__(self, smtp_host: str, smtp_port: int, from_address: str):
        self.smtp_host = smtp_host
        self.smtp_port = smtp_port
        self.from_address = from_address

    def send(self, to: str, subject: str, body: str) -> None:
        ...
```

Now the sender is reusable. Its identity (SMTP config, from address) is stable; the
per-message data varies naturally with each call.

---

## 7. Dishonest Methods

### Before: Method secretly depends on instance state

```python
class PriceCalculator:
    def __init__(self, tax_rate: Decimal):
        self.tax_rate = tax_rate
        self._last_discount = Decimal("0")  # set by a prior method call

    def apply_discount(self, price: Decimal, code: str) -> Decimal:
        discount = self._lookup_discount(code)
        self._last_discount = discount  # stash for later
        return price * (1 - discount)

    def compute_total(self, subtotal: Decimal) -> Decimal:
        # secretly depends on apply_discount having been called first
        taxed = subtotal * (1 + self.tax_rate)
        return taxed - (subtotal * self._last_discount)
```

### After: Methods declare what they need

```python
class PriceCalculator:
    def __init__(self, tax_rate: Decimal):
        self.tax_rate = tax_rate

    def apply_discount(self, price: Decimal, discount: Decimal) -> Decimal:
        return price * (1 - discount)

    def compute_total(self, subtotal: Decimal, discount: Decimal) -> Decimal:
        taxed = subtotal * (1 + self.tax_rate)
        return taxed - (subtotal * discount)
```

Both methods use `self.tax_rate` (stable identity state) and receive everything else as args.
No hidden ordering dependency.

---

## 8. Too Many Parameters

### Before: Seven-param function

```python
def create_shipment(origin_city: str, origin_state: str, origin_zip: str,
                    dest_city: str, dest_state: str, dest_zip: str,
                    weight_lbs: float) -> Shipment:
    ...
```

### After: Bundled into meaningful types

```python
@dataclass(frozen=True)
class Address:
    city: str
    state: str
    zip_code: str

def create_shipment(origin: Address, destination: Address, weight_lbs: float) -> Shipment:
    ...
```

Three params instead of seven. The Address type is also reusable elsewhere.

---

## 9. Optional Parameter Abuse

### Before: One function with five optional toggles

```python
def export_report(data: ReportData,
                  format: str = "pdf",
                  include_charts: bool = True,
                  include_appendix: bool = False,
                  compress: bool = False,
                  watermark: str | None = None) -> bytes:
    output = render_body(data)
    if include_charts:
        output = add_charts(output, data)
    if include_appendix:
        output = add_appendix(output, data)
    if format == "pdf":
        result = to_pdf(output)
    elif format == "html":
        result = to_html(output)
    elif format == "csv":
        result = to_csv(data)
    if watermark:
        result = apply_watermark(result, watermark)
    if compress:
        result = gzip_compress(result)
    return result
```

This function has 2 × 2 × 2 × 3 × 2 = 48 behavioral paths. Most combinations are probably
never tested.

### After: Separate functions with required signatures

```python
def render_report(data: ReportData) -> RenderedReport:
    return RenderedReport(body=render_body(data), charts=render_charts(data))

def render_report_with_appendix(data: ReportData) -> RenderedReport:
    report = render_report(data)
    return RenderedReport(body=report.body, charts=report.charts,
                          appendix=render_appendix(data))

def export_pdf(report: RenderedReport) -> bytes: ...
def export_html(report: RenderedReport) -> bytes: ...
def export_csv(data: ReportData) -> bytes: ...

def apply_watermark(content: bytes, text: str) -> bytes: ...
def compress(content: bytes) -> bytes: ...
```

Each function has one path. The shell composes them as needed:

```python
report = render_report_with_appendix(data)
output = export_pdf(report)
output = apply_watermark(output, "DRAFT")
output = compress(output)
```

---

## 10. Branch Accumulation

### Before: Nested conditionals

```python
def calculate_shipping(order: Order) -> Decimal:
    if order.is_domestic:
        if order.weight_lbs <= 1:
            if order.is_priority:
                return Decimal("8.99")
            else:
                return Decimal("4.99")
        elif order.weight_lbs <= 5:
            if order.is_priority:
                return Decimal("12.99")
            else:
                return Decimal("7.99")
        else:
            if order.is_priority:
                return Decimal("19.99")
            else:
                return Decimal("14.99")
    else:
        if order.weight_lbs <= 1:
            return Decimal("24.99")
        else:
            return Decimal("49.99")
```

### After: Data-driven, flat

```python
DOMESTIC_RATES: list[tuple[float, Decimal, Decimal]] = [
    #  (max_lbs, standard, priority)
    (1,  Decimal("4.99"),  Decimal("8.99")),
    (5,  Decimal("7.99"),  Decimal("12.99")),
    (float("inf"), Decimal("14.99"), Decimal("19.99")),
]

INTERNATIONAL_RATES: list[tuple[float, Decimal]] = [
    (1, Decimal("24.99")),
    (float("inf"), Decimal("49.99")),
]

def calculate_shipping(order: Order) -> Decimal:
    if not order.is_domestic:
        return _lookup_rate(INTERNATIONAL_RATES, order.weight_lbs)
    rates = DOMESTIC_RATES
    for max_lbs, standard, priority in rates:
        if order.weight_lbs <= max_lbs:
            return priority if order.is_priority else standard
    raise ValueError(f"No rate for weight: {order.weight_lbs}")
```

The logic has one path with a simple loop. New weight tiers are added to the data table, not
as new branches.

### Before: Wide model with defaults forces a guard at every site

A single loose model covering many record shapes. Every field is optional because "it depends
on the record type." The consequences ripple out into every consumer.

```python
class Event(BaseModel):
    type: str
    uuid: str = ""
    timestamp: str = ""
    message: Message | None = None
    session_id: str = ""
    cwd: str = ""
    is_sidechain: bool = False
    custom_title: str = ""
    worktree_name: str = ""

def handle(event: Event) -> None:
    if not event.uuid:
        return                                  # guard 1
    if event.is_sidechain:
        return                                  # guard 2
    if event.type not in ("user", "assistant"):
        return                                  # guard 3
    if not event.message:
        return                                  # guard 4
    if event.type == "user" and event.message.role == "user":
        ...                                     # guard 5 (compound)
    # every caller everywhere pays for the looseness of this one type
```

Nine defaults in the model produce at least five guards at every use site. The guards
restate in code what the type is refusing to say: "user events have messages, worktree
events have worktree_name, custom-title events have custom_title."

### After: Discriminated union eliminates the guards entirely

```python
class UserEvent(BaseModel):
    type: Literal["user"]
    uuid: str
    timestamp: datetime
    message: UserMessage
    session_id: str
    cwd: str

class AssistantEvent(BaseModel):
    type: Literal["assistant"]
    uuid: str
    timestamp: datetime
    message: AssistantMessage

class WorktreeEvent(BaseModel):
    type: Literal["worktree-state"]
    worktree_name: str
    cwd: str

class CustomTitleEvent(BaseModel):
    type: Literal["custom-title"]
    custom_title: str

Event = Annotated[
    UserEvent | AssistantEvent | WorktreeEvent | CustomTitleEvent,
    Field(discriminator="type"),
]

def handle(event: Event) -> None:
    # No guards needed. Type-narrow by isinstance or pattern match, and every field
    # the relevant branch touches is guaranteed present.
    match event:
        case UserEvent(message=msg):
            render_user(msg)
        case AssistantEvent(message=msg):
            render_assistant(msg)
        case WorktreeEvent() | CustomTitleEvent():
            pass  # metadata-only; not rendered
```

The nine defaults are gone. The five guards are gone. The sidechain filter and "is this a
renderable type" check happen at the boundary (where external JSON becomes `Event`), not on
every consumer. Adding a new event type is a new class, not a new branch in every caller.

This is the single biggest branch-reduction move available in a typed Python codebase.

---

## 11. Mixed Pure and Impure

### Before: Calculation that secretly sends email

```python
def calculate_low_stock_items(inventory: list[Item], threshold: int) -> list[Item]:
    low_stock = [item for item in inventory if item.quantity < threshold]
    if low_stock:
        send_email(
            to="warehouse@company.com",
            subject="Low stock alert",
            body=f"{len(low_stock)} items below threshold",
        )
    return low_stock
```

The function says "calculate" but it also sends email. A caller who just wants to know which
items are low stock will trigger alerts they didn't intend.

### After: Calculation returns data; shell acts on it

```python
# Core
def find_low_stock(inventory: list[Item], threshold: int) -> list[Item]:
    return [item for item in inventory if item.quantity < threshold]

# Shell
low_stock = find_low_stock(inventory, threshold)
if low_stock:
    notifier.send_low_stock_alert(low_stock)
```

---

## 12. Accumulated State

### Before: Methods must be called in order

```python
class DataPipeline:
    def __init__(self):
        self._raw_data = None
        self._validated = None
        self._transformed = None

    def load(self, path: str):
        self._raw_data = read_csv(path)

    def validate(self):
        # crashes if load() wasn't called
        self._validated = [r for r in self._raw_data if r.is_valid()]

    def transform(self):
        # crashes if validate() wasn't called
        self._transformed = [enrich(r) for r in self._validated]

    def save(self, dest: str):
        # crashes if transform() wasn't called
        write_csv(dest, self._transformed)
```

Nothing in the API tells the caller to call these in order. Each method mutates shared state
that the next method silently depends on.

### After: Explicit data flow, no shared mutable state

```python
# Core: each step takes input and returns output
def validate_rows(raw: list[RawRow]) -> list[ValidRow]:
    return [r for r in raw if r.is_valid()]

def transform_rows(valid: list[ValidRow]) -> list[TransformedRow]:
    return [enrich(r) for r in valid]

# Shell: explicit pipeline
def run_pipeline(source: Path, dest: Path):
    raw = read_csv(source)
    valid = validate_rows(raw)
    transformed = transform_rows(valid)
    write_csv(dest, transformed)
```

Each function declares exactly what it needs. The pipeline order is visible in the shell.
There's no hidden state to get wrong.

---

## 13. Premature Abstraction

### Before: Abstract base class for one implementation

```python
from abc import ABC, abstractmethod

class BaseNotifier(ABC):
    @abstractmethod
    def send(self, message: str) -> None: ...

    @abstractmethod
    def format_message(self, template: str, **kwargs) -> str: ...

    @abstractmethod
    def validate_recipient(self, recipient: str) -> bool: ...

class EmailNotifier(BaseNotifier):
    def send(self, message: str) -> None: ...
    def format_message(self, template: str, **kwargs) -> str: ...
    def validate_recipient(self, recipient: str) -> bool: ...
```

There's only one notifier type. The ABC adds a file, a concept, and a maintenance burden
for zero benefit. Worse, the abstract interface was designed around email's needs — if SMS
or push notifications are added later, they may not fit this shape at all.

### After: Just the concrete class; abstract when a second type appears

```python
class EmailNotifier:
    def __init__(self, smtp_host: str, from_address: str):
        self.smtp_host = smtp_host
        self.from_address = from_address

    def send(self, to: str, subject: str, body: str) -> None:
        ...
```

If a second notifier type appears later, then introduce a Protocol based on the *actual*
shared interface — which may look nothing like what you would have guessed upfront.

---

## 14. Defensive Exception Handling

### Before: Catching and swallowing in core logic

```python
def process_payment(order: Order, gateway: PaymentGateway) -> str:
    try:
        result = gateway.charge(order.total, order.payment_method)
        try:
            receipt = generate_receipt(result)
            try:
                send_receipt(order.email, receipt)
            except Exception:
                pass  # email failed, oh well
            return receipt.id
        except Exception as e:
            logger.error(f"Receipt generation failed: {e}")
            return result.transaction_id
    except PaymentDeclined:
        return "DECLINED"
    except Exception as e:
        logger.error(f"Payment failed: {e}")
        return "ERROR"
```

Exceptions are caught at every level, swallowed, and turned into magic strings. Failures
are invisible. The caller gets "ERROR" and has no way to handle different failure modes.

### After: Core raises, shell catches at the boundary

```python
# Core: raises on failure, no try/except
def generate_receipt(transaction: Transaction) -> Receipt:
    if not transaction.is_successful:
        raise PaymentFailed(transaction.id, transaction.error)
    return Receipt(
        transaction_id=transaction.id,
        amount=transaction.amount,
        timestamp=transaction.completed_at,
    )

# Shell: catches at boundary, handles each case explicitly
async def handle_payment(request: PaymentRequest, gateway: PaymentGateway,
                         mailer: Mailer, db: Database) -> Response:
    try:
        transaction = gateway.charge(request.amount, request.method)
        receipt = generate_receipt(transaction)
        db.save_receipt(receipt)
        mailer.send_receipt(request.email, receipt)
        return Response(200, receipt)
    except PaymentDeclined as e:
        return Response(402, f"Payment declined: {e.reason}")
    except PaymentFailed as e:
        return Response(500, f"Payment processing error")
```

---

## 15. Config Foraging

### Before: Classes read their own config from the environment

```python
class NotificationService:
    def __init__(self):
        self.smtp_host = os.environ.get("SMTP_HOST", "localhost")
        self.smtp_port = int(os.environ.get("SMTP_PORT", "587"))
        self.from_email = os.environ.get("FROM_EMAIL", "noreply@app.com")
        self.sms_api_key = os.environ.get("SMS_API_KEY", "")
        self.slack_webhook = os.environ.get("SLACK_WEBHOOK", "")
```

Every class forages for its own config. There's no central place to see what the app needs.
Testing requires monkeypatching `os.environ`. Missing config is discovered at runtime when
some code path finally runs.

### After: Typed config loaded once at the edge

```python
@dataclass(frozen=True)
class EmailConfig:
    smtp_host: str
    smtp_port: int
    from_address: str

@dataclass(frozen=True)
class SmsConfig:
    api_key: str

def load_email_config() -> EmailConfig:
    return EmailConfig(
        smtp_host=os.environ["SMTP_HOST"],
        smtp_port=int(os.environ["SMTP_PORT"]),
        from_address=os.environ["FROM_EMAIL"],
    )

# Missing env vars fail immediately at startup, not at runtime
# Components receive exactly what they need
class EmailNotifier:
    def __init__(self, config: EmailConfig):
        self.config = config
```

---

## 16. Logging in Core Logic

### Before: Core logic decides what to log

```python
import logging

logger = logging.getLogger(__name__)

def reconcile_accounts(expected: list[Entry], actual: list[Entry]) -> list[Entry]:
    logger.info(f"Starting reconciliation: {len(expected)} expected, {len(actual)} actual")
    discrepancies = []
    for entry in expected:
        if entry not in actual:
            logger.warning(f"Missing entry: {entry.id} - ${entry.amount}")
            discrepancies.append(entry)
    for entry in actual:
        if entry not in expected:
            logger.warning(f"Extra entry: {entry.id} - ${entry.amount}")
            discrepancies.append(entry)
    logger.info(f"Reconciliation complete: {len(discrepancies)} discrepancies")
    return discrepancies
```

The core logic is coupled to the logging framework. In tests, you see log noise. The function
can't be used in a context where you want different logging behavior.

### After: Core returns data; shell logs

```python
# Core: returns rich result, no logging
@dataclass(frozen=True)
class ReconciliationResult:
    missing: list[Entry]
    extra: list[Entry]

    @property
    def discrepancy_count(self) -> int:
        return len(self.missing) + len(self.extra)

def reconcile_accounts(expected: list[Entry], actual: list[Entry]) -> ReconciliationResult:
    expected_set = set(expected)
    actual_set = set(actual)
    return ReconciliationResult(
        missing=[e for e in expected if e not in actual_set],
        extra=[e for e in actual if e not in expected_set],
    )

# Shell: logs based on result
result = reconcile_accounts(expected, actual)
logger.info("Reconciliation complete",
            expected=len(expected), actual=len(actual),
            discrepancies=result.discrepancy_count)
for entry in result.missing:
    logger.warning("Missing entry", entry_id=entry.id, amount=str(entry.amount))
```

---

## 17. Async Infecting the Core

### Before: Pure logic made async because its caller is async

```python
async def calculate_order_total(order_id: str, db: AsyncDatabase) -> Decimal:
    order = await db.get_order(order_id)
    items = await db.get_order_items(order_id)

    subtotal = sum(item.price * item.quantity for item in items)
    if order.coupon_code:
        coupon = await db.get_coupon(order.coupon_code)
        subtotal *= (1 - coupon.discount)
    tax = subtotal * await db.get_tax_rate(order.region)
    return subtotal + tax
```

The arithmetic (sum, multiply, discount) is pure. But because it's interleaved with database
calls, the entire function is async and untestable without an async database mock.

### After: Shell gathers data, core computes synchronously

```python
# Core: pure, synchronous
def compute_order_total(items: list[OrderItem], discount: Decimal,
                        tax_rate: Decimal) -> Decimal:
    subtotal = sum(item.price * item.quantity for item in items)
    discounted = subtotal * (1 - discount)
    tax = discounted * tax_rate
    return discounted + tax

# Shell: async, gathers data, calls core
async def handle_order_total(order_id: str, db: AsyncDatabase) -> Decimal:
    order, items, tax_rate = await asyncio.gather(
        db.get_order(order_id),
        db.get_order_items(order_id),
        db.get_tax_rate_for_order(order_id),
    )
    discount = Decimal("0")
    if order.coupon_code:
        coupon = await db.get_coupon(order.coupon_code)
        discount = coupon.discount
    return compute_order_total(items, discount, tax_rate)
```

The shell also benefits — `asyncio.gather` parallelizes the independent fetches, which the
interleaved version couldn't do.

---

## 18. Naming Violations

### Before: Vague, misleading, or type-revealing names

```python
class DataManager:  # manager of what?
    def __init__(self):
        self.data_list = []  # type in the name
        self.flag = False    # flag for what?

    def process(self, input):  # process how?
        temp = input.get("value")  # temp what?
        if self.flag:
            result = self.do_thing(temp)  # what thing?
        else:
            result = self.do_other_thing(temp)
        self.data_list.append(result)
        return result

    def handle(self, item, type, do_validate=True):  # shadows builtin 'type'
        ...
```

### After: Names reveal intent

```python
class OrderAccumulator:
    def __init__(self):
        self.pending_orders: list[Order] = []
        self.is_batch_mode: bool = False

    def add_order(self, raw_input: dict[str, str]) -> Order:
        amount = Decimal(raw_input["value"])
        order = (self.create_batch_order(amount) if self.is_batch_mode
                 else self.create_single_order(amount))
        self.pending_orders.append(order)
        return order

    def validate_order(self, order: Order, category: OrderCategory) -> ValidationResult:
        ...
```

Every name tells the reader what it holds or does. No `Manager`, no `process`, no shadowed
builtins, no type-in-name variables.

---

## 19. Cached Flags

### Before: Four booleans to answer one question

```python
from pydantic import BaseModel


class ThreadState(BaseModel):
    was_interrupted: bool
    did_assistant_finish: bool
    did_assistant_error: bool
    was_tool_call_only: bool


def should_show_footer(state: ThreadState) -> bool:
    return (
        state.did_assistant_finish
        and not state.was_interrupted
        and not state.did_assistant_error
        and not state.was_tool_call_only
    )
```

Four fields to answer one question, with four mutation sites elsewhere keeping them in sync.

### After: Derive from evidence

```python
def should_show_footer(events: list[SessionEvent]) -> bool:
    latest = get_latest_assistant_message(events)
    if not latest:
        return False
    return latest.completed and not latest.error and latest.finish != "tool-calls"
```

The answer is computed from events that already exist. Testing is data-in, answer-out:

```python
def test_footer_hidden_for_aborted_runs():
    events = load_events("./fixtures/aborted-session.jsonl")
    assert should_show_footer(events) is False
```

No mocking or timing reproduction. The bug is in the events or in the pure function.

---

## 20. Optional Bags (Make Impossible States Impossible)

This is one of the most fundamental patterns in type design. When a model uses optional fields
to represent different states, the type system permits combinations that make no domain sense —
and every function that touches the model must defensively handle nonsense it should never have
been possible to create. The fix is to make wrong states unrepresentable: if the data can't
exist in an invalid shape, no code anywhere needs to check for one.

### Before: Optional fields that allow impossible states

```python
from datetime import datetime
from typing import Literal

from pydantic import BaseModel


class PaymentState(BaseModel):
    status: Literal["idle", "processing", "settled"]
    gateway: Literal["stripe", "paypal"] | None = None
    transaction_id: str | None = None
    initiated_at: datetime | None = None
    settled_at: datetime | None = None
```

When `status` is `'idle'`, should `gateway` or `transaction_id` exist? The type doesn't say.
Nothing prevents constructing `PaymentState(status="idle", settled_at="2024-01-01")` — a
payment that settled without ever being processed. Every consumer must guess, defensively
check, or silently produce wrong answers.

### After: Discriminated union — each state carries exactly its fields

```python
from datetime import datetime
from typing import Annotated, Literal, Union

from pydantic import BaseModel, Discriminator


class IdlePayment(BaseModel):
    status: Literal["idle"] = "idle"


class ProcessingPayment(BaseModel):
    status: Literal["processing"] = "processing"
    gateway: Literal["stripe", "paypal"]
    transaction_id: str
    initiated_at: datetime


class SettledPayment(BaseModel):
    status: Literal["settled"] = "settled"
    gateway: Literal["stripe", "paypal"]
    transaction_id: str
    settled_at: datetime


PaymentState = Annotated[
    Union[IdlePayment, ProcessingPayment, SettledPayment],
    Discriminator("status"),
]
```

An idle payment with a `settled_at` is now a type error, not a runtime surprise. A `match` on
`status` gives you typed access to exactly the fields that exist in that state. No defensive
checks needed — the impossible state was never created.

---

## 21. Sentinel Values

### Before: Sentinel pretends to be a real value

```python
from typing import Literal

PendingAction = Literal["none", "confirm_address", "select_shipping"]
```

`'none'` is not an action — it is the absence of one. But the type treats it as a valid action,
so every `match` or `if` must special-case it.

### After: Null represents absence honestly

```python
from typing import Literal

from pydantic import BaseModel

PendingAction = Literal["confirm_address", "select_shipping"]


class OrderState(BaseModel):
    pending_action: PendingAction | None = None
```

`None` forces the caller to handle the absent case explicitly. No sentinel can sneak through
the system pretending to be meaningful data.

---

## 22. Grab-Bag Models

### Before: Twenty optional fields

```python
from pydantic import BaseModel


class UserProfile(BaseModel):
    first_name: str | None = None
    last_name: str | None = None
    email: str | None = None
    phone: str | None = None
    company: str | None = None
    job_title: str | None = None
    billing_address: str | None = None
    card_last4: str | None = None
    # ... more
```

Every consumer does `profile.first_name or defaults.first_name` for each field. No guarantee
that related fields are present together.

### After: Phased composition — check one optional instead of eight

```python
from pydantic import BaseModel


class Identity(BaseModel):
    first_name: str
    last_name: str
    email: str


class Billing(BaseModel):
    address: str
    card_last4: str


class UserProfile(BaseModel):
    identity: Identity | None = None
    billing: Billing | None = None
```

When `identity` exists, all its fields are guaranteed present. One `if profile.identity:`
replaces eight individual checks.

---

## 23. Unbranded Primitives

### Before: Type aliases that don't protect

```python
UserId = str
TeamId = str


def get_team_members(team_id: TeamId) -> list[UserId]:
    ...

# Passes type checking — but is logically wrong
get_team_members(some_user_id)
```

A function accepting `TeamId` will happily take a `UserId` because both are `str`.

### After: NewType creates distinct types for static analysis

```python
from typing import NewType

UserId = NewType("UserId", str)
TeamId = NewType("TeamId", str)


def get_team_members(team_id: TeamId) -> list[UserId]:
    ...

# mypy/pyright will flag this as an error
get_team_members(some_user_id)  # error: expected TeamId, got UserId
```

Zero runtime cost. The distinction exists only for static checkers, which is exactly where
this class of bug is caught.

---

## 24. Ambiguous Mutation Contract

### Before: Mutates AND returns the same reference

```python
from pydantic import BaseModel


class AppState(BaseModel):
    pending_action: str | None = None
    counter: int = 0


def with_pending_action(state: AppState, action: str) -> AppState:
    state.pending_action = action
    return state
```

Callers cannot tell whether to use the return value or the original. Both refer to the same
mutated object, which silently breaks any code holding a reference to the "old" state.

### After: Pick one contract

```python
# Option A: mutate, return None
def apply_pending_action(state: AppState, action: str) -> None:
    state.pending_action = action


# Option B: clone, return new (Pydantic)
def with_pending_action(state: AppState, action: str) -> AppState:
    return state.model_copy(update={"pending_action": action})
```

Option A says "I changed your object." Option B says "Here's a new object." Neither is
ambiguous. For Pydantic models, `model_copy(update={...})` is the idiomatic clone-and-modify.

---

## 25. Unscoped Mutable State

### Before: Mutable state visible to the whole class

```python
import threading


class Writer:
    def __init__(self) -> None:
        self._pending_text: str = ""
        self._debounce_timeout: threading.Timer | None = None

    def queue_send(self, text: str) -> None:
        self._pending_text = text
        if self._debounce_timeout:
            self._debounce_timeout.cancel()
        self._debounce_timeout = threading.Timer(0.3, self._flush)
        self._debounce_timeout.start()

    def flush_now(self) -> None:
        if self._debounce_timeout:
            self._debounce_timeout.cancel()
            self._debounce_timeout = None
        self._flush()

    def something_else(self) -> None:
        # can also touch self._debounce_timeout — nothing prevents it
        ...

    def _flush(self) -> None:
        self._debounce_timeout = None
        # send self._pending_text ...
```

Every method on the class can read and write `_debounce_timeout`. The scope of possible
mutation is the entire class — if the timer is in a bad state, the bug could be in any method.

### After: Same Writer, timer encapsulated in a small class

```python
import threading
from collections.abc import Callable


class _Debouncer:
    """Timer state is encapsulated — only trigger() and clear() can touch it."""

    def __init__(self, callback: Callable[[], None], delay_seconds: float = 0.3):
        self._timer: threading.Timer | None = None
        self._callback = callback
        self._delay_seconds = delay_seconds

    def trigger(self) -> None:
        if self._timer:
            self._timer.cancel()
        self._timer = threading.Timer(self._delay_seconds, self._fire)
        self._timer.start()

    def clear(self) -> None:
        if self._timer:
            self._timer.cancel()
            self._timer = None

    def _fire(self) -> None:
        self._timer = None
        self._callback()


class Writer:
    def __init__(self) -> None:
        self._pending_text: str = ""
        self._debouncer = _Debouncer(self._flush)

    def queue_send(self, text: str) -> None:
        self._pending_text = text
        self._debouncer.trigger()

    def flush_now(self) -> None:
        self._debouncer.clear()
        self._flush()

    def something_else(self) -> None:
        # cannot touch the timer — it's inside _debouncer
        ...

    def _flush(self) -> None:
        # send self._pending_text ...
        ...
```

Same `Writer`, same behavior. But `something_else` cannot touch the timer — it's encapsulated
inside `_Debouncer`, whose public interface is just `trigger()` and `clear()`. The scope of
possible mutation is one small class, not the entire `Writer`.

---

## 26. Manual Resource Cleanup

### Before: Manual `.close()` calls

```python
def main():
    pw = sync_playwright().start()
    browser = pw.chromium.launch()
    http = httpx.Client(...)
    try:
        # ... work ...
    finally:
        http.close()
        browser.close()
        pw.stop()
```

Closing order matters and is easy to get wrong. An exception between creation and `finally`
leaks resources. Adding a new resource requires updating the `finally` block.

### After: Context managers handle cleanup

```python
def main():
    with (
        sync_playwright() as pw,
        httpx.Client(...) as http,
        pw.chromium.launch() as browser,
    ):
        # ... work ...
```

Cleanup happens automatically in reverse order. Adding a resource is one line.

---

## 27. Set-Later Instance Variables

### Before: Initialize as None, set in another method

```python
class Client:
    def __init__(self, name: str):
        self.name = name
        self.channel_id: str | None = None

    def resolve(self):
        self.channel_id = lookup_channel(self.name)

    def post(self, text: str):
        # must remember to call resolve() first
        http.post(f"/channels/{self.channel_id}/messages", ...)
```

Every method must handle the "not yet resolved" state or risk a `None` error.

### After: `cached_property` computes on first access

```python
from functools import cached_property

class Client:
    def __init__(self, name: str):
        self.name = name

    @cached_property
    def channel_id(self) -> str:
        return lookup_channel(self.name)

    def post(self, text: str):
        http.post(f"/channels/{self.channel_id}/messages", ...)
```

No initialization order to remember. The value exists when you need it.

---

## 28. Config Wrapper Classes for Static Values

### Before: Pydantic model wrapping constants

```python
class AppConfig(BaseModel, frozen=True):
    api_url: str = "https://api.example.com"
    timeout: int = 30
    max_retries: int = 3

config = AppConfig()
```

A class that holds three static strings. Nothing is parsed or validated.

### After: Module-level constants

```python
API_URL = "https://api.example.com"
TIMEOUT = 30
MAX_RETRIES = 3
```

---

## 29. Pydantic for Internal Data

### Before: Pydantic model for data passed between your own functions

```python
class DialpadMessage(BaseModel, frozen=True):
    sender: str
    text: str
    timestamp: str

    @computed_field
    @property
    def message_id(self) -> str:
        return hashlib.sha256(f"{self.sender}:{self.text}".encode()).hexdigest()[:16]
```

### After: Dataclass — no validation needed for internal data

```python
@dataclass
class DialpadMessage:
    sender: str
    text: str
    timestamp: str

    @property
    def message_id(self) -> str:
        return hashlib.sha256(f"{self.sender}:{self.text}".encode()).hexdigest()[:16]
```

Reserve Pydantic for external JSON boundaries (API responses, webhook payloads).

---

## Review Checklist

When reviewing code (yours or an agent's), run through these checks:

**Architecture & boundaries**
- [ ] Is business logic entangled with I/O? Separate into pure core and thin shell. (#1)
- [ ] Does core logic import `os`, `requests`, or framework modules? Extract infrastructure. (#2)
- [ ] Do framework types (HTTP requests, ORM rows) leak into domain logic? Convert at the boundary. (#3)
- [ ] Does a class straddle two abstraction levels? Split it. (#1)

**Interfaces & APIs**
- [ ] Is the interface as complex as the implementation? Deepen the module or remove the wrapper. (#4)
- [ ] Does `__init__` perform I/O or network calls? Move work to methods. (#5)
- [ ] Are per-call arguments crammed into `__init__`? Move them to method parameters. (#6)
- [ ] Does a method secretly depend on prior calls or hidden instance state? Declare what it needs. (#7)
- [ ] Does any function take four or more arguments? Bundle related params into a dataclass. (#8)
- [ ] Do optional params create hidden behavioral branches? Split into separate functions. (#9)
- [ ] Does any function both mutate its input and return it? Pick one contract. (#24)

**State & type design**
- [ ] Do any models allow field combinations that should be impossible? Discriminated union. (#20)
- [ ] Are there sentinel values (`'none'`, `'unknown'`, `-1`) where `None` would work? Use null. (#21)
- [ ] Does a model have many optional fields that are valid only in groups? Phased composition. (#22)
- [ ] Are there identical type aliases for different domain concepts? Brand with `NewType`. (#23)
- [ ] Are there dead type variants never constructed? Delete them. (#20)

**Code structure**
- [ ] Can any new field be derived from existing state? Derive it. (#19)
- [ ] Is mutable state visible beyond its minimal scope? Encapsulate it in a small class. (#25)
- [ ] Are there nested conditionals three levels deep? Flatten with guard clauses, tables, or polymorphism. (#10)
- [ ] Does a "calculate" function also write to a database or send email? Separate calculation from action. (#11)
- [ ] Must methods be called in a specific undocumented order? Make data flow explicit. (#12)
- [ ] Is there an ABC or Protocol with only one implementation? Delete it; abstract when a second type appears. (#13)
- [ ] Is there an if-chain where every branch returns a similar shape? Make it a table. (#10)

**Error handling, config & logging**
- [ ] Are exceptions caught and swallowed in core logic? Let them propagate to the shell. (#14)
- [ ] Do classes read `os.environ` themselves? Load config once at the edge, pass it in. (#15)
- [ ] Does core logic import `logging`? Return rich result types; let the shell log. (#16)

**Resource & lifecycle management**
- [ ] Are resources closed with manual `.close()` calls? Use `with` blocks. (#26)
- [ ] Are instance vars initialized as `None` and set by a later method? Use `cached_property`. (#27)
- [ ] Is a Pydantic model or dataclass wrapping static constants? Use module-level constants. (#28)
- [ ] Is Pydantic used for internal data passed between your own functions? Use dataclasses. (#29)
- [ ] Does a class create its own HTTP/DB client internally? Inject the client from outside. (#5, #26)

**Async & naming**
- [ ] Is pure logic marked `async` because its caller is? Have the shell await data first. (#17)
- [ ] Are there vague names like `Manager`, `process`, `data_list`? Name for intent, not type. (#18)
- [ ] Are there underscore-prefixed names? Use regular names. (#18)
