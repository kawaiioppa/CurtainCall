# Verification

## Portable Swift logic

With Swift 6.2 or newer on a supported platform:

```sh
swift test --jobs 4
```

The package compiles the app's actual models, services and observable stores. It
uses an isolated in-memory Auth storage and a loopback-only client for defaults;
this support client is outside the iOS target. Tests must inject network behavior
where needed. The package is not an iOS build and does not verify SwiftUI types,
navigation, Keychain or deep-link delivery by the operating system.

On Fedora, Ubuntu Swift toolchains may need compatible versioned libcurl symbols.
Use a compatible toolchain/runtime rather than replacing system libraries. The
2026-09-14 local run uses an isolated libcurl in `/tmp/curtaincall-curl/lib` with
`LD_LIBRARY_PATH` and `swift test -Xlinker -L/tmp/curtaincall-curl/lib`.

## Database behavior

With PostgreSQL `initdb`, `pg_ctl`, and `psql` on PATH, run as an unprivileged user:

```sh
python3 validation/test_database.py
```

This creates a disposable cluster listening only on its private Unix socket,
applies all migrations, runs rollback SQL tests, and tests two transactions
contending for the final room slot. The server is stopped and its directory
removed at completion. A minimal local `auth.users`/`auth.uid()` fixture supports
policy checks; hosted Auth and PostgREST integration still require Supabase.

SQL files in `supabase/tests` can also run against the configured hosted project;
all their fixtures roll back. Never commit test fixtures into the real catalogue.

## iOS

On macOS with the configured simulator:

```sh
xcodebuild test -project CurtainCall.xcodeproj -scheme CurtainCall \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' \
  -only-testing:CurtainCallTests
```

Then verify signup/recovery links and the complete discovery → room creation →
room reopening → member management flow with two authenticated users. Linux
Swift parsing does not replace this verification.
