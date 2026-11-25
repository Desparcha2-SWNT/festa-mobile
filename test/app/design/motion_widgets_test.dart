import 'package:festa/app/design/design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Monta [child] en una app mínima. [reduced] simula el ajuste "reducir animaciones" del teléfono.
Widget _app(Widget child, {bool reduced = false}) => MaterialApp(
  home: Builder(
    builder: (context) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
      child: Scaffold(body: Center(child: child)),
    ),
  ),
);

void main() {
  group('FestaCelebration', () {
    Future<void> showFrom(WidgetTester tester, {bool reduced = false, VoidCallback? onTapBehind}) async {
      await tester.pumpWidget(
        _app(
          Builder(
            builder: (context) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FilledButton(
                  key: const Key('celebrate'),
                  onPressed: () => FestaCelebration.show(context, title: '¡Vas a este plan!', message: 'Te esperamos'),
                  child: const Text('Celebrar'),
                ),
                TextButton(key: const Key('behind'), onPressed: onTapBehind, child: const Text('Detrás')),
              ],
            ),
          ),
          reduced: reduced,
        ),
      );
      await tester.tap(find.byKey(const Key('celebrate')));
      await tester.pump();
    }

    testWidgets('muestra el título y se quita sola', (tester) async {
      await showFrom(tester);
      await tester.pump(FestaMotion.celebrate * 0.5);
      expect(find.text('¡Vas a este plan!'), findsOneWidget);
      expect(find.text('Te esperamos'), findsOneWidget);

      await tester.pumpAndSettle();
      expect(find.byType(FestaCelebrationView), findsNothing);
    });

    testWidgets('no bloquea los toques de la pantalla de atrás', (tester) async {
      var tapped = false;
      await showFrom(tester, onTapBehind: () => tapped = true);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(FestaCelebrationView), findsOneWidget);

      await tester.tap(find.byKey(const Key('behind')));
      expect(tapped, isTrue);
      await tester.pumpAndSettle();
    });

    testWidgets('con "reducir animaciones" no hay confeti y termina antes', (tester) async {
      await showFrom(tester, reduced: true);
      final view = tester.widget<FestaCelebrationView>(find.byType(FestaCelebrationView));
      expect(view.confetti, isFalse);
      expect(view.reduced, isTrue);

      await tester.pump(const Duration(milliseconds: 1200));
      expect(find.byType(FestaCelebrationView), findsNothing);
    });
  });

  group('FestaShake', () {
    double dx(WidgetTester tester) => tester
        .widget<Transform>(find.descendant(of: find.byType(FestaShake), matching: find.byType(Transform)))
        .transform
        .getTranslation()
        .x;

    Widget shake(Object? trigger) => _app(FestaShake(trigger: trigger, child: const Text('QR')));

    testWidgets('se sacude cuando cambia el disparador y vuelve al centro', (tester) async {
      await tester.pumpWidget(shake(null));
      await tester.pumpWidget(shake(1));
      await tester.pump(FestaMotion.slow * 0.08);
      expect(dx(tester), isNot(0));

      await tester.pumpAndSettle();
      expect(dx(tester), closeTo(0, 0.01));
    });

    testWidgets('el mismo disparador no la repite', (tester) async {
      await tester.pumpWidget(shake(1));
      await tester.pumpAndSettle();
      await tester.pumpWidget(shake(1));
      await tester.pump(FestaMotion.slow * 0.08);
      expect(dx(tester), closeTo(0, 0.01));
    });
  });

  testWidgets('FestaAnimatedCount cuenta hasta el valor nuevo', (tester) async {
    Widget count(int value) => _app(FestaAnimatedCount(value: value, builder: (_, shown) => Text('$shown van')));

    await tester.pumpWidget(count(3));
    expect(find.text('3 van'), findsOneWidget);

    await tester.pumpWidget(count(4));
    await tester.pumpAndSettle();
    expect(find.text('4 van'), findsOneWidget);
  });

  testWidgets('FestaFadeSlideIn con "reducir animaciones" aparece de una', (tester) async {
    await tester.pumpWidget(_app(const FestaFadeSlideIn(index: 5, child: Text('Hola')), reduced: true));
    await tester.pump();
    final fade = tester.widget<FadeTransition>(
      find.ancestor(of: find.text('Hola'), matching: find.byType(FadeTransition)).first,
    );
    expect(fade.opacity.value, 1);
  });
}
