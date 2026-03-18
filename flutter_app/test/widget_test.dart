import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readlepress/widgets/observation_form.dart';

void main() {
  testWidgets('ObservationForm placeholder renders', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: ObservationForm(),
        ),
      ),
    );
    expect(find.text('Observation Form'), findsOneWidget);
  });
}
