import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:litratolink/app/app.dart';
import 'package:litratolink/config/env.dart';

void main() {
  testWidgets('shows the Potoos splash screen', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appEnvProvider.overrideWithValue(
            const AppEnv(
              appEnv: 'test',
              supabaseUrl: '',
              supabaseAnonKey: '',
              googleWebClientId: '',
              googleIosClientId: '',
            ),
          ),
        ],
        child: const PotoosApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 2000));
    await tester.pump();

    expect(find.text('Original memories, safely shared.'), findsWidgets);
  });
}
