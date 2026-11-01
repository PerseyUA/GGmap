/// Build-time configuration.
///
/// Values are injected with `--dart-define` from GitHub Actions secrets.
/// Nothing secret is stored in the repository.
abstract final class Env {
  /// ArcGIS Location Platform API key (basemap privilege only).
  static const String esriApiKey = String.fromEnvironment('ESRI_API_KEY');

  static bool get hasEsriApiKey => esriApiKey.isNotEmpty;
}
