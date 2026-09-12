# Concert community

Approved direction: implement concert discovery, detail/session selection, session rooms, immediate admission, persisted messages, then realtime chat, in that order.

The current app uses SwiftUI and Supabase Auth. The adjacent Spring project is scaffold-only and its foundation document explicitly labels that stack as superseded for iOS. Extend the existing Supabase project, preserving authentication.

## Discovery

Store performances separately from sessions in Postgres. Performances have a UUID, optional unique KOPIS ID, title, optional poster, venue, region, date range and description. Sessions reference a performance and have explicit start/end instants and schedule source. Never infer actual sessions from a broad performance date range. Unknown end time remains nullable and blocks room creation later.

Public reads are allowed; only server/operator credentials can maintain the catalogue. Enable RLS and explicit grants. Catalogue search supports literal title matching, region, date overlap, deterministic pagination. The iOS screen distinguishes loading, failure/retry, empty catalogue and empty search results. Detail shows missing optional information honestly and dates in Asia/Seoul.

KOPIS ingestion runs server-side with a secret key, bounded requests and idempotent upserts. No private API key in iOS. External failures must leave the stored catalogue usable. Operator-supplied sessions are supported without inventing schedules.

## Rooms and chat

Rooms reference a session. Retain the requirements in ../../../../docs/requirements.md: capacity 2–10 including host; atomic immediate entry; no kicked-user reentry; host transfer; all retained history for members; revoke access on leaving/kick/expiry; calendar-month expiry in Seoul; room creation through end +24h. Adult-only access fails closed until a real verification provider is configured. Use database transactions/RPC for membership and message changes, with server-authoritative identity and authorization.

Persist before acknowledgement. Retry messages using a client-generated idempotency UUID and order by a room sequence. Realtime is a notification to reload authorized history, not a substitute for persistence. Reconnect uses sequence cursors. Prevent old subscriptions from disclosing message bodies after membership revocation.

## Verification

Use Swift Testing for decoding, stale search responses, pagination and failures; simulator build/tests and UI checks for navigation. Database tests must execute as anon/authenticated to prove grants/RLS, then test transactional room capacity, history access and lifecycle boundaries. Test fixtures must be rolled back or isolated, never presented as actual performances.

## Completion

Do not mark the full objective complete until discovery, real catalogue ingestion, rooms, persistence and realtime all work and are verified. Missing KOPIS credentials or deployment access are explicit remaining work, not permission to substitute sample production data.
