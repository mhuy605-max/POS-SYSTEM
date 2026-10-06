import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/design_system.dart';
import '../../app/theme.dart';
import 'catalog_controller.dart';
import 'product_repository.dart';

class ProductReorderScreen extends ConsumerStatefulWidget {
  const ProductReorderScreen({super.key});

  @override
  ConsumerState<ProductReorderScreen> createState() =>
      _ProductReorderScreenState();
}

class _ProductReorderScreenState extends ConsumerState<ProductReorderScreen> {
  List<CatalogProduct>? _items;
  bool _saving = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_load);
  }

  Future<void> _load() async {
    try {
      final items = await ref.read(productRepositoryProvider).listProducts();
      if (mounted) setState(() => _items = items.toList(growable: true));
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  Future<void> _done() async {
    if (_items == null || _saving) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(catalogControllerProvider.notifier)
          .reorderProducts(_items!.map((item) => item.id).toList());
      if (mounted) context.pop();
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không thể lưu thứ tự món.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sắp xếp món'),
        actions: [
          TextButton(
            key: const Key('finish-product-reorder'),
            onPressed: _saving ? null : _done,
            child: _saving
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Xong'),
          ),
        ],
      ),
      body: _error != null
          ? AppAsyncError(
              message: 'Không thể tải danh sách món.',
              onRetry: _load,
            )
          : _items == null
          ? const AppLoadingState(label: 'Đang tải danh sách món')
          : Column(
              children: [
                Expanded(
                  child: ReorderableListView.builder(
                    key: const Key('product-reorder-list'),
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    buildDefaultDragHandles: false,
                    itemCount: _items!.length,
                    onReorderItem: (oldIndex, newIndex) {
                      setState(() {
                        final moved = _items!.removeAt(oldIndex);
                        _items!.insert(newIndex, moved);
                      });
                    },
                    itemBuilder: (context, index) {
                      final product = _items![index];
                      return Padding(
                        key: ValueKey(product.id),
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Card(
                          child: ListTile(
                            key: Key('reorder-product-${product.id}'),
                            minTileHeight: 64,
                            leading: ReorderableDelayedDragStartListener(
                              index: index,
                              child: const SizedBox.square(
                                dimension: 48,
                                child: Icon(
                                  Icons.drag_indicator_rounded,
                                  color: AppColors.secondaryInk,
                                ),
                              ),
                            ),
                            title: Text(
                              product.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            subtitle: Text(product.categoryName),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SafeArea(
                  top: false,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(16, 12, 16, 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.touch_app_outlined,
                          size: 18,
                          color: AppColors.secondaryInk,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Giữ và kéo để thay đổi vị trí',
                          style: TextStyle(color: AppColors.secondaryInk),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
