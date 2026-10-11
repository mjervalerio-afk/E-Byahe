import 'package:flutter/material.dart';

import '../theme.dart';
import '../services/gps_simulator.dart';
import '../services/route_state_manager.dart';
import '../services/supabase_simulation_service.dart';

/// Developer-only controls for exercising GPS and route logic without hardware.
class GpsSimulatorPanel extends StatefulWidget {
  final GpsSimulator simulator;
  final SupabaseSimulationService supabase;
  const GpsSimulatorPanel({super.key, required this.simulator, required this.supabase});

  @override
  State<GpsSimulatorPanel> createState() => _GpsSimulatorPanelState();
}

class _GpsSimulatorPanelState extends State<GpsSimulatorPanel> {
  late String _scenario;
  late String _startingStop;
  late bool _includeCollege;
  late bool _automatic;
  late int _speed;
  late GpsSource _source;
  late final TextEditingController _tripIdController;

  @override
  void initState() {
    super.initState();
    final sim = widget.simulator;
    if (sim.state == null) sim.configure();
    _scenario = sim.scenarioId;
    _startingStop = sim.startingStopId;
    _includeCollege = sim.includeCollege;
    _automatic = sim.automatic;
    _speed = sim.speedMultiplier;
    _source = sim.source;
    _tripIdController = TextEditingController(text: sim.tripId);
  }

  @override
  void dispose() {
    _tripIdController.dispose();
    super.dispose();
  }

  List<String> get _availableStops => routeScenarios[_scenario]!.stopIds
      .where((id) => _includeCollege || id != 'college')
      .toSet()
      .toList();

  void _applyConfiguration() {
    final stops = _availableStops;
    if (!stops.contains(_startingStop)) _startingStop = stops.first;
    widget.simulator.configure(
      scenarioId: _scenario,
      startingStopId: _startingStop,
      includeCollege: _includeCollege,
      automatic: _automatic,
      speedMultiplier: _speed,
      source: _source,
      tripId: _source == GpsSource.supabaseTestSimulation ? _tripIdController.text.trim() : null,
    );
  }

  void _changeScenario(String value) {
    setState(() {
      _scenario = value;
      final stops = routeScenarios[value]!.stopIds
          .where((id) => _includeCollege || id != 'college')
          .toSet()
          .toList();
      if (!stops.contains(_startingStop)) _startingStop = stops.first;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.simulator,
      builder: (context, _) {
        final sim = widget.simulator;
        final state = sim.state;
        final active = state != null && state.status != SimulationStatus.stopped;
        final coordinateText = state == null
            ? 'Not initialized'
            : state.position.latitude.toStringAsFixed(6) + ', ' +
                state.position.longitude.toStringAsFixed(6);
        final destination = state?.nextStopId;
        final distance = state != null && destination != null
            ? RouteStateManager.distanceMeters(state.position, routeStops[destination]!.position)
            : null;
        final etaMinutes = distance == null ? null : (distance / 333.0).ceil();

        return SafeArea(
          child: Container(
            margin: const EdgeInsets.fromLTRB(10, 22, 10, 8),
            constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.88),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.line),
              boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 24)],
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 12, 10, 8),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.softBlue,
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: const Icon(Icons.gps_fixed, color: AppColors.navy),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('GPS Simulator', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.navy)),
                            Text('Developer testing only', style: TextStyle(fontSize: 12, color: AppColors.muted)),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Close simulator',
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: active ? AppColors.softAmber : AppColors.softBlue,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: active ? AppColors.amber : AppColors.line),
                        ),
                        child: Row(
                          children: [
                            Icon(active ? Icons.warning_amber_rounded : Icons.info_outline,
                                color: active ? const Color(0xFF946200) : AppColors.navy),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                active ? 'SIMULATED GPS ACTIVE — TEST COORDINATES ONLY' : 'SIMULATED GPS is stopped',
                                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12,
                                    color: active ? const Color(0xFF805900) : AppColors.navy),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      _sectionTitle('Data source'),
                      DropdownButtonFormField<GpsSource>(
                        value: _source,
                        isExpanded: true,
                        decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                        items: [
                          const DropdownMenuItem(value: GpsSource.localSimulation, child: Text('Local Simulation (no database)')),
                          DropdownMenuItem(
                            value: GpsSource.supabaseTestSimulation,
                            enabled: widget.supabase.isConfigured,
                            child: Text(widget.supabase.isConfigured
                                ? 'Supabase Test Simulation'
                                : 'Supabase Test Simulation (configure keys first)'),
                          ),
                          const DropdownMenuItem(
                            value: GpsSource.realGps,
                            enabled: false,
                            child: Text('Real GPS (provider not configured)'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() => _source = value);
                        },
                      ),
                      const SizedBox(height: 7),
                      Text(
                        _source == GpsSource.supabaseTestSimulation
                            ? 'Writes are restricted to gps_locations_test / shuttle-test-01.'
                            : 'Local mode updates the map only and never writes GPS data.',
                        style: const TextStyle(fontSize: 11, color: AppColors.muted),
                      ),
                      if (_source == GpsSource.supabaseTestSimulation) ...[
                        const SizedBox(height: 10),
                        TextField(
                          controller: _tripIdController,
                          maxLength: 80,
                          decoration: const InputDecoration(
                            labelText: 'Test trip ID',
                            helperText: 'Use the same ID on a read-only observer client.',
                            border: OutlineInputBorder(),
                            isDense: true,
                            counterText: '',
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),
                      _sectionTitle('Route setup'),
                      DropdownButtonFormField<String>(
                        value: _scenario,
                        decoration: const InputDecoration(labelText: 'Route scenario', border: OutlineInputBorder(), isDense: true),
                        items: [
                          for (final item in routeScenarios.values)
                            DropdownMenuItem(value: item.id, child: Text(item.id + ' · ' + item.name)),
                        ],
                        onChanged: (value) { if (value != null) _changeScenario(value); },
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        value: _availableStops.contains(_startingStop) ? _startingStop : _availableStops.first,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Starting stop', border: OutlineInputBorder(), isDense: true),
                        items: [
                          for (final id in _availableStops)
                            DropdownMenuItem(value: id, child: Text(routeStops[id]!.name)),
                        ],
                        onChanged: (value) { if (value != null) setState(() => _startingStop = value); },
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Include PCU College Building', style: TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: const Text('Turn off to test trips that skip this checkpoint.', style: TextStyle(fontSize: 11)),
                        value: _includeCollege,
                        onChanged: (value) => setState(() {
                          _includeCollege = value;
                          if (!_availableStops.contains(_startingStop)) _startingStop = _availableStops.first;
                        }),
                      ),
                      Row(
                        children: [
                          const Expanded(child: Text('Movement mode', style: TextStyle(fontWeight: FontWeight.w600))),
                          SegmentedButton<bool>(
                            segments: const [
                              ButtonSegment(value: true, label: Text('Auto')),
                              ButtonSegment(value: false, label: Text('Manual')),
                            ],
                            selected: {_automatic},
                            showSelectedIcon: false,
                            onSelectionChanged: (v) => setState(() => _automatic = v.first),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          const Expanded(child: Text('Simulation speed', style: TextStyle(fontWeight: FontWeight.w600))),
                          Text(_speed.toString() + '×', style: const TextStyle(color: AppColors.blue, fontWeight: FontWeight.w800)),
                        ],
                      ),
                      Slider(
                        value: _speed.toDouble(),
                        min: 1,
                        max: 10,
                        divisions: 9,
                        label: _speed.toString() + '×',
                        onChanged: (v) => setState(() => _speed = v.round()),
                      ),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _actionButton('Apply / Reset', Icons.restart_alt, _applyConfiguration),
                          _actionButton('Start', Icons.play_arrow, () { _applyConfiguration(); sim.start(); }),
                          _actionButton('Pause', Icons.pause, sim.pause),
                          _actionButton('Resume', Icons.play_arrow, sim.resume),
                          _actionButton('Stop', Icons.stop, sim.stop),
                          _actionButton('Previous', Icons.skip_previous, sim.previousCheckpoint),
                          _actionButton('Next checkpoint', Icons.skip_next, sim.nextCheckpoint),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _sectionTitle('Live test state'),
                      _infoRow('Status', state?.status.name.toUpperCase() ?? 'NOT INITIALIZED'),
                      _infoRow('Source', state?.source.name ?? '—'),
                      _infoRow('Latitude, longitude', coordinateText),
                      _infoRow('GPS timestamp', state?.timestamp.toLocal().toString().split('.').first ?? '—'),
                      _infoRow('Current stop', state?.currentStopName ?? '—'),
                      _infoRow('Next destination', state?.nextDestinationName ?? '—'),
                      _infoRow('Straight-line distance', distance == null ? 'Unavailable' : (distance / 1000).toStringAsFixed(2) + ' km (test estimate)'),
                      _infoRow('ETA', etaMinutes == null ? 'Unavailable' : etaMinutes.toString() + ' min (rough estimate)'),
                      _infoRow('Simulated speed', sim.simulatedSpeedKmh.toStringAsFixed(1) + ' km/h (test estimate)'),
                      _infoRow('Route progress', state == null ? '—' : (sim.routeProgress * 100).round().toString() + '%'),
                      _infoRow('Supabase', widget.supabase.isConfigured ? 'Keys configured; connection checked on write' : 'Not configured'),
                      if (sim.lastCheckpointResult != null) _infoRow('Last checkpoint test', sim.lastCheckpointResult!),
                      const SizedBox(height: 14),
                      _sectionTitle('Invisible checkpoint test'),
                      const Text('Synthetic coordinates only; this line is not shown to passengers and is not road-aligned.', style: TextStyle(fontSize: 11, color: AppColors.muted)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 7,
                        runSpacing: 7,
                        children: [
                          _actionButton('Correct direction', Icons.check_circle_outline, () => sim.runCheckpointTest('correct direction')),
                          _actionButton('Wrong direction', Icons.wrong_location_outlined, () => sim.runCheckpointTest('wrong direction')),
                          _actionButton('Approach only', Icons.near_me_outlined, () => sim.runCheckpointTest('approach only')),
                          _actionButton('Duplicate point', Icons.content_copy, () => sim.runCheckpointTest('duplicate coordinates')),
                          _actionButton('GPS noise', Icons.waves, () => sim.runCheckpointTest('noise')),
                          _actionButton('Repeated crossing', Icons.repeat, () => sim.runCheckpointTest('repeated crossing')),
                          _actionButton('College not next', Icons.route, () => sim.runCheckpointTest('college not next')),
                          _actionButton('Stale GPS', Icons.history, () => sim.runCheckpointTest('stale GPS')),
                          _actionButton('Invalid GPS', Icons.gps_off, () => sim.runCheckpointTest('invalid GPS')),
                          _actionButton('Unrealistic jump', Icons.warning_amber, () => sim.runCheckpointTest('unrealistic jump')),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(child: _sectionTitle('Event log')),
                          TextButton.icon(
                            onPressed: sim.clearEvents,
                            icon: const Icon(Icons.delete_sweep_outlined, size: 16),
                            label: const Text('Clear'),
                          ),
                        ],
                      ),
                      Container(
                        constraints: const BoxConstraints(maxHeight: 190),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: const Color(0xFFF5F8FC), borderRadius: BorderRadius.circular(12)),
                        child: sim.events.isEmpty
                            ? const Text('No events yet.', style: TextStyle(color: AppColors.muted, fontSize: 12))
                            : ListView.separated(
                                shrinkWrap: true,
                                itemCount: sim.events.length > 20 ? 20 : sim.events.length,
                                separatorBuilder: (_, __) => const Divider(height: 8),
                                itemBuilder: (_, index) => Text(sim.events[index], style: const TextStyle(fontSize: 11, color: AppColors.navy)),
                              ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _sectionTitle(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.navy)),
  );

  Widget _infoRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 138, child: Text(label, style: const TextStyle(fontSize: 11, color: AppColors.muted))),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.navy))),
      ],
    ),
  );

  Widget _actionButton(String label, IconData icon, VoidCallback onPressed) => OutlinedButton.icon(
    onPressed: onPressed,
    icon: Icon(icon, size: 16),
    label: Text(label, style: const TextStyle(fontSize: 11)),
    style: OutlinedButton.styleFrom(
      foregroundColor: AppColors.navy,
      side: const BorderSide(color: AppColors.line),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      visualDensity: VisualDensity.compact,
    ),
  );
}
