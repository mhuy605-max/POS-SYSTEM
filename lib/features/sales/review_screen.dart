import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/design_system.dart';
import '../../app/theme.dart';
import '../../core/money.dart';
import '../orders/order_repository.dart';
import 'cart_controller.dart';

class ReviewScreen extends ConsumerWidget {
  const ReviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartControllerProvider);
    return PopScope(
      canPop: !cart.isSubmitting,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Đơn hiện tại'),
          actions: [
            if (cart.lines.isNotEmpty && !cart.isSubmitting)
              TextButton(
                onPressed: () => _confirmClear(context, ref),
                child: const Text('Xóa đơn'),
              ),
          ],
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Row(
                children: [
                  Expanded(
                    child: _TypeButton(
                      label: 'Tại quán',
                      icon: Icons.storefront_outlined,
                      selected: cart.orderType == OrderType.dineIn,
                      onPressed: cart.isSubmitting
                          ? null
                          : () => ref
                                .read(cartControllerProvider.notifier)
                                .setOrderType(
                                  cart.orderType == OrderType.dineIn
                                      ? null
                                      : OrderType.dineIn,
                                ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _TypeButton(
                      label: 'Mang về',
                      icon: Icons.takeout_dining_outlined,
                      selected: cart.orderType == OrderType.takeaway,
                      onPressed: cart.isSubmitting
                          ? null
                          : () => ref
                                .read(cartControllerProvider.notifier)
                                .setOrderType(
                                  cart.orderType == OrderType.takeaway
                                      ? null
                                      : OrderType.takeaway,
                                ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: cart.lines.isEmpty
                  ? const AppEmptyState(
                      icon: Icons.shopping_bag_outlined,
                      title: 'Đơn hiện tại đang trống',
                      message: 'Quay lại Bán hàng để thêm món vào đơn.',
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: cart.lines.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) => _CartLineCard(
                        key: ValueKey(cart.lines[index].lineId),
                        line: cart.lines[index],
                        enabled: !cart.isSubmitting,
                      ),
                    ),
            ),
            AppBottomActionSurface(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Tổng cộng',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      AppAnimatedValue(
                        value: cart.total,
                        child: Text(
                          formatVnd(cart.total),
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
                    onPressed: cart.lines.isEmpty || cart.isSubmitting
                        ? null
                        : () => _submit(context, ref),
                    icon: cart.isSubmitting
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.print_outlined),
                    label: Text('In bill • ${formatVnd(cart.total)}'),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'Đơn được lưu trước, sau đó gửi đến máy in đã chọn',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.secondaryInk,
                    ),
                  ),
                ],
              ),
            ),
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

class _TypeButton extends StatelessWidget {
  const _TypeButton({
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
        duration: AppMotion.duration(context, AppMotion.fast),
        child: AnimatedContainer(
          duration: AppMotion.duration(context, AppMotion.standard),
          curve: AppMotion.curve,
          decoration: BoxDecoration(
            color: selected ? AppColors.primarySoft : AppColors.surface,
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.outline,
            ),
            borderRadius: BorderRadius.circular(AppRadii.button),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onPressed,
              excludeFromSemantics: true,
              borderRadius: BorderRadius.circular(AppRadii.button),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: AppSizes.buttonHeight,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      icon,
                      color: selected
                          ? AppColors.primaryStrong
                          : AppColors.secondaryInk,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      label,
                      style: TextStyle(
                        color: selected
                            ? AppColors.primaryStrong
                            : AppColors.secondaryInk,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CartLineCard extends ConsumerStatefulWidget {
  const _CartLineCard({
    required super.key,
    required this.line,
    required this.enabled,
  });
  final CartLine line;
  final bool enabled;

  @override
  ConsumerState<_CartLineCard> createState() => _CartLineCardState();
}

class _CartLineCardState extends ConsumerState<_CartLineCard> {
  late final TextEditingController _noteController;
  late final FocusNode _noteFocus;

  @override
  void initState() {
    super.initState();
    _noteController = TextEditingController(text: widget.line.note);
    _noteFocus = FocusNode();
  }

  @override
  void didUpdateWidget(covariant _CartLineCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final external = widget.line.note ?? '';
    if (!_noteFocus.hasFocus && _noteController.text != external) {
      _noteController.text = external;
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    _noteFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Card(
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
                      widget.line.productName,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      '${formatVnd(widget.line.unitPrice)} / phần',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.secondaryInk,
                      ),
                    ),
                  ],
                ),
              ),
              AppAnimatedValue(
                value: widget.line.lineTotal,
                child: Text(
                  formatVnd(widget.line.lineTotal),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            key: Key('cart-note-${widget.line.lineId}'),
            controller: _noteController,
            focusNode: _noteFocus,
            enabled: widget.enabled,
            onChanged: (value) => ref
                .read(cartControllerProvider.notifier)
                .setNote(widget.line.lineId, value),
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
                key: Key('remove-cart-line-${widget.line.lineId}'),
                onPressed: widget.enabled
                    ? () => ref
                          .read(cartControllerProvider.notifier)
                          .remove(widget.line.lineId)
                    : null,
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Bỏ món',
              ),
              const Spacer(),
              IconButton(
                onPressed: widget.enabled
                    ? () => ref
                          .read(cartControllerProvider.notifier)
                          .decrement(widget.line.lineId)
                    : null,
                icon: const Icon(Icons.remove),
                tooltip: 'Giảm',
              ),
              SizedBox(
                width: 36,
                child: AppAnimatedValue(
                  value: widget.line.quantity,
                  child: Text(
                    '${widget.line.quantity}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              IconButton(
                onPressed: widget.enabled
                    ? () => ref
                          .read(cartControllerProvider.notifier)
                          .increment(widget.line.lineId)
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
