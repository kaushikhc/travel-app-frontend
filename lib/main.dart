import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/branding/app_brand.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(_bundledLicenses);
  runApp(
    const ProviderScope(
      child: TravelApp(),
    ),
  );
}

class TravelApp extends ConsumerWidget {
  const TravelApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: AppBrand.name,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      routerConfig: router,
    );
  }
}

/// Licenses for files we bundle ourselves (fonts and seed data). Package
/// licenses are added by Flutter automatically. All appear in the
/// "Open-source licenses" screen on the Profile page.
Stream<LicenseEntry> _bundledLicenses() async* {
  final String inter = await rootBundle.loadString('assets/licenses/OFL-Inter.txt');
  final String outfit = await rootBundle.loadString('assets/licenses/OFL-Outfit.txt');
  final String data = await rootBundle.loadString('assets/licenses/DATA-CREDITS.txt');
  yield LicenseEntryWithLineBreaks(const <String>['Inter font'], inter);
  yield LicenseEntryWithLineBreaks(const <String>['Outfit font'], outfit);
  yield LicenseEntryWithLineBreaks(const <String>['Country and region data'], data);
}
