import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/location.dart';

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

  double get penaltyMinutesPerStop {
    if (isStorming) return 8;
    if (isRaining) return 4;
    return 0;
  }
}

/// Uses OpenWeatherMap's free tier — no billing/card required, unlike
/// Google Maps. Sign up free at openweathermap.org/api, paste your key
/// below. Until you do, calls safely fall back to clear weather.
class WeatherService {
  static const String _apiKey = 'YOUR_OPENWEATHERMAP_API_KEY';

  Future<WeatherCondition> getCurrentConditions(Location location) async {
    if (_apiKey == 'YOUR_OPENWEATHERMAP_API_KEY') {
      return const WeatherCondition.clear();
    }
    try {
      final uri = Uri.parse(
        'https://api.openweathermap.org/data/2.5/weather'
        '?lat=${location.latitude}&lon=${location.longitude}'
        '&appid=$_apiKey&units=metric',
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 6));
      if (response.statusCode != 200) return const WeatherCondition.clear();

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
