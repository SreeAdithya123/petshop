import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/models.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../../widgets/pet_widgets.dart';
import '../../widgets/seller/seller_common.dart';
import '../../widgets/seller_scaffold.dart';
import '../../widgets/shared_widgets.dart';
import '../../widgets/ui_kit.dart';

/// Ports src/pages/seller/Products.jsx: a shop owner's own product listings
/// with an Add / Edit form in a bottom sheet and per-row availability toggle,
/// Edit and Delete actions.
class SellerProductsScreen extends StatelessWidget {
  const SellerProductsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SellerScaffold(
      title: 'Products',
      subtitle: 'Your medicine and store listings.',
      builder: (context, shop) => _ProductsWorkspace(shop: shop),
    );
  }
}

const _filters = <StatusFilter>[
  StatusFilter('all', 'All'),
  StatusFilter('available', 'Available'),
  StatusFilter('unavailable', 'Unavailable'),
];

const _categoryLabels = {'medicine': 'Medicine', 'store': 'Store'};

String _statusOf(Product product) => product.status;

Future<List<Product>> _fetchProducts(String shopId) async {
  final rows = await fetchAllRows(() => SupabaseService.client.from('products').select().eq('shop_id', shopId));
  final products = rows.map(Product.fromJson).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return products;
}

class _ProductsWorkspace extends ConsumerStatefulWidget {
  final Shop shop;
  const _ProductsWorkspace({required this.shop});

  @override
  ConsumerState<_ProductsWorkspace> createState() => _ProductsWorkspaceState();
}

class _ProductsWorkspaceState extends ConsumerState<_ProductsWorkspace> {
  late final SellerQuery<List<Product>> _query;
  String _filter = 'all';
  int _limit = kPageSize;
  String? _busyId;

  @override
  void initState() {
    super.initState();
    final shopId = widget.shop.id;
    _query = SellerQuery<List<Product>>(() => _fetchProducts(shopId));
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _openForm([Product? product]) async {
    final saved = await showFormSheet<bool>(
      context,
      title: product == null ? 'Add a product' : 'Edit product',
      builder: (sheetContext) => _ProductForm(shopId: widget.shop.id, product: product),
    );
    if (saved != true || !mounted) return;
    showSnack(context, product == null ? 'Product added.' : 'Product updated.');
    _query.reload();
  }

  Future<void> _toggleAvailability(Product product) async {
    if (_busyId != null) return;
    final next = product.status == 'available' ? 'unavailable' : 'available';
    setState(() => _busyId = product.id);
    final failure = await updateRow('products', product.id, {'status': next}, match: {'status': product.status});
    if (!mounted) return;
    setState(() => _busyId = null);

    if (failure != null) {
      showSnack(context, failure, error: true);
      if (failure == kNothingChanged) _query.reload();
      return;
    }
    showSnack(context, next == 'available' ? 'Now available to customers.' : 'Hidden from customers.');
    _query.reload();
  }

  Future<void> _delete(Product product) async {
    if (_busyId != null) return;
    final confirmed = await confirmAction(
      context,
      title: 'Delete this listing?',
      message: '${product.name} will be removed from your shop. This can\'t be undone.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!confirmed || !mounted) return;

    setState(() => _busyId = product.id);
    final failure = await deleteRow('products', product.id);
    if (!mounted) return;
    setState(() => _busyId = null);

    if (failure != null) {
      showSnack(context, failure, error: true);
      return;
    }
    showSnack(context, 'Listing deleted.');
    _query.reload();
  }

  @override
  Widget build(BuildContext context) {
    listenForShopRefresh(ref, _query.reload);
    final readOnly = widget.shop.status == 'suspended';

    return SellerQueryPanel<List<Product>>(
      query: _query,
      what: 'your products',
      builder: (context, products) {
        final visible = applyStatusFilter(_filters, _filter, products, _statusOf);
        final shown = math.min(_limit, visible.length);
        final addButton = ElevatedButton.icon(
          onPressed: () => _openForm(),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Add a product'),
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!readOnly && products.isNotEmpty) ...[
              Align(alignment: Alignment.centerLeft, child: addButton),
              const SizedBox(height: 16),
            ],
            if (products.isNotEmpty) ...[
              FilterChipBar<String>(
                options: filterOptions(_filters, products, _statusOf),
                selected: _filter,
                onSelected: (value) => setState(() {
                  _filter = value;
                  _limit = kPageSize;
                }),
              ),
              const SizedBox(height: 16),
            ],
            if (products.isEmpty)
              CardBox(
                child: EmptyState(
                  title: 'No products listed yet',
                  description: 'Add your first product to start reaching customers.',
                  action: readOnly ? null : addButton,
                ),
              )
            else if (visible.isEmpty)
              const CardBox(
                child: EmptyState(title: 'Nothing here', description: 'No products match this filter.'),
              )
            else ...[
              for (final product in visible.take(shown))
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _ProductCard(
                    key: ValueKey(product.id),
                    product: product,
                    readOnly: readOnly,
                    busy: _busyId == product.id,
                    onToggle: () => _toggleAvailability(product),
                    onEdit: () => _openForm(product),
                    onDelete: () => _delete(product),
                  ),
                ),
              LoadMoreButton(
                shown: shown,
                total: visible.length,
                onPressed: () => setState(() => _limit += kPageSize),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _ProductCard extends StatelessWidget {
  final Product product;
  final bool readOnly;
  final bool busy;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ProductCard({
    super.key,
    required this.product,
    required this.readOnly,
    required this.busy,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final available = product.status == 'available';
    final outOfStock = product.stockQuantity <= 0;
    final category = _categoryLabels[product.category] ?? titleCase(product.category);

    return CardBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 56,
                  height: 56,
                  child: ProductPhotoView(
                    src: product.photoUrls.isNotEmpty ? product.photoUrls.first : null,
                    category: product.category,
                    cacheWidth: 112,
                    semanticLabel: 'Photo of ${product.name}',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.display(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$category · ${product.stockQuantity} in stock',
                      style: AppTheme.body(fontSize: 13, color: AppColors.inkSoft),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              StatusBadge(status: product.status, label: titleCase(product.status)),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                formatPrice(product.price),
                style: AppTheme.body(fontWeight: FontWeight.w600, color: AppColors.accent),
              ),
              if (outOfStock)
                Text('Out of stock', style: AppTheme.body(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.error)),
            ],
          ),
          if (!readOnly) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                OutlinedButton(
                  onPressed: busy ? null : onToggle,
                  child: Text(available ? 'Mark unavailable' : 'Mark available'),
                ),
                TextButton(
                  onPressed: busy ? null : onEdit,
                  child: const Text('Edit'),
                ),
                TextButton(
                  onPressed: busy ? null : onDelete,
                  style: TextButton.styleFrom(foregroundColor: AppColors.error),
                  child: const Text('Delete'),
                ),
                if (busy)
                  Semantics(
                    label: 'Saving',
                    child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Add / edit form shown in a bottom sheet. Pops with `true` once saved.
class _ProductForm extends StatefulWidget {
  final String shopId;
  final Product? product;
  const _ProductForm({required this.shopId, this.product});

  @override
  State<_ProductForm> createState() => _ProductFormState();
}

class _ProductFormState extends State<_ProductForm> {
  late final TextEditingController _name;
  late final TextEditingController _price;
  late final TextEditingController _stock;
  late final TextEditingController _description;
  late final TextEditingController _photos;
  late String _category;

  String? _nameError;
  String? _priceError;
  String? _stockError;
  String? _photosError;
  String? _formError;
  bool _submitting = false;

  bool get _editing => widget.product != null;

  @override
  void initState() {
    super.initState();
    final product = widget.product;
    _name = TextEditingController(text: product?.name ?? '');
    _price = TextEditingController(text: product == null ? '' : plainNumber(product.price));
    _stock = TextEditingController(text: product == null ? '' : '${product.stockQuantity}');
    _description = TextEditingController(text: product?.description ?? '');
    _photos = TextEditingController(text: product?.photoUrls.join(', ') ?? '');
    _category = (product != null && _categoryLabels.containsKey(product.category)) ? product.category : 'medicine';
  }

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    _stock.dispose();
    _description.dispose();
    _photos.dispose();
    super.dispose();
  }

  bool _validate() {
    String? nameError;
    String? priceError;
    String? stockError;

    if (_name.text.trim().isEmpty) nameError = 'Enter a product name.';

    final priceText = _price.text.trim();
    final price = parseAmount(priceText);
    if (priceText.isEmpty) {
      priceError = 'Enter a price.';
    } else if (price == null || price <= 0) {
      priceError = 'Price must be greater than zero.';
    }

    final stockText = _stock.text.trim();
    final stock = int.tryParse(stockText);
    if (stockText.isEmpty) {
      stockError = 'Enter a stock quantity.';
    } else if (stock == null || stock < 0) {
      stockError = 'Enter a whole number, like 12.';
    }

    final photosError = photoUrlsError(_photos.text);

    setState(() {
      _nameError = nameError;
      _priceError = priceError;
      _stockError = stockError;
      _photosError = photosError;
    });
    return nameError == null && priceError == null && stockError == null && photosError == null;
  }

  Future<void> _submit() async {
    if (_submitting) return;
    FocusScope.of(context).unfocus();
    setState(() => _formError = null);
    if (!_validate()) return;

    final description = _description.text.trim();
    final payload = <String, dynamic>{
      'category': _category,
      'name': _name.text.trim(),
      'description': description.isEmpty ? null : description,
      'price': parseAmount(_price.text)!,
      'stock_quantity': int.parse(_stock.text.trim()),
      'photo_urls': parseUrlList(_photos.text),
    };

    setState(() => _submitting = true);
    final product = widget.product;
    final failure = product == null
        ? await insertRow('products', {'shop_id': widget.shopId, ...payload})
        : await updateRow('products', product.id, payload);
    if (!mounted) return;

    if (failure != null) {
      setState(() {
        _submitting = false;
        _formError = failure;
      });
      return;
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = !_submitting;
    return PopScope(
      canPop: !_submitting,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _category,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Category'),
            items: [
              for (final entry in _categoryLabels.entries)
                DropdownMenuItem<String>(value: entry.key, child: Text(entry.value)),
            ],
            onChanged: enabled ? (value) => setState(() => _category = value ?? 'medicine') : null,
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _name,
            enabled: enabled,
            textCapitalization: TextCapitalization.sentences,
            inputFormatters: [LengthLimitingTextInputFormatter(120)],
            decoration: InputDecoration(labelText: 'Product name', errorText: _nameError, errorMaxLines: 2),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _price,
            enabled: enabled,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
            decoration: InputDecoration(
              labelText: 'Price (INR)',
              prefixText: '₹ ',
              errorText: _priceError,
              errorMaxLines: 2,
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _stock,
            enabled: enabled,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
            decoration: InputDecoration(labelText: 'Stock quantity', errorText: _stockError, errorMaxLines: 2),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _description,
            enabled: enabled,
            minLines: 3,
            maxLines: 5,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Description', alignLabelWithHint: true),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _photos,
            enabled: enabled,
            keyboardType: TextInputType.url,
            autocorrect: false,
            decoration: InputDecoration(
              labelText: 'Photo URLs',
              hintText: 'https://example.com/photo1.jpg, https://example.com/photo2.jpg',
              helperText: 'Separate multiple links with commas.',
              errorText: _photosError,
              errorMaxLines: 2,
            ),
          ),
          if (_formError != null) ...[
            const SizedBox(height: 14),
            NoticeBox.error(message: _formError!),
          ],
          const SizedBox(height: 20),
          LoadingButton(
            label: _editing ? 'Save changes' : 'Add product',
            loading: _submitting,
            expand: true,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}
