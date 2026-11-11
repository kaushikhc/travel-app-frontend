import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../domain/journey_models.dart';

/// Visited places and travel paths on a plain longitude/latitude plane, fitted to the data.
/// There is no basemap yet (a map tile or coastline source still has to be chosen).
class WorldMap extends StatelessWidget {
  final MapData data;

  const WorldMap({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final ColorScheme c = Theme.of(context).colorScheme;
    return CustomPaint(
      painter: WorldMapPainter(data: data, line: c.primary, dot: c.tertiary, grid: c.outlineVariant, background: c.surfaceContainerHighest),
      child: const SizedBox.expand(),
    );
  }
}

class WorldMapPainter extends CustomPainter {
  final MapData data;
  final Color line;
  final Color dot;
  final Color grid;
  final Color background;

  const WorldMapPainter({required this.data, required this.line, required this.dot, required this.grid, required this.background});

  /// Longitude/latitude bounds of everything on the map, padded to at least 20 degrees each way.
  static ({double minLon, double maxLon, double minLat, double maxLat}) bounds(MapData d) {
    final List<GeoPoint> all = <GeoPoint>[...d.points, for (final (GeoPoint, GeoPoint) p in d.paths) ...<GeoPoint>[p.$1, p.$2]];
    double minLon = all.first.lon, maxLon = all.first.lon, minLat = all.first.lat, maxLat = all.first.lat;
    for (final GeoPoint p in all) {
      minLon = math.min(minLon, p.lon);
      maxLon = math.max(maxLon, p.lon);
      minLat = math.min(minLat, p.lat);
      maxLat = math.max(maxLat, p.lat);
    }
    double pad(double lo, double hi, double limit, bool upper) {
      final double extra = math.max(10, (hi - lo) * 0.1) + math.max(0, (20 - (hi - lo)) / 2);
      return upper ? math.min(limit, hi + extra) : math.max(-limit, lo - extra);
    }

    return (minLon: pad(minLon, maxLon, 180, false), maxLon: pad(minLon, maxLon, 180, true), minLat: pad(minLat, maxLat, 90, false), maxLat: pad(minLat, maxLat, 90, true));
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = background);
    if (data.isEmpty) return;
    final b = bounds(data);
    final double w = b.maxLon - b.minLon;
    final double h = b.maxLat - b.minLat;
    final double scale = math.min(size.width / w, size.height / h);
    final double ox = (size.width - w * scale) / 2;
    final double oy = (size.height - h * scale) / 2;
    Offset at(GeoPoint p) => Offset(ox + (p.lon - b.minLon) * scale, oy + (b.maxLat - p.lat) * scale);

    final Paint gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (double lon = (b.minLon / 30).ceil() * 30.0; lon <= b.maxLon; lon += 30) {
      canvas.drawLine(at((lon: lon, lat: b.maxLat)), at((lon: lon, lat: b.minLat)), gridPaint);
    }
    for (double lat = (b.minLat / 30).ceil() * 30.0; lat <= b.maxLat; lat += 30) {
      canvas.drawLine(at((lon: b.minLon, lat: lat)), at((lon: b.maxLon, lat: lat)), gridPaint);
    }
    final Paint linePaint = Paint()
      ..color = line
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    for (final (GeoPoint, GeoPoint) p in data.paths) {
      canvas.drawLine(at(p.$1), at(p.$2), linePaint);
    }
    final Paint dotPaint = Paint()..color = dot;
    for (final GeoPoint p in data.points) {
      canvas.drawCircle(at(p), 5, dotPaint);
    }
  }

  @override
  bool shouldRepaint(WorldMapPainter old) => old.data != data || old.line != line || old.dot != dot;
}
