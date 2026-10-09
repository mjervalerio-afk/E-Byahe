import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import '../theme.dart';
import '../widgets/landmarks.dart';

// ---------------------------------------------------------------------------
// Edit the schedule and fares here. They are used by the cards AND by the
// quick answers, so you only change them in one place.
// ---------------------------------------------------------------------------
const _operatingDays = 'Monday to Saturday';
const _operatingHours = '7:00 AM – 7:00 PM';
const _fareMallToPcu = '₱12';
const _farePcuToCollege = '₱10';

/// The Info tab: about, schedule, fares, a small tappable map of the places,
/// how to read the app, quick answers, and an Exit button.
///
/// There is no login yet, so "Exit" closes the app on a phone. (A browser
/// tab can't close itself, so in Chrome the button does nothing — expected.)
/// When you add accounts, replace `_confirmExit` with a real sign-out.
class InfoScreen extends StatelessWidget {
  /// Called when a place is tapped; the shell switches to the map and flies to it.
  final ValueChanged<Landmark>? onShowPlace;

  /// Called when the mini map itself is tapped; the shell opens the Live Map.
  final VoidCallback? onOpenMap;

  const InfoScreen({super.key, this.onShowPlace, this.onOpenMap});

  Future<void> _confirmExit(BuildContext context) async {
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Exit E-Byahe?'),
        content: const Text('The app will close. You can reopen it anytime.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.red),
            child: const Text('Exit'),
          ),
        ],
      ),
    );

    if (shouldExit == true) {
      await SystemNavigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AppHeader(
          title: 'Info',
          subtitle: 'About E-Byahe Shuttle',
          leading: Image.asset(
            'assets/images/logo.png',
            width: 44,
            height: 44,
            fit: BoxFit.contain,
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              _buildAboutCard(),
              const SizedBox(height: 14),
              _buildScheduleCard(),
              const SizedBox(height: 14),
              _buildFareCard(),
              const SizedBox(height: 14),
              _buildPlacesCard(),
              const SizedBox(height: 14),
              _buildHowItWorksCard(),
              const SizedBox(height: 14),
              _buildFaqCard(),
              const SizedBox(height: 14),
              _buildVersionCard(),
              const SizedBox(height: 20),
              _buildExitButton(context),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------- cards

  Widget _buildAboutCard() {
    return const _InfoCard(
      title: 'About',
      child: Text(
        'E-Byahe Shuttle is a live tracking app for the Philippine Christian '
        'University campus shuttle. See where the shuttle is, how many seats '
        'are free, and how soon it reaches your stop, so you can plan your '
        'ride before you walk out the door.',
        style: TextStyle(color: AppColors.muted, fontSize: 13, height: 1.5),
      ),
    );
  }

  Widget _buildScheduleCard() {
    return const _InfoCard(
      title: 'Schedule & Operating Hours',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _IconBadge(icon: Icons.schedule),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Operating hours',
                  style: TextStyle(color: AppColors.muted, fontSize: 12),
                ),
                SizedBox(height: 2),
                Text(
                  _operatingHours,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                    color: AppColors.navy,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  _operatingDays,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: AppColors.blue,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Shuttles dispatch at regular intervals throughout operating hours.',
                  style: TextStyle(color: AppColors.muted, fontSize: 12, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFareCard() {
    return _InfoCard(
      title: 'Fare Matrix',
      subtitle: 'Shuttle fares',
      child: Column(
        children: const [
          _FareRow(
            route: 'Robinsons Place / SM Dasmariñas - PCU Main',
            fare: _fareMallToPcu,
          ),
          Divider(height: 20, color: AppColors.line),
          _FareRow(
            route: 'PCU Main - PCU College Building',
            fare: _farePcuToCollege,
          ),
          SizedBox(height: 14),
          _NoteBox(
            icon: Icons.payments_outlined,
            text: 'Please prepare exact change before boarding.',
          ),
        ],
      ),
    );
  }

  Widget _buildPlacesCard() {
    return _InfoCard(
      title: 'Places on the map',
      subtitle: 'Tap the map or a place to open it on the Live Map.',
      child: Column(
        children: [
          _buildMiniMap(),
          const SizedBox(height: 8),
          for (int i = 0; i < liveMapLandmarks.length; i++) ...[
            InkWell(
              onTap: onShowPlace == null ? null : () => onShowPlace!(liveMapLandmarks[i]),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: liveMapLandmarks[i].color,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(liveMapLandmarks[i].icon, color: Colors.white, size: 17),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        liveMapLandmarks[i].name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: AppColors.navy,
                        ),
                      ),
                    ),
                    if (onShowPlace != null)
                      const Icon(Icons.chevron_right, color: Color(0xFFB7BEC9)),
                  ],
                ),
              ),
            ),
            if (i != liveMapLandmarks.length - 1)
              const Divider(height: 1, color: AppColors.line),
          ],
        ],
      ),
    );
  }

  /// A small, fixed (not draggable) map so the page still scrolls normally.
  /// Tap a pin to fly to that place; tap anywhere else to open the Live Map.
  Widget _buildMiniMap() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        height: 190,
        child: Stack(
          children: [
            FlutterMap(
              options: MapOptions(
                initialCenter: liveMapInitialCenter,
                initialZoom: liveMapInitialZoom,
                backgroundColor: const Color(0xFFF2F4F7),
                interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
                onTap: (_, __) => onOpenMap?.call(),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  maxZoom: 19,
                  userAgentPackageName: 'com.pcu.e_byahe_shuttle',
                ),
                MarkerLayer(
                  markers: [
                    for (final landmark in liveMapLandmarks)
                      Marker(
                        point: landmark.position,
                        width: 96,
                        height: 72,
                        alignment: Alignment.topCenter,
                        child: GestureDetector(
                          onTap: onShowPlace == null ? null : () => onShowPlace!(landmark),
                          child: OverflowBox(
                            alignment: Alignment.topCenter,
                            maxHeight: double.infinity,
                            child: _MiniPin(
                              landmark: landmark,
                              label: _shortLabel(landmark.name),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
            // Required map credit.
            Positioned(
              left: 6,
              bottom: 4,
              child: IgnorePointer(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: const Text(
                    '© OpenStreetMap contributors',
                    style: TextStyle(fontSize: 8, color: Color(0xFF4B5563)),
                  ),
                ),
              ),
            ),
            // Hint that the map can be tapped.
            Positioned(
              right: 8,
              top: 8,
              child: IgnorePointer(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.metallicBlue,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.open_in_full, size: 12, color: Colors.white),
                      SizedBox(width: 4),
                      Text(
                        'Open map',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHowItWorksCard() {
    return const _InfoCard(
      title: 'How it works',
      child: Column(
        children: [
          _StepRow(
            icon: Icons.map,
            title: 'Live Map',
            text: 'Campus stops and nearby places on a real map.',
          ),
          _StepRow(
            icon: Icons.directions_bus_outlined,
            title: 'Shuttles',
            text: 'Every shuttle, its seats and ETA. Tap one for details.',
          ),
          _StepRow(
            icon: Icons.event_seat_outlined,
            title: 'Seat Map',
            text: 'Green seats are free. Red seats are taken.',
            isLast: true,
          ),
        ],
      ),
    );
  }

  Widget _buildFaqCard() {
    const items = [
      (
        'How much is the shuttle fare?',
        'Rides between Robinsons/SM Dasmariñas and PCU cost $_fareMallToPcu. '
            'Transfers between the PCU Main Campus and PCU College Building '
            'cost $_farePcuToCollege. Please prepare exact change.'
      ),
      (
        'What are the shuttle operating hours?',
        'Shuttles run $_operatingDays, from $_operatingHours.'
      ),
      (
        'What do Full, Almost full and Seats open mean?',
        'Full means no free seats. Almost full means one seat is left. '
            'Seats open means two or more are free.'
      ),
      (
        'How are the seats counted?',
        'Each seat has a weight sensor. When someone sits down, that seat '
            'turns red on the Seat Map. This prototype currently shows sample data.'
      ),
      (
        'How accurate is the shuttle location?',
        'Location comes from a GPS module on the shuttle and can be off by a '
            'few meters, especially near tall buildings.'
      ),
      (
        'Why is the map blank?',
        'Map tiles load online, so the phone needs an internet connection. '
            'Check your connection and reopen the app.'
      ),
    ];

    return Container(
      decoration: appCardDecoration(),
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Theme(
        data: ThemeData(
          useMaterial3: true,
          dividerColor: Colors.transparent,
          colorSchemeSeed: AppColors.blue,
        ),
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Quick answers',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: AppColors.navy,
                  ),
                ),
              ),
            ),
            for (final item in items)
              ExpansionTile(
                tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                expandedCrossAxisAlignment: CrossAxisAlignment.start,
                title: Text(
                  item.$1,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.navy,
                  ),
                ),
                children: [
                  Text(
                    item.$2,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 12.5,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildVersionCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.softBlue,
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: AppColors.blue, size: 18),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Version 0.1.0 (prototype). Shuttle data is provided for reference only.',
              style: TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExitButton(BuildContext context) {
    return SizedBox(
      height: 50,
      child: OutlinedButton.icon(
        onPressed: () => _confirmExit(context),
        icon: const Icon(Icons.logout),
        label: const Text('Exit', style: TextStyle(fontWeight: FontWeight.w700)),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.red,
          backgroundColor: Colors.white,
          side: const BorderSide(color: AppColors.red, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }
}

String _shortLabel(String name) {
  switch (name) {
    case 'SM City Dasmariñas':
      return 'SM Dasmariñas';
    case 'Robinsons Place Dasmariñas':
      return 'Robinsons';
    case 'Philippine Christian University':
      return 'PCU';
    case 'PCU College Building':
      return 'College Bldg';
    default:
      return name;
  }
}

// ======================================================================
// Pieces
// ======================================================================

class _InfoCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;

  const _InfoCard({required this.title, this.subtitle, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: appCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: AppColors.navy,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(subtitle!, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
          ],
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _IconBadge extends StatelessWidget {
  final IconData icon;
  const _IconBadge({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.softBlue,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: AppColors.blue, size: 22),
    );
  }
}

class _FareRow extends StatelessWidget {
  final String route;
  final String fare;
  const _FareRow({required this.route, required this.fare});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            route,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: AppColors.navy,
              height: 1.3,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.softGreen,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            fare,
            style: const TextStyle(
              color: AppColors.green,
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
        ),
      ],
    );
  }
}

class _NoteBox extends StatelessWidget {
  final IconData icon;
  final String text;
  const _NoteBox({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.softAmber,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.amber),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Color(0xFF7A4B00),
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A small map pin for the mini map: tiny label, colored circle, pointer.
class _MiniPin extends StatelessWidget {
  final Landmark landmark;
  final String label;

  const _MiniPin({required this.landmark, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 3)],
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1F2937),
            ),
          ),
        ),
        const SizedBox(height: 2),
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: landmark.color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 3)],
          ),
          child: Icon(landmark.icon, color: Colors.white, size: 13),
        ),
        Transform.translate(
          offset: const Offset(0, -4),
          child: Icon(Icons.arrow_drop_down, size: 18, color: landmark.color),
        ),
      ],
    );
  }
}

class _StepRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;
  final bool isLast;

  const _StepRow({
    required this.icon,
    required this.title,
    required this.text,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.softBlue,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.blue, size: 19),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: AppColors.navy,
                  ),
                ),
                const SizedBox(height: 2),
                Text(text, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}