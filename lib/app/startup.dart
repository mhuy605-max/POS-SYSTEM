import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../backup/backup_providers.dart';
import '../backup/restore_service.dart';
import '../data/app_database.dart';
import '../data/database_provider.dart';
import '../features/products/product_image_store.dart';
import 'app.dart';
import 'theme.dart';

typedef StartupInitializer = Future<StartupDependencies> Function();

final class StartupDependencies {
  const StartupDependencies({
    required this.database,
    required this.restoreService,
  });

  final AppDatabase database;
  final BackupRestorer restoreService;

  Future<void> dispose() => database.close();
}

Future<StartupDependencies> initializeProductionApplication() async {
  AppDatabase? database;
  try {
    database = await openProductionDatabase();
    final support = await getApplicationSupportDirectory();
    final restoreService = RestoreService(
      database: database,
      imageStore: ProductImageStore(support),
      journalDirectory: Directory(
        '${support.path}${Platform.pathSeparator}.restore-recovery',
      ),
    );
    await restoreService.recoverPendingRestore();
    return StartupDependencies(
      database: database,
      restoreService: restoreService,
    );
  } catch (_) {
    await database?.close();
    rethrow;
  }
}

class StartupHost extends StatefulWidget {
  const StartupHost({
    required this.initialize,
    this.animateEntrance = true,
    super.key,
  });

  final StartupInitializer initialize;
  final bool animateEntrance;

  @override
  State<StartupHost> createState() => _StartupHostState();
}

class _StartupHostState extends State<StartupHost> {
  StartupDependencies? _dependencies;
  Object? _error;
  var _attempt = 0;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    final attempt = ++_attempt;
    setState(() => _error = null);
    try {
      final dependencies = await widget.initialize();
      if (!mounted || attempt != _attempt) {
        await dependencies.dispose();
        return;
      }
      setState(() => _dependencies = dependencies);
    } catch (error) {
      if (mounted && attempt == _attempt) setState(() => _error = error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dependencies = _dependencies;
    if (dependencies != null) {
      return ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWith((ref) {
            ref.onDispose(dependencies.database.close);
            return dependencies.database;
          }),
          restoreServiceProvider.overrideWithValue(dependencies.restoreService),
        ],
        child: DakaoInBillApp(animateEntrance: widget.animateEntrance),
      );
    }
    return MaterialApp(
      title: 'Đakao In Bill',
      debugShowCheckedModeBanner: false,
      theme: appTheme,
      home: _StartupSurface(error: _error, onRetry: _initialize),
    );
  }
}

class _StartupSurface extends StatelessWidget {
  const _StartupSurface({required this.error, required this.onRetry});

  final Object? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.canvas,
    body: SafeArea(
      child: Stack(
        fit: StackFit.expand,
        children: [
          const Center(
            child: Image(
              image: AssetImage('assets/images/dakao_logo.png'),
              width: 111,
              height: 128,
              filterQuality: FilterQuality.high,
            ),
          ),
          Center(
            child: Transform.translate(
              offset: const Offset(0, 150),
              child: error == null
                  ? const _StartupLoading()
                  : _StartupError(onRetry: onRetry),
            ),
          ),
        ],
      ),
    ),
  );
}

class _StartupLoading extends StatelessWidget {
  const _StartupLoading();

  @override
  Widget build(BuildContext context) => Semantics(
    key: const Key('startup-loading'),
    label: 'Đang khởi động Đakao In Bill',
    child: const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Đakao In Bill',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        SizedBox(height: 14),
        SizedBox.square(
          dimension: 22,
          child: CircularProgressIndicator(strokeWidth: 2.4),
        ),
      ],
    ),
  );
}

class _StartupError extends StatelessWidget {
  const _StartupError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    key: const Key('startup-error'),
    constraints: const BoxConstraints(maxWidth: 320),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Không thể khởi động ứng dụng',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 6),
        const Text(
          'Không thể mở dữ liệu an toàn. Hãy thử lại.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.secondaryInk),
        ),
        const SizedBox(height: 14),
        FilledButton(onPressed: onRetry, child: const Text('Thử lại')),
      ],
    ),
  );
}
