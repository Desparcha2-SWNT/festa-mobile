import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'router.dart';
import 'theme.dart';

class FestaApp extends ConsumerWidget {
  const FestaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp.router(
    title: 'Festa',
    debugShowCheckedModeBanner: false,
    theme: FestaTheme.light(),
    darkTheme: FestaTheme.dark(),
    routerConfig: ref.watch(routerProvider),
    // Español de Colombia para los textos de Material (calendario, reloj, botones de los diálogos).
    locale: const Locale('es', 'CO'),
    supportedLocales: const [Locale('es', 'CO')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
  );
}
