import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/models.dart';
import '../../repositories/repositories.dart';
import '../../state/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../../widgets/role_shell.dart';
import '../../widgets/shared_widgets.dart';

/// Ports src/pages/seller/Products.jsx: a shop owner's own product
/// listings, with an inline "Add a product" form and per-row availability
/// toggle / Delete actions.
class SellerProductsScreen extends ConsumerStatefulWidget {
  const SellerProductsScreen({super.key});

  @override
  ConsumerState<SellerProductsScreen> createState() => _SellerProductsScreenState();
}

class _SellerProductsScreenState extends ConsumerState<SellerProductsScreen> {
  Shop? _shop;
  bool _shopLoading = true;

  List<Product> _products = const [];
  bool _productsLoading = true;
  String? _productsError;

  bool _formOpen = false;
  Map<String, String> _errors = {};
  String _formError = '';
  bool _submitting = false;

  String _category = 'medicine';
  final _nameCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _stockCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _photoUrlsCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadShop();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    _stockCtrl.dispose();
    _descriptionCtrl.dispose();
    _photoUrlsCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadShop() async {
    final profile = ref.read(authControllerProvider).profile;
    if (profile == null) {
      setState(() {
        _shopLoading = false;
        _productsLoading = false;
      });
      return;
    }
    try {
      final shop = await ShopsRepository().getByOwnerId(profile.id);
      if (!mounted) return;
      setState(() {
        _shop = shop;
        _shopLoading = false;
      });
      if (shop != null) {
        await _loadProducts(shop.id);
      } else {
        setState(() => _productsLoading = false);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _shopLoading = false;
        _productsLoading = false;
      });
    }
  }

  Future<void> _loadProducts([String? shopId]) async {
    final id = shopId ?? _shop?.id;
    if (id == null) return;
    setState(() {
      _productsLoading = true;
      _productsError = null;
    });
    try {
      final products = await ProductsRepository().listByShop(id);
      if (!mounted) return;
      setState(() {
        _products = products;
        _productsLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _productsError = _describeError(e, 'Something went wrong loading your products.');
        _productsLoading = false;
      });
    }
  }

  String _describeError(Object error, String fallback) {
    if (error is PostgrestException) {
      return error.message.isNotEmpty ? error.message : fallback;
    }
    final text = error.toString();
    return text.isNotEmpty ? text : fallback;
  }

  Map<String, String> _validate() {
    final errors = <String, String>{};
    if (_nameCtrl.text.trim().isEmpty) errors['name'] = 'Enter a product name.';

    final priceText = _priceCtrl.text.trim();
    if (priceText.isEmpty) {
      errors['price'] = 'Enter a price.';
    } else {
      final price = num.tryParse(priceText);
      if (price == null || price < 0) errors['price'] = 'Enter a valid price.';
    }

    final stockText = _stockCtrl.text.trim();
    if (stockText.isEmpty) {
      errors['stock_quantity'] = 'Enter a stock quantity.';
    } else {
      final stock = num.tryParse(stockText);
      if (stock == null || stock < 0) errors['stock_quantity'] = 'Enter a valid stock quantity.';
    }

    return errors;
  }

  void _clearForm() {
    setState(() => _category = 'medicine');
    _nameCtrl.clear();
    _priceCtrl.clear();
    _stockCtrl.clear();
    _descriptionCtrl.clear();
    _photoUrlsCtrl.clear();
  }

  Future<void> _submit() async {
    setState(() => _formError = '');
    final errors = _validate();
    setState(() => _errors = errors);
    if (errors.isNotEmpty) return;

    setState(() => _submitting = true);
    try {
      final photoUrls = _photoUrlsCtrl.text
          .split(',')
          .map((u) => u.trim())
          .where((u) => u.isNotEmpty)
          .toList();
      final description = _descriptionCtrl.text.trim();

      await ProductsRepository().insert({
        'shop_id': _shop!.id,
        'category': _category,
        'name': _nameCtrl.text.trim(),
        'description': description.isEmpty ? null : description,
        'price': num.parse(_priceCtrl.text.trim()),
        'stock_quantity': num.parse(_stockCtrl.text.trim()).round(),
        'photo_urls': photoUrls,
      });

      _clearForm();
      if (!mounted) return;
      setState(() {
        _errors = {};
        _formOpen = false;
      });
      await _loadProducts();
    } catch (e) {
      if (!mounted) return;
      setState(() => _formError = _describeError(e, 'Something went wrong adding this product.'));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _toggleAvailability(Product product) async {
    final nextStatus = product.status == 'available' ? 'unavailable' : 'available';
    try {
      await ProductsRepository().update(product.id, {'status': nextStatus});
      await _loadProducts();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(_describeError(e, 'Could not update this listing.'))));
    }
  }

  Future<bool> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this listing?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Delete', style: AppTheme.body(color: AppColors.error, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  Future<void> _deleteProduct(String productId) async {
    final confirmed = await _confirmDelete();
    if (!confirmed) return;
    try {
      await ProductsRepository().delete(productId);
      await _loadProducts();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(_describeError(e, 'Could not delete this listing.'))));
    }
  }

  String _capitalize(String s) => s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

  Color _statusColor(String status) {
    switch (status) {
      case 'available':
        return AppColors.trust;
      default:
        return AppColors.inkSoft;
    }
  }

  @override
  Widget build(BuildContext context) {
    return RoleShell(
      title: 'Products',
      child: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_shopLoading) return const LoadingView();

    if (_shop == null) {
      return Padding(
        padding: kScreenPadding,
        child: EmptyState(
          title: "You haven't set up your shop yet",
          description: 'Create your shop profile to start listing pets and products.',
          action: ElevatedButton(
            onPressed: () => context.push('/seller/store'),
            child: const Text('Set up your shop'),
          ),
        ),
      );
    }

    return ListView(
      padding: kScreenPadding,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text('Products', style: AppTheme.display(fontSize: 26, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                textStyle: AppTheme.body(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              onPressed: () => setState(() => _formOpen = !_formOpen),
              child: Text(_formOpen ? 'Cancel' : 'Add a product'),
            ),
          ],
        ),
        if (_formOpen) ...[
          const SizedBox(height: 20),
          _buildForm(),
        ],
        const SizedBox(height: 28),
        _buildProductsList(),
      ],
    );
  }

  Widget _buildForm() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _category,
            decoration: const InputDecoration(labelText: 'Category'),
            items: const [
              DropdownMenuItem(value: 'medicine', child: Text('Medicine')),
              DropdownMenuItem(value: 'store', child: Text('Store')),
            ],
            onChanged: (value) => setState(() => _category = value ?? 'medicine'),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nameCtrl,
            decoration: InputDecoration(labelText: 'Product name', errorText: _errors['name']),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _priceCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: 'Price', errorText: _errors['price']),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _stockCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: false),
            decoration: InputDecoration(labelText: 'Stock quantity', errorText: _errors['stock_quantity']),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _descriptionCtrl,
            minLines: 3,
            maxLines: 5,
            decoration: const InputDecoration(labelText: 'Description'),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _photoUrlsCtrl,
            decoration: const InputDecoration(
              labelText: 'Photo URLs',
              hintText: 'https://example.com/photo1.jpg, https://example.com/photo2.jpg',
            ),
          ),
          const SizedBox(height: 6),
          Text('Separate multiple URLs with commas.', style: AppTheme.body(fontSize: 12, color: AppColors.inkSoft)),
          if (_formError.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(_formError, style: AppTheme.body(color: AppColors.error)),
          ],
          const SizedBox(height: 20),
          Align(
            alignment: Alignment.centerLeft,
            child: ElevatedButton(
              onPressed: _submitting ? null : _submit,
              child: Text(_submitting ? 'Adding…' : 'Add product'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductsList() {
    if (_productsLoading) return const LoadingView();
    if (_productsError != null) return ErrorView(message: _productsError!);
    if (_products.isEmpty) {
      if (_formOpen) return const SizedBox.shrink();
      return const EmptyState(
        title: 'No products listed yet',
        description: 'Add your first product to start reaching customers.',
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          for (var i = 0; i < _products.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: AppColors.border),
            _buildProductRow(_products[i]),
          ],
        ],
      ),
    );
  }

  Widget _buildProductRow(Product product) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(product.name, style: AppTheme.body(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(
            '${_capitalize(product.category)} · ${product.stockQuantity} in stock',
            style: AppTheme.body(fontSize: 13, color: AppColors.inkSoft),
          ),
          const SizedBox(height: 8),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 16,
            runSpacing: 6,
            children: [
              Text(
                formatPrice(product.price),
                style: AppTheme.body(fontWeight: FontWeight.w600, color: AppColors.accent),
              ),
              Text(
                _capitalize(product.status),
                style: AppTheme.body(fontWeight: FontWeight.w600, color: _statusColor(product.status)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              OutlinedButton(
                onPressed: () => _toggleAvailability(product),
                child: Text(product.status == 'available' ? 'Mark unavailable' : 'Mark available'),
              ),
              TextButton(
                style: TextButton.styleFrom(foregroundColor: AppColors.primary),
                onPressed: () => _deleteProduct(product.id),
                child: const Text('Delete'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
