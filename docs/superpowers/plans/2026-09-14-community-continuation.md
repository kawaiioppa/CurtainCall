# Community continuation implementation plan

> Use Superpowers implementation and review skills; continue without routine approval pauses under the user's instruction to develop in the reviewed order.

**Goal:** Complete the reviewed sequence: room navigation/management, persisted chat, realtime recovery, catalogue ingestion, and release readiness.
**Architecture:** Keep SwiftUI and Supabase. Postgres is authoritative for identity, membership, capacity, lifecycle and message authorization. Swift stores expose loading, errors and membership loss explicitly.
**Spec:** ../specs/2026-09-13-concert-community-design.md

## Decisions and constraints
- The user's continuation approves the sequence presented in the review. Reuse the existing approved architecture; no separate design approval needed.
- Work on the existing clean `feat/concert-community` checkout so changes remain in the user's active workspace.
- Never substitute fixture data for actual catalogue data. No private key in the app.
- Linux can verify portable Swift and SQL behavior; iOS build/navigation evidence still requires macOS/Xcode.
- No publication, shared-branch push or destructive data changes as part of local development.

## 1. Repair entry flow and connect room management
- [ ] Regression tests for structured room errors, existing member reopening a full room, loading failures and membership revocation.
- [ ] Fix recovery-link failure and provide safe cancellation.
- [ ] Extend RoomModels/RoomService; add RoomStore, RoomDetailView, MyRoomsView.
- [ ] Navigate to returned room ID after create/join; allow existing members to open full rooms.
- [ ] Connect participant list, leave, kick, host transfer and room editing with confirmations and authoritative reload.
- [ ] Correct adult-only form state and creation eligibility messaging.
- [ ] Run Swift tests and DB acceptance tests; independently review changes.

## 2. Persist messages
- [ ] Add SQL acceptance tests for authorization, retained history, idempotent send and room sequence ordering.
- [ ] Add migration for private message storage and authorized RPC reads/writes; paginate history.
- [ ] Add Chat models/service/store/view; show pending/failed messages and retry with same UUID.
- [ ] Verify two-user send/read and revoked/expired membership behavior.

## 3. Realtime and recovery
- [ ] Use notification-only subscription, reload authorized rows, sequence catch-up and subscription teardown.
- [ ] Test reconnect, missed notifications, foreground refresh and leave/kick/expiry handling.

## 4. Real catalogue operations
- [ ] Implement bounded KOPIS XML ingestion with fixtures, idempotent upserts and failure preservation.
- [ ] Provide operator session registration with explicit start/end/source.
- [ ] Verify real provider using credentials when available; document exact unmet dependencies.

## 5. Release readiness and full audit
- [ ] Implement/report remaining moderation, account management and operational requirements without inventing provider credentials or legal copy.
- [ ] Verify app build and two-device UI behavior on an available Apple environment.
- [ ] Update README/progress with actual evidence and outstanding deployment/configuration needs.
