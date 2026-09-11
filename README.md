# CurtainCall iOS

SwiftUI iOS app with Supabase. Email signup, login, confirmation email resend, Apple/Google OAuth launch, session observation, and local logout are implemented. Chat is not implemented.

## Supabase

- Client: `CurtainCall/Supabase.swift`
- Swift package: `supabase-swift`, pinned to `2.55.2`
- The configured publishable key is public client configuration, not an administrator credential. Never replace it with a secret or service-role key.
- Database tables and access policies have not been created by this setup. Enable RLS and define appropriate policies before exposing application data.
- Xcode resolves the package automatically when opening `CurtainCall.xcodeproj`. Keep `Package.resolved` in version control.

## Build

Open `CurtainCall.xcodeproj`, select the CurtainCall scheme and an iOS simulator, then build with Command-B.

The app uses Supabase rather than the sibling Spring/MySQL backend. The shared documents in `../docs` still describe that earlier backend design and require revision before implementing application features.

## Authentication setup and verification

In Supabase Authentication → URL Configuration, add `curtaincall://auth/callback` to Redirect URLs. Keep email confirmation enabled. The app registers this scheme and handles the callback with the SDK. If email is opened on another device, confirm there and then log in manually in the app.

For OAuth, enable Apple and/or Google under Authentication → Sign In / Providers and enter each provider's credentials in Supabase. The app starts the PKCE flow and uses the same callback URL; provider credentials must never be placed in the iOS project. OAuth buttons can be displayed before provider setup, but the provider must be enabled for a real sign-in to succeed.

Signup stores the nickname in user metadata for display only; it must never be used for authorization. The SDK manages persisted sessions and refresh tokens. Passwords are not stored by application code and are cleared on authentication transitions.

The 60-second resend cooldown is a UI convenience; Supabase enforces the actual server limits. Signup deliberately uses a neutral confirmation message because Supabase may obscure existing accounts.

Current limitations:
- Terms and privacy documents are unavailable per the user; consent/version recording is a release prerequisite, not implemented with invented text.
- The previous requirements mention verification codes. This implementation uses the default Supabase confirmation link. Code-based verification remains a product decision.
- OAuth provider sign-in remains pending provider credentials and a real Apple/Google account.
- Password reset, profile editing, and account deletion are outside this signup/login change.

Tests: `xcodebuild -project CurtainCall.xcodeproj -scheme CurtainCall -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' test -only-testing:CurtainCallTests -only-testing:CurtainCallUITests/CurtainCallUITests`

### Verification on 2026-09-11

- Simulator build-for-testing succeeded.
- Swift Testing: 3 tests passed (7 validation assertions).
- iOS 26.5 / iPhone 17 Pro: signup/login UI test passed; covers empty login, switching modes, signup fields, and short-password rejection.
- Screen inspected in the simulator (dark appearance).
- Actual project password login endpoint rejected a synthetic invalid account with HTTP 400 / `invalid_credentials`; no account or email was created by that check.
- Test signup for `2501ksh@gmail.com` returned HTTP 200 and sent a confirmation email. After the user confirmed the link, password login returned HTTP 200 with a confirmed user and access/refresh tokens. This verifies the remote signup, confirmation, and login path. The iOS persisted-session restoration and in-app logout still need device-level verification.
