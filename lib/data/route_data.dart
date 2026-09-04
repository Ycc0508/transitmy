import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:http/http.dart' as http;

class RouteData {
  static const String _gtfsUrl =
      'https://api.data.gov.my/gtfs-static/prasarana?category=rapid-rail-kl';

  static bool _loaded = false;

  static final Map<String, _Stop> _stops = {};
  static final Map<String, _Route> _routes = {};
  static final Map<String, _Trip> _trips = {};
  static final List<_StopTime> _stopTimes = [];

  // stop name -> route IDs
  static final Map<String, Set<String>> _stationRoutes = {};

  // route ID -> ordered stop IDs
  static final Map<String, List<String>> _routeStations = {};

  // route ID -> stop ID -> earliest known arrival time
  static final Map<String, Map<String, String>> _routeStopTimes = {};

  // route ID -> set of station names
  static final Map<String, Set<String>> _routeStationNames = {};

  // ============================================================
  // LOAD GOVERNMENT GTFS DATA
  // ============================================================

  static Future<void> loadData() async {
    if (_loaded) {
      return;
    }

    print('========================================');
    print('Route Service');
    print('Loading Government GTFS Static Data...');
    print('========================================');

    try {
      final response = await http.get(Uri.parse(_gtfsUrl));

      print('GTFS STATUS: ${response.statusCode}');

      if (response.statusCode != 200) {
        throw Exception(
          'Failed to download GTFS data: ${response.statusCode}',
        );
      }

      final archive = ZipDecoder().decodeBytes(response.bodyBytes);

      _parseStops(_readFile(archive, 'stops.txt'));
      _parseRoutes(_readFile(archive, 'routes.txt'));
      _parseTrips(_readFile(archive, 'trips.txt'));
      _parseStopTimes(_readFile(archive, 'stop_times.txt'));

      _buildStationRoutes();
      _buildRouteNetworks();

      _loaded = true;

      print('Government GTFS loaded successfully.');
      print('Stops: ${_stops.length}');
      print('Routes: ${_routes.length}');
      print('Trips: ${_trips.length}');
      print('Stop times: ${_stopTimes.length}');
      print('Station routes: ${_stationRoutes.length}');
      print('Route networks: ${_routeStations.length}');
    } catch (e) {
      print('GTFS ERROR: $e');
      rethrow;
    }
  }

  // ============================================================
  // GET GTFS STATIONS
  // ============================================================

  static Future<List<String>> getStations() async {
    await loadData();

    final stationNames = _stops.values
        .map((stop) => stop.name.trim())
        .where((name) => name.isNotEmpty)
        .toSet()
        .toList();

    stationNames.sort();

    print('Available GTFS stations: ${stationNames.length}');

    return stationNames;
  }

  // ============================================================
  // READ FILE FROM ZIP
  // ============================================================

  static String _readFile(
      Archive archive,
      String fileName,
      ) {
    final file = archive.findFile(fileName);

    if (file == null) {
      throw Exception('$fileName not found in GTFS ZIP');
    }

    return utf8.decode(file.content as List<int>);
  }

  // ============================================================
  // PARSE STOPS
  // ============================================================

  static void _parseStops(String csv) {
    final rows = _parseCsv(csv);

    if (rows.isEmpty) {
      throw Exception('stops.txt is empty');
    }

    final header = rows.first;

    print('GTFS STOPS HEADER: $header');

    final stopIdIndex = _indexOf(
      header,
      'stop_id',
    );

    final stopNameIndex = _indexOf(
      header,
      'stop_name',
    );

    if (stopIdIndex == -1 || stopNameIndex == -1) {
      throw Exception(
        'stop_id or stop_name not found',
      );
    }

    for (final row in rows.skip(1)) {
      if (row.length <= stopNameIndex) {
        continue;
      }

      final id = row[stopIdIndex].trim();
      final name = row[stopNameIndex].trim();

      if (id.isEmpty || name.isEmpty) {
        continue;
      }

      final stop = _Stop(
        id: id,
        name: name,
      );

      _stops[id] = stop;
    }

    // Diagnostic output
    final checkNames = [
      'GOMBAK',
      'MASJID JAMEK',
      'PASAR SENI',
      'DANG WANGI',
      'BUKIT BINTANG',
      'BUKIT NANAS',
    ];

    print('--------------------------------');

    for (final stop in _stops.values) {
      final upperName = stop.name.toUpperCase();

      if (checkNames.any(
            (name) => upperName.contains(name),
      )) {
        print('STOP NAME: ${stop.name}');
        print('STOP ID: ${stop.id}');
        print('--------------------------------');
      }
    }
  }

  // ============================================================
  // PARSE ROUTES
  // ============================================================

  static void _parseRoutes(String csv) {
    final rows = _parseCsv(csv);

    if (rows.isEmpty) {
      return;
    }

    final header = rows.first;

    final routeIdIndex = _indexOf(
      header,
      'route_id',
    );

    final shortNameIndex = _indexOf(
      header,
      'route_short_name',
    );

    final longNameIndex = _indexOf(
      header,
      'route_long_name',
    );

    for (final row in rows.skip(1)) {
      if (routeIdIndex == -1 ||
          row.length <= routeIdIndex) {
        continue;
      }

      final routeId = row[routeIdIndex].trim();

      if (routeId.isEmpty) {
        continue;
      }

      final shortName =
      shortNameIndex != -1 &&
          row.length > shortNameIndex
          ? row[shortNameIndex].trim()
          : '';

      final longName =
      longNameIndex != -1 &&
          row.length > longNameIndex
          ? row[longNameIndex].trim()
          : '';

      _routes[routeId] = _Route(
        id: routeId,
        shortName: shortName,
        longName: longName,
      );
    }
  }

  // ============================================================
  // PARSE TRIPS
  // ============================================================

  static void _parseTrips(String csv) {
    final rows = _parseCsv(csv);

    if (rows.isEmpty) {
      return;
    }

    final header = rows.first;

    final routeIdIndex = _indexOf(
      header,
      'route_id',
    );

    final tripIdIndex = _indexOf(
      header,
      'trip_id',
    );

    for (final row in rows.skip(1)) {
      if (routeIdIndex == -1 ||
          tripIdIndex == -1 ||
          row.length <= tripIdIndex) {
        continue;
      }

      final routeId = row[routeIdIndex].trim();
      final tripId = row[tripIdIndex].trim();

      if (routeId.isEmpty || tripId.isEmpty) {
        continue;
      }

      _trips[tripId] = _Trip(
        id: tripId,
        routeId: routeId,
      );
    }
  }

  // ============================================================
  // PARSE STOP TIMES
  // ============================================================

  static void _parseStopTimes(String csv) {
    final rows = _parseCsv(csv);

    if (rows.isEmpty) {
      return;
    }

    final header = rows.first;

    final tripIdIndex = _indexOf(
      header,
      'trip_id',
    );

    final stopIdIndex = _indexOf(
      header,
      'stop_id',
    );

    final arrivalIndex = _indexOf(
      header,
      'arrival_time',
    );

    final departureIndex = _indexOf(
      header,
      'departure_time',
    );

    final sequenceIndex = _indexOf(
      header,
      'stop_sequence',
    );

    for (final row in rows.skip(1)) {
      if (tripIdIndex == -1 ||
          stopIdIndex == -1 ||
          row.length <= stopIdIndex) {
        continue;
      }

      final tripId = row[tripIdIndex].trim();
      final stopId = row[stopIdIndex].trim();

      if (tripId.isEmpty || stopId.isEmpty) {
        continue;
      }

      final arrival =
      arrivalIndex != -1 &&
          row.length > arrivalIndex
          ? row[arrivalIndex].trim()
          : '';

      final departure =
      departureIndex != -1 &&
          row.length > departureIndex
          ? row[departureIndex].trim()
          : '';

      final sequence =
      sequenceIndex != -1 &&
          row.length > sequenceIndex
          ? int.tryParse(
        row[sequenceIndex].trim(),
      ) ??
          0
          : 0;

      _stopTimes.add(
        _StopTime(
          tripId: tripId,
          stopId: stopId,
          arrivalTime: arrival,
          departureTime: departure,
          sequence: sequence,
        ),
      );
    }
  }

  // ============================================================
  // BUILD STATION -> ROUTES
  // ============================================================

  static void _buildStationRoutes() {
    _stationRoutes.clear();

    for (final stop in _stops.values) {
      final routeId = _findRouteIdForStop(
        stop.id,
      );

      if (routeId == null) {
        continue;
      }

      final stationName =
      _normaliseStationName(
        stop.name,
      );

      _stationRoutes.putIfAbsent(
        stationName,
            () => <String>{},
      );

      _stationRoutes[stationName]!.add(
        routeId,
      );
    }

    // Because one stop may belong to different routes,
    // also inspect all stop times.
    for (final stopTime in _stopTimes) {
      final stop = _stops[stopTime.stopId];
      final trip = _trips[stopTime.tripId];

      if (stop == null || trip == null) {
        continue;
      }

      final stationName =
      _normaliseStationName(
        stop.name,
      );

      _stationRoutes.putIfAbsent(
        stationName,
            () => <String>{},
      );

      _stationRoutes[stationName]!.add(
        trip.routeId,
      );
    }
  }

  // ============================================================
  // BUILD ROUTE NETWORK
  // ============================================================

  static void _buildRouteNetworks() {
    _routeStations.clear();
    _routeStopTimes.clear();
    _routeStationNames.clear();

    final Map<String, List<_StopTime>>
    tripStopTimes = {};

    for (final stopTime in _stopTimes) {
      tripStopTimes
          .putIfAbsent(
        stopTime.tripId,
            () => [],
      )
          .add(stopTime);
    }

    for (final tripEntry
    in tripStopTimes.entries) {
      final trip = _trips[tripEntry.key];

      if (trip == null) {
        continue;
      }

      final routeId = trip.routeId;

      final times =
      tripEntry.value.toList()
        ..sort(
              (a, b) => a.sequence.compareTo(
            b.sequence,
          ),
        );

      _routeStations.putIfAbsent(
        routeId,
            () => [],
      );

      _routeStopTimes.putIfAbsent(
        routeId,
            () => {},
      );

      _routeStationNames.putIfAbsent(
        routeId,
            () => {},
      );

      for (final stopTime in times) {
        final stop = _stops[stopTime.stopId];

        if (stop == null) {
          continue;
        }

        if (!_routeStations[routeId]!
            .contains(stop.id)) {
          _routeStations[routeId]!
              .add(stop.id);
        }

        final stationName =
        _normaliseStationName(
          stop.name,
        );

        _routeStationNames[routeId]!
            .add(stationName);

        final existingTime =
        _routeStopTimes[routeId]![
        stop.id];

        if (existingTime == null ||
            _timeToMinutes(
              stopTime.arrivalTime,
            ) <
                _timeToMinutes(
                  existingTime,
                )) {
          _routeStopTimes[routeId]![
          stop.id] =
              stopTime.arrivalTime;
        }
      }
    }
  }

  // ============================================================
  // FIND ROUTES
  // ============================================================

  static Future<List<RouteResult>> findRoutes(
      String from,
      String to,
      ) async {
    await loadData();

    print('========================================');
    print('FROM INPUT: $from');
    print('TO INPUT: $to');

    final fromStop = _findStop(from);
    final toStop = _findStop(to);

    if (fromStop == null) {
      print('FROM STATION NOT FOUND');
      return [];
    }

    if (toStop == null) {
      print('TO STATION NOT FOUND');
      return [];
    }

    print(
      'FROM STATION: ${fromStop.name} (${fromStop.id})',
    );

    print(
      'TO STATION: ${toStop.name} (${toStop.id})',
    );

    final fromName =
    _normaliseStationName(
      fromStop.name,
    );

    final toName =
    _normaliseStationName(
      toStop.name,
    );

    final fromRoutes =
        _stationRoutes[fromName] ??
            <String>{};

    final toRoutes =
        _stationRoutes[toName] ??
            <String>{};

    print('FROM ROUTES: $fromRoutes');
    print('TO ROUTES: $toRoutes');

    // ----------------------------------------------------------
    // DIRECT ROUTE
    // ----------------------------------------------------------

    final directRoutes =
    fromRoutes.intersection(
      toRoutes,
    );

    if (directRoutes.isNotEmpty) {
      print('DIRECT ROUTE FOUND');

      final results = <RouteResult>[];

      for (final routeId
      in directRoutes) {
        final duration =
        _calculateDirectDuration(
          routeId,
          fromStop.id,
          toStop.id,
        );

        results.add(
          RouteResult(
            routeIds: [routeId],
            stationNames: [
              fromStop.name,
              toStop.name,
            ],
            transfers: 0,
            duration: duration,
          ),
        );
      }

      return results;
    }

    // ----------------------------------------------------------
    // TRANSFER ROUTE
    // ----------------------------------------------------------

    print('No direct route.');
    print(
      'Searching for routes with up to 2 transfers...',
    );

    final transferResult =
    _findTransferRoute(
      fromName,
      toName,
      fromRoutes,
      toRoutes,
    );

    if (transferResult == null) {
      print(
        'NO ROUTE FOUND WITHIN 2 TRANSFERS',
      );

      return [];
    }

    print('TRANSFER ROUTE FOUND');

    print(
      'Routes: ${transferResult.routeIds}',
    );

    print(
      'Stations: ${transferResult.stationNames}',
    );

    print(
      'Transfers: ${transferResult.transfers}',
    );

    return [transferResult];
  }

  // ============================================================
  // TRANSFER BFS
  // ============================================================

  static RouteResult? _findTransferRoute(
      String fromName,
      String toName,
      Set<String> fromRoutes,
      Set<String> toRoutes,
      ) {
    final queue = <_SearchNode>[];

    final visited = <String>{};

    // Start from every route serving the origin.
    for (final routeId in fromRoutes) {
      queue.add(
        _SearchNode(
          routeIds: [routeId],
          stationNames: [fromName],
          currentStation: fromName,
          transfers: 0,
        ),
      );
    }

    while (queue.isNotEmpty) {
      final current = queue.removeAt(0);

      final currentRoute =
          current.routeIds.last;

      final visitKey =
          '$currentRoute|${current.currentStation}|${current.transfers}';

      if (visited.contains(visitKey)) {
        continue;
      }

      visited.add(visitKey);

      // --------------------------------------------------------
      // Can current route reach destination?
      // --------------------------------------------------------

      if (_routeStationNames[
      currentRoute]
          ?.contains(toName) ??
          false) {
        return RouteResult(
          routeIds: current.routeIds,
          stationNames: [
            ...current.stationNames,
            toName,
          ],
          transfers: current.transfers,
          duration: _estimateTransferDuration(
            current.routeIds,
            current.transfers,
          ),
        );
      }

      // Maximum 2 transfers.
      if (current.transfers >= 2) {
        continue;
      }

      // --------------------------------------------------------
      // Find interchange stations
      // on current route.
      // --------------------------------------------------------

      final currentStations =
          _routeStationNames[
          currentRoute] ??
              {};

      for (final stationName
      in currentStations) {
        if (stationName ==
            current.currentStation) {
          continue;
        }

        final stationRoutes =
            _stationRoutes[
            stationName] ??
                {};

        for (final nextRoute
        in stationRoutes) {
          if (nextRoute ==
              currentRoute) {
            continue;
          }

          if (current.routeIds
              .contains(nextRoute)) {
            continue;
          }

          final newRouteIds = [
            ...current.routeIds,
            nextRoute,
          ];

          final newStationNames = [
            ...current.stationNames,
            stationName,
          ];

          queue.add(
            _SearchNode(
              routeIds: newRouteIds,
              stationNames:
              newStationNames,
              currentStation:
              stationName,
              transfers:
              current.transfers + 1,
            ),
          );
        }
      }
    }

    return null;
  }

  // ============================================================
  // FIND STOP
  // ============================================================

  static _Stop? _findStop(
      String input,
      ) {
    final query =
    _normaliseStationName(input);

    // Exact match first.
    for (final stop in _stops.values) {
      if (_normaliseStationName(
        stop.name,
      ) ==
          query) {
        return stop;
      }
    }

    // Contains match.
    for (final stop in _stops.values) {
      final name =
      _normaliseStationName(
        stop.name,
      );

      if (name.contains(query) ||
          query.contains(name)) {
        return stop;
      }
    }

    return null;
  }

  // ============================================================
  // NORMALISE STATION NAME
  // ============================================================

  static String _normaliseStationName(
      String name,
      ) {
    return name
        .toUpperCase()
        .replaceAll(
      RegExp(r'\(.*?\)'),
      '',
    )
        .replaceAll(
      RegExp(r'[^A-Z0-9 ]'),
      ' ',
    )
        .replaceAll(
      RegExp(r'\s+'),
      ' ',
    )
        .trim();
  }

  // ============================================================
  // FIND ROUTE ID FOR STOP
  // ============================================================

  static String? _findRouteIdForStop(
      String stopId,
      ) {
    for (final stopTime in _stopTimes) {
      if (stopTime.stopId != stopId) {
        continue;
      }

      final trip = _trips[stopTime.tripId];

      if (trip != null) {
        return trip.routeId;
      }
    }

    return null;
  }

  // ============================================================
  // DIRECT ROUTE DURATION
  // ============================================================

  static int _calculateDirectDuration(
      String routeId,
      String fromStopId,
      String toStopId,
      ) {
    final times =
    _routeStopTimes[routeId];

    if (times == null) {
      return 10;
    }

    final fromTime =
    times[fromStopId];

    final toTime =
    times[toStopId];

    if (fromTime == null ||
        toTime == null) {
      return 10;
    }

    final fromMinutes =
    _timeToMinutes(fromTime);

    final toMinutes =
    _timeToMinutes(toTime);

    if (fromMinutes >= 0 &&
        toMinutes >= 0 &&
        toMinutes > fromMinutes) {
      return toMinutes - fromMinutes;
    }

    return 10;
  }

  // ============================================================
  // TRANSFER DURATION
  // ============================================================

  static int _estimateTransferDuration(
      List<String> routeIds,
      int transfers,
      ) {
    final baseDuration =
        routeIds.length * 10;

    final transferTime =
        transfers * 5;

    return baseDuration + transferTime;
  }

  // ============================================================
  // TIME
  // ============================================================

  static int _timeToMinutes(
      String time,
      ) {
    if (time.isEmpty) {
      return -1;
    }

    final parts = time.split(':');

    if (parts.length < 2) {
      return -1;
    }

    final hour =
    int.tryParse(parts[0]);

    final minute =
    int.tryParse(parts[1]);

    if (hour == null ||
        minute == null) {
      return -1;
    }

    return hour * 60 + minute;
  }

  // ============================================================
  // CSV PARSER
  // ============================================================

  static List<List<String>> _parseCsv(
      String csv,
      ) {
    final rows = <List<String>>[];

    final lines =
    const LineSplitter().convert(csv);

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
        if (insideQuotes &&
            i + 1 < line.length &&
            line[i + 1] == '"') {
          buffer.write('"');
          i++;
        } else {
          insideQuotes =
          !insideQuotes;
        }
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

  static int _indexOf(
      List<String> header,
      String name,
      ) {
    return header.indexWhere(
          (value) =>
      value.trim().toLowerCase() ==
          name.toLowerCase(),
    );
  }
}

// ================================================================
// PUBLIC RESULT MODEL
// ================================================================

class RouteResult {
  final List<String> routeIds;
  final List<String> stationNames;
  final int transfers;
  final int duration;

  const RouteResult({
    required this.routeIds,
    required this.stationNames,
    required this.transfers,
    required this.duration,
  });

  String get lineName {
    if (routeIds.isEmpty) {
      return '';
    }

    return routeIds.join(' → ');
  }
}

// ================================================================
// INTERNAL MODELS
// ================================================================

class _Stop {
  final String id;
  final String name;

  const _Stop({
    required this.id,
    required this.name,
  });
}

class _Route {
  final String id;
  final String shortName;
  final String longName;

  const _Route({
    required this.id,
    required this.shortName,
    required this.longName,
  });
}

class _Trip {
  final String id;
  final String routeId;

  const _Trip({
    required this.id,
    required this.routeId,
  });
}

class _StopTime {
  final String tripId;
  final String stopId;
  final String arrivalTime;
  final String departureTime;
  final int sequence;

  const _StopTime({
    required this.tripId,
    required this.stopId,
    required this.arrivalTime,
    required this.departureTime,
    required this.sequence,
  });
}

class _SearchNode {
  final List<String> routeIds;
  final List<String> stationNames;
  final String currentStation;
  final int transfers;

  const _SearchNode({
    required this.routeIds,
    required this.stationNames,
    required this.currentStation,
    required this.transfers,
  });
}