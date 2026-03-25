import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:masapp/core/config/theme_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('ThemeProvider toggles app theme mode', (
    WidgetTester tester,
  ) async {
    final provider = ThemeProvider();

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => provider,
        child: Consumer<ThemeProvider>(
          builder: (context, theme, _) {
            return MaterialApp(
              themeMode: theme.themeMode,
              home: Scaffold(
                body: Text(
                  theme.themeMode.toString(),
                  textDirection: TextDirection.ltr,
                ),
              ),
            );
          },
        ),
      ),
    );

    expect(find.text('ThemeMode.system'), findsOneWidget);

    await provider.setDarkMode();
    await tester.pump();
    expect(find.text('ThemeMode.dark'), findsOneWidget);

    await provider.setLightMode();
    await tester.pump();
    expect(find.text('ThemeMode.light'), findsOneWidget);
  });
}
