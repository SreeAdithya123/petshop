/// The text of PETSTA's Privacy Policy and Terms of Use, kept apart from the
/// screens that display it so it can be edited (or reviewed by counsel)
/// without touching any UI code.

/// Shown on both documents.
const String kLegalEffectiveDate = '17 Oct 2026';

/// Honest status of the text; shown at the end of both documents.
const String kLegalReviewNote =
    "This is a plain-language summary. It is to be reviewed by the owner's legal counsel before the app is submitted to the app stores.";

/// One headed block of a legal document: optional paragraphs, then optional
/// bullet points.
class LegalSection {
  final String heading;
  final List<String> paragraphs;
  final List<String> bullets;

  const LegalSection(this.heading, {this.paragraphs = const [], this.bullets = const []});
}

class LegalDocument {
  final String title;

  /// One or two sentences shown above the first section.
  final String intro;
  final List<LegalSection> sections;

  const LegalDocument({required this.title, required this.intro, required this.sections});
}

const LegalDocument privacyPolicyDocument = LegalDocument(
  title: 'Privacy Policy',
  intro: 'PETSTA is a pet marketplace: you browse and reserve pets, buy pet supplies, book services and vet video '
      'consults, and collect your purchases from local shops. This page explains in plain language what the app '
      'does with your information. PETSTA has no ads and no tracking.',
  sections: [
    LegalSection(
      'What we collect',
      bullets: [
        'Your account: your name, email address, phone number and password. The password is stored in scrambled '
            'form by our sign-in provider, so nobody at PETSTA or at any shop can read it.',
        'Addresses you choose to save under My account.',
        'Your activity in the app: orders and reservations, service bookings and custom service requests, demo '
            'requests, gifts, refund requests, wishlist items, and the support tickets and messages you send.',
        'If you run a shop: your shop details (name, address, phone, licence number) and the pets, products, '
            'services, orders and requests for that shop.',
        'On your phone only: your cart and your signed-in session are kept on your device so they are still there '
            'next time you open the app.',
      ],
    ),
    LegalSection(
      'What we do not collect',
      bullets: [
        'No payments. PETSTA does not collect card or bank details and nothing is paid inside the app. Pickup '
            'and payment happen in person at the shop. Nothing is shipped.',
        'No ads, no advertising ID, no analytics or tracking tools, and we never sell your data.',
        'The app itself does not ask for your location, contacts, camera or microphone.',
      ],
    ),
    LegalSection(
      'How we use your information',
      bullets: [
        'To run your account and show you your orders, bookings, requests and refunds.',
        'To let the shop you deal with prepare your reservation, answer your request or handle a refund. A shop '
            'you order from, reserve with, book with or send a request to can see what it needs to serve you, '
            'typically your name, your phone number and what you asked for.',
        'To answer your support messages, review shops and services before they go live, and keep the '
            'marketplace safe. PETSTA administrators can see this information for those purposes.',
      ],
    ),
    LegalSection(
      'Who else is involved',
      bullets: [
        'Supabase hosts our database and handles sign-in. It processes and stores your information on our behalf.',
        'Video consults and demos open a Jitsi Meet room (meet.jit.si), a third-party service, in your browser. '
            'Jitsi has its own privacy policy and sees what you share during the call.',
        'Shop contact details (address and phone number) are never shown to customers in the app.',
      ],
    ),
    LegalSection(
      'Keeping your information safe',
      paragraphs: [
        'Data travels over encrypted connections, and the database only lets you see your own orders, requests '
            'and messages. No system is perfectly secure, so please choose a strong password and keep it to yourself.',
      ],
    ),
    LegalSection(
      'How long we keep it',
      paragraphs: [
        'We keep your information while your account is open. When you delete your account we delete or anonymise '
            'your personal data. Records a shop needs for its own sales history may remain, without your personal '
            'details.',
      ],
    ),
    LegalSection(
      'Your choices',
      bullets: [
        'Update your name, phone number and addresses any time in My account.',
        'Delete your account in the app: open My account, go to Profile and choose Delete my account. This removes '
            'or anonymises your personal data and cannot be undone. Shop owners and admins should contact support '
            'first.',
        'Ask a question or request a copy of your information through the Support screen.',
        'Log out from the menu any time.',
      ],
    ),
    LegalSection(
      'Children',
      paragraphs: [
        'PETSTA is not aimed at children and we do not knowingly collect their information.',
      ],
    ),
    LegalSection(
      'Changes to this policy',
      paragraphs: [
        'If this policy changes, the new version will appear here with a new effective date.',
      ],
    ),
    LegalSection(
      'Contact us',
      paragraphs: [
        'Questions about your privacy? Open the menu, choose Support and send us a message.',
      ],
    ),
  ],
);

const LegalDocument termsDocument = LegalDocument(
  title: 'Terms of Use',
  intro: 'These are the ground rules for using PETSTA. By creating an account or using the app you agree to them '
      'and to the Privacy Policy.',
  sections: [
    LegalSection(
      'What PETSTA is',
      paragraphs: [
        'PETSTA is a marketplace that connects customers with licensed local pet shops and service providers. '
            'Shops list pets, supplies and services and are responsible for them. PETSTA provides the app.',
      ],
    ),
    LegalSection(
      'Your account',
      bullets: [
        'You must be 18 or older, or use PETSTA together with a parent or guardian.',
        'Give accurate details and keep your password private. You are responsible for what happens on your '
            'account, so tell us straight away if you think someone else has access.',
        'One person, one account. Customers can delete their account in the app at any time.',
      ],
    ),
    LegalSection(
      'Reserving and buying',
      bullets: [
        'Reserving a pet or placing an order in the app asks the shop to hold the item for you. It is not a '
            'payment.',
        'Pickup and payment happen in person at the shop. Nothing is shipped.',
        'Prices and availability are set by the shop. Check the pet or product when you collect it.',
        'Where the app offers it, you can cancel an order from My orders while it is still pending.',
      ],
    ),
    LegalSection(
      'Pets',
      paragraphs: [
        'Pets are living animals. Shops are responsible for the accuracy of their listings, health information and '
            'certifications. We review shops before approving them but cannot inspect every animal, so please '
            'check the pet and its papers at pickup before you pay.',
      ],
    ),
    LegalSection(
      'Services and video consults',
      paragraphs: [
        'Bookings, demos and vet video consults are arranged between you and the shop or vet. Video calls run on '
            'Jitsi Meet. A video consult is not a substitute for emergency care: if your pet is in danger, go to a '
            'vet in person.',
      ],
    ),
    LegalSection(
      'Refunds and problems',
      paragraphs: [
        'If something goes wrong, send a refund request from My account. The shop decides on it in line with its '
            'policy and the law, and our Support team can help if you are stuck.',
      ],
    ),
    LegalSection(
      'Shop owners',
      bullets: [
        'A shop must be approved by PETSTA before it goes live and must hold any licence the law requires.',
        'Keep listings, prices and stock accurate, and honour reservations you have confirmed.',
        'Use customers\' details only to serve their order or request.',
        'You also agree to the shop contract shown in the app.',
      ],
    ),
    LegalSection(
      'Playing fair',
      bullets: [
        'No fraud, fake reviews, harassment or illegal trade in animals.',
        'Do not try to break, overload or scrape the app, or to reach other people\'s data.',
        'You are responsible for the reviews and messages you post. We may remove content that breaks these rules.',
      ],
    ),
    LegalSection(
      'Suspending or ending access',
      paragraphs: [
        'We may suspend or close accounts and shops that break these terms. You can stop using PETSTA, or delete '
            'your account, at any time.',
      ],
    ),
    LegalSection(
      'Limits',
      paragraphs: [
        'PETSTA is provided as is, as far as the law allows. Dealings in person happen between you and the shop, '
            'and PETSTA is not responsible for them beyond what the law requires. Nothing here limits rights you '
            'have under consumer law.',
      ],
    ),
    LegalSection(
      'Changes to these terms',
      paragraphs: [
        'We may update these terms. The new version will appear here with a new effective date, and using PETSTA '
            'after that means you accept it.',
      ],
    ),
    LegalSection(
      'Contact us',
      paragraphs: [
        'Questions about these terms? Open the menu, choose Support and send us a message.',
      ],
    ),
  ],
);
