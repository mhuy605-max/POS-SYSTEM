import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/design_system.dart';
import '../../app/theme.dart';
import '../../core/money.dart';
import 'catalog_controller.dart';
import 'product_option_repository.dart';

class OptionManagementView extends ConsumerWidget {
  const OptionManagementView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = ref.watch(optionManagementControllerProvider);
    return groups.when(
      loading: () => const AppLoadingState(label: 'Đang tải tùy chọn'),
      error: (error, stack) => AppAsyncError(
        message: 'Không thể tải nhóm tùy chọn.',
        onRetry: () =>
            ref.read(optionManagementControllerProvider.notifier).refresh(),
      ),
      data: (items) => RefreshIndicator(
        onRefresh: ref
            .read(optionManagementControllerProvider.notifier)
            .refresh,
        child: ListView(
          key: const Key('option-group-list'),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            if (items.isEmpty)
              const AppEmptyState(
                icon: Icons.tune_rounded,
                title: 'Chưa có nhóm tùy chọn',
                message: 'Tạo nhóm dùng lại cho nhiều món.',
              )
            else
              for (final group in items) ...[
                _GroupCard(group: group),
                const SizedBox(height: 10),
              ],
            const SizedBox(height: 8),
            FilledButton.icon(
              key: const Key('add-option-group'),
              onPressed: () => _createGroup(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('Thêm nhóm tùy chọn'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createGroup(BuildContext context, WidgetRef ref) async {
    final name = await _nameDialog(context, title: 'Thêm nhóm tùy chọn');
    if (name == null || !context.mounted) return;
    try {
      await ref
          .read(optionManagementControllerProvider.notifier)
          .createGroup(name);
    } catch (_) {
      if (context.mounted) _error(context, 'Không thể tạo nhóm tùy chọn.');
    }
  }
}

class _GroupCard extends ConsumerWidget {
  const _GroupCard({required this.group});

  final CatalogOptionGroup group;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      key: Key('option-group-${group.id}'),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push('/products/options/${group.id}'),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group.name,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${group.items.length} lựa chọn · ${group.isActive ? 'Đang bật' : 'Đã tạm ẩn'}',
                      style: TextStyle(
                        color: group.isActive
                            ? AppColors.success
                            : AppColors.secondaryInk,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Đổi tên nhóm',
                onPressed: () async {
                  final name = await _nameDialog(
                    context,
                    title: 'Đổi tên nhóm',
                    initialValue: group.name,
                  );
                  if (name == null || !context.mounted) return;
                  try {
                    await ref
                        .read(optionManagementControllerProvider.notifier)
                        .renameGroup(group.id, name);
                  } catch (_) {
                    if (context.mounted) {
                      _error(context, 'Không thể đổi tên nhóm.');
                    }
                  }
                },
                icon: const Icon(Icons.edit_outlined),
              ),
              Switch(
                key: Key('option-group-active-${group.id}'),
                value: group.isActive,
                onChanged: (value) => _setActive(context, ref, value),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _setActive(
    BuildContext context,
    WidgetRef ref,
    bool value,
  ) async {
    if (!value) {
      final count = await ref
          .read(productOptionRepositoryProvider)
          .countProductsUsingGroup(group.id);
      if (!context.mounted) return;
      if (count > 0) {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Tạm ẩn nhóm tùy chọn?'),
            content: Text(
              'Nhóm đang được gắn với $count món. Cấu hình vẫn được giữ để bật lại sau.',
            ),
            actions: [
              TextButton(
                onPressed: () => context.pop(false),
                child: const Text('Hủy'),
              ),
              FilledButton(
                key: const Key('confirm-deactivate-option-group'),
                onPressed: () => context.pop(true),
                child: const Text('Tạm ẩn'),
              ),
            ],
          ),
        );
        if (confirmed != true || !context.mounted) return;
      }
    }
    try {
      await ref
          .read(optionManagementControllerProvider.notifier)
          .setGroupActive(group.id, value);
    } catch (_) {
      if (context.mounted) _error(context, 'Không thể đổi trạng thái nhóm.');
    }
  }
}

class OptionGroupDetailScreen extends ConsumerWidget {
  const OptionGroupDetailScreen({required this.groupId, super.key});

  final int groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = ref.watch(optionManagementControllerProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          groups.value
                  ?.where((group) => group.id == groupId)
                  .firstOrNull
                  ?.name ??
              'Tùy chọn',
        ),
      ),
      body: groups.when(
        loading: () => const AppLoadingState(label: 'Đang tải lựa chọn'),
        error: (error, stack) => AppAsyncError(
          message: 'Không thể tải lựa chọn.',
          onRetry: () =>
              ref.read(optionManagementControllerProvider.notifier).refresh(),
        ),
        data: (groups) {
          final group = groups.where((item) => item.id == groupId).firstOrNull;
          if (group == null) {
            return const Center(
              child: Text('Nhóm tùy chọn không còn tồn tại.'),
            );
          }
          return _OptionList(group: group);
        },
      ),
    );
  }
}

class _OptionList extends ConsumerStatefulWidget {
  const _OptionList({required this.group});

  final CatalogOptionGroup group;

  @override
  ConsumerState<_OptionList> createState() => _OptionListState();
}

class _OptionListState extends ConsumerState<_OptionList> {
  late List<CatalogOptionItem> _items;

  @override
  void initState() {
    super.initState();
    _items = [...widget.group.items];
  }

  @override
  void didUpdateWidget(covariant _OptionList oldWidget) {
    super.didUpdateWidget(oldWidget);
    _items = [...widget.group.items];
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: _items.isEmpty
              ? const AppEmptyState(
                  icon: Icons.playlist_add,
                  title: 'Chưa có lựa chọn',
                  message: 'Thêm lựa chọn đầu tiên cho nhóm này.',
                )
              : ReorderableListView.builder(
                  key: const Key('option-item-list'),
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  buildDefaultDragHandles: false,
                  itemCount: _items.length,
                  onReorderItem: (oldIndex, newIndex) async {
                    setState(() {
                      final moved = _items.removeAt(oldIndex);
                      _items.insert(newIndex, moved);
                    });
                    try {
                      await ref
                          .read(optionManagementControllerProvider.notifier)
                          .reorderOptions(
                            widget.group.id,
                            _items.map((item) => item.id).toList(),
                          );
                    } catch (_) {
                      if (context.mounted) {
                        _error(context, 'Không thể lưu thứ tự lựa chọn.');
                      }
                    }
                  },
                  itemBuilder: (context, index) {
                    final item = _items[index];
                    return Padding(
                      key: ValueKey(item.id),
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Card(
                        child: ListTile(
                          key: Key('option-item-${item.id}'),
                          leading: ReorderableDelayedDragStartListener(
                            index: index,
                            child: const SizedBox.square(
                              dimension: 48,
                              child: Icon(Icons.drag_indicator_rounded),
                            ),
                          ),
                          title: Text(
                            item.name,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: item.isActive
                                  ? AppColors.ink
                                  : AppColors.secondaryInk,
                            ),
                          ),
                          subtitle: Text(
                            '${item.priceDelta == 0 ? '' : '+'}${formatVnd(item.priceDelta)} · ${item.isActive ? 'Đang bật' : 'Đã tạm ẩn'}',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'Sửa lựa chọn',
                                onPressed: () => _edit(item),
                                icon: const Icon(Icons.edit_outlined),
                              ),
                              Switch(
                                key: Key('option-active-${item.id}'),
                                value: item.isActive,
                                onChanged: (value) => ref
                                    .read(
                                      optionManagementControllerProvider
                                          .notifier,
                                    )
                                    .setOptionActive(item.id, value),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
        AppBottomActionSurface(
          child: FilledButton.icon(
            key: const Key('add-option-item'),
            onPressed: () => _edit(null),
            icon: const Icon(Icons.add),
            label: const Text('Thêm lựa chọn'),
          ),
        ),
      ],
    );
  }

  Future<void> _edit(CatalogOptionItem? item) async {
    final result = await _optionDialog(context, item: item);
    if (result == null || !mounted) return;
    try {
      final controller = ref.read(optionManagementControllerProvider.notifier);
      if (item == null) {
        await controller.createOption(
          groupId: widget.group.id,
          name: result.name,
          priceDelta: result.price,
        );
      } else {
        await controller.updateOption(
          item.id,
          name: result.name,
          priceDelta: result.price,
        );
      }
    } catch (_) {
      if (mounted) _error(context, 'Không thể lưu lựa chọn.');
    }
  }
}

Future<String?> _nameDialog(
  BuildContext context, {
  required String title,
  String initialValue = '',
}) async {
  final controller = TextEditingController(text: initialValue);
  final result = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        key: const Key('option-group-name'),
        controller: controller,
        autofocus: true,
        maxLength: 40,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => context.pop(controller.text.trim()),
        decoration: const InputDecoration(hintText: 'Ví dụ: Món thêm'),
      ),
      actions: [
        TextButton(onPressed: () => context.pop(), child: const Text('Hủy')),
        FilledButton(
          key: const Key('save-option-group'),
          onPressed: () => context.pop(controller.text.trim()),
          child: const Text('Lưu'),
        ),
      ],
    ),
  );
  return result == null || result.isEmpty ? null : result;
}

typedef _OptionDraft = ({String name, int price});

Future<_OptionDraft?> _optionDialog(
  BuildContext context, {
  CatalogOptionItem? item,
}) async {
  final name = TextEditingController(text: item?.name ?? '');
  final price = TextEditingController(text: (item?.priceDelta ?? 0).toString());
  String? error;
  final result = await showDialog<_OptionDraft>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text(item == null ? 'Thêm lựa chọn' : 'Sửa lựa chọn'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const Key('option-item-name'),
              controller: name,
              autofocus: true,
              maxLength: 40,
              decoration: const InputDecoration(labelText: 'Tên lựa chọn'),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('option-item-price'),
              controller: price,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: 'Giá thêm (VND)',
                suffixText: 'đ',
                errorText: error,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => context.pop(), child: const Text('Hủy')),
          FilledButton(
            key: const Key('save-option-item'),
            onPressed: () {
              final parsed = int.tryParse(price.text);
              if (name.text.trim().isEmpty || parsed == null || parsed < 0) {
                setState(() => error = 'Nhập tên và giá nguyên không âm.');
                return;
              }
              context.pop((name: name.text.trim(), price: parsed));
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    ),
  );
  return result;
}

void _error(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}
