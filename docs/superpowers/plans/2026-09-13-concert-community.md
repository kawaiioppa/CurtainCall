# Concert Community Implementation Plan

> **For agentic workers:** Use superpowers:executing-plans to implement task-by-task. Keep the overall goal active through all stages.

**Goal:** Connect concert discovery to session rooms and persisted realtime group chat.

**Architecture:** SwiftUI feature screens and observable stores call Supabase. Postgres owns authorization and atomic membership/message rules; server-side ingestion owns KOPIS credentials.

**Tech Stack:** Existing SwiftUI, Observation, Swift Testing, supabase-swift 2.55.2, hosted Postgres 17.

**Spec:** ../specs/2026-09-13-concert-community-design.md

## Global Constraints

- Preserve existing email authentication.
- Use Asia/Seoul for performance/session presentation and calendar expiry.
- Never use sample data or authentication bypasses in production.
- Enforce public read / server-only catalogue mutation in Postgres.
- Keep full room/chat acceptance criteria in the spec; discovery alone is not completion.

## 1. Discovery foundation and screens

Files: `CurtainCall/Concerts/ConcertModels.swift`, `ConcertService.swift`, `ConcertStore.swift`, `ConcertViews.swift`; modify `Views/HomeView.swift`; add `CurtainCallTests/ConcertTests.swift`; add versioned catalogue migration under `supabase/migrations`.

Interfaces: `Performance: Decodable, Identifiable, Hashable`; `PerformanceSession: Decodable, Identifiable`; `ConcertFilter` (title, optional region/date); `ConcertService.performances(filter:offset:) async throws -> [Performance]`; `sessions(performanceID:) async throws -> [PerformanceSession]`.

- [ ] Test optional fields, literal search escaping, a late response after a new search, failed pagination preserving loaded results.
- [ ] Run tests to record missing feature failures.
- [ ] Create catalogue tables, keys, checks, indexes and RLS; verify public reads and denied client writes in rollback transactions.
- [ ] Implement models/service/store; page size 20, stable date+UUID order, cancel/stale request protection.
- [ ] Replace welcome-only home with catalogue; implement search, filters, load-more, refresh, retry and detail/session navigation.
- [ ] Run unit tests and simulator UI verification.

## 2. Real catalogue ingestion

Files: server-side KOPIS importer and tests, operator session import procedure, setup documentation.

- [ ] Verify official KOPIS response contract and available project secrets without displaying secret values.
- [ ] Test XML parsing, missing optional fields, upsert identity and external failure behavior using fixed response fixtures.
- [ ] Implement bounded import with server-only key; retain existing data on failures.
- [ ] Run against the real provider and verify app catalogue/detail/session reads. If a credential is missing, record the exact dependency and continue independent room work.

## 3. Rooms

Files: room migrations/tests, `CurtainCall/Rooms/` models/service/store/views.

- [ ] Write DB acceptance tests for last-slot concurrency, repeated admission, kicked reentry, host transfer, creation/expiry boundaries and adult access.
- [ ] Implement atomic server operations and restricted reads; verify as distinct authenticated users.
- [ ] Implement session room list, creation, entry, leave, host management and membership state restoration.
- [ ] Run integration and simulator tests.

## 4. Messages and realtime

Files: message migrations/tests, `CurtainCall/Chat/` models/service/store/views.

- [ ] Test retained history, authorization after leave/kick, retry deduplication, ordered pagination and reconnect.
- [ ] Implement transactional send and authorized cursor reads, then notification-only realtime and reload.
- [ ] Verify two-user messaging, disconnect/reconnect recovery, revocation and expiry end-to-end.
- [ ] Update README and audit every spec requirement before completing the goal.
