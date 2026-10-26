/// Rule-based knowledge for the pharmacy assistant (port of
/// src/components/health/pharmacyIntents.js). There is no AI behind it:
/// [matchIntent] matches keywords in the customer's message against the table
/// below and the chat shows canned, general-care guidance.
///
/// Everything here is pure Dart (no Flutter, no network) so it can be unit
/// tested: [normalizeQuery], [looksLikeEmergency], [matchIntent], [isGreeting],
/// [sanitizeKeyword] and [buildProductFilter].
///
/// Safety rules for anything added to this file:
///  * No dosages, no drug names to give, no prescription advice.
///  * Red flags (poisoning, seizures, collapse, breathing trouble, bloat,
///    urinary blockage, heatstroke, trauma, heavy bleeding, swallowed objects,
///    eclampsia ...) always win over every other topic and never come with
///    product suggestions.
///  * Every non-emergency topic lists "see a vet if" signs.
library;

const pharmacyDisclaimer =
    "Prescription medicines need a vet's prescription. This is general guidance, not a diagnosis.";

const pharmacyQuickReplies = <String>[
  'My dog has an upset stomach',
  'Tick & flea prevention',
  'Itchy skin',
  'Vaccination schedule',
  'Pet is not eating',
  'My dog is limping',
  'Cough or sneezing',
];

const pharmacyIntroMessage =
    "Hi! I'm PETSTA's automated pharmacy assistant. Tell me what's bothering your pet, or pick a topic below, and I'll share general care tips, warning signs to watch for and products in the store that may help. I'm not a vet or a pharmacist. If it looks like an emergency, don't chat: go to a vet straight away.";

const pharmacyFallbackMessage =
    "I'm not sure I understood that. I can share general guidance on the topics below. For anything specific to your pet, a vet consultation is the best next step.";

/// One topic in the assistant's knowledge table.
///
/// [keywords] are matched as whole words after [normalizeQuery] (apostrophes
/// dropped, so write "cant" and "wont"). Each word may carry a trailing
/// s / es / ed / d / ing / y ("itch" also catches "itching" and "itchy"; words
/// of three letters or fewer only take "s"). A `*` between two words allows up
/// to two other words in between ("scratch * ear" matches "scratching her
/// ear"). Multi-word keywords count for more. [topic] is the label shown as a
/// quick-reply chip and must itself match this intent. [searchKeywords]
/// (letters, digits and spaces only) are looked up in the product catalogue;
/// [category] `'medicine'` limits that search to medicine, null searches every
/// category.
class PharmacyIntent {
  final String id;
  final bool urgent;
  final String? topic;
  final String? title;
  final List<String> keywords;
  final String message;
  final List<String> steps;
  final List<String> seeVet;
  final List<String> searchKeywords;
  final String? category;
  final String? noProductsNote;

  const PharmacyIntent({
    required this.id,
    this.urgent = false,
    this.topic,
    this.title,
    required this.keywords,
    required this.message,
    this.steps = const [],
    this.seeVet = const [],
    this.searchKeywords = const [],
    this.category,
    this.noProductsNote,
  });
}

/// What [matchIntent] found: a topic ([intent]), an emergency ([isEmergency],
/// in which case [intent] is [emergencyIntent]), or nothing (both default).
class IntentMatch {
  final PharmacyIntent? intent;
  final bool isEmergency;

  const IntentMatch({this.intent, this.isEmergency = false});
}

/// The urgent answer. It has no [PharmacyIntent.searchKeywords], so nothing
/// built from it can ever suggest a product.
const emergencyIntent = PharmacyIntent(
  id: 'emergency',
  urgent: true,
  keywords: [],
  message:
      "This could be an emergency. Please don't wait: go to your nearest vet clinic or emergency vet immediately.",
  steps: [
    'Take your pet to the nearest vet clinic or emergency vet right now.',
    'If you can, phone the clinic on the way so they can get ready for you.',
    'Keep your pet calm, warm and as still as possible, and bring the packaging or a photo of anything they ate or swallowed.',
    "Don't give food, human medicines or home remedies, and don't try to make your pet vomit, unless a vet tells you to.",
  ],
);

/// The non-emergency topics, in priority order: on a score tie the topic listed
/// first wins.
const pharmacyIntents = <PharmacyIntent>[
  PharmacyIntent(
    id: 'digestive',
    topic: 'Upset stomach',
    title: 'Upset stomach, vomiting or loose stools',
    keywords: [
      'upset stomach',
      'stomach ache',
      'stomach pain',
      'tummy ache',
      'tummy',
      'stomach',
      'vomit',
      'throwing up',
      'threw up',
      'been sick',
      'being sick',
      'sick again',
      'diarrhea',
      'diarrhoea',
      'loose stool',
      'loose motion',
      'runny poo',
      'runny stool',
      'soft stool',
      'watery stool',
      'nausea',
      'indigestion',
      'gas',
      'gassy',
      'dehydrated',
    ],
    message:
        "A mild upset stomach often settles with rest. Keep fresh water available, offer small plain meals instead of one big portion, and avoid table scraps, treats and sudden food changes while your pet recovers. Please don't give human anti-sickness or anti-diarrhoea medicines.",
    seeVet: [
      'vomiting or diarrhoea lasts more than a day, or keeps coming back',
      'there is blood in the vomit or stool, or the stool is black',
      'the belly looks swollen or seems painful',
      "your pet is very tired, refuses water or can't keep water down",
      'your pet may have eaten something harmful or a foreign object',
      'your pet is a puppy, kitten or senior (they dehydrate quickly)',
    ],
    searchKeywords: ['probiotic', 'digest', 'diarrhea', 'stomach'],
    category: 'medicine',
  ),
  PharmacyIntent(
    id: 'constipation',
    topic: 'Constipation',
    title: 'Constipation or straining to poo',
    keywords: [
      'constipation',
      'constipated',
      'hard stool',
      'hard poo',
      'dry stool',
      'no stool',
      'no poo',
      'cant poo',
      'cant poop',
      'not poop',
      'not poo',
      'havent poop',
      'strain * poo',
      'strain * poop',
    ],
    message:
        "Occasional hard stools often ease with plenty of fresh water, gentle exercise and a steady routine. A little extra fibre in the usual diet can help, but change foods gradually. Please don't give laxatives, oils or human remedies unless a vet advises it.",
    seeVet: [
      'there has been no stool for more than a day or two',
      'your pet strains with little or nothing coming out, or cries while trying (in cats this can also be a urinary blockage, which is an emergency)',
      'there is blood or mucus, or the belly looks swollen or painful',
      'there is vomiting as well, or your pet is lethargic',
      'your pet is a puppy, kitten or senior',
    ],
    searchKeywords: ['fibre', 'fiber', 'digest'],
    category: 'medicine',
  ),
  PharmacyIntent(
    id: 'cough',
    topic: 'Cough or sneezing',
    title: 'Coughing and sneezing',
    keywords: [
      'cough',
      'sneeze',
      'sneezing',
      'reverse sneezing',
      'runny nose',
      'blocked nose',
      'stuffy nose',
      'nasal discharge',
      'kennel cough',
      'common cold',
      'has a cold',
      'wheeze',
      'wheezing',
      'congested',
      'honking',
      'hacking',
      'gagging',
    ],
    message:
        'An occasional cough or sneeze is usually harmless; dust, excitement or pulling on a collar can set it off. Keep your pet calm and away from smoke, strong sprays and dust, and use a harness instead of a collar if they pull. Coughs can spread between pets, so keep them away from other animals until a vet has seen them.',
    seeVet: [
      'the cough or sneezing lasts more than a few days',
      'breathing looks fast, laboured or noisy (pale or bluish gums mean an emergency)',
      'the nose runs thick yellow or green, or there is blood',
      'your pet is lethargic, off food or has a fever',
      'your pet is a puppy, kitten or senior',
      'a honking cough started after boarding or time with other dogs',
    ],
    searchKeywords: ['cough', 'throat', 'respiratory'],
    category: 'medicine',
  ),
  PharmacyIntent(
    id: 'ear',
    topic: 'Ear problems',
    title: 'Ear problems',
    keywords: [
      'ear',
      'earache',
      'ear infection',
      'ear wax',
      'ear mite',
      'ear scratching',
      'scratch * ear',
      'itchy ear',
      'smelly ear',
      'stinky ear',
      'ear smell',
      'ear odour',
      'ear odor',
      'ear discharge',
      'shaking head',
      'head shaking',
      'head tilt',
    ],
    message:
        'Light dirt on the outer ear can be wiped away with a soft cloth and a pet-safe ear cleaner. Never push anything into the ear canal, and dry the ears well after baths and swimming.',
    seeVet: [
      'your pet tilts their head or loses balance',
      'there is a strong smell or discharge',
      'the ear looks red or swollen, or hurts when touched',
      'symptoms last more than a couple of days',
    ],
    searchKeywords: ['ear clean', 'ear drop', 'ear care', 'ear mite'],
    category: 'medicine',
  ),
  PharmacyIntent(
    id: 'eye',
    topic: 'Eye problems',
    title: 'Eye problems',
    keywords: [
      'eye',
      'eyelid',
      'watery eye',
      'red eye',
      'tear stain',
      'squint',
      'eye discharge',
      'eye infection',
      'cloudy eye',
      'crusty eye',
      'third eyelid',
      'conjunctivitis',
      'pink eye',
      'goopy',
      'gunk',
    ],
    message:
        "Gently wipe away crusty discharge with a clean cloth dampened in lukewarm water, using a fresh patch for each eye. Don't use human eye drops or medicines unless a vet has recommended them.",
    seeVet: [
      'your pet squints or keeps an eye shut',
      'the eye looks cloudy or very red',
      'the discharge is yellow or green',
      'there is a visible injury, or your pet paws at the eye',
      'your pet suddenly bumps into things',
    ],
    searchKeywords: ['eye clean', 'eye drop', 'eye wash', 'eye care'],
    category: 'medicine',
  ),
  PharmacyIntent(
    id: 'dental',
    topic: 'Teeth and gums',
    title: 'Teeth, gums and bad breath',
    keywords: [
      'teeth',
      'tooth',
      'dental',
      'bad breath',
      'smelly breath',
      'stinky breath',
      'gum',
      'plaque',
      'tartar',
      'toothpaste',
      'brush * teeth',
      'gingivitis',
    ],
    message:
        'Brushing regularly with a pet-specific toothpaste (never human toothpaste) and offering suitable dental chews helps keep teeth and gums healthy. Start slowly and keep it positive.',
    seeVet: [
      'the breath suddenly smells much worse',
      'the gums are red, swollen or bleeding',
      'teeth look loose or broken',
      'your pet drools, drops food or paws at their mouth',
    ],
    searchKeywords: ['dental', 'tooth', 'teeth', 'breath'],
  ),
  PharmacyIntent(
    id: 'parasites',
    topic: 'Fleas and ticks',
    title: 'Fleas and ticks',
    keywords: [
      'flea',
      'tick',
      'parasite',
      'lice',
      'louse',
      'infestation',
      'mite',
      'mange',
      'flea collar',
      'tick collar',
    ],
    message:
        "Fleas and ticks are best handled with regular prevention suited to your pet's species, age and weight. Comb the coat after time outdoors, wash bedding in hot water and treat every pet in the home together. Never use a product made for another species, as some dog products are toxic to cats.",
    seeVet: [
      "you can't remove a tick cleanly",
      'your pet seems weak or has pale gums after tick exposure',
      'a puppy, kitten or small pet has a heavy infestation',
      'the skin is red and sore, or hair is falling out',
    ],
    searchKeywords: ['flea', 'tick control', 'tick collar', 'tick spray', 'tick prevent'],
    category: 'medicine',
  ),
  PharmacyIntent(
    id: 'worming',
    topic: 'Worming',
    title: 'Worms',
    keywords: [
      'worm',
      'wormer',
      'deworm',
      'dewormer',
      'tapeworm',
      'roundworm',
      'hookworm',
      'scoot',
      'pot belly',
      'rice grains',
    ],
    message:
        "Regular worming, planned with your vet around your pet's age, weight and lifestyle, keeps worms under control. Puppies and kittens need it more often. Wash your hands after handling pets and pick up droppings promptly.",
    seeVet: [
      'you can see worms in the stool or vomit',
      'the belly looks swollen while your pet loses weight',
      'your pet scoots or constantly licks their bottom',
      'a puppy or kitten has diarrhoea',
    ],
    searchKeywords: ['worm'],
    category: 'medicine',
  ),
  PharmacyIntent(
    id: 'skin',
    topic: 'Itchy skin',
    title: 'Itchy skin, rashes and hot spots',
    keywords: [
      'itch',
      'scratch',
      'skin',
      'rash',
      'hot spot',
      'hotspot',
      'hair loss',
      'losing hair',
      'dandruff',
      'flaky',
      'allergy',
      'allergies',
      'allergic',
      'redness',
      'bald patch',
      'bald spot',
      'dry skin',
      'eczema',
      'shedding',
      'dull coat',
      'licking * paw',
      'chewing * paw',
    ],
    message:
        'Itching often comes from dry skin, allergies or parasites. Check the coat for fleas, keep bedding clean, and bathe only with a pet-safe shampoo, since human products can irritate. Stop your pet from scratching raw patches.',
    seeVet: [
      'the skin is raw, bleeding or oozing',
      'hair is falling out in patches',
      'there is facial swelling or hives (this can be an emergency)',
      'scratching or licking keeps your pet awake',
      'the skin has a bad smell',
    ],
    searchKeywords: ['skin', 'itch', 'medicated shampoo', 'allerg'],
    category: 'medicine',
  ),
  PharmacyIntent(
    id: 'joints',
    topic: 'Limping and joint pain',
    title: 'Limping, joints and mobility',
    keywords: [
      'joint',
      'arthritis',
      'limp',
      'stiff',
      'stiffness',
      'lame',
      'lameness',
      'mobility',
      'hip',
      'slow to get up',
      'cant jump',
      'sore leg',
      'favouring',
      'favoring',
      'wont put weight',
    ],
    message:
        'Keep exercise gentle and steady, maintain a healthy weight to take pressure off the joints, and offer soft, warm bedding. Avoid slippery floors and lots of stairs. Joint supplements are sold for older pets, but have a vet check the cause first.',
    seeVet: [
      'limping lasts more than a day or two',
      "a leg is held up or won't take weight",
      'there is swelling, heat or obvious pain',
      'your pet cries out or becomes suddenly stiff',
    ],
    searchKeywords: ['joint', 'glucosamine', 'arthritis', 'mobility'],
  ),
  PharmacyIntent(
    id: 'vaccination',
    topic: 'Vaccination schedule',
    title: 'Vaccinations',
    keywords: [
      'vaccine',
      'vaccination',
      'vaccinate',
      'vaccinated',
      'immunisation',
      'immunization',
      'booster',
      'shot',
      'jab',
      'rabies',
      'distemper',
      'parvo',
      'dhpp',
    ],
    message:
        'Core vaccines are usually given as a series when your pet is young, followed by boosters through life. The exact schedule depends on species, age, local risks and the vaccines used, so your vet will set it for your pet. Keep the vaccination card safe and ask which boosters are due.',
    seeVet: [
      'the vaccination history is overdue or unknown',
      'you have a new puppy or kitten and need a starting schedule',
      "you're planning boarding, daycare or travel",
      'your pet is swollen, tired or vomiting after a vaccine',
      'an unvaccinated puppy has bloody diarrhoea or repeated vomiting (this can be parvovirus and is an emergency)',
    ],
    noProductsNote:
        "Vaccines are given by a vet, so there's nothing to buy from the store. A vet consultation is the way to plan the schedule.",
  ),
  PharmacyIntent(
    id: 'appetite',
    topic: 'Loss of appetite',
    title: 'Loss of appetite or thirst',
    keywords: [
      'not eating',
      'wont eat',
      'doesnt eat',
      'dont eat',
      'doesnt want * eat',
      'refuse to eat',
      'refusing food',
      'stopped eating',
      'off food',
      'not hungry',
      'appetite',
      'eating less',
      'picky',
      'fussy',
      'not drinking',
      'wont drink',
      'skipping meals',
    ],
    message:
        "A pet that skips a meal now and then is usually fine. Try warming the food slightly, keep to a routine, reduce stress and noise at mealtimes, and check that nothing about the food has changed. Don't force-feed, and keep fresh water available.",
    seeVet: [
      "your pet hasn't eaten for a full day (about 12 hours for puppies, kittens and small pets)",
      "your pet won't drink at all",
      'there is vomiting or diarrhoea as well',
      'your pet is hiding, very tired or losing weight',
      'your pet drools or paws at their mouth',
    ],
    searchKeywords: ['appetite', 'vitamin', 'tonic'],
  ),
  PharmacyIntent(
    id: 'weight',
    topic: 'Weight and diet',
    title: 'Weight and diet',
    keywords: [
      'weight',
      'overweight',
      'obese',
      'obesity',
      'chubby',
      'fat',
      'underweight',
      'skinny',
      'thin',
      'diet',
      'portion',
      'nutrition',
      'what to feed',
      'how much to feed',
      'feed',
      'dog food',
      'cat food',
      'puppy food',
      'kitten food',
      'pet food',
    ],
    message:
        "Feed measured portions of a complete food suited to your pet's age and size, and count treats as part of the day's food. Change foods gradually over about a week, and avoid human foods like chocolate, grapes, raisins, onions and anything sweetened with xylitol. Weigh your pet regularly so changes show early.",
    seeVet: [
      'your pet is losing or gaining weight quickly without a diet change',
      'your pet is drinking or urinating much more than usual',
      'your pet is very thin, with ribs, hips or spine easy to see',
      'you want a weight-loss plan (a vet can set a safe pace)',
      'your pet has a health condition and needs a special diet',
    ],
    searchKeywords: ['food', 'diet', 'weight control', 'low fat'],
  ),
  PharmacyIntent(
    id: 'weather',
    topic: 'Hot and cold weather',
    title: 'Hot and cold weather',
    keywords: [
      'weather',
      'hot weather',
      'hot day',
      'heat wave',
      'heatwave',
      'summer',
      'sunburn',
      'panting',
      'too hot',
      'keep cool',
      'cool down',
      'cooling',
      'cold weather',
      'too cold',
      'winter',
      'shivering',
      'freezing',
      'chilly',
    ],
    message:
        "In hot weather keep fresh water out, walk at the cool ends of the day, give shade and airflow, and never leave a pet in a parked car. Hot pavement can burn paws; if it's too hot for the back of your hand, it's too hot for them. In the cold, keep walks shorter, dry your pet well afterwards and give warm bedding away from draughts.",
    seeVet: [
      "heavy panting that won't settle, drooling, vomiting or wobbliness in the heat (treat it as an emergency)",
      'shivering that continues indoors, or your pet seems weak and sleepy in the cold',
      'paws look red, blistered or cracked',
      'the skin looks sunburnt, especially on pale ears and noses',
    ],
    searchKeywords: ['cooling mat', 'cool mat', 'sweater', 'jacket', 'water bowl'],
  ),
  PharmacyIntent(
    id: 'travel',
    topic: 'Travel',
    title: 'Travelling with your pet',
    keywords: [
      'travel',
      'travelling',
      'traveling',
      'car sick',
      'car sickness',
      'motion sickness',
      'flight',
      'long drive',
      'road trip',
      'moving house',
      'relocating',
      'carrier',
    ],
    message:
        "Get your pet used to the carrier or car seat beforehand with short practice trips, keep them secure and well ventilated, and stop for water and breaks on long journeys. Never leave a pet alone in a parked vehicle. A light meal a few hours before travelling is gentler on the stomach than a full bowl. Ask your vet about travel anxiety, motion sickness and any papers you need before trains, flights or boarding.",
    seeVet: [
      'your pet drools heavily, vomits or pants hard on trips',
      'your pet panics or hurts themselves when travelling',
      'you need health certificates or vaccination proof for the journey',
      'your pet is very young, old or unwell and the trip is long',
    ],
    searchKeywords: ['carrier', 'travel', 'harness', 'seat belt'],
  ),
  PharmacyIntent(
    id: 'anxiety',
    topic: 'Anxiety and behaviour',
    title: 'Anxiety and behaviour',
    keywords: [
      'anxious',
      'anxiety',
      'stress',
      'scared',
      'afraid',
      'fear',
      'barking',
      'howling',
      'aggressive',
      'aggression',
      'destructive',
      'separation',
      'fireworks',
      'thunder',
      'restless',
      'behaviour',
      'behavior',
      'biting',
    ],
    message:
        'Anxious or unsettled pets do best with a predictable routine, daily exercise and play, and a quiet safe space to retreat to. For triggers like fireworks, stay calm yourself, close windows and curtains and offer a favourite toy. Reward calm behaviour rather than scolding fear.',
    seeVet: [
      'behaviour changes suddenly',
      "your pet is aggressive in a way that's out of character",
      'your pet hurts themselves or licks constantly',
      'your pet stops eating or toileting',
      'the anxiety keeps getting worse despite routine changes',
    ],
    searchKeywords: ['calming', 'anxiety', 'stress relief', 'chew toy'],
  ),
  PharmacyIntent(
    id: 'newpet',
    topic: 'New puppy or kitten',
    title: 'New puppy or kitten basics',
    keywords: [
      'new puppy',
      'new kitten',
      'new pet',
      'puppy or kitten',
      'just adopted',
      'just got * puppy',
      'just got * kitten',
      'bringing home',
      'brought home',
      'first night',
      'first week',
      'first time owner',
      'house training',
      'potty training',
      'toilet training',
      'litter training',
      'crate training',
      'teething',
    ],
    message:
        "Welcome! In the first days set up a quiet, warm sleeping spot, keep a steady feeding and toilet routine, and let your new pet settle before lots of visitors. Keep feeding the food they came with and change it gradually. Book a first vet check and ask about vaccination and worming schedules, and keep unvaccinated puppies and kittens away from public parks and unfamiliar animals until your vet says it's safe. Puppy-proof the house: tuck away cables, small objects and plants.",
    seeVet: [
      'your pet refuses food or water for a day, or vomits or has diarrhoea (young pets dehydrate fast)',
      'your pet is very sleepy, weak, cold or limp',
      'there is coughing, sneezing, runny eyes or a swollen belly',
      'you have no vaccination or worming records',
    ],
    searchKeywords: ['puppy', 'kitten', 'starter'],
  ),
  PharmacyIntent(
    id: 'wounds',
    topic: 'Cuts and wounds',
    title: 'Minor cuts and scrapes (first aid)',
    keywords: [
      'wound',
      'small cut',
      'deep cut',
      'bad cut',
      'minor cut',
      'got * cut',
      'cut * paw',
      'cut * leg',
      'cut * ear',
      'cut himself',
      'cut herself',
      'cut itself',
      'bite',
      'bitten',
      'scrape',
      'graze',
      'scab',
      'bleed',
      'injury',
      'injured',
      'torn nail',
      'broken nail',
      'split nail',
    ],
    message:
        "For a small, shallow scrape, gently rinse with clean lukewarm water, pat dry and stop your pet licking it (a protective cone helps). Don't use human antiseptics, creams or medicines unless a vet says so, and watch the area for changes.",
    steps: [
      'Stay calm and gently hold your pet still so they cannot lick or bite the area.',
      'Rinse with clean lukewarm water to wash away dirt.',
      'If it is bleeding, press a clean cloth on it firmly for several minutes.',
      'Cover loosely with a clean dressing if your pet will leave it alone.',
    ],
    seeVet: [
      'the wound is deep, gaping or still bleeding after several minutes of pressure',
      'it was a bite from another animal (they infect easily)',
      'there is swelling, heat, pus or a bad smell',
      "it isn't healing after a few days",
      'your pet is limping, dull or off their food',
    ],
    searchKeywords: ['wound', 'antiseptic', 'bandage', 'first aid'],
    category: 'medicine',
  ),
  PharmacyIntent(
    id: 'swelling',
    topic: 'Lumps, bumps and stings',
    title: 'Lumps, bumps, stings and swelling',
    keywords: [
      'lump',
      'bump',
      'swelling',
      'swollen',
      'sting',
      'stung',
      'bee',
      'wasp',
      'insect bite',
      'abscess',
      'boil',
      'cyst',
      'growth',
      'tumour',
      'tumor',
    ],
    message:
        "Most lumps and bumps turn out to be harmless, but only an examination can tell. Note when you first noticed it, how big it is and whether it changes, take a photo, and don't squeeze it or treat it at home. For a sting, keep your pet calm and watch them closely for the next few hours.",
    seeVet: [
      'it is new, growing quickly, hard, hot or painful',
      'it oozes, bleeds or smells bad',
      'the face, lips or throat swell, or there are hives (this can be an emergency)',
      'your pet is lethargic, off food or has trouble breathing',
    ],
    noProductsNote:
        "A new lump needs a proper look, so there's nothing in the store I'd suggest. A vet consultation is the best next step.",
  ),
  PharmacyIntent(
    id: 'medicines',
    topic: 'Medicines and doses',
    title: 'Medicines and doses',
    keywords: [
      'dose',
      'dosage',
      'overdose',
      'paracetamol',
      'ibuprofen',
      'aspirin',
      'acetaminophen',
      'painkiller',
      'pain killer',
      'antibiotic',
      'steroid',
      'human medicine',
      'human medication',
      'prescription',
      'prescribe',
      'tablet',
      'syrup',
      'medicine',
      'medication',
    ],
    message:
        "I can't recommend doses or choose a medicine for your pet. Medicines must be chosen and dosed by a vet for your pet's species, age and weight, and many human medicines (including common painkillers) are dangerous for pets. Prescription items in the store need a vet's prescription.",
    seeVet: [
      'you want to give any medicine, supplement or human remedy',
      'your pet needs pain relief',
      'your pet has already taken a human medicine (treat it as an emergency)',
      'a prescribed medicine causes vomiting, drowsiness or a rash',
    ],
    noProductsNote:
        "Medicines are chosen and dosed by a vet, so I can't suggest a specific product. A vet consultation is the safest next step.",
  ),
];

/// Topic chips for the "I didn't understand" reply.
final List<String> pharmacyTopics = [
  for (final intent in pharmacyIntents)
    if (!intent.urgent && intent.topic != null) intent.topic!,
];

/// Lower-case, drop apostrophes ("can't" -> "cant"), turn everything else that
/// isn't a letter or digit into spaces and collapse runs of spaces. Safe on
/// any input, including the empty string.
String normalizeQuery(String text) {
  return text
      .toLowerCase()
      .replaceAll(RegExp("['’‘`]"), '')
      .replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), ' ')
      .trim();
}

// Red-flag phrases, matched on whole words after [normalizeQuery] (so no
// apostrophes: "cant", "wont"). Anything listed here is treated as an
// emergency even if the sentence is also a question or says "not": for a
// possible poisoning, seizure or breathing problem a false alarm costs far
// less than a missed one.
const _emergencySources = <String>[
  // Poisons, toxins and things that should never be eaten.
  r'\bpoison(?:s|ed|ing|ous)?\b',
  r'\btoxic(?:ity)?\b',
  r'\bchoc(?:o)?lat(?:e|es)?\b(?! (?:labrador|labradors|lab|labs|coat|coats|coloured|colored|brown|point|poodle|spaniel|retriever|haired|fur|eyes|nose))',
  r'\bcocoa\b',
  r'\bxylitol\b',
  r'\b(?:grapes?|raisins?|sultanas?)\b',
  r'\b(?:antifreeze|coolant|rodenticide)\b',
  r'\b(?:ate|eaten|eating|swallowed|swallowing|licked|licking|drank|drunk|chewed|chewing|got into|gets into) (?:\w+ ){0,4}(?:pesticides?|insecticides?|weedkiller|weed killer|snail bait|bleach|detergent|cleaner|batter(?:y|ies)|paint|petrol|diesel|kerosene|medicine|medication|pills?|tablets?|painkillers?|ibuprofen|paracetamol|acetaminophen|aspirin|lil(?:y|ies)|macadamias?|onions?|garlic|mushrooms?|cannabis|marijuana|alcohol|nicotine|cigarettes?)\b',
  // Seizures, collapse and paralysis.
  r'\bs(?:ei|ie|e)[sz]ure?s?\b',
  r'\b(?:seizing|convulsing|convulsions?|convulsed|epileptic fits?)\b',
  r'\bfoaming (?:at the |from the )?mouth\b',
  r'\b(?:having|has|have|had|got|getting|gets|keeps having|kept having) (?:(?:a|another) fit|(?:some |two |three |more )?fits)\b',
  r'\b(?:is|was|keeps|started|began|been) fitting\b',
  r'\bfits\b',
  // The words themselves.
  r'\bemergency\b(?! (?:kit|contact|fund|numbers?))',
  r'\b(?:dying|about to die|going to die|life threatening)\b',
  r'\b(?:dog|cat|puppy|kitten|pet|he|she|it) (?:is |was |has been )?not moving\b',
  r'\b(?:collaps(?:e|ed|es|ing)|unconscious|unresponsive|passed out|fainted|fainting)\b',
  r'\b(?:wont|will not|cant|cannot) wake up\b',
  r'\bnot waking up\b',
  r'\bparalys(?:ed|is)\b',
  r'\b(?:suddenly|all of a sudden) (?:cant|cannot|unable to) (?:walk|stand|move|use)\b',
  // Breathing and gum colour.
  r'\b(?:cant|cannot|can not|couldnt|unable to|struggling to|struggles to|hard to|not able to) breathe\b',
  r'\b(?:difficulty|trouble|problems?|struggling|struggle|issues?) (?:in |with )?breathing\b',
  r'\b(?:not breathing|stopped breathing|stops breathing|barely breathing|laboured breathing|labored breathing|short of breath|gasping|choked|chokes)\b',
  r'\bchoking\b(?! hazards?)',
  r'\bbreathing (?:very |really |so )?(?:fast|heavily|hard|rapidly|badly|noisily)\b',
  r'\b(?:blue|bluish|purple|grey|gray|pale|white) gums?\b',
  r'\b(?:blue|bluish|purple) (?:tongue|lips?)\b',
  r'\bgums? (?:are |is |look |looks |turned |turning |have turned |has turned )?(?:blue|bluish|purple|grey|gray|pale|white)\b(?! pink)',
  r'\b(?:tongue|lips?) (?:is |are |looks? |turned |turning )?(?:blue|bluish|purple)\b',
  // Bloat (a hard, swollen belly) and unproductive retching.
  r'\b(?:bloat|bloated|bloating|gdv)\b',
  r'\b(?:hard|tight|swollen|distended|enlarged|tense|ballooned) (?:belly|stomach|tummy|abdomen)\b',
  r'\b(?:belly|stomach|tummy|abdomen) (?:is |looks |feels |has |became |gone |got )?(?:very |really |suddenly |so )?(?:hard|tight|swollen|distended|tense)\b',
  r'\b(?:unproductive|dry) (?:retching|vomiting|heaving)\b',
  r'\b(?:retching|gagging|trying to vomit|trying to throw up) (?:but |and )?(?:nothing|no)\b',
  // Urinary blockage.
  r'\b(?:cant|cannot|can not|unable to|not able to|struggling to|straining to|strains to) (?:pee|wee|urinate|passing urine|pass urine)\b',
  r'\b(?:hasnt|havent|has not|have not|didnt|did not) (?:peed|weed|urinated|passed urine|passed any urine)\b',
  r'\b(?:no urine|not producing urine|not passing urine)\b',
  r'\bstrain(?:ing|s|ed)? (?:in |at |on |over )?(?:the |his |her |its )?(?:litter|tray|box)\b',
  r'\burinary (?:blockage|obstruction|block)\b',
  r'\bblocked (?:bladder|urethra|cat)\b',
  // Heat, trauma, bites, shocks and burns.
  r'\bheat ?stroke\b',
  r'\boverheat(?:ed|ing|s)?\b',
  r'\bhit by (?:a |an |the )?(?:car|vehicle|truck|lorry|bus|bike|motorbike|motorcycle|scooter|auto|rickshaw|train|van|jeep|tempo)\b',
  r'\b(?:got|been|was|gets|being|nearly|almost|just) (?:run|ran) over\b',
  r'\b(?:run|ran) over by\b',
  r'\b(?:run|ran) over (?:my|our|the|a|his|her) (?:dog|cat|puppy|kitten|pet)\b',
  r'\b(?:attacked|mauled|savaged) by\b',
  r'\b(?:fell|fallen|dropped|thrown|jumped) (?:from|off|out of) (?:the |a |an |our |my )?(?:\w+ )?(?:balcony|building|height|roof|terrace|window|floor|storey|story)\b',
  r'\b(?:broken|fractured|snapped|dislocated) (?:bone|bones|leg|back|jaw|spine|neck|hip|pelvis|skull)\b',
  r'\bbroke (?:his |her |its |a |the )?(?:leg|back|jaw|spine|neck|hip|pelvis)\b',
  r'\b(?:snake ?bite|snake bit(?:ten)?|(?:bit|bitten) by (?:a |the )?(?:snake|cobra|viper|krait)|(?:scorpion|spider) (?:sting|stung|bite|bit))\b',
  r'\b(?:electrocuted|electric shock|electrical shock)\b',
  r'\b(?:drowning|drowned|nearly drowned|almost drowned)\b',
  r'\b(?:burnt|burned|scalded) (?:his |her |its |their |the |a |my )?(?:paws?|skin|mouth|tongue|foot|feet|legs?|ears?|nose|belly|back|face|body|himself|herself|itself)\b',
  r'\b(?:got|been|was|gets|badly|severely|being) (?:burnt|burned|scalded)\b',
  r'\bchemical burns?\b',
  r'\b(?:allergic reaction|anaphylaxis|anaphylactic|hives)\b',
  r'\b(?:face|muzzle|lips?|tongue|throat) (?:is |are |has |have |got )?(?:swollen|swelling|puffed up|puffy)\b',
  r'\b(?:swollen|puffy|swelling) (?:face|muzzle|lips?|tongue|throat)\b',
  // Heavy bleeding and blood in vomit or stool.
  r'\b(?:heavy|severe|profuse|serious) bleeding\b',
  r'\bbleeding (?:heavily|badly|profusely|a lot|non ?stop|nonstop|everywhere|through)\b',
  r'\b(?:a lot of|lots of|so much|loads of) blood\b(?! tests?| work| donors?| donation)',
  r'\bblood everywhere\b',
  r'\b(?:losing|lost) (?:a lot of )?blood\b',
  r'\b(?:wont|will not|cant|cannot) stop bleeding\b',
  r'\bbleeding (?:wont|will not|doesnt|does not|isnt|is not) stop(?:ping)?\b',
  r'\b(?:vomit(?:ing|ed|s)?|throwing up|threw up|coughing up|coughed up|passing|passed) (?:up )?(?:some |a little |a bit of |lots of )?blood\b',
  r'\bblood in (?:the |his |her |its )?(?:vomit|vomiting)\b',
  r'\b(?:bloody|blood stained) (?:vomit|diarrh(?:o)?ea)\b',
  r'\b(?:black|tarry|coffee ground)(?: tarry)? (?:stool|stools|poo|poop|vomit)\b',
  // Swallowed objects and choking.
  r'\b(?:swallow(?:ed|s|ing)?|ate|eaten|eating|gulped|gobbled|chewed up) (?:down )?(?:a |an |the |some |my |his |her |whole |part of (?:a |the )?|half (?:a |the )?|pieces? of (?:a |the )?)?(?:\w+ ){0,2}(?:socks?|stockings?|toys?|objects?|stones?|rocks?|pebbles?|corn ?cobs?|needles?|pins?|threads?|coins?|batter(?:y|ies)|magnets?|hair ?ties?|ribbons?|rubber bands?|elastics?|buttons?|plastic|wrappers?|foil|skewers?|fish ?hooks?|hooks?|bottle caps?)\b',
  r'\b(?:swallow(?:ed|s|ing)?|gulped|gobbled) (?:down )?(?:a |an |the |some |my |his |her |whole |part of (?:a |the )?|half (?:a |the )?|pieces? of (?:a |the )?)?(?:\w+ ){0,2}(?:strings?|bones?|sticks?|seeds?|pits?|plastic bags?|bags?|bottle tops?|lids?)\b',
  r'\bswallow(?:ed|s|ing)? (?:something|anything|a foreign|foreign)\b',
  r'\b(?:ate|eaten|eating|swallowed|swallowing|licked|chewed|got into) (?:something|anything|some) (?:bad|toxic|dangerous|poisonous|strange|weird|harmful|unknown|unsafe|he shouldnt|she shouldnt|it shouldnt|they shouldnt)\b',
  r'\bforeign (?:object|body)\b',
  r'\b(?:cant|cannot|unable to|difficulty|trouble) swallow(?:ing)?\b',
  r'\b(?:stuck|lodged) in (?:his |her |its |the |their )?(?:throat|mouth)\b',
  // Pregnancy and birth emergencies.
  r'\b(?:eclampsia|milk fever|dystocia)\b',
  r'\b(?:difficult|prolonged|obstructed|stuck in) (?:labou?r|birth|whelping|delivery)\b',
];

final List<RegExp> _emergencyPatterns = [for (final source in _emergencySources) RegExp(source)];

// "non-toxic shampoo", "xylitol free toothpaste" or "the collar fits well" is
// reassurance or shopping talk, not an alarm: these phrases are removed before
// the red flags are looked for.
final RegExp _reassurancePhrase = RegExp(
  r'\b(?:non toxic|xylitol free|free of xylitol|free from xylitol|without xylitol|no xylitol|chocolate free|cocoa butter)\b'
  r'|\b(?:this|that|it|collar|harness|leash|lead|bed|crate|cage|carrier|jacket|coat|sweater|size|which|what|does|do|will|would|if|well|always|perfectly) fits\b'
  r'|\bfits (?:well|perfectly|nicely|snugly|great|me|my|in|on|the|a|an|over|under|around)\b',
);

bool _hasEmergencyPhrase(String normalized) {
  final text = normalized.replaceAll(_reassurancePhrase, ' ');
  for (final pattern in _emergencyPatterns) {
    if (pattern.hasMatch(text)) return true;
  }
  return false;
}

/// True when [text] mentions a red flag that needs a vet now: poisoning or a
/// toxic food (chocolate, xylitol, grapes ...), seizures, collapse, trouble
/// breathing or blue gums, a hard bloated belly, being unable to pee, heatstroke,
/// being hit by a car, heavy bleeding, a swallowed sock / toy / object,
/// eclampsia and similar.
///
/// Matching is on whole words after [normalizeQuery], so "I can't breathe" and
/// "cant BREATHE!!" are the same, and "chocolate labrador" is not an alarm.
bool looksLikeEmergency(String text) => _hasEmergencyPhrase(normalizeQuery(text));

// A trailing s / es / ed / d / ing / y is allowed on every word; very short
// words only take "s" so "ear" never matches "eared" or "eyes" -> "eyed".
const _wordSuffix = '(?:s|es|ed|d|ing|y)?';

RegExp _keywordPattern(String keyword) {
  final buffer = StringBuffer(r'\b');
  final words = keyword.split(' ');
  for (var i = 0; i < words.length; i++) {
    final word = words[i];
    if (word == '*') {
      // Up to two other words between the neighbours.
      buffer.write(r'(?: [a-z0-9]+){0,2}');
      continue;
    }
    if (i > 0) buffer.write(' ');
    buffer
      ..write(word)
      ..write(word.length <= 3 ? '(?:s)?' : _wordSuffix);
  }
  buffer.write(r'\b');
  return RegExp(buffer.toString());
}

/// Number of real words in [keyword]; longer phrases are more specific.
int _keywordWeight(String keyword) => keyword.split(' ').where((word) => word != '*').length;

class _CompiledKeyword {
  final RegExp pattern;
  final int weight;
  const _CompiledKeyword(this.pattern, this.weight);
}

class _CompiledIntent {
  final PharmacyIntent intent;
  final List<_CompiledKeyword> keywords;
  const _CompiledIntent(this.intent, this.keywords);
}

final List<_CompiledIntent> _compiled = [
  for (final intent in pharmacyIntents)
    _CompiledIntent(
      intent,
      [
        for (final keyword in intent.keywords) _CompiledKeyword(_keywordPattern(keyword), _keywordWeight(keyword)),
      ],
    ),
];

/// Routes a customer message to a topic.
///
/// Emergency red flags ([looksLikeEmergency]) always win and come back as
/// `IntentMatch(intent: emergencyIntent, isEmergency: true)`; the chat shows
/// the urgent answer and never searches the store for them. Otherwise the topic
/// with the highest keyword score wins (on a tie the topic listed first in
/// [pharmacyIntents] does); no match at all gives an empty [IntentMatch].
IntentMatch matchIntent(String text) {
  final normalized = normalizeQuery(text);
  if (normalized.isEmpty) return const IntentMatch();
  if (_hasEmergencyPhrase(normalized)) {
    return const IntentMatch(intent: emergencyIntent, isEmergency: true);
  }

  PharmacyIntent? best;
  var bestScore = 0;
  for (final entry in _compiled) {
    var score = 0;
    for (final keyword in entry.keywords) {
      if (keyword.pattern.hasMatch(normalized)) score += keyword.weight;
    }
    if (score > bestScore) {
      best = entry.intent;
      bestScore = score;
    }
  }
  return IntentMatch(intent: best);
}

final RegExp _greetingPattern = RegExp(r'^(?:hi+|hello|hey+|hiya|namaste|good (?:morning|afternoon|evening))\b');

/// True for a plain greeting ("hi", "Hello!", "good morning ..."), which gets
/// the intro message instead of the "I didn't understand" reply.
bool isGreeting(String text) => _greetingPattern.hasMatch(normalizeQuery(text));

/// Keeps only letters, digits and single spaces so a keyword can't break the
/// PostgREST filter syntax.
String sanitizeKeyword(String keyword) {
  return keyword
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9 ]'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

/// The `.or()` filter string for a products query, or '' when there is nothing
/// to search for.
String buildProductFilter(List<String> keywords) {
  final unique = <String>{};
  for (final keyword in keywords) {
    final clean = sanitizeKeyword(keyword);
    if (clean.isNotEmpty) unique.add(clean);
  }
  return [
    for (final keyword in unique) ...['name.ilike.%$keyword%', 'description.ilike.%$keyword%'],
  ].join(',');
}
