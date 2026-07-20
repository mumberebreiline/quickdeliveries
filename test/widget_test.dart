import 'package:flutter_test/flutter_test.dart';
import 'package:quickdeliveries/models/location.dart';
import 'package:quickdeliveries/models/order_model.dart';
import 'package:quickdeliveries/services/route_optimizer_service.dart';
import 'package:quickdeliveries/utils/constants.dart';

// The old default test pumped `MyApp`, the counter-app starter widget —
// that class doesn't exist anymore (the real root widget is `App`, in
// lib/app/app.dart, wrapped in Firebase init + Provider in main.dart,
// which a plain widget test can't easily satisfy without extra setup).
// Instead, this tests the one piece of pure logic most worth getting
// right: the route optimizer.
void main() {
  test('groups orders into time windows and sequences by distance', () async {
    final optimizer = RouteOptimizerService();
    final now = DateTime.now();

    final orderA = FoodOrder(
      id: 'a',
      userId: 'u1',
      customerName: 'Alice',
      customerPhone: '0700000001',
      items: [OrderItem(foodId: 'p1', name: 'Rolex', price: 7000, quantity: 1)],
      total: 7000,
      createdAt: now,
      deliveryLocation: CampusLocations.buildings[0],
      preferredTime: now.add(const Duration(minutes: 10)),
    );

    final orderB = FoodOrder(
      id: 'b',
      userId: 'u2',
      customerName: 'Brian',
      customerPhone: '0700000002',
      items: [
        OrderItem(
          foodId: 'p2',
          name: 'Rice with beans',
          price: 5000,
          quantity: 1,
        ),
      ],
      total: 5000,
      createdAt: now,
      deliveryLocation: CampusLocations.buildings[1],
      preferredTime: now.add(const Duration(minutes: 12)),
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
