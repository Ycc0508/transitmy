import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const TransportFinderApp());
}

// ============================================================
// APP
// ============================================================

class TransportFinderApp extends StatelessWidget {
  const TransportFinderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Nearby Transport',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.blue,
      ),
      home: const TransportHomePage(),
    );
  }
}

// ============================================================
// TRANSPORT STOP
// ============================================================

class TransportStop {
  final String id;
  final String name;
  final double latitude;
  final double longitude;

  final String? parentStation;
  final String? description;
  final String? officialAddress;

  final Set<String> routeIds;
  final List<RouteInfo> routes;

  double? distanceMeters;
  String? address;

  TransportStop({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.parentStation,
    this.description,
    this.officialAddress,
    Set<String>? routeIds,
    List<RouteInfo>? routes,
    this.distanceMeters,
    this.address,
  })  : routeIds = routeIds ?? <String>{},
        routes = routes ?? <RouteInfo>[];

  TransportStop copyWith({
    double? distanceMeters,
    String? address,
    List<RouteInfo>? routes,
  }) {
    return TransportStop(
      id: id,
      name: name,
      latitude: latitude,
      longitude: longitude,
      parentStation: parentStation,
      description: description,
      officialAddress: officialAddress,
      routeIds: routeIds,
      routes: routes ?? this.routes,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      address: address ?? this.address,
    );
  }
}

// ============================================================
// ROUTE INFO
// ============================================================

class RouteInfo {
  final String id;
  final String shortName;
  final String longName;
  final String routeType;

  RouteInfo({
    required this.id,
    required this.shortName,
    required this.longName,
    required this.routeType,
  });

  String get displayName {
    if (longName.isNotEmpty && shortName.isNotEmpty) {
      return '$longName ($shortName)';
    }

    if (longName.isNotEmpty) {
      return longName;
    }

    if (shortName.isNotEmpty) {
      return shortName;
    }

    return id;
  }

  String get transportType {
    final text =
        '${shortName.toLowerCase()} ${longName.toLowerCase()} ${id.toLowerCase()}';

    if (text.contains('monorail') || text.contains('mono')) {
      return 'Monorail';
    }

    if (text.contains('mrt') ||
        text.contains('kajang') ||
        text.contains('putrajaya') ||
        text.contains('mass rapid transit')) {
      return 'MRT';
    }

    if (text.contains('lrt') ||
        text.contains('light rail') ||
        text.contains('kelana jaya') ||
        text.contains('ampang') ||
        text.contains('sri petaling') ||
        text.contains('shah alam')) {
      return 'LRT';
    }

    if (text.contains('bus')) {
      return 'Bus';
    }

    return routeType;
  }
}

// ============================================================
// GTFS SERVICE
// ============================================================

class GtfsService {
  static const String rapidBusUrl =
      'https://api.data.gov.my/gtfs-static/prasarana?category=rapid-bus-kl';

  static const String rapidRailUrl =
      'https://api.data.gov.my/gtfs-static/prasarana?category=rapid-rail-kl';

  Future<List<TransportStop>> loadAllStops() async {
    final Map<String, TransportStop> allStops = {};
    final Map<String, RouteInfo> allRoutes = {};

    // --------------------------------------------------------
    // Load Rapid Bus
    // --------------------------------------------------------

    try {
      final busZip = await _downloadZip(rapidBusUrl);

      if (busZip != null) {
        _parseStops(
          busZip,
          allStops,
        );

        _parseRoutes(
          busZip,
          allRoutes,
        );

        _parseStopRoutes(
          busZip,
          allStops,
        );
      }
    } catch (e) {
      debugPrint('Rapid Bus GTFS error: $e');
    }

    // --------------------------------------------------------
    // Load Rapid Rail
    // --------------------------------------------------------

    try {
      final railZip = await _downloadZip(rapidRailUrl);

      if (railZip != null) {
        _parseStops(
          railZip,
          allStops,
        );

        _parseRoutes(
          railZip,
          allRoutes,
        );

        _parseStopRoutes(
          railZip,
          allStops,
        );
      }
    } catch (e) {
      debugPrint('Rapid Rail GTFS error: $e');
    }

    // --------------------------------------------------------
    // Match routes to stops
    // --------------------------------------------------------

    for (final stop in allStops.values) {
      final matchedRoutes = <RouteInfo>[];

      for (final routeId in stop.routeIds) {
        final route = allRoutes[routeId];

        if (route != null) {
          matchedRoutes.add(route);
        }
      }

      stop.routes
        ..clear()
        ..addAll(matchedRoutes);
    }

    // --------------------------------------------------------
    // Parent station aggregation
    // --------------------------------------------------------

    _mergeParentStationRoutes(
      allStops,
    );

    return allStops.values.toList();
  }

  // ==========================================================
  // DOWNLOAD ZIP
  // ==========================================================

  Future<Archive?> _downloadZip(String url) async {
    final response = await http.get(
      Uri.parse(url),
    );

    if (response.statusCode != 200) {
      debugPrint(
        'GTFS HTTP ${response.statusCode}: $url',
      );
      return null;
    }

    return ZipDecoder().decodeBytes(
      response.bodyBytes,
    );
  }

  // ==========================================================
  // FIND FILE
  // ==========================================================

  ArchiveFile? _findFile(
      Archive archive,
      String filename,
      ) {
    for (final file in archive.files) {
      final cleanName = file.name
          .replaceAll('\\', '/')
          .split('/')
          .last
          .toLowerCase();

      if (cleanName == filename.toLowerCase()) {
        return file;
      }
    }

    return null;
  }

  // ==========================================================
  // READ FILE
  // ==========================================================

  String? _readFile(
      Archive archive,
      String filename,
      ) {
    final file = _findFile(
      archive,
      filename,
    );

    if (file == null) {
      return null;
    }

    return utf8.decode(
      file.content as List<int>,
      allowMalformed: true,
    );
  }

  // ==========================================================
  // PARSE STOPS
  // ==========================================================

  void _parseStops(
      Archive archive,
      Map<String, TransportStop> stops,
      ) {
    final content = _readFile(
      archive,
      'stops.txt',
    );

    if (content == null) {
      return;
    }

    final rows = _parseCsv(
      content,
    );

    if (rows.isEmpty) {
      return;
    }

    final header = rows.first;

    final idIndex = _columnIndex(
      header,
      ['stop_id'],
    );

    final nameIndex = _columnIndex(
      header,
      ['stop_name'],
    );

    final latIndex = _columnIndex(
      header,
      ['stop_lat'],
    );

    final lonIndex = _columnIndex(
      header,
      ['stop_lon'],
    );

    final parentIndex = _columnIndex(
      header,
      ['parent_station'],
    );

    final descIndex = _columnIndex(
      header,
      ['stop_desc'],
    );

    final addressIndex = _columnIndex(
      header,
      [
        'stop_address',
        'address',
      ],
    );

    if (idIndex == -1 ||
        nameIndex == -1 ||
        latIndex == -1 ||
        lonIndex == -1) {
      return;
    }

    for (int i = 1; i < rows.length; i++) {
      final row = rows[i];

      if (row.length <= max(
        max(idIndex, nameIndex),
        max(latIndex, lonIndex),
      )) {
        continue;
      }

      final id = row[idIndex].trim();
      final name = row[nameIndex].trim();

      final lat = double.tryParse(
        row[latIndex].trim(),
      );

      final lon = double.tryParse(
        row[lonIndex].trim(),
      );

      if (id.isEmpty ||
          name.isEmpty ||
          lat == null ||
          lon == null) {
        continue;
      }

      if (lat.abs() > 90 || lon.abs() > 180) {
        continue;
      }

      String? parent;
      String? description;
      String? officialAddress;

      if (parentIndex >= 0 && parentIndex < row.length) {
        final value = row[parentIndex].trim();

        if (value.isNotEmpty) {
          parent = value;
        }
      }

      if (descIndex >= 0 && descIndex < row.length) {
        final value = row[descIndex].trim();

        if (value.isNotEmpty) {
          description = value;
        }
      }

      if (addressIndex >= 0 && addressIndex < row.length) {
        final value = row[addressIndex].trim();

        if (value.isNotEmpty) {
          officialAddress = value;
        }
      }

      stops.putIfAbsent(
        id,
            () => TransportStop(
          id: id,
          name: name,
          latitude: lat,
          longitude: lon,
          parentStation: parent,
          description: description,
          officialAddress: officialAddress,
        ),
      );
    }
  }

  // ==========================================================
  // PARSE ROUTES
  // ==========================================================

  void _parseRoutes(
      Archive archive,
      Map<String, RouteInfo> routes,
      ) {
    final content = _readFile(
      archive,
      'routes.txt',
    );

    if (content == null) {
      return;
    }

    final rows = _parseCsv(
      content,
    );

    if (rows.isEmpty) {
      return;
    }

    final header = rows.first;

    final idIndex = _columnIndex(
      header,
      ['route_id'],
    );

    final shortIndex = _columnIndex(
      header,
      ['route_short_name'],
    );

    final longIndex = _columnIndex(
      header,
      ['route_long_name'],
    );

    final typeIndex = _columnIndex(
      header,
      ['route_type'],
    );

    if (idIndex == -1) {
      return;
    }

    for (int i = 1; i < rows.length; i++) {
      final row = rows[i];

      if (idIndex >= row.length) {
        continue;
      }

      final id = row[idIndex].trim();

      if (id.isEmpty) {
        continue;
      }

      String shortName = '';
      String longName = '';
      String type = '';

      if (shortIndex >= 0 && shortIndex < row.length) {
        shortName = row[shortIndex].trim();
      }

      if (longIndex >= 0 && longIndex < row.length) {
        longName = row[longIndex].trim();
      }

      if (typeIndex >= 0 && typeIndex < row.length) {
        type = row[typeIndex].trim();
      }

      routes[id] = RouteInfo(
        id: id,
        shortName: shortName,
        longName: longName,
        routeType: type,
      );
    }
  }

  // ==========================================================
  // STOP -> ROUTE
  // ==========================================================

  void _parseStopRoutes(
      Archive archive,
      Map<String, TransportStop> stops,
      ) {
    final stopTimesContent = _readFile(
      archive,
      'stop_times.txt',
    );

    final tripsContent = _readFile(
      archive,
      'trips.txt',
    );

    if (stopTimesContent == null ||
        tripsContent == null) {
      return;
    }

    final tripRows = _parseCsv(
      tripsContent,
    );

    if (tripRows.isEmpty) {
      return;
    }

    final tripHeader = tripRows.first;

    final tripIdIndex = _columnIndex(
      tripHeader,
      ['trip_id'],
    );

    final routeIdIndex = _columnIndex(
      tripHeader,
      ['route_id'],
    );

    if (tripIdIndex == -1 ||
        routeIdIndex == -1) {
      return;
    }

    final Map<String, String> tripToRoute = {};

    for (int i = 1; i < tripRows.length; i++) {
      final row = tripRows[i];

      if (tripIdIndex >= row.length ||
          routeIdIndex >= row.length) {
        continue;
      }

      final tripId = row[tripIdIndex].trim();
      final routeId = row[routeIdIndex].trim();

      if (tripId.isNotEmpty &&
          routeId.isNotEmpty) {
        tripToRoute[tripId] = routeId;
      }
    }

    final stopRows = _parseCsv(
      stopTimesContent,
    );

    if (stopRows.isEmpty) {
      return;
    }

    final stopHeader = stopRows.first;

    final stTripIndex = _columnIndex(
      stopHeader,
      ['trip_id'],
    );

    final stStopIndex = _columnIndex(
      stopHeader,
      ['stop_id'],
    );

    if (stTripIndex == -1 ||
        stStopIndex == -1) {
      return;
    }

    for (int i = 1; i < stopRows.length; i++) {
      final row = stopRows[i];

      if (stTripIndex >= row.length ||
          stStopIndex >= row.length) {
        continue;
      }

      final tripId = row[stTripIndex].trim();
      final stopId = row[stStopIndex].trim();

      final routeId = tripToRoute[tripId];

      if (routeId == null) {
        continue;
      }

      final stop = stops[stopId];

      if (stop != null) {
        stop.routeIds.add(
          routeId,
        );
      }
    }
  }

  // ==========================================================
  // PARENT STATION
  // ==========================================================

  void _mergeParentStationRoutes(
      Map<String, TransportStop> stops,
      ) {
    final Map<String, Set<String>> stationRoutes = {};

    for (final stop in stops.values) {
      final parent =
          stop.parentStation ?? stop.id;

      stationRoutes.putIfAbsent(
        parent,
            () => <String>{},
      );

      stationRoutes[parent]!.addAll(
        stop.routeIds,
      );
    }

    for (final stop in stops.values) {
      final parent =
          stop.parentStation ?? stop.id;

      final inherited =
      stationRoutes[parent];

      if (inherited != null) {
        stop.routeIds.addAll(
          inherited,
        );
      }
    }
  }

  // ==========================================================
  // CSV PARSER
  // ==========================================================

  List<List<String>> _parseCsv(
      String text,
      ) {
    final List<List<String>> result = [];

    final List<String> row = [];
    final StringBuffer field = StringBuffer();

    bool inQuotes = false;

    for (int i = 0; i < text.length; i++) {
      final char = text[i];

      if (char == '"') {
        if (inQuotes &&
            i + 1 < text.length &&
            text[i + 1] == '"') {
          field.write('"');
          i++;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (char == ',' && !inQuotes) {
        row.add(
          field.toString(),
        );
        field.clear();
      } else if ((char == '\n' || char == '\r') &&
          !inQuotes) {
        if (char == '\r' &&
            i + 1 < text.length &&
            text[i + 1] == '\n') {
          i++;
        }

        row.add(
          field.toString(),
        );

        field.clear();

        if (row.any(
              (e) => e.trim().isNotEmpty,
        )) {
          result.add(
            List<String>.from(row),
          );
        }

        row.clear();
      } else {
        field.write(char);
      }
    }

    if (field.isNotEmpty || row.isNotEmpty) {
      row.add(
        field.toString(),
      );

      if (row.any(
            (e) => e.trim().isNotEmpty,
      )) {
        result.add(
          List<String>.from(row),
        );
      }
    }

    return result;
  }

  int _columnIndex(
      List<String> header,
      List<String> names,
      ) {
    for (final name in names) {
      final index = header.indexWhere(
            (value) =>
        value.trim().toLowerCase() ==
            name.toLowerCase(),
      );

      if (index != -1) {
        return index;
      }
    }

    return -1;
  }
}

// ============================================================
// ADDRESS SERVICE
// ============================================================

class AddressService {
  static final Map<String, String> _cache = {};

  static Future<String?> reverseGeocode(
      double latitude,
      double longitude,
      ) async {
    final key =
        '${latitude.toStringAsFixed(6)},'
        '${longitude.toStringAsFixed(6)}';

    if (_cache.containsKey(key)) {
      return _cache[key];
    }

    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse'
            '?format=jsonv2'
            '&lat=$latitude'
            '&lon=$longitude'
            '&zoom=18'
            '&addressdetails=1',
      );

      final response = await http.get(
        uri,
        headers: const {
          'User-Agent':
          'NearbyTransportFlutterApp/1.0',
          'Accept':
          'application/json',
        },
      );

      if (response.statusCode != 200) {
        debugPrint(
          'Reverse geocoding HTTP '
              '${response.statusCode}',
        );
        return null;
      }

      final data =
      jsonDecode(response.body);

      final displayName =
      data['display_name'];

      if (displayName is String &&
          displayName.trim().isNotEmpty) {
        final address =
        displayName.trim();

        _cache[key] = address;

        return address;
      }
    } catch (e) {
      debugPrint(
        'Reverse geocoding error: $e',
      );
    }

    return null;
  }
}

// ============================================================
// HOME PAGE
// ============================================================

class TransportHomePage extends StatefulWidget {
  const TransportHomePage({
    super.key,
  });

  @override
  State<TransportHomePage> createState() =>
      _TransportHomePageState();
}

class _TransportHomePageState
    extends State<TransportHomePage> {
  final GtfsService _service =
  GtfsService();

  final TextEditingController
  _searchController =
  TextEditingController();

  List<TransportStop> _allStops = [];
  List<TransportStop> _filteredStops = [];

  Position? _currentPosition;

  bool _loading = true;
  bool _locationLoading = false;
  bool _addressLoading = false;

  String? _errorMessage;
  String? _locationMessage;

  String _selectedType = 'All';

  bool _nearestFirst = true;

  final Set<String> _favourites = {};

  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();

    _searchController.addListener(
      _onSearchChanged,
    );

    _loadData();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  // ==========================================================
  // LOAD DATA
  // ==========================================================

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final stops =
      await _service.loadAllStops();

      if (!mounted) {
        return;
      }

      setState(() {
        _allStops = stops;
        _loading = false;
      });

      _applyFilters();

      // Automatically request GPS.
      await _getCurrentLocation();

      if (!mounted) {
        return;
      }

      _applyFilters();

      // Only reverse geocode a small number
      // of visible results.
      await _loadVisibleAddresses();
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
        _errorMessage =
        'Unable to load transport data.\n$e';
      });
    }
  }

  // ==========================================================
  // LOCATION
  // ==========================================================

  Future<void> _getCurrentLocation() async {
    if (_locationLoading) {
      return;
    }

    setState(() {
      _locationLoading = true;
      _locationMessage =
      'Getting your current location...';
    });

    try {
      final serviceEnabled =
      await Geolocator
          .isLocationServiceEnabled();

      if (!serviceEnabled) {
        if (!mounted) {
          return;
        }

        setState(() {
          _locationLoading = false;
          _locationMessage =
          'Location is OFF. Please turn on GPS/location.';
        });

        return;
      }

      LocationPermission permission =
      await Geolocator.checkPermission();

      if (permission ==
          LocationPermission.denied) {
        permission =
        await Geolocator.requestPermission();
      }

      if (permission ==
          LocationPermission.denied) {
        if (!mounted) {
          return;
        }

        setState(() {
          _locationLoading = false;
          _locationMessage =
          'Location permission was denied.';
        });

        return;
      }

      if (permission ==
          LocationPermission.deniedForever) {
        if (!mounted) {
          return;
        }

        setState(() {
          _locationLoading = false;
          _locationMessage =
          'Location permission is permanently denied. '
              'Please enable it in device settings.';
        });

        return;
      }

      final position =
      await Geolocator.getCurrentPosition(
        locationSettings:
        const LocationSettings(
          accuracy:
          LocationAccuracy.high,
          distanceFilter: 0,
        ),
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _currentPosition = position;
        _locationLoading = false;
        _locationMessage =
        'Location detected successfully.';
      });

      _calculateDistances();
      _applyFilters();
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _locationLoading = false;
        _locationMessage =
        'Unable to get location: $e';
      });
    }
  }

  // ==========================================================
  // CALCULATE DISTANCES
  // ==========================================================

  void _calculateDistances() {
    final position =
        _currentPosition;

    if (position == null) {
      return;
    }

    for (final stop in _allStops) {
      stop.distanceMeters =
          Geolocator.distanceBetween(
            position.latitude,
            position.longitude,
            stop.latitude,
            stop.longitude,
          );
    }
  }

  // ==========================================================
  // SEARCH
  // ==========================================================

  String _normalizeSearch(
      String value,
      ) {
    return value
        .toLowerCase()
        .replaceAll(
      RegExp(r'[^a-z0-9]'),
      '',
    );
  }

  void _onSearchChanged() {
    _searchDebounce?.cancel();

    _searchDebounce = Timer(
      const Duration(
        milliseconds: 250,
      ),
          () {
        _applyFilters();
      },
    );
  }

  // ==========================================================
  // FILTER
  // ==========================================================

  void _applyFilters() {
    final search =
    _normalizeSearch(
      _searchController.text,
    );

    List<TransportStop> data =
    List.from(_allStops);

    // --------------------------------------------------------
    // SEARCH
    // --------------------------------------------------------

    if (search.isNotEmpty) {
      data = data.where((stop) {
        final name =
        _normalizeSearch(
          stop.name,
        );

        final description =
        _normalizeSearch(
          stop.description ?? '',
        );

        final address =
        _normalizeSearch(
          stop.address ??
              stop.officialAddress ??
              '',
        );

        final routeText =
        _normalizeSearch(
          stop.routes
              .map(
                (r) =>
            '${r.shortName} ${r.longName}',
          )
              .join(' '),
        );

        return name.contains(search) ||
            description.contains(search) ||
            address.contains(search) ||
            routeText.contains(search);
      }).toList();
    }

    // --------------------------------------------------------
    // TYPE FILTER
    // --------------------------------------------------------

    if (_selectedType != 'All') {
      data = data.where((stop) {
        return stop.routes.any(
              (route) =>
          route.transportType ==
              _selectedType,
        );
      }).toList();
    }

    // --------------------------------------------------------
    // SORT
    // --------------------------------------------------------

    if (_nearestFirst &&
        _currentPosition != null) {
      data.sort(
            (a, b) {
          final aDistance =
              a.distanceMeters ??
                  double.infinity;

          final bDistance =
              b.distanceMeters ??
                  double.infinity;

          return aDistance.compareTo(
            bDistance,
          );
        },
      );
    } else {
      data.sort(
            (a, b) => a.name
            .toLowerCase()
            .compareTo(
          b.name.toLowerCase(),
        ),
      );
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _filteredStops = data;
    });
  }

  // ==========================================================
  // ADDRESS
  // ==========================================================

  Future<void> _loadVisibleAddresses() async {
    if (_addressLoading) {
      return;
    }

    if (_filteredStops.isEmpty) {
      return;
    }

    _addressLoading = true;

    try {
      // Only process first 5.
      //
      // Nominatim public service has a strict
      // maximum of about 1 request/second.
      final count =
      min(5, _filteredStops.length);

      for (int i = 0; i < count; i++) {
        final stop =
        _filteredStops[i];

        if (stop.address != null &&
            stop.address!.isNotEmpty) {
          continue;
        }

        // First priority:
        // address directly supplied by GTFS.
        if (stop.officialAddress !=
            null &&
            stop.officialAddress!
                .trim()
                .isNotEmpty) {
          stop.address =
              stop.officialAddress!.trim();

          continue;
        }

        final address =
        await AddressService
            .reverseGeocode(
          stop.latitude,
          stop.longitude,
        );

        if (address != null &&
            address.isNotEmpty) {
          stop.address = address;
        }

        if (i + 1 < count) {
          await Future.delayed(
            const Duration(
              milliseconds: 1100,
            ),
          );
        }
      }
    } finally {
      _addressLoading = false;

      if (mounted) {
        setState(() {});
      }
    }
  }

  // ==========================================================
  // FAVOURITE
  // ==========================================================

  void _toggleFavourite(
      TransportStop stop,
      ) {
    setState(() {
      if (_favourites.contains(stop.id)) {
        _favourites.remove(
          stop.id,
        );
      } else {
        _favourites.add(
          stop.id,
        );
      }
    });
  }

  // ==========================================================
  // DISTANCE TEXT
  // ==========================================================

  String _distanceText(
      TransportStop stop,
      ) {
    final distance =
        stop.distanceMeters;

    if (distance == null) {
      return 'Location unavailable';
    }

    if (distance < 1000) {
      return '${distance.round()} m away';
    }

    return '${(distance / 1000).toStringAsFixed(2)} km away';
  }

  // ==========================================================
  // ADDRESS TEXT
  // ==========================================================

  String _addressText(
      TransportStop stop,
      ) {
    if (stop.address != null &&
        stop.address!.trim().isNotEmpty) {
      return stop.address!.trim();
    }

    if (stop.officialAddress != null &&
        stop.officialAddress!
            .trim()
            .isNotEmpty) {
      return stop.officialAddress!.trim();
    }

    if (_addressLoading) {
      return 'Finding address...';
    }

    return 'Address not available in the transport data';
  }

  // ==========================================================
  // TRANSPORT TYPE
  // ==========================================================

  String _mainTransportType(
      TransportStop stop,
      ) {
    final types = stop.routes
        .map(
          (r) => r.transportType,
    )
        .toSet();

    if (types.contains('MRT')) {
      return 'MRT';
    }

    if (types.contains('LRT')) {
      return 'LRT';
    }

    if (types.contains('Monorail')) {
      return 'Monorail';
    }

    if (types.contains('Bus')) {
      return 'Bus';
    }

    if (types.isNotEmpty) {
      return types.first;
    }

    return 'Transport';
  }

  // ==========================================================
  // NEAREST STOP
  // ==========================================================

  TransportStop? get _nearestStop {
    if (_currentPosition == null ||
        _allStops.isEmpty) {
      return null;
    }

    TransportStop? nearest;

    double nearestDistance =
        double.infinity;

    for (final stop in _allStops) {
      final distance =
          stop.distanceMeters;

      if (distance == null) {
        continue;
      }

      if (distance <
          nearestDistance) {
        nearestDistance = distance;
        nearest = stop;
      }
    }

    return nearest;
  }

  // ==========================================================
  // OPEN SETTINGS
  // ==========================================================

  Future<void> _openLocationSettings() async {
    try {
      await Geolocator
          .openLocationSettings();
    } catch (e) {
      debugPrint(
        'Unable to open location settings: $e',
      );
    }
  }

  Future<void> _openAppSettings() async {
    try {
      await Geolocator
          .openAppSettings();
    } catch (e) {
      debugPrint(
        'Unable to open app settings: $e',
      );
    }
  }

  // ==========================================================
  // DETAIL PAGE
  // ==========================================================

  void _openDetails(
      TransportStop stop,
      ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            TransportDetailPage(
              stop: stop,
              isFavourite:
              _favourites.contains(
                stop.id,
              ),
              onFavourite: () {
                _toggleFavourite(stop);
              },
            ),
      ),
    );
  }

  // ==========================================================
  // UI
  // ==========================================================

  @override
  Widget build(
      BuildContext context,
      ) {
    final nearest =
        _nearestStop;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Nearby Transport',
        ),
        actions: [
          IconButton(
            tooltip:
            'Refresh location',
            onPressed:
            _locationLoading
                ? null
                : _getCurrentLocation,
            icon: const Icon(
              Icons.my_location,
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(
        child:
        CircularProgressIndicator(),
      )
          : _errorMessage != null
          ? _buildError()
          : _buildMainContent(
        nearest,
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding:
        const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment:
          MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 60,
            ),
            const SizedBox(
              height: 16,
            ),
            Text(
              _errorMessage!,
              textAlign:
              TextAlign.center,
            ),
            const SizedBox(
              height: 20,
            ),
            FilledButton.icon(
              onPressed: _loadData,
              icon: const Icon(
                Icons.refresh,
              ),
              label:
              const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContent(
      TransportStop? nearest,
      ) {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding:
        const EdgeInsets.all(16),
        children: [
          _buildLocationCard(),

          const SizedBox(
            height: 12,
          ),

          if (nearest != null)
            _buildNearestCard(
              nearest,
            ),

          const SizedBox(
            height: 16,
          ),

          TextField(
            controller:
            _searchController,
            decoration:
            InputDecoration(
              hintText:
              'Search station, stop or line...',
              prefixIcon:
              const Icon(
                Icons.search,
              ),
              suffixIcon:
              _searchController
                  .text
                  .isEmpty
                  ? null
                  : IconButton(
                onPressed: () {
                  _searchController
                      .clear();
                },
                icon:
                const Icon(
                  Icons.clear,
                ),
              ),
              border:
              const OutlineInputBorder(),
            ),
          ),

          const SizedBox(
            height: 12,
          ),

          _buildFilters(),

          const SizedBox(
            height: 16,
          ),

          Row(
            mainAxisAlignment:
            MainAxisAlignment
                .spaceBetween,
            children: [
              Text(
                '${_filteredStops.length} transport stops',
                style:
                Theme.of(context)
                    .textTheme
                    .titleMedium,
              ),
              if (_nearestFirst &&
                  _currentPosition !=
                      null)
                const Text(
                  'Nearest first',
                  style: TextStyle(
                    fontWeight:
                    FontWeight.bold,
                  ),
                ),
            ],
          ),

          const SizedBox(
            height: 8,
          ),

          if (_filteredStops.isEmpty)
            _buildNoResults()
          else
            ..._filteredStops
                .map(
              _buildStopCard,
            ),
        ],
      ),
    );
  }

  Widget _buildLocationCard() {
    final position =
        _currentPosition;

    Color? color;

    if (_locationLoading) {
      color = Colors.orange;
    } else if (position != null) {
      color = Colors.green;
    } else {
      color = Colors.red;
    }

    return Card(
      child: Padding(
        padding:
        const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  position != null
                      ? Icons.location_on
                      : Icons.location_off,
                  color: color,
                ),
                const SizedBox(
                  width: 10,
                ),
                Expanded(
                  child: Text(
                    _locationLoading
                        ? 'Getting location...'
                        : position != null
                        ? 'Location detected'
                        : 'Location unavailable',
                    style:
                    const TextStyle(
                      fontWeight:
                      FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(
              height: 8,
            ),

            Text(
              _locationMessage ??
                  'Location is required to calculate distance.',
            ),

            if (position == null &&
                !_locationLoading)
              Padding(
                padding:
                const EdgeInsets.only(
                  top: 12,
                ),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed:
                      _getCurrentLocation,
                      icon: const Icon(
                        Icons.location_searching,
                      ),
                      label:
                      const Text(
                        'Try Location Again',
                      ),
                    ),
                    OutlinedButton(
                      onPressed:
                      _openLocationSettings,
                      child:
                      const Text(
                        'Turn On GPS',
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildNearestCard(
      TransportStop stop,
      ) {
    return Card(
      elevation: 3,
      child: InkWell(
        borderRadius:
        BorderRadius.circular(
          12,
        ),
        onTap: () =>
            _openDetails(stop),
        child: Padding(
          padding:
          const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.near_me,
                  ),
                  const SizedBox(
                    width: 8,
                  ),
                  const Text(
                    'Nearest to you',
                    style:
                    TextStyle(
                      fontWeight:
                      FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),

              const SizedBox(
                height: 10,
              ),

              Text(
                stop.name,
                style:
                const TextStyle(
                  fontWeight:
                  FontWeight.bold,
                  fontSize: 22,
                ),
              ),

              const SizedBox(
                height: 6,
              ),

              Text(
                '${_mainTransportType(stop)} • '
                    '${_distanceText(stop)}',
              ),

              const SizedBox(
                height: 6,
              ),

              Text(
                _addressText(stop),
                maxLines: 2,
                overflow:
                TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ChoiceChip(
          label:
          const Text('All'),
          selected:
          _selectedType ==
              'All',
          onSelected: (_) {
            setState(() {
              _selectedType =
              'All';
            });

            _applyFilters();
          },
        ),
        ChoiceChip(
          label:
          const Text('LRT'),
          selected:
          _selectedType ==
              'LRT',
          onSelected: (_) {
            setState(() {
              _selectedType =
              'LRT';
            });

            _applyFilters();
          },
        ),
        ChoiceChip(
          label:
          const Text('MRT'),
          selected:
          _selectedType ==
              'MRT',
          onSelected: (_) {
            setState(() {
              _selectedType =
              'MRT';
            });

            _applyFilters();
          },
        ),
        ChoiceChip(
          label:
          const Text('Monorail'),
          selected:
          _selectedType ==
              'Monorail',
          onSelected: (_) {
            setState(() {
              _selectedType =
              'Monorail';
            });

            _applyFilters();
          },
        ),
        ChoiceChip(
          label:
          const Text('Bus'),
          selected:
          _selectedType ==
              'Bus',
          onSelected: (_) {
            setState(() {
              _selectedType =
              'Bus';
            });

            _applyFilters();
          },
        ),
        FilterChip(
          label:
          const Text('Nearest first'),
          selected:
          _nearestFirst,
          onSelected: (value) {
            setState(() {
              _nearestFirst =
                  value;
            });

            _applyFilters();
          },
        ),
      ],
    );
  }

  Widget _buildNoResults() {
    return Card(
      child: Padding(
        padding:
        const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(
              Icons.search_off,
              size: 50,
            ),
            const SizedBox(
              height: 12,
            ),
            const Text(
              'No transport stops found.',
            ),
            const SizedBox(
              height: 8,
            ),
            const Text(
              'Try another station name or line.',
              textAlign:
              TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStopCard(
      TransportStop stop,
      ) {
    final favourite =
    _favourites.contains(
      stop.id,
    );

    final type =
    _mainTransportType(stop);

    return Card(
      margin:
      const EdgeInsets.only(
        bottom: 10,
      ),
      child: InkWell(
        onTap: () =>
            _openDetails(stop),
        borderRadius:
        BorderRadius.circular(
          12,
        ),
        child: Padding(
          padding:
          const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment:
                CrossAxisAlignment
                    .start,
                children: [
                  CircleAvatar(
                    child: Icon(
                      type == 'Bus'
                          ? Icons
                          .directions_bus
                          : Icons
                          .train,
                    ),
                  ),

                  const SizedBox(
                    width: 12,
                  ),

                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                      children: [
                        Text(
                          stop.name,
                          style:
                          const TextStyle(
                            fontWeight:
                            FontWeight.bold,
                            fontSize: 17,
                          ),
                        ),

                        const SizedBox(
                          height: 4,
                        ),

                        Text(
                          '$type • ${_distanceText(stop)}',
                          style:
                          TextStyle(
                            color: Theme.of(
                              context,
                            )
                                .colorScheme
                                .primary,
                            fontWeight:
                            FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),

                  IconButton(
                    onPressed: () =>
                        _toggleFavourite(
                          stop,
                        ),
                    icon: Icon(
                      favourite
                          ? Icons
                          .favorite
                          : Icons
                          .favorite_border,
                    ),
                  ),
                ],
              ),

              const SizedBox(
                height: 10,
              ),

              Row(
                crossAxisAlignment:
                CrossAxisAlignment
                    .start,
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    size: 20,
                  ),
                  const SizedBox(
                    width: 6,
                  ),
                  Expanded(
                    child: Text(
                      _addressText(
                        stop,
                      ),
                      maxLines: 2,
                      overflow:
                      TextOverflow
                          .ellipsis,
                    ),
                  ),
                ],
              ),

              if (stop.routes
                  .isNotEmpty) ...[
                const SizedBox(
                  height: 10,
                ),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: stop.routes
                      .map(
                        (route) =>
                        Chip(
                          label: Text(
                            route.displayName,
                          ),
                          visualDensity:
                          VisualDensity
                              .compact,
                        ),
                  )
                      .toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// DETAIL PAGE
// ============================================================

class TransportDetailPage
    extends StatelessWidget {
  final TransportStop stop;
  final bool isFavourite;
  final VoidCallback onFavourite;

  const TransportDetailPage({
    super.key,
    required this.stop,
    required this.isFavourite,
    required this.onFavourite,
  });

  String _distanceText() {
    if (stop.distanceMeters ==
        null) {
      return 'Location unavailable';
    }

    if (stop.distanceMeters! <
        1000) {
      return '${stop.distanceMeters!.round()} m';
    }

    return '${(stop.distanceMeters! / 1000).toStringAsFixed(2)} km';
  }

  @override
  Widget build(
      BuildContext context,
      ) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          stop.name,
        ),
        actions: [
          IconButton(
            onPressed:
            onFavourite,
            icon: Icon(
              isFavourite
                  ? Icons.favorite
                  : Icons.favorite_border,
            ),
          ),
        ],
      ),
      body: ListView(
        padding:
        const EdgeInsets.all(18),
        children: [
          Card(
            child: Padding(
              padding:
              const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment
                    .start,
                children: [
                  Text(
                    stop.name,
                    style:
                    Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(
                      fontWeight:
                      FontWeight
                          .bold,
                    ),
                  ),

                  const SizedBox(
                    height: 14,
                  ),

                  _infoRow(
                    Icons
                        .directions_transit,
                    'Transport',
                    stop.routes
                        .map(
                          (r) =>
                      r.transportType,
                    )
                        .toSet()
                        .join(', '),
                  ),

                  _infoRow(
                    Icons
                        .straighten,
                    'Distance',
                    _distanceText(),
                  ),

                  _infoRow(
                    Icons.location_on,
                    'Address',
                    stop.address ??
                        stop.officialAddress ??
                        'Address not available in official GTFS data',
                  ),

                  _infoRow(
                    Icons.map,
                    'Coordinates',
                    '${stop.latitude.toStringAsFixed(6)}, '
                        '${stop.longitude.toStringAsFixed(6)}',
                  ),

                  _infoRow(
                    Icons.tag,
                    'Stop ID',
                    stop.id,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(
            height: 16,
          ),

          const Text(
            'Lines',
            style:
            TextStyle(
              fontWeight:
              FontWeight.bold,
              fontSize: 18,
            ),
          ),

          const SizedBox(
            height: 8,
          ),

          if (stop.routes.isEmpty)
            const Text(
              'No route information found.',
            )
          else
            ...stop.routes.map(
                  (route) => Card(
                child: ListTile(
                  leading:
                  const Icon(
                    Icons.train,
                  ),
                  title: Text(
                    route.displayName,
                  ),
                  subtitle: Text(
                    route.transportType,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _infoRow(
      IconData icon,
      String title,
      String value,
      ) {
    return Padding(
      padding:
      const EdgeInsets.only(
        bottom: 14,
      ),
      child: Row(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 22,
          ),
          const SizedBox(
            width: 10,
          ),
          SizedBox(
            width: 90,
            child: Text(
              title,
              style:
              const TextStyle(
                fontWeight:
                FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
            ),
          ),
        ],
      ),
    );
  }
}