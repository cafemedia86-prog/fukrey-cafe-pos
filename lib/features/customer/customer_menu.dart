import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../repositories/menu_repository.dart';
import '../../repositories/user_repository.dart';
import '../pos/cart_provider.dart';
import '../../core/widgets/safe_image.dart';
import '../../core/widgets/shimmer_loader.dart';

class CustomerMenuScreen extends ConsumerStatefulWidget {
  final String outletId;
  final String? initialCategoryId;
  final String? searchQuery;
  const CustomerMenuScreen({super.key, required this.outletId, this.initialCategoryId, this.searchQuery});

  @override
  ConsumerState<CustomerMenuScreen> createState() => _CustomerMenuScreenState();
}

class _CustomerMenuScreenState extends ConsumerState<CustomerMenuScreen> {
  String? _selectedCategoryId;
  late final TextEditingController _searchController;
  String _currentSearchQuery = '';

  @override
  void initState() {
    super.initState();
    _selectedCategoryId = widget.initialCategoryId;
    _currentSearchQuery = widget.searchQuery ?? '';
    _searchController = TextEditingController(text: _currentSearchQuery);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final menuAsync = ref.watch(menuItemsProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final cartState = ref.watch(cartProvider);
    
    return Scaffold(
      backgroundColor: const Color(0xFFFDFCFB),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black, size: 20),
          onPressed: () => context.pop(),
        ),
        title: const Text('Menu', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 24)),
        centerTitle: false,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(15),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (val) => setState(() => _currentSearchQuery = val),
                decoration: const InputDecoration(
                  hintText: 'Search menu...',
                  border: InputBorder.none,
                  icon: Icon(Icons.search, size: 20),
                ),
              ),
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // Categories
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 15),
                child: categoriesAsync.when(
                  data: (categories) {
                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: [
                          // "All" Category
                          _buildCategoryChip(
                            label: 'All',
                            isSelected: _selectedCategoryId == null,
                            onTap: () => setState(() => _selectedCategoryId = null),
                          ),
                          ...categories.map((cat) => _buildCategoryChip(
                            label: cat['name'] ?? 'Category',
                            isSelected: _selectedCategoryId == cat['id'],
                            onTap: () => setState(() => _selectedCategoryId = cat['id']),
                          )).toList(),
                        ],
                      ),
                    );
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
              ),
              
              Expanded(
                child: menuAsync.when(
                  data: (items) {
                    final categoryFiltered = _selectedCategoryId == null 
                        ? items 
                        : items.where((i) => i.categoryId == _selectedCategoryId).toList();
                    
                    final filteredItems = _currentSearchQuery.isEmpty
                        ? categoryFiltered
                        : categoryFiltered.where((i) => 
                            i.name.toLowerCase().contains(_currentSearchQuery.toLowerCase()) ||
                            (i.description?.toLowerCase().contains(_currentSearchQuery.toLowerCase()) ?? false)
                          ).toList();

                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 100),
                      physics: const BouncingScrollPhysics(),
                      itemCount: filteredItems.length,
                      itemBuilder: (context, index) => _PremiumMenuItem(item: filteredItems[index]),
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, st) => Center(child: Text('Error: $e')),
                ),
              ),
            ],
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
                        BoxShadow(color: const Color(0xFF8B4513).withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.shopping_bag, color: Colors.white, size: 20),
                            const SizedBox(width: 12),
                            Text('${cartState.items.length} items', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        Row(
                          children: [
                            Text('₹${cartState.total.toStringAsFixed(0)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
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
    );
  }

  Widget _buildCategoryChip({required String label, required bool isSelected, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF8B4513) : Colors.white,
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            if (isSelected)
              BoxShadow(color: const Color(0xFF8B4513).withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 5))
            else
              BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 5, offset: const Offset(0, 2))
          ],
          border: Border.all(color: isSelected ? Colors.transparent : Colors.grey[200]!),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : Colors.black87,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _PremiumMenuItem extends ConsumerWidget {
  final dynamic item;
  const _PremiumMenuItem({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartState = ref.watch(cartProvider);
    final cartItem = cartState.items.where((i) => i.menuItem.id == item.id).firstOrNull;
    final quantity = cartItem?.quantity ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 8)),
        ],
      ),
      child: Row(
        children: [
          Hero(
            tag: 'item-${item.id}-img',
            child: SafeImage(
              url: item.imageUrl,
              width: 90, height: 90,
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(item.description ?? 'Classic Fukrey signature.', 
                    style: TextStyle(color: Colors.grey[500], fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 10),
                Text('₹${item.price}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF8B4513))),
              ],
            ),
          ),
          if (quantity == 0)
            GestureDetector(
              onTap: () => ref.read(cartProvider.notifier).addItem(item),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFDEFE6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text('ADD', style: TextStyle(color: Color(0xFF8B4513), fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            )
          else
            Container(
              height: 35,
              decoration: BoxDecoration(
                color: const Color(0xFF8B4513),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  IconButton(
                    iconSize: 14,
                    icon: const Icon(Icons.remove, color: Colors.white),
                    onPressed: () => ref.read(cartProvider.notifier).decrementItem(item.id),
                  ),
                  Text('$quantity', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                  IconButton(
                    iconSize: 14,
                    icon: const Icon(Icons.add, color: Colors.white),
                    onPressed: () => ref.read(cartProvider.notifier).addItem(item),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
