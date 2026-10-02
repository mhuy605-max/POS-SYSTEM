import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database_provider.dart';
import 'shop_settings_repository.dart';

final shopSettingsRepositoryProvider = Provider<ShopSettingsRepository>((ref) {
  return ShopSettingsRepository(ref.watch(appDatabaseProvider));
});

final shopSettingsProvider = StreamProvider.autoDispose<ShopSettings>((ref) {
  return ref.watch(shopSettingsRepositoryProvider).watch();
});

final shopSettingsControllerProvider =
    AsyncNotifierProvider<ShopSettingsController, void>(
      ShopSettingsController.new,
    );

final class ShopSettingsController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> save(ShopSettingsDraft draft) async {
    state = const AsyncLoading<void>();
    state = await AsyncValue.guard(
      () => ref.read(shopSettingsRepositoryProvider).save(draft),
    );
    if (state.hasError) {
      Error.throwWithStackTrace(state.error!, state.stackTrace!);
    }
  }
}
