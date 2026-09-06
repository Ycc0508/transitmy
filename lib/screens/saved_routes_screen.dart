import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../data/route_data.dart';

class SavedRoutesScreen extends StatefulWidget {
  const SavedRoutesScreen({super.key});

  @override
  State<SavedRoutesScreen> createState() => _SavedRoutesScreenState();
}

class _SavedRoutesScreenState extends State<SavedRoutesScreen> {
  static const Color primaryBlue = Color(0xFF2F68B1);

  static const List<String> _lines = [
    'MRT Kajang Line',
    'MRT Putrajaya Line',
    'LRT Kelana Jaya Line',
    'LRT Ampang Line',
    'KL Monorail',
    'Rapid Bus KL',
  ];

  List<Map<String, String>> _savedRoutes = [];
  List<String> _allStations = [];
  bool _stationsLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadRoutes();
    _loadStations();
  }

  Future<void> _loadStations() async {
    try {
      final stations = await RouteData.getStations();
      if (mounted) {
        setState(() {
          _allStations = stations;
          _stationsLoaded = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _stationsLoaded = true);
    }
  }

  Future<void> _loadRoutes() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('saved_routes') ?? '[]';
    final List decoded = jsonDecode(raw);
    setState(() {
      _savedRoutes = decoded.map((e) => Map<String, String>.from(e)).toList();
    });
  }

  Future<void> _saveRoutes() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('saved_routes', jsonEncode(_savedRoutes));
  }

  void _deleteRoute(int index) {
    setState(() {
      _savedRoutes.removeAt(index);
    });
    _saveRoutes();
  }

  Future<String?> _pickStation(BuildContext dialogContext, String title) {
    return showModalBottomSheet<String>(
      context: dialogContext,
      isScrollControlled: true,
      builder: (context) => _StationPicker(
        title: title,
        stations: _allStations,
      ),
    );
  }

  void _showAddDialog() async {
    if (!_stationsLoaded) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Loading stations, please wait...')),
      );
      return;
    }

    String selectedLine = _lines[0];
    String? selectedFrom;
    String? selectedTo;

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Add Route'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: selectedLine,
                decoration: const InputDecoration(
                  labelText: 'Line / Service',
                  border: OutlineInputBorder(),
                ),
                items: _lines
                    .map((l) => DropdownMenuItem(value: l, child: Text(l, style: const TextStyle(fontSize: 13))))
                    .toList(),
                onChanged: (value) {
                  if (value != null) setDialogState(() => selectedLine = value);
                },
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.radio_button_checked, size: 18),
                label: Text(
                  selectedFrom ?? 'Select From Station',
                  overflow: TextOverflow.ellipsis,
                ),
                style: OutlinedButton.styleFrom(
                  alignment: Alignment.centerLeft,
                  minimumSize: const Size(double.infinity, 48),
                ),
                onPressed: () async {
                  final picked = await _pickStation(dialogContext, 'From Station');
                  if (picked != null) {
                    setDialogState(() => selectedFrom = picked);
                  }
                },
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.location_on_outlined, size: 18),
                label: Text(
                  selectedTo ?? 'Select To Station',
                  overflow: TextOverflow.ellipsis,
                ),
                style: OutlinedButton.styleFrom(
                  alignment: Alignment.centerLeft,
                  minimumSize: const Size(double.infinity, 48),
                ),
                onPressed: () async {
                  final picked = await _pickStation(dialogContext, 'To Station');
                  if (picked != null) {
                    setDialogState(() => selectedTo = picked);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (selectedFrom == null || selectedTo == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please select both stations')),
                  );
                  return;
                }
                if (selectedFrom == selectedTo) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('From and To cannot be the same')),
                  );
                  return;
                }
                setState(() {
                  _savedRoutes.add({
                    'from': selectedFrom!,
                    'to': selectedTo!,
                    'line': selectedLine,
                  });
                });
                _saveRoutes();
                Navigator.pop(dialogContext);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: primaryBlue,
        foregroundColor: Colors.white,
        title: const Text('Saved Routes'),
      ),
      body: _savedRoutes.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.bookmark_border, size: 64, color: Colors.grey),
                  const SizedBox(height: 12),
                  const Text('No saved routes yet', style: TextStyle(color: Colors.grey, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text(
                    _stationsLoaded ? 'Tap + to save a route' : 'Loading stations...',
                    style: const TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _savedRoutes.length,
              itemBuilder: (context, index) {
                final route = _savedRoutes[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFEAF3FF),
                      child: Icon(Icons.route, color: primaryBlue),
                    ),
                    title: Text(
                      '${route['from']} → ${route['to']}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(route['line'] ?? ''),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.grey),
                      onPressed: () => _deleteRoute(index),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: primaryBlue,
        foregroundColor: Colors.white,
        onPressed: _showAddDialog,
        child: _stationsLoaded
            ? const Icon(Icons.add)
            : const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              ),
      ),
    );
  }
}

class _StationPicker extends StatefulWidget {
  final String title;
  final List<String> stations;

  const _StationPicker({required this.title, required this.stations});

  @override
  State<_StationPicker> createState() => _StationPickerState();
}

class _StationPickerState extends State<_StationPicker> {
  static const Color primaryBlue = Color(0xFF2F68B1);
  final TextEditingController _searchCtrl = TextEditingController();
  List<String> _filtered = [];

  @override
  void initState() {
    super.initState();
    _filtered = widget.stations;
    _searchCtrl.addListener(() {
      final q = _searchCtrl.text.toLowerCase();
      setState(() {
        _filtered = widget.stations
            .where((s) => s.toLowerCase().contains(q))
            .toList();
      });
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchCtrl,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Search station...',
                prefixIcon: const Icon(Icons.search, color: primaryBlue),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: widget.stations.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    controller: scrollController,
                    itemCount: _filtered.length,
                    itemBuilder: (context, index) {
                      final station = _filtered[index];
                      return ListTile(
                        leading: const Icon(Icons.train, color: primaryBlue),
                        title: Text(station),
                        onTap: () => Navigator.pop(context, station),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
