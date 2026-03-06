# Philosophy Reference

This document contains the foundational principles that govern how the data team thinks, plans,
and operates. These principles are drawn from practitioners at Airbnb, Facebook, Shopify, Stitch Fix,
and others, adapted for a mid-stage organization building its data foundations.

Read this file when producing strategic plans, roadmaps, communication artifacts, or any output
that requires understanding *why* the data team does things the way it does.

---

## Table of Contents

1. [Functional Data Engineering](#functional-data-engineering)
2. [The Trust Stack](#the-trust-stack)
3. [Team Operating Model](#team-operating-model)
4. [Working with Stakeholders](#working-with-stakeholders)
5. [Prioritization Philosophy](#prioritization-philosophy)
6. [Data Maturity Stages](#data-maturity-stages)
7. [Common Failure Modes](#common-failure-modes)

---

## Functional Data Engineering

Source: Maxime Beauchemin (creator of Apache Airflow). This is the technical and philosophical
foundation of how we build pipelines and models.

### The Two Principles

**Reproducibility.** Every task in the data pipeline should be deterministic and idempotent. Given
the same inputs, it produces the same outputs. You can re-run it safely without double-counting or
corrupting state. This requires immutable inputs and versioned logic.

**Re-computability.** Business logic changes. Bugs happen. You should be able to recompute any
derived dataset from scratch. This means keeping raw source data forever (the immutable staging area)
and designing transformations as pure functions that overwrite output partitions.

### Key Design Rules

**Treat partitions as immutable objects.** DML operations like UPDATE, APPEND, and DELETE are
mutations that ripple into side effects. A pure task should always fully overwrite its output
partition. Think of each partition as the immutable return value of a pure function.

**One task, one output.** Each transformation targets a single table partition. This creates a
clean mapping: table → task, partition → task instance. Lineage becomes trivial to trace.

**Locally scope all transitional state.** Temp tables, CTEs, intermediate dataframes — all must be
isolated per task instance so they can be parallelized without interference.

**Keep a persistent, immutable staging area.** All raw source data is accumulated and preserved
unchanged forever. Given this + pure tasks, you can theoretically rebuild the entire warehouse
from scratch.

**Encode changing logic with effective dates.** If a tax rule changes in 2024, don't just update
the task. Add conditional logic so the right rule applies to the right time range. A backfill of
2023 should apply 2023 rules. Business rule changes are often best expressed as "parameter tables"
with effective dates, not hardcoded conditionals.

**Avoid past-dependencies.** If partition N depends on partition N-1 of the same table, your DAG
depth grows linearly over time and backfills become serial. Design cumulative metrics in specialized
frameworks or snapshots rather than chained self-references.

**Partition on processing time, carry event time as a dimension.** This preserves immutability of
partitions even when data arrives late. It also enables time-machine queries: "February sales as
known on March 1st." The tradeoff is losing partition pruning on event time — mitigated by dual
partitioning or predicate tricks leveraging columnar format optimizations (BigQuery handles this
well with clustering on event time).

**Dimension snapshots over SCD Type 2.** Instead of managing surrogate keys and slowly changing
dimensions, take a full snapshot of the dimension at each ETL schedule. Yes, it duplicates data.
Storage is cheap. Engineering time and correctness are expensive. For very large dimensions, consider
nested/complex data types (e.g., a `state_history` STRUCT/ARRAY column with effective dates).

### Pragmatic Deviations

Strict immutability is the goal, not a religion. Common acceptable deviations:
- Joining against the latest available dimension snapshot for earlier SLAs, accepting that a
  recomputation may yield slightly different results
- Using incremental models in dbt where full refreshes are too expensive, with periodic full
  refreshes to reset accumulated drift
- Accepting that some sources (Netsuite via Fivetran, third-party CSVs) don't provide clean
  CDC and require merge/upsert patterns at the ingestion layer

The key: **document every deviation.** If you break immutability, write down why, what the risk is,
and when you plan to revisit it.

---

## The Trust Stack

Trust is the data team's product. It is built in layers, and each layer depends on the ones below it.

### Layer 1: Data Exists and Is Accessible
All important data, in one place, queryable. This is step zero. Even dumping production tables into
BigQuery hourly is a valid starting point. Accept the tech debt, note it, revisit later. Without
this, nothing else matters.

### Layer 2: Data Is Correct
Models are tested (not-null, unique, accepted-values, referential integrity, row-count thresholds).
Pipelines don't fail silently. Schema changes are detected and handled. Deduplication is explicit.
The JOIN that occasionally doubles rows is caught by a test, not by a stakeholder three months later.

### Layer 3: Data Is Understandable
Column descriptions exist. Business context is documented. Known caveats are surfaced. An analyst
can pick up a model built by another team and understand what it contains without reading the source
code. Agreed-upon modeling conventions (dimensional modeling, consistent naming, standard handling
of NULLs and unresolved dimension members) mean everyone speaks the same language.

### Layer 4: Data Is Consistent
The same metric computed by two different people yields the same number. This requires metric
definitions to live in one place (dbt), not scattered across Metabase queries and Google Sheets.
Vetted data points — key metrics stored with their question, answer, and code — don't change
over time. "How many customers did we have in Q1 2025?" returns the same answer today and in
three years.

### Layer 5: Data Is Actionable
Data is connected to decisions. Dashboards have owners. Insights come with opinions and
recommendations. The data team doesn't throw a graph at someone and walk away — they communicate
what it means and what they recommend doing about it.

Each layer requires the ones below it. You cannot have actionable data that isn't consistent.
You cannot have consistent data that isn't correct. Invest in the layers from the bottom up.

---

## Team Operating Model

### Product + Special Forces (Dual Mode)

**Data Product** is the foundational mode. It produces the data warehouse, models, pipelines,
documentation, and dashboards that the organization relies on. It follows these practices:
- All work is peer-reviewed (at least one other data person; cross-team for cross-team work)
- All business logic lives in dbt, in a single repo everyone can access
- All finalized dashboards live in Metabase (even though we dislike it — one place > the best place)
- Derived datasets are high-leverage: a well-modeled table that makes 20 future analyses easy
- Pipeline jobs are tested, don't fail silently, and are documented

**Data Special Forces** is the trust-building mode. It deploys a data person into a business team
to deliver immediate, visible impact. It follows these practices:
- Full vertical ownership: discovery → pipeline → model → analysis → communication
- Speed over polish: ship fast, accept tech debt, document it
- The embedded person becomes a domain expert and builds relationships
- When the engagement ends, artifacts are folded into the Data Product (the cleanup is planned, not hoped for)
- The insights surfaced become the case study that sells the org on data

### Centralized Management, Decentralized Work

Data people report into the data team (centralized management), but are assigned to work with
specific business teams (decentralized backlog). This provides:
- A manager who understands data work, can coach on quality, and provides career growth
- Tight feedback loops between data people and the business teams they serve
- Domain expertise that develops from sustained partnership with a team
- No central bottleneck for intake — the embedded person iterates directly with their team

### Hiring Profile

The ideal early-to-mid-stage data hire is a generalist: some software engineering, solid SQL,
strong communication skills, and a deep desire to find the story in the data. Think "data
journalist" — someone who wants to find the scoop, not someone who wants to tune hyperparameters.

Specific ML or advanced analytics hires come later, once the foundations are solid and there are
clear business problems that require those skills. Remove AI/ML from job postings until then.

---

## Working with Stakeholders

### The Requirements Contract

Data requests must include answers to these questions before work begins:

1. What decision does this enable?
2. Who is the decision-maker?
3. What accuracy is acceptable?
4. How will you know it's working?
5. What do you have today?
6. What is the cost of not doing this?

This is not bureaucracy — it's quality control. A request without this context will produce a result
that doesn't solve the actual problem. Pushing back respectfully is part of the job.

Frame it positively: "I want to make sure I build the thing that actually solves your problem. Can
you help me understand…"

### Translating Between Data and Business

When communicating with non-data stakeholders:

**Use concrete examples.** Don't say "data quality is complex." Say "when a customer clears their
cookies and comes back, our analytics sees them as a brand new person. One customer can look like
three. That's why our visitor counts are an overestimate — and why we need to be precise about
what 'user' means."

**Include opinions and recommendations.** Discovering an insight is half the work. The other half
is saying what it means and what to do about it. Many data people are uncomfortable with this,
but stakeholders need it.

**Explain the 'why' behind process.** When explaining why you need requirements upfront, don't say
"it's our process." Say "last quarter we built a dashboard that nobody used because we didn't
understand the actual decision it was supposed to inform. I don't want to waste your time or ours."

**Frame work in terms of business impact.** Not "we modeled the orders table" but "we built the
foundation that lets you see customer lifetime value across all channels, which wasn't possible before."

### Proactive Communication

Don't wait to be asked. Regularly communicate:
- What the data team is working on this quarter and why
- What we're NOT working on and why
- Key metrics and their definitions (surface ambiguity, don't hide it)
- Known data quality issues and their status
- Wins: where data informed a decision that moved a business metric

---

## Prioritization Philosophy

### The Priority Stack

1. **Trust-threatening issues.** If data is wrong and someone is making decisions on it, everything
   else stops. This includes silent pipeline failures, broken tests, stale dashboards that people
   still reference, and incorrect metric definitions.

2. **Foundation work that unblocks many things.** Centralizing a data source, building a derived
   dataset that 5 teams need, adding tests to a critical model, documenting metric definitions.
   High upfront cost, massive ongoing leverage.

3. **Special-forces deployments.** Targeted embeddings where data can make an immediate, visible
   difference. These earn trust and create the case studies that change organizational culture.

4. **Stakeholder requests that pass the requirements gate.** Prioritized by business impact and
   cost-of-not-doing-it, not by who yells the loudest.

5. **Tech debt cleanup.** Regularize special-forces artifacts. Refactor monster queries. Replace
   manual processes. Add tests. This is scheduled work, not "we'll get to it someday."

6. **Exploratory / R&D.** Recommendation systems, ML models, new tools. Invest in these once
   the foundation is solid, starting with small demos that prove value (the Flask-app-for-1%-of-users
   approach) rather than big-bang projects.

### Don't Accept New Work Without Addressing Bottlenecks

If the team is at capacity, adding more work doesn't make things go faster. Before accepting new
requests, address existing bottlenecks. This is Kanban thinking: work-in-progress limits exist for
a reason.

### Quarterly Planning

When planning a quarter:
- Review the trust stack: where are the gaps?
- Identify the 2-3 highest-leverage foundation pieces
- Plan 1-2 special-forces engagements
- Reserve 20% capacity for reactive/urgent work (it will come)
- Be explicit about what you're deferring and why
- Define success in terms of business outcomes, not deliverables

---

## Data Maturity Stages

Understanding where the org is helps calibrate expectations and communication.

### Stage 1: Data Desert
No warehouse. Data lives in production DBs, spreadsheets, SaaS tools. People make decisions on
gut feel or manual data pulls. The first priority is getting data into one queryable place.

### Stage 2: Oasis (current stage for most mid-stage orgs)
Warehouse exists. Some models exist. Small data team. Lots of gaps. Stakeholders are excited but
don't know how to work with data people. There are monster SQL queries in spreadsheets. Some
teams have hired their own "analysts" who work around the data team.

At this stage, focus on:
- Filling the most critical data gaps (get the important sources into BigQuery)
- Building the first high-leverage derived datasets
- Training stakeholders on how to request data work (the requirements contract)
- Deploying data special forces to earn trust with 1-2 key teams
- Opening up SQL access and training power users
- Establishing dbt as the single source of truth for transformations

### Stage 3: Irrigation
Foundations are solid. Most important data is modeled and tested. Stakeholders know how to work
with the data team. Dashboards are centralized. Metric definitions are consistent. The data team
starts to invest in more advanced work: experimentation platforms, ML features, self-serve analytics.

### Stage 4: Fertile Ground
Data-native organization. Metrics drive planning. Experiments drive product decisions. Failed
experiments are celebrated for what they teach. The CEO asks "what are the metrics?" in quarterly
reviews. The data team is a strategic partner, not a service org.

---

## Common Failure Modes

Recognize and avoid these patterns:

**The Ticket Queue.** Data team becomes a service desk. "Submit a ticket, get a CSV." Nobody has
time to be proactive, find cross-functional connections, or build foundations. The best people leave.

**The AI Lab.** Data team builds cool ML models that never ship because the product team can't
estimate the work and doesn't want to commit. The fix: take it one step further yourself. Build
a demo. Propose a 1% test.

**The Shadow Data Team.** Business teams hire their own analysts who build monster SQL queries
and critical spreadsheets outside the data team's purview. These inevitably break when schemas
change. The fix: embed data people into those teams and help them get to a better place, then fold
the artifacts into the product.

**Decision-Driven Report-Making.** Someone has already made a decision and wants a dashboard to
justify it. The data team becomes a "make me a chart that shows X" factory. The fix: insist on
the requirements contract. What decision are you making? What alternatives are you considering?

**The Faster Horse.** Stakeholder asks for "a column added to the dashboard" when what they
actually need is a completely different way of looking at the data. The fix: user stories, empathy,
and the discipline to ask "what are you trying to do?" before "what do you want me to build?"

**The Immaculate Backlog.** Perfect Jira hygiene, story points estimated to the decimal, velocity
charts on the wall — and none of it connected to business outcomes. The fix: throw away the
velocity metrics. Use Kanban. Measure impact, not throughput.

**The Lonely Genius.** One brilliant data person who knows everything and has documented nothing.
Single point of failure. The fix: peer review everything, document in dbt, make the bus factor
greater than one.
