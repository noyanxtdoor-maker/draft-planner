// Pack 3 — honest local Messages shell.
//
// The Home bell and the drawer Messages destination must open the same
// canonical screen with a truthful empty state, no remote behavior, no
// fabricated unread count, and no Android permission routing.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmplanner/core/diagnostics/sanitized_diagnostics.dart';
import 'package:rmplanner/core/platform/app_environment.dart';
import 'package:rmplanner/features/privacy/presentation/permissions_screen.dart';
import 'package:rmplanner/features/shell/messages_screen.dart';
import 'package:rmplanner/features/startup/presentation/home_screen.dart';

import '../../support/test_dependencies.dart';

void main() {
  Future<void> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(431, 912);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final database = openMemoryDatabase();
    addTearDown(database.close);
    final privacy = TestPrivacyDependencies(database: database);
    final startup = buildTestRepository(
      database: database,
      privacyGate: privacy.gate,
    );
    await startup.completeOnboarding();
    await tester.pumpWidget(
      privacy.buildApp(
        environment: const AppEnvironment(
          name: AppEnvironmentName.production,
          label: 'PRODUCTION',
        ),
        diagnostics: SanitizedDiagnostics(),
        startupRepository: startup,
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openDrawer(WidgetTester tester, String entryId) async {
    await tester.tap(find.byKey(const Key('home-hamburger')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(Key(entryId)),
      200,
      scrollable: find.descendant(
        of: find.byKey(const Key('global-app-drawer-list')),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key(entryId)));
    await tester.pumpAndSettle();
  }

  testWidgets('Home bell opens the canonical Messages screen, never '
      'permissions', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.byKey(const Key('home-messages')));
    await tester.pumpAndSettle();
    expect(find.byType(MessagesScreen), findsOneWidget);
    expect(find.byType(PermissionsScreen), findsNothing);
    expect(find.text('No messages yet.'), findsOneWidget);
    expect(find.byKey(const Key('messages-empty-body')), findsOneWidget);
    // No fake unread badge or message content is fabricated.
    expect(find.text('Not requested'), findsNothing);
    expect(find.textContaining('1'), findsNothing);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('drawer Messages opens the same canonical screen', (
    tester,
  ) async {
    await pumpApp(tester);
    await openDrawer(tester, 'drawer-messages');
    expect(find.byType(MessagesScreen), findsOneWidget);
    expect(find.byType(PermissionsScreen), findsNothing);
    expect(find.text('No messages yet.'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
