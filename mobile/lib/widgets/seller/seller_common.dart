import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_error.dart' show isRpcNotDeployedError, kRpcNotDeployedError, kStaleStatusError;
import '../../core/async_utils.dart' show withTimeout;
import '../../models/models.dart';
import '../../services/supabase_service.dart';
import '../../state/my_shop_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../../utils/video_room.dart';
import '../skeletons.dart';
import '../ui_kit.dart';

/// Shared helpers and small widgets for the seller Services / Demo requests /
/// Refunds / Orders screens (the Flutter counterparts of src/components/seller/
/// {helpers,mutations,profiles,useLoader,CustomerContact,Meta,SummaryTile,
/// LoadError,Tabs,Notice}).

// ---------------------------------------------------------------------------
// Errors
// ---------------------------------------------------------------------------

/// Shown when a server function the app calls has not been deployed yet.
const kNotAvailableYet = kRpcNotDeployedError;

/// True when [error] means the called Postgres function does not exist
/// (PostgREST PGRST202 / Postgres 42883). See `core/app_error.dart`.
bool isFunctionMissing(Object error) => isRpcNotDeployedError(error);

/// Friendly, user-facing text for anything thrown by a network call. Never
/// returns raw exception text.
String describeError(Object error) {
  if (isRpcNotDeployedError(error)) return kNotAvailableYet;
  if (error is PostgrestException && error.code == '23503') {
    return "That can't be done because other records depend on it (for example an order).";
  }
  return errorText(error);
}

// ---------------------------------------------------------------------------
// Mutations
// ---------------------------------------------------------------------------

/// Shown when an update/delete matched no row: row-level security or a trigger
/// changed nothing (typically the status moved on in the meantime).
const kNothingChanged = kStaleStatusError;

/// How long a list load may take before the screen offers a Retry. A load can
/// span several sequential requests, so this is longer than one request's limit.
const _kLoadTimeout = Duration(seconds: 40);

/// Updates one row and resolves to an error message, or null on success.
///
/// [match] adds equality filters (typically the status the row must still be
/// in) so a stale screen can't overwrite a newer state. Row-level security
/// rejects rows silently, so an empty result is reported as a failure.
Future<String?> updateRow(
  String table,
  String id,
  Map<String, dynamic> patch, {
  Map<String, Object>? match,
}) async {
  try {
    var query = SupabaseService.client.from(table).update(patch).eq('id', id);
    if (match != null) query = query.match(match);
    final rows = await withTimeout(query.select('id'));
    return rows.isEmpty ? kNothingChanged : null;
  } catch (e) {
    return describeError(e);
  }
}

/// Inserts one row and resolves to an error message, or null on success.
Future<String?> insertRow(String table, Map<String, dynamic> values) async {
  try {
    await withTimeout(SupabaseService.client.from(table).insert(values));
    return null;
  } catch (e) {
    return describeError(e);
  }
}

/// Deletes one row and resolves to an error message, or null on success.
Future<String?> deleteRow(String table, String id) async {
  try {
    final rows = await withTimeout(SupabaseService.client.from(table).delete().eq('id', id).select('id'));
    return rows.isEmpty ? kNothingChanged : null;
  } catch (e) {
    return describeError(e);
  }
}

/// Calls a Postgres function and resolves to an error message, or null on
/// success. A function that has not been deployed yet reports
/// [kNotAvailableYet] instead of throwing.
Future<String?> callRpc(String name, Map<String, dynamic> params) async {
  try {
    await withTimeout(SupabaseService.client.rpc(name, params: params));
    return null;
  } catch (e) {
    return describeError(e);
  }
}

// ---------------------------------------------------------------------------
// Loading
// ---------------------------------------------------------------------------

/// Rows revealed per "Load more" tap.
const kPageSize = 20;

/// Splits [list] into consecutive chunks of at most [size] items (used to keep
/// `inFilter` URLs short).
List<List<T>> chunkList<T>(List<T> list, int size) {
  final chunks = <List<T>>[];
  for (var i = 0; i < list.length; i += size) {
    chunks.add(list.sublist(i, i + size > list.length ? list.length : i + size));
  }
  return chunks;
}

/// Pages through a query past PostgREST's row cap (1000) so lists and totals
/// are never silently truncated. Ordered by id so pages never overlap.
Future<List<Map<String, dynamic>>> fetchAllRows(
  PostgrestFilterBuilder<PostgrestList> Function() buildQuery, {
  int pageSize = 1000,
  int maxPages = 100,
}) async {
  final rows = <Map<String, dynamic>>[];
  for (var page = 0; page < maxPages; page++) {
    final from = page * pageSize;
    final batch = await buildQuery().order('id', ascending: true).range(from, from + pageSize - 1);
    rows.addAll(batch);
    if (batch.length < pageSize) break;
  }
  return rows;
}

/// One list query: loads on creation, keeps the previous data on screen when
/// a later [reload] fails (mirrors useLoader in src/components/seller).
class SellerQuery<T> extends ChangeNotifier {
  SellerQuery(this._fetch) {
    reload();
  }

  final Future<T> Function() _fetch;
  T? data;
  String? error;
  bool loading = true;
  bool _disposed = false;
  int _ticket = 0;

  Future<void> reload() async {
    final ticket = ++_ticket;
    // A retry after a failed first load shows the skeleton again.
    if (data == null && !loading) {
      loading = true;
      notifyListeners();
    }
    try {
      final result = await withTimeout(_fetch(), timeout: _kLoadTimeout);
      if (_disposed || ticket != _ticket) return;
      data = result;
      error = null;
    } catch (e) {
      if (_disposed || ticket != _ticket) return;
      error = describeError(e);
    }
    loading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// Server-side paging for long lists: the first page loads on creation and
/// [loadMore] appends the next one. When a later [reload] or page fails, what
/// is already on screen stays and the failure is reported separately.
class PagedQuery<T> extends ChangeNotifier {
  PagedQuery(this._fetchPage, {this.pageSize = 25}) {
    reload();
  }

  /// Fetches rows [from]..[to] inclusive (PostgREST `range` semantics).
  final Future<List<T>> Function(int from, int to) _fetchPage;
  final int pageSize;

  List<T> items = const [];

  /// First-page / refresh failure.
  String? error;

  /// Failure of the last "Load more".
  String? moreError;

  /// True until the first page arrives (or fails).
  bool loading = true;
  bool loadingMore = false;
  bool hasMore = false;
  bool _disposed = false;
  int _ticket = 0;

  Future<void> reload() async {
    final ticket = ++_ticket;
    if (items.isEmpty && !loading) {
      loading = true;
      notifyListeners();
    }
    try {
      final page = await withTimeout(_fetchPage(0, pageSize - 1), timeout: _kLoadTimeout);
      if (_disposed || ticket != _ticket) return;
      items = page;
      hasMore = page.length >= pageSize;
      error = null;
      moreError = null;
    } catch (e) {
      if (_disposed || ticket != _ticket) return;
      error = describeError(e);
    }
    loading = false;
    loadingMore = false;
    notifyListeners();
  }

  Future<void> loadMore() async {
    if (loading || loadingMore || !hasMore) return;
    final ticket = _ticket;
    loadingMore = true;
    moreError = null;
    notifyListeners();
    try {
      final from = items.length;
      final page = await withTimeout(_fetchPage(from, from + pageSize - 1), timeout: _kLoadTimeout);
      if (_disposed || ticket != _ticket) return;
      items = [...items, ...page];
      hasMore = page.length >= pageSize;
    } catch (e) {
      if (_disposed || ticket != _ticket) return;
      moreError = describeError(e);
    }
    loadingMore = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// Re-runs [onRefreshed] when SellerScaffold's pull-to-refresh finishes
/// re-reading the shop. Call it from a ConsumerState.build.
void listenForShopRefresh(WidgetRef ref, VoidCallback onRefreshed) {
  ref.listen<AsyncValue<Shop?>>(myShopProvider, (previous, next) {
    if ((previous?.isLoading ?? false) && !next.isLoading && !next.hasError) onRefreshed();
  });
}

/// A requester's name and phone (shop owners may see these for their own
/// requests; they come from a second `profiles` query).
class CustomerInfo {
  final String name;
  final String? phone;
  const CustomerInfo({required this.name, this.phone});
}

/// Rows plus the customers who made them. [customersError] is set when the
/// profiles lookup failed (the rows are still shown, as "Customer").
class WithCustomers<T> {
  final List<T> rows;
  final Map<String, CustomerInfo> customers;
  final String? customersError;
  const WithCustomers(this.rows, this.customers, this.customersError);
}

/// Names and phones come from a second query (there is no FK to embed);
/// row-level security only exposes the people who requested something from
/// this shop.
Future<WithCustomers<T>> attachCustomers<T>(List<T> rows, String Function(T row) customerIdOf) async {
  final ids = {for (final row in rows) customerIdOf(row)}.where((id) => id.isNotEmpty).toList();
  final customers = <String, CustomerInfo>{};
  String? failure;

  if (ids.isNotEmpty) {
    try {
      for (final chunk in chunkList(ids, 100)) {
        final data = await SupabaseService.client.from('profiles').select('id, name, phone').inFilter('id', chunk);
        for (final row in data) {
          final id = row['id'] as String?;
          if (id == null) continue;
          customers[id] = CustomerInfo(name: (row['name'] as String?) ?? '', phone: row['phone'] as String?);
        }
      }
    } catch (e) {
      failure = describeError(e);
    }
  }
  return WithCustomers<T>(rows, customers, failure);
}

// ---------------------------------------------------------------------------
// Filters
// ---------------------------------------------------------------------------

/// One filter chip. [statuses] lets a chip cover several statuses
/// ("Rejected & cancelled"); the special value 'all' matches everything.
class StatusFilter {
  final String value;
  final String label;
  final List<String>? statuses;
  const StatusFilter(this.value, this.label, {this.statuses});
}

Map<String, int> countByStatus(Iterable<String> statuses) {
  final counts = <String, int>{};
  for (final status in statuses) {
    counts[status] = (counts[status] ?? 0) + 1;
  }
  return counts;
}

/// Filter-chip options with a count each; "all" counts every row.
List<FilterOption<String>> filterOptions<T>(
  List<StatusFilter> filters,
  List<T> rows,
  String Function(T row) statusOf,
) {
  final counts = countByStatus(rows.map(statusOf));
  return [
    for (final filter in filters)
      FilterOption<String>(
        filter.value,
        filter.label,
        count: filter.value == 'all'
            ? rows.length
            : (filter.statuses ?? [filter.value]).fold<int>(0, (sum, status) => sum + (counts[status] ?? 0)),
      ),
  ];
}

/// Rows matching a chip: "all", or any of the chip's statuses.
List<T> applyStatusFilter<T>(
  List<StatusFilter> filters,
  String value,
  List<T> rows,
  String Function(T row) statusOf,
) {
  if (value == 'all') return rows;
  var statuses = <String>[value];
  for (final filter in filters) {
    if (filter.value == value) {
      statuses = filter.statuses ?? [value];
      break;
    }
  }
  return rows.where((row) => statuses.contains(statusOf(row))).toList();
}

// ---------------------------------------------------------------------------
// Formatting / validation
// ---------------------------------------------------------------------------

const _modeLabels = {'in_person': 'In person', 'video': 'Video call', 'phone': 'Phone call'};

String modeLabel(String? mode) {
  if (mode == null || mode.isEmpty) return '';
  return _modeLabels[mode] ?? titleCase(mode);
}

final _clockPattern = RegExp(r'^(\d{1,2}):(\d{2})(?::\d{2})?$');

/// "14:30" or "14:30:00" -> "2:30 PM". Anything else is shown as written: a
/// customer's demo time arrives as free text ("2:00 PM", "Morning"), which a
/// looser parser would misread (mirrors formatTime in the web helpers).
String formatTimeLabel(String? raw) {
  final text = (raw ?? '').trim();
  if (text.isEmpty) return '';
  final match = _clockPattern.firstMatch(text);
  if (match == null) return text;
  final hours = int.parse(match.group(1)!);
  final twelve = hours % 12 == 0 ? 12 : hours % 12;
  return '$twelve:${match.group(2)} ${hours >= 12 ? 'PM' : 'AM'}';
}

/// "5 Oct 2026 at 2:30 PM", dropping whichever half is missing.
String formatSlot(DateTime? date, String? time) {
  final parts = [if (date != null) formatDate(date), formatTimeLabel(time)];
  return parts.where((part) => part.isNotEmpty).join(' at ');
}

/// True for an absolute https:// URL with a host.
bool isHttpsUrl(String value) {
  final uri = Uri.tryParse(value.trim());
  return uri != null && uri.scheme == 'https' && uri.host.isNotEmpty;
}

/// 1500 -> "1500", 99.5 -> "99.5" (no trailing ".0" in a text field).
String plainNumber(num value) => value == value.roundToDouble() ? value.toStringAsFixed(0) : value.toString();

/// Parses an amount typed into a price/stock field. Blank, non-numeric,
/// infinite and negative input gives null.
double? parseAmount(String raw) {
  final value = double.tryParse(raw.trim().replaceAll(',', ''));
  if (value == null || !value.isFinite || value < 0) return null;
  return value;
}

/// Splits a comma/newline separated list of photo links.
List<String> parseUrlList(String raw) =>
    raw.split(RegExp(r'[,\n]')).map((url) => url.trim()).where((url) => url.isNotEmpty).toList();

/// Why [raw] (a list of photo links) can't be saved, or null when it is fine.
/// Only https links are accepted (phones block plain http images), at most
/// [max] of them.
String? photoUrlsError(String raw, {int max = 8}) {
  final urls = parseUrlList(raw);
  if (urls.length > max) return 'Add at most $max photo links.';
  for (final url in urls) {
    if (!isHttpsUrl(url)) return 'Photo links must start with https://';
  }
  return null;
}

/// "14:30:00" -> "14:30"; empty when [raw] isn't a clock time (e.g. "Morning").
String toTimeValue(String? raw) {
  final match = _clockPattern.firstMatch((raw ?? '').trim());
  if (match == null) return '';
  return '${match.group(1)!.padLeft(2, '0')}:${match.group(2)}';
}

/// "HH:mm" for sending a picked time to a Postgres `time` column.
String formatTimeOfDay(TimeOfDay time) =>
    '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

/// Opens [uri] in another app; tells the user when nothing could handle it.
Future<void> openExternal(
  BuildContext context,
  Uri uri, {
  LaunchMode mode = LaunchMode.externalApplication,
}) async {
  var opened = false;
  try {
    opened = await launchUrl(uri, mode: mode);
  } catch (_) {
    opened = false;
  }
  if (!opened && context.mounted) showSnack(context, "Couldn't open that.", error: true);
}

// ---------------------------------------------------------------------------
// Widgets
// ---------------------------------------------------------------------------

/// Error card with a retry button. [compact] is the slim inline variant used
/// when a background refresh failed but older data is still on screen.
class SellerLoadError extends StatelessWidget {
  final String what;
  final String message;
  final VoidCallback onRetry;
  final bool compact;

  const SellerLoadError({
    super.key,
    required this.what,
    required this.message,
    required this.onRetry,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          NoticeBox.error(message: "Couldn't refresh $what: $message"),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      );
    }
    return Semantics(
      container: true,
      liveRegion: true,
      child: CardBox(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Couldn't load $what", style: AppTheme.display(fontSize: 16)),
            const SizedBox(height: 6),
            Text(message, style: AppTheme.body(fontSize: 13.5, color: AppColors.error)),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Retry'),
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Body of a list panel driven by a [SellerQuery]: a skeleton while loading, a
/// retry card when the first load failed, otherwise [builder] (with an inline
/// retry when only a background refresh failed).
class SellerQueryPanel<T> extends StatelessWidget {
  final SellerQuery<T> query;
  final String what;
  final Widget Function(BuildContext context, T data) builder;

  /// Shown while the first load runs; a list of cards when omitted.
  final Widget? skeleton;

  const SellerQueryPanel({
    super.key,
    required this.query,
    required this.what,
    required this.builder,
    this.skeleton,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: query,
      builder: (context, _) {
        final data = query.data;
        if (data == null) {
          if (query.loading) return skeleton ?? const ListSkeleton(count: 3);
          return SellerLoadError(
            what: what,
            message: query.error ?? 'Something went wrong.',
            onRetry: query.reload,
          );
        }
        final refreshError = query.error;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (refreshError != null) ...[
              SellerLoadError(what: what, message: refreshError, onRetry: query.reload, compact: true),
              const SizedBox(height: 12),
            ],
            builder(context, data),
          ],
        );
      },
    );
  }
}

/// Body of a list panel driven by a [PagedQuery]: a skeleton for the first
/// load, a retry card when it failed, otherwise [builder] followed by a
/// "Load more" footer.
class PagedQueryPanel<T> extends StatelessWidget {
  final PagedQuery<T> query;
  final String what;
  final Widget Function(BuildContext context, List<T> items) builder;

  const PagedQueryPanel({super.key, required this.query, required this.what, required this.builder});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: query,
      builder: (context, _) {
        if (query.loading && query.items.isEmpty) return const ListSkeleton(count: 3);
        final error = query.error;
        if (error != null && query.items.isEmpty) {
          return SellerLoadError(what: what, message: error, onRetry: query.reload);
        }
        final moreError = query.moreError;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (error != null) ...[
              SellerLoadError(what: what, message: error, onRetry: query.reload, compact: true),
              const SizedBox(height: 12),
            ],
            builder(context, query.items),
            if (moreError != null) ...[
              const SizedBox(height: 4),
              NoticeBox.error(message: "Couldn't load more: $moreError"),
            ],
            if (query.hasMore || moreError != null)
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 8),
                child: Column(
                  children: [
                    Text(
                      'Showing ${query.items.length}',
                      style: AppTheme.body(fontSize: 13, color: AppColors.inkSoft),
                    ),
                    const SizedBox(height: 8),
                    LoadingButton(
                      label: 'Load more',
                      outlined: true,
                      loading: query.loadingMore,
                      onPressed: query.loadMore,
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Footer for lists that reveal [kPageSize] rows at a time: "Showing 20 of 57"
/// and a "Load more" button. Renders nothing once everything is shown.
class LoadMoreButton extends StatelessWidget {
  final int shown;
  final int total;
  final VoidCallback onPressed;

  const LoadMoreButton({super.key, required this.shown, required this.total, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    if (shown >= total) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      child: Column(
        children: [
          Text('Showing $shown of $total', style: AppTheme.body(fontSize: 13, color: AppColors.inkSoft)),
          const SizedBox(height: 8),
          OutlinedButton(onPressed: onPressed, child: const Text('Load more')),
        ],
      ),
    );
  }
}

/// Label + big number tile ("Pending 3").
class SellerSummaryTile extends StatelessWidget {
  final String label;
  final String value;
  const SellerSummaryTile({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: '$label: $value',
      excludeSemantics: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: AppTheme.body(fontSize: 13, color: AppColors.inkSoft)),
            const SizedBox(height: 4),
            // Long figures ("₹12,45,000") shrink instead of wrapping on narrow
            // screens or large text sizes.
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value, style: AppTheme.display(fontSize: 22)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Label/value line for card details; [child] overrides [text].
class SellerMetaRow extends StatelessWidget {
  final String label;
  final String? text;
  final Widget? child;
  const SellerMetaRow(this.label, {super.key, this.text, this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 108, child: Text(label, style: AppTheme.body(fontSize: 13, color: AppColors.inkSoft))),
          Expanded(child: child ?? Text(text ?? '', style: AppTheme.body(fontSize: 14))),
        ],
      ),
    );
  }
}

/// Soft grey block for a quoted message or note ("Customer note: ...").
class SellerNoteBox extends StatelessWidget {
  final String label;
  final String text;
  const SellerNoteBox({super.key, required this.label, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text.rich(
        TextSpan(
          style: AppTheme.body(fontSize: 14),
          children: [
            TextSpan(text: '$label: ', style: AppTheme.body(fontSize: 14, color: AppColors.inkSoft)),
            TextSpan(text: text),
          ],
        ),
      ),
    );
  }
}

/// Person icon + name, with the phone number as a tap-to-call link.
class SellerCustomerContact extends StatelessWidget {
  final CustomerInfo? customer;
  const SellerCustomerContact({super.key, required this.customer});

  @override
  Widget build(BuildContext context) {
    final name = (customer?.name ?? '').trim();
    final phone = (customer?.phone ?? '').trim();
    void call() => openExternal(
          context,
          Uri(scheme: 'tel', path: phone.replaceAll(RegExp(r'[^\d+]'), '')),
          mode: LaunchMode.platformDefault,
        );
    return Wrap(
      spacing: 14,
      runSpacing: 0,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.person_outline, size: 16, color: AppColors.inkSoft),
            const SizedBox(width: 6),
            Flexible(child: Text(name.isEmpty ? 'Customer' : name, style: AppTheme.body(fontSize: 14))),
          ],
        ),
        if (phone.isNotEmpty)
          Semantics(
            button: true,
            label: 'Call $phone',
            onTap: call,
            excludeSemantics: true,
            child: InkWell(
              onTap: call,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.phone_outlined, size: 16, color: AppColors.primary),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(phone, style: AppTheme.body(fontSize: 14, color: AppColors.primary)),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// A saved video-call link with an "Open" button. Only web links are opened;
/// anything else stored in the column stays plain text.
class SellerVideoLink extends StatelessWidget {
  final String url;
  const SellerVideoLink(this.url, {super.key});

  @override
  Widget build(BuildContext context) {
    final text = url.trim();
    final uri = isSafeWebLink(text) ? Uri.tryParse(text) : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          text,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AppTheme.body(fontSize: 13.5, color: AppColors.primary),
        ),
        const SizedBox(height: 6),
        Tooltip(
          message: 'Open video call link',
          child: OutlinedButton.icon(
            onPressed: uri == null ? null : () => openExternal(context, uri),
            icon: const Icon(Icons.open_in_new, size: 18),
            label: const Text('Open'),
          ),
        ),
      ],
    );
  }
}

/// Read-only field that opens a date/time picker when tapped.
class SellerPickerField extends StatelessWidget {
  final String label;
  final String? value;
  final IconData icon;
  final VoidCallback? onTap;
  final String? errorText;

  const SellerPickerField({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
    this.errorText,
  });

  @override
  Widget build(BuildContext context) {
    final text = value ?? '';
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: text.isEmpty ? label : '$label, $text',
      onTap: onTap,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: InputDecorator(
          isEmpty: text.isEmpty,
          decoration: InputDecoration(
            labelText: label,
            errorText: errorText,
            suffixIcon: Icon(icon, size: 20),
          ),
          child: Text(text, style: AppTheme.body()),
        ),
      ),
    );
  }
}

/// A tab in [SellerTabBar]. [attention] tabs highlight their badge while the
/// count is above zero.
class SellerTab {
  final String value;
  final String label;
  final int? count;
  final bool attention;
  const SellerTab(this.value, this.label, {this.count, this.attention = false});
}

/// Underlined tab strip with count badges (the web Tabs component). The body
/// is switched by the caller, so the page stays one non-scrolling column.
class SellerTabBar extends StatelessWidget {
  final List<SellerTab> tabs;
  final String selected;
  final ValueChanged<String> onSelected;

  const SellerTabBar({super.key, required this.tabs, required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final tab in tabs)
              _TabButton(tab: tab, active: tab.value == selected, onTap: () => onSelected(tab.value)),
          ],
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  final SellerTab tab;
  final bool active;
  final VoidCallback onTap;

  const _TabButton({required this.tab, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final highlighted = tab.attention && (tab.count ?? 0) > 0;
    final count = tab.count;
    return Semantics(
      button: true,
      selected: active,
      label: count == null ? tab.label : '${tab.label}, $count',
      onTap: onTap,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: active ? AppColors.primary : Colors.transparent, width: 2),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  tab.label,
                  style: AppTheme.body(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: active ? AppColors.primary : AppColors.inkSoft,
                  ),
                ),
                if (count != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: highlighted ? AppColors.accent : AppColors.ink.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '$count',
                      style: AppTheme.body(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: highlighted ? Colors.white : AppColors.inkSoft,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
