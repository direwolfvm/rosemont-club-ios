# The Rosemont Club for iOS

A native SwiftUI app (Xcode project in `Rosemont Club/`) for [rosemont.club](https://rosemont.club), the neighborhood homepage, directory, calendar, and resource finder for Rosemont, Alexandria. It talks to the same trusted API and Firebase sign-in that the website uses, so profiles, permissions, residency status, RSVPs, follows, and poll responses are shared between web and app.

## What the app does

- **Home**: welcome copy from the site's editable content, the map carousel (present-day and historic maps), quick links, the next upcoming gathering, featured groups, the resource finder, and community questions.
- **Groups, Events, Resources**: searchable directories. Resources use the same "Who are you? / What are you looking for?" tag filters as the site. Events show the next occurrence, computed with the same weekly, monthly, and nth-weekday recurrence rules in Eastern time.
- **Detail pages**: descriptions, host group, communication channels, when/where tiles, sponsor notes, related listings, "Help look after this listing", and share links back to the website.
- **Members**: follow or request to join groups, RSVP to a chosen occurrence, vote in quick polls and see aggregate results, send feedback to the volunteer team, and approve membership requests for groups you own.
- **Calendar**: native Add to Calendar via the system event editor, a Google Calendar link, and `.ics` downloads for one event or the whole neighborhood feed.
- **Profile**: edit display name and bio, verify Rosemont residency (address checked server-side and never stored), request volunteer review, see the groups and gatherings you follow and the listings you look after.
- **Audience rules** are enforced by the server. Records outside your audience appear locked, exactly as on the website.

## Sign-in, registration, and biometrics

- Email/password sign-in and registration go straight to the Firebase Identity Toolkit REST API for the shared Identity Platform tenant (`alex311-qfnem`), so no Firebase SDK is bundled. Public client identifiers are fetched from `/api/config` at launch with the same values as a fallback.
- Registration is a mobile-friendly form (display name, email keyboard, password with visibility toggle and an 8-character minimum). It sends the verification email, creates the Club profile through the API, and then offers Face ID / Touch ID and residency verification in a short welcome step.
- **Biometric verification**: when enabled, the Firebase refresh token is stored in the Keychain behind a `.biometryCurrentSet` access control. Reading it prompts for Face ID / Touch ID, and the item is invalidated if the enrolled biometrics change. The app shows a lock screen at launch and after two minutes in the background, with password sign-in and public browsing as fallbacks. Without biometrics enabled, the session is stored in the Keychain (this device only) and restored silently, like the website's persistent sign-in.
- Google sign-in remains a website feature: it needs an iOS OAuth client registered in the Firebase project. Neighbors who signed up with Google can set a password with "Forgot password?" and use it in the app.

## Building

Requires Xcode 16 or later and iOS 17 or later.

```sh
open "Rosemont Club/Rosemont Club.xcodeproj"
```

Select the Rosemont Club scheme and run on a simulator or device. For a device, choose your team under Signing & Capabilities. The project uses no third-party dependencies.

Command-line build for the simulator:

```sh
xcodebuild -project "Rosemont Club/Rosemont Club.xcodeproj" -scheme "Rosemont Club" -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

Keychain items with biometric access control require a signed build (the default "Sign to Run Locally" simulator signing is enough). Building with `CODE_SIGNING_ALLOWED=NO` makes those Keychain calls fail with `errSecMissingEntitlement`.

## Project layout

| Path | Responsibility |
|---|---|
| `Rosemont Club/Rosemont Club/App/AppModel.swift` | Directory state, session, token refresh, biometric lock, notices |
| `Rosemont Club/Rosemont Club/App/Theme.swift` | Website palette with dark-mode counterparts, button and card styles |
| `Rosemont Club/Rosemont Club/Models/Entity.swift` | Lenient decoding of `/api/entities` records and audience helpers |
| `Rosemont Club/Rosemont Club/Models/Occurrences.swift` | Port of `lib/events.ts` recurrence, display formatting, Google Calendar link |
| `Rosemont Club/Rosemont Club/Services/FirebaseAuth.swift` | Identity Toolkit REST client: sign in, sign up, verification, reset, refresh |
| `Rosemont Club/Rosemont Club/Services/Keychain.swift` | Keychain wrapper with biometric access control; biometry capability checks |
| `Rosemont Club/Rosemont Club/Services/APIClient.swift` | Bearer-token JSON client for `https://rosemont.club/api` |
| `Rosemont Club/Rosemont Club/Views/` | Home, directories, detail, profile, auth, lock, governance, about |
| `Rosemont Club/Rosemont Club/Resources/rosemont-boundary.json` | Community boundary outline drawn on the About page |

## Debug launch arguments

In Debug builds only, `-seedBiometricSession` stores a dummy biometric-protected session so the lock screen can be exercised on a simulator with Face ID enrolled, and `-clearSession` removes any saved session.

## Not in the app

Content creation and editing, the volunteer admin console (people, permissions, inbox, audit), and Google sign-in stay on the website. Owners and administrators see a link to the relevant website page from the app.
