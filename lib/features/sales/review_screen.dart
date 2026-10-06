import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/design_system.dart';
import '../../app/theme.dart';
import '../../core/money.dart';
import '../orders/order_repository.dart';
import '../products/catalog_controller.dart';
import '../products/product_option_repository.dart';
import 'cart_controller.dart';
import 'configure_item_sheet.dart';

class ReviewScreen extends ConsumerWidget {
  const ReviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final structure = ref.watch(
      cartControllerProvider.select(
        (cart) => (
          submitting: cart.isSubmitting,
          lineIds: cart.lines.map((line) => line.lineId).join(','),
        ),
      ),
    );
    final lineIds = ref
        .read(cartControllerProvider)
        .lines
        .map((line) => line.lineId)
        .toList(growable: false);
    return PopScope(
      canPop: !structure.submitting,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Đơn hiện tại'),
          actions: [
            if (lineIds.isNotEmpty && !structure.submitting)
              TextButton(
                onPressed: () => _confirmClear(context, ref),
                child: const Text('Xóa đơn'),
              ),
          ],
        ),
        body: Column(
          children: [
            const _OrderTypeSelector(),
            Expanded(
              child: lineIds.isEmpty
                  ? const AppEmptyState(
                      icon: Icons.shopping_bag_outlined,
                      title: 'Đơn hiện tại đang trống',
                      message: 'Quay lại Bán hàng để thêm món vào đơn.',
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: lineIds.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) => _CartLineCard(
                        key: ValueKey(lineIds[index]),
                        lineId: lineIds[index],
                      ),
                    ),
            ),
            _ReviewSummary(onSubmit: () => _submit(context, ref)),
          ],
        ),
      ),
    );
  }

  Future<void> _submit(BuildContext context, WidgetRef ref) async {
    try {
      final result = await ref.read(cartControllerProvider.notifier).submit();
      if (context.mounted && ModalRoute.of(context)?.isCurrent == true) {
        context.pop(result);
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Không thể lưu đơn. Món có thể đã thay đổi; hãy quay lại, '
              'kiểm tra giỏ hàng rồi thử lại.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _confirmClear(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa đơn hiện tại?'),
        content: const Text('Tất cả món và ghi chú trong đơn sẽ bị xóa.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Giữ lại'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xóa đơn'),
          ),
        ],
      ),
    );
    if (confirmed == true) ref.read(cartControllerProvider.notifier).clear();
  }
}

class _OrderTypeSelector extends ConsumerWidget {
  const _OrderTypeSelector();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(
      cartControllerProvider.select(
        (cart) => (orderType: cart.orderType, submitting: cart.isSubmitting),
      ),
    );
    void select(OrderType type) => ref
        .read(cartControllerProvider.notifier)
        .setOrderType(state.orderType == type ? null : type);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.outline),
          borderRadius: BorderRadius.circular(AppRadii.button),
        ),
        child: Padding(
          padding: const EdgeInsets.all(3),
          child: LayoutBuilder(
            builder: (context, constraints) => SizedBox(
              height: AppSizes.buttonHeight,
              child: Stack(
                children: [
                  AnimatedOpacity(
                    opacity: state.orderType == null ? 0 : 1,
                    duration: AppMotion.duration(context, AppMotion.selection),
                    child: AnimatedAlign(
                      alignment: state.orderType == OrderType.takeaway
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      duration: AppMotion.duration(
                        context,
                        AppMotion.orderType,
                      ),
                      curve: AppMotion.curve,
                      child: SizedBox(
                        width: constraints.maxWidth / 2,
                        height: AppSizes.buttonHeight,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: AppColors.primarySoft,
                            borderRadius: BorderRadius.circular(AppRadii.field),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: _TypeSegment(
                          label: 'Tại quán',
                          icon: Icons.storefront_outlined,
                          selected: state.orderType == OrderType.dineIn,
                          onPressed: state.submitting
                              ? null
                              : () => select(OrderType.dineIn),
                        ),
                      ),
                      Expanded(
                        child: _TypeSegment(
                          label: 'Mang về',
                          icon: Icons.takeout_dining_outlined,
                          selected: state.orderType == OrderType.takeaway,
                          onPressed: state.submitting
                              ? null
                              : () => select(OrderType.takeaway),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TypeSegment extends StatelessWidget {
  const _TypeSegment({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onPressed,
  });
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      label: label,
      onTap: onPressed,
      excludeSemantics: true,
      child: AnimatedOpacity(
        opacity: enabled ? 1 : .48,
        duration: AppMotion.duration(context, AppMotion.pressRelease),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            excludeFromSemantics: true,
            borderRadius: BorderRadius.circular(AppRadii.field),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TweenAnimationBuilder<Color?>(
                  tween: ColorTween(
                    end: selected
                        ? AppColors.primaryStrong
                        : AppColors.secondaryInk,
                  ),
                  duration: AppMotion.duration(context, AppMotion.selection),
                  builder: (context, color, _) => Icon(icon, color: color),
                ),
                const SizedBox(width: 8),
                AnimatedDefaultTextStyle(
                  duration: AppMotion.duration(context, AppMotion.selection),
                  curve: AppMotion.curve,
                  style: TextStyle(
                    color: selected
                        ? AppColors.primaryStrong
                        : AppColors.secondaryInk,
                    fontWeight: FontWeight.w700,
                  ),
                  child: Text(label),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReviewSummary extends ConsumerWidget {
  const _ReviewSummary({required this.onSubmit});

  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(
      cartControllerProvider.select(
        (cart) => (
          total: cart.total,
          empty: cart.lines.isEmpty,
          submitting: cart.isSubmitting,
        ),
      ),
    );
    return AppBottomActionSurface(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Text(
                'Tổng cộng',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              AppAnimatedValue(
                value: summary.total,
                child: Text(
                  formatVnd(summary.total),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryStrong,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            key: const Key('submit-order'),
            onPressed: summary.empty || summary.submitting ? null : onSubmit,
            icon: summary.submitting
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.print_outlined),
            label: Text('In bill • ${formatVnd(summary.total)}'),
          ),
          const SizedBox(height: 5),
          const Text(
            'Đơn được lưu trước, sau đó gửi đến máy in đã chọn',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: AppColors.secondaryInk),
          ),
        ],
      ),
    );
  }
}

class _CartLineCard extends ConsumerStatefulWidget {
  const _CartLineCard({required super.key, required this.lineId});
  final int lineId;

  @override
  ConsumerState<_CartLineCard> createState() => _CartLineCardState();
}

class _CartLineCardState extends ConsumerState<_CartLineCard> {
  late final TextEditingController _noteController;
  late final FocusNode _noteFocus;
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    _noteController = TextEditingController();
    _noteFocus = FocusNode();
  }

  @override
  void dispose() {
    _noteController.dispose();
    _noteFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = ref.watch(
      cartControllerProvider.select((cart) {
        CartLine? line;
        for (final candidate in cart.lines) {
          if (candidate.lineId == widget.lineId) {
            line = candidate;
            break;
          }
        }
        return (line: line, enabled: !cart.isSubmitting);
      }),
    );
    final line = snapshot.line;
    if (line == null) return const SizedBox.shrink();
    final external = line.note ?? '';
    if (!_noteFocus.hasFocus && _noteController.text != external) {
      _noteController.value = TextEditingValue(
        text: external,
        selection: TextSelection.collapsed(offset: external.length),
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        line.productName,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        '${formatVnd(line.unitPrice)} / phần',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.secondaryInk,
                        ),
                      ),
                      if (line.selectedOptions.isNotEmpty)
                        TextButton.icon(
                          key: Key('edit-cart-line-${line.lineId}'),
                          onPressed: snapshot.enabled && !_editing
                              ? () => _editConfiguration(line)
                              : null,
                          icon: _editing
                              ? const SizedBox.square(
                                  dimension: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.tune_rounded, size: 18),
                          label: const Text('Sửa tùy chọn'),
                        ),
                    ],
                  ),
                ),
                AppAnimatedValue(
                  value: line.lineTotal,
                  child: Text(
                    formatVnd(line.lineTotal),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            if (line.selectedOptions.isNotEmpty) ...[
              const SizedBox(height: 6),
              for (final option in line.selectedOptions)
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '+ ${option.optionName}',
                          key: Key(
                            'cart-option-${line.lineId}-${option.optionItemId}',
                          ),
                          style: const TextStyle(
                            color: AppColors.secondaryInk,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Text(
                            option.priceDelta == 0
                                ? '0đ'
                                : '+${formatVnd(option.priceDelta)}',
                            style: const TextStyle(
                              color: AppColors.secondaryInk,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
            const SizedBox(height: 8),
            TextField(
              key: Key('cart-note-${line.lineId}'),
              controller: _noteController,
              focusNode: _noteFocus,
              enabled: snapshot.enabled,
              onChanged: (value) => ref
                  .read(cartControllerProvider.notifier)
                  .setNote(line.lineId, value),
              decoration: const InputDecoration(
                hintText: 'Ghi chú cho món',
                prefixIcon: Icon(Icons.edit_note),
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton(
                  key: Key('remove-cart-line-${line.lineId}'),
                  onPressed: snapshot.enabled
                      ? () => ref
                            .read(cartControllerProvider.notifier)
                            .remove(line.lineId)
                      : null,
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Bỏ món',
                ),
                const Spacer(),
                IconButton(
                  onPressed: snapshot.enabled
                      ? () => ref
                            .read(cartControllerProvider.notifier)
                            .decrement(line.lineId)
                      : null,
                  icon: const Icon(Icons.remove),
                  tooltip: 'Giảm',
                ),
                SizedBox(
                  width: 36,
                  child: AppAnimatedValue(
                    value: line.quantity,
                    child: Text(
                      '${line.quantity}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: snapshot.enabled
                      ? () => ref
                            .read(cartControllerProvider.notifier)
                            .increment(line.lineId)
                      : null,
                  icon: const Icon(Icons.add),
                  tooltip: 'Tăng',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editConfiguration(CartLine line) async {
    if (_editing) return;
    setState(() => _editing = true);
    try {
      final repository = ref.read(productOptionRepositoryProvider);
      final groups = await repository.listSelectableGroupsForSales(
        line.productId,
      );
      final ids = [
        for (final group in groups)
          for (final option in group.items) option.id,
      ];
      final current = ids.isEmpty
          ? const <ResolvedProductOption>[]
          : await repository.resolveSelectableOptions(line.productId, ids);
      if (!mounted) return;
      await showConfigureItemSheet(
        context: context,
        productId: line.productId,
        productName: line.productName,
        baseUnitPrice: line.baseUnitPrice,
        selectableOptions: current,
        existingLine: line,
        onSubmit: (options, note) async {
          try {
            final changed = ref
                .read(cartControllerProvider.notifier)
                .editConfiguration(
                  line.lineId,
                  selectedOptions: options,
                  note: note,
                );
            return changed ? null : 'Không thể cập nhật món trong đơn.';
          } on DomainValidationException {
            return 'Giá món vượt giới hạn hỗ trợ. Hãy bỏ bớt tùy chọn.';
          }
        },
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Cấu hình món đã thay đổi. Hãy kiểm tra lại tùy chọn.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _editing = false);
    }
  }
}
