import 'package:flutter/material.dart';

import 'theme.dart';

abstract final class AppSpacing {
  static const x1 = 4.0;
  static const x2 = 8.0;
  static const x3 = 12.0;
  static const x4 = 16.0;
  static const x5 = 20.0;
  static const x6 = 24.0;
  static const x8 = 32.0;
  static const screen = x4;
}

abstract final class AppRadii {
  static const field = 12.0;
  static const button = 13.0;
  static const card = 16.0;
  static const dialog = 20.0;
  static const pill = 999.0;
}

abstract final class AppSizes {
  static const touchTarget = 48.0;
  static const buttonHeight = 52.0;
  static const icon = 24.0;
  static const iconSmall = 20.0;
}

abstract final class AppMotion {
  static const fast = Duration(milliseconds: 120);
  static const standard = Duration(milliseconds: 180);
  static const spatial = Duration(milliseconds: 220);
  static const curve = Curves.easeOutCubic;

  static Duration duration(BuildContext context, Duration preferred) =>
      MediaQuery.maybeOf(context)?.disableAnimations == true
      ? Duration.zero
      : preferred;
}

enum AppStatusTone { brand, success, warning, error, neutral, information }

extension AppStatusToneColors on AppStatusTone {
  Color get foreground => switch (this) {
    AppStatusTone.brand => AppColors.primaryStrong,
    AppStatusTone.success => AppColors.success,
    AppStatusTone.warning => AppColors.warning,
    AppStatusTone.error => AppColors.error,
    AppStatusTone.neutral => AppColors.secondaryInk,
    AppStatusTone.information => AppColors.information,
  };

  Color get background => switch (this) {
    AppStatusTone.brand => AppColors.primarySoft,
    AppStatusTone.success => AppColors.successSoft,
    AppStatusTone.warning => AppColors.warningSoft,
    AppStatusTone.error => AppColors.errorSoft,
    AppStatusTone.neutral => AppColors.surfaceLow,
    AppStatusTone.information => AppColors.informationSoft,
  };
}

class AppStatusBadge extends StatelessWidget {
  const AppStatusBadge({required this.label, required this.tone, super.key});
  final String label;
  final AppStatusTone tone;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: AppMotion.duration(context, AppMotion.standard),
    curve: AppMotion.curve,
    decoration: BoxDecoration(
      color: tone.background,
      borderRadius: BorderRadius.circular(AppRadii.pill),
    ),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    child: Text(
      label,
      style: TextStyle(
        color: tone.foreground,
        fontSize: 11,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.actionKey,
    super.key,
  });
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Key? actionKey;

  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.x8),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            DecoratedBox(
              decoration: const BoxDecoration(
                color: AppColors.surfaceLow,
                shape: BoxShape.circle,
              ),
              child: SizedBox.square(
                dimension: 64,
                child: Icon(icon, color: AppColors.secondaryInk, size: 28),
              ),
            ),
            const SizedBox(height: AppSpacing.x4),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.x2),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: AppColors.secondaryInk),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: AppSpacing.x5),
              FilledButton(
                key: actionKey,
                onPressed: onAction,
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

class AppLoadingState extends StatelessWidget {
  const AppLoadingState({this.label = 'Đang tải…', super.key});
  final String label;

  @override
  Widget build(BuildContext context) => Center(
    child: Semantics(
      label: label,
      child: const SizedBox.square(
        dimension: 28,
        child: CircularProgressIndicator(strokeWidth: 2.5),
      ),
    ),
  );
}

class AppAsyncError extends StatelessWidget {
  const AppAsyncError({required this.message, this.onRetry, super.key});
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => AppEmptyState(
    icon: Icons.error_outline,
    title: 'Có lỗi xảy ra',
    message: message,
    actionLabel: onRetry == null ? null : 'Thử lại',
    onAction: onRetry,
  );
}

class AppAnimatedValue extends StatelessWidget {
  const AppAnimatedValue({required this.value, required this.child, super.key});
  final Object value;
  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: AppMotion.duration(context, AppMotion.standard),
    switchInCurve: AppMotion.curve,
    switchOutCurve: Curves.easeIn,
    transitionBuilder: (child, animation) => FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, .08),
          end: Offset.zero,
        ).animate(animation),
        child: child,
      ),
    ),
    child: KeyedSubtree(key: ValueKey(value), child: child),
  );
}

class AppBottomActionSurface extends StatelessWidget {
  const AppBottomActionSurface({required this.child, super.key});
  final Widget child;

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.outline)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        child: child,
      ),
    ),
  );
}

class AppPressable extends StatefulWidget {
  const AppPressable({
    required this.child,
    required this.onTap,
    this.borderRadius = AppRadii.card,
    super.key,
  });
  final Widget child;
  final VoidCallback? onTap;
  final double borderRadius;

  @override
  State<AppPressable> createState() => _AppPressableState();
}

class _AppPressableState extends State<AppPressable> {
  var _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) => AnimatedScale(
    scale: _pressed ? .985 : 1,
    duration: AppMotion.duration(context, AppMotion.fast),
    curve: AppMotion.curve,
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onTap,
        onHighlightChanged: widget.onTap == null ? null : _setPressed,
        borderRadius: BorderRadius.circular(widget.borderRadius),
        child: widget.child,
      ),
    ),
  );
}
