import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/design_system.dart';
import '../../app/theme.dart';
import '../../core/money.dart';
import 'catalog_controller.dart';
import 'product_option_repository.dart';
import 'product_repository.dart';

class ProductFormScreen extends ConsumerStatefulWidget {
  const ProductFormScreen({super.key, this.productId});

  final int? productId;

  @override
  ConsumerState<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends ConsumerState<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _priceController = TextEditingController(text: '0');
  final _descriptionController = TextEditingController();
  List<CatalogCategory> _categories = const [];
  List<CatalogOptionGroup> _optionGroups = const [];
  final Set<int> _selectedOptionGroupIds = {};
  int? _categoryId;
  bool _isAvailable = true;
  String? _imagePath;
  File? _selectedImage;
  bool _loading = true;
  bool _saving = false;
  Object? _loadError;

  bool get _editing => widget.productId != null;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_load);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final repository = ref.read(productRepositoryProvider);
      final optionRepository = ref.read(productOptionRepositoryProvider);
      final categories = await repository.listCategories();
      CatalogProduct? product;
      if (_editing) product = await repository.getProduct(widget.productId!);
      final optionGroups = await optionRepository.listGroups();
      final attached = _editing
          ? await optionRepository.listAttachedGroupsForManagement(
              widget.productId!,
            )
          : const <CatalogOptionGroup>[];
      if (!mounted) return;
      setState(() {
        _categories = categories
            .where(
              (category) =>
                  category.isActive || category.id == product?.categoryId,
            )
            .toList(growable: false);
        _categoryId =
            product?.categoryId ??
            categories.where((item) => item.isActive).firstOrNull?.id;
        _optionGroups = optionGroups;
        _selectedOptionGroupIds
          ..clear()
          ..addAll(attached.map((group) => group.id));
        if (product != null) {
          _nameController.text = product.name;
          _priceController.text = product.price.toString();
          _descriptionController.text = product.description ?? '';
          _isAvailable = product.isAvailable;
          _imagePath = product.imagePath;
        }
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = error;
        _loading = false;
      });
    }
  }

  Future<void> _pickImage() async {
    final result = await FilePicker.pickFile(type: FileType.image);
    final path = result?.path;
    if (path == null || !mounted) return;
    setState(() => _selectedImage = File(path));
  }

  Future<void> _openCategories() async {
    await context.push('/products/categories');
    if (!mounted) return;
    final categories = await ref
        .read(productRepositoryProvider)
        .listCategories();
    if (!mounted) return;
    final active = categories.where((item) => item.isActive).toList();
    setState(() {
      _categories = active;
      if (!_categories.any((item) => item.id == _categoryId)) {
        _categoryId = active.firstOrNull?.id;
      }
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _categoryId == null) return;
    setState(() => _saving = true);
    try {
      var storedImagePath = _imagePath;
      if (_selectedImage != null) {
        final imageStore = await ref.read(productImageStoreProvider.future);
        storedImagePath = await imageStore.importFile(_selectedImage!);
      }
      final draft = ProductDraft(
        categoryId: _categoryId!,
        name: _nameController.text,
        description: _descriptionController.text,
        price: int.parse(_priceController.text),
        imagePath: storedImagePath,
        isAvailable: _isAvailable,
      );
      final controller = ref.read(catalogControllerProvider.notifier);
      if (_editing) {
        await controller.updateProductWithOptionGroups(
          widget.productId!,
          draft,
          _selectedOptionGroupIds.toList(),
        );
      } else {
        await controller.createProductWithOptionGroups(
          draft,
          _selectedOptionGroupIds.toList(),
        );
      }
      if (!mounted) return;
      context.pop();
    } on DomainValidationException catch (error) {
      _showError(error.message);
    } catch (error) {
      _showError('Không thể lưu món. Vui lòng thử lại.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ẩn món khỏi danh mục?'),
        content: const Text(
          'Món sẽ không còn xuất hiện trong danh mục đang dùng. Dữ liệu hóa đơn cũ vẫn được giữ nguyên.',
        ),
        actions: [
          TextButton(
            onPressed: () => context.pop(false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            key: const Key('confirm-delete-product'),
            onPressed: () => context.pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Ẩn món'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await ref
        .read(catalogControllerProvider.notifier)
        .deleteProduct(widget.productId!);
    if (mounted) context.pop(true);
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_editing ? 'Sửa món' : 'Thêm món')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
          ? const Center(child: Text('Không thể tải thông tin món.'))
          : Form(
              key: _formKey,
              child: ListView(
                key: const Key('product-form-scroll'),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  if (_editing) ...[
                    _buildImageSection(),
                    const SizedBox(height: 16),
                  ],
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _FieldLabel(label: 'Tên món', required: true),
                          const SizedBox(height: 8),
                          TextFormField(
                            key: const Key('product-name'),
                            controller: _nameController,
                            maxLength: 40,
                            decoration: const InputDecoration(
                              hintText: 'Ví dụ: Cơm sườn bì chả',
                              counterText: '',
                            ),
                            validator: (value) =>
                                value == null || value.trim().isEmpty
                                ? 'Vui lòng nhập tên món.'
                                : null,
                          ),
                          const SizedBox(height: 16),
                          _FieldLabel(label: 'Giá bán (VND)', required: true),
                          const SizedBox(height: 8),
                          TextFormField(
                            key: const Key('product-price'),
                            controller: _priceController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            decoration: const InputDecoration(suffixText: 'đ'),
                            validator: (value) {
                              final price = int.tryParse(value ?? '');
                              return price == null || price < 0
                                  ? 'Giá phải là số nguyên không âm.'
                                  : null;
                            },
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final value in [35000, 45000, 55000, 65000])
                                ActionChip(
                                  label: Text('${value ~/ 1000}k'),
                                  onPressed: () =>
                                      _priceController.text = value.toString(),
                                  backgroundColor: AppColors.surface,
                                  side: const BorderSide(
                                    color: AppColors.outline,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          _FieldLabel(
                            label: 'Danh mục phục vụ',
                            required: true,
                          ),
                          const SizedBox(height: 8),
                          if (_categories.isEmpty)
                            FilledButton.tonalIcon(
                              onPressed: _openCategories,
                              icon: const Icon(Icons.add),
                              label: const Text('Tạo danh mục trước'),
                            )
                          else
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final category in _categories)
                                  ChoiceChip(
                                    label: Text(category.name),
                                    selected: _categoryId == category.id,
                                    onSelected: (_) => setState(
                                      () => _categoryId = category.id,
                                    ),
                                    showCheckmark: false,
                                    selectedColor: AppColors.primarySoft,
                                    backgroundColor: AppColors.surface,
                                    side: BorderSide(
                                      color: _categoryId == category.id
                                          ? AppColors.primary
                                          : AppColors.outline,
                                    ),
                                    labelStyle: TextStyle(
                                      color: _categoryId == category.id
                                          ? AppColors.primaryStrong
                                          : AppColors.secondaryInk,
                                      fontWeight: FontWeight.w700,
                                    ),
                                    chipAnimationStyle: AppMotion.chipStyle(
                                      context,
                                    ),
                                  ),
                              ],
                            ),
                          if (_categoryId == null)
                            const Padding(
                              padding: EdgeInsets.only(top: 8),
                              child: Text(
                                'Vui lòng chọn danh mục.',
                                style: TextStyle(
                                  color: AppColors.error,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          const SizedBox(height: 20),
                          const _FieldLabel(
                            label: 'Mô tả ngắn',
                            required: false,
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            key: const Key('product-description'),
                            controller: _descriptionController,
                            minLines: 3,
                            maxLines: 4,
                            decoration: const InputDecoration(
                              hintText: 'Ví dụ: Sườn nướng than mềm thơm…',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (!_editing) ...[
                    const SizedBox(height: 16),
                    _buildImageSection(),
                  ],
                  const SizedBox(height: 16),
                  _buildOptionGroupsSection(),
                  const SizedBox(height: 16),
                  Card(
                    child: SwitchListTile(
                      key: const Key('product-available'),
                      value: _isAvailable,
                      onChanged: (value) =>
                          setState(() => _isAvailable = value),
                      title: const Text(
                        'Trạng thái bán hàng',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        _isAvailable
                            ? 'Món đang hiển thị để chọn bán'
                            : 'Món vẫn được quản lý nhưng đang hết',
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ListenableBuilder(
                    listenable: Listenable.merge([
                      _nameController,
                      _priceController,
                    ]),
                    builder: (context, child) => _ReceiptLinePreview(
                      name: _nameController.text.trim().isEmpty
                          ? 'Món mới'
                          : _nameController.text.trim(),
                      price: int.tryParse(_priceController.text) ?? 0,
                    ),
                  ),
                  if (_editing) ...[
                    const SizedBox(height: 20),
                    OutlinedButton.icon(
                      key: const Key('delete-product'),
                      onPressed: _saving ? null : _delete,
                      icon: const Icon(Icons.inventory_2_outlined),
                      label: const Text('Ẩn món khỏi danh mục'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        foregroundColor: AppColors.error,
                      ),
                    ),
                  ],
                ],
              ),
            ),
      bottomNavigationBar: _loading || _loadError != null
          ? null
          : AppBottomActionSurface(
              child: FilledButton.icon(
                key: const Key('save-product'),
                onPressed: _saving || _categories.isEmpty ? null : _save,
                icon: _saving
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        _editing
                            ? Icons.check_circle_outline
                            : Icons.add_circle_outline,
                      ),
                label: Text(_editing ? 'Lưu thay đổi' : 'Lưu & Thêm món'),
              ),
            ),
    );
  }

  Widget _buildImageSection() => _ImageSection(
    selectedImage: _selectedImage,
    storedImagePath: _imagePath,
    onPick: _pickImage,
    onRemove: () => setState(() {
      _selectedImage = null;
      _imagePath = null;
    }),
  );

  Widget _buildOptionGroupsSection() => Card(
    key: const Key('product-option-groups'),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tùy chọn món',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          const Text(
            'Chọn các nhóm tùy chọn dùng cho món này.',
            style: TextStyle(color: AppColors.secondaryInk),
          ),
          const SizedBox(height: 10),
          if (_optionGroups.isEmpty)
            const Text(
              'Chưa có nhóm tùy chọn. Có thể lưu món mà không cần nhóm.',
              style: TextStyle(color: AppColors.secondaryInk),
            )
          else
            for (final group in _optionGroups)
              CheckboxListTile(
                key: Key('attach-option-group-${group.id}'),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: _selectedOptionGroupIds.contains(group.id),
                onChanged: (selected) => setState(() {
                  if (selected == true) {
                    _selectedOptionGroupIds.add(group.id);
                  } else {
                    _selectedOptionGroupIds.remove(group.id);
                  }
                }),
                title: Text(
                  group.name,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  group.isActive
                      ? '${group.items.length} lựa chọn'
                      : '${group.items.length} lựa chọn · Đã tạm ẩn',
                  style: TextStyle(
                    color: group.isActive
                        ? AppColors.secondaryInk
                        : AppColors.error,
                  ),
                ),
              ),
        ],
      ),
    ),
  );
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.label, required this.required});
  final String label;
  final bool required;

  @override
  Widget build(BuildContext context) => Text.rich(
    TextSpan(
      text: label,
      children: required
          ? const [
              TextSpan(
                text: ' *',
                style: TextStyle(color: AppColors.primary),
              ),
            ]
          : const [
              TextSpan(
                text: '  Tùy chọn',
                style: TextStyle(fontSize: 12, color: AppColors.secondaryInk),
              ),
            ],
    ),
    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
  );
}

class _ImageSection extends ConsumerWidget {
  const _ImageSection({
    required this.selectedImage,
    required this.storedImagePath,
    required this.onPick,
    required this.onRemove,
  });

  final File? selectedImage;
  final String? storedImagePath;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    File? image = selectedImage;
    if (image == null && storedImagePath != null) {
      image = ref
          .watch(productImageStoreProvider)
          .value
          ?.resolve(storedImagePath!);
    }
    final hasImage = image != null && image.existsSync();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Ảnh minh họa',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Text(
                  hasImage ? 'Đã chọn' : 'Tùy chọn',
                  style: TextStyle(
                    color: hasImage
                        ? AppColors.success
                        : AppColors.secondaryInk,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (hasImage)
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      image,
                      width: 104,
                      height: 104,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      children: [
                        FilledButton.tonalIcon(
                          onPressed: onPick,
                          icon: const Icon(Icons.photo_library_outlined),
                          label: const Text('Đổi ảnh khác'),
                        ),
                        TextButton.icon(
                          onPressed: onRemove,
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('Gỡ bỏ ảnh'),
                        ),
                      ],
                    ),
                  ),
                ],
              )
            else
              InkWell(
                key: const Key('pick-product-image'),
                onTap: onPick,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    vertical: 24,
                    horizontal: 12,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLow,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Column(
                    children: [
                      Icon(
                        Icons.add_photo_alternate_outlined,
                        color: AppColors.primary,
                        size: 32,
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Chọn ảnh món ăn',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        'Không có ảnh vẫn bán được',
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ReceiptLinePreview extends StatelessWidget {
  const _ReceiptLinePreview({required this.name, required this.price});
  final String name;
  final int price;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: AppColors.surfaceLow,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const Icon(Icons.receipt_long_outlined, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          Text(
            formatVnd(price),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    ),
  );
}
