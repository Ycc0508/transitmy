import 'package:flutter/material.dart';

import '../data/ridership_api.dart';
import '../models/ridership.dart';

class RidershipScreen extends StatefulWidget {
  const RidershipScreen({super.key});

  @override
  State<RidershipScreen> createState() =>
      _RidershipScreenState();
}

class _RidershipScreenState
    extends State<RidershipScreen> {
  late Future<List<Ridership>> _ridershipFuture;

  @override
  void initState() {
    super.initState();

    _ridershipFuture =
        RidershipApi.fetchRidership();
  }

  Future<void> _refresh() async {
    setState(() {
      _ridershipFuture =
          RidershipApi.fetchRidership();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Public Transport Ridership',
        ),
        actions: [
          IconButton(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<List<Ridership>>(
        future: _ridershipFuture,
        builder: (context, snapshot) {
          // Loading
          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          // Error
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment:
                  MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 50,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Unable to load ridership data.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _refresh,
                      child: const Text(
                        'Try Again',
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          final data = snapshot.data ?? [];

          if (data.isEmpty) {
            return const Center(
              child: Text(
                'No ridership data available.',
              ),
            );
          }

          // Latest record
          final latest = data.first;

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'Latest Ridership',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 6),

                Text(
                  'Date: ${latest.date}',
                  style: const TextStyle(
                    color: Colors.grey,
                  ),
                ),

                const SizedBox(height: 20),

                _buildRidershipCard(
                  title: 'MRT Kajang Line',
                  value: latest.mrtKajang,
                  icon: Icons.train,
                ),

                _buildRidershipCard(
                  title: 'MRT Putrajaya Line',
                  value: latest.mrtPutrajaya,
                  icon: Icons.train,
                ),

                _buildRidershipCard(
                  title: 'LRT Kelana Jaya Line',
                  value: latest.lrtKelanaJaya,
                  icon: Icons.train,
                ),

                _buildRidershipCard(
                  title: 'LRT Ampang Line',
                  value: latest.lrtAmpang,
                  icon: Icons.train,
                ),

                _buildRidershipCard(
                  title: 'KL Monorail',
                  value: latest.monorail,
                  icon: Icons.train,
                ),

                _buildRidershipCard(
                  title: 'Rapid Bus KL',
                  value: latest.rapidBusKL,
                  icon: Icons.directions_bus,
                ),

                const SizedBox(height: 16),

                Card(
                  color: Colors.grey.shade100,
                  child: const Padding(
                    padding: EdgeInsets.all(14),
                    child: Row(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 20,
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Ridership data is obtained from '
                                'the Malaysian Government open '
                                'data platform.',
                            style: TextStyle(
                              fontSize: 13,
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
        },
      ),
    );
  }

  Widget _buildRidershipCard({
    required String title,
    required int value,
    required IconData icon,
  }) {
    return Card(
      margin: const EdgeInsets.only(
        bottom: 12,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius:
                BorderRadius.circular(12),
                color: Colors.blue.withOpacity(0.1),
              ),
              child: Icon(
                icon,
                size: 28,
              ),
            ),

            const SizedBox(width: 16),

            Expanded(
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  const SizedBox(height: 6),

                  Text(
                    _formatNumber(value),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 2),

                  const Text(
                    'Passengers',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
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

  String _formatNumber(int number) {
    return number
        .toString()
        .replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
          (match) => '${match[1]},',
    );
  }
}