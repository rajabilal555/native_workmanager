import Flutter
import UIKit

// Part of the Flutter 3.38+ UIScene lifecycle template. The example app uses
// the NEW template on purpose: it is the lifecycle where plugin registration
// happens after the app finishes launching, which crashed BGTaskScheduler
// registration in issue #36. Running the device test suite on this template
// is the regression coverage for that fix — do not revert to the pre-3.38
// AppDelegate-only template.
class SceneDelegate: FlutterSceneDelegate {

}
