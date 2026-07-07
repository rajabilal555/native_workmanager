#import "NWMBGTaskRegistrar.h"
#import <BackgroundTasks/BackgroundTasks.h>

/// See NWMBGTaskRegistrar.h for the full rationale (Issue #36).
///
/// ⚠️ This file is the ONLY place in the plugin allowed to call
/// `BGTaskScheduler registerForTaskWithIdentifier:`. Swift code must go
/// through `registerIdentifierIfNeeded:` so registration failures are caught
/// (@try/@catch) instead of crashing the app — Swift cannot catch NSException.

// Kept in sync with BGTaskSchedulerManager.defaultTaskIdentifier / .refreshTaskIdentifier.
static NSString *const kNWMProcessingIdentifier = @"dev.brewkits.native_workmanager.task";
static NSString *const kNWMRefreshIdentifier = @"dev.brewkits.native_workmanager.refresh";

static NSMutableSet<NSString *> *gRegistered;
static NSMutableSet<NSString *> *gRegisteredInLoad;
static NSMutableDictionary<NSString *, NWMBGTaskHandler> *gHandlers;
static NSMutableDictionary<NSString *, NSMutableArray<BGTask *> *> *gBufferedTasks;
static NSMutableDictionary<NSString *, NSNumber *> *gRegisterAttempts;

@implementation NWMBGTaskRegistrar

+ (void)load {
    // +load runs at binary load time, before main() — guaranteed to be inside
    // the "before application finishes launching" window on every app template.
    gRegistered = [NSMutableSet set];
    gRegisteredInLoad = [NSMutableSet set];
    gHandlers = [NSMutableDictionary dictionary];
    gBufferedTasks = [NSMutableDictionary dictionary];
    gRegisterAttempts = [NSMutableDictionary dictionary];

    if (@available(iOS 13.0, *)) {
        for (NSString *identifier in self.pluginTaskIdentifiers) {
            if ([self registerIdentifierIfNeeded:identifier]) {
                [gRegisteredInLoad addObject:identifier];
            }
        }
    }
}

+ (NSArray<NSString *> *)pluginTaskIdentifiers {
    return @[ kNWMProcessingIdentifier, kNWMRefreshIdentifier ];
}

+ (BOOL)didRegisterIdentifier:(NSString *)identifier {
    @synchronized(self) {
        return [gRegistered containsObject:identifier];
    }
}

+ (BOOL)registerIdentifierIfNeeded:(NSString *)identifier {
    if (@available(iOS 13.0, *)) {
        @synchronized(self) {
            if ([gRegistered containsObject:identifier]) {
                return YES;
            }
            gRegisterAttempts[identifier] = @([gRegisterAttempts[identifier] intValue] + 1);

            // BGTaskScheduler throws if the identifier is not declared in
            // Info.plist > BGTaskSchedulerPermittedIdentifiers. Skip quietly:
            // apps that don't use background execution for this identifier
            // simply don't get a handler (matches previous behavior, where
            // setup_ios adds the identifiers).
            NSArray *permitted = [NSBundle.mainBundle
                objectForInfoDictionaryKey:@"BGTaskSchedulerPermittedIdentifiers"];
            if (![permitted isKindOfClass:[NSArray class]] || ![permitted containsObject:identifier]) {
                NSLog(@"native_workmanager: '%@' is not in Info.plist BGTaskSchedulerPermittedIdentifiers — "
                      @"background execution for it is disabled. Run `dart run native_workmanager:setup_ios` "
                      @"to configure.", identifier);
                return NO;
            }

            @try {
                BOOL accepted = [BGTaskScheduler.sharedScheduler
                    registerForTaskWithIdentifier:identifier
                                       usingQueue:nil
                                    launchHandler:^(BGTask *task) {
                                        [NWMBGTaskRegistrar dispatchTask:task forIdentifier:identifier];
                                    }];
                if (accepted) {
                    [gRegistered addObject:identifier];
                } else {
                    NSLog(@"native_workmanager: BGTaskScheduler rejected registration of '%@'.", identifier);
                }
                return accepted;
            } @catch (NSException *exception) {
                // Two known causes, both previously fatal (Issue #36):
                // - "All launch handlers must be registered before application
                //   finishes launching" — registration attempted too late
                //   (Flutter 3.38+ UIScene template) AND the +load hook did not
                //   run (should not happen when this target is linked).
                // - "Launch handler for task ... already registered" — duplicate
                //   registration (e.g. GeneratedPluginRegistrant re-run on a
                //   headless background engine).
                NSLog(@"native_workmanager: failed to register BGTask handler '%@': %@ — %@. "
                      @"Background execution for this identifier is disabled for this launch. "
                      @"See doc/TROUBLESHOOTING.md (Issue #36).",
                      identifier, exception.name, exception.reason);
                return NO;
            }
        }
    }
    return NO;
}

+ (void)setTaskHandler:(NWMBGTaskHandler)handler forIdentifier:(NSString *)identifier {
    NSArray<BGTask *> *toDrain = nil;
    @synchronized(self) {
        gHandlers[identifier] = [handler copy];
        toDrain = [gBufferedTasks[identifier] copy];
        [gBufferedTasks removeObjectForKey:identifier];
    }
    for (BGTask *task in toDrain) {
        handler(task);
    }
}

/// Entry point for every BGTask launch. Bootstraps the Swift side if needed,
/// then forwards to the attached handler — or buffers the task until one is
/// attached (cold-start background launch before any Swift code has run).
+ (void)dispatchTask:(BGTask *)task forIdentifier:(NSString *)identifier API_AVAILABLE(ios(13.0)) {
    // Runtime lookup instead of import: the Swift target depends on this
    // target, so importing Swift here would be a circular dependency.
    Class bootstrap = NSClassFromString(@"NWMBootstrap");
    SEL ensureAttached = NSSelectorFromString(@"ensureAttached");
    if ([bootstrap respondsToSelector:ensureAttached]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [bootstrap performSelector:ensureAttached];
#pragma clang diagnostic pop
    }

    NWMBGTaskHandler handler = nil;
    @synchronized(self) {
        handler = gHandlers[identifier];
        if (handler == nil) {
            // Buffer until the Swift side attaches. If it never does, let the
            // expiration handler complete the task so iOS doesn't penalize the app.
            NSMutableArray *buffer = gBufferedTasks[identifier];
            if (buffer == nil) {
                buffer = [NSMutableArray array];
                gBufferedTasks[identifier] = buffer;
            }
            [buffer addObject:task];
            __weak BGTask *weakTask = task;
            task.expirationHandler = ^{
                [weakTask setTaskCompletedWithSuccess:NO];
            };
            NSLog(@"native_workmanager: BGTask '%@' fired before the plugin attached a handler — buffered.",
                  identifier);
        }
    }
    if (handler != nil) {
        handler(task);
    }
}

+ (NSDictionary<NSString *, NSDictionary *> *)debugSnapshot {
    NSMutableDictionary *snapshot = [NSMutableDictionary dictionary];
    @synchronized(self) {
        for (NSString *identifier in self.pluginTaskIdentifiers) {
            snapshot[identifier] = @{
                // Explicit (BOOL) casts are load-bearing, not decoration: `@()` boxes
                // based on the expression's static C type. `containsObject:` is declared
                // to return BOOL so it boxes correctly on its own, but `!=` always
                // yields C `int` — without the cast, `@(a != nil)` boxes an NSNumber
                // int, which the Flutter standard codec decodes as Dart `int` (e.g. 1),
                // not `bool` (true), and integration test issue_36 catches exactly this.
                @"registered": @((BOOL)[gRegistered containsObject:identifier]),
                @"registeredInLoad": @((BOOL)[gRegisteredInLoad containsObject:identifier]),
                @"handlerAttached": @((BOOL)(gHandlers[identifier] != nil)),
                @"registerAttempts": gRegisterAttempts[identifier] ?: @0,
            };
        }
    }
    return snapshot;
}

@end
