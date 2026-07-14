import 'package:flutter_test/flutter_test.dart';
import 'package:quickdeliveries/models/location.dart';
import 'package:quickdeliveries/models/order.dart';
import 'package:quickdeliveries/models/order_item.dart';
import 'package:quickdeliveries/services/route_optimizer_service.dart';
import 'package:quickdeliveries/utils/constants.dart';

// The old default test pumped `MyApp`, the counter-app starter widget.
// That widget doesn't exist anymore (our root widget is `App`, in
// lib/app/app.dart) — and `App` calls Firebase.initializeApp() in main(),
// which isn't available in a plain widget test without extra setup. So
// instead of a UI smoke test, this checks the one piece of pure logic
// that's most important to get right: the route optimizer.
void main() {
  test('groups orders into time windows and sequences by distance', () async {
    final optimizer = RouteOptimizerService();
    final now = DateTime.now();

    final orderA = FoodOrder(
      id: 'a',
      customerId: 'c1',
      customerName: 'Alice',
      customerPhone: '0700000001',
      items: const [
        OrderItem(
          productId: 'p1',
          productName: 'Rolex',
          quantity: 1,
          unitPrice: 7000,
        ),
      ],
      deliveryLocation: CampusLocations.buildings[0],
      preferredTime: now.add(const Duration(minutes: 10)),
      createdAt: now,
    );

    final orderB = FoodOrder(
      id: 'b',
      customerId: 'c2',
      customerName: 'Brian',
      customerPhone: '0700000002',
      items: const [
        OrderItem(
          productId: 'p2',
          productName: 'Rice with beans',
          quantity: 1,
          unitPrice: 5000,
        ),
      ],
      deliveryLocation: CampusLocations.buildings[1],
      preferredTime: now.add(const Duration(minutes: 12)),
      createdAt: now,
    );

    final plan = await optimizer.buildDeliveryPlan([
      orderA,
      orderB,
    ], vendorStart: CampusLocations.vendorBase);

    expect(plan.windows, isNotEmpty);
    expect(plan.totalStops, 2);
    expect(plan.totalDistanceKm, greaterThan(0));
  });

  test('Location.distanceToKm is symmetric and zero for the same point', () {
    const a = Location(id: 'a', name: 'A', latitude: 0.33, longitude: 32.56);
    const b = Location(id: 'b', name: 'B', latitude: 0.34, longitude: 32.57);

    expect(a.distanceToKm(a), 0.0);
    expect(a.distanceToKm(b), closeTo(b.distanceToKm(a), 0.0001));
  });
}
