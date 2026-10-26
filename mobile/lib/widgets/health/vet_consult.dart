import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/service_models.dart';
import '../../state/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../services/booking_sheet.dart';
import '../services/bookings_list.dart';
import '../services/service_support.dart';
import '../skeletons.dart';
import '../ui_kit.dart';

const _flow = <({String title, String text})>[
  (title: 'Book a slot', text: 'Pick a vet, a date and a time that suits you.'),
  (title: 'Clinic confirms', text: 'The clinic confirms your slot and adds a video link to your booking.'),
  (title: 'Join from here', text: 'At your slot time, open My consultations below and tap Join video consult.'),
];

/// The vet teleconsultation flow (mirrors src/components/health/VetConsult.jsx):
/// how it works, bookable vets, and the customer's own consultations.
///
/// Returns non-scrolling content -- place it inside a scroll view. The parent
/// can pull-to-refresh through a `GlobalKey<VetConsultState>` and jump to the
/// customer's consultations with [VetConsultState.scrollToConsultations].
class VetConsult extends ConsumerStatefulWidget {
  const VetConsult({super.key});

  @override
  ConsumerState<VetConsult> createState() => VetConsultState();
}

class VetConsultState extends ConsumerState<VetConsult> {
  final _consultationsKey = GlobalKey<ConsultationsSectionState>();
  final _consultationsAnchor = GlobalKey();

  List<ServiceItem> _services = const [];
  bool _loading = true;
  String? _error;

  // A scroll request made before the consultations section exists (the account
  // is still loading) waits here and is retried after each build.
  bool _scrollPending = false;

  @override
  void initState() {
    super.initState();
    _loadServices();
  }

  /// Loads the vets. The current list stays on screen while it reloads, so a
  /// failed refresh shows a notice above the stale rows instead of blanking them.
  Future<void> _loadServices() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final services = await fetchApprovedServices(category: 'vet');
      if (!mounted) return;
      setState(() {
        _services = services;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = errorText(error);
        _loading = false;
      });
    }
  }

  /// Reloads the vets and the customer's consultations.
  Future<void> refresh() async {
    final consultations = _consultationsKey.currentState?.reload();
    await _loadServices();
    if (consultations != null) await consultations;
  }

  /// Scrolls the enclosing scroll view to "My consultations".
  void scrollToConsultations() {
    _scrollPending = true;
    _scheduleScroll();
  }

  void _scheduleScroll() {
    WidgetsBinding.instance.addPostFrameCallback((_) => _flushScroll());
  }

  void _flushScroll() {
    if (!_scrollPending || !mounted) return;
    final anchor = _consultationsAnchor.currentContext;
    if (anchor == null) return; // not built yet; retried after the next build
    _scrollPending = false;
    scrollIntoView(anchor);
  }

  Future<void> _book(ServiceItem service) async {
    final viewMine = await showBookingSheet(
      context,
      service: service,
      consult: true,
      onBooked: () => _consultationsKey.currentState?.reload(),
    );
    if (viewMine == true && mounted) scrollToConsultations();
  }

  @override
  Widget build(BuildContext context) {
    final access = ServiceAccess.from(ref.watch(authControllerProvider));
    // Sellers and admins don't book consultations, so they don't get the list.
    final showMine = !access.loading && (!access.signedIn || access.canBook);
    final userId = access.userId;

    if (_scrollPending) {
      if (!access.loading && !showMine) {
        _scrollPending = false;
      } else {
        _scheduleScroll();
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeading(
          icon: Icons.medical_services_outlined,
          title: 'Vet teleconsultation',
          description: 'Book a slot with a vet and meet over video, phone or in person.',
        ),
        const SizedBox(height: 16),
        for (var i = 0; i < _flow.length; i++) ...[
          _FlowStep(number: i + 1, title: _flow[i].title, text: _flow[i].text),
          const SizedBox(height: 10),
        ],
        Text(
          "Video links are provided by the clinic. PETSTA doesn't host the calls itself.",
          style: AppTheme.body(fontSize: 12, color: AppColors.inkSoft),
        ),
        const SizedBox(height: 4),
        Text(videoExpectationText, style: AppTheme.body(fontSize: 12, color: AppColors.inkSoft)),
        const SizedBox(height: 20),
        _buildVets(),
        if (showMine) ...[
          const SizedBox(height: 32),
          Column(
            key: _consultationsAnchor,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: Text('My consultations', style: AppTheme.display(fontSize: 20)),
              ),
              const SizedBox(height: 14),
              if (userId != null && access.canBook)
                ConsultationsSection(key: _consultationsKey, userId: userId)
              else
                const LoginPromptCard(
                  compact: true,
                  title: 'Log in to continue',
                  description: 'Log in to see your consultations and join video calls.',
                ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildVets() {
    final error = _error;
    if (_loading && _services.isEmpty) {
      return const ListSkeleton(count: 2, itemHeight: 130);
    }
    if (error != null && _services.isEmpty) {
      return InlineErrorNotice(message: "Couldn't load vets: $error", onRetry: _loadServices);
    }
    if (_services.isEmpty) {
      return CardBox(
        child: Column(
          children: [
            Text(
              'No vet consultations yet',
              textAlign: TextAlign.center,
              style: AppTheme.display(fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              'No vet has listed a teleconsultation so far. Send a custom request and nearby vets can reply with a quote.',
              textAlign: TextAlign.center,
              style: AppTheme.body(color: AppColors.inkSoft),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.push('/services#custom'),
              child: const Text('Request a custom service'),
            ),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (error != null) ...[
          InlineErrorNotice(message: "Couldn't refresh vets: $error", onRetry: _loadServices),
          const SizedBox(height: 12),
        ],
        for (final service in _services) ...[
          _VetRow(service: service, onBook: () => _book(service)),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

/// The customer's own vet consultations (service_bookings with category 'vet').
/// Owns its data controller; reload it through a `GlobalKey<ConsultationsSectionState>`.
class ConsultationsSection extends StatefulWidget {
  final String userId;

  const ConsultationsSection({super.key, required this.userId});

  @override
  State<ConsultationsSection> createState() => ConsultationsSectionState();
}

class ConsultationsSectionState extends State<ConsultationsSection> {
  late ServiceBookingsController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ServiceBookingsController(userId: widget.userId, category: 'vet');
  }

  @override
  void didUpdateWidget(covariant ConsultationsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) {
      _controller.dispose();
      _controller = ServiceBookingsController(userId: widget.userId, category: 'vet');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> reload() => _controller.load(silent: true);

  @override
  Widget build(BuildContext context) {
    return BookingsList(
      controller: _controller,
      emptyMessage: 'No consultations yet. Book a vet above to get started.',
    );
  }
}

class _SectionHeading extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _SectionHeading({required this.icon, required this.title, required this.description});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ExcludeSemantics(
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 22, color: Colors.white),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: Text(title, style: AppTheme.display(fontSize: 20)),
              ),
              const SizedBox(height: 2),
              Text(description, style: AppTheme.body(fontSize: 13.5, color: AppColors.inkSoft)),
            ],
          ),
        ),
      ],
    );
  }
}

class _FlowStep extends StatelessWidget {
  final int number;
  final String title;
  final String text;

  const _FlowStep({required this.number, required this.title, required this.text});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: 'Step $number: $title. $text',
      excludeSemantics: true,
      child: CardBox(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
              child: Text(
                '$number',
                style: AppTheme.body(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTheme.body(fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(text, style: AppTheme.body(fontSize: 13.5, color: AppColors.inkSoft)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VetRow extends StatelessWidget {
  final ServiceItem service;
  final VoidCallback onBook;

  const _VetRow({required this.service, required this.onBook});

  @override
  Widget build(BuildContext context) {
    final duration = formatDuration(service.durationMinutes);
    final shopName = service.shopName?.trim() ?? '';
    final description = service.description?.trim() ?? '';

    return CardBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ExcludeSemantics(
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.medical_services_outlined, size: 22, color: AppColors.primary),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (shopName.isNotEmpty)
                      Text(
                        shopName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.body(fontSize: 13, color: AppColors.inkSoft),
                      ),
                    Text(service.name, style: AppTheme.body(fontSize: 15, fontWeight: FontWeight.w600)),
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        description,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.body(fontSize: 13.5, color: AppColors.inkSoft),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                formatPrice(service.price),
                style: AppTheme.display(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.accent),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Wrap (not Row) so the duration and button stack at 320dp / large text.
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              if (duration.isNotEmpty)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.schedule, size: 14, color: AppColors.inkSoft),
                    const SizedBox(width: 4),
                    Text(duration, style: AppTheme.body(fontSize: 12, color: AppColors.inkSoft)),
                  ],
                ),
              Semantics(
                button: true,
                label: 'Book video consult with ${shopName.isEmpty ? service.name : shopName}',
                excludeSemantics: true,
                onTap: onBook,
                child: ElevatedButton.icon(
                  onPressed: onBook,
                  icon: const Icon(Icons.videocam_outlined, size: 18),
                  label: const Text('Book video consult'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
