import 'package:flutter/material.dart';
import '../models/location.dart';

/// Shows that a delivery point is being figured out automatically — a
/// spinner while locating, a friendly label once resolved, or a plain
/// retry button if GPS genuinely couldn't be reached. Never a form field
/// to fill in. Shared by every screen that can place an order.
class LocationStatus extends StatelessWidget {
  final bool isLocating;
  final Location? location;
  final String? error;
  final VoidCallback onRetry;

  const LocationStatus({
    super.key,
    required this.isLocating,
    required this.location,
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    if (isLocating) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 10),
            Text('Detecting your delivery location...'),
          ],
        ),
      );
    }

    if (error != null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                error!,
                style: const TextStyle(fontSize: 12, color: Colors.red),
              ),
            ),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.location_on, color: Colors.green, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              location == null
                  ? 'Delivering to your location'
                  : 'Delivering to: ${location!.name}',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
