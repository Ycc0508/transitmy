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
      title: 'Transport Finder',
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
  final String name;
  final String type;
  final String line;
  final double distance;
  final String operatingHours;
  final List<String> facilities;

  Transport({
    required this.name,
    required this.type,
    required this.line,
    required this.distance,
    required this.operatingHours,
    required this.facilities,
  });
}

// ======================================================
// SAMPLE DATA
// ======================================================

final List<Transport> transportList = [
  // ---------------- BUS STOPS ----------------

  Transport(
    name: 'Wangsa Maju Bus Stop',
    type: 'Bus Stop',
    line: 'Rapid KL',
    distance: 0.3,
    operatingHours: '5:30 AM - 12:00 AM',
    facilities: [
      'Bus Shelter',
      'Seating',
      'Information Board',
    ],
  ),

  Transport(
    name: 'Setapak Central Bus Stop',
    type: 'Bus Stop',
    line: 'Rapid KL',
    distance: 0.8,
    operatingHours: '5:30 AM - 12:00 AM',
    facilities: [
      'Bus Shelter',
      'Seating',
    ],
  ),

  Transport(
    name: 'PV128 Bus Stop',
    type: 'Bus Stop',
    line: 'Rapid KL',
    distance: 1.1,
    operatingHours: '5:30 AM - 12:00 AM',
    facilities: [
      'Bus Shelter',
      'Seating',
      'Information Board',
    ],
  ),

  // ---------------- LRT STATIONS ----------------

  Transport(
    name: 'Wangsa Maju LRT Station',
    type: 'LRT',
    line: 'Kelana Jaya Line',
    distance: 1.2,
    operatingHours: '6:00 AM - 12:00 AM',
    facilities: [
      'Lift',
      'Escalator',
      'Toilet',
      'Parking',
    ],
  ),

  Transport(
    name: 'Sri Rampai LRT Station',
    type: 'LRT',
    line: 'Kelana Jaya Line',
    distance: 2.0,
    operatingHours: '6:00 AM - 12:00 AM',
    facilities: [
      'Lift',
      'Escalator',
      'Parking',
    ],
  ),

  Transport(
    name: 'Setiawangsa LRT Station',
    type: 'LRT',
    line: 'Kelana Jaya Line',
    distance: 2.5,
    operatingHours: '6:00 AM - 12:00 AM',
    facilities: [
      'Lift',
      'Escalator',
      'Toilet',
      'Parking',
    ],
  ),

  // ---------------- MRT ----------------

  Transport(
    name: 'Ampang Park MRT Station',
    type: 'MRT',
    line: 'Putrajaya Line',
    distance: 4.8,
    operatingHours: '6:00 AM - 12:00 AM',
    facilities: [
      'Lift',
      'Escalator',
      'Toilet',
      'Parking',
    ],
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

class _TransportHomePageState extends State<TransportHomePage> {
  String searchText = '';

  final Set<String> favouriteNames = {};

  // ----------------------------------------------------
  // SEARCH
  // ----------------------------------------------------

  List<Transport> get filteredTransport {
    if (searchText.isEmpty) {
      return transportList;
    }

    return transportList.where((transport) {
      return transport.name
          .toLowerCase()
          .contains(searchText.toLowerCase()) ||
          transport.type
              .toLowerCase()
              .contains(searchText.toLowerCase()) ||
          transport.line
              .toLowerCase()
              .contains(searchText.toLowerCase());
    }).toList();
  }

  // ----------------------------------------------------
  // TOGGLE FAVOURITE
  // ----------------------------------------------------

  void toggleFavourite(String name) {
    setState(() {
      if (favouriteNames.contains(name)) {
        favouriteNames.remove(name);
      } else {
        favouriteNames.add(name);
      }
    });
  }

  // ----------------------------------------------------
  // OPEN DETAILS
  // ----------------------------------------------------

  void openDetails(Transport transport) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StopDetailsPage(
          transport: transport,
          isFavourite:
          favouriteNames.contains(transport.name),
          onFavouriteChanged: () {
            toggleFavourite(transport.name);
            setState(() {});
          },
        ),
      ),
    );
  }

  // ----------------------------------------------------
  // BUILD
  // ----------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final nearbyBusStops = filteredTransport
        .where((transport) => transport.type == 'Bus Stop')
        .toList();

    final stations = filteredTransport
        .where(
          (transport) =>
      transport.type == 'LRT' ||
          transport.type == 'MRT',
    )
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nearby Transport'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.star),
            tooltip: 'Favourites',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => FavouritesPage(
                    favouriteNames: favouriteNames,
                    onFavouriteChanged: () {
                      setState(() {});
                    },
                  ),
                ),
              );
            },
          ),
        ],
      ),

      body: Column(
        children: [
          // ==================================================
          // SEARCH BAR
          // ==================================================

          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              onChanged: (value) {
                setState(() {
                  searchText = value;
                });
              },
              decoration: InputDecoration(
                hintText: 'Search stops or stations...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: searchText.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    setState(() {
                      searchText = '';
                    });
                  },
                )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
            ),
          ),

          // ==================================================
          // LIST
          // ==================================================

          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
              ),
              children: [
                // --------------------------------------------
                // BUS STOPS
                // --------------------------------------------

                const Text(
                  '🚏 Nearby Bus Stops',
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 10),

                if (nearbyBusStops.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(20),
                    child: Text(
                      'No bus stops found.',
                      textAlign: TextAlign.center,
                    ),
                  ),

                ...nearbyBusStops.map(
                      (transport) => TransportCard(
                    transport: transport,
                    isFavourite:
                    favouriteNames.contains(
                      transport.name,
                    ),
                    onFavourite: () {
                      toggleFavourite(transport.name);
                    },
                    onTap: () {
                      openDetails(transport);
                    },
                  ),
                ),

                const SizedBox(height: 25),

                // --------------------------------------------
                // MRT / LRT
                // --------------------------------------------

                const Text(
                  '🚇 MRT / LRT Stations',
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 10),

                if (stations.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(20),
                    child: Text(
                      'No stations found.',
                      textAlign: TextAlign.center,
                    ),
                  ),

                ...stations.map(
                      (transport) => TransportCard(
                    transport: transport,
                    isFavourite:
                    favouriteNames.contains(
                      transport.name,
                    ),
                    onFavourite: () {
                      toggleFavourite(transport.name);
                    },
                    onTap: () {
                      openDetails(transport);
                    },
                  ),
                ),

                const SizedBox(height: 30),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ======================================================
// TRANSPORT CARD
// ======================================================

class TransportCard extends StatelessWidget {
  final Transport transport;
  final bool isFavourite;
  final VoidCallback onFavourite;
  final VoidCallback onTap;

  const TransportCard({
    super.key,
    required this.transport,
    required this.isFavourite,
    required this.onFavourite,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool isBus = transport.type == 'Bus Stop';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: onTap,

        leading: CircleAvatar(
          child: Icon(
            isBus
                ? Icons.directions_bus
                : Icons.train,
          ),
        ),

        title: Text(
          transport.name,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),

        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),

            Text(transport.line),

            const SizedBox(height: 4),

            Text(
              '${transport.distance.toStringAsFixed(1)} km away',
            ),
          ],
        ),

        isThreeLine: true,

        trailing: IconButton(
          icon: Icon(
            isFavourite
                ? Icons.star
                : Icons.star_border,
          ),
          onPressed: onFavourite,
        ),
      ),
    );
  }
}

// ======================================================
// DETAILS PAGE
// ======================================================

class StopDetailsPage extends StatelessWidget {
  final Transport transport;
  final bool isFavourite;
  final VoidCallback onFavouriteChanged;

  const StopDetailsPage({
    super.key,
    required this.transport,
    required this.isFavourite,
    required this.onFavouriteChanged,
  });

  @override
  Widget build(BuildContext context) {
    final bool isBus =
        transport.type == 'Bus Stop';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transport Details'),
        actions: [
          IconButton(
            icon: Icon(
              isFavourite
                  ? Icons.star
                  : Icons.star_border,
            ),
            onPressed: onFavouriteChanged,
          ),
        ],
      ),

      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ------------------------------------------------
          // ICON
          // ------------------------------------------------

          CircleAvatar(
            radius: 45,
            child: Icon(
              isBus
                  ? Icons.directions_bus
                  : Icons.train,
              size: 45,
            ),
          ),

          const SizedBox(height: 20),

          // ------------------------------------------------
          // NAME
          // ------------------------------------------------

          Text(
            transport.name,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 25,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 10),

          Text(
            transport.type,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 17,
            ),
          ),

          const SizedBox(height: 30),

          // ------------------------------------------------
          // INFORMATION
          // ------------------------------------------------

          InfoTile(
            icon: Icons.route,
            title: 'Line / Operator',
            value: transport.line,
          ),

          InfoTile(
            icon: Icons.location_on,
            title: 'Distance',
            value:
            '${transport.distance.toStringAsFixed(1)} km',
          ),

          InfoTile(
            icon: Icons.access_time,
            title: 'Operating Hours',
            value: transport.operatingHours,
          ),

          const SizedBox(height: 20),

          const Text(
            'Facilities',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 10),

          ...transport.facilities.map(
                (facility) => ListTile(
              leading: const Icon(Icons.check_circle),
              title: Text(facility),
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

class InfoTile extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(
          value,
          style: const TextStyle(
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}

// ======================================================
// FAVOURITES PAGE
// ======================================================

class FavouritesPage extends StatefulWidget {
  final Set<String> favouriteNames;
  final VoidCallback onFavouriteChanged;

  const FavouritesPage({
    super.key,
    required this.favouriteNames,
    required this.onFavouriteChanged,
  });

  @override
  State<FavouritesPage> createState() =>
      _FavouritesPageState();
}

class _FavouritesPageState
    extends State<FavouritesPage> {

  void removeFavourite(String name) {
    setState(() {
      widget.favouriteNames.remove(name);
    });

    widget.onFavouriteChanged();
  }

  @override
  Widget build(BuildContext context) {
    final favourites = transportList
        .where(
          (transport) =>
          widget.favouriteNames.contains(
            transport.name,
          ),
    )
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Favourite Stops'),
      ),

      body: favourites.isEmpty
          ? const Center(
        child: Column(
          mainAxisAlignment:
          MainAxisAlignment.center,
          children: [
            Icon(
              Icons.star_border,
              size: 70,
            ),
            SizedBox(height: 15),
            Text(
              'No favourite stops yet.',
              style: TextStyle(
                fontSize: 18,
              ),
            ),
          ],
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: favourites.length,
        itemBuilder: (context, index) {
          final transport = favourites[index];

          return TransportCard(
            transport: transport,
            isFavourite: true,
            onFavourite: () {
              removeFavourite(
                transport.name,
              );
            },
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      StopDetailsPage(
                        transport: transport,
                        isFavourite: true,
                        onFavouriteChanged: () {
                          removeFavourite(
                            transport.name,
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