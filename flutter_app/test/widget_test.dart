import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:readlepress/widgets/mastery_level_indicator.dart';

void main() {
  group('MasteryLevelIndicator', () {
    testWidgets('renders foundational emojis', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MasteryLevelIndicator(
              numericValue: 0.75,
              stageCode: 'FOUNDATIONAL',
            ),
          ),
        ),
      );

      expect(find.text('🌊'), findsOneWidget);
      expect(find.text('⛰️'), findsOneWidget);
      expect(find.text('🌤️'), findsOneWidget);
      expect(find.text('⭐'), findsOneWidget);
      expect(find.text('Star'), findsOneWidget);
    });

    testWidgets('renders preparatory label chip', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MasteryLevelIndicator(
              numericValue: 0.6,
              stageCode: 'PREPARATORY',
            ),
          ),
        ),
      );

      expect(find.text('Proficient'), findsOneWidget);
    });

    testWidgets('renders middle label with percentage', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MasteryLevelIndicator(
              numericValue: 0.5,
              stageCode: 'MIDDLE',
            ),
          ),
        ),
      );

      expect(find.text('Proficient'), findsOneWidget);
      expect(find.text('50%'), findsOneWidget);
    });

    testWidgets('renders secondary numeric with descriptor', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MasteryLevelIndicator(
              numericValue: 0.85,
              stageCode: 'SECONDARY',
            ),
          ),
        ),
      );

      expect(find.text('85'), findsOneWidget);
      expect(find.text('Advanced'), findsOneWidget);
    });

    testWidgets('handles zero value', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MasteryLevelIndicator(
              numericValue: 0.0,
              stageCode: 'PREPARATORY',
            ),
          ),
        ),
      );

      expect(find.text('Beginning'), findsOneWidget);
    });

    testWidgets('handles max value', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MasteryLevelIndicator(
              numericValue: 1.0,
              stageCode: 'SECONDARY',
            ),
          ),
        ),
      );

      expect(find.text('100'), findsOneWidget);
      expect(find.text('Advanced'), findsOneWidget);
    });
  });

  group('MasteryDot', () {
    testWidgets('renders with value', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MasteryDot(numericValue: 0.8),
          ),
        ),
      );

      expect(find.byType(MasteryDot), findsOneWidget);
    });

    testWidgets('renders with null value', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MasteryDot(numericValue: null),
          ),
        ),
      );

      expect(find.byType(MasteryDot), findsOneWidget);
    });
  });
}
