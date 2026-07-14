// driver_main.dart is a flutter_driver harness entrypoint, not app code; it
// legitimately imports the flutter_driver dev dependency.
// ignore: depend_on_referenced_packages
import 'package:flutter_driver/driver_extension.dart';
import 'main.dart' as app;

void main() {
  enableFlutterDriverExtension();
  app.main();
}
