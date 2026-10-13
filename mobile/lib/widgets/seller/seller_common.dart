import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/models.dart';
import '../../services/supabase_service.dart';
import '../../state/my_shop_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../shared_widgets.dart';
import '../ui_kit.dart';

/// Shared helpers and small widgets for the seller Services / Demo requests /
/// Refunds screens (the Flutter counterparts of src/components/seller/
/// {helpers,mutations,profiles,useLoader,CustomerContact,Meta,SummaryTile,
/// LoadError,Tabs,Notice}).

// ---------------------------------------------------------------------------
// Mutations
// ---------------------------------------------------------------------------

/// Shown when an update/delete matched no row: row-level security or a trigger
/// changed nothing (typically the status moved on in the meantime).
const kNothingChanged = "That didn't go through — its status may have changed.";

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
    final rows = await query.select('id');
    return rows.isEmpty ? kNothingChanged : null;
  } catch (e) {
    return errorText(e);
  }
}

/// Deletes one row and resolves to an error message, or null on success.
Future<String?> deleteRow(String table, String id) async {
  try {
    final rows = await SupabaseService.client.from(table).delete().eq('id', id).select('id');
    return rows.isEmpty ? kNothingChanged : null;
  } catch (e) {
    return errorText(e);
  }
}

// ---------------------------------------------------------------------------
// Loading
// ---------------------------------------------------------------------------

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
    // A retry after a failed first load shows the spinner again.
    if (data == null && !loading) {
      loading = true;
      notifyListeners();
    }
    try {
      final result = await _fetch();
      if (_disposed || ticket != _ticket) return;
      data = result;
      error = null;
    } catch (e) {
      if (_disposed || ticket != _ticket) return;
      error = errorText(e);
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
      final data = await SupabaseService.client.from('profiles').select('id, name, phone').inFilter('id', ids);
      for (final row in data) {
        final id = row['id'] as String?;
        if (id == null) continue;
        customers[id] = CustomerInfo(name: (row['name'] as String?) ?? '', phone: row['phone'] as String?);
      }
    } catch (e) {
      failure = errorText(e);
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
    return CardBox(
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
            label: const Text('Try again'),
          ),
        ],
      ),
    );
  }
}

/// Body of a list panel driven by a [SellerQuery]: loading text, a retry card
/// when the first load failed, otherwise [builder] (with an inline retry when
/// only a background refresh failed).
class SellerQueryPanel<T> extends StatelessWidget {
  final SellerQuery<T> query;
  final String what;
  final Widget Function(BuildContext context, T data) builder;

  const SellerQueryPanel({super.key, required this.query, required this.what, required this.builder});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: query,
      builder: (context, _) {
        final data = query.data;
        if (data == null) {
          if (query.loading) return LoadingView(label: 'Loading $what…');
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

/// Label + big number tile ("Pending 3").
class SellerSummaryTile extends StatelessWidget {
  final String label;
  final String value;
  const SellerSummaryTile({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
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
          Text(value, style: AppTheme.display(fontSize: 22)),
        ],
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
    return Wrap(
      spacing: 14,
      runSpacing: 4,
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
          InkWell(
            onTap: () => openExternal(
              context,
              Uri(scheme: 'tel', path: phone.replaceAll(RegExp(r'[^\d+]'), '')),
              mode: LaunchMode.platformDefault,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.phone_outlined, size: 16, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Text(phone, style: AppTheme.body(fontSize: 14, color: AppColors.primary)),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// A tappable https link shown as text.
class SellerLinkText extends StatelessWidget {
  final String url;
  const SellerLinkText(this.url, {super.key});

  @override
  Widget build(BuildContext context) {
    final parsed = Uri.tryParse(url.trim());
    // Only web links are opened; anything else stored in the column stays plain text.
    final uri = (parsed != null && (parsed.scheme == 'https' || parsed.scheme == 'http')) ? parsed : null;
    return InkWell(
      onTap: uri == null ? null : () => openExternal(context, uri),
      child: Text(
        url,
        style: AppTheme.body(fontSize: 14, color: AppColors.primary).copyWith(decoration: TextDecoration.underline),
      ),
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
    return InkWell(
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
    return Semantics(
      button: true,
      selected: active,
      child: InkWell(
        onTap: onTap,
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
              if (tab.count != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: highlighted ? AppColors.accent : AppColors.ink.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${tab.count}',
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
    );
  }
}
