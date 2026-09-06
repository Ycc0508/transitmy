import 'dart:math';
import 'package:flutter/material.dart';



// ======================================================
// APP
// ======================================================

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Rapid Transport Finder',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
        ),
        useMaterial3: true,
      ),
      home: const TransportHomePage(),
    );
  }
}

// ======================================================
// TRANSPORT MODEL
// ======================================================

class Transport {
  final String id;
  final String name;
  final String type;
  final String line;
  final String code;

  final double latitude;
  final double longitude;

  final String address;
  final String operator;

  Transport({
    required this.id,
    required this.name,
    required this.type,
    required this.line,
    required this.code,
    required this.latitude,
    required this.longitude,
    required this.address,
    required this.operator,
  });
}

// ======================================================
// REAL TRANSPORT DATA
// ======================================================
//
// Coordinates are based on publicly available transport/
// mapping data.
//
// NOTE:
// This is a static dataset for the assignment.
// It is NOT live GPS data.
//
// ======================================================

final List<Transport> transportList = [

  // ====================================================
  // RAPID BUS
  // ====================================================

  Transport(
    id: 'BUS_WANGSA_MAJU',
    name: 'LRT Wangsa Maju',
    type: 'Bus',
    line: 'Rapid KL Bus',
    code: 'Wangsa Maju Bus Stop',
    latitude: 3.20501,
    longitude: 101.73235,
    address: 'Wangsa Maju, Kuala Lumpur',
    operator: 'Rapid Bus Sdn Bhd',
  ),

  Transport(
    id: 'BUS_WANGSA_MAJU_LRT',
    name: 'Wangsa Maju LRT Bus Stop',
    type: 'Bus',
    line: 'Rapid KL Bus',
    code: 'Near Wangsa Maju LRT',
    latitude: 3.20501,
    longitude: 101.73235,
    address: 'Wangsa Maju, Kuala Lumpur',
    operator: 'Rapid Bus Sdn Bhd',
  ),

  // ====================================================
  // LRT
  // ====================================================

  Transport(
    id: 'KJ3',
    name: 'Wangsa Maju',
    type: 'LRT',
    line: 'Kelana Jaya Line',
    code: 'KJ3',
    latitude: 3.20556,
    longitude: 101.73139,
    address:
    'Jalan 1/27A, Section 2, Wangsa Maju, 53300 Kuala Lumpur',
    operator: 'Rapid Rail',
  ),

  Transport(
    id: 'KJ4',
    name: 'Sri Rampai',
    type: 'LRT',
    line: 'Kelana Jaya Line',
    code: 'KJ4',
    latitude: 3.19889,
    longitude: 101.73694,
    address:
    'Jalan Wangsa Perdana 1, Taman Sri Rampai, 53300 Kuala Lumpur',
    operator: 'Rapid Rail',
  ),

  Transport(
    id: 'KJ5',
    name: 'Setiawangsa',
    type: 'LRT',
    line: 'Kelana Jaya Line',
    code: 'KJ5',
    latitude: 3.17571,
    longitude: 101.73586,
    address:
    'Jalan Jelatek, AU1, Taman Setiawangsa, 54200 Kuala Lumpur',
    operator: 'Rapid Rail',
  ),

  // ====================================================
  // MRT
  // ====================================================

  Transport(
    id: 'PY20',
    name: 'Ampang Park',
    type: 'MRT',
    line: 'Putrajaya Line',
    code: 'PY20',
    latitude: 3.15972,
    longitude: 101.71861,
    address:
    'Jalan Ampang, Kuala Lumpur',
    operator: 'Rapid Rail',
  ),
];

// ======================================================
// HOME PAGE
// ======================================================

class TransportHomePage extends StatefulWidget {
  const TransportHomePage({super.key});

  @override
  State<TransportHomePage> createState() =>
      _TransportHomePageState();
}

class _TransportHomePageState
    extends State<TransportHomePage> {

  // ----------------------------------------------------
  // USER LOCATION
  // ----------------------------------------------------
  //
  // Temporary reference location.
  //
  // Later we can replace this with actual GPS.
  //
  // ----------------------------------------------------

  final double userLatitude = 3.2050;
  final double userLongitude = 101.7320;

  String searchText = '';

  String selectedFilter = 'All';

  final Set<String> favouriteIds = {};

  // ====================================================
  // DISTANCE CALCULATION
  // ====================================================

  double calculateDistance(
      double lat1,
      double lon1,
      double lat2,
      double lon2,
      ) {

    const double earthRadius = 6371;

    final double dLat =
        (lat2 - lat1) * pi / 180;

    final double dLon =
        (lon2 - lon1) * pi / 180;

    final double a =
        sin(dLat / 2) * sin(dLat / 2) +
            cos(lat1 * pi / 180) *
                cos(lat2 * pi / 180) *
                sin(dLon / 2) *
                sin(dLon / 2);

    final double c =
        2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

  // ====================================================
  // FILTER + SEARCH + SORT
  // ====================================================

  List<Transport> get filteredTransport {

    List<Transport> result =
    List.from(transportList);

    // --------------------------------------------------
    // SEARCH
    // --------------------------------------------------

    if (searchText.isNotEmpty) {

      final query =
      searchText.toLowerCase();

      result = result.where((transport) {

        return transport.name
            .toLowerCase()
            .contains(query) ||
            transport.type
                .toLowerCase()
                .contains(query) ||
            transport.line
                .toLowerCase()
                .contains(query) ||
            transport.code
                .toLowerCase()
                .contains(query);

      }).toList();
    }

    // --------------------------------------------------
    // FILTER
    // --------------------------------------------------

    if (selectedFilter != 'All') {

      result = result.where(
            (transport) =>
        transport.type == selectedFilter,
      ).toList();
    }

    // --------------------------------------------------
    // SORT BY DISTANCE
    // --------------------------------------------------

    result.sort((a, b) {

      final distanceA =
      calculateDistance(
        userLatitude,
        userLongitude,
        a.latitude,
        a.longitude,
      );

      final distanceB =
      calculateDistance(
        userLatitude,
        userLongitude,
        b.latitude,
        b.longitude,
      );

      return distanceA.compareTo(distanceB);
    });

    return result;
  }

  // ====================================================
  // FAVOURITE
  // ====================================================

  void toggleFavourite(String id) {

    setState(() {

      if (favouriteIds.contains(id)) {

        favouriteIds.remove(id);

      } else {

        favouriteIds.add(id);
      }
    });
  }

  // ====================================================
  // OPEN DETAILS
  // ====================================================

  void openDetails(Transport transport) {

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            TransportDetailsPage(
              transport: transport,
              distance: calculateDistance(
                userLatitude,
                userLongitude,
                transport.latitude,
                transport.longitude,
              ),
              isFavourite:
              favouriteIds.contains(
                transport.id,
              ),
              onFavouriteChanged: () {

                toggleFavourite(
                  transport.id,
                );
              },
            ),
      ),
    );
  }

  // ====================================================
  // BUILD
  // ====================================================

  @override
  Widget build(BuildContext context) {

    final transports =
        filteredTransport;

    return Scaffold(

      // ==================================================
      // APP BAR
      // ==================================================

      appBar: AppBar(

        title: const Text(
          'Nearby Transport',
        ),

        centerTitle: true,

        actions: [

          IconButton(
            icon: const Icon(
              Icons.star,
            ),

            tooltip: 'Favourites',

            onPressed: () {

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      FavouritesPage(
                        favouriteIds:
                        favouriteIds,
                      ),
                ),
              );
            },
          ),
        ],
      ),

      // ==================================================
      // BODY
      // ==================================================

      body: Column(

        children: [

          // =================================================
          // SEARCH
          // =================================================

          Padding(
            padding:
            const EdgeInsets.all(16),

            child: TextField(

              onChanged: (value) {

                setState(() {

                  searchText = value;
                });
              },

              decoration:
              InputDecoration(

                hintText:
                'Search stops or stations...',

                prefixIcon:
                const Icon(
                  Icons.search,
                ),

                suffixIcon:
                searchText.isNotEmpty
                    ? IconButton(
                  icon:
                  const Icon(
                    Icons.clear,
                  ),

                  onPressed: () {

                    setState(() {

                      searchText =
                      '';
                    });
                  },
                )
                    : null,

                border:
                OutlineInputBorder(

                  borderRadius:
                  BorderRadius.circular(
                    15,
                  ),
                ),
              ),
            ),
          ),

          // =================================================
          // FILTER
          // =================================================

          SizedBox(

            height: 50,

            child: ListView(

              scrollDirection:
              Axis.horizontal,

              padding:
              const EdgeInsets.symmetric(
                horizontal: 16,
              ),

              children: [

                buildFilterChip(
                  'All',
                ),

                buildFilterChip(
                  'Bus',
                ),

                buildFilterChip(
                  'LRT',
                ),

                buildFilterChip(
                  'MRT',
                ),
              ],
            ),
          ),

          const SizedBox(
            height: 10,
          ),

          // =================================================
          // RESULT COUNT
          // =================================================

          Padding(

            padding:
            const EdgeInsets.symmetric(
              horizontal: 16,
            ),

            child: Row(

              children: [

                Text(
                  '${transports.length} transport locations found',
                  style:
                  const TextStyle(
                    fontWeight:
                    FontWeight.bold,
                  ),
                ),

                const Spacer(),

                const Icon(
                  Icons.sort,
                  size: 18,
                ),

                const SizedBox(
                  width: 4,
                ),

                const Text(
                  'Nearest first',
                ),
              ],
            ),
          ),

          const SizedBox(
            height: 10,
          ),

          // =================================================
          // LIST
          // =================================================

          Expanded(

            child: transports.isEmpty

                ? const Center(

              child: Column(

                mainAxisAlignment:
                MainAxisAlignment.center,

                children: [

                  Icon(
                    Icons.search_off,
                    size: 60,
                  ),

                  SizedBox(
                    height: 15,
                  ),

                  Text(
                    'No transport found',
                    style:
                    TextStyle(
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            )

                : ListView.builder(

              padding:
              const EdgeInsets
                  .symmetric(
                horizontal: 16,
              ),

              itemCount:
              transports.length,

              itemBuilder:
                  (context, index) {

                final transport =
                transports[index];

                final distance =
                calculateDistance(
                  userLatitude,
                  userLongitude,
                  transport.latitude,
                  transport.longitude,
                );

                return TransportCard(

                  transport:
                  transport,

                  distance:
                  distance,

                  isFavourite:
                  favouriteIds
                      .contains(
                    transport.id,
                  ),

                  onFavourite: () {

                    toggleFavourite(
                      transport.id,
                    );
                  },

                  onTap: () {

                    openDetails(
                      transport,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ====================================================
  // FILTER CHIP
  // ====================================================

  Widget buildFilterChip(
      String filter,
      ) {

    final bool selected =
        selectedFilter == filter;

    return Padding(

      padding:
      const EdgeInsets.only(
        right: 8,
      ),

      child: FilterChip(

        label: Text(filter),

        selected: selected,

        onSelected: (value) {

          setState(() {

            selectedFilter =
                filter;
          });
        },
      ),
    );
  }
}

// ======================================================
// TRANSPORT CARD
// ======================================================

class TransportCard
    extends StatelessWidget {

  final Transport transport;

  final double distance;

  final bool isFavourite;

  final VoidCallback onFavourite;

  final VoidCallback onTap;

  const TransportCard({

    super.key,

    required this.transport,

    required this.distance,

    required this.isFavourite,

    required this.onFavourite,

    required this.onTap,
  });

  @override
  Widget build(
      BuildContext context,
      ) {

    IconData icon;

    if (transport.type == 'Bus') {

      icon =
          Icons.directions_bus;

    } else {

      icon = Icons.train;
    }

    return Card(

      margin:
      const EdgeInsets.only(
        bottom: 10,
      ),

      child: ListTile(

        onTap: onTap,

        leading:
        CircleAvatar(

          child:
          Icon(icon),
        ),

        title: Text(

          transport.name,

          style:
          const TextStyle(
            fontWeight:
            FontWeight.bold,
          ),
        ),

        subtitle:
        Column(

          crossAxisAlignment:
          CrossAxisAlignment.start,

          children: [

            const SizedBox(
              height: 4,
            ),

            Text(
              '${transport.type} • ${transport.line}',
            ),

            const SizedBox(
              height: 4,
            ),

            Text(
              '${distance.toStringAsFixed(2)} km away',
            ),
          ],
        ),

        isThreeLine:
        true,

        trailing:
        IconButton(

          icon:
          Icon(

            isFavourite
                ? Icons.star
                : Icons.star_border,
          ),

          onPressed:
          onFavourite,
        ),
      ),
    );
  }
}

// ======================================================
// DETAILS PAGE
// ======================================================

class TransportDetailsPage
    extends StatelessWidget {

  final Transport transport;

  final double distance;

  final bool isFavourite;

  final VoidCallback
  onFavouriteChanged;

  const TransportDetailsPage({

    super.key,

    required this.transport,

    required this.distance,

    required this.isFavourite,

    required this.onFavouriteChanged,
  });

  @override
  Widget build(
      BuildContext context,
      ) {

    final bool isBus =
        transport.type == 'Bus';

    return Scaffold(

      appBar:
      AppBar(

        title:
        const Text(
          'Transport Details',
        ),

        actions: [

          IconButton(

            icon:
            Icon(

              isFavourite
                  ? Icons.star
                  : Icons.star_border,
            ),

            onPressed:
            onFavouriteChanged,
          ),
        ],
      ),

      body:
      ListView(

        padding:
        const EdgeInsets.all(
          20,
        ),

        children: [

          // ==============================================
          // ICON
          // ==============================================

          CircleAvatar(

            radius: 45,

            child:
            Icon(

              isBus
                  ? Icons.directions_bus
                  : Icons.train,

              size: 45,
            ),
          ),

          const SizedBox(
            height: 20,
          ),

          // ==============================================
          // NAME
          // ==============================================

          Text(

            transport.name,

            textAlign:
            TextAlign.center,

            style:
            const TextStyle(

              fontSize: 26,

              fontWeight:
              FontWeight.bold,
            ),
          ),

          const SizedBox(
            height: 8,
          ),

          Text(

            transport.type,

            textAlign:
            TextAlign.center,

            style:
            const TextStyle(
              fontSize: 17,
            ),
          ),

          const SizedBox(
            height: 30,
          ),

          // ==============================================
          // INFORMATION
          // ==============================================

          InfoTile(

            icon:
            Icons.confirmation_number,

            title:
            'Station / Stop Code',

            value:
            transport.code,
          ),

          InfoTile(

            icon:
            Icons.route,

            title:
            'Line',

            value:
            transport.line,
          ),

          InfoTile(

            icon:
            Icons.business,

            title:
            'Operator',

            value:
            transport.operator,
          ),

          InfoTile(

            icon:
            Icons.location_on,

            title:
            'Distance',

            value:
            '${distance.toStringAsFixed(2)} km',
          ),

          InfoTile(

            icon:
            Icons.place,

            title:
            'Address',

            value:
            transport.address,
          ),

          InfoTile(

            icon:
            Icons.gps_fixed,

            title:
            'Coordinates',

            value:
            '${transport.latitude}, '
                '${transport.longitude}',
          ),

          const SizedBox(
            height: 20,
          ),

          // ==============================================
          // SOURCE NOTE
          // ==============================================

          Card(

            child:
            Padding(

              padding:
              const EdgeInsets.all(
                16,
              ),

              child:
              Row(

                crossAxisAlignment:
                CrossAxisAlignment.start,

                children: [

                  const Icon(
                    Icons.info_outline,
                  ),

                  const SizedBox(
                    width: 12,
                  ),

                  Expanded(

                    child:
                    Text(

                      'Transport information is '
                          'based on publicly available '
                          'Rapid KL / Prasarana transport '
                          'data.',

                      style:
                      TextStyle(
                        color:
                        Colors.grey[700],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ======================================================
// INFO TILE
// ======================================================

class InfoTile
    extends StatelessWidget {

  final IconData icon;

  final String title;

  final String value;

  const InfoTile({

    super.key,

    required this.icon,

    required this.title,

    required this.value,
  });

  @override
  Widget build(
      BuildContext context,
      ) {

    return Card(

      margin:
      const EdgeInsets.only(
        bottom: 8,
      ),

      child:
      ListTile(

        leading:
        Icon(icon),

        title:
        Text(
          title,
          style:
          const TextStyle(
            fontWeight:
            FontWeight.bold,
          ),
        ),

        subtitle:
        Padding(

          padding:
          const EdgeInsets.only(
            top: 4,
          ),

          child:
          Text(value),
        ),
      ),
    );
  }
}

// ======================================================
// FAVOURITES PAGE
// ======================================================

class FavouritesPage
    extends StatefulWidget {

  final Set<String>
  favouriteIds;

  const FavouritesPage({

    super.key,

    required this.favouriteIds,
  });

  @override
  State<FavouritesPage>
  createState() =>
      _FavouritesPageState();
}

class _FavouritesPageState
    extends State<FavouritesPage> {

  void removeFavourite(
      String id,
      ) {

    setState(() {

      widget.favouriteIds
          .remove(id);
    });
  }

  @override
  Widget build(
      BuildContext context,
      ) {

    final favourites =
    transportList
        .where(
          (transport) =>
          widget.favouriteIds
              .contains(
            transport.id,
          ),
    )
        .toList();

    return Scaffold(

      appBar:
      AppBar(

        title:
        const Text(
          'Favourite Transport',
        ),
      ),

      body:

      favourites.isEmpty

          ? const Center(

        child:
        Column(

          mainAxisAlignment:
          MainAxisAlignment
              .center,

          children: [

            Icon(
              Icons.star_border,
              size: 70,
            ),

            SizedBox(
              height: 15,
            ),

            Text(
              'No favourites yet',
              style:
              TextStyle(
                fontSize: 18,
              ),
            ),
          ],
        ),
      )

          : ListView.builder(

        padding:
        const EdgeInsets.all(
          16,
        ),

        itemCount:
        favourites.length,

        itemBuilder:
            (context, index) {

          final transport =
          favourites[index];

          return TransportCard(

            transport:
            transport,

            distance:
            0,

            isFavourite:
            true,

            onFavourite: () {

              removeFavourite(
                transport.id,
              );
            },

            onTap: () {

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder:
                      (context) =>
                      TransportDetailsPage(
                        transport:
                        transport,

                        distance:
                        0,

                        isFavourite:
                        true,

                        onFavouriteChanged:
                            () {

                          removeFavourite(
                            transport.id,
                          );

                          Navigator.pop(
                            context,
                          );
                        },
                      ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}