import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rmplanner/app/router/route_names.dart';
import 'package:rmplanner/app/router/startup_route_guard.dart';
import 'package:rmplanner/app/shell/main_shell.dart';
import 'package:rmplanner/features/planner/domain/calendar_event.dart';
import 'package:rmplanner/features/planner/domain/planner_date.dart';
import 'package:rmplanner/features/planner/presentation/calendar_event_detail_screen.dart';
import 'package:rmplanner/features/planner/presentation/calendar_event_form_screen.dart';
import 'package:rmplanner/features/planner/presentation/planner_screen.dart';
import 'package:rmplanner/features/planner/presentation/task_detail_screen.dart';
import 'package:rmplanner/features/planner/presentation/task_form_screen.dart';
import 'package:rmplanner/features/privacy/presentation/diagnostic_preview_screen.dart';
import 'package:rmplanner/features/privacy/presentation/permissions_screen.dart';
import 'package:rmplanner/features/privacy/presentation/privacy_center_screen.dart';
import 'package:rmplanner/features/startup/application/startup_providers.dart';
import 'package:rmplanner/features/startup/presentation/home_screen.dart';
import 'package:rmplanner/features/startup/presentation/link_recovery_screen.dart';
import 'package:rmplanner/features/startup/presentation/onboarding_screen.dart';
import 'package:rmplanner/features/startup/presentation/protected_content_screen.dart';
import 'package:rmplanner/features/startup/presentation/recovery_screen.dart';
import 'package:rmplanner/features/startup/presentation/startup_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final startupState = ref.watch(startupControllerProvider);
  final router = GoRouter(
    initialLocation: RoutePaths.startup,
    redirect: (context, state) {
      return StartupRouteGuard.redirect(
        state: startupState,
        currentLocation: state.matchedLocation,
      );
    },
    routes: <RouteBase>[
      GoRoute(
        name: RouteNames.startup,
        path: RoutePaths.startup,
        builder: (context, state) => const StartupScreen(),
      ),
      GoRoute(
        name: RouteNames.onboarding,
        path: RoutePaths.onboarding,
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        name: RouteNames.recovery,
        path: RoutePaths.recovery,
        builder: (context, state) => const RecoveryScreen(),
      ),
      GoRoute(
        name: RouteNames.protectedContent,
        path: RoutePaths.protectedContent,
        builder: (context, state) => const ProtectedContentScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: <RouteBase>[
          GoRoute(
            name: RouteNames.home,
            path: RoutePaths.home,
            builder: (context, state) => const HomeScreen(),
          ),
          GoRoute(
            name: RouteNames.planner,
            path: RoutePaths.planner,
            builder: (context, state) => const PlannerScreen(),
          ),
        ],
      ),
      GoRoute(
        name: RouteNames.taskCreate,
        path: RoutePaths.taskCreate,
        builder: (context, state) {
          final rawDate = state.uri.queryParameters['date'];
          return TaskFormScreen.create(
            initialDueDate: rawDate == null ? null : PlannerDate.parse(rawDate),
          );
        },
      ),
      GoRoute(
        name: RouteNames.taskDetail,
        path: '${RoutePaths.tasks}/:taskId',
        builder: (context, state) {
          return TaskDetailScreen(taskId: state.pathParameters['taskId']!);
        },
        routes: <RouteBase>[
          GoRoute(
            name: RouteNames.taskEdit,
            path: 'edit',
            builder: (context, state) {
              return TaskFormScreen.edit(
                taskId: state.pathParameters['taskId']!,
              );
            },
          ),
        ],
      ),
      GoRoute(
        name: RouteNames.calendarEventCreate,
        path: RoutePaths.calendarEventCreate,
        builder: (context, state) {
          final rawDate = state.uri.queryParameters['date'];
          return CalendarEventFormScreen.create(
            initialDate: rawDate == null
                ? PlannerDate.fromDateTime(DateTime.now())
                : PlannerDate.parse(rawDate),
          );
        },
      ),
      GoRoute(
        name: RouteNames.calendarEventDetail,
        path: '${RoutePaths.calendarEvents}/:eventId/:originalDate',
        builder: (context, state) => CalendarEventDetailScreen(
          eventId: state.pathParameters['eventId']!,
          originalDate: PlannerDate.parse(
            state.pathParameters['originalDate']!,
          ),
        ),
        routes: <RouteBase>[
          GoRoute(
            name: RouteNames.calendarEventEdit,
            path: 'edit',
            builder: (context, state) {
              final rawScope = state.uri.queryParameters['scope'];
              return CalendarEventFormScreen.edit(
                eventId: state.pathParameters['eventId']!,
                originalDate: PlannerDate.parse(
                  state.pathParameters['originalDate']!,
                ),
                scope: rawScope == null
                    ? CalendarEventEditScope.occurrence
                    : CalendarEventEditScope.values.byName(rawScope),
              );
            },
          ),
          GoRoute(
            name: RouteNames.calendarEventReschedule,
            path: 'reschedule',
            builder: (context, state) {
              final rawScope = state.uri.queryParameters['scope'];
              return CalendarEventFormScreen.reschedule(
                eventId: state.pathParameters['eventId']!,
                originalDate: PlannerDate.parse(
                  state.pathParameters['originalDate']!,
                ),
                scope: rawScope == null
                    ? CalendarEventEditScope.occurrence
                    : CalendarEventEditScope.values.byName(rawScope),
              );
            },
          ),
        ],
      ),
      GoRoute(
        name: RouteNames.privacyCenter,
        path: RoutePaths.privacyCenter,
        builder: (context, state) => const PrivacyCenterScreen(),
      ),
      GoRoute(
        name: RouteNames.permissions,
        path: RoutePaths.permissions,
        builder: (context, state) => const PermissionsScreen(),
      ),
      GoRoute(
        name: RouteNames.diagnosticPreview,
        path: RoutePaths.diagnosticPreview,
        builder: (context, state) => const DiagnosticPreviewScreen(),
      ),
    ],
    errorBuilder: (context, state) =>
        LinkRecoveryScreen(attemptedLocation: state.uri.toString()),
  );
  ref.onDispose(router.dispose);
  return router;
});
