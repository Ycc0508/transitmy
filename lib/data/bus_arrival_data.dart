import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'arrival_data.dart';

class BusArrivalService {
  static const String _gtfsUrl =
      'https://api.data.gov.my/gtfs-static/prasarana?category=rapid-bus-kl';

  static bool _loaded = false;

  static final List<_BusStop> _stops = [];
  static final List<_BusRoute> _routes = [];
  static final List<_BusTrip> _trips = [];
  static final List<_BusStopTime> _stopTimes = [];
  static final List<_BusFrequency> _frequencies = [];

  static Future<void> loadData() async {
    if (_loaded) {
      return;
    }

    debugPrint(
      'Bus Arrival Service',
    );

    debugPrint(
      'Loading Government Rapid Bus GTFS Static Data...',
    );

    try {
      final response = await http.get(
        Uri.parse(_gtfsUrl),
      );

      if (response.statusCode != 200) {
        throw Exception(
          'Failed to load Rapid Bus GTFS data. '
              'Status: ${response.statusCode}',
        );
      }

      final archive = ZipDecoder().decodeBytes(
        response.bodyBytes,
      );

      _stops.clear();
      _routes.clear();
      _trips.clear();
      _stopTimes.clear();
      _frequencies.clear();

      for (final file in archive) {
        if (!file.isFile) {
          continue;
        }

        final content = utf8.decode(
          file.content as List<int>,
        );

        if (file.name.endsWith('stops.txt')) {
          _parseStops(content);
        } else if (file.name.endsWith('routes.txt')) {
          _parseRoutes(content);
        } else if (file.name.endsWith('trips.txt')) {
          _parseTrips(content);
        } else if (file.name.endsWith('stop_times.txt')) {
          _parseStopTimes(content);
        } else if (file.name.endsWith('frequencies.txt')) {
          _parseFrequencies(content);
        }
      }

      _loaded = true;

      debugPrint(
        'Bus Arrival GTFS loaded successfully.',
      );

      debugPrint(
        'Bus Stops: ${_stops.length}',
      );

      debugPrint(
        'Bus Routes: ${_routes.length}',
      );

      debugPrint(
        'Bus Trips: ${_trips.length}',
      );

      debugPrint(
        'Bus Stop Times: ${_stopTimes.length}',
      );

      debugPrint(
        'Bus Frequencies: ${_frequencies.length}',
      );
    } catch (e) {
      debugPrint(
        'Bus Arrival GTFS error: $e',
      );

      rethrow;
    }
  }

  static Future<List<ArrivalData>> getArrivals(
      String stationName, {
        String? routeId,
      }) async {
    await loadData();

    debugPrint(
      'BUS ARRIVAL STATION: $stationName',
    );

    final stop = _findStop(stationName);

    if (stop == null) {
      debugPrint(
        'Bus arrival station not found: $stationName',
      );

      return [];
    }

    debugPrint(
      'Bus arrival stop found: '
          '${stop.name} (${stop.id})',
    );

    final stopTimes = _stopTimes
        .where(
          (stopTime) =>
      stopTime.stopId == stop.id,
    )
        .toList();

    if (stopTimes.isEmpty) {
      debugPrint(
        'No bus stop times found for ${stop.name}',
      );

      return [];
    }

    final now = DateTime.now();

    final List<ArrivalData> results = [];

    for (final stopTime in stopTimes) {
      final trip = _findTrip(
        stopTime.tripId,
      );

      if (trip == null) {
        continue;
      }

      if (routeId != null &&
          routeId.trim().isNotEmpty) {
        if (!_routeMatches(
          trip.routeId,
          routeId,
        )) {
          continue;
        }
      }

      final route = _findRoute(
        trip.routeId,
      );

      final lineName = _getLineName(
        route,
        trip.routeId,
      );

      final frequencies = _frequencies
          .where(
            (frequency) =>
        frequency.tripId == trip.id,
      )
          .toList();

      if (frequencies.isNotEmpty) {
        for (final frequency in frequencies) {
          final arrival = _getNextFrequencyArrival(
            stopTime.arrivalTime,
            frequency,
            now,
          );

          if (arrival == null) {
            continue;
          }

          results.add(
            ArrivalData(
              station: stationName,
              line: lineName,
              arrivalTime: _formatTime(
                arrival,
              ),
              status: 'Scheduled',
            ),
          );
        }
      } else {
        final arrival = _parseGtfsDateTime(
          stopTime.arrivalTime,
          now,
        );

        if (arrival == null) {
          continue;
        }

        if (!arrival.isAfter(now)) {
          continue;
        }

        results.add(
          ArrivalData(
            station: stationName,
            line: lineName,
            arrivalTime: _formatTime(
              arrival,
            ),
            status: 'Scheduled',
          ),
        );
      }
    }

    results.sort(
          (a, b) {
        final timeA = _parseDisplayTime(
          a.arrivalTime,
        );

        final timeB = _parseDisplayTime(
          b.arrivalTime,
        );

        return timeA.compareTo(timeB);
      },
    );

    final Set<String> seen = {};

    final List<ArrivalData> uniqueResults = [];

    for (final arrival in results) {
      final key =
          '${arrival.line}_${arrival.arrivalTime}';

      if (seen.add(key)) {
        uniqueResults.add(
          arrival,
        );
      }

      if (uniqueResults.length >= 5) {
        break;
      }
    }

    debugPrint(
      'Bus arrivals found: '
          '${uniqueResults.length}',
    );

    for (final arrival in uniqueResults) {
      debugPrint(
        'Bus ${arrival.line}: '
            '${arrival.arrivalTime} '
            '(${arrival.status})',
      );
    }

    return uniqueResults;
  }

  static _BusStop? _findStop(
      String stationName,
      ) {
    final target = _normalise(
      stationName,
    );

    for (final stop in _stops) {
      if (_normalise(stop.name) == target) {
        return stop;
      }
    }

    for (final stop in _stops) {
      final name = _normalise(
        stop.name,
      );

      if (name.contains(target) ||
          target.contains(name)) {
        return stop;
      }
    }

    final targetTokens = target
        .split(' ')
        .where(
          (token) => token.isNotEmpty,
    )
        .toList();

    if (targetTokens.isEmpty) {
      return null;
    }

    for (final stop in _stops) {
      final nameTokens = _normalise(
        stop.name,
      )
          .split(' ')
          .where(
            (token) => token.isNotEmpty,
      )
          .toList();

      final matched = targetTokens.every(
            (token) =>
            nameTokens.contains(token),
      );

      if (matched) {
        return stop;
      }
    }

    return null;
  }

  static bool _routeMatches(
      String gtfsRouteId,
      String selectedRoute,
      ) {
    final selected = selectedRoute
        .trim()
        .toLowerCase();

    final gtfs = gtfsRouteId
        .trim()
        .toLowerCase();

    if (gtfs == selected) {
      return true;
    }

    final route = _findRoute(
      gtfsRouteId,
    );

    if (route == null) {
      return false;
    }

    if (route.shortName
        .trim()
        .toLowerCase() ==
        selected) {
      return true;
    }

    if (route.longName
        .trim()
        .toLowerCase() ==
        selected) {
      return true;
    }

    return false;
  }

  static _BusTrip? _findTrip(
      String tripId,
      ) {
    for (final trip in _trips) {
      if (trip.id == tripId) {
        return trip;
      }
    }

    return null;
  }

  static _BusRoute? _findRoute(
      String routeId,
      ) {
    for (final route in _routes) {
      if (route.id == routeId) {
        return route;
      }
    }

    return null;
  }

  static String _getLineName(
      _BusRoute? route,
      String routeId,
      ) {
    if (route == null) {
      return routeId;
    }

    if (route.shortName.trim().isNotEmpty) {
      return route.shortName.trim();
    }

    if (route.longName.trim().isNotEmpty) {
      return route.longName.trim();
    }

    return route.id;
  }

  static DateTime? _getNextFrequencyArrival(
      String stopTime,
      _BusFrequency frequency,
      DateTime now,
      ) {
    final baseTime = _parseGtfsDateTime(
      stopTime,
      now,
    );

    if (baseTime == null) {
      return null;
    }

    final start = _parseGtfsDateTime(
      frequency.startTime,
      now,
    );

    final end = _parseGtfsDateTime(
      frequency.endTime,
      now,
    );

    if (start == null || end == null) {
      return null;
    }

    final headway = frequency.headwaySeconds;

    if (headway <= 0) {
      return null;
    }

    DateTime candidate = baseTime;

    while (candidate.isBefore(start)) {
      candidate = candidate.add(
        Duration(
          seconds: headway,
        ),
      );
    }

    while (candidate.isBefore(now)) {
      candidate = candidate.add(
        Duration(
          seconds: headway,
        ),
      );
    }

    if (candidate.isAfter(end)) {
      return null;
    }

    return candidate;
  }

  static DateTime? _parseGtfsDateTime(
      String value,
      DateTime baseDate,
      ) {
    try {
      final parts = value
          .trim()
          .split(':');

      if (parts.length != 3) {
        return null;
      }

      final hour = int.parse(
        parts[0],
      );

      final minute = int.parse(
        parts[1],
      );

      final second = int.parse(
        parts[2],
      );

      final dayOffset = hour ~/ 24;

      final realHour = hour % 24;

      return DateTime(
        baseDate.year,
        baseDate.month,
        baseDate.day + dayOffset,
        realHour,
        minute,
        second,
      );
    } catch (_) {
      return null;
    }
  }

  static String _formatTime(
      DateTime time,
      ) {
    final hour = time.hour;

    final minute = time.minute;

    final displayHour = hour == 0
        ? 12
        : hour > 12
        ? hour - 12
        : hour;

    final period =
    hour >= 12 ? 'PM' : 'AM';

    return '$displayHour:'
        '${minute.toString().padLeft(2, '0')} '
        '$period';
  }

  static DateTime _parseDisplayTime(
      String value,
      ) {
    try {
      final parts = value.split(' ');

      final time = parts[0];

      final period =
      parts.length > 1
          ? parts[1].toUpperCase()
          : 'AM';

      final timeParts =
      time.split(':');

      var hour = int.parse(
        timeParts[0],
      );

      final minute = int.parse(
        timeParts[1],
      );

      if (period == 'PM' &&
          hour != 12) {
        hour += 12;
      }

      if (period == 'AM' &&
          hour == 12) {
        hour = 0;
      }

      return DateTime(
        2000,
        1,
        1,
        hour,
        minute,
      );
    } catch (_) {
      return DateTime(
        2000,
        1,
        1,
      );
    }
  }

  static String _normalise(
      String value,
      ) {
    var result =
    value.toUpperCase();

    result = result.replaceAll(
      RegExp(r'\([^)]*\)'),
      '',
    );

    result = result.replaceAll(
      RegExp(r'\bOPP\b'),
      '',
    );

    result = result.replaceAll(
      RegExp(r'\bOPPOSITE\b'),
      '',
    );

    result = result.replaceAll(
      RegExp(r'[^A-Z0-9]+'),
      ' ',
    );

    result = result.replaceAll(
      RegExp(r'\s+'),
      ' ',
    );

    return result.trim();
  }

  static List<String> _parseCsvLine(
      String line,
      ) {
    final result = <String>[];

    final buffer = StringBuffer();

    bool insideQuotes = false;

    for (int i = 0;
    i < line.length;
    i++) {
      final char = line[i];

      if (char == '"') {
        insideQuotes = !insideQuotes;
      } else if (char == ',' &&
          !insideQuotes) {
        result.add(
          buffer.toString().trim(),
        );

        buffer.clear();
      } else {
        buffer.write(char);
      }
    }

    result.add(
      buffer.toString().trim(),
    );

    return result;
  }

  static List<List<String>> _parseCsv(
      String content,
      ) {
    final lines =
    const LineSplitter().convert(
      content,
    );

    if (lines.isEmpty) {
      return [];
    }

    final rows =
    <List<String>>[];

    for (final line in lines) {
      if (line.trim().isEmpty) {
        continue;
      }

      rows.add(
        _parseCsvLine(line),
      );
    }

    return rows;
  }

  static Map<String, int> _headers(
      List<String> header,
      ) {
    final map =
    <String, int>{};

    for (int i = 0;
    i < header.length;
    i++) {
      map[
      header[i].trim()] = i;
    }

    return map;
  }

  static String _value(
      List<String> row,
      Map<String, int> headers,
      String column,
      ) {
    final index =
    headers[column];

    if (index == null ||
        index >= row.length) {
      return '';
    }

    return row[index].trim();
  }

  static void _parseStops(
      String content,
      ) {
    final rows =
    _parseCsv(content);

    if (rows.isEmpty) {
      return;
    }

    final headers =
    _headers(rows.first);

    for (final row
    in rows.skip(1)) {
      final id = _value(
        row,
        headers,
        'stop_id',
      );

      final name = _value(
        row,
        headers,
        'stop_name',
      );

      if (id.isEmpty) {
        continue;
      }

      _stops.add(
        _BusStop(
          id: id,
          name: name,
        ),
      );
    }
  }

  static void _parseRoutes(
      String content,
      ) {
    final rows =
    _parseCsv(content);

    if (rows.isEmpty) {
      return;
    }

    final headers =
    _headers(rows.first);

    for (final row
    in rows.skip(1)) {
      final id = _value(
        row,
        headers,
        'route_id',
      );

      final shortName = _value(
        row,
        headers,
        'route_short_name',
      );

      final longName = _value(
        row,
        headers,
        'route_long_name',
      );

      if (id.isEmpty) {
        continue;
      }

      _routes.add(
        _BusRoute(
          id: id,
          shortName: shortName,
          longName: longName,
        ),
      );
    }
  }

  static void _parseTrips(
      String content,
      ) {
    final rows =
    _parseCsv(content);

    if (rows.isEmpty) {
      return;
    }

    final headers =
    _headers(rows.first);

    for (final row
    in rows.skip(1)) {
      final routeId = _value(
        row,
        headers,
        'route_id',
      );

      final tripId = _value(
        row,
        headers,
        'trip_id',
      );

      if (tripId.isEmpty) {
        continue;
      }

      _trips.add(
        _BusTrip(
          id: tripId,
          routeId: routeId,
        ),
      );
    }
  }

  static void _parseStopTimes(
      String content,
      ) {
    final rows =
    _parseCsv(content);

    if (rows.isEmpty) {
      return;
    }

    final headers =
    _headers(rows.first);

    for (final row
    in rows.skip(1)) {
      final tripId = _value(
        row,
        headers,
        'trip_id',
      );

      final stopId = _value(
        row,
        headers,
        'stop_id',
      );

      final arrivalTime =
      _value(
        row,
        headers,
        'arrival_time',
      );

      if (tripId.isEmpty ||
          stopId.isEmpty ||
          arrivalTime.isEmpty) {
        continue;
      }

      _stopTimes.add(
        _BusStopTime(
          tripId: tripId,
          stopId: stopId,
          arrivalTime: arrivalTime,
        ),
      );
    }
  }

  static void _parseFrequencies(
      String content,
      ) {
    final rows =
    _parseCsv(content);

    if (rows.isEmpty) {
      return;
    }

    final headers =
    _headers(rows.first);

    for (final row
    in rows.skip(1)) {
      final tripId = _value(
        row,
        headers,
        'trip_id',
      );

      final startTime =
      _value(
        row,
        headers,
        'start_time',
      );

      final endTime =
      _value(
        row,
        headers,
        'end_time',
      );

      final headway =
      _value(
        row,
        headers,
        'headway_secs',
      );

      if (tripId.isEmpty ||
          startTime.isEmpty ||
          endTime.isEmpty ||
          headway.isEmpty) {
        continue;
      }

      final headwaySeconds =
      int.tryParse(headway);

      if (headwaySeconds == null ||
          headwaySeconds <= 0) {
        continue;
      }

      _frequencies.add(
        _BusFrequency(
          tripId: tripId,
          startTime: startTime,
          endTime: endTime,
          headwaySeconds:
          headwaySeconds,
        ),
      );
    }
  }
}

class _BusStop {
  final String id;
  final String name;

  _BusStop({
    required this.id,
    required this.name,
  });
}

class _BusRoute {
  final String id;
  final String shortName;
  final String longName;

  _BusRoute({
    required this.id,
    required this.shortName,
    required this.longName,
  });
}

class _BusTrip {
  final String id;
  final String routeId;

  _BusTrip({
    required this.id,
    required this.routeId,
  });
}

class _BusStopTime {
  final String tripId;
  final String stopId;
  final String arrivalTime;

  _BusStopTime({
    required this.tripId,
    required this.stopId,
    required this.arrivalTime,
  });
}

class _BusFrequency {
  final String tripId;
  final String startTime;
  final String endTime;
  final int headwaySeconds;

  _BusFrequency({
    required this.tripId,
    required this.startTime,
    required this.endTime,
    required this.headwaySeconds,
  });
}