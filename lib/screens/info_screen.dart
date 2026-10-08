import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme.dart';
import '../widgets/landmarks.dart';

/// The Info tab: what the app is, how to read it, the places on the map
/// (tap one to see it on the map), quick answers, and an Exit button.
///
/// There is no login yet, so "Exit" closes the app on a phone. (A browser
/// tab can't close itself, so in Chrome the button does nothing — expected.)
/// When you add accounts, replace `_confirmExit` with a real sign-out.
class InfoScreen extends StatelessWidget {
  /// Called when a place is tapped; the shell switches to the map and flies to it.
  final ValueChanged<Landmark>? onShowPlace;

  const InfoScreen({super.key, this.onShowPlace});

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
              _buildHowItWorksCard(),
              const SizedBox(height: 14),
              _buildPlacesCard(),
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

  Widget _buildPlacesCard() {
    return _InfoCard(
      title: 'Places on the map',
      subtitle: 'Tap a place to see it on the map.',
      child: Column(
        children: [
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

  Widget _buildFaqCard() {
    const items = [
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
