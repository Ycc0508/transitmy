import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:http/http.dart' as http;

class BusRouteData {
  static const String _gtfsUrl =
      'https://api.data.gov.my/gtfs-static/prasarana?category=rapid-bus-kl';

  static bool _loaded = false;

  static final List<_BusStop> _stops = [];
  static final List<_BusRoute> _routes = [];
  static final List<_BusTrip> _trips = [];
  static final List<_BusStopTime> _stopTimes = [];

  static final Map<String, Set<String>> _stopRoutes = {};
  static final Map<String, List<_BusStopTime>> _tripStopTimes = {};

  static Future<void> loadData() async {
    if (_loaded) {
      return;
    }

    print('========================================');
    print('Bus Route Service');
    print('Loading Rapid Bus KL GTFS Static Data...');
    print('========================================');

    try {
      final response = await http.get(
        Uri.parse(_gtfsUrl),
      );

      print(
        'BUS GTFS STATUS: ${response.statusCode}',
      );

      if (response.statusCode != 200) {
        throw Exception(
          'Failed to load Rapid Bus KL GTFS',
        );
      }

      final archive = ZipDecoder().decodeBytes(
        response.bodyBytes,
      );

      _stops.clear();
      _routes.clear();
      _trips.clear();
      _stopTimes.clear();
      _stopRoutes.clear();
      _tripStopTimes.clear();

      _parseStops(
        _readFile(
          archive,
          'stops.txt',
        ),
      );

      _parseRoutes(
        _readFile(
          archive,
          'routes.txt',
        ),
      );

      _parseTrips(
        _readFile(
          archive,
          'trips.txt',
        ),
      );

      _parseStopTimes(
        _readFile(
          archive,
          'stop_times.txt',
        ),
      );

      _buildIndexes();

      _loaded = true;

      final stationNames = <String>{};

      for (final stop in _stops) {
        if (stop.name.trim().isNotEmpty) {
          stationNames.add(
            stop.name.trim(),
          );
        }
      }

      print(
        'Rapid Bus GTFS loaded successfully.',
      );

      print(
        'Bus stops: ${_stops.length}',
      );

      print(
        'Bus routes: ${_routes.length}',
      );

      print(
        'Bus trips: ${_trips.length}',
      );

      print(
        'Bus stop times: ${_stopTimes.length}',
      );

      print(
        'Available Rapid Bus stations: '
            '${stationNames.length}',
      );

      print(
        '========================================',
      );
    } catch (e) {
      print(
        'BUS GTFS ERROR: $e',
      );

      rethrow;
    }
  }

  static Future<List<String>> getStations() async {
    await loadData();

    final names = <String>{};

    for (final stop in _stops) {
      if (stop.name.trim().isNotEmpty) {
        names.add(
          stop.name.trim(),
        );
      }
    }

    final result = names.toList();

    result.sort(
          (a, b) => a.toLowerCase().compareTo(
        b.toLowerCase(),
      ),
    );

    print(
      'BusRouteData.getStations(): '
          '${result.length} stations',
    );

    return result;
  }

  static Future<List<BusRouteResult>> findRoutes(
      String from,
      String to,
      ) async {
    await loadData();

    print('========================================');

    print(
      'BUS FROM: $from',
    );

    print(
      'BUS TO: $to',
    );

    final fromStop = _findStop(from);

    final toStop = _findStop(to);

    if (fromStop == null) {
      print(
        'BUS FROM STATION NOT FOUND',
      );

      print(
        '========================================',
      );

      return [];
    }

    if (toStop == null) {
      print(
        'BUS TO STATION NOT FOUND',
      );

      print(
        '========================================',
      );

      return [];
    }

    final fromRoutes =
        _stopRoutes[fromStop.id] ??
            <String>{};

    final toRoutes =
        _stopRoutes[toStop.id] ??
            <String>{};

    print(
      'BUS FROM ROUTES: ${fromRoutes.length}',
    );

    print(
      'BUS TO ROUTES: ${toRoutes.length}',
    );

    final commonRoutes =
    fromRoutes.intersection(
      toRoutes,
    );

    print(
      'COMMON BUS ROUTES: '
          '${commonRoutes.length}',
    );

    final results =
    <BusRouteResult>[];

    for (final routeId in commonRoutes) {
      final route =
      _findRoute(routeId);

      if (route == null) {
        continue;
      }

      final duration =
      _calculateDuration(
        routeId,
        fromStop.id,
        toStop.id,
      );

      final finalDuration =
          duration ?? 20;

      results.add(
        BusRouteResult(
          routeId: route.id,
          lineName:
          _routeName(route),
          from: fromStop.name,
          to: toStop.name,
          duration: finalDuration,
        ),
      );
    }

    results.sort(
          (a, b) => a.duration.compareTo(
        b.duration,
      ),
    );

    print(
      'BUS ROUTES FOUND: '
          '${results.length}',
    );

    for (final result
    in results.take(5)) {
      print(
        'BUS ${result.lineName}: '
            '${result.duration} min',
      );
    }

    print(
      '========================================',
    );

    return results;
  }

  static _BusStop? _findStop(
      String input,
      ) {
    final query =
    _normalise(input);

    if (query.isEmpty) {
      return null;
    }

    for (final stop in _stops) {
      if (_normalise(stop.name) ==
          query) {
        return stop;
      }
    }

    for (final stop in _stops) {
      final name =
      _normalise(stop.name);

      if (name.contains(query) ||
          query.contains(name)) {
        return stop;
      }
    }

    final queryTokens = query
        .split(' ')
        .where(
          (value) =>
      value.isNotEmpty,
    )
        .toSet();

    _BusStop? bestStop;

    int bestScore = 0;

    for (final stop in _stops) {
      final stopTokens =
      _normalise(stop.name)
          .split(' ')
          .where(
            (value) =>
        value.isNotEmpty,
      )
          .toSet();

      final score =
          queryTokens
              .intersection(
            stopTokens,
          )
              .length;

      if (score > bestScore) {
        bestScore = score;
        bestStop = stop;
      }
    }

    return bestStop;
  }

  static int? _calculateDuration(
      String routeId,
      String fromStopId,
      String toStopId,
      ) {
    int? bestDuration;

    for (final trip in _trips) {
      if (trip.routeId != routeId) {
        continue;
      }

      final times =
      _tripStopTimes[trip.tripId];

      if (times == null ||
          times.isEmpty) {
        continue;
      }

      _BusStopTime? fromTime;
      _BusStopTime? toTime;

      for (final time in times) {
        if (time.stopId ==
            fromStopId) {
          fromTime = time;
        }

        if (time.stopId ==
            toStopId) {
          toTime = time;
        }
      }

      if (fromTime == null ||
          toTime == null) {
        continue;
      }

      if (toTime.sequence <=
          fromTime.sequence) {
        continue;
      }

      final start =
      _parseTime(
        fromTime.departureTime.isNotEmpty
            ? fromTime.departureTime
            : fromTime.arrivalTime,
      );

      final end =
      _parseTime(
        toTime.arrivalTime.isNotEmpty
            ? toTime.arrivalTime
            : toTime.departureTime,
      );

      if (start == null ||
          end == null) {
        continue;
      }

      int duration =
          end - start;

      if (duration < 0) {
        duration += 24 * 60;
      }

      if (duration <= 0) {
        continue;
      }

      if (bestDuration == null ||
          duration < bestDuration) {
        bestDuration = duration;
      }
    }

    return bestDuration;
  }

  static String _readFile(
      Archive archive,
      String filename,
      ) {
    final file =
    archive.findFile(filename);

    if (file == null) {
      throw Exception(
        '$filename not found in GTFS archive',
      );
    }

    return utf8.decode(
      file.content as List<int>,
    );
  }

  static void _parseStops(
      String content,
      ) {
    final rows =
    _parseCsv(content);

    if (rows.isEmpty) {
      return;
    }

    final header =
        rows.first;

    final stopIdIndex =
    _columnIndex(
      header,
      'stop_id',
    );

    final stopNameIndex =
    _columnIndex(
      header,
      'stop_name',
    );

    for (int i = 1;
    i < rows.length;
    i++) {
      final row = rows[i];

      if (row.length <=
          stopNameIndex) {
        continue;
      }

      final stopId =
      row[stopIdIndex].trim();

      final stopName =
      row[stopNameIndex].trim();

      if (stopId.isEmpty ||
          stopName.isEmpty) {
        continue;
      }

      _stops.add(
        _BusStop(
          id: stopId,
          name: stopName,
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

    final header =
        rows.first;

    final routeIdIndex =
    _columnIndex(
      header,
      'route_id',
    );

    final shortNameIndex =
    _optionalColumnIndex(
      header,
      'route_short_name',
    );

    final longNameIndex =
    _optionalColumnIndex(
      header,
      'route_long_name',
    );

    for (int i = 1;
    i < rows.length;
    i++) {
      final row = rows[i];

      if (row.length <=
          routeIdIndex) {
        continue;
      }

      final routeId =
      row[routeIdIndex].trim();

      if (routeId.isEmpty) {
        continue;
      }

      String shortName = '';
      String longName = '';

      if (shortNameIndex >= 0 &&
          shortNameIndex <
              row.length) {
        shortName =
            row[shortNameIndex].trim();
      }

      if (longNameIndex >= 0 &&
          longNameIndex <
              row.length) {
        longName =
            row[longNameIndex].trim();
      }

      _routes.add(
        _BusRoute(
          id: routeId,
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

    final header =
        rows.first;

    final routeIdIndex =
    _columnIndex(
      header,
      'route_id',
    );

    final tripIdIndex =
    _columnIndex(
      header,
      'trip_id',
    );

    for (int i = 1;
    i < rows.length;
    i++) {
      final row = rows[i];

      if (row.length <=
          tripIdIndex) {
        continue;
      }

      final routeId =
      row[routeIdIndex].trim();

      final tripId =
      row[tripIdIndex].trim();

      if (routeId.isEmpty ||
          tripId.isEmpty) {
        continue;
      }

      _trips.add(
        _BusTrip(
          routeId: routeId,
          tripId: tripId,
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

    final header =
        rows.first;

    final tripIdIndex =
    _columnIndex(
      header,
      'trip_id',
    );

    final arrivalIndex =
    _columnIndex(
      header,
      'arrival_time',
    );

    final departureIndex =
    _columnIndex(
      header,
      'departure_time',
    );

    final stopIdIndex =
    _columnIndex(
      header,
      'stop_id',
    );

    final sequenceIndex =
    _columnIndex(
      header,
      'stop_sequence',
    );

    for (int i = 1;
    i < rows.length;
    i++) {
      final row = rows[i];

      if (row.length <=
          sequenceIndex) {
        continue;
      }

      final tripId =
      row[tripIdIndex].trim();

      final stopId =
      row[stopIdIndex].trim();

      final arrivalTime =
      row[arrivalIndex].trim();

      final departureTime =
      row[departureIndex].trim();

      final sequence =
      int.tryParse(
        row[sequenceIndex].trim(),
      );

      if (tripId.isEmpty ||
          stopId.isEmpty ||
          sequence == null) {
        continue;
      }

      _stopTimes.add(
        _BusStopTime(
          tripId: tripId,
          stopId: stopId,
          arrivalTime: arrivalTime,
          departureTime:
          departureTime,
          sequence: sequence,
        ),
      );
    }
  }

  static void _buildIndexes() {
    final tripRouteMap =
    <String, String>{};

    for (final trip in _trips) {
      tripRouteMap[trip.tripId] =
          trip.routeId;
    }

    for (final stopTime in _stopTimes) {
      final routeId =
      tripRouteMap[
      stopTime.tripId];

      if (routeId == null) {
        continue;
      }

      _stopRoutes
          .putIfAbsent(
        stopTime.stopId,
            () => <String>{},
      )
          .add(routeId);

      _tripStopTimes
          .putIfAbsent(
        stopTime.tripId,
            () => <_BusStopTime>[],
      )
          .add(stopTime);
    }

    for (final times
    in _tripStopTimes.values) {
      times.sort(
            (a, b) =>
            a.sequence.compareTo(
              b.sequence,
            ),
      );
    }
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

  static String _routeName(
      _BusRoute route,
      ) {
    if (route.shortName.isNotEmpty) {
      return route.shortName;
    }

    if (route.longName.isNotEmpty) {
      return route.longName;
    }

    return route.id;
  }

  static int? _parseTime(
      String value,
      ) {
    final parts =
    value.split(':');

    if (parts.length != 3) {
      return null;
    }

    final hour =
    int.tryParse(parts[0]);

    final minute =
    int.tryParse(parts[1]);

    final second =
    int.tryParse(parts[2]);

    if (hour == null ||
        minute == null ||
        second == null) {
      return null;
    }

    return hour * 60 +
        minute +
        (second / 60).round();
  }

  static String _normalise(
      String value,
      ) {
    var result =
    value.toUpperCase();

    result = result.replaceAll(
      RegExp(r'\([^)]*\)'),
      ' ',
    );

    result = result.replaceAll(
      RegExp(r'\bOPP\b'),
      ' ',
    );

    result = result.replaceAll(
      RegExp(r'\bOPPOSITE\b'),
      ' ',
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

  static List<List<String>> _parseCsv(
      String content,
      ) {
    final lines =
    const LineSplitter()
        .convert(content);

    final result =
    <List<String>>[];

    for (final line in lines) {
      if (line.trim().isEmpty) {
        continue;
      }

      result.add(
        _parseCsvLine(line),
      );
    }

    return result;
  }

  static List<String> _parseCsvLine(
      String line,
      ) {
    final result =
    <String>[];

    final buffer =
    StringBuffer();

    bool insideQuotes = false;

    for (int i = 0;
    i < line.length;
    i++) {
      final char = line[i];

      if (char == '"') {
        insideQuotes =
        !insideQuotes;
      } else if (char == ',' &&
          !insideQuotes) {
        result.add(
          buffer.toString(),
        );

        buffer.clear();
      } else {
        buffer.write(char);
      }
    }

    result.add(
      buffer.toString(),
    );

    return result;
  }

  static int _columnIndex(
      List<String> header,
      String name,
      ) {
    final index =
    _optionalColumnIndex(
      header,
      name,
    );

    if (index == -1) {
      throw Exception(
        '$name column not found',
      );
    }

    return index;
  }

  static int _optionalColumnIndex(
      List<String> header,
      String name,
      ) {
    for (int i = 0;
    i < header.length;
    i++) {
      if (header[i].trim() ==
          name) {
        return i;
      }
    }

    return -1;
  }
}

class BusRouteResult {
  final String routeId;
  final String lineName;
  final String from;
  final String to;
  final int duration;

  const BusRouteResult({
    required this.routeId,
    required this.lineName,
    required this.from,
    required this.to,
    required this.duration,
  });
}

class _BusStop {
  final String id;
  final String name;

  const _BusStop({
    required this.id,
    required this.name,
  });
}

class _BusRoute {
  final String id;
  final String shortName;
  final String longName;

  const _BusRoute({
    required this.id,
    required this.shortName,
    required this.longName,
  });
}

class _BusTrip {
  final String routeId;
  final String tripId;

  const _BusTrip({
    required this.routeId,
    required this.tripId,
  });
}

class _BusStopTime {
  final String tripId;
  final String stopId;
  final String arrivalTime;
  final String departureTime;
  final int sequence;

  const _BusStopTime({
    required this.tripId,
    required this.stopId,
    required this.arrivalTime,
    required this.departureTime,
    required this.sequence,
  });
}