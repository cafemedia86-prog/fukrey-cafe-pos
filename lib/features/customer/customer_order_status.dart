import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../repositories/order_repository.dart';

class CustomerOrderStatusScreen extends ConsumerWidget {
  final String orderId;
  const CustomerOrderStatusScreen({super.key, required this.orderId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // We can use a stream or just watch the order repository
    final orderStream = ref.watch(orderRepositoryProvider).watchOrder(orderId);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Order Status', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.go('/customer'),
        ),
      ),
      body: StreamBuilder<Map<String, dynamic>?>(
        stream: orderStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final order = snapshot.data;
          if (order == null) {
            return const Center(child: Text('Order not found'));
          }

          final status = order['status'] ?? 'pending';
          
          return SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              children: [
                _StatusIcon(status: status),
                const SizedBox(height: 24),
                Text(
                  _getStatusText(status),
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                if (status == 'pending' || status == 'preparing') 
                  _EstimatedTimeCountdown(status: status),
                Text(
                  'Order ID: #${orderId.substring(0, 8).toUpperCase()}',
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
                const SizedBox(height: 48),
                _StatusTimeline(currentStatus: status),
                const SizedBox(height: 48),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: [
                      const Text('Scan at counter when ready', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      // Placeholder for QR code
                      Container(
                        width: 150,
                        height: 150,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: const Icon(Icons.qr_code_2, size: 100, color: Colors.black),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'pending': return 'Order Placed';
      case 'preparing': return 'Preparing your order...';
      case 'ready': return 'Your order is ready!';
      case 'completed': return 'Order Handed Over';
      case 'cancelled': return 'Order Cancelled';
      default: return 'Order Processing';
    }
  }
}

class _StatusIcon extends StatelessWidget {
  final String status;
  const _StatusIcon({required this.status});

  @override
  Widget build(BuildContext context) {
    IconData icon;
    Color color;
    switch (status) {
      case 'pending': icon = Icons.receipt_long; color = Colors.blue; break;
      case 'preparing': icon = Icons.outdoor_grill; color = Colors.orange; break;
      case 'ready': icon = Icons.shopping_bag; color = Colors.green; break;
      case 'completed': icon = Icons.check_circle; color = Colors.green; break;
      case 'cancelled': icon = Icons.cancel; color = Colors.red; break;
      default: icon = Icons.info_outline; color = Colors.grey;
    }

    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: 50),
    );
  }
}

class _StatusTimeline extends StatelessWidget {
  final String currentStatus;
  const _StatusTimeline({required this.currentStatus});

  @override
  Widget build(BuildContext context) {
    final stages = ['pending', 'preparing', 'ready', 'completed'];
    final labels = ['Accepted', 'Preparing', 'Ready', 'Picked Up'];
    final currentIndex = stages.indexOf(currentStatus);

    return Column(
      children: List.generate(stages.length, (index) {
        final isCompleted = index <= currentIndex;
        final isLast = index == stages.length - 1;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: isCompleted ? Colors.orange : Colors.grey[200],
                    shape: BoxShape.circle,
                  ),
                  child: isCompleted ? const Icon(Icons.check, color: Colors.white, size: 16) : null,
                ),
                if (!isLast)
                  Container(
                    width: 2,
                    height: 40,
                    color: isCompleted ? Colors.orange : Colors.grey[200],
                  ),
              ],
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  labels[index],
                  style: TextStyle(
                    fontWeight: isCompleted ? FontWeight.bold : FontWeight.normal,
                    color: isCompleted ? Colors.black : Colors.grey[400],
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _getStatusSubtext(stages[index], isCompleted),
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
              ],
            ),
          ],
        );
      }),
    );
  }

  String _getStatusSubtext(String stage, bool isCompleted) {
    if (!isCompleted) return 'Waiting...';
    switch (stage) {
      case 'pending': return 'Kitchen has received order';
      case 'preparing': return 'Chef is working on it';
      case 'ready': return 'Collect at the counter';
      case 'completed': return 'Order picked up';
      default: return '';
    }
  }
}

class _EstimatedTimeCountdown extends StatefulWidget {
  final String status;
  const _EstimatedTimeCountdown({required this.status});

  @override
  State<_EstimatedTimeCountdown> createState() => _EstimatedTimeCountdownState();
}

class _EstimatedTimeCountdownState extends State<_EstimatedTimeCountdown> {
  late int _minutes;

  @override
  void initState() {
    super.initState();
    _minutes = widget.status == 'pending' ? 12 : 5;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.timer_outlined, color: Colors.orange, size: 18),
          const SizedBox(width: 8),
          Text(
            'Ready in ~$_minutes-${_minutes + 3} mins',
            style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
