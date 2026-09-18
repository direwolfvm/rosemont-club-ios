#!/usr/bin/env node
// App Store Connect helper for The Rosemont Club. Node 22+, no dependencies.
//
//   ASC_KEY_ID=… ASC_ISSUER_ID=… ASC_KEY_PATH=~/Downloads/AuthKey_XXXX.p8 node scripts/asc.mjs <command>
//
// Commands:
//   status                 Show the app, versions, builds, and screenshot sets.
//   metadata               Create version 1.0 if needed and write name, subtitle, categories,
//                          description, keywords, URLs, promotional text, and what's new (from docs/APP-STORE.md values).
//   screenshots <dir>      Upload PNGs from <dir> as the 6.9-inch iPhone set, replacing existing ones.
//   review                 Set App Review contact/notes and the demo account NAME. The demo password is
//                          never sent by this script; paste it in App Store Connect by hand.
//   attach-build [build]   Attach the newest processed build (or CFBundleVersion <build>) to version 1.0.
//
// Upload the IPA separately:
//   xcrun altool --upload-app -f "Rosemont Club.ipa" -t ios --apiKey $ASC_KEY_ID --apiIssuer $ASC_ISSUER_ID
// (altool looks for the key at ~/.appstoreconnect/private_keys/AuthKey_$ASC_KEY_ID.p8)

import { createHash, createSign } from "node:crypto";
import { readFileSync, readdirSync, statSync } from "node:fs";
import { join } from "node:path";

const BUNDLE_ID = "com.rosemont.rosemontclub";
const VERSION = "1.0";
const API = "https://api.appstoreconnect.apple.com/v1";

const META = {
  name: "Rosemont Club",
  subtitle: "Neighbors, events & resources",
  privacyPolicyUrl: "https://rosemont.club/privacy",
  primaryCategory: "SOCIAL_NETWORKING",
  secondaryCategory: "LIFESTYLE",
  supportUrl: "https://rosemont.club/support",
  marketingUrl: "https://rosemont.club",
  promotionalText:
    "Live in Rosemont? You're already in the Club. Find neighbors, gatherings, and local resources for Rosemont, Alexandria.",
  keywords: "Rosemont,Alexandria,neighborhood,neighbors,community,events,civic,local,Virginia,groups",
  whatsNew:
    "First release: groups, events with RSVP and calendar export, the resource finder, quick polls, residency verification, and Face ID sign-in.",
  description: `Live in Rosemont? You're already in the Club.

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

The app uses the same account as rosemont.club, so your profile, follows, and RSVPs stay in sync between the website and your phone.`,
  review: {
    demoAccountName: "app-review@rosemont.club",
    demoAccountRequired: true,
    contactFirstName: process.env.ASC_CONTACT_FIRST || "Jordan",
    contactLastName: process.env.ASC_CONTACT_LAST || "Eccles",
    contactEmail: process.env.ASC_CONTACT_EMAIL || "",
    contactPhone: process.env.ASC_CONTACT_PHONE || "",
    notes: `The Rosemont Club is a neighborhood community app for Rosemont, Alexandria, Virginia. It uses the same accounts as https://rosemont.club.

Most content is public and can be browsed without signing in. Signing in enables following groups, RSVPs, polls, and feedback. Use the demo account or create a new account with any email address.

Residency verification ("You" tab) sends an Alexandria street address to the U.S. Census geocoder and compares the result to the neighborhood boundary. The address is never stored. Any address inside Rosemont works, for example "10 E Rosemont Ave, Alexandria, VA 22301". Content marked "Verified residents" is limited to neighbors who pass this check or are approved by a volunteer.

Face ID / Touch ID is optional. It protects a saved sign-in in the device Keychain; no biometric data leaves the device.

"Add to Calendar" uses the system event editor and does not require calendar permission.`,
  },
};

// ---------- auth ----------
const keyId = need("ASC_KEY_ID"), issuer = need("ASC_ISSUER_ID");
const keyPath = need("ASC_KEY_PATH").replace(/^~/, process.env.HOME);
const privateKey = readFileSync(keyPath, "utf8");
function need(name) { const v = process.env[name]; if (!v) { console.error(`Set ${name}`); process.exit(2); } return v; }
function b64url(buf) { return Buffer.from(buf).toString("base64").replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, ""); }
function token() {
  const now = Math.floor(Date.now() / 1000);
  const header = b64url(JSON.stringify({ alg: "ES256", kid: keyId, typ: "JWT" }));
  const payload = b64url(JSON.stringify({ iss: issuer, iat: now, exp: now + 15 * 60, aud: "appstoreconnect-v1" }));
  const sig = createSign("SHA256").update(`${header}.${payload}`).sign({ key: privateKey, dsaEncoding: "ieee-p1363" });
  return `${header}.${payload}.${b64url(sig)}`;
}
async function api(method, path, body) {
  const res = await fetch(path.startsWith("http") ? path : API + path, {
    method,
    headers: { Authorization: `Bearer ${token()}`, "Content-Type": "application/json" },
    body: body ? JSON.stringify(body) : undefined,
  });
  const text = await res.text();
  const data = text ? JSON.parse(text) : {};
  if (!res.ok) throw new Error(`${method} ${path} -> ${res.status}: ${JSON.stringify(data.errors || data).slice(0, 800)}`);
  return data;
}
const get = (p) => api("GET", p), post = (p, b) => api("POST", p, b), patch = (p, b) => api("PATCH", p, b), del = (p) => api("DELETE", p);

// ---------- lookups ----------
async function app() {
  const { data } = await get(`/apps?filter[bundleId]=${BUNDLE_ID}`);
  if (!data.length) throw new Error(`No App Store Connect app has bundle ID ${BUNDLE_ID}. Create it in App Store Connect (My Apps > + > New App) with name "${META.name}", bundle ID ${BUNDLE_ID}, the SKU you chose, primary language English (U.S.).`);
  return data[0];
}
async function version(appId, create = false) {
  const { data } = await get(`/apps/${appId}/appStoreVersions?filter[platform]=IOS&limit=5`);
  let v = data.find((x) => x.attributes.versionString === VERSION) || data.find((x) => /PREPARE|DEVELOPER_REJECTED|REJECTED|WAITING/.test(x.attributes.appStoreState || x.attributes.appVersionState || ""));
  if (!v && create) {
    ({ data: v } = await post("/appStoreVersions", { data: { type: "appStoreVersions", attributes: { platform: "IOS", versionString: VERSION }, relationships: { app: { data: { type: "apps", id: appId } } } } }));
    console.log(`Created version ${VERSION}`);
  }
  if (!v) throw new Error("No editable version found");
  return v;
}
async function versionLocalization(versionId) {
  const { data } = await get(`/appStoreVersions/${versionId}/appStoreVersionLocalizations`);
  let l = data.find((x) => x.attributes.locale === "en-US") || data[0];
  if (!l) ({ data: l } = await post("/appStoreVersionLocalizations", { data: { type: "appStoreVersionLocalizations", attributes: { locale: "en-US" }, relationships: { appStoreVersion: { data: { type: "appStoreVersions", id: versionId } } } } }));
  return l;
}

// ---------- commands ----------
const commands = {
  async status() {
    const a = await app();
    console.log(`App: ${a.attributes.name} (${a.id}) sku=${a.attributes.sku}`);
    const { data: versions } = await get(`/apps/${a.id}/appStoreVersions?filter[platform]=IOS&limit=5`);
    for (const v of versions) console.log(`  version ${v.attributes.versionString}: ${v.attributes.appVersionState || v.attributes.appStoreState}`);
    const { data: builds } = await get(`/builds?filter[app]=${a.id}&sort=-uploadedDate&limit=5`);
    for (const b of builds) console.log(`  build ${b.attributes.version}: ${b.attributes.processingState} (${b.attributes.uploadedDate})`);
    try {
      const v = await version(a.id); const l = await versionLocalization(v.id);
      const { data: sets } = await get(`/appStoreVersionLocalizations/${l.id}/appScreenshotSets`);
      for (const s of sets) console.log(`  screenshots ${s.attributes.screenshotDisplayType}`);
    } catch (e) { console.log("  " + e.message); }
  },

  async metadata() {
    const a = await app();
    const { data: infos } = await get(`/apps/${a.id}/appInfos`);
    const info = infos.find((i) => /PREPARE|DEVELOPER_REJECTED|REJECTED|WAITING/.test(i.attributes.state || i.attributes.appStoreState || "")) || infos[0];
    await patch(`/appInfos/${info.id}`, { data: { type: "appInfos", id: info.id, relationships: {
      primaryCategory: { data: { type: "appCategories", id: META.primaryCategory } },
      secondaryCategory: { data: { type: "appCategories", id: META.secondaryCategory } } } } });
    const { data: infoLocs } = await get(`/appInfos/${info.id}/appInfoLocalizations`);
    let il = infoLocs.find((x) => x.attributes.locale === "en-US") || infoLocs[0];
    const infoAttrs = { name: META.name, subtitle: META.subtitle, privacyPolicyUrl: META.privacyPolicyUrl };
    if (il) await patch(`/appInfoLocalizations/${il.id}`, { data: { type: "appInfoLocalizations", id: il.id, attributes: infoAttrs } });
    else await post("/appInfoLocalizations", { data: { type: "appInfoLocalizations", attributes: { locale: "en-US", ...infoAttrs }, relationships: { appInfo: { data: { type: "appInfos", id: info.id } } } } });
    const v = await version(a.id, true);
    await patch(`/appStoreVersions/${v.id}`, { data: { type: "appStoreVersions", id: v.id, attributes: { copyright: "2026 The Rosemont Club", releaseType: "AFTER_APPROVAL" } } });
    const l = await versionLocalization(v.id);
    await patch(`/appStoreVersionLocalizations/${l.id}`, { data: { type: "appStoreVersionLocalizations", id: l.id, attributes: {
      description: META.description, keywords: META.keywords, supportUrl: META.supportUrl, marketingUrl: META.marketingUrl,
      promotionalText: META.promotionalText, ...(VERSION === "1.0" ? {} : { whatsNew: META.whatsNew }) } } });
    // App Store Connect rejects whatsNew on an app's first version.
    try {
      // The declaration lives on the app info. Booleans and content descriptors are named
      // explicitly because the API rejects unknown or mistyped attributes.
      const { data: decl } = await get(`/appInfos/${info.id}/ageRatingDeclaration`);
      const attrs = { ageRatingOverride: "NONE" };
      for (const k of ["advertising", "gambling", "healthOrWellnessTopics", "lootBox", "messagingAndChat", "parentalControls", "ageAssurance", "socialMedia", "socialMediaAgeRestricted", "unrestrictedWebAccess", "userGeneratedContent"]) attrs[k] = false;
      for (const k of ["alcoholTobaccoOrDrugUseOrReferences", "contests", "gamblingSimulated", "gunsOrOtherWeapons", "medicalOrTreatmentInformation", "profanityOrCrudeHumor", "sexualContentGraphicAndNudity", "sexualContentOrNudity", "horrorOrFearThemes", "matureOrSuggestiveThemes", "violenceCartoonOrFantasy", "violenceRealistic", "violenceRealisticProlongedGraphicOrSadistic"]) attrs[k] = "NONE";
      await patch(`/ageRatingDeclarations/${decl.id}`, { data: { type: "ageRatingDeclarations", id: decl.id, attributes: attrs } });
      console.log("Age rating: no descriptors (4+)");
    } catch (e) { console.log("Age rating not set automatically (" + e.message.slice(0, 300) + "); answer it in App Store Connect."); }
    console.log("Metadata written for version " + VERSION);
  },

  async screenshots(dir) {
    if (!dir) throw new Error("screenshots <dir>");
    const a = await app(); const v = await version(a.id, true); const l = await versionLocalization(v.id);
    const { data: sets } = await get(`/appStoreVersionLocalizations/${l.id}/appScreenshotSets`);
    let set = sets.find((s) => s.attributes.screenshotDisplayType === "APP_IPHONE_67");
    if (set) {
      const { data: old } = await get(`/appScreenshotSets/${set.id}/appScreenshots`);
      for (const s of old) await del(`/appScreenshots/${s.id}`);
    } else {
      ({ data: set } = await post("/appScreenshotSets", { data: { type: "appScreenshotSets", attributes: { screenshotDisplayType: "APP_IPHONE_67" }, relationships: { appStoreVersionLocalization: { data: { type: "appStoreVersionLocalizations", id: l.id } } } } }));
    }
    const files = readdirSync(dir).filter((f) => /^\d+.*\.png$/i.test(f)).sort();
    for (const f of files) {
      const buf = readFileSync(join(dir, f));
      const { data: shot } = await post("/appScreenshots", { data: { type: "appScreenshots", attributes: { fileName: f, fileSize: buf.length }, relationships: { appScreenshotSet: { data: { type: "appScreenshotSets", id: set.id } } } } });
      for (const op of shot.attributes.uploadOperations) {
        const headers = Object.fromEntries(op.requestHeaders.map((h) => [h.name, h.value]));
        const res = await fetch(op.url, { method: op.method, headers, body: buf.subarray(op.offset, op.offset + op.length) });
        if (!res.ok) throw new Error(`upload chunk failed ${res.status}`);
      }
      await patch(`/appScreenshots/${shot.id}`, { data: { type: "appScreenshots", id: shot.id, attributes: { uploaded: true, sourceFileChecksum: createHash("md5").update(buf).digest("hex") } } });
      console.log("uploaded " + f);
    }
  },

  async review() {
    const a = await app(); const v = await version(a.id, true);
    const attrs = { ...META.review };
    let existing = null;
    try { ({ data: existing } = await get(`/appStoreVersions/${v.id}/appStoreReviewDetail`)); } catch {}
    if (existing) await patch(`/appStoreReviewDetails/${existing.id}`, { data: { type: "appStoreReviewDetails", id: existing.id, attributes: attrs } });
    else await post("/appStoreReviewDetails", { data: { type: "appStoreReviewDetails", attributes: attrs, relationships: { appStoreVersion: { data: { type: "appStoreVersions", id: v.id } } } } });
    console.log("Review details set. Paste the demo account password in App Store Connect > App Review Information.");
  },

  async "attach-build"(buildNumber) {
    const a = await app(); const v = await version(a.id, true);
    const { data: builds } = await get(`/builds?filter[app]=${a.id}&filter[processingState]=VALID&sort=-uploadedDate&limit=10`);
    const b = buildNumber ? builds.find((x) => x.attributes.version === buildNumber) : builds[0];
    if (!b) throw new Error("No processed build found yet; wait for App Store Connect to finish processing.");
    await patch(`/appStoreVersions/${v.id}/relationships/build`, { data: { type: "builds", id: b.id } });
    console.log(`Attached build ${b.attributes.version} to version ${VERSION}`);
  },
};

const [cmd, ...args] = process.argv.slice(2);
if (!commands[cmd]) { console.error("Commands: " + Object.keys(commands).join(", ")); process.exit(2); }
commands[cmd](...args).catch((e) => { console.error(e.message); process.exit(1); });
