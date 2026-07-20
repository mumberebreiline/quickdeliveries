import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../models/location.dart';
import '../../providers/order_provider.dart';
import '../../utils/constants.dart';
import '../../utils/helpers.dart';
import '../../utils/validators.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/quantity_selector.dart';
import 'order_status_screen.dart';

/// Where the customer reviews their cart and tells the vendor exactly where
/// and when they want the food — the two pieces of information the route
/// optimizer needs most.
class OrderScreen extends StatefulWidget {
  const OrderScreen({super.key});

  @override
  State<OrderScreen> createState() => _OrderScreenState();
}

class _OrderScreenState extends State<OrderScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _notesController = TextEditingController();

  Location? _selectedBuilding;
  TimeOfDay? _selectedTime;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final now = TimeOfDay.now();
    final picked = await showTimePicker(context: context, initialTime: now);
    if (picked != null) setState(() => _selectedTime = picked);
  }
import '../../models/order_model.dart';
import '../../services/order_service.dart';

  Future<void> _submit(OrderProvider orderProvider) async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedBuilding == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please choose a delivery building')),
      );
      return;
    }
    if (_selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please choose a preferred time')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final now = DateTime.now();
    var preferredTime = DateTime(
      now.year,
      now.month,
      now.day,
      _selectedTime!.hour,
      _selectedTime!.minute,
    );
    // If the picked time already passed today, assume they mean tomorrow.
    if (preferredTime.isBefore(now)) {
      preferredTime = preferredTime.add(const Duration(days: 1));
    }

    final orderId = orderProvider.checkout(
      customerId: const Uuid().v4(),
      customerName: _nameController.text.trim(),
      customerPhone: _phoneController.text.trim(),
      deliveryLocation: _selectedBuilding!,
      preferredTime: preferredTime,
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
      onError: (error) {
        // The write failed in the background, after we've already
        // navigated away. OrderStatusScreen's own timeout is the backstop
        // that tells the customer something went wrong; this is just for
        // your own debugging in the meantime.
        debugPrint('Order save failed: $error');
      },
    );

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => OrderStatusScreen(orderId: orderId)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final orderProvider = context.watch<OrderProvider>();
    final cart = orderProvider.cart.values.toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Your Order')),
      body: cart.isEmpty
          ? const Center(child: Text('Your cart is empty'))
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  ...cart.map(
                    (line) => Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text(line.product.name),
                        subtitle: Text(formatUgx(line.product.price)),
                        trailing: QuantitySelector(
                          quantity: line.quantity,
                          onChanged: (q) =>
                              orderProvider.updateQuantity(line.product.id, q),
                        ),
                      ),
                    ),
                  ),
                  const Divider(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        formatUgx(orderProvider.cartTotal),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: 'Your name'),
                    validator: (v) => Validators.notEmpty(v, fieldName: 'Name'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Phone number',
                    ),
                    validator: Validators.phone,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<Location>(
                    initialValue: _selectedBuilding,
                    decoration: const InputDecoration(labelText: 'Deliver to'),
                    items: CampusLocations.buildings
                        .map(
                          (b) =>
                              DropdownMenuItem(value: b, child: Text(b.name)),
                        )
                        .toList(),
                    onChanged: (b) => setState(() => _selectedBuilding = b),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      _selectedTime == null
                          ? 'Choose preferred time'
                          : 'Deliver around ${_selectedTime!.format(context)}',
                    ),
                    trailing: const Icon(Icons.access_time),
                    onTap: _pickTime,
                    tileColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _notesController,
                    decoration: const InputDecoration(
                      labelText: 'Notes (optional)',
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 24),
                  CustomButton(
                    label: 'Place Order',
                    fullWidth: true,
                    isLoading: _isSubmitting,
                    onPressed: () => _submit(orderProvider),
                  ),
                ],
              ),
            ),
    );
  }
}
