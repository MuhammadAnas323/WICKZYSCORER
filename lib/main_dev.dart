// lib/main_dev.dart
import 'package:sportyapp/firebase_options.dart' as dev_options;
import 'main.dart';

void main() {
  mainCommon(dev_options.DefaultFirebaseOptionsDev.currentPlatform);
}
