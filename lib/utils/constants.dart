import '../models/location.dart';

class AppConfig {
  /// How wide each delivery time-window bucket is. Orders needed around
  /// the same time get batched together instead of separate trips.
  static const Duration deliveryWindowSize = Duration(minutes: 30);

  /// Assumed average speed (km/h) for a vendor walking/boda-boda-ing
  /// around campus — used only to *estimate* ETAs and lateness risk.
  static const double assumedSpeedKmh = 12.0;

  /// If an order's estimated arrival is more than this many minutes past
  /// the customer's preferred time, it's flagged as at-risk.
  static const int latenessGraceMinutes = 15;
}

/// Preset delivery points around Makerere University main campus.
/// Coordinates are approximate — swap for precise GPS pins (or let the
/// vendor drop a pin per building) before going to production.
class CampusLocations {
  static const vendorBase = Location(
    id: 'vendor_base',
    name: 'Vendor Kitchen / Stall',
    latitude: 0.33280,
    longitude: 32.56750,
    description: 'Starting point for every delivery route',
  );

  static const List<Location> buildings = [
    Location(
      id: 'main_building',
      name: 'Main Building',
      latitude: 0.33170,
      longitude: 32.56900,
    ),
    Location(
      id: 'cit_building',
      name: 'CIT Building (Block B)',
      latitude: 0.33430,
      longitude: 32.57170,
    ),
    Location(
      id: 'library',
      name: 'University Library',
      latitude: 0.33230,
      longitude: 32.56980,
    ),
    Location(
      id: 'lumumba_hall',
      name: 'Lumumba Hall',
      latitude: 0.33590,
      longitude: 32.57120,
    ),
    Location(
      id: 'livingstone_hall',
      name: 'Livingstone Hall',
      latitude: 0.33020,
      longitude: 32.56680,
    ),
    Location(
      id: 'mary_stuart_hall',
      name: 'Mary Stuart Hall',
      latitude: 0.33380,
      longitude: 32.56600,
    ),
    Location(
      id: 'ctf1',
      name: 'CTF1 Lecture Complex',
      latitude: 0.33350,
      longitude: 32.57050,
    ),
    Location(
      id: 'freedom_square',
      name: 'Freedom Square',
      latitude: 0.33260,
      longitude: 32.56850,
    ),
    Location(
      id: 'school_of_law',
      name: 'School of Law',
      latitude: 0.33110,
      longitude: 32.56820,
    ),
  ];

  static Location? findById(String id) {
    if (id == vendorBase.id) return vendorBase;
    for (final b in buildings) {
      if (b.id == id) return b;
    }
    return null;
  }
}
