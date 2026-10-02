import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/seed_data.dart';
import '../models/models.dart';
import '../repositories/repositories.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/pet_widgets.dart';
import '../widgets/role_shell.dart';

const _categoryStyle = {
  'Dog': (emoji: '🐶', color: AppColors.primary),
  'Cat': (emoji: '🐱', color: AppColors.accent),
  'Bird': (emoji: '🐦', color: AppColors.secondary),
  'Rabbit': (emoji: '🐰', color: AppColors.trust),
  'Small Pet': (emoji: '🐹', color: AppColors.warning),
};

const _whyPetsta = [
  (icon: Icons.medical_services_outlined, title: 'Health info included', desc: 'Species, breed, and age up front'),
  (icon: Icons.location_on_outlined, title: 'Pickup nearby', desc: "Nothing ships — meet at the shop"),
  (icon: Icons.headset_mic_outlined, title: 'Get help anytime', desc: "Raise a ticket, we'll follow up"),
  (icon: Icons.verified_outlined, title: 'Licensed shops only', desc: 'Every seller is a verified dealer'),
];

/// Mirrors src/pages/Home.jsx (post-PETSTA redesign): gradient hero, why-us
/// icons, animated stats, a live Supabase-backed featured-products strip,
/// popular breeds, trending/top picks, top-rated shops, a category grid,
/// and a real newsletter signup.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
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

  Future<void> _loadFeaturedProducts() async {
    try {
      final products = await ProductsRepository().listAvailable();
      if (!mounted) return;
      setState(() => _featuredProducts = products.take(8).toList());
    } catch (_) {
      // Featured strip is optional decoration; fail quietly.
    }
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

  List<SeedPet> get _trending {
    final list = seedPets.where((pet) => pet.status != 'sold').toList()
      ..sort((a, b) => b.listedDate.compareTo(a.listedDate));
    return list.take(4).toList();
  }

  List<SeedPet> get _topPicks {
    final list = seedPets.where((pet) => pet.status != 'sold').toList()
      ..sort((a, b) => b.price.compareTo(a.price));
    return list.take(4).toList();
  }

  List<SeedShop> get _topShops {
    final list = seedShops.where((shop) => shop.reviewCount > 0).toList()
      ..sort((a, b) => b.rating.compareTo(a.rating));
    return list.take(3).toList();
  }

  List<({String breed, SeedPet? pet})> get _featuredBreeds {
    return breedList.take(8).map((breed) {
      SeedPet? match;
      for (final pet in seedPets) {
        if (pet.breed == breed) {
          match = pet;
          break;
        }
      }
      return (breed: breed, pet: match);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return RoleShell(
      title: 'PETSTA',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
        children: [
          _Hero(petCount: seedPets.length, shopCount: seedShops.length),
          const SizedBox(height: 32),
          _WhyPetsta(),
          const SizedBox(height: 32),
          _StatsRow(
            petCount: seedPets.length,
            shopCount: seedShops.length,
            speciesCount: speciesList.length,
          ),
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
              for (final entry in _featuredBreeds)
                _BreedCard(
                  breed: entry.breed,
                  pet: entry.pet,
                  onTap: () => context.push('/pets?breed=${Uri.encodeComponent(entry.breed)}'),
                ),
            ],
          ),
          const SizedBox(height: 32),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Icon(Icons.trending_up, size: 20, color: AppColors.trust),
              const SizedBox(width: 6),
              Text('Trending now', style: AppTheme.display(fontSize: 19, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 250,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _trending.length,
              separatorBuilder: (context, index) => const SizedBox(width: 14),
              itemBuilder: (context, index) => SizedBox(width: 170, child: _PetMiniCard(pet: _trending[index])),
            ),
          ),
          const SizedBox(height: 28),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Icon(Icons.favorite, size: 20, color: AppColors.accent),
              const SizedBox(width: 6),
              Text('Top picks', style: AppTheme.display(fontSize: 19, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 250,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _topPicks.length,
              separatorBuilder: (context, index) => const SizedBox(width: 14),
              itemBuilder: (context, index) => SizedBox(width: 170, child: _PetMiniCard(pet: _topPicks[index])),
            ),
          ),
          const SizedBox(height: 32),
          Text('⭐ Top-rated shops', style: AppTheme.display(fontSize: 19, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          ..._topShops.map(
            (shop) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _TopShopCard(shop: shop),
            ),
          ),
          const SizedBox(height: 32),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1,
            children: [
              for (final species in speciesList)
                _CategoryTile(
                  species: species,
                  onTap: () => context.push('/pets?species=${Uri.encodeComponent(species)}'),
                ),
            ],
          ),
          const SizedBox(height: 32),
          _NewsletterCard(
            controller: _newsletterController,
            state: _newsletterState,
            onSubmit: _submitNewsletter,
          ),
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  final int petCount;
  final int shopCount;
  const _Hero({required this.petCount, required this.shopCount});

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
                Text(
                  '$petCount+ pets across $shopCount local shops',
                  style: AppTheme.body(fontSize: 12.5, fontWeight: FontWeight.w600, color: Colors.white),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          RichText(
            text: TextSpan(
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
          Wrap(
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
                  '$value+',
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

class _FeaturedProductCard extends StatelessWidget {
  final Product product;
  const _FeaturedProductCard({required this.product});

  @override
  Widget build(BuildContext context) {
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
              product.category,
              style: AppTheme.body(fontSize: 11, color: AppColors.inkSoft),
            ),
            const SizedBox(height: 2),
            Text(
              product.name,
              style: AppTheme.body(fontSize: 13.5, fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (product.shop != null)
              Text(
                product.shop!.name,
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
  final SeedPet? pet;
  final VoidCallback onTap;
  const _BreedCard({required this.breed, required this.pet, required this.onTap});

  @override
  Widget build(BuildContext context) {
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: PetPhotoView(src: pet?.photos?.firstOrNull, species: pet?.species ?? 'Dog'),
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

class _PetMiniCard extends StatelessWidget {
  final SeedPet pet;
  const _PetMiniCard({required this.pet});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.push('/pets/${pet.id}'),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: PetPhotoView(src: pet.photos?.firstOrNull, species: pet.species),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pet.name,
                    style: AppTheme.body(fontSize: 15, fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${pet.species} · ${pet.breed}',
                    style: AppTheme.body(fontSize: 12.5, color: AppColors.inkSoft),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    formatPrice(pet.price),
                    style: AppTheme.display(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.accent),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopShopCard extends StatelessWidget {
  final SeedShop shop;
  const _TopShopCard({required this.shop});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.push('/sellers/${shop.id}'),
      borderRadius: BorderRadius.circular(12),
      child: Container(
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
            RatingStarsView(rating: shop.rating, reviewCount: shop.reviewCount),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.location_on_outlined, size: 15, color: AppColors.inkSoft),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    shop.city,
                    style: AppTheme.body(fontSize: 13, color: AppColors.inkSoft),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
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
    final style = _categoryStyle[species] ?? (emoji: '🐾', color: AppColors.primary);
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
            Text(style.emoji, style: const TextStyle(fontSize: 28)),
            const SizedBox(height: 4),
            Text(
              species,
              style: AppTheme.display(fontSize: 11.5, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
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

extension _FirstOrNull<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
