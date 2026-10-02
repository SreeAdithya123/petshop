/**
 * Rule-based knowledge for the pharmacy assistant. There is no AI behind it:
 * `getReply` matches keywords in the customer's message against this table
 * and returns canned, general-care guidance. Nothing here gives dosages or
 * recommends a prescription medicine.
 */

export const DISCLAIMER =
  "Prescription medicines need a vet's prescription. This is general guidance, not a diagnosis.";

export const QUICK_REPLIES = [
  "My dog has an upset stomach",
  "Tick & flea prevention",
  "Itchy skin",
  "Vaccination schedule",
  "Pet is not eating",
];

export const INTRO_MESSAGE =
  "Hi! I'm PETSTA's automated pharmacy assistant. Tell me what's bothering your pet, or pick a topic below, and I'll share general care tips, warning signs to watch for and products in the store that may help. I'm not a vet or a pharmacist.";

const FALLBACK_MESSAGE =
  "I'm not sure I understood that. I can share general guidance on the topics below. For anything specific to your pet, a vet consultation is the best next step.";

/**
 * `keywords` are matched as whole words (a trailing s / es / ed / ing / y is
 * allowed, so "itch" also catches "itching" and "itchy"); multi-word
 * keywords count for more. `topic` is the label shown as a quick-reply chip
 * and must itself match this intent. `searchKeywords` (letters, digits and
 * spaces only) are looked up in the product catalogue; `category: "medicine"`
 * limits that search to medicine, `null` searches every category.
 */
const INTENTS = [
  {
    id: "emergency",
    urgent: true,
    keywords: [
      "poison",
      "toxic",
      "seizure",
      "seizing",
      "convulsion",
      "convulsing",
      "bleeding heavily",
      "bleeding badly",
      "bleeding a lot",
      "bleeding profusely",
      "heavy bleeding",
      "wont stop bleeding",
      "bleeding wont stop",
      "collapsed",
      "collapse",
      "unconscious",
      "unresponsive",
      "cant breathe",
      "cannot breathe",
      "not breathing",
      "struggling to breathe",
      "difficulty breathing",
      "trouble breathing",
      "gasping for air",
      "choking",
      "choked",
      "swallow",
      "swallowing",
      "hit by car",
      "hit by a car",
      "run over",
      "chocolate",
      "xylitol",
      "grapes",
      "raisins",
      "antifreeze",
      "rat poison",
      "rodent poison",
      "snake bite",
      "heatstroke",
      "heat stroke",
      "bloated stomach",
      "swollen stomach",
      "swollen belly",
      "pale gums",
      "broken bone",
    ],
    message:
      "This could be an emergency. Please don't wait: go to your nearest vet clinic or emergency vet immediately.",
    steps: [
      "Take your pet to the nearest vet clinic or emergency vet right now.",
      "If you can, phone the clinic on the way so they can get ready for you.",
      "Don't give food, human medicines or home remedies, and don't try to make your pet vomit, unless a vet tells you to.",
    ],
  },
  {
    id: "digestive",
    topic: "Upset stomach",
    title: "Upset stomach or digestion",
    keywords: [
      "upset stomach",
      "stomach",
      "tummy",
      "vomit",
      "throwing up",
      "diarrhea",
      "diarrhoea",
      "loose stool",
      "loose motion",
      "constipation",
      "constipated",
      "gas",
      "nausea",
      "indigestion",
    ],
    message:
      "A mild upset stomach often settles with rest. Keep fresh water available, offer small plain meals instead of one big portion, and avoid table scraps, treats and sudden food changes while your pet recovers.",
    seeVet: [
      "vomiting or diarrhoea lasts more than a day",
      "there is blood in the vomit or stool",
      "the belly looks swollen or seems painful",
      "your pet is very tired or refuses water",
      "your pet is a puppy, kitten or senior (they dehydrate quickly)",
    ],
    searchKeywords: ["probiotic", "digest", "diarrhea", "stomach"],
    category: "medicine",
  },
  {
    id: "ear",
    topic: "Ear problems",
    title: "Ear problems",
    keywords: [
      "ear",
      "earache",
      "ear infection",
      "ear wax",
      "ear mite",
      "shaking head",
      "head shaking",
      "smelly ears",
    ],
    message:
      "Light dirt on the outer ear can be wiped away with a soft cloth and a pet-safe ear cleaner. Never push anything into the ear canal, and dry the ears well after baths and swimming.",
    seeVet: [
      "your pet tilts their head or loses balance",
      "there is a strong smell or discharge",
      "the ear looks red or swollen, or hurts when touched",
      "symptoms last more than a couple of days",
    ],
    searchKeywords: ["ear clean", "ear drop", "ear care", "ear mite"],
    category: "medicine",
  },
  {
    id: "eye",
    topic: "Eye problems",
    title: "Eye problems",
    keywords: [
      "eye",
      "eyelid",
      "watery eyes",
      "red eye",
      "tear stains",
      "squinting",
      "eye discharge",
      "goopy",
    ],
    message:
      "Gently wipe away crusty discharge with a clean cloth dampened in lukewarm water, using a fresh patch for each eye. Don't use human eye drops or medicines unless a vet has recommended them.",
    seeVet: [
      "your pet squints or keeps an eye shut",
      "the eye looks cloudy or very red",
      "the discharge is yellow or green",
      "there is a visible injury, or your pet paws at the eye",
    ],
    searchKeywords: ["eye clean", "eye drop", "eye wash", "eye care"],
    category: "medicine",
  },
  {
    id: "dental",
    topic: "Teeth and gums",
    title: "Teeth and gums",
    keywords: [
      "teeth",
      "tooth",
      "dental",
      "bad breath",
      "gum",
      "plaque",
      "tartar",
      "toothpaste",
      "brushing teeth",
    ],
    message:
      "Brushing regularly with a pet-specific toothpaste (never human toothpaste) and offering suitable dental chews helps keep teeth and gums healthy. Start slowly and keep it positive.",
    seeVet: [
      "the breath suddenly smells much worse",
      "the gums are red, swollen or bleeding",
      "teeth look loose or broken",
      "your pet drools, drops food or paws at their mouth",
    ],
    searchKeywords: ["dental", "tooth", "teeth", "breath"],
    category: null,
  },
  {
    id: "parasites",
    topic: "Fleas and ticks",
    title: "Fleas and ticks",
    keywords: ["flea", "tick", "parasite", "lice", "infestation"],
    message:
      "Fleas and ticks are best handled with regular prevention suited to your pet's species, age and weight. Comb the coat after time outdoors, wash bedding in hot water and treat every pet in the home together. Never use a product made for another species, as some dog products are toxic to cats.",
    seeVet: [
      "you can't remove a tick cleanly",
      "your pet seems weak or has pale gums after tick exposure",
      "a puppy, kitten or small pet has a heavy infestation",
      "the skin is red and sore, or hair is falling out",
    ],
    searchKeywords: ["flea", "tick control", "tick collar", "tick spray", "tick prevent"],
    category: "medicine",
  },
  {
    id: "worming",
    topic: "Worming",
    title: "Worms",
    keywords: [
      "worm",
      "deworm",
      "dewormer",
      "tapeworm",
      "roundworm",
      "hookworm",
      "scooting",
      "pot belly",
    ],
    message:
      "Regular worming, planned with your vet around your pet's age, weight and lifestyle, keeps worms under control. Puppies and kittens need it more often. Wash your hands after handling pets and pick up droppings promptly.",
    seeVet: [
      "you can see worms in the stool or vomit",
      "the belly looks swollen while your pet loses weight",
      "your pet scoots or constantly licks their bottom",
      "a puppy or kitten has diarrhoea",
    ],
    searchKeywords: ["worm"],
    category: "medicine",
  },
  {
    id: "skin",
    topic: "Itchy skin",
    title: "Itchy skin",
    keywords: [
      "itch",
      "scratch",
      "skin",
      "rash",
      "hot spot",
      "hotspot",
      "hair loss",
      "dandruff",
      "flaky",
      "allergy",
      "allergic",
      "redness",
      "bald patch",
    ],
    message:
      "Itching often comes from dry skin, allergies or parasites. Check the coat for fleas, keep bedding clean, and bathe only with a pet-safe shampoo, since human products can irritate. Stop your pet from scratching raw patches.",
    seeVet: [
      "the skin is raw, bleeding or oozing",
      "hair is falling out in patches",
      "there is facial swelling or hives",
      "scratching or licking keeps your pet awake",
      "the skin has a bad smell",
    ],
    searchKeywords: ["skin", "itch", "medicated shampoo", "allerg"],
    category: "medicine",
  },
  {
    id: "joints",
    topic: "Joint and mobility",
    title: "Joints and mobility",
    keywords: [
      "joint",
      "arthritis",
      "limp",
      "stiff",
      "stiffness",
      "lame",
      "lameness",
      "mobility",
      "hip",
      "slow to get up",
      "cant jump",
    ],
    message:
      "Keep exercise gentle and steady, maintain a healthy weight to take pressure off the joints, and offer soft, warm bedding. Avoid slippery floors and lots of stairs. Joint supplements are sold for older pets, but have a vet check the cause first.",
    seeVet: [
      "limping lasts more than a day or two",
      "a leg is held up or won't take weight",
      "there is swelling, heat or obvious pain",
      "your pet cries out or becomes suddenly stiff",
    ],
    searchKeywords: ["joint", "glucosamine", "arthritis", "mobility"],
    category: null,
  },
  {
    id: "vaccination",
    topic: "Vaccination schedule",
    title: "Vaccinations",
    keywords: [
      "vaccine",
      "vaccination",
      "vaccinate",
      "vaccinated",
      "immunisation",
      "immunization",
      "booster",
      "shots",
      "jab",
    ],
    message:
      "Core vaccines are usually given as a series when your pet is young, followed by boosters through life. The exact schedule depends on species, age, local risks and the vaccines used, so your vet will set it for your pet. Keep the vaccination card safe and ask which boosters are due.",
    seeVet: [
      "the vaccination history is overdue or unknown",
      "you have a new puppy or kitten and need a starting schedule",
      "you're planning boarding, daycare or travel",
      "your pet is swollen, tired or vomiting after a vaccine",
    ],
    searchKeywords: [],
    category: null,
    noProductsNote:
      "Vaccines are given by a vet, so there's nothing to buy from the store. A vet consultation is the way to plan the schedule.",
  },
  {
    id: "appetite",
    topic: "Loss of appetite",
    title: "Loss of appetite",
    keywords: [
      "not eating",
      "wont eat",
      "doesnt eat",
      "dont eat",
      "refuses to eat",
      "refusing food",
      "stopped eating",
      "off food",
      "not hungry",
      "appetite",
      "eating less",
      "picky",
    ],
    message:
      "A pet that skips a meal now and then is usually fine. Try warming the food slightly, keep to a routine, reduce stress and noise at mealtimes, and check that nothing about the food has changed. Don't force-feed, and keep fresh water available.",
    seeVet: [
      "your pet hasn't eaten for a full day (about 12 hours for puppies, kittens and small pets)",
      "there is vomiting or diarrhoea as well",
      "your pet is hiding, very tired or losing weight",
      "your pet drools or paws at their mouth",
    ],
    searchKeywords: ["appetite", "vitamin", "tonic"],
    category: null,
  },
  {
    id: "anxiety",
    topic: "Anxiety and behaviour",
    title: "Anxiety and behaviour",
    keywords: [
      "anxious",
      "anxiety",
      "stress",
      "scared",
      "afraid",
      "fear",
      "barking",
      "howling",
      "aggressive",
      "aggression",
      "destructive",
      "separation",
      "fireworks",
      "thunder",
      "restless",
      "behaviour",
      "behavior",
      "biting",
    ],
    message:
      "Anxious or unsettled pets do best with a predictable routine, daily exercise and play, and a quiet safe space to retreat to. For triggers like fireworks, stay calm yourself, close windows and curtains and offer a favourite toy. Reward calm behaviour rather than scolding fear.",
    seeVet: [
      "behaviour changes suddenly",
      "your pet is aggressive in a way that's out of character",
      "your pet hurts themselves or licks constantly",
      "your pet stops eating or toileting",
      "the anxiety keeps getting worse despite routine changes",
    ],
    searchKeywords: ["calming", "anxiety", "stress relief", "chew toy"],
    category: null,
  },
  {
    id: "wounds",
    topic: "Cuts and wounds",
    title: "Cuts and wounds",
    keywords: [
      "wound",
      "cut",
      "bite",
      "scrape",
      "graze",
      "scab",
      "bleeding",
      "injury",
      "injured",
      "burn",
      "swelling",
      "lump",
      "sting",
    ],
    message:
      "For a small, shallow scrape, gently rinse with clean lukewarm water, pat dry and stop your pet licking it (a protective cone helps). Don't use human antiseptics, creams or medicines unless a vet says so, and watch the area for changes.",
    seeVet: [
      "the wound is deep, gaping or still bleeding",
      "it was a bite from another animal (they infect easily)",
      "there is swelling, heat, pus or a bad smell",
      "it isn't healing after a few days",
      "your pet is limping, dull or off their food",
    ],
    searchKeywords: ["wound", "antiseptic", "bandage", "first aid"],
    category: "medicine",
  },
];

/** Topic chips for the "I didn't understand" reply. */
export const TOPICS = INTENTS.filter((intent) => !intent.urgent).map((intent) => intent.topic);

const GREETING_PATTERN = /^(hi|hii|hello|hey|namaste|good (morning|afternoon|evening))\b/;

function keywordPattern(keyword) {
  return new RegExp(`\\b${keyword}(?:s|es|ed|ing|y)?\\b`);
}

const COMPILED = INTENTS.map((intent) => ({
  intent,
  patterns: intent.keywords.map((keyword) => ({
    pattern: keywordPattern(keyword),
    weight: keyword.split(" ").length,
  })),
}));

/** Lower-case, drop apostrophes ("can't" -> "cant"), turn everything else that isn't a letter or digit into spaces. */
export function normalizeText(text) {
  return String(text)
    .toLowerCase()
    .replace(/['’]/g, "")
    .replace(/[^a-z0-9]+/g, " ")
    .trim();
}

function scoreIntents(normalized) {
  return COMPILED.map(({ intent, patterns }) => ({
    intent,
    score: patterns.reduce((total, { pattern, weight }) => (pattern.test(normalized) ? total + weight : total), 0),
  })).filter(({ score }) => score > 0);
}

/**
 * Turns a customer message into a reply object:
 *   { kind: "emergency", message, steps }
 *   { kind: "advice", intentId, title, message, seeVet, searchKeywords, category, noProductsNote? }
 *   { kind: "greeting" | "fallback", message }
 * Emergency red flags always win and never come with product suggestions.
 */
export function getReply(input) {
  const normalized = normalizeText(input);
  const matches = scoreIntents(normalized);

  const emergency = matches.find(({ intent }) => intent.urgent);
  if (emergency) {
    return { kind: "emergency", message: emergency.intent.message, steps: emergency.intent.steps };
  }

  // Highest score wins; on a tie the intent listed first in the table does.
  const best = matches.reduce((top, match) => (!top || match.score > top.score ? match : top), null);
  if (best) {
    const { id, title, message, seeVet, searchKeywords, category, noProductsNote } = best.intent;
    return { kind: "advice", intentId: id, title, message, seeVet, searchKeywords, category, noProductsNote };
  }

  if (GREETING_PATTERN.test(normalized)) return { kind: "greeting", message: INTRO_MESSAGE };
  return { kind: "fallback", message: FALLBACK_MESSAGE };
}

/** Keeps only letters, digits and single spaces so a keyword can't break the PostgREST filter syntax. */
export function sanitizeKeyword(keyword) {
  return String(keyword)
    .toLowerCase()
    .replace(/[^a-z0-9 ]/g, "")
    .replace(/\s+/g, " ")
    .trim();
}

/** The `.or()` filter string for a products query, or "" when there is nothing to search for. */
export function buildProductFilter(keywords) {
  return [...new Set(keywords.map(sanitizeKeyword).filter(Boolean))]
    .flatMap((keyword) => [`name.ilike.%${keyword}%`, `description.ilike.%${keyword}%`])
    .join(",");
}
