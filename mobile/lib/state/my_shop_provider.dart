import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../repositories/repositories.dart';
import 'auth_provider.dart';

/// The signed-in shop owner's own shop row, or null if they haven't created
/// one yet. Mirrors src/hooks/useMyShop.js. Refresh with
/// `ref.invalidate(myShopProvider)`.
final myShopProvider = FutureProvider.autoDispose<Shop?>((ref) async {
  final auth = ref.watch(authControllerProvider);
  final profile = auth.profile;
  if (profile == null) return null;
  return ShopsRepository().getByOwnerId(profile.id);
});
