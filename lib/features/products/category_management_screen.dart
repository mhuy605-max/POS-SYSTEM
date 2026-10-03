import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/design_system.dart';
import '../../app/theme.dart';
import '../../core/money.dart';
import 'catalog_controller.dart';
import 'product_repository.dart';

class CategoryManagementScreen extends ConsumerStatefulWidget {
  const CategoryManagementScreen({super.key});

  @override
  ConsumerState<CategoryManagementScreen> createState() =>
      _CategoryManagementScreenState();
}

class _CategoryManagementScreenState
    extends ConsumerState<CategoryManagementScreen> {
  final _newCategoryController = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _newCategoryController.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (_newCategoryController.text.trim().isEmpty || _busy) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(categoryControllerProvider.notifier)
          .create(_newCategoryController.text);
      _newCategoryController.clear();
    } on DomainValidationException catch (error) {
      _showError(error.message);
    } catch (_) {
      _showError('Không thể tạo danh mục.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _rename(CatalogCategory category) async {
    var proposedName = category.name;
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Đổi tên danh mục'),
        content: TextFormField(
          key: const Key('rename-category-field'),
          initialValue: category.name,
          autofocus: true,
          maxLength: 40,
          textInputAction: TextInputAction.done,
          onChanged: (value) => proposedName = value,
          onFieldSubmitted: (value) => Navigator.pop(context, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          FilledButton(
            key: const Key('confirm-rename-category'),
            onPressed: () => Navigator.pop(context, proposedName),
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
    if (name == null || name.trim().isEmpty) return;
    await ref
        .read(categoryControllerProvider.notifier)
        .rename(category.id, name);
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoryControllerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Danh mục')),
      body: categories.when(
        loading: () => const AppLoadingState(label: 'Đang tải danh mục'),
        error: (error, stack) => AppAsyncError(
          message: 'Không thể tải danh mục.',
          onRetry: () =>
              ref.read(categoryControllerProvider.notifier).refresh(),
        ),
        data: (items) => ListView(
          key: const Key('category-list'),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            _CategorySummary(items: items),
            const SizedBox(height: 20),
            const Text(
              'Tạo danh mục mới',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('new-category-name'),
                    controller: _newCategoryController,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _create(),
                    decoration: const InputDecoration(
                      hintText: 'Tên danh mục mới…',
                      prefixIcon: Icon(Icons.playlist_add),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  key: const Key('add-category'),
                  onPressed: _busy ? null : _create,
                  icon: const Icon(Icons.add),
                  label: const Text('Thêm'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Row(
              children: [
                Expanded(
                  child: Text(
                    'THỨ TỰ HIỂN THỊ',
                    style: TextStyle(
                      color: AppColors.secondaryInk,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  'Giữ & kéo để xếp',
                  style: TextStyle(color: AppColors.secondaryInk, fontSize: 11),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              itemCount: items.length,
              onReorderItem: (oldIndex, newIndex) {
                ref
                    .read(categoryControllerProvider.notifier)
                    .move(items[oldIndex].id, newIndex);
              },
              itemBuilder: (context, index) => Padding(
                key: ValueKey(items[index].id),
                padding: const EdgeInsets.only(bottom: 10),
                child: _CategoryRow(
                  category: items[index],
                  index: index,
                  onRename: () => _rename(items[index]),
                  onActiveChanged: (value) => ref
                      .read(categoryControllerProvider.notifier)
                      .setActive(items[index].id, value),
                ),
              ),
            ),
            const SizedBox(height: 8),
            const _CategoryRuleCallout(),
          ],
        ),
      ),
    );
  }
}

class _CategorySummary extends StatelessWidget {
  const _CategorySummary({required this.items});

  final List<CatalogCategory> items;

  @override
  Widget build(BuildContext context) {
    final active = items.where((item) => item.isActive).length;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surfaceLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
              child: Padding(
                padding: EdgeInsets.all(10),
                child: Icon(Icons.category_outlined, color: AppColors.primary),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Thực đơn hiện tại\n$active/${items.length} nhóm đang hoạt động',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.category,
    required this.index,
    required this.onRename,
    required this.onActiveChanged,
  });

  final CatalogCategory category;
  final int index;
  final VoidCallback onRename;
  final ValueChanged<bool> onActiveChanged;

  @override
  Widget build(BuildContext context) => Card(
    key: Key('category-${category.id}'),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          ReorderableDelayedDragStartListener(
            index: index,
            child: const SizedBox.square(
              dimension: 48,
              child: Icon(
                Icons.drag_indicator_rounded,
                color: AppColors.secondaryInk,
              ),
            ),
          ),
          const SizedBox(width: 6),
          DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const SizedBox.square(
              dimension: 48,
              child: Icon(Icons.restaurant_menu, color: AppColors.primary),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  category.isActive ? 'Đang hoạt động' : 'Đã tạm ẩn',
                  style: TextStyle(
                    color: category.isActive
                        ? AppColors.success
                        : AppColors.secondaryInk,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Đổi tên',
            onPressed: onRename,
            icon: const Icon(Icons.edit_outlined),
          ),
          Switch(
            key: Key('category-active-${category.id}'),
            value: category.isActive,
            onChanged: onActiveChanged,
            activeTrackColor: AppColors.primary,
          ),
        ],
      ),
    ),
  );
}

class _CategoryRuleCallout extends StatelessWidget {
  const _CategoryRuleCallout();

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: AppColors.surfaceLow,
      borderRadius: BorderRadius.circular(16),
    ),
    child: const Padding(
      padding: EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: AppColors.primary),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Quy tắc danh mục\nTạm ẩn danh mục không xóa món hoặc thay đổi dữ liệu hóa đơn cũ.',
              style: TextStyle(color: AppColors.secondaryInk),
            ),
          ),
        ],
      ),
    ),
  );
}
