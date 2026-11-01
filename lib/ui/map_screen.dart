import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../config/env.dart';
import '../map/esri_imagery.dart';
import '../mgrs/mgrs_coordinate.dart';
import 'goto_sheet.dart';

/// Prototype mark: kept in memory only (stage 1). Persistence comes in MVP.
class PrototypeMark {
  PrototypeMark({required this.name, required this.coordinate});

  final String name;
  final MgrsCoordinate coordinate;
}

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  // Centre of Ukraine, overview zoom.
  static const _initialCenter = LatLng(48.5, 31.5);
  static const _initialZoom = 6.0;

  final _mapController = MapController();
  final _marks = <PrototypeMark>[];
  MgrsCoordinate? _current;

  DateTime? _lastTileError;
  Timer? _errorTimer;

  @override
  void dispose() {
    _errorTimer?.cancel();
    super.dispose();
  }

  bool get _imageryUnavailable =>
      _lastTileError != null &&
      DateTime.now().difference(_lastTileError!) < const Duration(seconds: 8);

  void _onTileError() {
    final wasShown = _imageryUnavailable;
    _lastTileError = DateTime.now();
    if (!wasShown && mounted) setState(() {});
    _errorTimer?.cancel();
    _errorTimer = Timer(const Duration(seconds: 9), () {
      if (mounted) setState(() {});
    });
  }

  static double _zoomFor(MgrsCoordinate c) => switch (c.precision) {
        5 => 18,
        4 => 17,
        3 => 15,
        2 => 12,
        _ => 9,
      };

  Future<void> _goto() async {
    final c = await showGotoSheet(context);
    if (c == null || !mounted) return;
    setState(() => _current = c);
    _mapController.move(c.center, _zoomFor(c));
    await _offerMark(c);
  }

  Future<void> _offerMark(MgrsCoordinate c) async {
    final nameController = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Створити мітку?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(c.display),
            const SizedBox(height: 12),
            TextField(
              controller: nameController,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Назва'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Скасувати'),
          ),
          FilledButton(
            onPressed: () {
              final text = nameController.text.trim();
              Navigator.of(context).pop(text.isEmpty ? 'Мітка' : text);
            },
            child: const Text('Зберегти'),
          ),
        ],
      ),
    );
    nameController.dispose();
    if (name == null || !mounted) return; // Cancelled: no mark (FLOW-7).
    setState(() => _marks.add(PrototypeMark(name: name, coordinate: c)));
  }

  void _showMark(PrototypeMark mark) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => ListTile(
        leading: const Icon(Icons.place),
        title: Text(mark.name),
        subtitle: Text(
          '${mark.coordinate.display}\n${mark.coordinate.cellSizeLabel}',
        ),
        isThreeLine: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final current = _current;

    return Scaffold(
      appBar: AppBar(title: const Text('GGMap · прототип')),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: const MapOptions(
              initialCenter: _initialCenter,
              initialZoom: _initialZoom,
              interactionOptions: InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
            ),
            children: [
              if (Env.hasEsriApiKey)
                EsriImagery.layer(onTileError: _onTileError),
              MarkerLayer(
                markers: [
                  for (final mark in _marks)
                    Marker(
                      point: mark.coordinate.center,
                      width: 44,
                      height: 44,
                      alignment: Alignment.topCenter,
                      child: GestureDetector(
                        onTap: () => _showMark(mark),
                        child: Icon(
                          Icons.place,
                          size: 44,
                          color: scheme.tertiary,
                        ),
                      ),
                    ),
                  if (current != null)
                    Marker(
                      point: current.center,
                      width: 36,
                      height: 36,
                      child: Icon(
                        Icons.add_circle_outline,
                        size: 36,
                        color: scheme.primary,
                      ),
                    ),
                ],
              ),
              EsriImagery.attributionWidget(),
            ],
          ),
          if (!Env.hasEsriApiKey)
            const _Banner(
              text: 'Ключ Esri не задано у збірці — знімки недоступні.',
            )
          else if (_imageryUnavailable)
            const _Banner(
              text: 'Немає мережі або знімки недоступні. '
                  'Мітки й координати працюють.',
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _goto,
        icon: const Icon(Icons.my_location_outlined),
        label: const Text('Координати'),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: Card(
          color: scheme.errorContainer,
          margin: const EdgeInsets.all(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              text,
              style: TextStyle(color: scheme.onErrorContainer),
            ),
          ),
        ),
      ),
    );
  }
}
