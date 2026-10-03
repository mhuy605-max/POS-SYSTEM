import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/design_system.dart';
import '../../app/theme.dart';
import 'shop_settings_controller.dart';
import 'shop_settings_repository.dart';

class ShopSettingsScreen extends ConsumerStatefulWidget {
  const ShopSettingsScreen({super.key});

  @override
  ConsumerState<ShopSettingsScreen> createState() => _ShopSettingsScreenState();
}

class _ShopSettingsScreenState extends ConsumerState<ShopSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _shopName = TextEditingController();
  final _address = TextEditingController();
  final _phone = TextEditingController();
  final _footer = TextEditingController();
  bool _initialized = false;

  @override
  void dispose() {
    _shopName.dispose();
    _address.dispose();
    _phone.dispose();
    _footer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(shopSettingsProvider);
    final saving = ref.watch(shopSettingsControllerProvider).isLoading;
    return Scaffold(
      appBar: AppBar(title: const Text('Thông tin quán & bill')),
      body: settings.when(
        loading: () => const AppLoadingState(label: 'Đang tải thông tin quán'),
        error: (error, _) =>
            const AppAsyncError(message: 'Không thể đọc thông tin quán.'),
        data: (value) {
          if (!_initialized) {
            _initialized = true;
            _shopName.text = value.shopName;
            _address.text = value.address;
            _phone.text = value.phone;
            _footer.text = value.receiptFooter;
          }
          return Form(
            key: _formKey,
            child: ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
              children: [
                const Text(
                  'Thông tin hiển thị trên bill mới',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 14),
                _field(
                  _shopName,
                  'Tên quán',
                  key: const Key('shop-name-field'),
                  required: true,
                ),
                const SizedBox(height: 12),
                _field(_address, 'Địa chỉ (không bắt buộc)'),
                const SizedBox(height: 12),
                _field(
                  _phone,
                  'Số điện thoại (không bắt buộc)',
                  keyboard: TextInputType.phone,
                ),
                const SizedBox(height: 12),
                _field(
                  _footer,
                  'Lời nhắn cuối bill (không bắt buộc)',
                  maxLines: 3,
                ),
                const SizedBox(height: 20),
                const Text(
                  'Xem trước bill 58mm',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                AnimatedBuilder(
                  animation: Listenable.merge([
                    _shopName,
                    _address,
                    _phone,
                    _footer,
                  ]),
                  builder: (context, _) => _ReceiptPreview(
                    shopName: _shopName.text,
                    address: _address.text,
                    phone: _phone.text,
                    footer: _footer.text,
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  key: const Key('save-shop-settings'),
                  onPressed: saving ? null : _save,
                  icon: saving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: const Text('Lưu thông tin'),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Thay đổi chỉ áp dụng cho đơn và bill tạo sau khi lưu. Bill lịch sử giữ nguyên thông tin đã chụp lúc tạo đơn.',
                  style: TextStyle(color: AppColors.secondaryInk, height: 1.45),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    Key? key,
    bool required = false,
    int maxLines = 1,
    TextInputType? keyboard,
  }) => TextFormField(
    key: key,
    controller: controller,
    decoration: InputDecoration(labelText: label),
    maxLines: maxLines,
    keyboardType: keyboard,
    validator: required
        ? (value) => value == null || value.trim().isEmpty
              ? 'Vui lòng nhập tên quán.'
              : null
        : null,
  );

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    try {
      await ref
          .read(shopSettingsControllerProvider.notifier)
          .save(
            ShopSettingsDraft(
              shopName: _shopName.text,
              address: _address.text,
              phone: _phone.text,
              receiptFooter: _footer.text,
            ),
          );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Đã lưu thông tin quán.')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$error')));
      }
    }
  }
}

class _ReceiptPreview extends StatelessWidget {
  const _ReceiptPreview({
    required this.shopName,
    required this.address,
    required this.phone,
    required this.footer,
  });
  final String shopName;
  final String address;
  final String phone;
  final String footer;

  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      width: 280,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        children: [
          Text(
            shopName.trim().isEmpty
                ? 'TÊN QUÁN'
                : shopName.trim().toUpperCase(),
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          if (address.trim().isNotEmpty)
            Text(address.trim(), textAlign: TextAlign.center),
          if (phone.trim().isNotEmpty)
            Text(phone.trim(), textAlign: TextAlign.center),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Text('------------------------------'),
          ),
          const Row(
            children: [
              Expanded(
                child: Text(
                  'Món mẫu x1',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(width: 8),
              Text('45.000đ'),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Text('------------------------------'),
          ),
          if (footer.trim().isNotEmpty)
            Text(footer.trim(), textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}
