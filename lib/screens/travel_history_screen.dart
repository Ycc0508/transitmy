import 'package:flutter/material.dart';

class TravelHistoryScreen extends StatelessWidget {
  const TravelHistoryScreen({super.key});

  static const Color primaryBlue = Color(0xFF2F68B1);

  static final List<Map<String, String>> _history = [
    {
      'date': '2026-09-05',
      'from': 'KL Sentral',
      'to': 'Bukit Bintang',
      'line': 'MRT Kajang Line',
      'duration': '12 min',
    },
    {
      'date': '2026-09-04',
      'from': 'Pasar Seni',
      'to': 'Dang Wangi',
      'line': 'LRT Kelana Jaya Line',
      'duration': '8 min',
    },
    {
      'date': '2026-09-03',
      'from': 'Masjid Jamek',
      'to': 'Sri Petaling',
      'line': 'LRT Ampang Line',
      'duration': '22 min',
    },
    {
      'date': '2026-09-01',
      'from': 'KL Sentral',
      'to': 'Putrajaya Sentral',
      'line': 'MRT Putrajaya Line',
      'duration': '38 min',
    },
    {
      'date': '2026-08-30',
      'from': 'Imbi',
      'to': 'KL Sentral',
      'line': 'KL Monorail',
      'duration': '10 min',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: primaryBlue,
        foregroundColor: Colors.white,
        title: const Text('Travel History'),
      ),
      body: _history.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 64, color: Colors.grey),
                  SizedBox(height: 12),
                  Text('No travel history yet', style: TextStyle(color: Colors.grey, fontSize: 16)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _history.length,
              itemBuilder: (context, index) {
                final trip = _history[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEAF3FF),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.train, color: primaryBlue, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${trip['from']} → ${trip['to']}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                trip['line'] ?? '',
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              trip['date'] ?? '',
                              style: const TextStyle(fontSize: 11, color: Colors.grey),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              trip['duration'] ?? '',
                              style: const TextStyle(
                                fontSize: 12,
                                color: primaryBlue,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
