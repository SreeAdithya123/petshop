# Production checklist (owner actions)

Things the code cannot do for you. Work top to bottom before the first public
release; tick each box. See [`RELEASING.md`](RELEASING.md) for the build steps
and [`store-listing.md`](store-listing.md) for the store text and privacy
answers.

## 1. Store accounts

- [ ] **Apple Developer Program** membership (paid, annual). Register the App ID
      `com.petsta.pawsnearby`, create the app in App Store Connect.
- [ ] **Google Play Console** developer account (one-time fee). Create the app
      with package name `com.pawsnearby.pawsnearby` and enrol in Play App Signing.
      Personal accounts must finish identity verification and a closed test
      (currently 12 testers for 14 days) before production access.
- [ ] Both identifiers are permanent. Do not change them after the first upload.
- [ ] Back up `mobile/android/app/upload-keystore.jks` and
      `mobile/android/key.properties` (password manager plus an offline copy).
      They are git-ignored; losing them means an upload-key reset with Google.

## 2. Supabase (project `pytkeurgdbhekyppfblh`)

Authentication, URL configuration:

- [ ] **Site URL**: set it to a real public URL (the website, or a landing page
      that says "open the PETSTA app"). Do not leave `localhost`.
- [ ] **Redirect URLs allow-list**: add `io.supabase.petsta://reset-callback/`
      (and `io.supabase.petsta://login-callback/`). Without this, password-reset
      links fall back to the Site URL and never open the app. Both Android
      (`AndroidManifest.xml`) and iOS (`Info.plist`) already register the scheme.
- [ ] Test it on a real phone: Forgot password, tap the e-mail link, the app
      opens on the reset screen.

Authentication, security:

- [ ] Turn on **leaked password protection** (Authentication, Sign In / Providers,
      Password security) and set a sensible minimum length (8 or more).
- [ ] Confirm **e-mail confirmation** is on if you want verified addresses.
- [ ] Review rate limits on sign-in, sign-up and password reset.

E-mail delivery:

- [ ] Configure **custom SMTP** (Resend, Postmark, SES, Brevo, ...). The default
      Supabase mailer is heavily rate limited (a few messages per hour) and is for
      testing only, so sign-up confirmations and resets will stall under real use.
      Use a domain with SPF, DKIM and DMARC set up, and edit the e-mail templates
      to say PETSTA.

Plan, backups and cost:

- [ ] **Upgrade from the free tier.** Free projects pause after a week of
      inactivity and have no backups.
- [ ] Enable **daily backups** (Pro plan; consider Point-in-Time Recovery once
      there are real orders). Do a test restore once.
- [ ] Set a **spend cap** / budget alert, and watch database size, egress and
      monthly active users.
- [ ] **Rotate the anon key** if it was ever exposed in a place it should not be
      (the anon key is public by design and RLS-gated, but the `service_role` key
      must never be in the app, the repo or a screenshot). If you rotate, update
      `mobile/lib/config/env.dart` and the web app, then ship new builds.

Database (deploy before shipping the app that calls them; the app shows
"This action isn't available yet" if they are missing):

- [ ] `seller_update_order_status(p_order_id uuid, p_status text)`
- [ ] `cancel_my_order(p_order_id uuid)`
- [ ] `delete_my_account()`
- [ ] Row-level security reviewed table by table with a non-admin test account
      for each role (customer, shop owner, admin). Confirm customers cannot read
      `shops.address`, `shops.phone`, `pets.cost_price` or `products.cost_price`.
      Today this is enforced by the app's column lists only; moving private shop
      columns to a separate table or column-level privileges closes it for good.
- [ ] Storage, if you add uploads later: private buckets and per-user policies.

## 3. Legal and policy

- [ ] **Privacy policy and Terms** shown in the app (Account, About and legal)
      have been reviewed by a lawyer for the countries you launch in, and match
      what the app actually collects (see the data tables in `store-listing.md`).
      Publish the same text at a **public URL**: both stores require one.
- [ ] **Account deletion**: Apple requires in-app account deletion and Google
      requires an in-app path plus a public web URL. Deploy `delete_my_account`,
      decide the process for shop owners (the app tells them to contact support
      first) and write it up at the deletion URL.
- [ ] **Live-animal and pet-medicine rules**: shops must hold the licences their
      jurisdiction requires (for example pet-shop registration under local animal
      welfare law) and prescription-only medicines must be handled as the law
      requires. Have counsel confirm the marketplace role, listing rules and
      liability wording.
- [ ] **Shop owners' contract**: the in-app seller contract text (Seller, Contract)
      has been reviewed, covers listing accuracy, licences, refunds and pickup
      rules, commission or fees, termination and data protection, and is
      accepted by each shop before it can list.
- [ ] **User-generated content** (shop reviews, support messages): define a
      moderation process (who removes content, within what time), and make sure
      users can report a problem. Apple Guideline 1.2 and Play's UGC policy
      expect it.
- [ ] Consumer-law basics: refund and cancellation policy shown before
      reserving, prices shown with tax rules for your country, a grievance /
      contact officer if your law requires one.
- [ ] Content rating questionnaires and the Play **Data safety** and Apple
      **App Privacy** forms completed from `store-listing.md`. Re-do them if
      you add analytics, crash reporting, ads or new data fields.

## 4. Operations and monitoring

- [ ] **Crash reporting provider**: the app currently keeps errors on the device
      only (`lib/core/crash_reporter.dart`). Pick Sentry or Firebase Crashlytics,
      implement `CrashReporter`, install it before `runApp`, upload the
      `build/symbols` of each release, never attach e-mail, phone or address, and
      update the Data safety / privacy labels (crash logs, diagnostics).
- [ ] A **support inbox** monitored daily: the in-app tickets are answered from
      the admin Support screen, and the public support e-mail in the store
      listing needs an owner.
- [ ] An **admin** account exists and the process for approving shops and
      services is staffed.
- [ ] Uptime: know how to tell if Supabase is down (status page subscription)
      and what the app shows ("Can't reach PETSTA, try again").

## 5. Testing before launch

- [ ] **Real devices**, not only emulators: at least one low-end Android phone
      (2 to 3 GB RAM), one recent Pixel or Samsung, one older iPhone and one
      current iPhone, plus an iPad if the iPad build is listed.
- [ ] Release builds (`flutter run --release` or the Play internal track and
      TestFlight), signed with the real keys.
- [ ] Walk through every role: customer (browse, wishlist, reserve, gift, cart,
      checkout, cancel, refund, service booking, vet consult, support ticket,
      delete account), shop owner (apply, get approved, add pets, products,
      services, handle orders, demos and refunds), admin (approve, support).
- [ ] Edge cases: airplane mode and weak network, app killed mid-checkout,
      expired session, two phones signed in to one account, text size 130 percent
      and 200 percent, small screens (320 dp wide), dark mode, rotation.
- [ ] Deep links: password reset on Android and iOS, from a cold start and from
      a running app.
- [ ] Seed the live database with real shops and pets (no "test" listings), and
      create the demo accounts for store reviewers (`store-listing.md`, section 7).
- [ ] Final `flutter analyze` and `flutter test` green on the release commit.

## 6. Launch day

- [ ] Staged rollout on Play (start at 10 percent), phased release on iOS.
- [ ] Watch Supabase logs, auth errors and the crash dashboard for the first
      48 hours; keep the previous build ready to re-promote.
- [ ] Tag the commit (`git tag v1.0.0+1`) and keep the `build/symbols` zip with it.
