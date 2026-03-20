import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:csv/csv.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../repositories/sales_repository.dart';
import '../../repositories/menu_repository.dart';
import '../../repositories/user_repository.dart';
import '../auth/auth_provider.dart';
import '../../core/file_utils.dart';
import 'dart:io' show File;



class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  int _selectedMenuIndex = 0;

  @override
  Widget build(BuildContext context) {
    final userProfileAsync = ref.watch(userProfileProvider);

    return userProfileAsync.when(
      data: (profile) {
        if (profile == null || (profile.role != 'admin' && profile.role != 'staff')) {
          Future.microtask(() => { if (context.mounted) context.go('/') });
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final isAdmin = profile.role == 'admin';

        if (profile.outletId != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ref.read(outletFilterProvider.notifier).setFilter(profile.outletId);
          });
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 1100;
            
            final sidebarContent = MainSidebar(
              isAdmin: isAdmin,
              selectedIndex: _selectedMenuIndex,
              onItemSelected: (index) {
                setState(() => _selectedMenuIndex = index);
                if (isMobile) {
                  Navigator.pop(context);
                }
              },
            );

            return Scaffold(
              backgroundColor: const Color(0xFFF5F6FA),
              drawer: (isMobile || !isAdmin) ? Drawer(child: sidebarContent) : null,
              body: Row(
                children: [
                  if (isAdmin && !isMobile) sidebarContent, 
                  Expanded(
                    child: Builder(
                      builder: (context) => Column(
                        children: [
                          _TopAppBar(
                            isAdmin: isAdmin, 
                            showMenuIcon: isMobile || !isAdmin,
                            onMenuPressed: () => Scaffold.of(context).openDrawer(),
                          ),
                          Expanded(
                            child: IndexedStack(
                              index: _selectedMenuIndex,
                            children: [
                              const _OverviewTab(),
                              if (isAdmin) const _OutletsTab() else const SizedBox(),
                              if (isAdmin) const _UsersTab() else const SizedBox(),
                              if (isAdmin) const _CategoriesTab() else const SizedBox(),
                              if (isAdmin) const _MenuTab() else const SizedBox(),
                            ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, st) => Scaffold(body: Center(child: Text('Error: $e'))),
    );
  }
}

class _TopAppBar extends ConsumerWidget {
  final bool isAdmin;
  final bool showMenuIcon;
  final VoidCallback onMenuPressed;
  const _TopAppBar({required this.isAdmin, required this.showMenuIcon, required this.onMenuPressed});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      height: 70,
      color: const Color(0xFF8B3E22), 
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          if (showMenuIcon) ...[
            IconButton(
              icon: const Icon(Icons.menu, color: Colors.white),
              onPressed: onMenuPressed,
            ),
            const SizedBox(width: 8),
          ],
          Text(isAdmin ? 'Admin Console' : 'Outlet Console', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const Spacer(),
          Expanded(
            flex: 3,
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 150) return const SizedBox.shrink();
                return Container(
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Icon(Icons.search, color: Colors.white.withOpacity(0.5)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Search analytics...',
                        hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
          const SizedBox(width: 20),
          IconButton(icon: const Icon(Icons.notifications, color: Colors.white), onPressed: () {}),
          IconButton(icon: const Icon(Icons.settings, color: Colors.white), onPressed: () {}),
          const SizedBox(width: 8),
          const CircleAvatar(
            backgroundColor: Color(0xFFE9A075),
            child: Icon(Icons.person, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

class MainSidebar extends ConsumerWidget {
  final bool isAdmin;
  final int selectedIndex;
  final Function(int) onItemSelected;

  const MainSidebar({required this.isAdmin, required this.selectedIndex, required this.onItemSelected});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      width: 250,
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
             padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
             child: Column(
               crossAxisAlignment: CrossAxisAlignment.start,
               children: [
                 Text(isAdmin ? 'Management' : 'Outlet Control', style: const TextStyle(color: Color(0xFF6B1F0E), fontSize: 18, fontWeight: FontWeight.w900)),
                 const SizedBox(height: 4),
                 Text(isAdmin ? 'AMBER SLATE CONTROL' : 'LOCAL HUB ACCESS', style: const TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
               ],
             ),
          ),
          const SizedBox(height: 16),
          MainSidebarNavItem(title: 'Overview', icon: Icons.dashboard, isSelected: selectedIndex == 0, onTap: () => onItemSelected(0)),
          if (isAdmin) MainSidebarNavItem(title: 'Outlets', icon: Icons.storefront, isSelected: selectedIndex == 1, onTap: () => onItemSelected(1)),
          if (isAdmin) MainSidebarNavItem(title: 'Users', icon: Icons.people_outline, isSelected: selectedIndex == 2, onTap: () => onItemSelected(2)),
          if (isAdmin) MainSidebarNavItem(title: 'Categories', icon: Icons.category_outlined, isSelected: selectedIndex == 3, onTap: () => onItemSelected(3)),
          if (isAdmin) MainSidebarNavItem(title: 'Menu', icon: Icons.restaurant_menu, isSelected: selectedIndex == 4, onTap: () => onItemSelected(4)),
          if (!isAdmin) MainSidebarNavItem(title: 'Open POS', icon: Icons.point_of_sale, isSelected: selectedIndex == -1, onTap: () => context.go('/pos')),
          const Spacer(),
          const Divider(),
          MainSidebarNavItem(title: 'Support', icon: Icons.help_outline, isSelected: false, onTap: () {}),
          MainSidebarNavItem(
            title: 'Logout', 
            icon: Icons.logout, 
            isSelected: false, 
            onTap: () => ref.read(authControllerProvider.notifier).logout(),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class MainSidebarNavItem extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const MainSidebarNavItem({required this.title, required this.icon, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: isSelected ? Colors.white : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        boxShadow: isSelected ? [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4, offset: const Offset(0, 2))] : [],
      ),
      child: ListTile(
        leading: Icon(icon, color: isSelected ? const Color(0xFF8B3E22) : Colors.grey[600]),
        title: Text(title, style: TextStyle(color: isSelected ? const Color(0xFF8B3E22) : Colors.grey[600], fontWeight: isSelected ? FontWeight.bold : FontWeight.w500)),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}



// -----------------------------------------------------------------------------
// OVERVIEW TAB
// -----------------------------------------------------------------------------

class _OverviewTab extends ConsumerWidget {
  const _OverviewTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(outletsRepoProvider);
    
    final statsAsync = ref.watch(filteredSalesProvider);
    final userProfile = ref.watch(userProfileProvider).value;
    final isOutletManager = userProfile?.outletId != null;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PerformanceHeader(isOutletManager: isOutletManager),
          const SizedBox(height: 24),
          
          statsAsync.when(
            data: (stats) => _OverviewContentGrid(stats: stats),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, st) => Text('Error: $e'),
          ),
        ],
      ),
    );
  }
}

class _OverviewContentGrid extends ConsumerWidget {
  final SalesStats stats;
  const _OverviewContentGrid({required this.stats});

  void _showAllOrders(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 600,
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('All Recent Orders', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                ],
              ),
              const SizedBox(height: 16),
              Flexible(
                child: Consumer(
                  builder: (context, ref, child) {
                    final ordersAsync = ref.watch(filteredOrdersProvider);
                    return ordersAsync.when(
                      data: (orders) => orders.isEmpty
                          ? const Center(child: Text('No orders found'))
                          : ListView.separated(
                              shrinkWrap: true,
                              itemCount: orders.length,
                              separatorBuilder: (context, index) => const SizedBox(height: 12),
                              itemBuilder: (context, index) => _OrderCard(order: orders[index]),
                            ),
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (e, st) => Text('Error: $e'),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 900;
        
        final chart = _PaymentMethodsChart(stats: stats);
        final ordersList = Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Recent Orders', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  TextButton(
                    onPressed: () => _showAllOrders(context),
                    child: const Text('View All', style: TextStyle(color: Color(0xFF8B3E22), fontWeight: FontWeight.bold)),
                  )
                ],
              ),
              const SizedBox(height: 16),
              const _RecentOrdersList(),
            ],
          ),
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _StatGrid(stats: stats),
            const SizedBox(height: 24),
            if (isNarrow) ...[
              chart,
              const SizedBox(height: 24),
              ordersList,
            ] else 
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 1, child: chart),
                  const SizedBox(width: 24),
                  Expanded(flex: 1, child: ordersList),
                ],
              ),
          ],
        );
      }
    );
  }
}

class _PaymentMethodsChart extends ConsumerWidget {
  final SalesStats stats;
  const _PaymentMethodsChart({required this.stats});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(allFilteredOrdersProvider);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Sales Amount by Payment Method', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 48),
          ordersAsync.when(
            data: (orders) {
              double upi = 0;
              double cash = 0;
              double card = 0;

              for (var o in orders) {
                final amount = (o['total_amount'] as num?)?.toDouble() ?? 0.0;
                final mode = (o['payment_method']?.toString().toLowerCase() ?? 'cash');
                if (mode.contains('upi')) {
                  upi += amount;
                } else if (mode.contains('card')) {
                  card += amount;
                } else {
                  cash += amount;
                }
              }

              final total = upi + cash + card;
              if (total == 0) return const Center(child: Text('No payment data'));

              return Column(
                children: [
                  SizedBox(
                    height: 200,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        PieChart(
                          PieChartData(
                            sectionsSpace: 0,
                            centerSpaceRadius: 70,
                            sections: [
                              PieChartSectionData(
                                color: const Color(0xFF8B3E22), // UPI - brown
                                value: upi,
                                title: '',
                                radius: 25,
                              ),
                              PieChartSectionData(
                                color: const Color(0xFF007A7C), // Cash - teal
                                value: cash,
                                title: '',
                                radius: 25,
                              ),
                              PieChartSectionData(
                                color: const Color(0xFFD47C42), // Card - orange
                                value: card,
                                title: '',
                                radius: 25,
                              ),
                            ],
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                             const Text('TOTAL', style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
                             Text('100%', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                          ],
                        )
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                  _LegendItem(color: const Color(0xFF8B3E22), label: 'UPI', amount: '₹ ${upi.toStringAsFixed(2)}'),
                  const SizedBox(height: 16),
                  _LegendItem(color: const Color(0xFF007A7C), label: 'Cash', amount: '₹ ${cash.toStringAsFixed(2)}'),
                  const SizedBox(height: 16),
                  _LegendItem(color: const Color(0xFFD47C42), label: 'Card', amount: '₹ ${card.toStringAsFixed(2)}'),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, st) => Text('Error: $e'),
          ),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final String amount;

  const _LegendItem({required this.color, required this.label, required this.amount});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 12),
        Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
        const Spacer(),
        Text(amount, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class _PerformanceHeader extends ConsumerWidget {
  final bool isOutletManager;
  const _PerformanceHeader({required this.isOutletManager});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final range = ref.watch(dateRangeProvider);
    final outletId = ref.watch(outletFilterProvider);
    final paymentMethod = ref.watch(paymentMethodFilterProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Performance Overview', 
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF1E1E1E))
        ),
        const SizedBox(height: 4),
        const Text('Real-time business insights across all channels.', style: TextStyle(color: Colors.grey, fontSize: 16)),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
          ),
          child: Wrap(
            spacing: 24,
            runSpacing: 16,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (!isOutletManager)
                _ModernFilterDropdown(
                  icon: Icons.store,
                  label: 'Outlet:',
                  value: outletId == null ? 'All' : 'Specific',
                  onTap: () => _showOutletPicker(context, ref),
                ),
              _ModernFilterDropdown(
                icon: Icons.calendar_today,
                label: 'Date:',
                value: '${DateFormat('dd MMM').format(range.start)} - ${DateFormat('dd MMM').format(range.end)}',
                onTap: () async {
                  final picked = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(2023),
                    lastDate: DateTime.now().add(const Duration(days: 1)),
                    initialDateRange: range,
                  );
                  if (picked != null) {
                    ref.read(dateRangeProvider.notifier).setRange(DateTimeRange(
                      start: picked.start,
                      end: DateTime(picked.end.year, picked.end.month, picked.end.day, 23, 59, 59),
                    ));
                  }
                },
              ),
              _ModernFilterDropdown(
                icon: Icons.payment,
                label: 'Payment Method',
                value: paymentMethod == null ? 'All' : paymentMethod.toUpperCase(),
                onTap: () => _showPaymentPicker(context, ref),
              ),
              ElevatedButton.icon(
                onPressed: () => _exportToCSV(context, ref),
                icon: const Icon(Icons.download, size: 16, color: Colors.black87),
                label: const Text('Export CSV', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEEEEEE),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showOutletPicker(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Consumer(
        builder: (context, ref, child) {
          final outletsAsync = ref.watch(outletsRepoProvider);
          return Container(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.6, minHeight: 200),
            child: outletsAsync.when(
              data: (outlets) => ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 20),
                children: [
                   const ListTile(title: Text('Select Outlet', style: TextStyle(fontWeight: FontWeight.bold))),
                   ListTile(
                     title: const Text('All Outlets'),
                     onTap: () { ref.read(outletFilterProvider.notifier).setFilter(null); Navigator.pop(context); },
                   ),
                   ...outlets.map((o) => ListTile(
                     title: Text(o['name']),
                     onTap: () { ref.read(outletFilterProvider.notifier).setFilter(o['id']); Navigator.pop(context); },
                   )),
                ],
              ),
              loading: () => const SizedBox(
                height: 200, 
                child: Center(child: CircularProgressIndicator(color: Colors.orange))
              ),
              error: (e, st) => Center(child: Padding(padding: EdgeInsets.all(20), child: Text('Error: $e'))),
            ),
          );
        },
      ),
    );
  }

  void _showPaymentPicker(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 20),
        children: [
          const ListTile(title: Text('Select Payment Mode', style: TextStyle(fontWeight: FontWeight.bold))),
          ListTile(
            title: const Text('All Payments'),
            onTap: () { ref.read(paymentMethodFilterProvider.notifier).setFilter(null); Navigator.pop(context); },
          ),
          ...['Cash', 'Card', 'UPI'].map((m) => ListTile(
            title: Text(m),
            onTap: () { ref.read(paymentMethodFilterProvider.notifier).setFilter(m); Navigator.pop(context); },
          )),
        ],
      ),
    );
  }

  Future<void> _exportToCSV(BuildContext context, WidgetRef ref) async {
    try {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Generating CSV...')));
      final orders = await ref.read(allFilteredOrdersProvider.future);
      if (orders.isEmpty) {
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No orders to export')));
        return;
      }
      final List<List<dynamic>> rows = [
        ['Order ID','Date','Time','Customer','Payment Mode','Items','Total Amount','Status']
      ];
      for (var order in orders) {
        final time = DateTime.parse(order['created_at']).toLocal();
        final itemsList = order['order_items'] as List? ?? [];
        final itemsString = itemsList.map((i) => "${i['menu_items']?['name'] ?? 'Item'} (x${i['quantity']})").join(", ");
        rows.add([
          order['id'].toString().substring(0, 8),
          DateFormat('dd/MM/yyyy').format(time),
          DateFormat('HH:mm').format(time),
          order['customer_name'] ?? 'Guest',
          order['payment_method']?.toString().toUpperCase() ?? 'CASH',
          itemsString,
          order['total_amount'],
          order['status']
        ]);
      }
      final csvData = const ListToCsvConverter().convert(rows);
      final fileName = "orders_export_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.csv";
      await saveAndShareFile(csvData, fileName);
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Exported: $fileName')));
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }
  }
}

class _ModernFilterDropdown extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  const _ModernFilterDropdown({required this.icon, required this.label, required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: const Color(0xFF8B3E22)),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
            if (value.isNotEmpty) ...[
              const SizedBox(width: 4),
              Flexible(child: Text(value, style: const TextStyle(color: Color(0xFF8B3E22), fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
            ],
            const SizedBox(width: 4),
            const Icon(Icons.keyboard_arrow_down, size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}

class _StatGrid extends StatelessWidget {
  final SalesStats stats;
  const _StatGrid({required this.stats});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 800;
        
        if (isNarrow) {
          return Column(
            children: [
              _StatCard(
                title: 'Total Revenue', 
                value: '₹ ${stats.totalRevenue.toStringAsFixed(2)}', 
                icon: Icons.currency_rupee, 
                change: '${stats.revenueChange >= 0 ? '+' : ''}${stats.revenueChange.toStringAsFixed(1)}%', 
                isPositive: stats.revenueChange >= 0
              ),
              const SizedBox(height: 16),
              _StatCard(
                title: 'Total Orders', 
                value: stats.totalOrders.toString(), 
                icon: Icons.shopping_bag, 
                change: '${stats.ordersChange >= 0 ? '+' : ''}${stats.ordersChange.toStringAsFixed(1)}%', 
                isPositive: stats.ordersChange >= 0
              ),
              const SizedBox(height: 16),
              _StatCard(
                title: 'Avg. Order', 
                value: '₹ ${stats.averageOrderValue.toStringAsFixed(2)}', 
                icon: Icons.trending_up, 
                change: '${stats.avgOrderChange >= 0 ? '+' : ''}${stats.avgOrderChange.toStringAsFixed(1)}%', 
                isPositive: stats.avgOrderChange >= 0
              ),
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: _StatCard(
              title: 'Total Revenue', 
              value: '₹ ${stats.totalRevenue.toStringAsFixed(1)}', 
              icon: Icons.currency_rupee, 
              change: '${stats.revenueChange >= 0 ? '+' : ''}${stats.revenueChange.toStringAsFixed(1)}%', 
              isPositive: stats.revenueChange >= 0
            )),
            const SizedBox(width: 24),
            Expanded(child: _StatCard(
              title: 'Total Orders', 
              value: stats.totalOrders.toString(), 
              icon: Icons.shopping_bag, 
              change: '${stats.ordersChange >= 0 ? '+' : ''}${stats.ordersChange.toStringAsFixed(1)}%', 
              isPositive: stats.ordersChange >= 0
            )),
            const SizedBox(width: 24),
            Expanded(child: _StatCard(
              title: 'Avg. Order', 
              value: '₹ ${stats.averageOrderValue.toStringAsFixed(1)}', 
              icon: Icons.trending_up, 
              change: '${stats.avgOrderChange >= 0 ? '+' : ''}${stats.avgOrderChange.toStringAsFixed(1)}%', 
              isPositive: stats.avgOrderChange >= 0
            )),
          ],
        );
      }
    );
  }
}

class _RecentOrdersList extends ConsumerWidget {
  const _RecentOrdersList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(filteredOrdersProvider);

    return ordersAsync.when(
      data: (orders) => orders.isEmpty
          ? const Center(child: Padding(padding: EdgeInsets.all(32), child: Text('No orders found')))
          : ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: orders.length > 5 ? 5 : orders.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) => _OrderCard(order: orders[index]),
            ),
      loading: () => const SizedBox(height: 200, child: Center(child: CircularProgressIndicator())),
      error: (e, st) => Text('Error: $e'),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final Map<String, dynamic> order;
  const _OrderCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final total = order['total_amount'] ?? 0;
    final time = DateTime.parse(order['created_at']).toLocal();
    final paymentMethod = order['payment_method']?.toString() ?? 'Cash';
    
    final diff = DateTime.now().difference(time);
    String timeAgo;
    if (diff.inMinutes < 60) {
      timeAgo = '${diff.inMinutes} mins ago';
    } else if (diff.inHours < 24) {
      timeAgo = '${diff.inHours} hour${diff.inHours > 1 ? 's' : ''} ago';
    } else {
      timeAgo = DateFormat('dd MMM').format(time);
    }

    // Usually there's a status. For UI we just say SUCCESS or PENDING.
    final status = order['status']?.toString().toUpperCase() ?? 'SUCCESS';
    final isSuccess = status == 'SUCCESS' || status == 'COMPLETED';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.receipt_long, color: Color(0xFF8B3E22), size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('#${order['id'].toString().substring(0, 8)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    if ((order['customer_name']?.toString().isNotEmpty ?? false) || (order['customer_phone']?.toString().isNotEmpty ?? false)) ...[
                       const SizedBox(height: 2),
                       Text('${order['customer_name'] ?? 'Guest'} ${order['customer_phone'] != null ? '• ${order['customer_phone']}' : ''}', 
                         style: TextStyle(color: Colors.grey[800], fontSize: 13, fontWeight: FontWeight.w600)),
                    ],
                    const SizedBox(height: 4),
                    Text('${DateFormat('dd MMM yyyy, hh:mm a').format(time)} • $paymentMethod Payment', style: const TextStyle(color: Colors.grey, fontSize: 10)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('₹ $total', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isSuccess ? const Color(0xFFE0F2F1) : const Color(0xFFFBE9E7),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      isSuccess ? 'SUCCESS' : status,
                      style: TextStyle(
                        color: isSuccess ? const Color(0xFF00796B) : const Color(0xFFD84315),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const Divider(height: 24),
          ...?((order['order_items'] as List?)?.map((item) {
            final menuName = item['menu_items']?['name'] ?? 'Item';
            final qty = item['quantity'] ?? 1;
            return Padding(
              padding: const EdgeInsets.only(bottom: 4.0),
              child: Row(
                children: [
                  const Icon(Icons.circle, size: 6, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text('$menuName', style: const TextStyle(fontSize: 13, color: Colors.black87)),
                  const Spacer(),
                  Text('x$qty', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black54)),
                ],
              ),
            );
          })),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final String change;
  final bool isPositive;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.change,
    required this.isPositive,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                  color: Color(0xFFFFF7ED),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: const Color(0xFF8B3E22), size: 22),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isPositive ? const Color(0xFFE0F7FA) : const Color(0xFFFFEBEE),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  change,
                  style: TextStyle(
                    color: isPositive ? const Color(0xFF00838F) : const Color(0xFFC62828),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(title, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF1E1E1E))),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// OUTLETS TAB
// -----------------------------------------------------------------------------
class _OutletsTab extends ConsumerStatefulWidget {
  const _OutletsTab();

  @override
  ConsumerState<_OutletsTab> createState() => _OutletsTabState();
}

class _OutletsTabState extends ConsumerState<_OutletsTab> {
  final _supabase = Supabase.instance.client;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddOutletDialog(context),
        child: const Icon(Icons.add),
      ),
      body: FutureBuilder(
        future: _supabase.from('outlets').select(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final outlets = snapshot.data as List<dynamic>? ?? [];
          if (outlets.isEmpty) {
            return const Center(child: Text('No outlets found. Add one!'));
          }

          return ListView.builder(
            itemCount: outlets.length,
            itemBuilder: (context, index) {
              final outlet = outlets[index];
              return ListTile(
                leading: const CircleAvatar(child: Icon(Icons.store)),
                title: Text(outlet['name']),
                subtitle: Text(outlet['address'] ?? 'No address'),
                trailing: IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () => _showAddOutletDialog(context, outlet: outlet),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showAddOutletDialog(BuildContext context, {Map<String, dynamic>? outlet}) {
    final nameController = TextEditingController(text: outlet?['name'] ?? '');
    final addressController = TextEditingController(text: outlet?['address'] ?? '');
    final brandNameController = TextEditingController(text: outlet?['brand_name'] ?? '');
    final fssaiController = TextEditingController(text: outlet?['fssai_number'] ?? '');
    final gstController = TextEditingController(text: outlet?['gst_number'] ?? '');
    final upiController = TextEditingController(text: outlet?['upi_id'] ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(outlet == null ? 'Add Outlet' : 'Edit Outlet'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Outlet Name (Internal)')),
              TextField(controller: addressController, decoration: const InputDecoration(labelText: 'Address')),
              TextField(controller: brandNameController, decoration: const InputDecoration(labelText: 'Brand Name (Printed)')),
              TextField(controller: fssaiController, decoration: const InputDecoration(labelText: 'FSSAI Number')),
              TextField(controller: gstController, decoration: const InputDecoration(labelText: 'GST Number')),
              TextField(controller: upiController, decoration: const InputDecoration(labelText: 'UPI ID (e.g., user@upi)')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              try {
                final data = {
                  'name': nameController.text,
                  'address': addressController.text,
                  'brand_name': brandNameController.text.isEmpty ? null : brandNameController.text,
                  'fssai_number': fssaiController.text.isEmpty ? null : fssaiController.text,
                  'gst_number': gstController.text.isEmpty ? null : gstController.text,
                  'upi_id': upiController.text.isEmpty ? null : upiController.text,
                };
                if (outlet == null) {
                  await _supabase.from('outlets').insert(data);
                } else {
                  await _supabase.from('outlets').update(data).eq('id', outlet['id']);
                }
                
                if (context.mounted) {
                  Navigator.pop(context);
                  // Refresh the provider so the POS screen gets the new data
                  ref.invalidate(outletsRepoProvider); 
                  setState(() {}); // Refresh list in admin UI
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// MENU TAB
// -----------------------------------------------------------------------------
class _MenuTab extends ConsumerStatefulWidget {
  const _MenuTab();

  @override
  ConsumerState<_MenuTab> createState() => _MenuTabState();
}

class _MenuTabState extends ConsumerState<_MenuTab> {
  final _supabase = Supabase.instance.client;
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedCategoryId; // null = All
  List<dynamic> _categories = [];

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final data = await _supabase.from('categories').select().order('name');
    if (mounted) setState(() => _categories = data as List<dynamic>);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddMenuDialog(context),
        child: const Icon(Icons.add),
      ),
      body: FutureBuilder(
        future: _supabase.from('menu_items').select(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final allItems = snapshot.data as List<dynamic>? ?? [];
          if (allItems.isEmpty) {
            return const Center(child: Text('No menu items. Add one!'));
          }

          // Filter items by search and category
          final items = allItems.where((item) {
            final name = (item['name'] as String? ?? '').toLowerCase();
            final matchesSearch = _searchQuery.isEmpty || name.contains(_searchQuery.toLowerCase());
            final matchesCategory = _selectedCategoryId == null || item['category_id'] == _selectedCategoryId;
            return matchesSearch && matchesCategory;
          }).toList();

          return Column(
            children: [
              // Search bar
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search menu items...',
                    prefixIcon: const Icon(Icons.search, color: Colors.orange),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.grey[100],
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val),
                ),
              ),
              // Category filter chips
              if (_categories.isNotEmpty)
                SizedBox(
                  height: 44,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    children: [
                      _CategoryFilterChip(
                        label: 'All',
                        isSelected: _selectedCategoryId == null,
                        onTap: () => setState(() => _selectedCategoryId = null),
                      ),
                      ..._categories.map((cat) => _CategoryFilterChip(
                        label: cat['name'],
                        isSelected: _selectedCategoryId == cat['id'],
                        onTap: () => setState(() => _selectedCategoryId = cat['id']),
                      )),
                    ],
                  ),
                ),
              const Divider(height: 1),
              // Results
              if (items.isEmpty)
                const Expanded(child: Center(child: Text('No items match your filters.')))
              else
                Expanded(
                  child: ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final isAvailable = item['is_available'] ?? true;
                      // Find category name
                      final catName = _categories
                          .cast<Map<String, dynamic>?>()
                          .firstWhere((c) => c?['id'] == item['category_id'], orElse: () => null)?['name'] ?? '';

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isAvailable ? Colors.orange : Colors.grey,
                          child: const Icon(Icons.fastfood, color: Colors.white),
                        ),
                        title: Text(item['name']),
                        subtitle: Text('₹${item['price']}${catName.isNotEmpty ? ' | $catName' : ''} | ${isAvailable ? "Available" : "Hidden"}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Switch(
                              value: isAvailable,
                              onChanged: (val) => _toggleAvailability(item['id'], val),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () => _showAddMenuDialog(context, item: item),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _confirmDeleteItem(item['id']),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  void _showAddMenuDialog(BuildContext context, {Map<String, dynamic>? item}) {
    final nameController = TextEditingController(text: item?['name'] ?? '');
    final priceController = TextEditingController(text: item?['price']?.toString() ?? '');
    String? selectedCategoryId = item?['category_id'];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(item == null ? 'Add Menu Item' : 'Edit Menu Item'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Item Name')),
                TextField(controller: priceController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Price')),
                const SizedBox(height: 16),
                
                // Category Dropdown
                FutureBuilder(
                  future: _supabase.from('categories').select(),
                  builder: (context, snapshot) {
                    final categories = snapshot.data as List<dynamic>? ?? [];
                    return DropdownButtonFormField<String>(
                      value: selectedCategoryId,
                      decoration: const InputDecoration(labelText: 'Category'),
                      items: categories.map((c) => DropdownMenuItem<String>(
                        value: c['id'],
                        child: Text(c['name']),
                      )).toList(),
                      onChanged: (val) => setDialogState(() => selectedCategoryId = val),
                    );
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                try {
                  final data = {
                    'name': nameController.text,
                    'price': double.tryParse(priceController.text) ?? 0.0,
                    'category_id': selectedCategoryId,
                  };
                  
                  if (item == null) {
                    await _supabase.from('menu_items').insert(data);
                  } else {
                    await _supabase.from('menu_items').update(data).eq('id', item['id']);
                  }
                  
                  if (context.mounted) {
                    Navigator.pop(context);
                    setState(() {}); // Refresh list
                    // Invalidate menu items provider to refresh POS
                    ref.invalidate(menuItemsProvider);
                  }
                } catch (e) {
                  if (context.mounted) {
                     ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleAvailability(String id, bool available) async {
    try {
      await _supabase.from('menu_items').update({'is_available': available}).eq('id', id);
      setState(() {});
      ref.invalidate(menuItemsProvider);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _confirmDeleteItem(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Item?'),
        content: const Text('Are you sure you want to delete this menu item?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _supabase.from('menu_items').delete().eq('id', id);
        setState(() {});
        ref.invalidate(menuItemsProvider);
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }
}

// -----------------------------------------------------------------------------
// CATEGORIES TAB
// -----------------------------------------------------------------------------
class _CategoriesTab extends StatefulWidget {
  const _CategoriesTab();

  @override
  State<_CategoriesTab> createState() => _CategoriesTabState();
}

class _CategoriesTabState extends State<_CategoriesTab> {
  final _supabase = Supabase.instance.client;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCategoryDialog(context),
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder(
        stream: _supabase.from('categories').stream(primaryKey: ['id']),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final categories = snapshot.data ?? [];
          if (categories.isEmpty) {
            return const Center(child: Text('No categories found.'));
          }

          return ListView.builder(
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final cat = categories[index];
              return ListTile(
                leading: const Icon(Icons.label),
                title: Text(cat['name']),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () => _showCategoryDialog(context, category: cat),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _confirmDelete(cat['id']),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showCategoryDialog(BuildContext context, {Map<String, dynamic>? category}) {
    final nameController = TextEditingController(text: category?['name'] ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(category == null ? 'Add Category' : 'Edit Category'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(labelText: 'Category Name'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isEmpty) return;
              try {
                if (category == null) {
                  await _supabase.from('categories').insert({'name': nameController.text});
                } else {
                  await _supabase.from('categories').update({'name': nameController.text}).eq('id', category['id']);
                }
                if (mounted) Navigator.pop(context);
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Category?'),
        content: const Text('Are you sure? Items in this category might be affected.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _supabase.from('categories').delete().eq('id', id);
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }
}

// -----------------------------------------------------------------------------
// USERS TAB
// -----------------------------------------------------------------------------
class _UsersTab extends ConsumerWidget {
  const _UsersTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(allUsersProvider);
    final outletsAsync = ref.watch(outletsRepoProvider);

    return Scaffold(
      body: usersAsync.when(
        data: (users) => ListView.builder(
          itemCount: users.length,
          itemBuilder: (context, index) {
            final user = users[index];
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: user.role == 'admin' ? Colors.red : Colors.orange,
                child: Icon(
                  user.role == 'admin' ? Icons.admin_panel_settings : Icons.person,
                  color: Colors.white,
                ),
              ),
              title: Text(user.email),
              subtitle: Text('Role: ${user.role.toUpperCase()}'),
              trailing: IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () => _showEditUserDialog(context, ref, user, outletsAsync),
              ),
            );
          },
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error: $e')),
      ),
    );
  }

  void _showEditUserDialog(
    BuildContext context, 
    WidgetRef ref, 
    UserModel user, 
    AsyncValue<List<Map<String, dynamic>>> outletsAsync
  ) {
    String selectedRole = user.role;
    String? selectedOutletId = user.outletId;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Edit User: ${user.email}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: selectedRole,
                decoration: const InputDecoration(labelText: 'Role'),
                items: const [
                  DropdownMenuItem(value: 'admin', child: Text('Admin')),
                  DropdownMenuItem(value: 'staff', child: Text('Staff')),
                ],
                onChanged: (val) => setDialogState(() => selectedRole = val!),
              ),
              const SizedBox(height: 16),
              outletsAsync.when(
                data: (outlets) => DropdownButtonFormField<String>(
                  value: selectedOutletId,
                  decoration: const InputDecoration(labelText: 'Assign Outlet'),
                  hint: const Text('None'),
                  items: [
                    const DropdownMenuItem<String>(value: null, child: Text('No Outlet')),
                    ...outlets.map((o) => DropdownMenuItem<String>(
                      value: o['id'],
                      child: Text(o['name']),
                    )),
                  ],
                  onChanged: (val) => setDialogState(() => selectedOutletId = val),
                ),
                loading: () => const CircularProgressIndicator(),
                error: (e, st) => Text('Error loading outlets: $e'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                try {
                  await ref.read(userRepositoryProvider).updateUser(
                    user.id,
                    role: selectedRole,
                    outletId: selectedOutletId,
                  );
                  ref.invalidate(allUsersProvider);
                  if (context.mounted) Navigator.pop(context);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Helper widget: Category filter chip for Admin Menu Tab
// ---------------------------------------------------------------------------
class _CategoryFilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryFilterChip({required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? Colors.orange : Colors.grey[200],
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.black87,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}
