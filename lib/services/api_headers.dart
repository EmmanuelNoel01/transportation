import 'dart:convert';

import 'package:http/http.dart' as http;

class ApiHeaders {
  static Map<String, String> getGooglePlacesHeaders(String apiKey) {
    return {
      'Content-Type': 'application/json',
      'X-Goog-Api-Key': apiKey,
      'X-Goog-FieldMask': '*',  // Request all fields
    };
  }
  
  static Map<String, String> getMapsHeaders(String apiKey) {
    return {
      'Content-Type': 'application/json',
      'X-Goog-Api-Key': apiKey,
    };
  }
  
  static Future<http.Response> makeGoogleApiRequest(
    String url, 
    String apiKey,
    {Map<String, dynamic>? body}
  ) async {
    final headers = getGooglePlacesHeaders(apiKey);
    
    if (body != null) {
      return await http.post(
        Uri.parse(url),
        headers: headers,
        body: jsonEncode(body),
      );
    } else {
      return await http.get(
        Uri.parse(url),
        headers: headers,
      );
    }
  }
}