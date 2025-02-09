enum VideoQuality {
  original,
  high,
  medium,
  low;

  String get label {
    switch (this) {
      case VideoQuality.original:
        return 'Original';
      case VideoQuality.high:
        return 'High (1080p)';
      case VideoQuality.medium:
        return 'Medium (720p)';
      case VideoQuality.low:
        return 'Low (480p)';
    }
  }

  int get height {
    switch (this) {
      case VideoQuality.original:
        return -1; // Keep original height
      case VideoQuality.high:
        return 1080;
      case VideoQuality.medium:
        return 720;
      case VideoQuality.low:
        return 480;
    }
  }

  double get bitrateFactor {
    switch (this) {
      case VideoQuality.original:
        return 1.0;
      case VideoQuality.high:
        return 0.8;
      case VideoQuality.medium:
        return 0.6;
      case VideoQuality.low:
        return 0.4;
    }
  }
}
