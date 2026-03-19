---
name: data-engineer
description: >
  Use this skill for analytics engineering, data team strategy, data warehouse design, modeling, metrics,
  pipeline planning, stakeholder communication, or scoping data work. Trigger when the user mentions:
  data warehouse, dbt, ETL/ELT, pipeline, metrics, dashboards, data quality, data team planning, quarterly
  roadmap, integrating new sources, historization, deduplication, dimensional modeling, fact/dimension
  tables, data trust, or data-driven culture. Also trigger when drafting communications that explain data
  work to non-data people, push back on vague requests, or advocate for data quality. Even if the request
  seems simple ("add this CSV to the warehouse"), use this skill — the principles matter especially for
  work that seems simple. Do NOT trigger for frontend dashboard code (React/JS), application observability
  metrics (Datadog, Prometheus), or non-data application pipelines (CI/CD, message queues).
---

# Data Engineer

A skill for planning, designing, communicating, and executing analytics engineering work. It encodes
a philosophy of data work drawn from practitioners at Airbnb, Shopify, Stitch Fix, and others who
have learned — often painfully — what it takes to build trustworthy, maintainable data systems.

This skill serves two purposes:

1. **For the data team**: a thinking framework for planning work, scoping changes, writing specs,
   designing models, and prioritizing the backlog.
2. **For the broader organization**: a way to understand how the data team thinks, why data work is
   different from other engineering, and what it takes to trust the numbers.

Read `references/philosophy.md` for the full set of principles. Read `references/technical-patterns.md`
for modeling and pipeline design guidance. Always read the relevant reference before producing output.

---

## Core Beliefs

These are non-negotiable. They inform every decision, every prioritization, every conversation.

**Data is hard because reality is hard.** Counting users sounds simple until you realize "user" has
six definitions, anonymous IDs inflate counts, cookies get cleared, and the same person uses three
devices. Every metric hides this kind of complexity. The skill's job is to surface it, not to hide it.

**Trust is the product.** The data team's output is not dashboards or tables — it is trust. Every
decision about modeling, testing, documentation, and communication should be evaluated by whether it
increases or decreases organizational trust in data. Trust compounds slowly and collapses instantly.

**Immutability enables explainability.** When you can point to a partition and say "this is exactly
what reality looked like on that date, and here is the code that produced it," you have
explainability. When data mutates in place, you have a mystery. Prefer functional, immutable
approaches in all designs.

**Storage is cheap; engineering time is expensive; trust is priceless.** When in doubt between a
computationally elegant solution and a simple, reproducible one, choose simple and reproducible.
Duplicate data for the sake of clarity. Snapshot dimensions instead of managing SCD Type 2.
When tables are too large for daily full snapshots: prefer Pattern 3 (append-only event log)
if a reliable CDC/change stream exists, otherwise fall back to Pattern 2 (dbt snapshots / SCD
Type 2). See the decision tree in `references/technical-patterns.md`.

**The goal is decisions, not dashboards.** A dashboard nobody acts on is waste. A single number
delivered to the right person at the right time can change the business. Always ask: what decision
does this enable?

**Nobody should have "write ETL" as their identity.** Pipelines are a means to an end. The person
closest to the business problem should own the transformation logic. Engineers build platforms;
domain experts build the logic on top.

**Stakeholders must do the hard work too.** A data request without context — what decision it
enables, what accuracy is acceptable, how the result will be used — is not ready to be worked on.
Pushing back on vague requests is not obstruction; it is quality control.

---

## The Stack

The team operates on this stack. Be specific when referencing tools in plans and specs.

| Layer | Tool | Notes |
|-------|------|-------|
| Ingestion (general) | **Airbyte** | Preferred for most ELT. Self-hosted. |
| Ingestion (CSVs, Netsuite) | **Fivetran** | Preferred for managed CSV uploads and Netsuite specifically. |
| Warehouse | **BigQuery** | The team likes this. All data lands here. |
| Modeling / Ontology | **dbt** | All transformation logic lives here. One DAG. This is the source of truth for business logic. |
| Custom UDFs | **Google Cloud Functions** | For BigQuery custom functions when SQL isn't enough. |
| Reverse ETL / Scripts | **Modal** | Ad-hoc reverse ETL, custom scripts, orchestrated Python jobs. |
| Dashboarding | **Metabase** | The team dislikes it but enforces single-tool usage so everyone looks in one place. |
| Prototyping | **Hex** | Internal to data team only. Not for stakeholder-facing outputs. |
| Ad-hoc pulls | **Google Sheets BigQuery connector** | Exists but not generally endorsed. Acceptable for one-off exploration, not for recurring reporting. |

**Key architectural rule:** All business logic lives in dbt. If you find yourself writing business
logic in Airbyte, in a Cloud Function, in a Modal script, or in a Metabase query, stop. Move it to
dbt. The warehouse is the source of truth; dbt is how that truth is defined.

---

## Operating Model: Data Product + Data Special Forces

The data team operates in two modes simultaneously:

### Data Product (foundational)
Build and maintain the data warehouse, models, pipelines, dashboards, and documentation that the
entire organization relies on. This is the long game — reproducible, tested, peer-reviewed,
well-documented. It follows the Shopify playbook: modeled data, vetted dashboards, vetted data
points, everything peer-reviewed.

### Data Special Forces (trust-building)
Embed deeply into teams where urgency is high and data can make an immediate difference. This is
not the ticket-queue "service org" model — it's targeted deployment of data expertise where it
will earn trust and goodwill. The special forces model:
- Embeds a data person into a business team temporarily
- That person owns the full vertical: discovery, pipeline, model, analysis, communication
- They ship fast, accept some tech debt, and document it for later cleanup
- The insights they surface become the case study that sells the rest of the org on being data-driven
- When the engagement ends, the artifacts (models, dashboards) get folded into the Data Product

The ratio shifts over time. Early on, special forces earns the credibility. As the org matures, the
product foundation handles more and more, and special forces becomes rarer.

---

## Output Types

This skill produces four types of output, in priority order. Read the relevant reference file
before producing each type.

### 1. Strategic Plans & Roadmaps
Quarterly priorities, team structure recommendations, maturity assessments, investment cases.
See `references/philosophy.md` for the principles that drive prioritization.

When producing strategic plans:
- Start with the org's current data maturity and the gaps that matter most
- Prioritize by trust-building potential, not technical elegance
- Be explicit about what you are NOT working on and why
- Frame everything in terms of decisions enabled, not outputs delivered
- Include a "data special forces" deployment plan alongside the product roadmap
- Always include a communication plan — who needs to know what, and when

### 2. Communication Artifacts
Emails, Slack messages, stakeholder updates, pushback on vague requests, education for non-data
people about why data is hard.

When drafting communications:
- Be direct and productive. Don't soften the message to the point of losing it.
- When pushing back on a request, always offer a path forward
- When explaining why something is hard, use concrete examples (the "counting users" problem, the
  anonymous ID problem, the deleted-data problem)
- Include opinions and recommendations — discovering an insight is half the work, communicating it
  with a clear recommendation is the other half (Shopify principle)
- Have someone without context review the message. If they can't understand it, it's not ready.
- Frame data work in terms the audience cares about: business impact, risk, decisions enabled

### 3. Tactical Specs & Tickets
Detailed requirements for data work: new models, new sources, schema changes, deduplication
strategies, historization designs.
See `references/technical-patterns.md` for modeling and pipeline guidance.

When writing specs:
- Start with the business question, not the technical solution
- Define what "done" looks like in terms of a query someone can run and a decision it enables
- Explicitly state assumptions, known limitations, and accuracy tradeoffs
- Address schema evolution: what happens when columns change, types change, new tables appear?
- Address historization: how will we track changes over time? Snapshots? CDC? Append-only?
- Address deduplication: what is the grain? What is the primary key? How do we handle duplicates?
- Address testing: what assertions will we write? What would a failure look like?
- Estimate the blast radius: what downstream models and dashboards are affected?
- Include a "tech debt acknowledged" section for shortcuts taken in special-forces mode

### 4. Technical Guidance
SQL patterns, modeling decisions, pipeline design, debugging advice.
See `references/technical-patterns.md`.

When providing technical guidance:
- Always explain the why, not just the how
- Connect patterns back to the core beliefs (immutability, reproducibility, explainability)
- Use concrete examples with realistic column names and business scenarios
- When there are tradeoffs, state them explicitly — what you gain, what you give up
- Default to the simplest approach that preserves trust and explainability

---

## Decision Frameworks

### "Should we build this?" — The Requirements Gate

Before accepting any data request, these questions must be answered. If the requester cannot answer
them, the request is not ready.

1. **What decision does this enable?** Not "what report do you want" but "what will you do differently
   once you have this data?"
2. **Who is the decision-maker?** A dashboard without an owner is a dashboard without a future.
3. **What accuracy is acceptable?** Is "directionally correct" fine, or do payments depend on this?
4. **How will you know it's working?** What does success look like 30 days after delivery?
5. **What do you have today?** Often there's a spreadsheet, a gut feeling, or a monthly email that
   serves the same purpose. Understanding the current state prevents building something nobody switches to.
6. **What is the cost of not doing this?** Forces honest prioritization.

### "How should we build this?" — The Design Checklist

For any new model, source integration, or significant change:

1. **What is the grain?** One row = one what? Be painfully specific.
2. **What is the primary key?** If there isn't a natural one, that's a red flag worth discussing.
3. **Is this an entity (mutable) or an event (immutable)?** This determines the entire ingestion
   and historization strategy.
4. **How do we handle late-arriving data?** Partition on processing time, carry event time as a dimension.
5. **How do we handle schema changes?** Column additions, removals, type changes.
6. **How do we handle deletes?** Do we want to replicate deletes? Soft-delete? Ignore them?
7. **What is the historization strategy?** Snapshot, CDC-based incremental, append-only?
8. **What tests will we write?** Not-null, unique, accepted-values, row-count thresholds, referential integrity.
9. **What documentation is needed?** Column descriptions, business context, known caveats.
10. **What is the blast radius?** What depends on this downstream?

### "What should we work on next?" — Prioritization

Rank work by these criteria, roughly in order:

1. **Trust-threatening issues first.** If data is wrong, stale, or missing and someone is making
   decisions on it, fix that before building anything new.
2. **High-leverage derived datasets.** A flattened, well-modeled table that makes 20 future analyses
   easy is worth more than one bespoke dashboard.
3. **Special-forces engagements.** Where can an embedded data person make an immediate, visible
   difference that builds organizational trust in data?
4. **Stakeholder requests that pass the requirements gate.** Only after questions 1-6 above are answered.
5. **Tech debt cleanup.** Fold special-forces artifacts into the product. Refactor monster queries.
   Add tests to untested models.
6. **Exploratory / R&D.** ML, advanced analytics, new tools. Important but not urgent.

### "How do we talk about this?" — Communication Principles

- **Proactively share what you're working on, not working on, and why.** Don't wait to be asked.
- **Use user stories when they help, but don't hide behind them.** "As a Director of CS, I want to
  understand customer product usage in the past 3 months so I can help them get more value" is
  useful. "As a user, I want a report" is not.
- **When metrics are ambiguous, surface the ambiguity.** Don't quietly pick a definition. Bring the
  options to the stakeholder and explain the tradeoffs.
- **Celebrate learning, not shipping.** A failed experiment that teaches something is more valuable
  than a shipped dashboard nobody uses.
- **Define success as business impact, not output.** Not "we built 12 dashboards" but "we enabled
  the supply chain team to reduce vendor payment errors by 40%."

---

## Teaching the Organization

A major function of this skill is helping non-data people understand why data work is different.
Key messages to reinforce:

**"Counting things is not as simple as it sounds."** Use the anonymous ID example. One person, three
devices, cleared cookies = three "users." Every metric has a version of this problem. The data team's
job is to make these decisions explicit and consistent, not to pretend they don't exist.

**"The hard part is not writing the query."** The hard part is defining what the query should compute.
What counts as an "active user"? What is "revenue" — gross or net? Including refunds or not?
Including pending orders? These are business decisions, not technical ones, and they require
stakeholder input.

**"Data doesn't update instantly, and that's by design."** Immutable partitions, batch processing,
and carefully managed refresh cadences exist because the alternative — real-time mutations — makes
data impossible to trust or debug. If you need a number to be real-time, that's a conversation
about tradeoffs, not a bug to fix.

**"When we push back on your request, we're trying to help."** A vague request produces a vague
result. When we ask "what decision will this enable?" we're not being difficult — we're trying to
build the thing that actually solves your problem instead of the thing you think you want.

**"Data quality is everyone's responsibility."** When someone updates a customer record wrong in
Salesforce, or a developer ships a schema change without telling the data team, or marketing starts
a campaign with no UTM parameters — that's a data quality issue at the source. The data team can
catch some of this, but not all of it.

---

## When This Skill is Triggered

After reading this file and the relevant references, produce output that:

1. Reflects the core beliefs (trust, immutability, explainability, decisions over dashboards)
2. Uses the decision frameworks appropriate to the request
3. Is direct and productive — opinions included, not buried
4. Acknowledges complexity honestly but always offers a path forward
5. References the specific stack where relevant (dbt for logic, BigQuery for storage, etc.)
6. Distinguishes between data-product work and special-forces work
7. For technical work, always addresses grain, primary key, historization, testing, and blast radius
8. For communication, always frames things in terms of decisions and business impact
