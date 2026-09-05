import 'package:flutter/material.dart';

import '../data/arrival_data.dart';
import '../data/bus_arrival_data.dart';
import '../models/route_option.dart';

class RouteDetailsScreen extends StatefulWidget {
  final RouteOption route;

  const RouteDetailsScreen({
    super.key,
    required this.route,
  });

  @override
  State<RouteDetailsScreen> createState() =>
      _RouteDetailsScreenState();
}

class _RouteDetailsScreenState
    extends State<RouteDetailsScreen> {
  static const Color primaryBlue =
  Color(0xFF2F68B1);

  static const Color darkBlue =
  Color(0xFF174A87);

  static const Color lightBlue =
  Color(0xFFEAF3FF);

  static const Color backgroundColor =
  Color(0xFFF7F9FD);

  static const Color orange =
  Color(0xFFFF8A65);

  static const Color green =
  Color(0xFF279A4B);

  List<ArrivalData> _arrivals = [];

  bool _isLoadingArrivals = true;

  String? _arrivalError;

  @override
  void initState() {
    super.initState();

    _loadArrivals();
  }

  Future<void> _loadArrivals() async {
    setState(() {
      _isLoadingArrivals = true;
      _arrivalError = null;
    });

    try {
      late final List<ArrivalData> arrivals;

      if (widget.route.transport ==
          'Rapid Bus') {
        arrivals =
        await BusArrivalService.getArrivals(
          widget.route.from,
          routeId: widget.route.line,
        );
      } else {
        arrivals =
        await ArrivalService.getArrivals(
          widget.route.from,
        );
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _arrivals = arrivals;
        _isLoadingArrivals = false;
      });
    } catch (e) {
      debugPrint(
        'Arrival loading error: $e',
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _isLoadingArrivals = false;
        _arrivalError = e.toString();
      });
    }
  }

  @override
  Widget build(
      BuildContext context,
      ) {
    final route = widget.route;

    return Scaffold(
      backgroundColor:
      backgroundColor,
      appBar: AppBar(
        backgroundColor:
        Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: darkBlue,
          ),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: const Text(
          'Route Details',
          style: TextStyle(
            color: darkBlue,
            fontSize: 20,
            fontWeight:
            FontWeight.w700,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildHeader(),
            Padding(
              padding:
              const EdgeInsets.fromLTRB(
                18,
                22,
                18,
                30,
              ),
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Your Journey',
                    style: TextStyle(
                      fontSize: 23,
                      fontWeight:
                      FontWeight.w700,
                      color:
                      Color(0xFF172033),
                    ),
                  ),
                  const SizedBox(
                    height: 12,
                  ),
                  _buildJourneyCard(
                    route,
                  ),
                  const SizedBox(
                    height: 26,
                  ),
                  const Text(
                    'Route Information',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight:
                      FontWeight.w700,
                      color:
                      Color(0xFF172033),
                    ),
                  ),
                  const SizedBox(
                    height: 12,
                  ),
                  _buildRouteInformation(
                    route,
                  ),
                  const SizedBox(
                    height: 28,
                  ),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Arrival Information',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight:
                            FontWeight.w700,
                            color:
                            Color(0xFF172033),
                          ),
                        ),
                      ),
                      Container(
                        decoration:
                        BoxDecoration(
                          color:
                          Colors.white,
                          borderRadius:
                          BorderRadius
                              .circular(
                            12,
                          ),
                        ),
                        child:
                        IconButton(
                          onPressed:
                          _isLoadingArrivals
                              ? null
                              : _loadArrivals,
                          icon:
                          const Icon(
                            Icons.refresh,
                            color:
                            primaryBlue,
                          ),
                          tooltip:
                          'Refresh arrival information',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(
                    height: 4,
                  ),
                  Text(
                    'Scheduled arrivals at '
                        '${route.from}',
                    style:
                    const TextStyle(
                      fontSize: 14,
                      color:
                      Color(0xFF7D8797),
                    ),
                  ),
                  const SizedBox(
                    height: 14,
                  ),
                  _buildArrivalSection(),
                  const SizedBox(
                    height: 26,
                  ),
                  _buildDataSourceCard(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final isBus =
        widget.route.transport ==
            'Rapid Bus';

    return Container(
      width: double.infinity,
      padding:
      const EdgeInsets.fromLTRB(
        20,
        20,
        20,
        24,
      ),
      decoration:
      const BoxDecoration(
        color: primaryBlue,
        borderRadius:
        BorderRadius.only(
          bottomLeft:
          Radius.circular(28),
          bottomRight:
          Radius.circular(28),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 55,
            height: 55,
            decoration:
            BoxDecoration(
              color: Colors.white,
              borderRadius:
              BorderRadius.circular(
                17,
              ),
            ),
            child: Icon(
              isBus
                  ? Icons.directions_bus
                  : Icons.train,
              color: primaryBlue,
              size: 31,
            ),
          ),
          const SizedBox(
            width: 14,
          ),
          const Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(
                  'TransitMY',
                  style: TextStyle(
                    color:
                    Colors.white,
                    fontSize: 22,
                    fontWeight:
                    FontWeight.w800,
                  ),
                ),
                SizedBox(
                  height: 3,
                ),
                Text(
                  'Your Smart Public Transport Companion',
                  style: TextStyle(
                    color:
                    Color(0xFFDCEBFF),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJourneyCard(
      RouteOption route,
      ) {
    return Container(
      width: double.infinity,
      padding:
      const EdgeInsets.all(20),
      decoration:
      BoxDecoration(
        color: Colors.white,
        borderRadius:
        BorderRadius.circular(
          20,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black
                .withOpacity(0.05),
            blurRadius: 12,
            offset:
            const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration:
                const BoxDecoration(
                  color: lightBlue,
                  shape:
                  BoxShape.circle,
                ),
                child: const Icon(
                  Icons.trip_origin,
                  color:
                  primaryBlue,
                  size: 18,
                ),
              ),
              Container(
                height: 42,
                width: 2,
                color:
                const Color(
                  0xFFBBD2EF,
                ),
              ),
              Container(
                width: 34,
                height: 34,
                decoration:
                const BoxDecoration(
                  color:
                  Color(0xFFFFF0EB),
                  shape:
                  BoxShape.circle,
                ),
                child:
                const Icon(
                  Icons.location_on,
                  color: orange,
                  size: 19,
                ),
              ),
            ],
          ),
          const SizedBox(
            width: 14,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                const Text(
                  'FROM',
                  style:
                  TextStyle(
                    fontSize: 11,
                    fontWeight:
                    FontWeight.w600,
                    color:
                    Color(0xFF8A94A4),
                    letterSpacing:
                    0.5,
                  ),
                ),
                const SizedBox(
                  height: 3,
                ),
                Text(
                  route.from,
                  style:
                  const TextStyle(
                    fontSize: 18,
                    fontWeight:
                    FontWeight.w700,
                    color:
                    Color(0xFF202B3C),
                  ),
                ),
                const SizedBox(
                  height: 30,
                ),
                const Text(
                  'TO',
                  style:
                  TextStyle(
                    fontSize: 11,
                    fontWeight:
                    FontWeight.w600,
                    color:
                    Color(0xFF8A94A4),
                    letterSpacing:
                    0.5,
                  ),
                ),
                const SizedBox(
                  height: 3,
                ),
                Text(
                  route.to,
                  style:
                  const TextStyle(
                    fontSize: 18,
                    fontWeight:
                    FontWeight.w700,
                    color:
                    Color(0xFF202B3C),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteInformation(
      RouteOption route,
      ) {
    final isBus =
        route.transport ==
            'Rapid Bus';

    return Container(
      width: double.infinity,
      padding:
      const EdgeInsets.symmetric(
        horizontal: 18,
        vertical: 6,
      ),
      decoration:
      BoxDecoration(
        color: Colors.white,
        borderRadius:
        BorderRadius.circular(
          20,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black
                .withOpacity(0.05),
            blurRadius: 12,
            offset:
            const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _detailRow(
            isBus
                ? Icons.directions_bus
                : Icons.train,
            'Transport',
            route.transport,
          ),
          _divider(),
          _detailRow(
            Icons.route,
            'Line',
            route.line.isEmpty
                ? isBus
                ? 'Rapid Bus'
                : 'Rapid Rail'
                : route.line,
          ),
          _divider(),
          _detailRow(
            Icons.access_time,
            'Estimated Duration',
            '${route.duration} minutes',
          ),
          _divider(),
          _detailRow(
            Icons.swap_horiz,
            'Transfers',
            route.transfers == 0
                ? 'Direct'
                : '${route.transfers}',
          ),
          _divider(),
          _detailRow(
            Icons.schedule,
            'Arrival Type',
            'Scheduled',
            valueColor: green,
          ),
        ],
      ),
    );
  }

  Widget _buildArrivalSection() {
    if (_isLoadingArrivals) {
      return Container(
        width: double.infinity,
        padding:
        const EdgeInsets.all(
          30,
        ),
        decoration:
        BoxDecoration(
          color: Colors.white,
          borderRadius:
          BorderRadius.circular(
            20,
          ),
        ),
        child:
        const Center(
          child:
          CircularProgressIndicator(
            color: primaryBlue,
          ),
        ),
      );
    }

    if (_arrivalError != null) {
      return Container(
        width: double.infinity,
        padding:
        const EdgeInsets.all(
          24,
        ),
        decoration:
        BoxDecoration(
          color: Colors.white,
          borderRadius:
          BorderRadius.circular(
            20,
          ),
        ),
        child: Column(
          children: [
            Container(
              width: 55,
              height: 55,
              decoration:
              BoxDecoration(
                color:
                const Color(
                  0xFFFFF0EB,
                ),
                borderRadius:
                BorderRadius
                    .circular(
                  16,
                ),
              ),
              child:
              const Icon(
                Icons.error_outline,
                color: orange,
                size: 30,
              ),
            ),
            const SizedBox(
              height: 12,
            ),
            const Text(
              'Unable to load arrival information.',
              textAlign:
              TextAlign.center,
              style:
              TextStyle(
                fontWeight:
                FontWeight.w600,
                color:
                Color(0xFF202B3C),
              ),
            ),
            const SizedBox(
              height: 14,
            ),
            SizedBox(
              height: 44,
              child:
              ElevatedButton(
                onPressed:
                _loadArrivals,
                style:
                ElevatedButton
                    .styleFrom(
                  backgroundColor:
                  primaryBlue,
                  foregroundColor:
                  Colors.white,
                  elevation: 0,
                  shape:
                  RoundedRectangleBorder(
                    borderRadius:
                    BorderRadius
                        .circular(
                      12,
                    ),
                  ),
                ),
                child:
                const Text(
                  'Try Again',
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_arrivals.isEmpty) {
      return Container(
        width: double.infinity,
        padding:
        const EdgeInsets.all(
          24,
        ),
        decoration:
        BoxDecoration(
          color: Colors.white,
          borderRadius:
          BorderRadius.circular(
            20,
          ),
        ),
        child: Column(
          children: [
            Container(
              width: 55,
              height: 55,
              decoration:
              BoxDecoration(
                color: lightBlue,
                borderRadius:
                BorderRadius
                    .circular(
                  16,
                ),
              ),
              child:
              const Icon(
                Icons.schedule,
                color:
                primaryBlue,
                size: 30,
              ),
            ),
            const SizedBox(
              height: 12,
            ),
            const Text(
              'No upcoming scheduled arrivals found.',
              textAlign:
              TextAlign.center,
              style:
              TextStyle(
                fontWeight:
                FontWeight.w600,
                color:
                Color(0xFF202B3C),
              ),
            ),
            const SizedBox(
              height: 5,
            ),
            const Text(
              'Please try another station.',
              style:
              TextStyle(
                color:
                Color(0xFF8A94A4),
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: _arrivals
          .map(
            (arrival) =>
            _buildArrivalCard(
              arrival,
            ),
      )
          .toList(),
    );
  }

  Widget _buildArrivalCard(
      ArrivalData arrival,
      ) {
    return Container(
      width: double.infinity,
      margin:
      const EdgeInsets.only(
        bottom: 12,
      ),
      padding:
      const EdgeInsets.all(
        14,
      ),
      decoration:
      BoxDecoration(
        color: Colors.white,
        borderRadius:
        BorderRadius.circular(
          18,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black
                .withOpacity(0.04),
            blurRadius: 10,
            offset:
            const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 82,
            padding:
            const EdgeInsets
                .symmetric(
              vertical: 11,
              horizontal: 5,
            ),
            decoration:
            BoxDecoration(
              color: lightBlue,
              borderRadius:
              BorderRadius.circular(
                13,
              ),
            ),
            child: Column(
              children: [
                Text(
                  arrival.arrivalTime,
                  textAlign:
                  TextAlign.center,
                  style:
                  const TextStyle(
                    fontSize: 16,
                    fontWeight:
                    FontWeight.w700,
                    color:
                    Color(0xFF202B3C),
                  ),
                ),
                const SizedBox(
                  height: 4,
                ),
                const Text(
                  'Arrival',
                  style:
                  TextStyle(
                    fontSize: 11,
                    color:
                    Color(0xFF8A94A4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(
            width: 14,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(
                  arrival.line,
                  style:
                  const TextStyle(
                    fontSize: 16,
                    fontWeight:
                    FontWeight.w700,
                    color:
                    Color(0xFF202B3C),
                  ),
                ),
                const SizedBox(
                  height: 6,
                ),
                Row(
                  children: [
                    const Icon(
                      Icons.schedule,
                      size: 14,
                      color: green,
                    ),
                    const SizedBox(
                      width: 5,
                    ),
                    Text(
                      arrival.status,
                      style:
                      const TextStyle(
                        fontSize: 13,
                        color: green,
                        fontWeight:
                        FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            width: 34,
            height: 34,
            decoration:
            BoxDecoration(
              color:
              const Color(
                0xFFF4F6FA,
              ),
              borderRadius:
              BorderRadius.circular(
                10,
              ),
            ),
            child:
            const Icon(
              Icons.chevron_right,
              color:
              Color(0xFF8A94A4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataSourceCard() {
    return Container(
      width: double.infinity,
      padding:
      const EdgeInsets.all(
        16,
      ),
      decoration:
      BoxDecoration(
        color: lightBlue,
        borderRadius:
        BorderRadius.circular(
          18,
        ),
        border: Border.all(
          color:
          const Color(
            0xFFD5E5F8,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration:
            BoxDecoration(
              color: Colors.white,
              borderRadius:
              BorderRadius.circular(
                11,
              ),
            ),
            child:
            const Icon(
              Icons.info_outline,
              color: primaryBlue,
              size: 21,
            ),
          ),
          const SizedBox(
            width: 12,
          ),
          const Expanded(
            child: Text(
              'Arrival information is based on '
                  'Government GTFS Static Data and '
                  'represents scheduled arrival times. '
                  'It is not real-time vehicle tracking.',
              style:
              TextStyle(
                fontSize: 12.5,
                height: 1.45,
                color:
                Color(0xFF536174),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(
      IconData icon,
      String title,
      String value, {
        Color? valueColor,
      }) {
    return Padding(
      padding:
      const EdgeInsets.symmetric(
        vertical: 13,
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration:
            BoxDecoration(
              color: lightBlue,
              borderRadius:
              BorderRadius.circular(
                10,
              ),
            ),
            child: Icon(
              icon,
              size: 19,
              color: primaryBlue,
            ),
          ),
          const SizedBox(
            width: 12,
          ),
          Expanded(
            child: Text(
              title,
              style:
              const TextStyle(
                fontSize: 14,
                color:
                Color(0xFF7D8797),
              ),
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign:
              TextAlign.right,
              style:
              TextStyle(
                fontSize: 14,
                fontWeight:
                FontWeight.w700,
                color: valueColor ??
                    const Color(
                      0xFF202B3C,
                    ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() {
    return const Divider(
      height: 1,
      color:
      Color(0xFFE8EDF4),
    );
  }
}