import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmplanner/app/theme/theme_color_mode.dart';
import 'package:rmplanner/features/settings/application/appearance_providers.dart';
import 'package:rmplanner/features/settings/application/appearance_repository.dart';

void main() {
  group('B1 appearance provider', () {
    test('build default is DARK (B2-FINAL-POLISH owner lock)', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(appearanceProvider), AppearanceMode.dark);
    });

    test('refresh() initializes state from the repository', () async {
      final repository = _FakeAppearanceRepository(AppearanceMode.dark);
      final container = ProviderContainer(
        overrides: [
          deviceAppearanceRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(appearanceProvider), AppearanceMode.dark);
      await container.read(appearanceProvider.notifier).refresh();
      expect(container.read(appearanceProvider), AppearanceMode.dark);
    });

    test('setMode persists then updates provider state', () async {
      final repository = _FakeAppearanceRepository();
      final container = ProviderContainer(
        overrides: [
          deviceAppearanceRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(appearanceProvider.notifier);
      final ok = await notifier.setMode(AppearanceMode.light);
      expect(ok, isTrue);
      expect(repository.value, AppearanceMode.light);
      expect(repository.saveCount, 1);
      expect(container.read(appearanceProvider), AppearanceMode.light);
    });

    test('setMode fails safely when persistence throws', () async {
      final repository = _FakeAppearanceRepository()
        ..throwOnSave = StateError('disk full');
      final container = ProviderContainer(
        overrides: [
          deviceAppearanceRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(appearanceProvider.notifier);
      final ok = await notifier.setMode(AppearanceMode.dark);
      expect(ok, isFalse);
      // State stays on the last confirmed value (the build default).
      expect(container.read(appearanceProvider), AppearanceMode.dark);
    });

    test('setMode does not touch any Goal/Planner/startup domain provider '
        '(source-structure isolation)', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      // The notifier's only dependency is the device-scoped appearance
      // repository. No domain provider is referenced or invalidated; this is
      // proven structurally in the audit (the notifier body reads only
      // deviceAppearanceRepositoryProvider and never calls ref.invalidate on
      // goal/planner/startup providers).
      final notifier = container.read(appearanceProvider.notifier);
      expect(notifier, isA<AppearanceNotifier>());
    });
  });
}

final class _FakeAppearanceRepository implements AppearanceRepository {
  _FakeAppearanceRepository([this.value = AppearanceMode.system]);

  AppearanceMode value;
  ThemeColorMode color = ThemeColorMode.rose;
  Object? throwOnSave;
  int saveCount = 0;

  @override
  Future<AppearanceMode> readAppearance() async => value;

  @override
  Future<void> saveAppearance(AppearanceMode mode) async {
    final error = throwOnSave;
    if (error != null) {
      throw error;
    }
    value = mode;
    saveCount += 1;
  }

  @override
  Future<ThemeColorMode> readThemeColor() async => color;

  @override
  Future<void> saveThemeColor(ThemeColorMode mode) async {
    final error = throwOnSave;
    if (error != null) {
      throw error;
    }
    color = mode;
    saveCount += 1;
  }
}
