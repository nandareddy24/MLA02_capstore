/// Standardized FixWise layout dimensions, spacing, radii, and component sizes.
abstract final class AppSpacing {
  // Spacing scale
  static const double xxs = 4;
  static const double xs = 8; // Small spacing: 8 px
  static const double sm = 12;
  static const double md = 16; // Medium spacing: 16 px
  static const double screenHorizontal = 20; // Horizontal screen padding: 20 px
  static const double contentVertical = 20; // Main content vertical spacing: 20-24 px
  static const double lg = 24; // Large spacing: 24 px
  static const double xl = 32;

  // Corner radii
  static const double radiusSm = 8;
  static const double inputRadius = 10; // Input corner radius: 10 px
  static const double buttonRadius = 12; // Button corner radius: 12 px
  static const double cardRadius = 14; // Card corner radius: 14 px
  static const double radiusMd = 12;
  static const double radiusLg = 14;

  // Component heights
  static const double primaryButtonHeight = 52;
  static const double secondaryButtonHeight = 48;
  static const double inputHeight = 54;

  // Icon sizes (20-24 px range)
  static const double iconSm = 20;
  static const double iconMd = 22;
  static const double iconLg = 24;
}
