import 'package:flutter/material.dart';

import '../data/route_data.dart';
import '../models/route_option.dart';
import 'route_details_screen.dart';

class RoutePlannerScreen extends StatefulWidget {
  const RoutePlannerScreen({super.key});

  @override
  State<RoutePlannerScreen> createState() => _RoutePlannerScreenState();
}

class _RoutePlannerScreenState extends State<RoutePlannerScreen> {
  // ============================================================
  // COLORS - TRANSITMY DESIGN
  // ============================================================

  static const Color primaryBlue = Color(0xFF2F68B1);
  static const Color darkBlue = Color(0xFF174A87);
  static const Color lightBlue = Color(0xFFEAF3FF);
  static const Color backgroundColor = Color(0xFFF7F9FD);
  static const Color orange = Color(0xFFFF8A65);

  // ============================================================
  // CONTROLLERS
  // ============================================================

  final TextEditingController _fromController =
  TextEditingController();

  final TextEditingController _toController =
  TextEditingController();

  final FocusNode _fromFocusNode = FocusNode();
  final FocusNode _toFocusNode = FocusNode();

  // ============================================================
  // GTFS STATIONS
  // ============================================================

  List<String> _stations = [];

  bool _isLoadingStations = true;

  // ============================================================
  // ROUTES
  // ============================================================

  List<RouteOption> _routes = [];

  bool _isLoading = false;

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    _loadStations();
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _fromController.dispose();
    _toController.dispose();

    _fromFocusNode.dispose();
    _toFocusNode.dispose();

    super.dispose();
  }

  // ============================================================
  // LOAD STATIONS
  // ============================================================

  Future<void> _loadStations() async {
    try {
      final stations = await RouteData.getStations();

      if (!mounted) {
        return;
      }

      setState(() {
        _stations = stations;
        _isLoadingStations = false;
      });

      print(
        'Route Planner loaded '
            '${_stations.length} GTFS stations.',
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoadingStations = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to load stations: $e',
          ),
        ),
      );
    }
  }

  // ============================================================
  // FIND ROUTE
  // ============================================================

  Future<void> _findRoute() async {
    final from = _fromController.text.trim();
    final to = _toController.text.trim();

    if (from.isEmpty || to.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please enter both stations.',
          ),
        ),
      );

      return;
    }

    if (from.toLowerCase() == to.toLowerCase()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'From and To stations cannot be the same.',
          ),
        ),
      );

      return;
    }

    setState(() {
      _isLoading = true;
      _routes = [];
    });

    try {
      final routeResults = await RouteData.findRoutes(
        from,
        to,
      );

      if (!mounted) {
        return;
      }

      // ========================================================
      // CONVERT RouteResult -> RouteOption
      // ========================================================

      final routeOptions = routeResults.map(
            (route) {
          return RouteOption(
            transport: 'Rapid Rail',
            line: route.lineName,
            from: from,
            to: to,
            duration: route.duration,
            transfers: route.transfers,
            nextArrival: 'Scheduled',
            followingArrival: 'Scheduled',
            status: 'Scheduled',
          );
        },
      ).toList();

      setState(() {
        _routes = routeOptions;
      });

      if (_routes.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No route found for the selected stations.',
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to find route: $e',
          ),
        ),
      );
    } finally {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
      });
    }
  }

  // ============================================================
  // CLEAR
  // ============================================================

  void _clearRoute() {
    setState(() {
      _fromController.clear();
      _toController.clear();
      _routes = [];
    });
  }

  // ============================================================
  // SWAP STATIONS
  // ============================================================

  void _swapStations() {
    final from = _fromController.text;
    final to = _toController.text;

    setState(() {
      _fromController.text = to;
      _toController.text = from;
      _routes = [];
    });
  }

  // ============================================================
  // STATION AUTOCOMPLETE
  // ============================================================

  Widget _buildStationField({
    required String label,
    required String hint,
    required IconData icon,
    required TextEditingController controller,
    required FocusNode focusNode,
  }) {
    return RawAutocomplete<String>(
      textEditingController: controller,
      focusNode: focusNode,

      displayStringForOption: (station) => station,

      optionsBuilder: (TextEditingValue value) {
        final query = value.text.trim().toLowerCase();

        if (query.isEmpty) {
          return const Iterable<String>.empty();
        }

        return _stations
            .where(
              (station) =>
              station.toLowerCase().contains(query),
        )
            .take(10);
      },

      onSelected: (String station) {
        controller.text = station;
      },

      // ========================================================
      // TEXT FIELD
      // ========================================================

      fieldViewBuilder: (
          BuildContext context,
          TextEditingController fieldController,
          FocusNode fieldFocusNode,
          VoidCallback onFieldSubmitted,
          ) {
        return TextField(
          controller: fieldController,
          focusNode: fieldFocusNode,

          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Color(0xFF202B3C),
          ),

          decoration: InputDecoration(
            labelText: label,
            hintText: _isLoadingStations
                ? 'Loading stations...'
                : hint,

            labelStyle: const TextStyle(
              color: Colors.grey,
            ),

            hintStyle: const TextStyle(
              color: Color(0xFF9AA5B5),
              fontSize: 14,
            ),

            prefixIcon: Container(
              margin: const EdgeInsets.all(10),
              padding: const EdgeInsets.all(8),

              decoration: BoxDecoration(
                color: lightBlue,
                borderRadius: BorderRadius.circular(10),
              ),

              child: Icon(
                icon,
                color: primaryBlue,
                size: 21,
              ),
            ),

            filled: true,
            fillColor: Colors.white,

            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 17,
            ),

            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(
                color: Color(0xFFDDE5F0),
              ),
            ),

            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(
                color: primaryBlue,
                width: 1.5,
              ),
            ),
          ),

          onSubmitted: (_) {
            onFieldSubmitted();
          },
        );
      },

      // ========================================================
      // DROPDOWN
      // ========================================================

      optionsViewBuilder: (
          BuildContext context,
          AutocompleteOnSelected<String> onSelected,
          Iterable<String> options,
          ) {
        return Align(
          alignment: Alignment.topLeft,

          child: Material(
            elevation: 8,

            borderRadius: BorderRadius.circular(16),

            color: Colors.white,

            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxHeight: 280,
                maxWidth: 600,
              ),

              child: ListView.builder(
                padding: const EdgeInsets.symmetric(
                  vertical: 8,
                ),

                shrinkWrap: true,

                itemCount: options.length,

                itemBuilder: (context, index) {
                  final station = options.elementAt(index);

                  return InkWell(
                    onTap: () {
                      onSelected(station);
                    },

                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 13,
                      ),

                      child: Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,

                            decoration: BoxDecoration(
                              color: lightBlue,
                              borderRadius:
                              BorderRadius.circular(10),
                            ),

                            child: const Icon(
                              Icons.train,
                              color: primaryBlue,
                              size: 20,
                            ),
                          ),

                          const SizedBox(width: 12),

                          Expanded(
                            child: Text(
                              station,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),

                          const Icon(
                            Icons.chevron_right,
                            color: Color(0xFF9AA5B5),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,

      appBar: AppBar(
        backgroundColor: Colors.white,

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
          'Route Planner',
          style: TextStyle(
            color: darkBlue,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),

      body: SingleChildScrollView(
        child: Column(
          children: [
            // ==================================================
            // BLUE HEADER
            // ==================================================

            _buildHeader(),

            // ==================================================
            // CONTENT
            // ==================================================

            Padding(
              padding: const EdgeInsets.fromLTRB(
                18,
                20,
                18,
                30,
              ),

              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,

                children: [
                  // ============================================
                  // TITLE
                  // ============================================

                  const Text(
                    'Plan Your Journey',
                    style: TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF172033),
                    ),
                  ),

                  const SizedBox(height: 6),

                  Text(
                    _isLoadingStations
                        ? 'Loading Government GTFS stations...'
                        : 'Choose your departure and destination',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF7D8797),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ============================================
                  // LOCATION CARD
                  // ============================================

                  _buildLocationCard(),

                  const SizedBox(height: 20),

                  // ============================================
                  // BUTTONS
                  // ============================================

                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 52,

                          child: ElevatedButton.icon(
                            onPressed:
                            _isLoading ||
                                _isLoadingStations
                                ? null
                                : _findRoute,

                            icon: _isLoading
                                ? const SizedBox(
                              width: 19,
                              height: 19,
                              child:
                              CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                                : const Icon(
                              Icons.search,
                              size: 21,
                            ),

                            label: Text(
                              _isLoading
                                  ? 'Searching...'
                                  : 'Find Route',
                            ),

                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryBlue,
                              foregroundColor: Colors.white,

                              disabledBackgroundColor:
                              const Color(0xFFB8C8DE),

                              disabledForegroundColor:
                              Colors.white,

                              elevation: 0,

                              shape: RoundedRectangleBorder(
                                borderRadius:
                                BorderRadius.circular(15),
                              ),

                              textStyle: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(width: 12),

                      SizedBox(
                        height: 52,

                        child: OutlinedButton(
                          onPressed:
                          _isLoading
                              ? null
                              : _clearRoute,

                          style: OutlinedButton.styleFrom(
                            foregroundColor: primaryBlue,

                            side: const BorderSide(
                              color: primaryBlue,
                            ),

                            shape: RoundedRectangleBorder(
                              borderRadius:
                              BorderRadius.circular(15),
                            ),
                          ),

                          child: const Text(
                            'Clear',
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 28),

                  // ============================================
                  // RESULTS
                  // ============================================

                  if (_routes.isNotEmpty) ...[
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Suggested Routes',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF172033),
                            ),
                          ),
                        ),

                        Container(
                          padding:
                          const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),

                          decoration: BoxDecoration(
                            color: lightBlue,
                            borderRadius:
                            BorderRadius.circular(20),
                          ),

                          child: Text(
                            '${_routes.length} route'
                                '${_routes.length == 1 ? '' : 's'}',
                            style: const TextStyle(
                              color: primaryBlue,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    ..._routes.map(
                          (route) => _buildRouteCard(route),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget _buildHeader() {
    return Container(
      width: double.infinity,

      padding: const EdgeInsets.fromLTRB(
        20,
        20,
        20,
        24,
      ),

      decoration: const BoxDecoration(
        color: primaryBlue,

        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),

      child: Row(
        children: [
          // Logo-style icon
          Container(
            width: 55,
            height: 55,

            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(17),
            ),

            child: const Icon(
              Icons.train,
              color: primaryBlue,
              size: 31,
            ),
          ),

          const SizedBox(width: 14),

          const Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,

              children: [
                Text(
                  'TransitMY',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),

                SizedBox(height: 3),

                Text(
                  'Your Smart Public Transport Companion',
                  style: TextStyle(
                    color: Color(0xFFDCEBFF),
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

  // ============================================================
  // LOCATION CARD
  // ============================================================

  Widget _buildLocationCard() {
    return Container(
      width: double.infinity,

      padding: const EdgeInsets.all(16),

      decoration: BoxDecoration(
        color: Colors.white,

        borderRadius: BorderRadius.circular(20),

        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),

      child: Stack(
        alignment: Alignment.centerRight,

        children: [
          Column(
            children: [
              _buildStationField(
                label: 'From',
                hint: 'Search departure station',
                icon: Icons.trip_origin,
                controller: _fromController,
                focusNode: _fromFocusNode,
              ),

              const SizedBox(height: 12),

              _buildStationField(
                label: 'To',
                hint: 'Search destination station',
                icon: Icons.location_on,
                controller: _toController,
                focusNode: _toFocusNode,
              ),
            ],
          ),

          // Swap button
          Positioned(
            right: 14,
            top: 48,

            child: Material(
              color: Colors.white,

              elevation: 3,

              shape: const CircleBorder(),

              child: InkWell(
                onTap: _swapStations,

                customBorder: const CircleBorder(),

                child: Container(
                  width: 42,
                  height: 42,

                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFDDE5F0),
                    ),
                  ),

                  child: const Icon(
                    Icons.swap_vert,
                    color: primaryBlue,
                    size: 22,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ROUTE CARD
  // ============================================================

  Widget _buildRouteCard(RouteOption route) {
    return Container(
      width: double.infinity,

      margin: const EdgeInsets.only(
        bottom: 16,
      ),

      decoration: BoxDecoration(
        color: Colors.white,

        borderRadius: BorderRadius.circular(20),

        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),

      child: Padding(
        padding: const EdgeInsets.all(18),

        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,

          children: [
            // ==================================================
            // TRANSPORT
            // ==================================================

            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,

                  decoration: BoxDecoration(
                    color: lightBlue,
                    borderRadius:
                    BorderRadius.circular(14),
                  ),

                  child: const Icon(
                    Icons.train,
                    color: primaryBlue,
                    size: 25,
                  ),
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,

                    children: [
                      Text(
                        route.transport,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight:
                          FontWeight.w700,
                          color: Color(0xFF172033),
                        ),
                      ),

                      const SizedBox(height: 4),

                      Text(
                        route.line.isEmpty
                            ? 'Rapid Rail'
                            : route.line,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF7D8797),
                        ),
                      ),
                    ],
                  ),
                ),

                Container(
                  padding:
                  const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),

                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF8EF),
                    borderRadius:
                    BorderRadius.circular(20),
                  ),

                  child: const Text(
                    'Scheduled',
                    style: TextStyle(
                      color: Color(0xFF279A4B),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 18),

            // ==================================================
            // JOURNEY
            // ==================================================

            Row(
              crossAxisAlignment:
              CrossAxisAlignment.start,

              children: [
                Column(
                  children: [
                    const Icon(
                      Icons.trip_origin,
                      color: primaryBlue,
                      size: 19,
                    ),

                    Container(
                      height: 28,
                      width: 2,
                      margin:
                      const EdgeInsets.symmetric(
                        vertical: 3,
                      ),
                      color:
                      const Color(0xFFBBD2EF),
                    ),

                    const Icon(
                      Icons.location_on,
                      color: orange,
                      size: 20,
                    ),
                  ],
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,

                    children: [
                      const Text(
                        'From',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF8A94A4),
                        ),
                      ),

                      const SizedBox(height: 2),

                      Text(
                        route.from,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight:
                          FontWeight.w600,
                          color: Color(0xFF202B3C),
                        ),
                      ),

                      const SizedBox(height: 18),

                      const Text(
                        'To',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF8A94A4),
                        ),
                      ),

                      const SizedBox(height: 2),

                      Text(
                        route.to,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight:
                          FontWeight.w600,
                          color: Color(0xFF202B3C),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 18),

            const Divider(
              color: Color(0xFFE8EDF4),
            ),

            const SizedBox(height: 14),

            // ==================================================
            // INFORMATION
            // ==================================================

            Row(
              children: [
                Expanded(
                  child: _infoItem(
                    Icons.access_time,
                    '${route.duration} min',
                    'Duration',
                  ),
                ),

                Container(
                  width: 1,
                  height: 35,
                  color: const Color(0xFFE3E8F0),
                ),

                Expanded(
                  child: _infoItem(
                    Icons.swap_horiz,
                    '${route.transfers}',
                    'Transfer',
                  ),
                ),

                Container(
                  width: 1,
                  height: 35,
                  color: const Color(0xFFE3E8F0),
                ),

                Expanded(
                  child: _infoItem(
                    Icons.schedule,
                    route.nextArrival,
                    'Arrival',
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // ==================================================
            // VIEW DETAILS
            // ==================================================

            SizedBox(
              width: double.infinity,

              height: 46,

              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,

                    MaterialPageRoute(
                      builder: (context) =>
                          RouteDetailsScreen(
                            route: route,
                          ),
                    ),
                  );
                },

                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryBlue,
                  foregroundColor: Colors.white,

                  elevation: 0,

                  shape: RoundedRectangleBorder(
                    borderRadius:
                    BorderRadius.circular(13),
                  ),
                ),

                child: const Row(
                  mainAxisAlignment:
                  MainAxisAlignment.center,

                  children: [
                    Text(
                      'View Route Details',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    SizedBox(width: 7),

                    Icon(
                      Icons.arrow_forward,
                      size: 18,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // INFO ITEM
  // ============================================================

  Widget _infoItem(
      IconData icon,
      String value,
      String label,
      ) {
    return Column(
      children: [
        Icon(
          icon,
          size: 19,
          color: primaryBlue,
        ),

        const SizedBox(height: 5),

        Text(
          value,
          textAlign: TextAlign.center,

          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Color(0xFF202B3C),
          ),
        ),

        const SizedBox(height: 2),

        Text(
          label,
          textAlign: TextAlign.center,

          style: const TextStyle(
            fontSize: 11,
            color: Color(0xFF8A94A4),
          ),
        ),
      ],
    );
  }
}