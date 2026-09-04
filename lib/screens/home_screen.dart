import 'package:flutter/material.dart';
import '../NearbyStation.dart';
import '../data/ridership_api.dart';
import '../models/ridership.dart';
import 'route_planner_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  final String email;
  final String name;
  final String phone;

  const HomeScreen({
    super.key,
    required this.email,
    this.name = '',
    this.phone = '',
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  static const Color primaryBlue = Color(0xFF2F68B1);
  static const Color lightBlue = Color(0xFFEAF3FF);

  List<Ridership> _ridershipData = [];
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _fetchRidershipData();
  }

  Future<void> _fetchRidershipData() async {
    try {
      final data = await RidershipApi.fetchRidership();
      setState(() {
        _ridershipData = data.take(6).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _hasError = true;
        _isLoading = false;
      });
    }
  }

  void _onNavTap(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Widget _buildHomeTab() {
    final String displayName = widget.name.isNotEmpty ? widget.name : widget.email;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
          decoration: const BoxDecoration(
            color: primaryBlue,
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(24),
              bottomRight: Radius.circular(24),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Welcome, $displayName',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Your Malaysia Public Transit Companion',
                style: TextStyle(fontSize: 13, color: Color(0xFFDCEBFF)),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Card(
                  color: lightBlue,
                  child: const Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Icon(Icons.train, color: primaryBlue, size: 32),
                        SizedBox(height: 8),
                        Text('7 Lines', style: TextStyle(fontWeight: FontWeight.bold)),
                        Text('Rail Network', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Card(
                  color: lightBlue,
                  child: const Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Icon(Icons.location_on, color: primaryBlue, size: 32),
                        SizedBox(height: 8),
                        Text('166 Stations', style: TextStyle(fontWeight: FontWeight.bold)),
                        Text('KL Transit', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              const Text(
                'Rapid Rail Ridership',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Text(
                'Source: data.gov.my',
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        if (_isLoading)
          const Expanded(child: Center(child: CircularProgressIndicator()))
        else if (_hasError)
          const Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.wifi_off, size: 48, color: Colors.grey),
                  SizedBox(height: 8),
                  Text('Unable to load data', style: TextStyle(color: Colors.grey)),
                ],
              ),
            ),
          )
        else
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _ridershipData.length,
              itemBuilder: (context, index) {
                final Ridership item = _ridershipData[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.calendar_today, size: 14, color: primaryBlue),
                            const SizedBox(width: 6),
                            Text(
                              item.date,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: primaryBlue,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _ridershipRow('MRT Kajang', item.mrtKajang),
                        _ridershipRow('MRT Putrajaya', item.mrtPutrajaya),
                        _ridershipRow('LRT Kelana Jaya', item.lrtKelanaJaya),
                        _ridershipRow('LRT Ampang', item.lrtAmpang),
                        _ridershipRow('Monorail', item.monorail),
                        _ridershipRow('Rapid Bus KL', item.rapidBusKL),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _ridershipRow(String label, int value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          const Icon(Icons.train, size: 14, color: Colors.grey),
          const SizedBox(width: 6),
          Expanded(
            child: Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ),
          Text(
            value.toString().replaceAllMapped(
              RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
              (m) => '${m[1]},',
            ),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> tabs = [
      _buildHomeTab(),
      const TransportHomePage(),
      const RoutePlannerScreen(),
      ProfileScreen(
        name: widget.name,
        email: widget.email,
        phone: widget.phone,
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: primaryBlue,
        title: const Text('transitMY', style: TextStyle(color: Colors.white)),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined, color: Colors.white),
            onPressed: () {},
          ),
        ],
      ),
      body: tabs[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onNavTap,
        selectedItemColor: primaryBlue,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.location_on), label: 'Nearby'),
          BottomNavigationBarItem(icon: Icon(Icons.route), label: 'Routes'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
