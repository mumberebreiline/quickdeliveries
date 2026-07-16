import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../app/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/order_provider.dart';
import '../../providers/location_provider.dart';
import '../../providers/route_savings_provider.dart';
import '../../services/route_optimizer_service.dart';

/// The Home tab of the vendor shell — leads with the route itself
/// (a live journey timeline) instead of a menu of destinations.
class DashboardHomeTab extends StatelessWidget {
  final void Function(int tabIndex) onNavigateToTab;

  const DashboardHomeTab({super.key, required this.onNavigateToTab});

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final orderProvider = context.watch<OrderProvider>();
    final locationProvider = context.watch<LocationProvider>();
    final routeSavings = context.watch<RouteSavingsProvider>();
    final auth = context.watch<AuthProvider>();

    final name = (auth.user?.displayName?.isNotEmpty ?? false)
        ? auth.user!.displayName!
        : (auth.user?.email?.split('@').first ?? 'Vendor');

    final plan = orderProvider.buildRoutePlan(locationProvider.currentLocation);
    final stops = plan.flatStops;

    return Container(
      color: const Color(0xFFF3F6F1),
      child: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: _ShiftHeader(
                greeting: _greeting(),
                name: name,
                isTracking: locationProvider.isTracking,
                onToggleShift: () {
                  if (locationProvider.isTracking) {
                    locationProvider.stopTracking();
                  } else {
                    routeSavings.resetForNewShift();
                    locationProvider.startTracking();
                  }
                },
                onLogout: () => auth.signOut(),
              ),
            ),
            SliverToBoxAdapter(
              child: _StatRow(
                stopCount: plan.totalStops,
                distanceLeftKm: plan.totalDistanceKm,
                minutesSaved: routeSavings.totalMinutesSaved,
              ),
            ),
            if (stops.isEmpty)
              const SliverToBoxAdapter(child: _EmptyRouteNotice())
            else
              SliverToBoxAdapter(
                child: _JourneyTimeline(
                  vendorLocationName: locationProvider.currentLocation.name,
                  stops: stops.take(4).toList(),
                  nextStopTrafficDelay: routeSavings.lastCheckedOption?.trafficDelayMinutes,
                ),
              ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              sliver: SliverToBoxAdapter(
                child: Row(
                  children: [
                    Expanded(
                      child: _QuickAction(
                        icon: Icons.inbox_outlined,
                        label: 'Incoming orders',
                        badge: orderProvider.activeOrders.isNotEmpty
                            ? '${orderProvider.activeOrders.length}'
                            : null,
                        onTap: () => onNavigateToTab(1),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _QuickAction(
                        icon: Icons.history_outlined,
                        label: 'History',
                        onTap: () => onNavigateToTab(3),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShiftHeader extends StatelessWidget {
  final String greeting;
  final String name;
  final bool isTracking;
  final VoidCallback onToggleShift;
  final VoidCallback onLogout;

  const _ShiftHeader({
    required this.greeting,
    required this.name,
    required this.isTracking,
    required this.onToggleShift,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    const weekdays = ['Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday'];
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    final dateLabel = '${weekdays[today.weekday - 1]}, ${months[today.month - 1]} ${today.day}';

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.primaryGreen, Color(0xFF0F3D12)],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$greeting, $name',
                        style: GoogleFonts.sora(
                            color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
                    Text(dateLabel,
                        style: GoogleFonts.inter(
                            color: Colors.white70, fontSize: 12.5)),
                  ],
                ),
              ),
              IconButton(
                onPressed: onLogout,
                icon: const Icon(Icons.logout_rounded, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onToggleShift,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppTheme.primaryGreen,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: Icon(isTracking ? Icons.stop_circle_outlined : Icons.play_circle_outline),
              label: Text(
                isTracking ? 'End shift' : 'Start shift',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final int stopCount;
  final double distanceLeftKm;
  final int minutesSaved;

  const _StatRow({
    required this.stopCount,
    required this.distanceLeftKm,
    required this.minutesSaved,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
      child: Row(
        children: [
          Expanded(child: _StatCell(value: '$stopCount', label: 'stops')),
          Container(width: 0.5, height: 32, color: const Color(0xFFE3EAE0)),
          Expanded(child: _StatCell(value: '${distanceLeftKm.toStringAsFixed(1)} km', label: 'left today')),
          Container(width: 0.5, height: 32, color: const Color(0xFFE3EAE0)),
          Expanded(
            child: _StatCell(
              value: '$minutesSaved min',
              label: 'saved by reroute',
              accent: minutesSaved > 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  final String value;
  final String label;
  final bool accent;
  const _StatCell({required this.value, required this.label, this.accent = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: GoogleFonts.sora(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: accent ? AppTheme.accentOrange : const Color(0xFF1A2E1A),
            )),
        Text(label, style: GoogleFonts.inter(fontSize: 10.5, color: Colors.black54)),
      ],
    );
  }
}

/// The hero of the tab — vendor's position at the top, then each stop
/// below it on a connecting line. The very next stop shows live traffic
/// context if we've recently checked it (fed by RouteMapScreen's polling).
class _JourneyTimeline extends StatelessWidget {
  final String vendorLocationName;
  final List<RouteStop> stops;
  final int? nextStopTrafficDelay;

  const _JourneyTimeline({
    required this.vendorLocationName,
    required this.stops,
    required this.nextStopTrafficDelay,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Your route',
              style: GoogleFonts.sora(fontSize: 15, fontWeight: FontWeight.w700)),
          Text('Live traffic-aware, updates automatically',
              style: GoogleFonts.inter(fontSize: 12, color: Colors.black54)),
          const SizedBox(height: 8),
          _TimelineNode(
            isVendor: true,
            title: 'You are here',
            subtitle: vendorLocationName,
          ),
          for (var i = 0; i < stops.length; i++)
            _TimelineNode(
              index: i + 1,
              title: stops[i].order.deliveryLocation.name,
              subtitle:
                  '${stops[i].distanceFromPreviousKm.toStringAsFixed(2)} km',
              atRisk: stops[i].isAtRiskOfLateness,
              trafficDelayMinutes: i == 0 ? nextStopTrafficDelay : null,
            ),
        ],
      ),
    );
  }
}

class _TimelineNode extends StatelessWidget {
  final bool isVendor;
  final int? index;
  final String title;
  final String subtitle;
  final bool atRisk;
  final int? trafficDelayMinutes;

  const _TimelineNode({
    this.isVendor = false,
    this.index,
    required this.title,
    required this.subtitle,
    this.atRisk = false,
    this.trafficDelayMinutes,
  });

  @override
  Widget build(BuildContext context) {
    final dotColor = isVendor
        ? AppTheme.primaryGreen
        : atRisk
            ? Colors.red
            : Colors.white;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: isVendor || atRisk ? dotColor : Colors.white,
                  shape: BoxShape.circle,
                  border: isVendor || atRisk
                      ? null
                      : Border.all(color: const Color(0xFFBFCBBB)),
                ),
                alignment: Alignment.center,
                child: isVendor
                    ? const Icon(Icons.location_on, color: Colors.white, size: 12)
                    : atRisk
                        ? const Icon(Icons.warning_rounded, color: Colors.white, size: 12)
                        : Text('$index',
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
              ),
              Expanded(child: Container(width: 1.5, color: const Color(0xFFDDE4D9))),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w600)),
                        Text(
                          atRisk ? 'At risk of lateness' : subtitle,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: atRisk ? Colors.red : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (trafficDelayMinutes != null && trafficDelayMinutes! > 2)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('+$trafficDelayMinutes min',
                          style: GoogleFonts.inter(
                              fontSize: 10.5, color: Colors.orange[800], fontWeight: FontWeight.w600)),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyRouteNotice extends StatelessWidget {
  const _EmptyRouteNotice();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE3EAE0)),
        ),
        child: Column(
          children: [
            Icon(Icons.nightlight_round, color: Colors.grey.shade400, size: 30),
            const SizedBox(height: 10),
            Text('No route yet',
                style: GoogleFonts.sora(fontWeight: FontWeight.w700, fontSize: 15)),
            const SizedBox(height: 4),
            Text("You'll see your journey here once orders come in.",
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 12.5, color: Colors.black54)),
          ],
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? badge;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE3EAE0)),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: AppTheme.primaryGreen),
              const SizedBox(width: 8),
              Expanded(
                child: Text(label,
                    style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600)),
              ),
              if (badge != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.accentOrange,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(badge!,
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}