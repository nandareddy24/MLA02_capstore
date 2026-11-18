/// A single structured symptom option belonging to a [SymptomGroup].
class SymptomItem {
  const SymptomItem({
    required this.id,
    required this.label,
  });

  final String id;
  final String label;

  factory SymptomItem.fromJson(Map<String, dynamic> json) {
    return SymptomItem(
      id: (json['id'] ?? '').toString(),
      label: (json['label'] ?? '').toString(),
    );
  }
}

/// Categorized group of symptoms (e.g., Power & Battery, Display & Touch).
class SymptomGroup {
  const SymptomGroup({
    required this.id,
    required this.name,
    required this.symptoms,
  });

  final String id;
  final String name;
  final List<SymptomItem> symptoms;

  factory SymptomGroup.fromJson(Map<String, dynamic> json) {
    final rawSymptoms = json['symptoms'];
    return SymptomGroup(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      symptoms: rawSymptoms is List
          ? rawSymptoms
              .whereType<Map<String, dynamic>>()
              .map(SymptomItem.fromJson)
              .toList()
          : const [],
    );
  }
}

/// A supported device category backed by the FixWise knowledge base / dataset.
class SupportedDeviceCategory {
  const SupportedDeviceCategory({
    required this.id,
    required this.name,
    required this.iconKey,
    required this.isSupported,
    required this.commonManufacturers,
    required this.symptomGroups,
  });

  final String id;
  final String name;
  final String iconKey;
  final bool isSupported;
  final List<String> commonManufacturers;
  final List<SymptomGroup> symptomGroups;

  List<SymptomItem> get allSymptoms =>
      symptomGroups.expand((group) => group.symptoms).toList();

  factory SupportedDeviceCategory.fromJson(Map<String, dynamic> json) {
    final manufacturersRaw = json['common_manufacturers'];
    final groupsRaw = json['symptom_groups'];

    return SupportedDeviceCategory(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      iconKey: (json['icon_key'] ?? 'other').toString(),
      isSupported: json['is_supported'] == true,
      commonManufacturers: manufacturersRaw is List
          ? manufacturersRaw.map((e) => e.toString()).toList()
          : const [],
      symptomGroups: groupsRaw is List
          ? groupsRaw
              .whereType<Map<String, dynamic>>()
              .map(SymptomGroup.fromJson)
              .toList()
          : const [],
    );
  }
}

/// Root catalog configuration of diagnosable device categories and structured symptoms.
class DiagnosticCatalog {
  const DiagnosticCatalog({
    required this.version,
    required this.categories,
    this.fromBackend = false,
  });

  final String version;
  final List<SupportedDeviceCategory> categories;
  final bool fromBackend;

  /// Only returns categories explicitly marked as supported in the dataset/backend.
  List<SupportedDeviceCategory> get supportedCategories =>
      categories.where((c) => c.isSupported).toList();

  SupportedDeviceCategory? findById(String id) {
    for (final category in supportedCategories) {
      if (category.id == id) return category;
    }
    return null;
  }

  factory DiagnosticCatalog.fromJson(
    Map<String, dynamic> json, {
    bool fromBackend = false,
  }) {
    final categoriesRaw = json['categories'];
    return DiagnosticCatalog(
      version: (json['catalog_version'] ?? '1.0.0').toString(),
      fromBackend: fromBackend,
      categories: categoriesRaw is List
          ? categoriesRaw
              .whereType<Map<String, dynamic>>()
              .map(SupportedDeviceCategory.fromJson)
              .where((c) => c.isSupported)
              .toList()
          : const [],
    );
  }
}
