import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../repositories/order_repository.dart';
import '../../repositories/user_repository.dart';
import '../pos/cart_provider.dart';
import 'package:geolocator/geolocator.dart';
import '../../repositories/coupon_repository.dart';
import '../auth/auth_provider.dart';

class CustomerCheckoutScreen extends ConsumerStatefulWidget {
  const CustomerCheckoutScreen({super.key});

  @override
  ConsumerState<CustomerCheckoutScreen> createState() => _CustomerCheckoutScreenState();
}

class _CustomerCheckoutScreenState extends ConsumerState<CustomerCheckoutScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _couponController = TextEditingController();
  bool _isPlacingOrder = false;
  bool _isLoadingOutlets = true;
  bool _isDetectingLocation = false;
  bool _isValidatingCoupon = false;
  List<Map<String, dynamic>> _outlets = [];
  Map<String, dynamic>? _selectedOutlet;
  bool _autoDetected = false;
  bool _hasAutoFilledProfileInfo = false;

  @override
  void initState() {
    super.initState();
    _loadOutletsAndDetect();
  }

  Future<void> _loadOutletsAndDetect() async {
    try {
      final data = await Supabase.instance.client.from('outlets').select();
      final outlets = List<Map<String, dynamic>>.from(data);
      setState(() {
        _outlets = outlets;
        _selectedOutlet = outlets.isNotEmpty ? outlets.first : null;
        _isLoadingOutlets = false;
        _isDetectingLocation = outlets.isNotEmpty;
      });

      if (outlets.isEmpty) return;

      // Try to get user location and find nearest cart
      try {
        var permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        if (permission == LocationPermission.deniedForever) throw Exception('denied');

        final position = await Geolocator.getCurrentPosition()
            .timeout(const Duration(seconds: 8));

        // Find nearest outlet using lat/lng columns if available
        double minDistance = double.maxFinite;
        Map<String, dynamic>? nearest;
        for (final o in outlets) {
          final double lat = (o['lat'] ?? 0).toDouble();
          final double lng = (o['lng'] ?? 0).toDouble();
          if (lat == 0.0 && lng == 0.0) continue; // Skip if no coordinates
          final distance = Geolocator.distanceBetween(
              position.latitude, position.longitude, lat, lng);
          if (distance < minDistance) {
            minDistance = distance;
            nearest = o;
          }
        }

        if (nearest != null && mounted) {
          setState(() {
            _selectedOutlet = nearest;
            _autoDetected = true;
            _isDetectingLocation = false;
          });
        } else {
          // No lat/lng in DB — just keep first outlet selected
          if (mounted) setState(() { _isDetectingLocation = false; _autoDetected = false; });
        }
      } catch (_) {
        // Location failed — silently fall back to first outlet
        if (mounted) setState(() { _isDetectingLocation = false; _autoDetected = false; });
      }
    } catch (e) {
      setState(() { _isLoadingOutlets = false; _isDetectingLocation = false; });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _couponController.dispose();
    super.dispose();
  }

  Future<void> _applyCoupon() async {
    final code = _couponController.text.trim();
    if (code.isEmpty) return;

    setState(() => _isValidatingCoupon = true);
    try {
      final coupon = await ref.read(couponRepositoryProvider).getCouponByCode(code);
      if (coupon != null) {
        final error = coupon.validate(ref.read(cartProvider).subtotal);
        if (error == null) {
          ref.read(cartProvider.notifier).applyCoupon(coupon);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Coupon applied successfully!'), backgroundColor: Colors.green),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(error), backgroundColor: Colors.red),
            );
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invalid coupon code'), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error validating coupon: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isValidatingCoupon = false);
    }
  }

  Future<void> _placeOrder() async {
    if (_nameController.text.isEmpty || _phoneController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter your name and phone number')));
      return;
    }

    if (_selectedOutlet == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a cart location')));
      return;
    }

    setState(() => _isPlacingOrder = true);
    final cartState = ref.read(cartProvider);
    final outletId = _selectedOutlet!['id'];
    final customerId = ref.read(userProfileProvider).value?.id;

    final orderData = {
      'outlet_id': outletId,
      'customer_id': customerId,
      'items': cartState.items.map((i) => {
        'id': i.menuItem.id,
        'name': i.menuItem.name,
        'quantity': i.quantity,
        'price': i.menuItem.price
      }).toList(),
      'total': cartState.total,
      'discount_amount': cartState.discountAmount,
      'coupon_code': cartState.appliedCoupon?.code,
      'customer_name': _nameController.text,
      'customer_phone': _phoneController.text,
      'status': 'pending',
      'order_type': 'takeaway',
    };

    try {
      final orderId = await ref.read(orderRepositoryProvider).createOrder(orderData);
      if (orderId != null) {
        ref.read(cartProvider.notifier).clearCart();
        if (mounted) {
          context.pushReplacement('/customer/order-status/$orderId');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Order Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isPlacingOrder = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cartState = ref.watch(cartProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Checkout', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: ref.watch(userProfileProvider).when(
        data: (profile) {
          // Auto-fill logic when profile changes
          if (profile != null && !_hasAutoFilledProfileInfo) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                if (_nameController.text.isEmpty) {
                  _nameController.text = profile.fullName ?? '';
                }
                if (_phoneController.text.isEmpty) {
                  _phoneController.text = profile.phone ?? '';
                }
                _hasAutoFilledProfileInfo = true;
              }
            });
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            // Cart selector
            Row(
              children: [
                const Text('Pick Up From', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(width: 10),
                if (_isDetectingLocation)
                  const SizedBox(
                    width: 14, height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF8B4513)),
                  )
                else if (_autoDetected)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: Colors.green[50], borderRadius: BorderRadius.circular(10)),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.location_on, color: Colors.green, size: 12),
                        SizedBox(width: 4),
                        Text('Auto-detected', style: TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (_isLoadingOutlets)
              const Center(child: CircularProgressIndicator())
            else if (_outlets.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(12)),
                child: const Text('No carts available. Please contact support.', style: TextStyle(color: Colors.red)),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<Map<String, dynamic>>(
                    isExpanded: true,
                    value: _selectedOutlet,
                    items: _outlets.map((outlet) {
                      return DropdownMenuItem(
                        value: outlet,
                        child: Row(
                          children: [
                            const Icon(Icons.storefront, color: Color(0xFF8B4513), size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(outlet['name'] ?? 'Cart', style: const TextStyle(fontWeight: FontWeight.bold)),
                                  if (outlet['address'] != null && outlet['address'].toString().isNotEmpty)
                                    Text(outlet['address'], style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (val) => setState(() => _selectedOutlet = val),
                  ),
                ),
              ),

            const SizedBox(height: 28),
            const Text('Your Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 14),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                hintText: 'Your Name',
                prefixIcon: const Icon(Icons.person_outline),
                filled: true,
                fillColor: Colors.grey[50],
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                hintText: 'Phone Number',
                prefixIcon: const Icon(Icons.phone_outlined),
                filled: true,
                fillColor: Colors.grey[50],
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
              ),
            ),

            const SizedBox(height: 28),
            const Text('Order Summary', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 14),
            if (cartState.items.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 40),
                decoration: BoxDecoration(
                  color: Colors.grey[50], 
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey[200]!, style: BorderStyle.none)
                ),
                child: Column(
                  children: [
                    Icon(Icons.shopping_basket_outlined, size: 48, color: Colors.grey[400]),
                    const SizedBox(height: 12),
                    Text('Your cart is empty', style: TextStyle(color: Colors.grey[600], fontSize: 16)),
                  ],
                ),
              )
            else
              ...cartState.items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.menuItem.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                          Text('₹${item.menuItem.price} each', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                        ],
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove, size: 16),
                            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                            padding: EdgeInsets.zero,
                            onPressed: () => ref.read(cartProvider.notifier).decrementItem(item.menuItem.id),
                          ),
                          Text('${item.quantity}', style: const TextStyle(fontWeight: FontWeight.bold)),
                          IconButton(
                            icon: const Icon(Icons.add, size: 16),
                            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                            padding: EdgeInsets.zero,
                            onPressed: () => ref.read(cartProvider.notifier).addItem(item.menuItem),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 15),
                    Text('₹${item.total.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              )),
            const Divider(height: 32),
            
            // Coupon Code Field
            if (cartState.items.isNotEmpty) ...[
              const Text('Apply Coupon', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _couponController,
                      decoration: InputDecoration(
                        hintText: 'Enter code...',
                        filled: true,
                        fillColor: Colors.grey[50],
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      textCapitalization: TextCapitalization.characters,
                      enabled: cartState.appliedCoupon == null,
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    height: 48,
                    child: TextButton(
                      onPressed: cartState.appliedCoupon != null 
                          ? () => ref.read(cartProvider.notifier).removeCoupon() 
                          : _isValidatingCoupon ? null : _applyCoupon,
                      style: TextButton.styleFrom(
                        backgroundColor: cartState.appliedCoupon != null ? Colors.red[50] : const Color(0xFF8B4513).withOpacity(0.1),
                        foregroundColor: cartState.appliedCoupon != null ? Colors.red : const Color(0xFF8B4513),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isValidatingCoupon 
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : Text(cartState.appliedCoupon != null ? 'Remove' : 'Apply', style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],

            if (cartState.appliedCoupon != null) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    cartState.appliedCoupon!.applicableItemIds != null && cartState.appliedCoupon!.applicableItemIds!.isNotEmpty
                        ? 'Item Discount (${cartState.appliedCoupon!.code})'
                        : 'Discount (${cartState.appliedCoupon!.code})', 
                    style: TextStyle(color: Colors.green[700])
                  ),
                  Text('-₹${cartState.discountAmount.toStringAsFixed(0)}', style: TextStyle(color: Colors.green[700], fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 12),
            ],

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Text('₹${cartState.total.toStringAsFixed(0)}',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF8B4513))),
              ],
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: (_isPlacingOrder || _outlets.isEmpty || cartState.items.isEmpty) ? null : _placeOrder,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8B4513),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  elevation: 0,
                ),
                child: _isPlacingOrder
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('CONFIRM ORDER', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      );
        }, // close data
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error: $e')),
      ), // close body: when()
    ); // close Scaffold
  } // close build()
} // close class
