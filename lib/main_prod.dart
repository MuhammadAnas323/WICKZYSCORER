// lib/main_prod.dart
import 'package:sportyapp/firebase_options_prod.dart' as prod_options;
import 'main.dart';

void main() {
  mainCommon(prod_options.DefaultFirebaseOptions.currentPlatform);
}