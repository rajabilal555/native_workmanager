# native_workmanager Roadmap

Our mission is to provide the most robust, efficient, and secure background execution engine for Flutter.

---
## ✅ Completed (v1.3.x)
- **v1.3.2 iOS UIScene Lifecycle Compatibility (Issue #36):**
  - Fixed a startup crash (`NSInternalInconsistencyException`) on apps using the Flutter 3.38+ UIScene template, where plugin registration runs after `didFinishLaunching` — too late for `BGTaskScheduler.register`.
  - BGTask launch handlers now register in an ObjC `+load` hook (`NWMBGTaskRegistrar`), always inside the launch window, on both the legacy and UIScene templates — no user setup required.
  - Closes out the registration-hook and reference-app work promised (but not delivered) in Issue #16.
  - `kmpworkmanager` core upgraded 2.5.1 → 3.0.1, fixing an expedited-task crash on Android 8–11 (API 26–30).
- **v1.3.0 "Zero-Config" Developer Experience** — both items below shipped:
  - **Android Auto-Init:** `androidx.startup` `Initializer` (`NativeWorkManagerInitializer`) runs before `Application.onCreate()` — no custom `Application` class or manifest edits needed for `DartWorker`.
  - **Unified CLI Setup Tool:** `dart run native_workmanager:setup` patches `AndroidManifest.xml` and `Info.plist` (`BGTaskSchedulerPermittedIdentifiers`) automatically. The iOS `+load` registration piece originally scoped as a CLI injection ships instead as a built-in plugin mechanism (v1.3.2) — simpler and always-on, no CLI step required.

---
## ✅ Completed (v1.2.x)
- **v1.2.6 Industrial Reliability & FGS Bypass:**
  - **Foreground Service (FGS) Support (Android)**: Bypass Android 12+ background restrictions for heavy tasks with prioritized notifications.
  - **Locked Device Support (Android)**: Optimized task execution during Doze mode via Expedited Work mapping.
  - **Swift Concurrency Stability (iOS)**: Eliminated database deadlocks by migrating to serial dispatch queues.
  - **iOS Scheduling Reliability**: Tuned internal delays to ensure consistent `BGTaskScheduler` enqueuing.
  - **Platform-Aware Test Suite**: Comprehensive integration tests with automatic simulator detection and isolation.
- **v1.2.3 Critical Core Stability:** 
...
  - Bypassed Android's 10KB WorkManager payload limit via automated secure file spilling (`wm_spill_*.json`).
  - Fixed iOS URLSession background file loss with synchronous blocking moves.
  - Eliminated iOS `BGTaskScheduler` starvation and race conditions via `TaskCompletionGuard`.
  - Full I/O interruption support: `worker.stop()` now drops mid-flight network connections on cancel.
  - Added `initialDelay` and `runImmediately` support for Periodic Tasks.
  - Advanced Security: Strict validation against Null Byte Injection, Path Traversal (`..`), and Shell Injection.
- **Android Cold-Start Persistence:** `DartWorker` execution reliably survives app kills and restores automatically.
- **Advanced Remote Trigger (FCM/APNs):** Enqueue complete Task Chains and Offline Queues via silent push without waking the Flutter Engine.
- **HMAC Security:** Robust HMAC SHA-256 signature verification for remote triggers.
- **Real-Time Observability & Middleware:** DevTools extension real-time visualizer and global interceptors.
- **Code Generation (`native_workmanager_gen`):** Generate type-safe enqueue wrappers via `@WorkerCallback` annotations.
- **Selective Plugin Registration:** Explicit opt-in flag `registerPlugins` to control background engine memory footprint.

---

## 🧩 Phase 2: Ecosystem, Templates & Integrations (v1.4.x - v1.5.x) — Current Priority

To capture mindshare from legacy libraries, we must provide "Plug & Play" solutions.

- [ ] **Cross-Integrations (Adapters):**
  - `NativeDioAdapter`: Use Dio configurations but execute via the Zero-Engine `HttpDownloadWorker`.
  - `FirebaseStorage Native`: Upload directly via Native SDK without booting Flutter.
  - `Hive/Isar Sync`: Auto-sync local DB to server via native workers.
- [ ] **"Plug & Play" Templates Repository:**
  - Provide ready-to-use Dart templates for common use cases: *Auto Photo Backup to S3*, *Offline Chat Queue*, *Netflix-style Large Video Download*.
- [ ] **Native Offline Queue Engine:** Built-in declarative pattern for queuing tasks while offline with automatic file/database-backed retry.
- [ ] **SwiftUI `@main` App Support:** CLI tool detects SwiftUI apps and generates `AppDelegate` adoption shims.

---

## 🚀 Phase 3: Scale & Desktop (v2.0.x+)
- [ ] **Cloud Coordination:** Synchronize task status and dependency resolution across multiple devices.
- [ ] **Enterprise Rate Limiting:** Advanced bandwidth and concurrency control for multi-tenant apps.
- [ ] **Desktop Support:** Expanding the native worker engine to Windows, macOS, and Linux.

---

## 📈 KPIs Target
| Metric | 3 Months | 6 Months | 12 Months |
|--------|---------|---------|----------|
| pub.dev Likes | 100+ | 500+ | 2,000+ |
| GitHub Stars | 200+ | 1,000+ | 3,000+ |
| Weekly Downloads | 1k | 5k | 20k |
| Enterprise Users | 1 | 3+ | 10+ |
| pub.dev Score | 160 | 160 | 160 |

*(Note: pub.dev score target increased to 160/160 following the v1.2.3 release).*