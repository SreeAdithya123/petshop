import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/async_utils.dart';
import '../models/models.dart';
import '../repositories/repositories.dart';
import 'auth_provider.dart';

/// The signed-in shop owner's own shop row, or null if they haven't created
/// one yet. Mirrors src/hooks/useMyShop.js. Refresh with
/// `ref.invalidate(myShopProvider)`.
///
/// Only the profile id is watched, so a profile refresh doesn't refetch the
/// shop. Retries are off (the default exponential backoff would hide the error
/// state for ~40s); a request that hangs fails with a timeout and screens show
/// their own Retry.
final myShopProvider = FutureProvider.autoDispose<Shop?>(retry: (retryCount, error) => null, (ref) async {
  final ownerId = ref.watch(authControllerProvider.select((auth) => auth.profile?.id));
  if (ownerId == null) return null;
  return withTimeout(ShopsRepository().getByOwnerId(ownerId));
});
