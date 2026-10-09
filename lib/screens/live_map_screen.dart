import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import '../theme.dart';
import '../widgets/landmarks.dart';
import '../widgets/shuttle_card.dart';
import '../widgets/shuttle_tile.dart';

/// Live map with a draggable frosted-glass shuttle panel.
class LiveMapScreen extends StatefulWidget {
  final List<Shuttle> shuttles;
  final ValueChanged<Shuttle> onOpenShuttle;
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
    if (place != null) _mapController.move(place.position, 16.5);
  }

  void _recenterMap() => _mapController.move(liveMapInitialCenter, liveMapInitialZoom);

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
            builder: (context, constraints) => Stack(
              children: [
                Positioned.fill(child: _buildMap()),
                _buildAttribution(),
                _buildRecenterButton(constraints.maxHeight),
                _buildShuttleSheet(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMap() {
    return FlutterMap(
      mapController: _mapController,
      options: const MapOptions(
        initialCenter: liveMapInitialCenter,
        initialZoom: liveMapInitialZoom,
        minZoom: 11,
        maxZoom: 18,
        backgroundColor: Color(0xFFF2F4F7),
        interactionOptions: InteractionOptions(
          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
        ),
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
                width: 130,
                height: 92,
                alignment: Alignment.topCenter,
                child: GestureDetector(
                  onTap: () => _mapController.move(landmark.position, 16.5),
                  child: _LandmarkPin(
                    landmark: landmark,
                    label: _shortLabel(landmark.name),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildAttribution() {
    return Positioned(
      top: 8,
      left: 8,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.82),
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: AppColors.line),
        ),
        child: const Text(
          '© OpenStreetMap contributors',
          style: TextStyle(fontSize: 9, color: Color(0xFF4B5563)),
        ),
      ),
    );
  }

  Widget _buildRecenterButton(double availableHeight) {
    return Positioned.fill(
      child: ListenableBuilder(
        listenable: _sheetController,
        builder: (context, _) {
          final sheetSize = _sheetController.isAttached
              ? _sheetController.size
              : _sheetInitialExtent;
          if (sheetSize > 0.6) return const SizedBox.shrink();

          return Align(
            alignment: Alignment.bottomRight,
            child: Padding(
              padding: EdgeInsets.only(
                right: 16,
                bottom: availableHeight * sheetSize + 12,
              ),
              child: Material(
                color: Colors.white,
                shape: const CircleBorder(),
                elevation: 7,
                shadowColor: AppColors.navy.withValues(alpha: 0.18),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: _recenterMap,
                  child: const SizedBox(
                    width: 48,
                    height: 48,
                    child: Icon(Icons.my_location, color: AppColors.navy, size: 22),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

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
          decoration: BoxDecoration(
            gradient: AppColors.glassGradient,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: Colors.white.withValues(alpha: 0.94), width: 1.4),
            boxShadow: const [
              BoxShadow(color: Color(0x33265F9E), blurRadius: 22, offset: Offset(0, -5)),
              BoxShadow(color: Color(0x55FFFFFF), blurRadius: 1, offset: Offset(0, 1)),
            ],
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFC5D9ED),
                    borderRadius: BorderRadius.circular(3),
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
                      fontSize: 19,
                      letterSpacing: -0.3,
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
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(
            gradient: AppColors.glassGradient,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white, width: 1.2),
            boxShadow: const [
              BoxShadow(color: Color(0x26265F9E), blurRadius: 7, offset: Offset(0, 2)),
            ],
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.navy,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: landmark.color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: const [
              BoxShadow(color: Color(0x55265F9E), blurRadius: 8, offset: Offset(0, 3)),
            ],
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
