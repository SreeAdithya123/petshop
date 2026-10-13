import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/columns.dart';
import '../models/models.dart';
import '../services/supabase_service.dart';
import '../state/catalog_provider.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../utils/pet_filters.dart';
import '../widgets/pet_widgets.dart';
import '../widgets/role_shell.dart';
import '../widgets/shared_widgets.dart';
import '../widgets/ui_kit.dart';

/// Species are free text on the seller side, so emoji are looked up
/// case-insensitively (see categoryStyle in src/pages/Home.jsx).
const _categoryEmoji = {
  'dog': '🐶',
  'cat': '🐱',
  'bird': '🐦',
  'rabbit': '🐰',
  'fish': '🐟',
  'hamster': '🐹',
  'guinea pig': '🐹',
  'small pet': '🐹',
  'turtle': '🐢',
  'reptile': '🦎',
};

const _exploreLinks = [
  (path: '/services', icon: Icons.content_cut, title: 'Services', desc: 'Vets, grooming, training and more'),
  (path: '/health', icon: Icons.monitor_heart_outlined, title: 'Health', desc: 'Check-ups and everyday pet care'),
  (path: '/store', icon: Icons.storefront_outlined, title: 'Store', desc: 'Medicine and supplies from local shops'),
];

const _whyPetsta = [
  (icon: Icons.medical_services_outlined, title: 'Health info included', desc: 'Species, breed, and age up front'),
  (icon: Icons.location_on_outlined, title: 'Pickup nearby', desc: "Nothing ships — meet at the shop"),
  (icon: Icons.headset_mic_outlined, title: 'Get help anytime', desc: "Raise a ticket, we'll follow up"),
  (icon: Icons.verified_outlined, title: 'Licensed shops only', desc: 'Every seller is a verified dealer'),
];

/// Mirrors src/pages/Home.jsx: gradient hero, why-us icons, entry cards for
/// Services / Health / Store, real catalog totals, a live Supabase-backed
/// featured-products strip, popular breeds, trending/top picks, top-rated
/// shops, a species grid and a newsletter signup. Pets and shops come from
/// the shared [catalogProvider] (no address or phone is ever shown).
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  List<Product> _featuredProducts = [];
  final _newsletterController = TextEditingController();
  String _newsletterState = 'idle'; // idle | sending | done | error

  @override
  void initState() {
    super.initState();
    _loadFeaturedProducts();
  }

  @override
  void dispose() {
    _newsletterController.dispose();
    super.dispose();
  }

  /// Public product columns plus just the shop's name (never `shops(*)`).
  Future<void> _loadFeaturedProducts() async {
    try {
      final rows = await SupabaseService.client
          .from('products')
          .select('$productPublicColumns, shops(name)')
          .eq('status', 'available')
          .order('created_at', ascending: false)
          .limit(8);
      if (!mounted) return;
      setState(() {
        _featuredProducts = (rows as List).map((r) => Product.fromJson(r as Map<String, dynamic>)).toList();
      });
    } catch (_) {
      // Supplementary strip: if the query fails it simply stays hidden.
    }
  }

  Future<void> _refresh() async {
    ref.invalidate(catalogProvider);
    final featured = _loadFeaturedProducts();
    try {
      await ref.read(catalogProvider.future).timeout(const Duration(seconds: 15));
    } catch (_) {
      // The catalog section renders its own error state.
    }
    await featured;
  }

  Future<void> _submitNewsletter() async {
    final email = _newsletterController.text.trim();
    if (email.isEmpty) return;
    setState(() => _newsletterState = 'sending');
    try {
      await SupabaseService.client.from('newsletter_subscribers').insert({'email': email});
      if (!mounted) return;
      setState(() {
        _newsletterState = 'done';
        _newsletterController.clear();
      });
    } catch (error) {
      if (!mounted) return;
      final isDuplicate = error.toString().toLowerCase().contains('duplicate');
      setState(() => _newsletterState = isDuplicate ? 'done' : 'error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final catalogAsync = ref.watch(catalogProvider);
    final loading = catalogAsync.isLoading && !catalogAsync.hasValue;
    final failed = catalogAsync.hasError && !catalogAsync.isLoading;
    final catalog = failed ? null : catalogAsync.value;
    // Non-null only when there is something to show (promotes cleanly below).
    final shown = (catalog != null && catalog.pets.isNotEmpty) ? catalog : null;

    final String badge;
    if (shown != null) {
      final petCount = shown.pets.length;
      final shopCount = shown.shops.length;
      badge = '$petCount ${petCount == 1 ? 'pet' : 'pets'} across $shopCount local ${shopCount == 1 ? 'shop' : 'shops'}';
    } else {
      badge = 'Pets from licensed local shops';
    }

    return RoleShell(
      title: 'PETSTA',
      child: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
          children: [
            _Hero(badge: badge),
            const SizedBox(height: 32),
            const _WhyPetsta(),
            const SizedBox(height: 24),
            const _ExploreLinks(),
            if (loading) ...[
              const SizedBox(height: 32),
              const _HomeSkeleton(),
            ],
            if (failed) ...[
              const SizedBox(height: 24),
              EmptyState(
                title: "We couldn't load pets right now",
                description: errorText(catalogAsync.error ?? 'Something went wrong.'),
                action: ElevatedButton(
                  onPressed: () => ref.invalidate(catalogProvider),
                  child: const Text('Try again'),
                ),
              ),
            ],
            if (catalog != null && catalog.pets.isEmpty) ...[
              const SizedBox(height: 24),
              EmptyState(
                title: 'No pets listed right now',
                description: "Shops haven't listed any pets yet. Check back soon.",
                action: ElevatedButton(
                  onPressed: () => context.push('/sellers'),
                  child: const Text('Browse shops'),
                ),
              ),
            ],
            if (shown != null) ...[
              const SizedBox(height: 32),
              _StatsRow(
                petCount: shown.pets.length,
                shopCount: shown.shops.length,
                speciesCount: shown.speciesList.length,
              ),
            ],
            if (_featuredProducts.isNotEmpty) ...[
              const SizedBox(height: 32),
              _SectionHeader(title: '🔥 Featured products', actionLabel: 'View all', onAction: () => context.push('/store')),
              const SizedBox(height: 12),
              SizedBox(
                height: 130,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _featuredProducts.length,
                  separatorBuilder: (context, index) => const SizedBox(width: 12),
                  itemBuilder: (context, index) => _FeaturedProductCard(product: _featuredProducts[index]),
                ),
              ),
            ],
            if (shown != null) ..._catalogSections(shown),
            const SizedBox(height: 32),
            _NewsletterCard(
              controller: _newsletterController,
              state: _newsletterState,
              onSubmit: _submitNewsletter,
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _catalogSections(Catalog catalog) {
    final trending = sortPets(catalog.pets, PetSort.newest).take(4).toList();
    final topPicks = sortPets(catalog.pets, PetSort.priceDesc).take(4).toList();

    final breeds = catalog.breedList.take(8).map((breed) {
      Pet? match;
      for (final pet in catalog.pets) {
        if (pet.breed == breed) {
          match = pet;
          break;
        }
      }
      return (breed: breed, pet: match);
    }).toList();

    final ratedShops = catalog.shops.where((shop) => catalog.statsFor(shop.id).reviewCount > 0).toList()
      ..sort((a, b) => catalog.statsFor(b.id).rating.compareTo(catalog.statsFor(a.id).rating));
    final shopsAreRated = ratedShops.isNotEmpty;
    final featuredShops = (shopsAreRated ? ratedShops : catalog.shops).take(3).toList();

    return [
      const SizedBox(height: 32),
      _SectionHeader(title: '🐾 Popular breeds', actionLabel: 'Explore all', onAction: () => context.push('/pets')),
      const SizedBox(height: 12),
      GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.95,
        children: [
          for (final entry in breeds)
            _BreedCard(
              breed: entry.breed,
              pet: entry.pet,
              onTap: () => context.push('/pets?breed=${Uri.encodeComponent(entry.breed)}'),
            ),
        ],
      ),
      const SizedBox(height: 32),
      const _StripTitle(icon: Icons.trending_up, color: AppColors.trust, title: 'Trending now'),
      const SizedBox(height: 12),
      _PetStrip(pets: trending, catalog: catalog),
      const SizedBox(height: 28),
      const _StripTitle(icon: Icons.favorite, color: AppColors.accent, title: 'Top picks'),
      const SizedBox(height: 12),
      _PetStrip(pets: topPicks, catalog: catalog),
      if (featuredShops.isNotEmpty) ...[
        const SizedBox(height: 32),
        Text(
          shopsAreRated ? '⭐ Top-rated shops' : '🏬 Local shops',
          style: AppTheme.display(fontSize: 19, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        for (final shop in featuredShops)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _TopShopCard(
              shop: shop,
              stats: catalog.statsFor(shop.id),
              petCount: catalog.petsByShop(shop.id).length,
            ),
          ),
      ],
      const SizedBox(height: 32),
      GridView.count(
        crossAxisCount: 3,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1,
        children: [
          for (final species in catalog.speciesList)
            _CategoryTile(
              species: species,
              onTap: () => context.push('/pets?species=${Uri.encodeComponent(species)}'),
            ),
        ],
      ),
    ];
  }
}

class _Hero extends StatelessWidget {
  final String badge;
  const _Hero({required this.badge});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.pets, size: 15, color: Colors.white),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    badge,
                    style: AppTheme.body(fontSize: 12.5, fontWeight: FontWeight.w600, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text.rich(
            TextSpan(
              style: AppTheme.display(fontSize: 32, fontWeight: FontWeight.w800, color: Colors.white),
              children: [
                const TextSpan(text: 'The '),
                TextSpan(
                  text: 'smartest',
                  style: TextStyle(
                    decoration: TextDecoration.underline,
                    decorationColor: Colors.pink[300],
                    decorationThickness: 2,
                  ),
                ),
                const TextSpan(text: ' way to find your best friend'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'From trusted local shops to your doorstep visit — browse, reserve, and pick up in person. '
            'Nothing ships.',
            style: AppTheme.body(fontSize: 15, color: Colors.white.withValues(alpha: 0.9)),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              ElevatedButton.icon(
                onPressed: () => context.push('/pets'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: AppColors.primary),
                icon: const Icon(Icons.pets, size: 16),
                label: const Text('Explore pets'),
              ),
              ElevatedButton(
                onPressed: () => context.push('/sellers'),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.tertiary, foregroundColor: Colors.white),
                child: const Text('Browse shops'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _TrustBadge(text: '✅ Every shop is a licensed dealer'),
              _TrustBadge(text: '🏬 Pickup in person — nothing ships'),
              _TrustBadge(text: '🎧 Support when you need it'),
            ],
          ),
        ],
      ),
    );
  }
}

class _TrustBadge extends StatelessWidget {
  final String text;
  const _TrustBadge({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(text, style: AppTheme.body(fontSize: 11.5, fontWeight: FontWeight.w600, color: Colors.white)),
    );
  }
}

class _WhyPetsta extends StatelessWidget {
  const _WhyPetsta();

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: [
        for (final item in _whyPetsta)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(item.icon, size: 26, color: AppColors.primary),
                const SizedBox(height: 6),
                Text(
                  item.title,
                  style: AppTheme.display(fontSize: 12.5, fontWeight: FontWeight.w700),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 2),
                Text(
                  item.desc,
                  style: AppTheme.body(fontSize: 10.5, color: AppColors.inkSoft),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// "More than pets": entry cards for Services, Health and the Store.
class _ExploreLinks extends StatelessWidget {
  const _ExploreLinks();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final link in _exploreLinks)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Material(
              color: AppColors.surface,
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: AppColors.border),
              ),
              child: InkWell(
                onTap: () => context.push(link.path),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(link.icon, size: 22, color: AppColors.primary),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(link.title, style: AppTheme.display(fontSize: 15.5, fontWeight: FontWeight.w700)),
                            Text(
                              link.desc,
                              style: AppTheme.body(fontSize: 13, color: AppColors.inkSoft),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.inkSoft),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Placeholder for the stats + strips while the catalog loads.
class _HomeSkeleton extends StatelessWidget {
  const _HomeSkeleton();

  @override
  Widget build(BuildContext context) {
    return SkeletonPulse(
      child: SizedBox(
        height: kPetStripHeight,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 3,
          separatorBuilder: (context, index) => const SizedBox(width: 14),
          itemBuilder: (context, index) => const SizedBox(width: 168, child: PetCardSkeleton()),
        ),
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  final int petCount;
  final int shopCount;
  final int speciesCount;
  const _StatsRow({required this.petCount, required this.shopCount, required this.speciesCount});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _StatCounter(target: petCount, label: 'Pets listed')),
        const SizedBox(width: 10),
        Expanded(child: _StatCounter(target: shopCount, label: 'Local shops')),
        const SizedBox(width: 10),
        Expanded(child: _StatCounter(target: speciesCount, label: 'Species available')),
      ],
    );
  }
}

class _StatCounter extends StatefulWidget {
  final int target;
  final String label;
  const _StatCounter({required this.target, required this.label});

  @override
  State<_StatCounter> createState() => _StatCounterState();
}

class _StatCounterState extends State<_StatCounter> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _controller.forward();
  }

  /// Counts up again if the real total changes (e.g. after a refresh).
  @override
  void didUpdateWidget(covariant _StatCounter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.target != widget.target) _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          final value = (widget.target * _animation.value).round();
          return Column(
            children: [
              ShaderMask(
                blendMode: BlendMode.srcIn,
                shaderCallback: (bounds) => AppColors.heroGradient.createShader(bounds),
                child: Text(
                  '$value',
                  style: AppTheme.display(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.label,
                style: AppTheme.body(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.inkSoft),
                textAlign: TextAlign.center,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String actionLabel;
  final VoidCallback onAction;
  const _SectionHeader({required this.title, required this.actionLabel, required this.onAction});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(title, style: AppTheme.display(fontSize: 19, fontWeight: FontWeight.w700))),
        TextButton(onPressed: onAction, child: Text(actionLabel)),
      ],
    );
  }
}

class _StripTitle extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  const _StripTitle({required this.icon, required this.color, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 6),
        Text(title, style: AppTheme.display(fontSize: 19, fontWeight: FontWeight.w700)),
      ],
    );
  }
}

/// Horizontal strip of [PetCard]s (trending / top picks).
class _PetStrip extends StatelessWidget {
  final List<Pet> pets;
  final Catalog catalog;
  const _PetStrip({required this.pets, required this.catalog});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: kPetStripHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: pets.length,
        separatorBuilder: (context, index) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          final pet = pets[index];
          return SizedBox(
            width: 168,
            child: PetCard(pet: pet, shopName: catalog.shopById(pet.shopId)?.name),
          );
        },
      ),
    );
  }
}

class _FeaturedProductCard extends StatelessWidget {
  final Product product;
  const _FeaturedProductCard({required this.product});

  @override
  Widget build(BuildContext context) {
    final shopName = product.shop?.name ?? '';
    return InkWell(
      onTap: () => context.push('/store/${product.id}'),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 150,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              titleCase(product.category),
              style: AppTheme.body(fontSize: 11, color: AppColors.inkSoft),
            ),
            const SizedBox(height: 2),
            Text(
              product.name,
              style: AppTheme.body(fontSize: 13.5, fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (shopName.isNotEmpty)
              Text(
                shopName,
                style: AppTheme.body(fontSize: 11, color: AppColors.inkSoft),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            const Spacer(),
            Text(
              formatPrice(product.price),
              style: AppTheme.display(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.accent),
            ),
          ],
        ),
      ),
    );
  }
}

class _BreedCard extends StatelessWidget {
  final String breed;
  final Pet? pet;
  final VoidCallback onTap;
  const _BreedCard({required this.breed, required this.pet, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final match = pet;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(12),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: PetPhotoView(
                src: match == null ? null : petCoverPhoto(match),
                species: match?.species ?? 'Dog',
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Text(
                breed,
                style: AppTheme.body(fontSize: 12.5, fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopShopCard extends StatelessWidget {
  final Shop shop;
  final ShopStats stats;
  final int petCount;
  const _TopShopCard({required this.shop, required this.stats, required this.petCount});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.push('/sellers/${shop.id}'),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(shop.name, style: AppTheme.display(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            if (stats.reviewCount > 0)
              RatingStarsView(rating: stats.rating, reviewCount: stats.reviewCount)
            else
              Text('No reviews yet', style: AppTheme.body(fontSize: 13, color: AppColors.inkSoft)),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.pets, size: 15, color: AppColors.inkSoft),
                const SizedBox(width: 5),
                Text(
                  '$petCount ${petCount == 1 ? 'pet' : 'pets'} listed',
                  style: AppTheme.body(fontSize: 13, color: AppColors.inkSoft),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  final String species;
  final VoidCallback onTap;
  const _CategoryTile({required this.species, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final emoji = _categoryEmoji[species.toLowerCase()] ?? '🐾';
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 28)),
            const SizedBox(height: 4),
            Text(
              species,
              style: AppTheme.display(fontSize: 11.5, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _NewsletterCard extends StatelessWidget {
  final TextEditingController controller;
  final String state;
  final VoidCallback onSubmit;
  const _NewsletterCard({required this.controller, required this.state, required this.onSubmit});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '📬 Join the PETSTA community',
            style: AppTheme.display(fontSize: 19, fontWeight: FontWeight.w800, color: Colors.white),
          ),
          const SizedBox(height: 6),
          Text(
            'Pet care tips and new listings near you, delivered occasionally.',
            style: AppTheme.body(fontSize: 13, color: Colors.white.withValues(alpha: 0.9)),
          ),
          const SizedBox(height: 16),
          if (state == 'done')
            Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "You're subscribed — welcome to PETSTA.",
                    style: AppTheme.body(fontWeight: FontWeight.w600, color: Colors.white),
                  ),
                ),
              ],
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: controller,
                  keyboardType: TextInputType.emailAddress,
                  style: AppTheme.body(color: AppColors.ink),
                  decoration: InputDecoration(
                    hintText: 'Your email address',
                    filled: true,
                    fillColor: Colors.white,
                    prefixIcon: const Icon(Icons.email_outlined, color: AppColors.inkSoft),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: state == 'sending' ? null : onSubmit,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: AppColors.primary),
                  child: Text(state == 'sending' ? 'Subscribing…' : 'Subscribe'),
                ),
                if (state == 'error') ...[
                  const SizedBox(height: 8),
                  Text(
                    "Couldn't subscribe right now — try again in a moment.",
                    style: AppTheme.body(fontSize: 12.5, color: Colors.pink.shade100),
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }
}
