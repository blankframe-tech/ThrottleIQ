# 🏛️ ThrottleIQ — Agent Rooms & Action Hub
**Cross-Agent Task Assignment, Roster, and Autonomous Coordination Directory**

---

## 📌 Purpose & Overview

The `agent_rooms/` directory is the operational nerve center for the autonomous and human-in-the-loop agents contributing to **ThrottleIQ**. It translates the project's macro roadmaps, backlog tickets, technical debt, and owner decision items into targeted, executable, and role-bounded action plans.

Sources aggregated and continuously synchronized:
- [`DOCS/Handoff for agents and Todos/HANDOFF_Document.md`](../Handoff%20for%20agents%20and%20Todos/HANDOFF_Document.md) (Architecture, branches, production state)
- [`DOCS/Handoff for agents and Todos/needs_attention.md`](../Handoff%20for%20agents%20and%20Todos/needs_attention.md) (Owner items, store forms, hardware needs, decisions)
- [`DOCS/Handoff for agents and Todos/issues_open.md`](../Handoff%20for%20agents%20and%20Todos/issues_open.md) (Active bug, performance, and feature debt)
- [`housekeeping/owner_works_now.html`](../../../../housekeeping/owner_works_now.html) (Master project audit & decisions matrix)
- [`judge.md`](../../../judge.md) (External product readiness assessment & score breakdown)

---

## 👥 The AgentsRoom Roster

| Role | Agent Identifier | Assigned Todo Document | Primary Domain & Focus | Live Status |
| :--- | :--- | :--- | :--- | :--- |
| **Principal Architect** | `agent-1792041018615-yq0zmn` | [`architect_todo.md`](architect_todo.md) | System design, database caching, read optimizations (§104), rules & indexes, Cloud Functions migration to Blaze, sensor algorithms. | Active / Available |
| **Product Manager** | `agent-1792620967421-eu9age` | [`product_manager_todo.md`](product_manager_todo.md) | PRD metrics, store listings, screenshot capture shot-lists, forum ideas, GTM strategy, pricing, and B2B pilot agreements. | Active / Available |
| **Operations Manager** | `agent-1792041478698-nhl5qr` | [`operations_manager_todo.md`](operations_manager_todo.md) | Release engineering, security migration execution, Data Safety forms, runbooks, SOPs, Cloudinary limits, and localization review tracking. | Active / Current Agent |
| **Chief of Staff** | `agent-chief-980b39eadf07f02c` | [`chief_of_staff_todo.md`](chief_of_staff_todo.md) | Executive triage, human-owner blocker clearance, cross-agent workflow alignment, budget/cloud approvals, and test-ride scheduling. | Standby / Coordinator |
| **QA / Test Engineer** | *Dedicated Test Runner* | [`qa_engineer_todo.md`](qa_engineer_todo.md) | Automated CI gates (2,100+ tests, 274 rules), emulator E2E suites, physical phone ride tests, low-RAM stress tests, and sensor benchmarks. | On-Demand Runner |

---

## 🔄 Inter-Agent Communication Protocol

1. **Reaching Colleagues via AgentsRoom Mailbox:**
   - Use `agents_send` with the recipient's live agent ID.
   - Check mailbox status with `agents_read_inbox` and acknowledge incoming work via `agents_ack` or `agents_reply`.
   - Never duplicate messages; monitor the 12-message conversation ceiling.

2. **Durable Memory & State Preservation:**
   - Backlog updates must go to the official backlog via MCP tools.
   - Architecture decisions require markdown ADRs under [`DOCS/For Devs and Contributors/architecture/`](../For%20Devs%20and%20Contributors/architecture/).
   - Every completed workstream must update its corresponding `agent_rooms/*_todo.md` file and mark related items in [`needs_attention.md`](../Handoff%20for%20agents%20and%20Todos/needs_attention.md).

3. **Quality Gate:**
   - Every agent touching code must run `scripts/check.sh` before handoff or commit.
