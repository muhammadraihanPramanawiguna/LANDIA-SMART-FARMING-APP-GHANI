
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:landiafarm_app/main.dart';

void main() {
  group('Landia Farm App Tests', () {
    testWidgets(
      'Aplikasi Landia Farm berhasil ditampilkan',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          const LandiaFarm(
            home: Scaffold(
              body: Center(
                child: Text('Landia Farm Test'),
              ),
            ),
          ),
        );

        expect(find.byType(MaterialApp), findsOneWidget);

        final app = tester.widget<MaterialApp>(
          find.byType(MaterialApp),
        );

        expect(app.title, 'Landia Farm');
        expect(find.text('Landia Farm Test'), findsOneWidget);
      },
    );

    testWidgets(
      'Tema aplikasi menggunakan warna hijau',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          const LandiaFarm(
            home: Scaffold(
              body: Text('Theme Test'),
            ),
          ),
        );

        final app = tester.widget<MaterialApp>(
          find.byType(MaterialApp),
        );

        final primaryColor = app.theme!.colorScheme.primary;

        // Memastikan warna utama berasal dari palet hijau.
        expect(primaryColor.g, greaterThan(primaryColor.r));
        expect(primaryColor.g, greaterThan(primaryColor.b));
      },
    );
  });
}
