import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

class UVService {
  Future<Map<String, dynamic>?> getCurrentUV() async {
    try {
      // 1. Check/Request Permissions
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return null; // Service disabled
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return null;
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        return null;
      }

      // 2. Get Location
      Position position = await Geolocator.getCurrentPosition();

      // 3. Call Open-Meteo API
      final url = Uri.parse(
          'https://api.open-meteo.com/v1/forecast?latitude=${position.latitude}&longitude=${position.longitude}&hourly=uv_index&forecast_days=1&timezone=auto');
      
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final hourly = data['hourly'];
        final indices = hourly['uv_index'] as List;

        // Find index for current hour
        // Open-Meteo returns ISO8601 strings in list. We just need to find the closest hour.
        // Or simpler: The API returns 24 hours starting from 00:00 of the day.
        // We can just grab the current hour index from 0-23.
        // Note: The API defaults to the given timezone, but explicit timezone handling is safer.
        // For simplicity, let's just grab the index matching DateTime.now().hour if logic holds.
        // Or safer: parse the time strings.
        
        // Simple approach: The API returns data for the requested day.
        // We need to match the current hour.
        
        final currentHour = DateTime.now().hour;
        if (currentHour < indices.length) {
            final uv = indices[currentHour];
            return {
                'uv': uv,
                'location': 'Your Location' // API doesn't return city name, would need Geocoding for that
            };
        }
      }
    } catch (e) {
      // debugPrint('UV Service Error: $e');
    }
    return null;
  }
}
