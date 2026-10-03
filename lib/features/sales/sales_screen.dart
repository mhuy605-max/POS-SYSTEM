import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/money.dart';
import '../../app/design_system.dart';
import '../../app/theme.dart';
import '../orders/order_providers.dart';
import '../orders/order_repository.dart';
import '../printing/printer_models.dart';
import '../products/catalog_controller.dart';
import '../products/product_repository.dart';
import 'cart_controller.dart';

final salesCatalogProvider = FutureProvider.autoDispose<CatalogState>((
  ref,
) async {
  final repository = ref.watch(productRepositoryProvider);
  final categories = await repository.listCategories();
  final products = await repository.listProducts();
  return CatalogState(categories: categories, products: products);
});

class SalesScreen extends ConsumerStatefulWidget {
  const SalesScreen({super.key});

  @override
  ConsumerState<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends ConsumerState<SalesScreen> {
  String _search = '';
  int? _categoryId;

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(salesCatalogProvider);
    final cart = ref.watch(cartControllerProvider);
    return Column(
      children: [
        Expanded(
          child: catalog.when(
            loading: () => const AppLoadingState(label: 'Đang tải thực đơn'),
            error: (error, _) => AppAsyncError(
              message: 'Không thể tải thực đơn. Hãy thử lại.',
              onRetry: () => ref.invalidate(salesCatalogProvider),
            ),
            data: (data) {
              final activeCategoryIds = data.categories
                  .where((category) => category.isActive)
                  .map((category) => category.id)
                  .toSet();
              final effectiveCategoryId =
                  activeCategoryIds.contains(_categoryId) ? _categoryId : null;
              final query = _search.trim().toLowerCase();
              final visibleProducts = data.products
                  .where(
                    (product) =>
                        activeCategoryIds.contains(product.categoryId) &&
                        (effectiveCategoryId == null ||
                            product.categoryId == effectiveCategoryId) &&
                        (query.isEmpty ||
                            product.name.toLowerCase().contains(query) ||
                            (product.description?.toLowerCase().contains(
                                  query,
                                ) ??
                                false)),
                  )
                  .toList();
              return CustomScrollView(
                key: const Key('sales-scroll'),
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                      child: TextField(
                        key: const Key('sales-search'),
                        decoration: const InputDecoration(
                          hintText: 'Tìm món...',
                          prefixIcon: Icon(Icons.search),
                        ),
                        onChanged: (value) => setState(() => _search = value),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 48,
                      child: ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        scrollDirection: Axis.horizontal,
                        children: [
                          _CategoryChip(
                            label: 'Tất cả',
                            selected: effectiveCategoryId == null,
                            onTap: () => setState(() => _categoryId = null),
                          ),
                          for (final category in data.categories.where(
                            (item) => item.isActive,
                          )) ...[
                            const SizedBox(width: 8),
                            _CategoryChip(
                              label: category.name,
                              selected: effectiveCategoryId == category.id,
                              onTap: () =>
                                  setState(() => _categoryId = category.id),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  if (visibleProducts.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: AppEmptyState(
                        icon: Icons.restaurant_menu_outlined,
                        title: query.isEmpty && effectiveCategoryId == null
                            ? 'Chưa có món để bán'
                            : 'Không tìm thấy món',
                        message: query.isEmpty && effectiveCategoryId == null
                            ? 'Món đang bán sẽ xuất hiện tại đây.'
                            : 'Thử từ khóa hoặc danh mục khác.',
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                      sliver: SliverGrid.builder(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              childAspectRatio: .78,
                            ),
                        itemCount: visibleProducts.length,
                        itemBuilder: (context, index) => _SaleProductCard(
                          product: visibleProducts[index],
                          onTap: () => ref
                              .read(cartControllerProvider.notifier)
                              .addProduct(visibleProducts[index]),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
        AppBottomActionSurface(
          child: FilledButton(
            key: const Key('open-current-order'),
            onPressed: () async {
              final result = await context.push<OrderSubmissionResult>(
                '/sales/current',
              );
              if (result != null && context.mounted) {
                final saved = await ref
                    .read(orderRepositoryProvider)
                    .loadOrder(result.orderId);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(_submissionFeedback(saved, result))),
                );
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: Row(
              children: [
                const Icon(Icons.shopping_bag_outlined),
                const SizedBox(width: 8),
                AppAnimatedValue(
                  value: cart.itemCount,
                  child: Text('${cart.itemCount} món'),
                ),
                const Spacer(),
                AppAnimatedValue(
                  value: cart.total,
                  child: Text(
                    formatVnd(cart.total),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.chevron_right),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

String _submissionFeedback(SavedOrder order, OrderSubmissionResult result) {
  final saved = 'Đã lưu đơn #${order.orderNumber.toString().padLeft(4, '0')}.';
  return switch (result.printResult.kind) {
    PrintResultKind.sent =>
      '$saved Dữ liệu đã gửi tới máy in; hãy kiểm tra giấy.',
    PrintResultKind.unknown =>
      '$saved Kết quả gửi chưa rõ; ứng dụng sẽ không tự động in lại.',
    PrintResultKind.failed =>
      result.printResult.errorCode == PrinterErrorCode.notConfigured
          ? '$saved Chưa cấu hình máy in.'
          : '$saved Không gửi được tới máy in. Có thể in lại từ Đơn hàng.',
  };
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => FilterChip(
    label: Text(label),
    selected: selected,
    onSelected: (_) => onTap(),
    showCheckmark: false,
    selectedColor: AppColors.primarySoft,
    side: BorderSide(color: selected ? AppColors.primary : AppColors.outline),
    labelStyle: TextStyle(
      color: selected ? AppColors.primaryStrong : AppColors.secondaryInk,
      fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
    ),
  );
}

class _SaleProductCard extends ConsumerWidget {
  const _SaleProductCard({required this.product, required this.onTap});
  final CatalogProduct product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final available = product.isAvailable;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: AppPressable(
        key: Key('sale-product-${product.id}'),
        onTap: available ? onTap : null,
        child: Opacity(
          opacity: available ? 1 : .58,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _ProductImage(product: product)),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            formatVnd(product.price),
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        if (available)
                          const Icon(Icons.add_circle, color: AppColors.primary)
                        else
                          const Text(
                            'Hết món',
                            style: TextStyle(
                              color: AppColors.error,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProductImage extends ConsumerWidget {
  const _ProductImage({required this.product});
  final CatalogProduct product;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final path = product.imagePath;
    if (path == null) {
      return const ColoredBox(
        color: AppColors.surfaceHigh,
        child: Center(
          child: Icon(
            Icons.restaurant,
            size: 42,
            color: AppColors.secondaryInk,
          ),
        ),
      );
    }
    final store = ref.watch(productImageStoreProvider);
    return store.when(
      data: (value) => Image.file(
        File(value.resolve(path).path),
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) =>
            const Center(child: Icon(Icons.broken_image_outlined)),
      ),
      loading: () => const ColoredBox(color: AppColors.surfaceHigh),
      error: (_, _) => const Center(child: Icon(Icons.broken_image_outlined)),
    );
  }
}
