import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/ridership.dart';

class RidershipApi {
  static const String _baseUrl =
      'https://api.data.gov.my/data-catalogue';

  static Future<List<Ridership>> fetchRidership() async {
    final url = Uri.parse(
      '$_baseUrl?id=ridership_headline&limit=10000',
    );

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body) as List;

        final ridershipList = jsonData
            .map(
              (json) => Ridership.fromJson(
            json as Map<String, dynamic>,
          ),
        )
            .toList();

        ridershipList.sort(
              (a, b) => b.date.compareTo(a.date),
        );

        return ridershipList;
      } else {
        throw Exception(
          'Failed to load ridership data: '
              '${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception(
        'Error fetching ridership data: $e',
      );
    }
  }
}