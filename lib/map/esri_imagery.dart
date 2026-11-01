import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import '../config/env.dart';

/// Esri World Imagery raster tiles via ArcGIS Location Platform.
///
/// Tiles are requested online only. Caching is limited to what the HTTP
/// layer does temporarily; tiles are not stored as an offline archive
/// (see ADR-0001 and Esri terms of use).
abstract final class EsriImagery {
  static const String attribution =
      'Esri, Vantor, Earthstar Geographics, and the GIS User Community';

  static const String _urlTemplate =
      'https://ibasemaps-api.arcgis.com/arcgis/rest/services/World_Imagery/'
      'MapServer/tile/{z}/{y}/{x}?token={token}';

  static TileLayer layer({
    required void Function() onTileError,
  }) {
    return TileLayer(
      urlTemplate: _urlTemplate,
      additionalOptions: const {'token': Env.esriApiKey},
      userAgentPackageName: 'ua.ggmap.ggmap',
      maxNativeZoom: 19,
      maxZoom: 20,
      errorTileCallback: (tile, error, stackTrace) => onTileError(),
      tileProvider: NetworkTileProvider(
        cachingProvider: const DisabledMapCachingProvider(),
      ),
    );
  }

  static Widget attributionWidget() {
    return const RichAttributionWidget(
      alignment: AttributionAlignment.bottomLeft,
      showFlutterMapAttribution: false,
      attributions: [
        TextSourceAttribution('Powered by Esri'),
        TextSourceAttribution(attribution),
      ],
    );
  }
}
