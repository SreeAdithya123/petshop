import 'package:flutter_test/flutter_test.dart';
import 'package:pawsnearby/widgets/health/pharmacy_intents.dart';

void main() {
  group('normalizeQuery', () {
    test('lowercases, drops apostrophes and collapses punctuation', () {
      expect(normalizeQuery("Can't BREATHE!!"), 'cant breathe');
      expect(normalizeQuery('  Tick & flea,   prevention?  '), 'tick flea prevention');
      expect(normalizeQuery(''), '');
      expect(normalizeQuery('???'), '');
    });
  });

  group('looksLikeEmergency', () {
    const emergencies = [
      'my dog ate chocolate',
      'she is having a seizure',
      'he has fits',
      'my cat collapsed',
      "he can't breathe",
      'blue gums',
      'bloated hard belly',
      "my cat can't pee",
      'straining but no urine',
      'heatstroke',
      'hit by a car',
      'heavy bleeding',
      'swallowed a sock',
      'eclampsia',
      'rat poison',
      'xylitol',
      'grapes',
      'antifreeze',
    ];
    for (final text in emergencies) {
      test('flags: $text', () => expect(looksLikeEmergency(text), isTrue));
    }

    const calm = [
      'my dog has an upset stomach',
      'chocolate labrador itchy skin',
      'non-toxic shampoo',
      'the collar fits',
      'tick and flea prevention',
      'vaccination schedule',
      'pet is not eating',
      '',
    ];
    for (final text in calm) {
      test('does not flag: "$text"', () => expect(looksLikeEmergency(text), isFalse));
    }
  });

  group('matchIntent', () {
    test('an emergency wins and carries no product keywords', () {
      final match = matchIntent('my puppy ate chocolate and is itchy');
      expect(match.isEmergency, isTrue);
      expect(match.intent, isNotNull);
      expect(match.intent!.searchKeywords, isEmpty);
    });

    test('everyday questions route to a topic, not an emergency', () {
      final match = matchIntent('My dog has an upset stomach');
      expect(match.isEmergency, isFalse);
      expect(match.intent, isNotNull);
      expect(match.intent!.urgent, isFalse);
    });

    test('empty and gibberish input match nothing', () {
      expect(matchIntent('').intent, isNull);
      expect(matchIntent('   ').intent, isNull);
      expect(matchIntent('qwertyuiop zxcvbnm').intent, isNull);
    });

    test('every quick reply finds an answer', () {
      for (final reply in pharmacyQuickReplies) {
        final match = matchIntent(reply);
        expect(match.intent, isNotNull, reason: reply);
        expect(match.isEmergency, isFalse, reason: reply);
      }
    });

    test('every topic chip routes to its own intent', () {
      for (final intent in pharmacyIntents.where((i) => !i.urgent && i.topic != null)) {
        expect(matchIntent(intent.topic!).intent?.id, intent.id, reason: intent.topic);
      }
    });
  });

  group('knowledge table safety', () {
    test('every topic tells the owner when to see a vet', () {
      for (final intent in pharmacyIntents) {
        expect(intent.seeVet, isNotEmpty, reason: intent.id);
        expect(intent.message.trim(), isNotEmpty, reason: intent.id);
      }
    });

    test('ids are unique', () {
      final ids = pharmacyIntents.map((i) => i.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('no message gives a dose', () {
      final dose = RegExp(r'\b\d+(?:\.\d+)?\s?(?:mg|mcg|ml|iu)\b', caseSensitive: false);
      for (final intent in [...pharmacyIntents, emergencyIntent]) {
        final text = [intent.message, ...intent.steps, ...intent.seeVet].join(' ');
        expect(dose.hasMatch(text), isFalse, reason: intent.id);
      }
    });

    test('search keywords are safe for a PostgREST filter', () {
      final safe = RegExp(r'^[a-z0-9 ]+$');
      for (final intent in pharmacyIntents) {
        for (final keyword in intent.searchKeywords) {
          expect(safe.hasMatch(keyword), isTrue, reason: '${intent.id}: $keyword');
        }
      }
    });
  });

  group('product filter helpers', () {
    test('sanitizeKeyword strips filter syntax', () {
      expect(sanitizeKeyword('Flea, Tick (shampoo)%'), 'flea tick shampoo');
      expect(sanitizeKeyword('a.b,c'), 'abc');
      expect(sanitizeKeyword('%%'), '');
    });

    test('buildProductFilter builds an or() list and dedupes', () {
      expect(buildProductFilter(['flea', 'Flea', 'tick']),
          'name.ilike.%flea%,description.ilike.%flea%,name.ilike.%tick%,description.ilike.%tick%');
      expect(buildProductFilter([]), '');
      expect(buildProductFilter(['%%']), '');
    });
  });

  group('greetings', () {
    test('isGreeting', () {
      expect(isGreeting('Hi'), isTrue);
      expect(isGreeting('hello there'), isTrue);
      expect(isGreeting('Good morning!'), isTrue);
      expect(isGreeting('my dog is sick'), isFalse);
    });
  });
}
