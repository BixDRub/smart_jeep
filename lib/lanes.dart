import 'dart:math' as math;
import 'package:latlong2/latlong.dart';

/// Offset an entire polyline by X meters (positive = right, negative = left)
List<LatLng> offsetPolyline(List<LatLng> points, double offsetMeters) {
  const earthRadius = 6378137.0;
  final List<LatLng> result = [];

  for (int i = 0; i < points.length; i++) {
    LatLng p = points[i];

    // Get previous & next points
    LatLng prev = i == 0 ? points[i] : points[i - 1];
    LatLng next = i == points.length - 1 ? points[i] : points[i + 1];

    // Bearing of road direction
    double bearing = math.atan2(
      next.latitude - prev.latitude,
      next.longitude - prev.longitude,
    );

    // Perpendicular angle
    double perpendicular = bearing + math.pi / 2;

    // Convert meter offset → degree offset
    double latOffset = (offsetMeters * math.sin(perpendicular)) / earthRadius;
    double lngOffset =
        (offsetMeters * math.cos(perpendicular)) /
            (earthRadius * math.cos(p.latitude * math.pi / 180));

    result.add(
      LatLng(
        p.latitude + latOffset * 180 / math.pi,
        p.longitude + lngOffset * 180 / math.pi,
      ),
    );
  }

  return result;
}

// Build exactly two lanes (left + right)
List<List<LatLng>> buildTwoLanes(List<LatLng> baseRoute, double laneWidthMeters) {
  return [
    offsetPolyline(baseRoute, laneWidthMeters),   // right lane
    offsetPolyline(baseRoute, -laneWidthMeters),  // left lane
  ];
}

// Build N parallel lanes
List<List<LatLng>> buildLanes(
  List<LatLng> baseRoute,
  int laneCount, {
  double spacingMeters = 4.0,
}) {
  final List<List<LatLng>> lanes = [];

  // Zero-centered offset distribution
  int middle = laneCount ~/ 2;

  for (int i = 0; i < laneCount; i++) {
    double offset = (i - middle) * spacingMeters;
    lanes.add(offsetPolyline(baseRoute, offset));
  }

  return lanes;
}
