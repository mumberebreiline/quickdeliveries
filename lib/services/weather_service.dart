import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/location.dart';

/// A simplified snapshot of current weather, translated straight into what
/// the route planner actually cares about: how much slower is a delivery
/// likely to be right now because of it.
class WeatherCondition {
  final String description;
  final bool isRaining;
  final bool isStorming;

  const WeatherCondition({
    required this.description,
    required this.isRaining,
    required this.isStorming,
  });

  const WeatherCondition.clear()
    : description = 'Clear',
      isRaining = false,
      isStorming = false;

  /// Extra minutes added per stop — footpaths on campus slow down a lot
  /// more than a paved road does in the rain.
  double get penaltyMinutesPerStop {
    if (isStorming) return 8;
    if (isRaining) return 4;
    return 0;
  }
}

/// Uses OpenWeatherMap's free tier (no billing/card required, unlike Google
/// Maps) to check current conditions near campus.
///
/// To use this: sign up free at openweathermap.org/api, grab your API key,
/// and paste it in below. Until you do, every call safely falls back to
/// [WeatherCondition.clear] — the app keeps working, it just won't factor
/// in weather until the key is added.
class WeatherService {
  static const String _apiKey = 'bd761a0fa9b061066958f62a996bb5d4';

  Future<WeatherCondition> getCurrentConditions(Location location) async {
    if (_apiKey == 'YOUR_OPENWEATHERMAP_API_KEY') {
      // Key not configured yet — degrade gracefully instead of failing.
      return const WeatherCondition.clear();
    }

    try {
      final uri = Uri.parse(
        'https://api.openweathermap.org/data/2.5/weather'
        '?lat=${location.latitude}&lon=${location.longitude}'
        '&appid=$_apiKey&units=metric',
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 6));

      if (response.statusCode != 200) {
        return const WeatherCondition.clear();
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final weatherList = data['weather'] as List<dynamic>?;
      final main = (weatherList != null && weatherList.isNotEmpty)
          ? (weatherList.first as Map<String, dynamic>)['main'] as String? ?? ''
          : '';

      final isStorming = main.toLowerCase().contains('thunderstorm');
      final isRaining =
          !isStorming &&
          (main.toLowerCase().contains('rain') ||
              main.toLowerCase().contains('drizzle'));

      return WeatherCondition(
        description: main.isEmpty ? 'Unknown' : main,
        isRaining: isRaining,
        isStorming: isStorming,
      );
    } catch (e) {
      debugPrint('Weather lookup failed, assuming clear: $e');
      return const WeatherCondition.clear();
    }
  }
}
