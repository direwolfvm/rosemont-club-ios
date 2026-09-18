# Handoff: enabling the iOS client on rosemont.club

**For:** the agent working in `direwolfvm/rosemont-club` (the Next.js site, local checkout `/Users/jke/Github-local/rosemont-club`).
**From:** the iOS app session, repo `rosemont-club-ios`, branch `claude/ios-app-biometric-auth-f51aca`.
**Date:** September 18, 2026.

## 1. What the iOS client is

A native SwiftUI app (bundle ID `club.rosemont.ios`, iOS 17+) that uses the website's existing backend unchanged:

- Reads and writes through `https://rosemont.club/api/*` with `Authorization: Bearer <Firebase ID token>`, exactly like the browser client in `components/client.tsx`.
- Signs in with the Firebase Identity Toolkit REST API directly (no Firebase SDK), scoped to the shared tenant `alex311-qfnem`. It reads the public client config from `GET /api/config` at launch and falls back to the same values from `deploy-env.yaml`.
- Stores the Firebase refresh token in the iOS Keychain, optionally behind Face ID / Touch ID. It refreshes ID tokens through `securetoken.googleapis.com`.
- Never bypasses server authorization: audience rules, ownership, rate limits and residency all stay server-side.

## 2. What already works with no web changes (verified today)

- Public browsing of `GET /api/entities` and `GET /api/entities/{id}` (including `upcoming`).
- Firebase password sign-in against the tenant from a non-browser client: a bad-credential attempt returned `INVALID_LOGIN_CREDENTIALS`, not an API-key restriction error, so the web API key is not referrer-restricted.
- Mutations from the app pass the origin check because `lib/origin.ts#allowedOrigin` returns `true` when no `Origin` header is present, and URLSession sends none.

Everything below is either hardening of those implicit dependencies or enabling features the app cannot provide on its own.

## 3. Requested changes, in priority order

### P0. Before neighbors install the app

1. **Lock in the null-origin behavior.** The app depends on `allowedOrigin(null, …) === true`. Add a regression test in `tests/origin.test.ts` asserting that a missing `Origin` header is allowed, and a comment in `lib/origin.ts` noting the native iOS client relies on it. Do not switch to "reject when Origin is missing" without coordinating a client header scheme first. If you want an explicit signal, the app can add `X-Rosemont-Client: ios/<version>`; say so and the iOS side will ship it.

2. **Keep the Firebase web API key usable from native clients.** Do not add HTTP-referrer restrictions to `FIREBASE_API_KEY` in Google Cloud without also creating an iOS-restricted key. Preferred: register an iOS app (bundle `club.rosemont.ios`) in the Firebase project `permitting-ai-helper`, then either
   - return its `apiKey`/`appId` from `GET /api/config` when the request carries `X-Rosemont-Client: ios/*` (or a `?platform=ios` query), or
   - hand the values to the iOS side to bake into `AppConfig.fallback`.
   Either way, keep the existing `/api/config` response shape (`apiKey`, `authDomain`, `projectId`, `appId`, `tenantId`) backward compatible.

3. **Auth email action links.** Registration in the app sends Firebase's verification email; "Forgot password?" sends the reset email. Confirm in the Firebase console (Authentication → Templates, for tenant `alex311-qfnem`) that the action URL / continue URL points at `https://rosemont.club` so neighbors land on the site after verifying or resetting. Confirm the tenant's password policy: the app enforces a minimum of 8 characters and should match whatever the tenant enforces.

4. **Pages the App Store submission needs.** Host a privacy policy at `https://rosemont.club/privacy` (or a stable equivalent) and a support/contact page. The privacy text can reuse `docs/BOUNDARY.md` and the README's "Authentication, authorization, and privacy" section: addresses go to the U.S. Census geocoder and are never stored, no public member directory, email through Mailgun with tracking disabled. The app's Face ID data never leaves the device (it is iOS Keychain access control, not a stored biometric). Send the final URLs back so the iOS side can put them in App Store Connect.

### P1. Makes web and app work as one

5. **Universal links and password autofill.** Serve `https://rosemont.club/.well-known/apple-app-site-association` with `Content-Type: application/json`, no redirect, no extension. In Next.js: put the file in `public/.well-known/` and add a `headers()` rule in `next.config.mjs` for that path. Contents:

   ```json
   {
     "applinks": {
       "apps": [],
       "details": [
         { "appIDs": ["TEAMID.club.rosemont.ios"], "components": [
           { "/": "/groups/*" }, { "/": "/events/*" }, { "/": "/resources/*" },
           { "/": "/polls/*" }, { "/": "/consultations/*" },
           { "/": "/profile" }, { "/": "/about" }, { "/": "/governance" }
         ] }
       ]
     },
     "webcredentials": { "apps": ["TEAMID.club.rosemont.ios"] }
   }
   ```

   `TEAMID` is the Apple Developer Team ID; get it from Jordan or the iOS side. `webcredentials` lets iOS Password AutoFill offer a neighbor's saved rosemont.club password inside the app, which is the practical "one account" experience. The iOS side will add the matching Associated Domains entitlement and route handling once the file is live.

6. **API contract stability.** The app decodes leniently (unknown fields ignored, missing fields defaulted), so additive changes are safe. The live API already returns fields the local `lib/schema.ts` does not (`calendarUrl`, `contactRelay`, `eligibility`); that is fine. Please avoid, without a heads-up:
   - renaming or removing the fields listed in section 4,
   - changing the `{ "error": "message" }` error body or the 401/403/409/429 semantics,
   - changing occurrence strings from `yyyy-MM-ddTHH:mm` Eastern wall-clock time (the RSVP API and the client's recurrence port both depend on it),
   - changing `entities/{id}/results` to return per-user data (the app shows aggregates only).

7. **Smart App Banner.** Once the app has an App Store ID, add `<meta name="apple-itunes-app" content="app-id=APPSTOREID">` in `app/layout.tsx` so mobile Safari offers the app on rosemont.club.

### P2. Optional

8. **Google sign-in in the app.** Not implemented on iOS because it needs an iOS OAuth client. If wanted: create an iOS OAuth client ID for bundle `club.rosemont.ios` in the `permitting-ai-helper` Google Cloud project (Firebase console does this when the iOS app is registered), confirm the Google provider is enabled on the tenant, and send the client ID and reversed client ID. The app would then use Google Sign-In plus `accounts:signInWithIdp`. Until then, the app tells Google users to set a password with "Forgot password?".

9. **Client version gate.** Consider adding `iosMinimumVersion` to `/api/config` so a breaking API change can prompt an app update instead of failing silently. The app will read it if present.

10. **Rate limits.** `publicReadLimit` keys on the last proxy hop of `x-forwarded-for` at 180 reads per minute per instance. The app makes one `entities` read per refresh plus a few per detail page, so this is fine, but carrier-grade NAT means many neighbors can share an IP. Watch for 429s in logs after launch.

11. **Copy.** `home-intro` currently says "Use this site to…". The app shows that text on its home screen. "Use the Club to…" reads correctly in both places if Jordan wants to change it in the content editor.

## 4. API surface the app depends on

| Method and path | Used for | Notes |
|---|---|---|
| `GET /api/config` | Firebase client config | Shape must stay backward compatible |
| `GET /api/entities` | Full directory in one call | Relies on locked projection (`id`, `name`, `slug`, `kind`, `visibility`, `locked`) |
| `GET /api/entities/{id}` | Detail refresh, `upcoming` | |
| `GET /api/me`, `PATCH /api/me` | Profile; first call creates the Club user | Body `{displayName, bio}` |
| `GET /api/activity` | Follows and RSVPs on the profile | |
| `POST /api/residency`, `POST /api/residency/review` | Residency check, volunteer review | |
| `POST /api/feedback` | Feedback and ownership requests | `type` is `feedback` or `ownership` |
| `GET/POST /api/entities/{id}/join` | Follow or request a group | |
| `GET/POST /api/entities/{id}/rsvp?date=` | RSVP per occurrence | |
| `POST /api/entities/{id}/vote`, `GET …/results` | Polls | |
| `GET/POST /api/entities/{id}/members` | Owner approval of requests | |
| `GET /api/calendar`, `GET /api/calendar/{id}` | `.ics` export | Bearer token sent when signed in |

Entity fields read by the app: `id, name, slug, kind, visibility, locked, summary, description, status, ownerIds, featured, audienceTags, topicTags, website, contactEmail, image, imageAlt, membership, scope, joinInstructions, channels[], groupId, relatedGroups, relatedEvents, relatedResources, start, end, timezone, location, streetAddress, mapUrl, sponsor, notes, capacity, rsvp, recurrence{}, overrides[], options, opens, closes, resultsVisibility, createdAt, updatedAt, upcoming`. Member fields: `id, email, displayName, bio, admin, disabled, verifiedResident, verificationDate, reviewRequested`.

Firebase endpoints used: `accounts:signInWithPassword`, `accounts:signUp`, `accounts:update` (display name), `accounts:sendOobCode` (`VERIFY_EMAIL`, `PASSWORD_RESET`), and `securetoken.googleapis.com/v1/token`, all with `tenantId: alex311-qfnem` where the API accepts it.

## 5. Verification checklist for the web side

```sh
# Native-style sign-in must reach the tenant (expect HTTP 400 INVALID_LOGIN_CREDENTIALS, not 403 about referrers)
curl -s "https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=$(curl -s https://rosemont.club/api/config | python3 -c 'import json,sys;print(json.load(sys.stdin)["apiKey"])')" \
  -H 'Content-Type: application/json' \
  -d '{"email":"nobody@example.com","password":"wrong","returnSecureToken":true,"tenantId":"alex311-qfnem"}'
```

```sh
# A mutation with no Origin header must not be rejected for origin (expect 401 "Please sign in", not 403 "origin")
curl -s -X POST https://rosemont.club/api/feedback -H 'Content-Type: application/json' -d '{"message":"origin check"}'
```

```sh
# After P1.5: AASA must be JSON with no redirect
curl -sI https://rosemont.club/.well-known/apple-app-site-association | grep -i -E "^(HTTP|content-type)"
```

Also run `npm test` after adding the origin regression test, and use the existing `scripts/smoke.ts` pattern if you want to exercise sign-up and cleanup with a temporary `rosemont-test-*` identity rather than leaving a real account behind.

## 6. What the iOS side needs back

- Apple Team ID confirmation and go-ahead once the AASA file is live (iOS then adds the Associated Domains entitlement).
- Final privacy policy and support URLs.
- iOS Firebase app values (`apiKey`, `appId`) if you register one, and the decision on whether `/api/config` will serve them.
- Whether you want a client header (`X-Rosemont-Client`) and, if so, the exact name.
- Google OAuth iOS client ID, only if P2.8 is pursued.

## 7. Non-goals

The app deliberately does not include content creation and editing, the admin console, or Google sign-in. Owners and admins are linked to the website pages for those. No web changes are needed for that split.
