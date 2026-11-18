/// Equipment or device categories supported by FixWise fault reporting.
enum DeviceCategory {
  hvac('HVAC & Climate'),
  electrical('Electrical & Power'),
  industrial('Industrial Machinery'),
  computing('Computing & Networking'),
  automotive('Automotive & Mobility'),
  appliance('Home & Commercial Appliance'),
  other('Other Equipment');

  const DeviceCategory(this.label);

  final String label;

  static DeviceCategory fromName(String value) {
    return DeviceCategory.values.firstWhere(
      (c) => c.name == value,
      orElse: () => DeviceCategory.other,
    );
  }
}

/// Represents a user-registered physical asset or device subject to fault diagnosis.
class DeviceModel {
  const DeviceModel({
    required this.id,
    required this.name,
    required this.category,
    required this.manufacturer,
    required this.modelNumber,
    this.serialNumber,
    this.location,
    required this.createdAt,
  });

  final String id;
  final String name;
  final DeviceCategory category;
  final String manufacturer;
  final String modelNumber;
  final String? serialNumber;
  final String? location;
  final DateTime createdAt;

  DeviceModel copyWith({
    String? id,
    String? name,
    DeviceCategory? category,
    String? manufacturer,
    String? modelNumber,
    String? serialNumber,
    String? location,
    DateTime? createdAt,
  }) {
    return DeviceModel(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      manufacturer: manufacturer ?? this.manufacturer,
      modelNumber: modelNumber ?? this.modelNumber,
      serialNumber: serialNumber ?? this.serialNumber,
      location: location ?? this.location,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'category': category.name,
        'manufacturer': manufacturer,
        'model_number': modelNumber,
        'serial_number': serialNumber,
        'location': location,
        'created_at': createdAt.toIso8601String(),
      };

  factory DeviceModel.fromMap(Map<String, Object?> map) {
    return DeviceModel(
      id: map['id'] as String,
      name: map['name'] as String,
      category: DeviceCategory.fromName(map['category'] as String),
      manufacturer: map['manufacturer'] as String,
      modelNumber: map['model_number'] as String,
      serialNumber: map['serial_number'] as String?,
      location: map['location'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'category': category.name,
        'manufacturer': manufacturer,
        'model_number': modelNumber,
        if (serialNumber != null && serialNumber!.isNotEmpty)
          'serial_number': serialNumber,
        if (location != null && location!.isNotEmpty) 'location': location,
      };
}
