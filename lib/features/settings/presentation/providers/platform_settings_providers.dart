import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/providers/auth_provider.dart';
import '../../data/platform_settings_repository.dart';
import '../../domain/platform_settings.dart';

/// Override in tests with a fake.
final platformSettingsRepositoryProvider = Provider<PlatformSettingsRepository>(
  (ref) => FirestorePlatformSettingsRepository(ref.watch(firestoreProvider)),
);

/// Live `settings/platform`.
final platformSettingsStreamProvider = StreamProvider<PlatformSettings>(
  (ref) => ref.watch(platformSettingsRepositoryProvider).watch(),
);

/// What the rest of the app reads: never loading, never an error. Until the
/// document arrives (or if it cannot be read) the defaults apply.
final platformSettingsProvider = Provider<PlatformSettings>(
  (ref) => ref.watch(platformSettingsStreamProvider).maybeWhen(
        data: (s) => s,
        orElse: () => PlatformSettings.defaults,
      ),
);
