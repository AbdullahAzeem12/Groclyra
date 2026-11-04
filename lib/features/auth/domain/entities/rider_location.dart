class RiderLocation {
  final String? country;
  final String? province;
  final String? division;
  final String? district;
  final String? tehsil;
  final String? city;
  final String? locality;
  final String? formattedAddress;
  final double? latitude;
  final double? longitude;
  final String source; // 'manual', 'gps', or 'map'

  RiderLocation({
    this.country,
    this.province,
    this.division,
    this.district,
    this.tehsil,
    this.city,
    this.locality,
    this.formattedAddress,
    this.latitude,
    this.longitude,
    required this.source,
  });

  RiderLocation copyWith({
    String? country,
    String? province,
    String? division,
    String? district,
    String? tehsil,
    String? city,
    String? locality,
    String? formattedAddress,
    double? latitude,
    double? longitude,
    String? source,
  }) {
    return RiderLocation(
      country: country ?? this.country,
      province: province ?? this.province,
      division: division ?? this.division,
      district: district ?? this.district,
      tehsil: tehsil ?? this.tehsil,
      city: city ?? this.city,
      locality: locality ?? this.locality,
      formattedAddress: formattedAddress ?? this.formattedAddress,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      source: source ?? this.source,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'country': country,
      'province': province,
      'division': division,
      'district': district,
      'tehsil': tehsil,
      'city': city,
      'locality': locality,
      'formattedAddress': formattedAddress,
      'latitude': latitude,
      'longitude': longitude,
      'source': source,
    };
  }

  factory RiderLocation.fromMap(Map<String, dynamic> map) {
    return RiderLocation(
      country: map['country'] as String?,
      province: map['province'] as String?,
      division: map['division'] as String?,
      district: map['district'] as String?,
      tehsil: map['tehsil'] as String?,
      city: map['city'] as String?,
      locality: map['locality'] as String?,
      formattedAddress: map['formattedAddress'] as String?,
      latitude: map['latitude'] != null ? (map['latitude'] as num).toDouble() : null,
      longitude: map['longitude'] != null ? (map['longitude'] as num).toDouble() : null,
      source: map['source'] as String? ?? 'unknown',
    );
  }
}
