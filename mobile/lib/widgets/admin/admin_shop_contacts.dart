import 'package:flutter/foundation.dart';

import '../../core/async_utils.dart';
import '../../repositories/shop_contact_repository.dart';
import '../seller/seller_common.dart' show chunkList, describeError;

/// Loads shop contact details (street address + phone) for the admin Shops
/// list, only for the shops currently on screen, and only through
/// [ShopContactRepository.fetchMany] (admins may read them; customer screens
/// never do).
///
/// A failed lookup is remembered per shop so the list does not retry in a loop;
/// the card shows a Retry button that calls [retry].
class ShopContactsLoader extends ChangeNotifier {
  static const _chunkSize = 50;

  final Map<String, ShopContact> _contacts = {};
  final Set<String> _loading = {};
  final Set<String> _failed = {};
  bool _disposed = false;

  /// Friendly text of the most recent failure.
  String? error;

  ShopContact? contactFor(String shopId) => _contacts[shopId];

  bool isLoading(String shopId) => _loading.contains(shopId);

  bool hasFailed(String shopId) => _failed.contains(shopId);

  /// Fetches the contact details of every id in [shopIds] that is not loaded,
  /// loading or failed yet. Safe to call on every rebuild (from a post-frame
  /// callback).
  Future<void> ensure(Iterable<String> shopIds) async {
    if (_disposed) return;
    final wanted = <String>[
      for (final id in shopIds)
        if (id.isNotEmpty && !_contacts.containsKey(id) && !_loading.contains(id) && !_failed.contains(id)) id,
    ];
    if (wanted.isEmpty) return;

    _loading.addAll(wanted);
    notifyListeners();

    final repository = ShopContactRepository();
    for (final chunk in chunkList(wanted, _chunkSize)) {
      try {
        final found = await withTimeout(repository.fetchMany(chunk));
        if (_disposed) return;
        for (final id in chunk) {
          // A shop the query returned nothing for simply has no contact on file.
          _contacts[id] = found[id] ?? ShopContact(shopId: id, address: '', phone: '');
        }
        _failed.removeAll(chunk);
      } catch (e) {
        if (_disposed) return;
        _failed.addAll(chunk);
        error = describeError(e);
      }
      _loading.removeAll(chunk);
      notifyListeners();
    }
  }

  /// Forgets what was loaded or failed (after a pull-to-refresh) so the next
  /// [ensure] fetches fresh details. Does not notify: callers rebuild anyway.
  void reset() {
    _contacts.clear();
    _failed.clear();
  }

  /// Tries again for one shop whose contact details failed to load.
  Future<void> retry(String shopId) {
    _failed.remove(shopId);
    return ensure([shopId]);
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
