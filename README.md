# E-Byahe Shuttle — Starter Frame

This is a runnable Flutter skeleton of the app: splash video → skeleton
loading → Live Map screen (mock data), matching your reference screenshot.
No backend, login, or real map SDK yet — that's intentional, per "focus on
the application first and building the frame."

## What's inside
```
lib/
  main.dart                     # app entry point
  screens/splash_screen.dart    # plays assets/videos/splash.mp4 once
  screens/skeleton_loading_screen.dart  # shimmer placeholder
  screens/live_map_screen.dart  # the Live Map frame (header, map, shuttle list, bottom nav)
  widgets/shuttle_tile.dart     # Shuttle model + mock data + list row UI
assets/videos/splash.mp4        # your uploaded splash clip
pubspec.yaml
```

## 1. Install prerequisites
1. Install the **Flutter SDK**: https://docs.flutter.dev/get-started/install
   (pick your OS; this installs Dart too).
2. Install **VS Code**: https://code.visualstudio.com
3. In VS Code, open the Extensions panel (`Ctrl+Shift+X`) and install:
   - **Flutter** (by Dart Code) — this pulls in the Dart extension too.
4. Verify the install in a terminal:
   ```
   flutter doctor
   ```
   Fix anything it flags red (Android SDK / Xcode / etc). You need at least
   one target: an Android emulator, a physical Android phone with USB
   debugging on, or Chrome (for a quick web preview while you build UI).

## 2. Open the project
1. Unzip this folder anywhere on your machine.
2. In VS Code: **File → Open Folder** → select `e_byahe_shuttle`.
3. Open a terminal in VS Code (`` Ctrl+` ``) and run:
   ```
   flutter pub get
   ```
   This downloads `video_player` and `shimmer`, the two packages this
   starter uses.

## 3. Run it
1. Pick a device in the bottom-right corner of VS Code (emulator, phone, or Chrome).
2. Press `F5`, or run in the terminal:
   ```
   flutter run
   ```
3. You should see: your splash video play once → a shimmering skeleton for
   ~1.4s → the Live Map frame with 3 mock shuttles, matching the reference
   screenshot.

## 4. Where to go next (in order)
1. **Tighten the splash timing/asset.** If your video has a different
   length or you want it letterboxed instead of cropped, tweak
   `splash_screen.dart` (`BoxFit.cover` → `BoxFit.contain`) or trim the
   clip. Swapping in a Lottie animation instead of a video later just means
   replacing this one file.
2. **Real map.** Add `google_maps_flutter` (needs a Google Cloud API key,
   free tier is enough for a school project) or `flutter_map` (uses
   OpenStreetMap, no API key/billing needed — friendlier for a capstone
   demo). Replace `_buildMapArea()` and `_StaticLandmarks` in
   `live_map_screen.dart` with the real map widget, keeping the same
   marker/info-card logic.
3. **Firebase.** Since you've already decided on Firebase:
   - Run `flutterfire configure` (after `dart pub global activate flutterfire_cli`)
     to wire up `firebase_options.dart`.
   - Add `cloud_firestore` and replace `mockShuttles` in `shuttle_tile.dart`
     with a `StreamBuilder<QuerySnapshot>` reading a `shuttles` collection.
4. **Hardware bridge.** Your Arduino/ESP unit (NEO-6M GPS + load cells per
   seat) publishes lat/lng + seats-occupied to the same Firestore
   `shuttles` collection (e.g. via HTTP to a small Cloud Function, or
   directly if you use an ESP32 with Wi-Fi). Once step 3 is wired up, the
   app updates automatically — no app-side changes needed.
5. **Shuttles tab / Info tab.** Currently just placeholders in the bottom
   nav (`_navIndex` state exists but doesn't switch screens yet). Add two
   more screens and swap `body:` based on `_navIndex`.

## Notes
- Colors/spacing are eyeballed from your screenshot, not pixel-perfect —
  adjust hex values in `live_map_screen.dart` and `shuttle_tile.dart` to taste.
- Everything is in mock data right now (`mockShuttles`), so the frame runs
  standalone with zero backend setup — good for demoing the UI before
  hardware/Firebase are ready.
