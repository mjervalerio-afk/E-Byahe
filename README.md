# E-Byahe Shuttle

E-Byahe is a Flutter campus-shuttle tracking UI using OpenStreetMap via flutter_map. It includes an in-app developer GPS simulator so route and marker behavior can be tested before a physical GPS receiver or ESP32 bridge is available.

## Run the app

Install Flutter, then run:

```bash
flutter pub get
flutter run
```

The simulator button (GPS crosshair near the map's upper-right corner) is shown only in Flutter debug builds. Passenger UI remains unchanged by default.

## GPS simulator

Choose **Local Simulation** to run the route logic entirely on the device. It does not write to a database and works without GPS hardware or Supabase.

The three configured scenarios are:

- **A:** PCU → SM Dasma → Robinsons Place Dasmariñas → PCU → PCU College Building
- **B:** Robinsons Place Dasmariñas → PCU → PCU College Building → SM Dasma → Robinsons Place Dasmariñas
- **C:** SM Dasma → Robinsons Place Dasmariñas → PCU → PCU College Building

Use the panel to set the starting stop, include/exclude PCU College Building, choose automatic or manual movement, change movement speed, start/pause/resume/stop/reset/step through checkpoints. It also exposes synthetic tests for correct/wrong-direction crossings, approaching without crossing, duplicate coordinates/events, GPS noise, stale or invalid samples, unrealistic jumps, and attempts to trigger the College Building checkpoint when it is not the next destination.

All map locations are taken from the existing map configuration. The College Building pin is approximate. Movement is linearly interpolated between stop coordinates for deterministic software testing; it does **not** follow actual roads and must not be treated as a production shuttle trace. The invisible checkpoint line is a configurable test boundary and is not drawn on the passenger map. Replace its endpoints and expected direction after measuring the intended road crossing.

The developer-panel ETA uses straight-line remaining distance and a nominal speed as a **rough fallback estimate**. It is not a road-routing result. Configure a road-routing service and verified road geometry before displaying it as a reliable passenger ETA.

Real GPS is intentionally disabled until a provider is connected.

## Optional Supabase test simulation

Supabase is optional. Basic local simulation works without a project or keys.

1. Use a **development/test Supabase project**, not your production project.
2. Open the Supabase SQL editor and run supabase/gps_simulator.sql. This creates only public.gps_locations_test, adds row-level security policies scoped to the fixed test shuttle and source_type = simulated, and adds the table to Supabase Realtime. The SQL does not create or update seat-occupancy tables.
3. Run Flutter with a Supabase project URL and a frontend publishable/anon key:

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://YOUR-PROJECT-REF.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=YOUR_PUBLISHABLE_OR_ANON_KEY
```

Use only a publishable/anon key in the app. Never place a service-role key or secret key in client code, build flags, or the repository.

4. Open the GPS simulator and choose **Supabase Test Simulation**. Apply the configuration and start the simulator. Test GPS rows are written only to gps_locations_test with a fixed test shuttle ID and a trip ID. If the table or permissions are not configured, the event log reports the write error.
5. To test a second debug client as an observer, start that client **before** the writer begins. Use the same **Test trip ID**, route scenario and starting stop, select **Manual** movement, apply the setup and press **Start**. Then start the writing simulator on the first client. Do not advance checkpoints on the observer client. It subscribes to the same test trip's Realtime rows. Use only one writing simulator for a given trip.

The simulator keeps route detection client-side and sends only simulated coordinate rows to the isolated table. Realtime records are validated and processed in timestamp order; the College Building transition still requires the directional checkpoint to pass. The app does not mix test locations into a production shuttle feed.

The included database policies are only a safe starting point for a development-only table and should not be copied to production GPS tables. Protect access to the Supabase project and use stricter authenticated policies if the test environment is shared.

## Main implementation files

- lib/services/route_state_manager.dart — centralized route scenarios, GPS validation, directional checkpoint detection and route transitions.
- lib/services/gps_simulator.dart — automatic/manual simulation, synthetic checkpoint test cases, bounded event log and Realtime-row validation.
- lib/services/supabase_simulation_service.dart — optional isolated Supabase writer and Realtime reader.
- lib/widgets/gps_simulator_panel.dart — debug-only developer controls.
- lib/screens/live_map_screen.dart — uses the existing map, moving shuttle marker and existing shuttle card; seat counts are copied unchanged from the existing shuttle model.
- test/route_state_manager_test.dart — route sequence, GPS validation, crossing and destination-guard tests.

## Verify

Run these commands on a machine with Flutter installed:

```bash
flutter pub get
flutter analyze
flutter test
```

No physical GPS, road-routing API, or Supabase credentials are required for local mode.