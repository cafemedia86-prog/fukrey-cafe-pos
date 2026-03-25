import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../repositories/sales_repository.dart';

// Shared player for alerts
final alertPlayerProvider = Provider<AudioPlayer>((ref) => AudioPlayer());

// Uses the global realtime trigger to refetch whenever orders change
final takeawayOrdersProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final outletId = ref.watch(outletFilterProvider);
  // Re-run this future whenever the realtime trigger emits a new value
  ref.watch(ordersRealtimeTriggerProvider);

  try {
    var query = Supabase.instance.client
        .from('orders')
        .select('id, status, total_amount, customer_name, customer_phone, created_at, accepted_at, ready_at, outlet_id, coupon_code, discount_amount, order_items(quantity, price, menu_items(name))')
        .or('status.eq.pending,status.eq.preparing,status.eq.ready')
        .order('created_at', ascending: true);

    final response = await query;
    var orders = List<Map<String, dynamic>>.from(response);
    if (outletId != null) {
      orders = orders.where((o) => o['outlet_id'] == outletId).toList();
    }
    return orders;
  } catch (e) {
    debugPrint("DEBUG: Error fetching takeaway orders: $e");
    throw e;
  }
});

class TakeawayOrdersScreen extends ConsumerWidget {
  const TakeawayOrdersScreen({super.key});

  Future<void> _updateStatus(BuildContext context, WidgetRef ref, String orderId, String newStatus) async {
    try {
      final updates = <String, dynamic>{'status': newStatus};
      if (newStatus == 'preparing') {
        updates['accepted_at'] = DateTime.now().toUtc().toIso8601String();
      } else if (newStatus == 'ready') {
        updates['ready_at'] = DateTime.now().toUtc().toIso8601String();
        // Stop any alerts
        ref.read(alertPlayerProvider).stop();
      }

      await Supabase.instance.client
          .from('orders')
          .update(updates)
          .eq('id', orderId);
      
      if (context.mounted) {
        String msg = 'Status updated to ${newStatus.toUpperCase()}';
        if (newStatus == 'completed') msg = 'Order Handed Over Successfully';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Update failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(takeawayOrdersProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFFDF5E6),
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.delivery_dining, color: Colors.white),
            const SizedBox(width: 8),
            const Text('Incoming Orders', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            ordersAsync.when(
              data: (orders) => orders.isEmpty
                  ? const SizedBox.shrink()
                  : Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(12)),
                      child: Text('${orders.length}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.volume_up, color: Colors.white),
            tooltip: 'Test Sound & Enable Audio',
            onPressed: () async {
              final player = ref.read(alertPlayerProvider);
              debugPrint("DEBUG: Attempting to play test alert sound.");
              await player.play(UrlSource('https://www.soundjay.com/buttons/beep-07.mp3'));
              debugPrint("DEBUG: Test alert sound played.");
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Testing Alert Sound...')),
                );
              }
            },
          ),
        ],
        backgroundColor: const Color(0xFF8B4513),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ordersAsync.when(
        data: (orders) {
          if (orders.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline, size: 64, color: Colors.green),
                  SizedBox(height: 16),
                  Text('No active takeaway orders', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey)),
                  SizedBox(height: 8),
                  Text('New orders will appear here automatically', style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final order = orders[index];
              return _OrderCard(order: order, onUpdate: _updateStatus);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error loading orders: $e')),
      ),
    );
  }
}

class _OrderCard extends ConsumerStatefulWidget {
  final Map<String, dynamic> order;
  final Function(BuildContext, WidgetRef, String, String) onUpdate;

  const _OrderCard({required this.order, required this.onUpdate});

  @override
  ConsumerState<_OrderCard> createState() => _OrderCardState();
}

class _OrderCardState extends ConsumerState<_OrderCard> {
  bool _isNearDeadline = false;
  Timer? _alertTimer;

  @override
  void dispose() {
    _alertTimer?.cancel();
    super.dispose();
  }

  void _onTimerUpdate(bool nearDeadline) {
    if (nearDeadline != _isNearDeadline) {
      setState(() => _isNearDeadline = nearDeadline);
      if (nearDeadline) {
        _playAlertSound();
      }
    }
  }

  Future<void> _playAlertSound() async {
    final player = ref.read(alertPlayerProvider);
    // Use a public beep sound link
    await player.play(UrlSource('https://www.soundjay.com/buttons/beep-07.mp3'));
    player.setReleaseMode(ReleaseMode.loop);
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final status = order['status'] ?? 'pending';
    final orderId = order['id'];
    final shortId = orderId.toString().substring(0, 8).toUpperCase();
    final createdAt = DateTime.tryParse(order['created_at'] ?? '')?.toLocal();
    final acceptedAt = order['accepted_at'] != null ? DateTime.tryParse(order['accepted_at'])?.toLocal() : null;
    final orderItems = (order['order_items'] as List?) ?? [];

    Color cardColor = Colors.white;
    if (status == 'preparing' && _isNearDeadline) {
      cardColor = Colors.red[50]!;
    } else if (status == 'ready') {
      cardColor = Colors.green[50]!;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 4,
      color: cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: status == 'preparing' && _isNearDeadline 
            ? BorderSide(color: Colors.red[400]!, width: 2) 
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Order #$shortId', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    if (createdAt != null)
                      Text('Ordered at: ${createdAt.hour}:${createdAt.minute.toString().padLeft(2, '0')}', 
                        style: const TextStyle(color: Colors.grey, fontSize: 13)),
                  ],
                ),
                _StatusBadge(status: status),
              ],
            ),
            const Divider(height: 32),
            
            if (status == 'preparing' && acceptedAt != null) ...[
              _OrderTimerDisplay(acceptedAt: acceptedAt, onDeadline: _onTimerUpdate),
              const SizedBox(height: 16),
            ],

            if (order['customer_name'] != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    const Icon(Icons.person, size: 18, color: Color(0xFF8B4513)),
                    const SizedBox(width: 8),
                    Text(order['customer_name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
              ),

            // Items List
            ...orderItems.map((item) {
              final name = item['menu_items']?['name'] ?? 'Unknown Item';
              final qty = item['quantity'] ?? 1;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(4)),
                      child: Text('x$qty', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text(name, style: const TextStyle(fontSize: 15))),
                  ],
                ),
              );
            }),

            const Divider(height: 32),
            
            // Action Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Total: ₹${order['total_amount']}', 
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF8B4513))),
                _ActionButtons(
                  status: status, 
                  onUpdate: (newStatus) => widget.onUpdate(context, ref, orderId, newStatus),
                ),
              ],
            ),
            if ((order['discount_amount'] ?? 0) > 0) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: Colors.green[50], borderRadius: BorderRadius.circular(8)),
                    child: Text(
                      'Coupon: ${order['coupon_code'] ?? 'Discount'} Applied (-₹${order['discount_amount'].toStringAsFixed(0)})',
                      style: TextStyle(color: Colors.green[700], fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    String text;
    IconData icon;

    switch (status) {
      case 'preparing': color = Colors.orange; text = 'PREPARING'; icon = Icons.outdoor_grill; break;
      case 'ready': color = Colors.green; text = 'READY'; icon = Icons.check_circle; break;
      default: color = Colors.blue; text = 'NEW'; icon = Icons.notification_important;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withOpacity(0.3))),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(text, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
        ],
      ),
    );
  }
}

class _ActionButtons extends StatelessWidget {
  final String status;
  final Function(String) onUpdate;
  const _ActionButtons({required this.status, required this.onUpdate});

  @override
  Widget build(BuildContext context) {
    if (status == 'pending') {
      return Row(
        children: [
          TextButton(onPressed: () => onUpdate('cancelled'), child: const Text('REJECT', style: TextStyle(color: Colors.red))),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () => onUpdate('preparing'),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8B4513), foregroundColor: Colors.white),
            child: const Text('ACCEPT'),
          ),
        ],
      );
    } else if (status == 'preparing') {
      return ElevatedButton.icon(
        onPressed: () => onUpdate('ready'),
        icon: const Icon(Icons.check),
        label: const Text('MARK AS READY'),
        style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
      );
    } else if (status == 'ready') {
      return ElevatedButton.icon(
        onPressed: () => onUpdate('completed'),
        icon: const Icon(Icons.handshake),
        label: const Text('HANDOVER'),
        style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
      );
    }
    return const SizedBox.shrink();
  }
}

class _OrderTimerDisplay extends StatefulWidget {
  final DateTime acceptedAt;
  final Function(bool) onDeadline;
  const _OrderTimerDisplay({required this.acceptedAt, required this.onDeadline});

  @override
  State<_OrderTimerDisplay> createState() => _OrderTimerDisplayState();
}

class _OrderTimerDisplayState extends State<_OrderTimerDisplay> {
  late Timer _timer;
  late Duration _remaining;

  @override
  void initState() {
    super.initState();
    _calculateRemaining();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _calculateRemaining());
  }

  void _calculateRemaining() {
    final deadline = widget.acceptedAt.add(const Duration(minutes: 10));
    setState(() {
      _remaining = deadline.difference(DateTime.now());
      if (_remaining.inSeconds <= 30 && _remaining.inSeconds > 0) {
        widget.onDeadline(true);
      } else {
        widget.onDeadline(false);
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isNegative = _remaining.isNegative;
    final absRemaining = _remaining.abs();
    final minutes = absRemaining.inMinutes.toString().padLeft(2, '0');
    final seconds = (absRemaining.inSeconds % 60).toString().padLeft(2, '0');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isNegative ? Colors.red[100] : (_remaining.inSeconds < 60 ? Colors.orange[50] : Colors.green[50]),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(isNegative ? Icons.warning : Icons.timer, color: isNegative ? Colors.red : Colors.green),
          const SizedBox(width: 12),
          Text(
            isNegative ? "OVERDUE by $minutes:$seconds" : "Time to prepare: $minutes:$seconds",
            style: TextStyle(
              fontSize: 18, 
              fontWeight: FontWeight.bold, 
              color: isNegative ? Colors.red : Colors.green[800],
            ),
          ),
        ],
      ),
    );
  }
}
