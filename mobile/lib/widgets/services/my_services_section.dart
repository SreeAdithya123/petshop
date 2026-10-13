import 'package:flutter/material.dart';

import '../ui_kit.dart';
import 'bookings_list.dart';
import 'requests_list.dart';

enum MyServicesTab { bookings, requests }

/// "My bookings & requests" body for signed-in customers (mirrors the lists in
/// MyServicesSection.jsx): a chip row switching between the customer's service
/// bookings and their custom service requests. Owns both data controllers; the
/// parent screen reaches them through a `GlobalKey<MyServicesSectionState>`.
class MyServicesSection extends StatefulWidget {
  final String userId;

  const MyServicesSection({super.key, required this.userId});

  @override
  State<MyServicesSection> createState() => MyServicesSectionState();
}

class MyServicesSectionState extends State<MyServicesSection> {
  late ServiceBookingsController _bookings;
  late CustomRequestsController _requests;
  MyServicesTab _tab = MyServicesTab.bookings;

  @override
  void initState() {
    super.initState();
    _createControllers();
  }

  void _createControllers() {
    _bookings = ServiceBookingsController(userId: widget.userId);
    _requests = CustomRequestsController(userId: widget.userId);
  }

  @override
  void didUpdateWidget(covariant MyServicesSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) {
      _bookings.dispose();
      _requests.dispose();
      _createControllers();
    }
  }

  @override
  void dispose() {
    _bookings.dispose();
    _requests.dispose();
    super.dispose();
  }

  Future<void> reloadBookings() => _bookings.load(silent: true);

  Future<void> reloadRequests() => _requests.load(silent: true);

  Future<void> reloadAll() async {
    final bookings = reloadBookings();
    final requests = reloadRequests();
    await bookings;
    await requests;
  }

  void showTab(MyServicesTab tab) {
    if (mounted) setState(() => _tab = tab);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([_bookings, _requests]),
      builder: (context, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FilterChipBar<MyServicesTab>(
              options: [
                FilterOption(
                  MyServicesTab.bookings,
                  'Bookings',
                  count: _bookings.loading ? null : _bookings.bookings.length,
                ),
                FilterOption(
                  MyServicesTab.requests,
                  'Custom requests',
                  count: _requests.loading ? null : _requests.requests.length,
                ),
              ],
              selected: _tab,
              onSelected: (tab) => setState(() => _tab = tab),
            ),
            const SizedBox(height: 14),
            if (_tab == MyServicesTab.bookings)
              BookingsList(
                controller: _bookings,
                emptyMessage: 'No bookings yet — pick a service above to book your first slot.',
              )
            else
              RequestsList(
                controller: _requests,
                emptyMessage: 'No custom requests yet — describe what you need and shops will quote.',
              ),
          ],
        );
      },
    );
  }
}
