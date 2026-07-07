#import <Foundation/Foundation.h>

@class BGTask;

NS_ASSUME_NONNULL_BEGIN

typedef void (^NWMBGTaskHandler)(BGTask *task);

/// Early BGTaskScheduler launch-handler registrar (Issue #36).
///
/// **Why this class exists — read before touching:**
///
/// Apple requires that ALL `BGTaskScheduler.register(forTaskWithIdentifier:)`
/// calls complete "before application finishes launching". Registering later
/// throws `NSInternalInconsistencyException` and crashes the app at startup.
///
/// Flutter 3.38+ migrated the iOS app template to the UIScene lifecycle.
/// On that template, plugins are registered from
/// `AppDelegate.didInitializeImplicitFlutterEngine`, which fires when the
/// FlutterViewController is loaded from the storyboard — AFTER
/// `application(_:didFinishLaunchingWithOptions:)` has already returned.
/// So any plugin that calls `BGTaskScheduler.register` during normal plugin
/// registration crashes on the new template (Issue #36, iPhone 15 / iOS 18.6.2).
///
/// This class fixes that by registering the launch handlers in ObjC `+load`,
/// which runs when the binary is loaded — long before the launch deadline —
/// regardless of which Flutter template or app lifecycle the host app uses.
///
/// **Why ObjC and not Swift:**
/// 1. Swift has no `+load` equivalent (static initializers are lazy, and by
///    the time any plugin Swift code runs on the new template it is already
///    too late).
/// 2. Swift cannot catch `NSException`. All `BGTaskScheduler.register` calls
///    in this plugin MUST go through this class so that registration problems
///    (too late / duplicate / identifier missing from Info.plist) degrade to
///    an error log instead of a startup crash.
///
/// **Task flow:** the launch handler registered here forwards each BGTask to
/// the Swift side (`BGTaskSchedulerManager`) via the handler installed with
/// `setTaskHandler:forIdentifier:`. If a task fires before the Swift side has
/// attached (cold-start background launch), the task is buffered and the
/// Swift side is bootstrapped through the ObjC runtime
/// (`NSClassFromString(@"NWMBootstrap")`) — a runtime lookup is used because
/// the Swift target depends on this target, so a compile-time import in the
/// other direction would be circular.
@interface NWMBGTaskRegistrar : NSObject

/// Identifiers this plugin owns. Kept in sync with
/// `BGTaskSchedulerManager.defaultTaskIdentifier` / `.refreshTaskIdentifier`.
@property (class, nonatomic, readonly) NSArray<NSString *> *pluginTaskIdentifiers;

/// YES if the identifier has been successfully registered with BGTaskScheduler
/// (either in `+load` or via a later `registerIdentifierIfNeeded:` call).
+ (BOOL)didRegisterIdentifier:(NSString *)identifier;

/// Registers the identifier with BGTaskScheduler if not already registered.
/// Safe to call at any time: exceptions are caught and logged, never thrown.
/// Returns YES if the identifier is registered after this call.
+ (BOOL)registerIdentifierIfNeeded:(NSString *)identifier;

/// Installs the handler that receives BGTasks for the identifier and drains
/// any tasks buffered before the handler was attached.
+ (void)setTaskHandler:(NWMBGTaskHandler)handler forIdentifier:(NSString *)identifier;

/// Diagnostic snapshot for the `debugBGTaskRegistration` method-channel call
/// and the issue_36 device regression test.
/// Keys: identifier → @{ @"registered": NSNumber(bool),
///                       @"registeredInLoad": NSNumber(bool),
///                       @"handlerAttached": NSNumber(bool),
///                       @"registerAttempts": NSNumber(int) }
+ (NSDictionary<NSString *, NSDictionary *> *)debugSnapshot;

@end

NS_ASSUME_NONNULL_END
