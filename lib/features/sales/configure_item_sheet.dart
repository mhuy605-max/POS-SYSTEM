import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/design_system.dart';
import '../../app/theme.dart';
import '../../core/money.dart';
import '../products/product_option_repository.dart';
import 'cart_controller.dart';

Future<bool?> showConfigureItemSheet({
  required BuildContext context,
  required int productId,
  required String productName,
  required int baseUnitPrice,
  required List<ResolvedProductOption> selectableOptions,
  required Future<String?> Function(
    List<ResolvedProductOption> options,
    String? note,
  )
  onSubmit,
  CartLine? existingLine,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.surface,
    builder: (context) => _ConfigureItemSheet(
      productId: productId,
      productName: productName,
      baseUnitPrice: baseUnitPrice,
      selectableOptions: selectableOptions,
      existingLine: existingLine,
      onSubmit: onSubmit,
    ),
  );
}

class _ConfigureItemSheet extends StatefulWidget {
  const _ConfigureItemSheet({
    required this.productId,
    required this.productName,
    required this.baseUnitPrice,
    required this.selectableOptions,
    required this.existingLine,
    required this.onSubmit,
  });

  final int productId;
  final String productName;
  final int baseUnitPrice;
  final List<ResolvedProductOption> selectableOptions;
  final CartLine? existingLine;
  final Future<String?> Function(
    List<ResolvedProductOption> options,
    String? note,
  )
  onSubmit;

  @override
  State<_ConfigureItemSheet> createState() => _ConfigureItemSheetState();
}

class _ConfigureItemSheetState extends State<_ConfigureItemSheet> {
  late final TextEditingController _noteController;
  late final Map<int, ResolvedProductOption> _selected;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _noteController = TextEditingController(text: widget.existingLine?.note);
    _selected = {
      for (final option in widget.existingLine?.selectedOptions ?? const [])
        option.optionItemId: ResolvedProductOption(
          productId: widget.productId,
          groupId: option.optionGroupId,
          optionItemId: option.optionItemId,
          groupName: option.groupName,
          optionName: option.optionName,
          priceDelta: option.priceDelta,
          groupSortOrder: option.groupSortOrder,
          optionSortOrder: option.optionSortOrder,
        ),
    };
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  int? get _configuredPrice {
    try {
      return checkedConfiguredUnitPrice(
        widget.baseUnitPrice,
        _selected.values.map((option) => option.priceDelta),
      );
    } on DomainValidationException {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentById = {
      for (final option in widget.selectableOptions)
        option.optionItemId: option,
    };
    final displayOptions = <ResolvedProductOption>[
      ...widget.selectableOptions,
      for (final selected in _selected.values)
        if (!currentById.containsKey(selected.optionItemId)) selected,
    ]..sort(_compareOptions);
    final groups = <int, List<ResolvedProductOption>>{};
    for (final option in displayOptions) {
      groups.putIfAbsent(option.groupId, () => []).add(option);
    }
    final price = _configuredPrice;
    return AnimatedPadding(
      duration: AppMotion.duration(context, AppMotion.selection),
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: FractionallySizedBox(
        heightFactor: .92,
        child: Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.outline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(
              child: ListView(
                key: const Key('configure-item-scroll'),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
                children: [
                  Text(
                    widget.productName,
                    style: Theme.of(context).textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    formatVnd(widget.baseUnitPrice),
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 20),
                  for (final entry in groups.entries) ...[
                    Text(
                      entry.value.first.groupName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    for (final option in entry.value)
                      _OptionTile(
                        option: _selected[option.optionItemId] ?? option,
                        selected: _selected.containsKey(option.optionItemId),
                        current: currentById[option.optionItemId],
                        onChanged: (selected) => _toggle(
                          option.optionItemId,
                          selected,
                          currentById[option.optionItemId],
                        ),
                      ),
                    const SizedBox(height: 14),
                  ],
                  const Text(
                    'Ghi chú',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    key: const Key('configure-item-note'),
                    controller: _noteController,
                    minLines: 2,
                    maxLines: 3,
                    maxLength: 200,
                    inputFormatters: [LengthLimitingTextInputFormatter(200)],
                    decoration: const InputDecoration(
                      hintText: 'Ví dụ: Ít hành, để riêng…',
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _error!,
                      key: const Key('configure-item-error'),
                      style: const TextStyle(
                        color: AppColors.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            AppBottomActionSurface(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Tổng món',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: AppAnimatedValue(
                          value: price ?? -1,
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                price == null
                                    ? 'Vượt giới hạn'
                                    : formatVnd(price),
                                key: const Key('configured-unit-price'),
                                style: TextStyle(
                                  color: price == null
                                      ? AppColors.error
                                      : AppColors.primaryStrong,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  FilledButton(
                    key: const Key('confirm-configured-item'),
                    onPressed: _submitting || price == null ? null : _confirm,
                    child: Text(
                      widget.existingLine == null
                          ? 'Thêm vào đơn'
                          : 'Lưu thay đổi',
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

  void _toggle(int optionId, bool selected, ResolvedProductOption? current) {
    if (_submitting) return;
    setState(() {
      _error = null;
      if (selected && current != null) {
        _selected[optionId] = current;
      } else if (!selected) {
        _selected.remove(optionId);
      }
    });
  }

  Future<void> _confirm() async {
    if (_submitting || _configuredPrice == null) return;
    setState(() => _submitting = true);
    final error = await widget.onSubmit(
      _selected.values.toList()..sort(_compareOptions),
      _noteController.text,
    );
    if (!mounted) return;
    if (error == null) {
      Navigator.pop(context, true);
    } else {
      setState(() {
        _submitting = false;
        _error = error;
      });
    }
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.option,
    required this.selected,
    required this.current,
    required this.onChanged,
  });

  final ResolvedProductOption option;
  final bool selected;
  final ResolvedProductOption? current;
  final ValueChanged<bool> onChanged;

  bool get _changed =>
      current == null ||
      current!.groupId != option.groupId ||
      current!.groupName != option.groupName ||
      current!.optionName != option.optionName ||
      current!.priceDelta != option.priceDelta;

  @override
  Widget build(BuildContext context) {
    return CheckboxListTile(
      key: Key('configure-option-${option.optionItemId}'),
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
      value: selected,
      onChanged: current != null || selected
          ? (value) => onChanged(value ?? false)
          : null,
      title: Text(
        option.optionName,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: _changed && selected
          ? const Text(
              'Cấu hình trong giỏ đã thay đổi',
              style: TextStyle(color: AppColors.error),
            )
          : null,
      secondary: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 128),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerRight,
          child: Text(
            option.priceDelta == 0 ? '0đ' : '+${formatVnd(option.priceDelta)}',
            style: const TextStyle(
              color: AppColors.primaryStrong,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

int _compareOptions(ResolvedProductOption left, ResolvedProductOption right) {
  final group = left.groupSortOrder.compareTo(right.groupSortOrder);
  if (group != 0) return group;
  final groupId = left.groupId.compareTo(right.groupId);
  if (groupId != 0) return groupId;
  final option = left.optionSortOrder.compareTo(right.optionSortOrder);
  if (option != 0) return option;
  return left.optionItemId.compareTo(right.optionItemId);
}
