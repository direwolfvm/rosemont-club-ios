# App Store submission kit

Everything needed to list The Rosemont Club on the App Store. Values below are ready to paste into App Store Connect; the checklist at the end records what has been done and what remains.

## Identity

| Field | Value |
|---|---|
| Name | Rosemont Club (as created in App Store Connect) |
| Subtitle | Neighbors, events & resources |
| Bundle ID | `com.rosemont.rosemontclub` |
| SKU | as created in App Store Connect |
| Primary language | English (U.S.) |
| Primary category | Social Networking |
| Secondary category | Lifestyle |
| Age rating | 4+ (no objectionable content; user-generated content is limited to poll responses and private feedback) |
| Price | Free |
| Availability | United States |
| Copyright | 2026 The Rosemont Club |
| Version | 1.0 (build 1) |

## URLs

| Field | Value |
|---|---|
| Support URL | https://rosemont.club/support |
| Privacy Policy URL | https://rosemont.club/privacy |
| Marketing URL | https://rosemont.club |

## Promotional text (170 characters max)

Live in Rosemont? You're already in the Club. Find neighbors, gatherings, and local resources for Rosemont, Alexandria.

## Description

Live in Rosemont? You're already in the Club.

The Rosemont Club is the neighborhood app for Rosemont in Alexandria, Virginia: a friendly place to meet neighbors, find something to do, and look up the local resources you need.

FIND YOUR PEOPLE
Browse neighborhood groups, from the neighborhood-wide Rosemont Neighbors group to the Friday Bike Bus. Follow the ones you care about and see how to join their conversations.

MAKE A LITTLE TIME
See what's coming up, including the monthly Rosemont Happy Hour. RSVP with one tap, add gatherings to your calendar, or subscribe to the neighborhood calendar feed.

FIND WHAT YOU NEED
A curated directory of city services, schools, parks, utilities, elected officials, and local news, filtered by who you are and what you're looking for.

LEND YOUR VOICE
Answer quick neighborhood polls, follow community consultations, and send ideas to the volunteer team.

NEIGHBORS, WITH PRIVACY
Verify that you live in Rosemont to unlock resident-only groups and details. Your address is checked against the neighborhood boundary and never stored. There is no public member directory. Sign in with Face ID or Touch ID after your first sign-in.

The app uses the same account as rosemont.club, so your profile, follows, and RSVPs stay in sync between the website and your phone.

## Keywords (100 characters max)

Rosemont,Alexandria,neighborhood,neighbors,community,events,civic,local,Virginia,groups

## What's new in this version

First release: groups, events with RSVP and calendar export, the resource finder, quick polls, residency verification, and Face ID sign-in.

## App Review information

**Sign-in required:** yes.

Demo account: `app-review@rosemont.club`. The password is in the private file created on September 18, 2026 (`~/Downloads/rosemont-app-review-account.txt`); paste it into App Store Connect by hand. The account is an ordinary member. An administrator can mark it as a verified resident in the website's admin People tab so reviewers can open resident-only content.

**Notes for the reviewer:**

> The Rosemont Club is a neighborhood community app for Rosemont, Alexandria, Virginia. It uses the same accounts as https://rosemont.club.
>
> Most content is public and can be browsed without signing in. Signing in enables following groups, RSVPs, polls, and feedback. Use the demo account above or create a new account with any email address.
>
> Residency verification ("You" tab) sends an Alexandria street address to the U.S. Census geocoder and compares the result to the neighborhood boundary. The address is never stored. Any address inside Rosemont works, for example "10 E Rosemont Ave, Alexandria, VA 22301". Content marked "Verified residents" is limited to neighbors who pass this check or are approved by a volunteer.
>
> Face ID / Touch ID is optional. It protects a saved sign-in in the device Keychain; no biometric data leaves the device.
>
> "Add to Calendar" uses the system event editor and does not require calendar permission.

Contact: the Club administrator's name, phone, and email (fill in).

## App Privacy (nutrition label answers)

The privacy manifest in the app (`PrivacyInfo.xcprivacy`) matches these answers.

- **Data collection:** yes.
- **Contact info: Email address.** Linked to the user, used for app functionality (account). Not used for tracking.
- **Contact info: Name.** Linked to the user, app functionality (display name). Not used for tracking.
- **Identifiers: User ID.** Linked to the user, app functionality (account). Not used for tracking.
- **User content: Other user content.** Linked to the user, app functionality (bio, poll responses, feedback messages). Not used for tracking.
- **Location:** not collected. The residency address is sent to a geocoder for a one-time check and is not stored; do not declare precise location.
- **Tracking:** no.
- **Third-party data:** none.

## Export compliance

`ITSAppUsesNonExemptEncryption` is set to `NO`: the app uses only HTTPS (exempt encryption), so no export documentation is needed and the question is answered automatically at upload.

## Screenshots

6.9-inch iPhone screenshots (1320 x 2868, captured on iPhone 17 Pro Max) are prepared for: Home, Events, an event page, Groups, Resources, and sign-in. The app is iPhone-only (`TARGETED_DEVICE_FAMILY = 1`), so iPad screenshots are not required.

## Checklist

Done in the project:

- [x] Bundle ID `com.rosemont.rosemontclub`, team `LAKT4757H4`, version 1.0 build 1.
- [x] App icon (1024 px), launch screen, Face ID and calendar usage strings.
- [x] Privacy manifest with collected data types and the UserDefaults API reason.
- [x] Export compliance key (`ITSAppUsesNonExemptEncryption = NO`).
- [x] iPhone-only device family (drop the iPad screenshot requirement; iPad runs it in compatibility mode).
- [x] Associated Domains entitlement; the site serves the association file.
- [x] Release archive builds with automatic signing.
- [x] Demo account created and its Club profile initialized.

Done in App Store Connect (requires the API key's Issuer ID):

- [x] App record created ("Rosemont Club", `com.rosemont.rosemontclub`).
- [ ] Version 1.0 metadata, URLs, categories, age rating.
- [ ] Screenshots uploaded.
- [ ] Build uploaded and attached to the version.
- [ ] App Review information (demo account name; the password must be pasted by a person).

Needs a person:

- [ ] Paste the demo password into App Review Information.
- [ ] Answer the App Privacy questionnaire (answers above; not available through the API).
- [ ] Accept the latest Paid Apps / developer agreements if App Store Connect prompts for them.
- [ ] Mark the demo account as a verified resident (optional but recommended).
- [ ] Submit for review.
