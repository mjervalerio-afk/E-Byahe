import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import '../theme.dart';
import '../widgets/landmarks.dart';
import '../widgets/shuttle_card.dart';
import '../widgets/shuttle_tile.dart';

/// The Live Map tab: the free OpenStreetMap map with four simple pins, and a
/// pull-up sheet listing the shuttles.
class LiveMapScreen extends StatefulWidget {
  final List<Shuttle> shuttles;
  final ValueChanged<Shuttle> onOpenShuttle;

  /// When this changes to a place, the map flies to it (used by the Info tab).
  final ValueNotifier<Landmark?>? focusPlace;

  const LiveMapScreen({
    super.key,
    required this.shuttles,
    required this.onOpenShuttle,
    this.focusPlace,
  });

  @override
  State<LiveMapScreen> createState() => _LiveMapScreenState();
}

class _LiveMapScreenState extends State<LiveMapScreen> {
  static const double _sheetMinExtent = 0.14;
  static const double _sheetInitialExtent = 0.36;
  static const double _sheetMaxExtent = 0.85;

  final MapController _mapController = MapController();
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();

  @override
  void initState() {
    super.initState();
    widget.focusPlace?.addListener(_onFocusPlace);
  }

  @override
  void dispose() {
    widget.focusPlace?.removeListener(_onFocusPlace);
    _mapController.dispose();
    _sheetController.dispose();
    super.dispose();
  }

  void _onFocusPlace() {
    final place = widget.focusPlace?.value;
    if (place == null) return;
    _mapController.move(place.position, 16.5);
  }

  void _recenterMap() {
    _mapController.move(liveMapInitialCenter, liveMapInitialZoom);
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
        return 'College Building';
      default:
        return name;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AppHeader(
          title: 'E-Byahe Shuttle',
          subtitle: 'PCU campus shuttle',
          leading: Image.asset(
            'assets/images/logo.png',
            width: 44,
            height: 44,
            fit: BoxFit.contain,
          ),
          trailing: const LivePill(),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Stack(
                children: [
                  Positioned.fill(child: _buildMap()),
                  _buildAttribution(),
                  _buildRecenterButton(constraints.maxHeight),
                  _buildShuttleSheet(),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------------- map

  Widget _buildMap() {
    return FlutterMap(
      mapController: _mapController,
      options: const MapOptions(
        initialCenter: liveMapInitialCenter,
        initialZoom: liveMapInitialZoom,
        minZoom: 11,
        maxZoom: 18,
        backgroundColor: Color(0xFFF2F4F7),
        // No two-finger rotation: it only makes the map harder to read.
        interactionOptions: InteractionOptions(
          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
        ),
      ),
      children: [
        TileLayer(
          // The free OpenStreetMap map. No API key, no account.
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          maxZoom: 19,
          userAgentPackageName: 'com.pcu.e_byahe_shuttle',
        ),
        MarkerLayer(
          markers: [
            for (final landmark in liveMapLandmarks)
              Marker(
                point: landmark.position,
                width: 130,
                height: 100,
                // Whole marker sits above the point, so the pin's tip
                // lands exactly on the coordinate.
                alignment: Alignment.topCenter,
                child: GestureDetector(
                  onTap: () => _mapController.move(landmark.position, 16.5),
                  // OverflowBox lets the pin be its natural height, so a
                  // font or text-size difference can never trigger the red
                  // "BOTTOM OVERFLOWED" warning.
                  child: OverflowBox(
                    alignment: Alignment.topCenter,
                    maxHeight: double.infinity,
                    child: _LandmarkPin(
                      landmark: landmark,
                      label: _shortLabel(landmark.name),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  /// Map credit required by OpenStreetMap. Top-left so the sheet never hides it.
  Widget _buildAttribution() {
    return Positioned(
      top: 8,
      left: 8,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.75),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Text(
          '© OpenStreetMap contributors',
          style: TextStyle(fontSize: 9, color: Color(0xFF4B5563)),
        ),
      ),
    );
  }

  /// Re-fits the map on the four places. It rides just above the sheet as the
  /// sheet is dragged, and hides when the sheet is nearly full-screen.
  Widget _buildRecenterButton(double availableHeight) {
    return Positioned.fill(
      child: ListenableBuilder(
        listenable: _sheetController,
        builder: (context, _) {
          final sheetSize =
              _sheetController.isAttached ? _sheetController.size : _sheetInitialExtent;
          if (sheetSize > 0.6) return const SizedBox.shrink();

          return Align(
            alignment: Alignment.bottomRight,
            child: Padding(
              padding: EdgeInsets.only(
                right: 16,
                bottom: availableHeight * sheetSize + 12,
              ),
              child: GestureDetector(
                onTap: _recenterMap,
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 6)],
                  ),
                  child: const Icon(Icons.my_location, color: AppColors.navy, size: 22),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ----------------------------------------------------------------- sheet

  Widget _buildShuttleSheet() {
    return DraggableScrollableSheet(
      controller: _sheetController,
      initialChildSize: _sheetInitialExtent,
      minChildSize: _sheetMinExtent,
      maxChildSize: _sheetMaxExtent,
      snap: true,
      snapSizes: const [_sheetMinExtent, _sheetInitialExtent, _sheetMaxExtent],
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 14)],
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD5D9DF),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Shuttles',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      color: AppColors.navy,
                    ),
                  ),
                  StatusPill(
                    color: AppColors.green,
                    background: AppColors.softGreen,
                    text: '${widget.shuttles.length} active',
                    leading: const Dot(color: AppColors.green),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              for (final shuttle in widget.shuttles) ...[
                ShuttleCard(
                  shuttle: shuttle,
                  onTap: () => widget.onOpenShuttle(shuttle),
                ),
                const SizedBox(height: 10),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// A map pin: short label on top, a colored circle with the place's icon,
/// and a small pointer whose tip is the exact coordinate.
class _LandmarkPin extends StatelessWidget {
  final Landmark landmark;
  final String label;

  const _LandmarkPin({required this.landmark, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1F2937),
            ),
          ),
        ),
        const SizedBox(height: 3),
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: landmark.color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 5)],
          ),
          child: Icon(landmark.icon, color: Colors.white, size: 18),
        ),
        Transform.translate(
          offset: const Offset(0, -5),
          child: Icon(Icons.arrow_drop_down, size: 24, color: landmark.color),
        ),
      ],
    );
  }
}