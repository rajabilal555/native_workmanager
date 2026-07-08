import Foundation

/// Runtime bridge called by NWMBGTaskRegistrar (ObjC) via
/// `NSClassFromString("NWMBootstrap")` when a BGTask fires before any Swift
/// code has run — a cold-start background launch on the Flutter 3.38+ UIScene
/// template, where plugin registration only happens once a FlutterViewController
/// is loaded (which never occurs in a UI-less background launch).
///
/// The lookup is by ObjC runtime name instead of a compile-time import because
/// the Swift target depends on the ObjC target; the reverse import would be
/// circular. The `@objc(NWMBootstrap)` attribute pins the unmangled runtime
/// name — do not rename either side independently.
@objc(NWMBootstrap)
public final class NWMBootstrap: NSObject {

    /// Attaches BGTaskSchedulerManager's handlers if not yet attached.
    /// Idempotent and safe to call from any thread at any time.
    @objc public static func ensureAttached() {
        if #available(iOS 13.0, *) {
            BGTaskSchedulerManager.shared.registerHandlers()
        }
    }
}
