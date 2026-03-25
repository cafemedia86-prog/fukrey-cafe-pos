import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../repositories/user_repository.dart';
import '../../repositories/menu_repository.dart';
import '../../repositories/offer_repository.dart';
import '../../core/widgets/safe_image.dart';
import 'customer_menu.dart';
import '../../core/widgets/shimmer_loader.dart';
import '../pos/cart_provider.dart';
import '../auth/auth_provider.dart';
import '../../repositories/auth_repository.dart';

class CustomerHomeScreen extends ConsumerStatefulWidget {
  const CustomerHomeScreen({super.key});

  @override
  ConsumerState<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends ConsumerState<CustomerHomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  bool _isSearchFocused = false;
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final menuItemsAsync = ref.watch(menuItemsProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final cartState = ref.watch(cartProvider);
    final offersAsync = ref.watch(offersProvider);
    final userProfileAsync = ref.watch(userProfileProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFFDFCFB),
      body: Stack(
        children: [
          menuItemsAsync.when(
            data: (items) {
              if (items.isEmpty) {
                return const Center(child: Text('No items available'));
              }
              return _HomeBody(
                items: items, 
                categoriesAsync: categoriesAsync,
                offersAsync: offersAsync,
                searchController: _searchController,
                searchFocus: _searchFocus,
                isSearchFocused: _isSearchFocused,
                searchQuery: _searchQuery,
                onSearchStateChanged: (focused, query) {
                  setState(() {
                    _isSearchFocused = focused;
                    _searchQuery = query;
                  });
                },
                userProfileAsync: userProfileAsync,
              );
            },
            loading: () => const HomeShimmer(),
            error: (e, st) => Center(child: Text('Error: $e')),
          ),
          
          if (cartState.items.isNotEmpty)
            Positioned(
              bottom: 20,
              left: 20,
              right: 20,
              child: GestureDetector(
                onTap: () => context.push('/customer/checkout'),
                child: Hero(
                  tag: 'cart-summary',
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B4513),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF8B4513).withOpacity(0.3),
                          blurRadius: 15,
                          offset: const Offset(0, 8),
                        )
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.shopping_bag, color: Colors.white, size: 20),
                            const SizedBox(width: 12),
                            Text(
                              '${cartState.items.length} items',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Text(
                              '₹${cartState.total.toStringAsFixed(0)}',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 14),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: _CustomBottomNav(
        onHomeTap: () {
          setState(() {
            _isSearchFocused = false;
            _searchQuery = '';
            _searchController.clear();
            _searchFocus.unfocus();
          });
        },
        onSearchTap: () {
          _searchFocus.requestFocus();
          setState(() => _isSearchFocused = true);
        },
        onCartTap: () => context.push('/customer/checkout'),
        onProfileTap: () {
          final profile = ref.read(userProfileProvider).value;
          if (profile != null) {
            _showProfileDialog(context, ref, profile);
          } else {
            context.push('/customer/login');
          }
        },
      ),
    );
  }

  void _showProfileDialog(BuildContext context, WidgetRef ref, UserModel profile) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      backgroundColor: Colors.white,
      builder: (context) => Container(
        padding: const EdgeInsets.all(32),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
            ),
            const CircleAvatar(
              radius: 45,
              backgroundColor: Color(0xFFFDEFE6),
              child: Icon(Icons.person, size: 50, color: Color(0xFF8B4513)),
            ),
            const SizedBox(height: 16),
            Text(profile.fullName ?? 'Customer', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF6B1F0E))),
            Text(profile.email, style: TextStyle(color: Colors.grey[500], fontSize: 16)),
            const SizedBox(height: 32),
            _buildProfileOption(Icons.history_rounded, 'Order History', () => Navigator.pop(context)),
            _buildProfileOption(Icons.settings_outlined, 'Account Settings', () => Navigator.pop(context)),
            const Divider(height: 32),
            _buildProfileOption(Icons.logout_rounded, 'Sign Out', () async {
              await ref.read(authRepositoryProvider).signOut();
              if (context.mounted) Navigator.pop(context);
            }, isDestructive: true),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileOption(IconData icon, String title, VoidCallback onTap, {bool isDestructive = false}) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isDestructive ? Colors.red[50] : const Color(0xFFFDFCFB),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: isDestructive ? Colors.red : const Color(0xFF8B4513), size: 20),
      ),
      title: Text(title, style: TextStyle(fontWeight: FontWeight.w600, color: isDestructive ? Colors.red : Colors.black87)),
      trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
    );
  }
}

class _HomeBody extends StatefulWidget {
  final List<dynamic> items;
  final AsyncValue<List<Map<String, dynamic>>> categoriesAsync;
  final AsyncValue<List<Offer>> offersAsync;
  final TextEditingController searchController;
  final FocusNode searchFocus;
  final bool isSearchFocused;
  final String searchQuery;
  final Function(bool, String) onSearchStateChanged;
  final AsyncValue<UserModel?> userProfileAsync;
  
  const _HomeBody({
    required this.items, 
    required this.categoriesAsync,
    required this.offersAsync,
    required this.searchController,
    required this.searchFocus,
    required this.isSearchFocused,
    required this.searchQuery,
    required this.onSearchStateChanged,
    required this.userProfileAsync,
  });

  @override
  State<_HomeBody> createState() => _HomeBodyState();
}

class _HomeBodyState extends State<_HomeBody> {
  int _currentOfferPage = 0;
  final PageController _pageController = PageController();
  Timer? _autoScrollTimer;

  @override
  void initState() {
    super.initState();
    _startAutoScroll();
  }

  void _startAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      widget.offersAsync.whenData((offers) {
        if (offers.isNotEmpty && _pageController.hasClients) {
          int nextPage = (_currentOfferPage + 1) % offers.length;
          _pageController.animateToPage(
            nextPage,
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeInOut,
          );
        }
      });
    });
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    final heroHeight = (screenHeight * 0.45).clamp(250.0, 380.0);
    final isSmallScreen = MediaQuery.sizeOf(context).width < 380;
    final horizontalPadding = 20.0;

    return Stack(
      children: [
        SingleChildScrollView(
          physics: widget.isSearchFocused ? const NeverScrollableScrollPhysics() : const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),
              
              // NEW HEADER ABOVE SLIDER
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 15),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
                        border: Border.all(color: Colors.grey[100]!),
                      ),
                      child: const Icon(Icons.location_on, color: Color(0xFF8B4513), size: 22),
                    ),
                    Column(
                      children: [
                        GestureDetector(
                          onLongPress: () => context.push('/login'),
                          child: const Text('Fukrey Cafe', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF6B1F0E))),
                        ),
                        widget.userProfileAsync.when(
                          data: (profile) => Text(
                            profile != null ? 'Hi, ${profile.fullName?.split(' ').first}' : 'Welcome!',
                            style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500),
                          ),
                          loading: () => const SizedBox.shrink(),
                          error: (_, __) => const SizedBox.shrink(),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
                        border: Border.all(color: Colors.grey[100]!),
                      ),
                      child: const Icon(Icons.notifications_none, color: Color(0xFF8B4513), size: 22),
                    ),
                  ],
                ),
              ),

              Stack(
                children: [
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                    child: widget.offersAsync.when(
                      data: (offers) {
                        if (offers.isEmpty) {
                          return SafeImage(
                            url: 'https://images.unsplash.com/photo-1495474472287-4d71bcdd2085?q=80&w=1000',
                            height: heroHeight * 0.75,
                            width: double.infinity,
                            borderRadius: BorderRadius.circular(25),
                          );
                        }
                        return SizedBox(
                          height: heroHeight * 0.75,
                          child: PageView.builder(
                            controller: _pageController,
                            onPageChanged: (idx) => setState(() => _currentOfferPage = idx),
                            itemCount: offers.length,
                            itemBuilder: (context, index) => SafeImage(
                              url: offers[index].imageUrl,
                              height: heroHeight * 0.75,
                              width: double.infinity,
                              borderRadius: BorderRadius.circular(25),
                            ),
                          ),
                        );
                      },
                      loading: () => ShimmerLoader(height: heroHeight * 0.75, width: double.infinity, borderRadius: 25),
                      error: (e, s) => Container(height: heroHeight * 0.75, decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(25))),
                    ),
                  ),
                  Container(
                    margin: EdgeInsets.symmetric(horizontal: horizontalPadding),
                    height: heroHeight * 0.75,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(25),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.01),
                          Colors.black.withOpacity(0.35),
                        ],
                      ),
                    ),
                  ),
                  // Dots indicator
                  widget.offersAsync.when(
                    data: (offers) {
                      if (offers.length <= 1) return const SizedBox.shrink();
                      return Positioned(
                        bottom: 15,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: List.generate(offers.length, (index) {
                              return AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                margin: const EdgeInsets.symmetric(horizontal: 4),
                                width: _currentOfferPage == index ? 16 : 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: _currentOfferPage == index ? Colors.white : Colors.white.withOpacity(0.5),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              );
                            }),
                          ),
                        ),
                      );
                    },
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                ],
              ),
              
              // NEW SEARCH BAR POSITION BELOW HERO
              Padding(
                padding: const EdgeInsets.fromLTRB(25, 20, 25, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 55,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(15),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 15,
                              offset: const Offset(0, 5),
                            )
                          ],
                          border: Border.all(color: Colors.grey[100]!),
                        ),
                        child: TextField(
                          controller: widget.searchController,
                          focusNode: widget.searchFocus,
                          onTap: () => widget.onSearchStateChanged(true, widget.searchQuery),
                          onChanged: (val) => widget.onSearchStateChanged(true, val.trim()),
                          onSubmitted: (val) {
                            if (val.trim().isNotEmpty) {
                              context.push('/customer/menu/general?search=${Uri.encodeComponent(val.trim())}');
                            }
                          },
                          style: const TextStyle(color: Colors.black87),
                          textInputAction: TextInputAction.search,
                          decoration: InputDecoration(
                            hintText: 'Search your favorite brew...',
                            hintStyle: TextStyle(color: Colors.grey[400]),
                            border: InputBorder.none,
                            icon: const Icon(Icons.search, color: Color(0xFF8B4513)),
                            suffixIcon: widget.searchQuery.isNotEmpty 
                                ? IconButton(
                                    icon: const Icon(Icons.clear, color: Colors.grey, size: 20),
                                    onPressed: () {
                                      widget.searchController.clear();
                                      widget.onSearchStateChanged(true, '');
                                    },
                                  )
                                : null,
                            isDense: true,
                          ),
                        ),
                      ),
                    ),
                    if (widget.isSearchFocused)
                      Padding(
                        padding: const EdgeInsets.only(left: 10),
                        child: TextButton(
                          onPressed: () => widget.onSearchStateChanged(false, ''),
                          child: const Text('Cancel', style: TextStyle(color: Color(0xFF8B4513), fontWeight: FontWeight.bold)),
                        ),
                      ),
                  ],
                ),
              ),

          const SizedBox(height: 30),
          
          Padding(
            padding: const EdgeInsets.only(left: 25),
            child: widget.categoriesAsync.when(
              data: (categories) => SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: categories.map((cat) => _CategoryPill(
                    id: cat['id'],
                    name: cat['name'] ?? 'General',
                  )).toList(),
                ),
              ),
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ),

          const SizedBox(height: 35),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 25),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Today\'s Special', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                GestureDetector(
                  onTap: () => context.push('/customer/menu/general'),
                  child: const Text('See all', style: TextStyle(color: Color(0xFF8B4513), fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 15),
          SizedBox(
            height: 280,
            child: ListView.builder(
              padding: const EdgeInsets.only(left: 25, right: 10),
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: widget.items.take(5).length,
              itemBuilder: (context, index) => _SpecialCard(item: widget.items[index]),
            ),
          ),

          const SizedBox(height: 35),
          
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 25),
            child: Text('Popular Choices', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(height: 15),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 25),
            child: Column(
              children: widget.items.skip(5).take(10).map((item) => _MenuRowItem(item: item)).toList(),
            ),
          ),
          
          const SizedBox(height: 100),
            ],
          ),
        ),
        if (widget.isSearchFocused && widget.searchQuery.isNotEmpty)
          Positioned(
            top: heroHeight * 0.75 + 165, // Adjust for new card offset + Header
            left: 0,
            right: 0,
            bottom: 0,
            child: Material(
              color: Colors.white,
              child: _buildSearchResults(),
            ),
          ),
      ],
    );
  }

  Widget _buildSearchResults() {
    final filtered = widget.items.where((i) {
      final query = widget.searchQuery.toLowerCase();
      final nameMatches = i.name.toString().toLowerCase().contains(query);
      final descMatches = i.description?.toString().toLowerCase().contains(query) ?? false;
      return nameMatches || descMatches;
    }).toList();

    return Container(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(25, 20, 25, 10),
            child: Row(
              children: [
                const Text('Search Results', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const Spacer(),
                Text('${filtered.length} found', style: const TextStyle(color: Colors.grey)),
              ],
            ),
          ),
          if (filtered.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.search_off, size: 64, color: Colors.grey[300]),
                    const SizedBox(height: 16),
                    Text('No matches for "${widget.searchQuery}"', style: TextStyle(color: Colors.grey[600])),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.only(bottom: 100),
                itemCount: filtered.length,
                itemBuilder: (context, index) => _MenuRowItem(item: filtered[index]),
              ),
            ),
        ],
      ),
    );
  }
}

class _CategoryPill extends StatelessWidget {
  final String? id;
  final String name;
  const _CategoryPill({this.id, required this.name});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/customer/menu/general?categoryId=$id'),
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(25),
          border: Border.all(color: Colors.grey[200]!),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Text(
          name,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87),
        ),
      ),
    );
  }
}

class _SpecialCard extends ConsumerWidget {
  final dynamic item;
  const _SpecialCard({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () => context.push('/customer/menu/general'),
      child: Container(
        width: 200,
        margin: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 8)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                child: SafeImage(url: item.imageUrl, width: double.infinity, height: double.infinity),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('₹${item.price}', style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF8B4513))),
                      Builder(
                        builder: (context) {
                          final cartItem = ref.watch(cartProvider).items.where((i) => i.menuItem.id == item.id).firstOrNull;
                          final quantity = cartItem?.quantity ?? 0;

                          if (quantity == 0) {
                            return GestureDetector(
                              onTap: () {
                                ref.read(cartProvider.notifier).addItem(item);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Added ${item.name} to cart'), duration: const Duration(seconds: 1)),
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: const BoxDecoration(color: Color(0xFFFDEFE6), shape: BoxShape.circle),
                                child: const Icon(Icons.add, size: 18, color: Color(0xFF8B4513)),
                              ),
                            );
                          }

                          return Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF8B4513),
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                GestureDetector(
                                  onTap: () => ref.read(cartProvider.notifier).decrementItem(item.id),
                                  child: const Padding(
                                    padding: EdgeInsets.all(6),
                                    child: Icon(Icons.remove, size: 14, color: Colors.white),
                                  ),
                                ),
                                Text('$quantity', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                                GestureDetector(
                                  onTap: () => ref.read(cartProvider.notifier).addItem(item),
                                  child: const Padding(
                                    padding: EdgeInsets.all(6),
                                    child: Icon(Icons.add, size: 14, color: Colors.white),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
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

class _MenuRowItem extends ConsumerWidget {
  final dynamic item;
  const _MenuRowItem({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () => context.push('/customer/menu/general'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 15),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey[50]!),
        ),
        child: Row(
          children: [
            SafeImage(url: item.imageUrl, width: 65, height: 65, borderRadius: BorderRadius.circular(15)),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  Text('Classic Fukrey Choice', style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                ],
              ),
            ),
            Builder(
              builder: (context) {
                final cartItem = ref.watch(cartProvider).items.where((i) => i.menuItem.id == item.id).firstOrNull;
                final quantity = cartItem?.quantity ?? 0;

                return Row(
                  children: [
                    Text('₹${item.price}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
                    const SizedBox(width: 12),
                    if (quantity == 0)
                      GestureDetector(
                        onTap: () {
                          ref.read(cartProvider.notifier).addItem(item);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Added ${item.name} to cart'), duration: const Duration(seconds: 1)),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(color: Color(0xFFFDEFE6), shape: BoxShape.circle),
                          child: const Icon(Icons.add, size: 16, color: Color(0xFF8B4513)),
                        ),
                      )
                    else
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF8B4513),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            GestureDetector(
                              onTap: () => ref.read(cartProvider.notifier).decrementItem(item.id),
                              child: const Padding(
                                padding: EdgeInsets.all(4),
                                child: Icon(Icons.remove, size: 14, color: Colors.white),
                              ),
                            ),
                            Text('$quantity', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                            GestureDetector(
                              onTap: () => ref.read(cartProvider.notifier).addItem(item),
                              child: const Padding(
                                padding: EdgeInsets.all(4),
                                child: Icon(Icons.add, size: 14, color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class HomeShimmer extends StatelessWidget {
  const HomeShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return const SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            ShimmerLoader(width: double.infinity, height: 380, borderRadius: 40),
            SizedBox(height: 20),
            ShimmerLoader(width: double.infinity, height: 40),
            SizedBox(height: 20),
            ShimmerLoader(width: double.infinity, height: 280, borderRadius: 30),
          ],
        ),
      ),
    );
  }
}

class _CustomBottomNav extends StatelessWidget {
  final VoidCallback onHomeTap;
  final VoidCallback onSearchTap;
  final VoidCallback onCartTap;
  final VoidCallback? onProfileTap;

  const _CustomBottomNav({
    required this.onHomeTap,
    required this.onSearchTap,
    required this.onCartTap,
    this.onProfileTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Colors.grey[200]!))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _NavIcon(icon: Icons.home, isSelected: true, onTap: onHomeTap),
          _NavIcon(icon: Icons.search, isSelected: false, onTap: onSearchTap),
          _NavIcon(icon: Icons.shopping_bag, isSelected: false, onTap: onCartTap),
          _NavIcon(icon: Icons.person_outline, isSelected: false, onTap: onProfileTap ?? () {}),
        ],
      ),
    );
  }
}

class _NavIcon extends StatelessWidget {
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;
  const _NavIcon({required this.icon, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Icon(icon, color: isSelected ? const Color(0xFF8B4513) : Colors.grey[400]),
    );
  }
}
