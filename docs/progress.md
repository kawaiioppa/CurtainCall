# Concert community progress

Goal: implement discovery → sessions → rooms/admission → persisted messages → realtime, with verified commits. Do not complete the goal at discovery.

## 2026-09-13

- Branch: `feat/concert-community`, starting at `d067622`.
- Current Supabase project: `dkqswnfiyvaefroklwmy` (CurtainCall), healthy. Public schema initially had no tables.
- Added catalogue migration and applied it through MCP. Public reads and client mutation denial verified by rollback SQL test.
- Added catalogue models, search/filter/pagination store/service and list/detail/session selection UI.
- Existing build failed due to missing Supabase imports in ContentView and AuthView; corrected both.
- Xcode simulator unit tests: 9 passed, including stale request and failed pagination behavior. UI source compiled in the second run.
- Security advisor reports pre-existing `rls_auto_enable` function execute grants and disabled leaked-password protection. Catalogue RLS had no findings. Do not claim a clean project-wide security audit.
- KOPIS API documentation v5.0 checked: XML catalogue, 31-day max range, max 100 records/page, CCCD for popular music. Schedule guidance is free text; never invent exact sessions.
- Supabase CLI available through `npx --yes supabase`; CLI account authentication is absent, while MCP works. Secret-name listing failed with Access token not provided. No KOPIS secret presence established. User was asked about key availability and later directed autonomous execution without routine questions.
- Remaining: HTTP boundary tests and UI navigation verification, KOPIS importer and live credentials, complete room and chat stages, integration tests and further commits.
