import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/design_system.dart';
import '../../app/theme.dart';
import '../../core/money.dart';
import 'catalog_controller.dart';
import 'category_management_screen.dart';
import 'option_management_screen.dart';
import 'product_repository.dart';

enum _ProductSection { products, categories, options }

class ProductsScreen extends ConsumerStatefulWidget {
  const ProductsScreen({super.key});

  @override
  ConsumerState<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends ConsumerState<ProductsScreen> {
  Timer? _searchDebounce;
  _ProductSection _section = _ProductSection.products;

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _search(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 250), () {
      ref.read(catalogControllerProvider.notifier).setSearch(value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(catalogControllerProvider);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: SegmentedButton<_ProductSection>(
            key: const Key('product-sections'),
            segments: const [
              ButtonSegment(
                value: _ProductSection.products,
                label: Text('Món ăn'),
                icon: Icon(Icons.restaurant_menu),
              ),
              ButtonSegment(
                value: _ProductSection.categories,
                label: Text('Danh mục'),
                icon: Icon(Icons.category_outlined),
              ),
              ButtonSegment(
                value: _ProductSection.options,
                label: Text('Tùy chọn'),
                icon: Icon(Icons.tune_rounded),
              ),
            ],
            selected: {_section},
            showSelectedIcon: false,
            onSelectionChanged: (selection) {
              FocusScope.of(context).unfocus();
              setState(() => _section = selection.single);
            },
          ),
        ),
        Expanded(
          child: Padding(
            // The app shell's navigation bar overlays branch content. Keep
            // management actions above its interactive area.
            padding: const EdgeInsets.only(bottom: 72),
            child: IndexedStack(
              index: _section.index,
              children: [
                catalog.when(
                  loading: () =>
                      const AppLoadingState(label: 'Đang tải danh sách món'),
                  error: (error, stack) => AppAsyncError(
                    message: 'Không thể tải danh sách món.',
                    onRetry: () =>
                        ref.read(catalogControllerProvider.notifier).refresh(),
                  ),
                  data: (state) => Column(
                    children: [
                      Expanded(
                        child: RefreshIndicator(
                          onRefresh: ref
                              .read(catalogControllerProvider.notifier)
                              .refresh,
                          child: CustomScrollView(
                            key: const Key('catalog-scroll'),
                            slivers: [
                              SliverPadding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  12,
                                  16,
                                  8,
                                ),
                                sliver: SliverList.list(
                                  children: [
                                    _CatalogHeader(
                                      count: state.products.length,
                                    ),
                                    const SizedBox(height: 16),
                                    TextField(
                                      key: const Key('catalog-search'),
                                      onChanged: _search,
                                      textInputAction: TextInputAction.search,
                                      decoration: const InputDecoration(
                                        hintText: 'Tìm tên món…',
                                        prefixIcon: Icon(Icons.search_rounded),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    _CategoryFilters(state: state),
                                    const SizedBox(height: 12),
                                  ],
                                ),
                              ),
                              if (state.products.isEmpty)
                                SliverFillRemaining(
                                  hasScrollBody: false,
                                  child: _EmptyCatalog(
                                    filtered:
                                        state.search.trim().isNotEmpty ||
                                        state.categoryId != null,
                                    onAdd: () => context.push('/products/add'),
                                  ),
                                )
                              else
                                SliverPadding(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    0,
                                    16,
                                    16,
                                  ),
                                  sliver: SliverList.separated(
                                    itemCount: state.products.length,
                                    separatorBuilder: (context, index) =>
                                        const SizedBox(height: 12),
                                    itemBuilder: (context, index) =>
                                        _ProductCard(
                                          product: state.products[index],
                                        ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      if (state.products.isNotEmpty)
                        _AddProductAction(
                          onPressed: () => context.push('/products/add'),
                        ),
                    ],
                  ),
                ),
                const CategoryManagementScreen(embedded: true),
                const OptionManagementView(),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CatalogHeader extends StatelessWidget {
  const _CatalogHeader({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            '$count món trong danh mục',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        const SizedBox(width: 8),
        OutlinedButton.icon(
          key: const Key('reorder-products'),
          onPressed: () => context.push('/products/reorder'),
          icon: const Icon(Icons.swap_vert_rounded, size: 20),
          label: const Text('Sắp xếp'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(48, 48),
            padding: const EdgeInsets.symmetric(horizontal: 12),
          ),
        ),
      ],
    );
  }
}

class _CategoryFilters extends ConsumerWidget {
  const _CategoryFilters({required this.state});

  final CatalogState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = state.categories.where((item) => item.isActive);
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _FilterChip(
            label: 'Tất cả',
            selected: state.categoryId == null,
            onSelected: () =>
                ref.read(catalogControllerProvider.notifier).setCategory(null),
          ),
          for (final category in categories) ...[
            const SizedBox(width: 8),
            _FilterChip(
              label: category.name,
              selected: state.categoryId == category.id,
              onSelected: () => ref
                  .read(catalogControllerProvider.notifier)
                  .setCategory(category.id),
            ),
          ],
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
      showCheckmark: false,
      labelStyle: TextStyle(
        color: selected ? AppColors.primaryStrong : AppColors.secondaryInk,
        fontWeight: FontWeight.w700,
      ),
      selectedColor: AppColors.primarySoft,
      backgroundColor: AppColors.surface,
      side: BorderSide(color: selected ? AppColors.primary : AppColors.outline),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.field),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      chipAnimationStyle: AppMotion.chipStyle(context),
    );
  }
}

class _ProductCard extends ConsumerWidget {
  const _ProductCard({required this.product});

  final CatalogProduct product;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final imageStore = ref.watch(productImageStoreProvider).value;
    final image = product.imagePath == null || imageStore == null
        ? null
        : imageStore.resolve(product.imagePath!);
    final unavailable = !product.isAvailable;
    return Card(
      key: Key('product-${product.id}'),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () async {
          final controller = ref.read(catalogControllerProvider.notifier);
          final messenger = ScaffoldMessenger.of(context);
          final deleted = await context.push<bool>(
            '/products/${product.id}/edit',
          );
          if (deleted == true) {
            messenger.showSnackBar(
              SnackBar(
                content: const Text('Đã ẩn món khỏi danh mục.'),
                action: SnackBarAction(
                  label: 'Hoàn tác',
                  onPressed: () => controller.restoreProduct(product.id),
                ),
              ),
            );
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              _ProductImage(file: image, unavailable: unavailable),
              const SizedBox(width: 12),
              Expanded(
                child: Opacity(
                  opacity: unavailable ? 0.62 : 1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              product.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                decoration: unavailable
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.edit_outlined,
                            size: 19,
                            color: Color(0xFF9B7D72),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        product.categoryName,
                        style: const TextStyle(
                          color: AppColors.secondaryInk,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        formatVnd(product.price),
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 70,
                child: Column(
                  children: [
                    Switch(
                      key: Key('availability-${product.id}'),
                      value: product.isAvailable,
                      onChanged: (value) => ref
                          .read(catalogControllerProvider.notifier)
                          .setAvailability(product.id, value),
                    ),
                    Text(
                      unavailable ? 'Hết món' : 'Đang bán',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: unavailable
                            ? AppColors.secondaryInk
                            : AppColors.success,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
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

class _ProductImage extends StatelessWidget {
  const _ProductImage({required this.file, required this.unavailable});

  final File? file;
  final bool unavailable;

  @override
  Widget build(BuildContext context) {
    final validFile = file != null && file!.existsSync();
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 76,
        height: 76,
        child: ColorFiltered(
          colorFilter: unavailable
              ? const ColorFilter.mode(Colors.grey, BlendMode.saturation)
              : const ColorFilter.mode(Colors.transparent, BlendMode.multiply),
          child: validFile
              ? Image.file(file!, fit: BoxFit.cover)
              : const ColoredBox(
                  color: AppColors.surfaceLow,
                  child: Icon(
                    Icons.restaurant_rounded,
                    color: AppColors.primary,
                    size: 32,
                  ),
                ),
        ),
      ),
    );
  }
}

class _AddProductAction extends StatelessWidget {
  const _AddProductAction({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return AppBottomActionSurface(
      child: SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          key: const Key('add-product'),
          onPressed: onPressed,
          icon: const Icon(Icons.add_circle_outline),
          label: const Text('Thêm món mới'),
        ),
      ),
    );
  }
}

class _EmptyCatalog extends StatelessWidget {
  const _EmptyCatalog({required this.filtered, required this.onAdd});
  final bool filtered;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return AppEmptyState(
      icon: filtered ? Icons.search_off_outlined : Icons.restaurant_outlined,
      title: filtered ? 'Không tìm thấy món' : 'Chưa có món nào',
      message: filtered
          ? 'Thử từ khóa hoặc danh mục khác.'
          : 'Thêm món đầu tiên để bắt đầu bán hàng.',
      actionLabel: filtered ? null : 'Thêm món đầu tiên',
      onAction: filtered ? null : onAdd,
      actionKey: filtered ? null : const Key('add-product'),
    );
  }
}
