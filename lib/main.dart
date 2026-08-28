import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'app/system_ui.dart';
import 'core/config/mapbox_configuration.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  AppSystemUi.configure();
  MapboxConfiguration.initialize();
  runApp(const ProviderScope(child: FluirApp()));
}
