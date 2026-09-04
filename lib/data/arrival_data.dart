import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ArrivalData {
  final String station;
  final String line;
  final String arrivalTime;
  final String status;

  const ArrivalData({
    required this.station,
    required this.line,
    required this.arrivalTime,
    required this.status,
  });
}

class ArrivalService {
  static const String _gtfsUrl =
      'https://api.data.gov.my/gtfs-static/prasarana?category=rapid-rail-kl';

  static bool _loaded = false;

  static final Map<String, _Stop> _stops = {};
  static final Map<String, _Route> _routes = {};
  static final Map<String, _Trip> _trips = {};

  static final List<_StopTime> _stopTimes = [];

  static final List<_Frequency> _frequencies = [];

  static final Map<String, _Calendar> _calendars = {};

  static final Map<String, _CalendarDate> _calendarDates = {};

  // ============================================================
  // LOAD GTFS DATA
  // ============================================================

  static Future<void> loadData() async {
    if (_loaded) {
      return;
    }

    debugPrint('========================================');
    debugPrint('Arrival Service');
    debugPrint('Loading Government GTFS Static Data...');
    debugPrint('========================================');

    final response = await http.get(
      Uri.parse(_gtfsUrl),
    );

    debugPrint(
      'GTFS STATUS: ${response.statusCode}',
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to load GTFS data: '
            '${response.statusCode}',
      );
    }

    final archive = ZipDecoder().decodeBytes(
      response.bodyBytes,
    );

    // ------------------------------------------------------------
    // STOPS
    // ------------------------------------------------------------

    _parseStops(
      _readFile(
        archive,
        'stops.txt',
      ),
    );

    // ------------------------------------------------------------
    // ROUTES
    // ------------------------------------------------------------

    _parseRoutes(
      _readFile(
        archive,
        'routes.txt',
      ),
    );

    // ------------------------------------------------------------
    // TRIPS
    // ------------------------------------------------------------

    _parseTrips(
      _readFile(
        archive,
        'trips.txt',
      ),
    );

    // ------------------------------------------------------------
    // STOP TIMES
    // ------------------------------------------------------------

    _parseStopTimes(
      _readFile(
        archive,
        'stop_times.txt',
      ),
    );

    // ------------------------------------------------------------
    // FREQUENCIES
    // ------------------------------------------------------------

    final frequencyFile = archive.findFile(
      'frequencies.txt',
    );

    if (frequencyFile != null) {
      _parseFrequencies(
        utf8.decode(
          frequencyFile.content as List<int>,
        ),
      );

      debugPrint(
        'frequencies.txt loaded.',
      );
    } else {
      debugPrint(
        'frequencies.txt not found.',
      );
    }

    // ------------------------------------------------------------
    // CALENDAR
    // ------------------------------------------------------------

    final calendarFile = archive.findFile(
      'calendar.txt',
    );

    if (calendarFile != null) {
      _parseCalendar(
        utf8.decode(
          calendarFile.content as List<int>,
        ),
      );

      debugPrint(
        'calendar.txt loaded.',
      );
    } else {
      debugPrint(
        'calendar.txt NOT found.',
      );
    }

    // ------------------------------------------------------------
    // CALENDAR DATES
    // ------------------------------------------------------------

    final calendarDateFile = archive.findFile(
      'calendar_dates.txt',
    );

    if (calendarDateFile != null) {
      _parseCalendarDates(
        utf8.decode(
          calendarDateFile.content as List<int>,
        ),
      );

      debugPrint(
        'calendar_dates.txt loaded.',
      );
    } else {
      debugPrint(
        'calendar_dates.txt not found.',
      );
    }

    _loaded = true;

    debugPrint(
      'Arrival GTFS loaded successfully.',
    );

    debugPrint(
      'Stops: ${_stops.length}',
    );

    debugPrint(
      'Routes: ${_routes.length}',
    );

    debugPrint(
      'Trips: ${_trips.length}',
    );

    debugPrint(
      'Stop times: ${_stopTimes.length}',
    );

    debugPrint(
      'Frequencies: ${_frequencies.length}',
    );

    debugPrint(
      'Calendars: ${_calendars.length}',
    );

    debugPrint(
      'Calendar dates: ${_calendarDates.length}',
    );

    // ------------------------------------------------------------
    // PRINT CALENDAR INFORMATION
    // ------------------------------------------------------------

    debugPrint('--------------------------------');
    debugPrint('CALENDAR DATA');

    for (final calendar in _calendars.values) {
      debugPrint(
        'Service ID: ${calendar.serviceId}',
      );

      debugPrint(
        'Mon=${calendar.monday} '
            'Tue=${calendar.tuesday} '
            'Wed=${calendar.wednesday} '
            'Thu=${calendar.thursday} '
            'Fri=${calendar.friday} '
            'Sat=${calendar.saturday} '
            'Sun=${calendar.sunday}',
      );

      debugPrint(
        'Start=${calendar.startDate} '
            'End=${calendar.endDate}',
      );

      debugPrint(
        '--------------------------------',
      );
    }
  }

  // ============================================================
  // GET ARRIVALS
  // ============================================================

  static Future<List<ArrivalData>> getArrivals(
      String station,
      ) async {
    await loadData();

    final query =
    _normaliseStationName(station);

    final matchingStops =
    _stops.values.where(
          (stop) =>
      _normaliseStationName(
        stop.name,
      ) ==
          query,
    );

    if (matchingStops.isEmpty) {
      debugPrint(
        'Arrival station not found: $station',
      );

      return [];
    }

    final stopIds = matchingStops
        .map(
          (stop) => stop.id,
    )
        .toSet();

    debugPrint('--------------------------------');
    debugPrint(
      'ARRIVAL STATION MATCH',
    );

    for (final stop in matchingStops) {
      debugPrint(
        '${stop.name} (${stop.id})',
      );
    }

    final now = DateTime.now();

    debugPrint(
      'Arrival query station: $station',
    );

    debugPrint(
      'Current local time: $now',
    );

    debugPrint(
      'Current weekday: ${now.weekday}',
    );

    final currentMinutes =
        now.hour * 60 + now.minute;

    debugPrint(
      'Current minutes: $currentMinutes',
    );

    // ==========================================================
    // NORMAL STOP TIME ARRIVALS
    // ==========================================================

    final arrivals =
    <_ArrivalCandidate>[];

    int stationStopTimeCount = 0;

    int validServiceCount = 0;

    int futureTimeCount = 0;

    // ==========================================================
    // CHECK STOP TIMES
    // ==========================================================

    for (final stopTime in _stopTimes) {
      // ----------------------------------------------------------
      // STATION
      // ----------------------------------------------------------

      if (!stopIds.contains(
        stopTime.stopId,
      )) {
        continue;
      }

      stationStopTimeCount++;

      // ----------------------------------------------------------
      // TRIP
      // ----------------------------------------------------------

      final trip =
      _trips[stopTime.tripId];

      if (trip == null) {
        continue;
      }

      // ----------------------------------------------------------
      // SERVICE
      // ----------------------------------------------------------

      final serviceRunning =
      _isTripRunningToday(
        trip.serviceId,
        now,
      );

      if (!serviceRunning) {
        continue;
      }

      validServiceCount++;

      // ----------------------------------------------------------
      // ARRIVAL TIME
      // ----------------------------------------------------------

      final arrivalMinutes =
      _timeToMinutes(
        stopTime.arrivalTime,
      );

      if (arrivalMinutes < 0) {
        continue;
      }

      // ----------------------------------------------------------
      // LINE
      // ----------------------------------------------------------

      final line =
      _getLineName(
        trip.routeId,
      );

      // ----------------------------------------------------------
      // FUTURE ARRIVAL
      // ----------------------------------------------------------

      if (arrivalMinutes >= currentMinutes) {
        futureTimeCount++;

        arrivals.add(
          _ArrivalCandidate(
            line: line,
            arrivalMinutes:
            arrivalMinutes,
            originalArrivalTime:
            stopTime.arrivalTime,
          ),
        );
      }
    }

    // ==========================================================
    // FREQUENCY-BASED ARRIVALS
    // ==========================================================

    int frequencyMatches = 0;

    for (final frequency in _frequencies) {
      final trip =
      _trips[frequency.tripId];

      if (trip == null) {
        continue;
      }

      // ----------------------------------------------------------
      // SERVICE
      // ----------------------------------------------------------

      final serviceRunning =
      _isTripRunningToday(
        trip.serviceId,
        now,
      );

      if (!serviceRunning) {
        continue;
      }

      // ----------------------------------------------------------
      // FIND STATION STOP TIME
      // ----------------------------------------------------------

      final stationStopTimes =
      _stopTimes.where(
            (stopTime) =>
        stopTime.tripId ==
            frequency.tripId &&
            stopIds.contains(
              stopTime.stopId,
            ),
      );

      for (final stopTime
      in stationStopTimes) {
        final baseArrival =
        _timeToMinutes(
          stopTime.arrivalTime,
        );

        if (baseArrival < 0) {
          continue;
        }

        final startTime =
        _timeToMinutes(
          frequency.startTime,
        );

        final endTime =
        _timeToMinutes(
          frequency.endTime,
        );

        if (startTime < 0 ||
            endTime < 0) {
          continue;
        }

        // --------------------------------------------------------
        // Calculate the frequency-based arrival.
        //
        // stop_times gives the base trip time.
        // frequencies gives the repeating service pattern.
        // --------------------------------------------------------

        final headwaySeconds =
            frequency.headwaySeconds;

        if (headwaySeconds <= 0) {
          continue;
        }

        final headwayMinutes =
            headwaySeconds / 60.0;

        // Time difference between the trip start
        // and the station arrival.
        final offset =
            baseArrival - startTime;

        final firstArrival =
            startTime + offset;

        double candidate =
        firstArrival.toDouble();

        // --------------------------------------------------------
        // Find the next occurrence after current time.
        // --------------------------------------------------------

        while (candidate <
            currentMinutes &&
            candidate <= endTime) {
          candidate +=
              headwayMinutes;
        }

        if (candidate >
            endTime ||
            candidate <
                currentMinutes) {
          continue;
        }

        final candidateMinutes =
        candidate.round();

        arrivals.add(
          _ArrivalCandidate(
            line: _getLineName(
              trip.routeId,
            ),
            arrivalMinutes:
            candidateMinutes,
            originalArrivalTime:
            stopTime.arrivalTime,
          ),
        );

        frequencyMatches++;
      }
    }

    // ==========================================================
    // DIAGNOSTIC
    // ==========================================================

    debugPrint('--------------------------------');
    debugPrint(
      'Arrival diagnostic:',
    );

    debugPrint(
      'Station stop times: '
          '$stationStopTimeCount',
    );

    debugPrint(
      'Valid service trips: '
          '$validServiceCount',
    );

    debugPrint(
      'Future stop-time arrivals: '
          '$futureTimeCount',
    );

    debugPrint(
      'Frequency matches: '
          '$frequencyMatches',
    );

    debugPrint(
      'Total candidate arrivals: '
          '${arrivals.length}',
    );

    // ==========================================================
    // SORT
    // ==========================================================

    arrivals.sort(
          (a, b) =>
          a.arrivalMinutes.compareTo(
            b.arrivalMinutes,
          ),
    );

    // ==========================================================
    // REMOVE DUPLICATES
    // ==========================================================

    final seen = <String>{};

    final result =
    <ArrivalData>[];

    for (final arrival in arrivals) {
      final key =
          '${arrival.line}|'
          '${arrival.arrivalMinutes}';

      if (!seen.add(key)) {
        continue;
      }

      result.add(
        ArrivalData(
          station: station,
          line: arrival.line,
          arrivalTime:
          _formatMinutes(
            arrival.arrivalMinutes,
          ),
          status: 'Scheduled',
        ),
      );

      if (result.length >= 5) {
        break;
      }
    }

    // ==========================================================
    // FINAL DEBUG
    // ==========================================================

    debugPrint('--------------------------------');

    debugPrint(
      'Arrivals found for $station: '
          '${result.length}',
    );

    for (final arrival in result) {
      debugPrint(
        '${arrival.line} '
            '${arrival.arrivalTime} '
            '${arrival.status}',
      );
    }

    debugPrint('========================================');

    return result;
  }

  // ============================================================
  // GET LINE NAME
  // ============================================================

  static String _getLineName(
      String routeId,
      ) {
    final route =
    _routes[routeId];

    if (route != null &&
        route.shortName.isNotEmpty) {
      return route.shortName;
    }

    if (route != null &&
        route.longName.isNotEmpty) {
      return route.longName;
    }

    return routeId;
  }

  // ============================================================
  // CHECK WHETHER SERVICE RUNS TODAY
  // ============================================================

  static bool _isTripRunningToday(
      String serviceId,
      DateTime date,
      ) {
    final calendar =
    _calendars[serviceId];

    debugPrint(
      'Checking service: $serviceId '
          'for ${date.year}-'
          '${date.month.toString().padLeft(2, '0')}-'
          '${date.day.toString().padLeft(2, '0')}',
    );

    // ----------------------------------------------------------
    // No matching calendar
    // ----------------------------------------------------------

    if (calendar == null) {
      debugPrint(
        'WARNING: No calendar found '
            'for service $serviceId',
      );

      return true;
    }

    // ----------------------------------------------------------
    // Date range
    // ----------------------------------------------------------

    final dateOnly = DateTime(
      date.year,
      date.month,
      date.day,
    );

    final startDate =
    _parseDate(
      calendar.startDate,
    );

    final endDate =
    _parseDate(
      calendar.endDate,
    );

    if (startDate == null ||
        endDate == null) {
      debugPrint(
        'WARNING: Invalid calendar date.',
      );

      return true;
    }

    if (dateOnly.isBefore(startDate) ||
        dateOnly.isAfter(endDate)) {
      debugPrint(
        'Service rejected: '
            'outside calendar date range.',
      );

      return false;
    }

    // ----------------------------------------------------------
    // Weekday
    // ----------------------------------------------------------

    bool active = false;

    switch (date.weekday) {
      case DateTime.monday:
        active = calendar.monday;
        break;

      case DateTime.tuesday:
        active = calendar.tuesday;
        break;

      case DateTime.wednesday:
        active = calendar.wednesday;
        break;

      case DateTime.thursday:
        active = calendar.thursday;
        break;

      case DateTime.friday:
        active = calendar.friday;
        break;

      case DateTime.saturday:
        active = calendar.saturday;
        break;

      case DateTime.sunday:
        active = calendar.sunday;
        break;
    }

    // ----------------------------------------------------------
    // Calendar exceptions
    // ----------------------------------------------------------

    final dateKey =
    _formatDateKey(dateOnly);

    final exception =
    _calendarDates[
    '$serviceId|$dateKey'];

    if (exception != null) {
      debugPrint(
        'Calendar exception found: '
            '${exception.exceptionType}',
      );

      // 1 = service added
      if (exception.exceptionType == 1) {
        active = true;
      }

      // 2 = service removed
      if (exception.exceptionType == 2) {
        active = false;
      }
    }

    debugPrint(
      'Final service active: $active',
    );

    return active;
  }

  // ============================================================
  // PARSE FREQUENCIES
  // ============================================================

  static void _parseFrequencies(
      String csv,
      ) {
    final rows =
    _parseCsv(csv);

    if (rows.isEmpty) {
      return;
    }

    final header =
        rows.first;

    final tripIdIndex =
    _indexOf(
      header,
      'trip_id',
    );

    final startTimeIndex =
    _indexOf(
      header,
      'start_time',
    );

    final endTimeIndex =
    _indexOf(
      header,
      'end_time',
    );

    final headwayIndex =
    _indexOf(
      header,
      'headway_secs',
    );

    if (tripIdIndex == -1 ||
        startTimeIndex == -1 ||
        endTimeIndex == -1 ||
        headwayIndex == -1) {
      debugPrint(
        'WARNING: frequencies.txt '
            'required columns not found.',
      );

      return;
    }

    for (final row in rows.skip(1)) {
      if (row.length <=
          headwayIndex) {
        continue;
      }

      final tripId =
      row[tripIdIndex].trim();

      final startTime =
      row[startTimeIndex].trim();

      final endTime =
      row[endTimeIndex].trim();

      final headwaySeconds =
      int.tryParse(
        row[headwayIndex].trim(),
      );

      if (tripId.isEmpty ||
          startTime.isEmpty ||
          endTime.isEmpty ||
          headwaySeconds == null) {
        continue;
      }

      _frequencies.add(
        _Frequency(
          tripId: tripId,
          startTime: startTime,
          endTime: endTime,
          headwaySeconds:
          headwaySeconds,
        ),
      );
    }
  }

  // ============================================================
  // PARSE CALENDAR
  // ============================================================

  static void _parseCalendar(
      String csv,
      ) {
    final rows =
    _parseCsv(csv);

    if (rows.isEmpty) {
      return;
    }

    final header =
        rows.first;

    final serviceIdIndex =
    _indexOf(
      header,
      'service_id',
    );

    final mondayIndex =
    _indexOf(
      header,
      'monday',
    );

    final tuesdayIndex =
    _indexOf(
      header,
      'tuesday',
    );

    final wednesdayIndex =
    _indexOf(
      header,
      'wednesday',
    );

    final thursdayIndex =
    _indexOf(
      header,
      'thursday',
    );

    final fridayIndex =
    _indexOf(
      header,
      'friday',
    );

    final saturdayIndex =
    _indexOf(
      header,
      'saturday',
    );

    final sundayIndex =
    _indexOf(
      header,
      'sunday',
    );

    final startDateIndex =
    _indexOf(
      header,
      'start_date',
    );

    final endDateIndex =
    _indexOf(
      header,
      'end_date',
    );

    if (serviceIdIndex == -1) {
      return;
    }

    for (final row in rows.skip(1)) {
      if (row.length <=
          serviceIdIndex) {
        continue;
      }

      final serviceId =
      row[serviceIdIndex].trim();

      if (serviceId.isEmpty) {
        continue;
      }

      _calendars[serviceId] =
          _Calendar(
            serviceId: serviceId,

            monday: _isOne(
              row,
              mondayIndex,
            ),

            tuesday: _isOne(
              row,
              tuesdayIndex,
            ),

            wednesday: _isOne(
              row,
              wednesdayIndex,
            ),

            thursday: _isOne(
              row,
              thursdayIndex,
            ),

            friday: _isOne(
              row,
              fridayIndex,
            ),

            saturday: _isOne(
              row,
              saturdayIndex,
            ),

            sunday: _isOne(
              row,
              sundayIndex,
            ),

            startDate: _getValue(
              row,
              startDateIndex,
            ),

            endDate: _getValue(
              row,
              endDateIndex,
            ),
          );
    }
  }

  // ============================================================
  // PARSE CALENDAR DATES
  // ============================================================

  static void _parseCalendarDates(
      String csv,
      ) {
    final rows =
    _parseCsv(csv);

    if (rows.isEmpty) {
      return;
    }

    final header =
        rows.first;

    final serviceIdIndex =
    _indexOf(
      header,
      'service_id',
    );

    final dateIndex =
    _indexOf(
      header,
      'date',
    );

    final exceptionTypeIndex =
    _indexOf(
      header,
      'exception_type',
    );

    if (serviceIdIndex == -1 ||
        dateIndex == -1 ||
        exceptionTypeIndex == -1) {
      return;
    }

    for (final row in rows.skip(1)) {
      if (row.length <=
          exceptionTypeIndex) {
        continue;
      }

      final serviceId =
      row[serviceIdIndex].trim();

      final date =
      row[dateIndex].trim();

      final exceptionType =
      int.tryParse(
        row[exceptionTypeIndex]
            .trim(),
      );

      if (serviceId.isEmpty ||
          date.isEmpty ||
          exceptionType == null) {
        continue;
      }

      _calendarDates[
      '$serviceId|$date'] =
          _CalendarDate(
            serviceId: serviceId,
            date: date,
            exceptionType:
            exceptionType,
          );
    }
  }

  // ============================================================
  // PARSE STOPS
  // ============================================================

  static void _parseStops(
      String csv,
      ) {
    final rows =
    _parseCsv(csv);

    if (rows.isEmpty) {
      return;
    }

    final header =
        rows.first;

    final stopIdIndex =
    _indexOf(
      header,
      'stop_id',
    );

    final stopNameIndex =
    _indexOf(
      header,
      'stop_name',
    );

    if (stopIdIndex == -1 ||
        stopNameIndex == -1) {
      throw Exception(
        'stop_id or stop_name not found',
      );
    }

    for (final row in rows.skip(1)) {
      if (row.length <=
          stopNameIndex) {
        continue;
      }

      final id =
      row[stopIdIndex].trim();

      final name =
      row[stopNameIndex].trim();

      if (id.isEmpty ||
          name.isEmpty) {
        continue;
      }

      _stops[id] =
          _Stop(
            id: id,
            name: name,
          );
    }
  }

  // ============================================================
  // PARSE ROUTES
  // ============================================================

  static void _parseRoutes(
      String csv,
      ) {
    final rows =
    _parseCsv(csv);

    if (rows.isEmpty) {
      return;
    }

    final header =
        rows.first;

    final routeIdIndex =
    _indexOf(
      header,
      'route_id',
    );

    final shortNameIndex =
    _indexOf(
      header,
      'route_short_name',
    );

    final longNameIndex =
    _indexOf(
      header,
      'route_long_name',
    );

    for (final row in rows.skip(1)) {
      if (routeIdIndex == -1 ||
          row.length <=
              routeIdIndex) {
        continue;
      }

      final routeId =
      row[routeIdIndex].trim();

      if (routeId.isEmpty) {
        continue;
      }

      final shortName =
      shortNameIndex != -1 &&
          row.length >
              shortNameIndex
          ? row[shortNameIndex].trim()
          : '';

      final longName =
      longNameIndex != -1 &&
          row.length >
              longNameIndex
          ? row[longNameIndex].trim()
          : '';

      _routes[routeId] =
          _Route(
            id: routeId,
            shortName: shortName,
            longName: longName,
          );
    }
  }

  // ============================================================
  // PARSE TRIPS
  // ============================================================

  static void _parseTrips(
      String csv,
      ) {
    final rows =
    _parseCsv(csv);

    if (rows.isEmpty) {
      return;
    }

    final header =
        rows.first;

    final routeIdIndex =
    _indexOf(
      header,
      'route_id',
    );

    final tripIdIndex =
    _indexOf(
      header,
      'trip_id',
    );

    final serviceIdIndex =
    _indexOf(
      header,
      'service_id',
    );

    for (final row in rows.skip(1)) {
      if (routeIdIndex == -1 ||
          tripIdIndex == -1 ||
          row.length <=
              tripIdIndex) {
        continue;
      }

      final routeId =
      row[routeIdIndex].trim();

      final tripId =
      row[tripIdIndex].trim();

      final serviceId =
      serviceIdIndex != -1 &&
          row.length >
              serviceIdIndex
          ? row[serviceIdIndex].trim()
          : '';

      if (routeId.isEmpty ||
          tripId.isEmpty) {
        continue;
      }

      _trips[tripId] =
          _Trip(
            id: tripId,
            routeId: routeId,
            serviceId: serviceId,
          );
    }
  }

  // ============================================================
  // PARSE STOP TIMES
  // ============================================================

  static void _parseStopTimes(
      String csv,
      ) {
    final rows =
    _parseCsv(csv);

    if (rows.isEmpty) {
      return;
    }

    final header =
        rows.first;

    final tripIdIndex =
    _indexOf(
      header,
      'trip_id',
    );

    final stopIdIndex =
    _indexOf(
      header,
      'stop_id',
    );

    final arrivalIndex =
    _indexOf(
      header,
      'arrival_time',
    );

    final departureIndex =
    _indexOf(
      header,
      'departure_time',
    );

    final sequenceIndex =
    _indexOf(
      header,
      'stop_sequence',
    );

    for (final row in rows.skip(1)) {
      if (tripIdIndex == -1 ||
          stopIdIndex == -1 ||
          row.length <=
              stopIdIndex) {
        continue;
      }

      final tripId =
      row[tripIdIndex].trim();

      final stopId =
      row[stopIdIndex].trim();

      if (tripId.isEmpty ||
          stopId.isEmpty) {
        continue;
      }

      final arrival =
      arrivalIndex != -1 &&
          row.length >
              arrivalIndex
          ? row[arrivalIndex].trim()
          : '';

      final departure =
      departureIndex != -1 &&
          row.length >
              departureIndex
          ? row[departureIndex].trim()
          : '';

      final sequence =
      sequenceIndex != -1 &&
          row.length >
              sequenceIndex
          ? int.tryParse(
        row[sequenceIndex]
            .trim(),
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
  // DATE
  // ============================================================

  static DateTime? _parseDate(
      String value,
      ) {
    if (value.length != 8) {
      return null;
    }

    final year =
    int.tryParse(
      value.substring(0, 4),
    );

    final month =
    int.tryParse(
      value.substring(4, 6),
    );

    final day =
    int.tryParse(
      value.substring(6, 8),
    );

    if (year == null ||
        month == null ||
        day == null) {
      return null;
    }

    return DateTime(
      year,
      month,
      day,
    );
  }

  static String _formatDateKey(
      DateTime date,
      ) {
    final year =
    date.year.toString();

    final month =
    date.month.toString().padLeft(
      2,
      '0',
    );

    final day =
    date.day.toString().padLeft(
      2,
      '0',
    );

    return '$year$month$day';
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

    final parts =
    time.split(':');

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

  static String _formatMinutes(
      int totalMinutes,
      ) {
    int hour =
        (totalMinutes ~/ 60) % 24;

    final minute =
        totalMinutes % 60;

    final period =
    hour >= 12 ? 'PM' : 'AM';

    if (hour == 0) {
      hour = 12;
    } else if (hour > 12) {
      hour -= 12;
    }

    return '$hour:'
        '${minute.toString().padLeft(2, '0')} '
        '$period';
  }

  // ============================================================
  // CSV
  // ============================================================

  static List<List<String>> _parseCsv(
      String csv,
      ) {
    final rows =
    <List<String>>[];

    final lines =
    const LineSplitter()
        .convert(csv);

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
    final result =
    <String>[];

    final buffer =
    StringBuffer();

    bool insideQuotes = false;

    for (int i = 0;
    i < line.length;
    i++) {
      final char =
      line[i];

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

  static String _getValue(
      List<String> row,
      int index,
      ) {
    if (index == -1 ||
        row.length <= index) {
      return '';
    }

    return row[index].trim();
  }

  static bool _isOne(
      List<String> row,
      int index,
      ) {
    if (index == -1 ||
        row.length <= index) {
      return false;
    }

    return row[index].trim() == '1';
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
  // READ ZIP FILE
  // ============================================================

  static String _readFile(
      Archive archive,
      String fileName,
      ) {
    final file =
    archive.findFile(
      fileName,
    );

    if (file == null) {
      throw Exception(
        '$fileName not found in GTFS ZIP',
      );
    }

    return utf8.decode(
      file.content as List<int>,
    );
  }
}

// ================================================================
// MODELS
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
  final String serviceId;

  const _Trip({
    required this.id,
    required this.routeId,
    required this.serviceId,
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

class _Frequency {
  final String tripId;
  final String startTime;
  final String endTime;
  final int headwaySeconds;

  const _Frequency({
    required this.tripId,
    required this.startTime,
    required this.endTime,
    required this.headwaySeconds,
  });
}

class _Calendar {
  final String serviceId;

  final bool monday;
  final bool tuesday;
  final bool wednesday;
  final bool thursday;
  final bool friday;
  final bool saturday;
  final bool sunday;

  final String startDate;
  final String endDate;

  const _Calendar({
    required this.serviceId,
    required this.monday,
    required this.tuesday,
    required this.wednesday,
    required this.thursday,
    required this.friday,
    required this.saturday,
    required this.sunday,
    required this.startDate,
    required this.endDate,
  });
}

class _CalendarDate {
  final String serviceId;
  final String date;
  final int exceptionType;

  const _CalendarDate({
    required this.serviceId,
    required this.date,
    required this.exceptionType,
  });
}

class _ArrivalCandidate {
  final String line;
  final int arrivalMinutes;
  final String originalArrivalTime;

  const _ArrivalCandidate({
    required this.line,
    required this.arrivalMinutes,
    required this.originalArrivalTime,
  });
}