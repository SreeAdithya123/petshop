# Store listing: PETSTA

Copy-paste material for Google Play Console and App Store Connect. Everything
here describes what the app does today; if a feature changes, change the
answers too (a wrong privacy answer is a policy violation on both stores).

Character limits are the stores' current limits. Counts below were checked.

## 1. Identity

| | Google Play | App Store |
|---|---|---|
| App name | `PETSTA: Pets, Supplies & Vets` (29 of 30) | `PETSTA` |
| Subtitle | n/a (use the short description) | `Pets, supplies & vet care` (25 of 30) |
| Package / bundle ID | `com.pawsnearby.pawsnearby` | `com.petsta.pawsnearby` |
| Primary category | Lifestyle (Shopping is also valid) | Lifestyle |
| Secondary category | n/a | Shopping |
| Price | Free | Free |
| In-app purchases | None | None |
| Ads | No ads | n/a |
| Contact email | `<support email>` (owner to fill in) | same |
| Privacy policy URL | `<public URL of the privacy policy>` | same |
| Support URL | `<public support page URL>` | same |
| Account deletion URL | `<public page explaining how to delete an account>` | n/a (in-app) |

Brand colour `#4F46E5` (indigo), gradient indigo to violet to pink, white paw
mark. Generated artwork is in `mobile/assets/` (re-run
`python mobile/assets/generate_brand_assets.py` to rebuild):

| Use | File |
|---|---|
| Play hi-res icon (512 x 512) | `mobile/assets/store/play_icon_512.png` |
| Play feature graphic (1024 x 500) | `mobile/assets/store/feature_graphic_1024x500.png` |
| App Store icon (1024 x 1024, no alpha) | `mobile/assets/icon/icon.png` (already inside the iOS asset catalog) |

## 2. Text

### Short description (Play, max 80)

```
Reserve pets, shop supplies, book services and vet video calls near you.
```
(72 characters)

### Promotional text (App Store, max 170, can be edited without a new build)

```
Find a pet from a licensed local shop, reserve it in minutes and pay at pickup. Shop supplies, book grooming and talk to a vet by video.
```
(136 characters)

### Keywords (App Store, max 100, comma separated, no spaces after commas)

```
pet,pets,puppy,dog,cat,kitten,pet shop,pet store,vet,grooming,pet supplies,pet food,aquarium,bird
```
(97 characters)

### Full description (Play max 4000, App Store max 4000)

```
PETSTA brings your local pet shops into one app. Browse pets from licensed shops near you, reserve the one you love and pay in person when you pick it up. Nothing is shipped, so you always meet your pet before you pay.

FIND A PET YOU LOVE
- Browse pets from approved local shops, with photos, age, breed and price
- Filter by species, breed, shop and budget
- Save favourites to your wishlist
- Ask for a demo, in person or by video, before you decide
- Reserve a pet in a few taps and collect it from the shop
- Gift a pet to someone special

SHOP FOR EVERYTHING ELSE
- Food, toys, accessories and care products from local shops
- One cart, one checkout; pickup and payment happen at the shop
- Track your orders and request a refund when something is wrong

BOOK SERVICES
- Grooming, bathing, trimming, training, walking, daycare and boarding
- Choose a local provider and request your preferred date and time
- Need something special? Send a custom service request

PETSTA HEALTH
- Book a video consultation with a vet
- Ask the pharmacy assistant about everyday pet care and find related products
- Health guidance is general information and does not replace a vet; in an emergency go to your nearest vet clinic

LEARN
- Pet-care videos picked by the PETSTA team

RUN A SHOP ON PETSTA
- Apply to sell as a licensed pet shop
- Manage your pets, products, services, orders, demos and refunds from your phone
- See revenue and order trends on your dashboard

SAFE AND SIMPLE
- No ads and no tracking
- No card details are collected in the app; you pay at the shop
- Delete your account from your profile at any time

PETSTA is a marketplace. Pets, products and services are offered by independent licensed shops, who are responsible for their listings and for complying with local animal-welfare and consumer laws.

Questions? Open Support in the app.
```

Before pasting, re-check these claims against the shipped build:
"Delete your account" needs the `delete_my_account` database function deployed,
and "No ads and no tracking" is true only while no analytics or ad SDK is added.

### What's new (v1.0.0)

```
Welcome to PETSTA 1.0: browse and reserve pets from local shops, shop supplies, book services and vet video consults, and run your shop from your phone.
```

## 3. Age rating

Answers are the same on both stores: no violence, no sexual content, no profanity,
no gambling, no alcohol/tobacco/drugs, no horror, no mature themes.

- **Google Play (IARC questionnaire)**: category "Reference, News or
  Educational" does not fit; choose **Utility, Productivity, Communication or
  Other** (shopping). Answer "No" to violence, sexual content, language,
  controlled substances, gambling. Answer **Yes** to "users can interact or
  exchange content" (shop reviews, support messages) and **No** to sharing
  location and to digital purchases. Online purchase of physical goods: Yes
  (reservations). Expected result: Everyone / PEGI 3 / equivalents, with the
  "Users interact" note.
- **App Store**: answer "None" to every content descriptor. Expected rating
  **4+**. If the new questionnaire asks about user-generated content or
  messaging, answer that text reviews and support messages exist, with no
  user-to-user chat. If the app gains user-to-user messaging or photo sharing,
  re-answer and add a reporting and blocking mechanism (App Store Review
  Guideline 1.2).
- **Target audience (Play)**: 18+ is the safest choice because shop owners
  contract with the platform; at minimum "not designed for children". Do not
  opt in to the Families programme.

## 4. Screenshot shot-list

Capture in light mode with realistic seeded data (a few real-looking shops and
pets, no lorem ipsum, no test accounts visible). Use text overlays no longer
than 6 words.

Required sizes:

- **Google Play**: 2 to 8 phone screenshots, 16:9 or 9:16, each side 320 to
  3840 px (use 1080 x 1920 or larger). Tablet screenshots (7" and 10") are
  optional but improve ranking if you support tablets.
- **App Store**: 6.9" iPhone (1320 x 2868) or 6.5" (1284 x 2778) is required;
  the other sizes scale from it. The app runs on iPad, so also supply 13" iPad
  (2064 x 2752).

| # | Screen | Overlay caption | Notes |
|---|---|---|---|
| 1 | Home | "Pets from local shops" | Hero, species grid, featured pets |
| 2 | Pets list with filters open | "Filter by breed and budget" | Show 4 to 6 cards with photos |
| 3 | Pet detail | "Meet before you pay" | Photo gallery, reserve and demo buttons |
| 4 | Reserve / order confirmation | "Reserve in a few taps" | Shows "pay at pickup" |
| 5 | Store with cart | "Everything for your pet" | Product grid, cart badge |
| 6 | Services | "Book grooming and more" | Category chips visible |
| 7 | Health, vet video consult | "Talk to a vet" | Safety note visible |
| 8 | Account, orders | "Track every order" | Order timeline |
| 9 | Seller dashboard | "Run your shop" | Revenue chart (seller account) |

Take iPhone screenshots from the Simulator (Device, Screenshot) or a real
device, Android ones from a Pixel-class emulator with the status bar in demo
mode (`adb shell settings put global sysui_demo_allowed 1`).

## 5. Google Play: Data safety form

Play Console, App content, Data safety. Answers (as of v1.0.0; no analytics,
ad or crash-reporting SDK is present, and the app never reads location,
contacts, camera, microphone, photos or device identifiers):

- Does the app collect or share any of the required user data types? **Yes**
  (collects).
- Is all collected data encrypted in transit? **Yes** (HTTPS to Supabase).
- Do you provide a way for users to request that their data be deleted?
  **Yes**: in-app "Delete account" (customers) and the account deletion URL
  above (for shop owners, who contact support first).
- **Shared with third parties: none.** Supabase and the meeting provider act as
  service providers on the owner's behalf, which Play does not count as
  sharing. The video link is a Jitsi room URL derived from the booking id and
  opens in the browser; the app sends no personal data to it.

| Data type | Collected | Required or optional | Purpose |
|---|---|---|---|
| Personal info: Name | Yes | Required (account) | App functionality, Account management |
| Personal info: Email address | Yes | Required | App functionality, Account management, Developer communications (optional newsletter) |
| Personal info: User IDs | Yes | Required | App functionality, Account management |
| Personal info: Address | Yes | Optional (saved addresses) | App functionality |
| Personal info: Phone number | Yes | Optional (needed for bookings and gifts) | App functionality |
| Financial info: Purchase history | Yes | Required for orders | App functionality |
| Financial info: card or bank details | **No** | n/a | Payment happens in person |
| Messages: Other in-app messages | Yes | Optional (support tickets, service requests, gift notes) | App functionality |
| App activity, web browsing, location, photos, audio, files, contacts, calendar, health and fitness, device or other IDs | **No** | n/a | n/a |
| App info and performance: crash logs, diagnostics | **No** (today) | n/a | Change to Yes if a crash reporting SDK is added |

None of the data is used for tracking or advertising by third parties.

## 6. Apple: App Privacy ("nutrition labels")

App Store Connect, App Privacy. The privacy manifest shipped in the app
(`ios/Runner/PrivacyInfo.xcprivacy`) says the same: no tracking, no tracking
domains.

- **Data used to track you: none.**
- **Data linked to you** (everything is tied to the signed-in account; nothing
  is collected without an account except the newsletter e-mail):

| Category | Data type | Purposes |
|---|---|---|
| Contact info | Name | App functionality |
| Contact info | Email address | App functionality, Developer's advertising or marketing (newsletter) |
| Contact info | Phone number | App functionality |
| Contact info | Physical address | App functionality |
| Purchases | Purchase history | App functionality |
| User content | Customer support | App functionality |
| User content | Other user content (reviews, notes, listings) | App functionality |
| Identifiers | User ID | App functionality |

- **Data not collected**: location, health and fitness, financial info (no card
  numbers), contacts, browsing history, search history, usage data, diagnostics
  (revisit if a crash reporter is added), sensitive info.
- **Required-reason API**: `UserDefaults` (shared_preferences stores the session
  and the cart), reason `CA92.1`. Declared in the manifest.
- **Export compliance**: `ITSAppUsesNonExemptEncryption = false` (only
  standard HTTPS).

## 7. Review notes (paste into "App Review Information" / Play "App access")

```
PETSTA is a marketplace where customers reserve pets and buy pet supplies from
independent licensed local shops. Nothing is shipped and no payment is taken
in the app: customers collect the pet or product at the shop and pay there.
Vet video consultations are held in an external video room that opens in the
browser; they are paid directly to the vet/shop, not through the app.

Demo accounts (create these before submitting and keep them working):
  Customer:    <email> / <password>
  Shop owner:  <email> / <password>   (approved shop with sample pets)
  Admin:       <email> / <password>   (optional)

Where to look: Home > Pets > a pet > Reserve; Store > Add to cart > Checkout;
Services; Health; Account > Orders. Account deletion: Account > Profile >
Delete account. Support: Account > Contact support.
```

Points a reviewer may raise, and the answer:

- *Why no in-app purchase?* Physical goods, live animals and services
  consumed outside the app are paid in person; in-app purchase rules cover
  digital goods only (confirm against the current App Review Guideline 3.1.3
  and Play Payments policy before each submission).
- *Medical content*: the Health tab gives general guidance, states it is not a
  substitute for a vet, and sends emergencies to a clinic.
- *User-generated content*: reviews and support messages exist; the owner must
  be able to remove content and act on reports (see `production-checklist.md`).
- *Live animals*: shops must hold the licences their jurisdiction requires.
