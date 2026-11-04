class PakistanLocationSuggestion {
  final String title;
  final String subtitle;
  final String province;
  final String district;
  final String city;
  final String? society;
  final double latitude;
  final double longitude;

  const PakistanLocationSuggestion({
    required this.title,
    required this.subtitle,
    required this.province,
    required this.district,
    required this.city,
    this.society,
    required this.latitude,
    required this.longitude,
  });

  String? get societyOrArea => society;
}

class PakistanCityData {
  final String name;
  final String province;
  final String district;
  final double defaultLat;
  final double defaultLng;
  final List<String> societies;

  const PakistanCityData({
    required this.name,
    required this.province,
    required this.district,
    required this.defaultLat,
    required this.defaultLng,
    required this.societies,
  });
}

class PakistanGeoData {
  static const List<String> provinces = [
    'Punjab',
    'Sindh',
    'Khyber Pakhtunkhwa',
    'Balochistan',
    'Islamabad Capital Territory',
    'Gilgit-Baltistan',
    'Azad Jammu and Kashmir',
  ];

  static const List<PakistanCityData> cities = [
    // Sindh
    PakistanCityData(
      name: 'Karachi',
      province: 'Sindh',
      district: 'Karachi South',
      defaultLat: 24.8607,
      defaultLng: 67.0011,
      societies: [
        'Clifton (Blocks 1-9)',
        'DHA Phase 1',
        'DHA Phase 2',
        'DHA Phase 4',
        'DHA Phase 5',
        'DHA Phase 6',
        'DHA Phase 7',
        'DHA Phase 8',
        'Gulshan-e-Iqbal',
        'Gulistan-e-Jauhar',
        'PECHS (Blocks 1-6)',
        'North Nazimabad',
        'Bahadurabad',
        'KDA Scheme 1',
        'Malir Cantonment',
        'Bahria Town Karachi',
        'Scheme 33 (Gulshan-e-Kaneez)',
        'Federal B Area (Yaseenabad)',
        'Saddar Urban Core',
        'Defense View Society',
        'Gulshan-e-Maymar',
      ],
    ),
    PakistanCityData(
      name: 'Hyderabad',
      province: 'Sindh',
      district: 'Hyderabad',
      defaultLat: 25.3960,
      defaultLng: 68.3578,
      societies: [
        'Latifabad Unit 1-12',
        'Qasimabad Phase 1 & 2',
        'Saddar Cantonment',
        'Citizen Colony',
        'Wapda Town Hyderabad',
        'Gulshan-e-Sarmast',
      ],
    ),
    PakistanCityData(
      name: 'Sukkur',
      province: 'Sindh',
      district: 'Sukkur',
      defaultLat: 27.7052,
      defaultLng: 68.8574,
      societies: [
        'Military Road',
        'Minara Road Area',
        'Shalimar Town',
        'Society Area Sukkur',
      ],
    ),

    // Punjab
    PakistanCityData(
      name: 'Lahore',
      province: 'Punjab',
      district: 'Lahore',
      defaultLat: 31.5204,
      defaultLng: 74.3587,
      societies: [
        'Canal Berg Housing Scheme',
        'Canal View Housing Society',
        'DHA Phase 1',
        'DHA Phase 2',
        'DHA Phase 3',
        'DHA Phase 4',
        'DHA Phase 5',
        'DHA Phase 6',
        'DHA Phase 7',
        'DHA Phase 8',
        'DHA Phase 9 (Prism)',
        'Gulberg (I, II, III)',
        'Model Town (Blocks A-M)',
        'Johar Town (Phases 1 & 2)',
        'Bahria Town Lahore (Sectors A-F)',
        'Bahria Orchard',
        'Wapda Town (Phases 1 & 2)',
        'Valencia Housing Society',
        'Izmir Town',
        'Tricon Village',
        'Sukh Chayn Gardens',
        'Jubilee Town',
        'Lahore Cantt (Saddar)',
        'Garden Town & Barkat Market',
        'Faisal Town',
        'Cavalry Ground',
        'Lake City Holdings',
        'Allama Iqbal Town',
        'Shadman Colony',
        'Township',
        'Paragon City',
        'Askari 10 & 11',
      ],
    ),
    PakistanCityData(
      name: 'Faisalabad',
      province: 'Punjab',
      district: 'Faisalabad',
      defaultLat: 31.4504,
      defaultLng: 73.1350,
      societies: [
        'Madina Town',
        'Peoples Colony 1 & 2',
        'D Ground Market Area',
        'Susan Road Enclave',
        'Gulberg Colony',
        'Canal Road Corridor',
        'Citi Housing Faisalabad',
        'FDA City',
        'Kohinoor City',
      ],
    ),
    PakistanCityData(
      name: 'Rawalpindi',
      province: 'Punjab',
      district: 'Rawalpindi',
      defaultLat: 33.5651,
      defaultLng: 73.0169,
      societies: [
        'Bahria Town (Phases 1-8)',
        'Chaklala Scheme 3',
        'Rawalpindi Cantt (Saddar)',
        'Westridge (1, 2, 3)',
        'Satellite Town',
        'Gulraiz Housing Society',
        'Media Town',
        'Askari 14',
      ],
    ),
    PakistanCityData(
      name: 'Multan',
      province: 'Punjab',
      district: 'Multan',
      defaultLat: 30.1575,
      defaultLng: 71.5249,
      societies: [
        'Multan Cantt',
        'Gulgasht Colony',
        'Bosan Road Area',
        'DHA Multan',
        'Model Town Multan',
        'Shah Rukn-e-Alam Colony',
        'Wapda Town Multan',
      ],
    ),
    PakistanCityData(
      name: 'Gujranwala',
      province: 'Punjab',
      district: 'Gujranwala',
      defaultLat: 32.1877,
      defaultLng: 74.1945,
      societies: [
        'Model Town Gujranwala',
        'DC Colony',
        'Citi Housing Gujranwala',
        'Master City',
        'Wapda Town',
        'Gujranwala Cantt',
      ],
    ),
    PakistanCityData(
      name: 'Sialkot',
      province: 'Punjab',
      district: 'Sialkot',
      defaultLat: 32.4945,
      defaultLng: 74.5229,
      societies: [
        'Sialkot Cantt',
        'Model Town Sialkot',
        'Citi Housing Sialkot',
        'Defense Road Corridor',
        'Paris Road Vicinity',
      ],
    ),
    PakistanCityData(
      name: 'Bahawalpur',
      province: 'Punjab',
      district: 'Bahawalpur',
      defaultLat: 29.3544,
      defaultLng: 71.6911,
      societies: [
        'Model Town A & B',
        'DHA Bahawalpur',
        'Cantonment Area',
        'Cheema Town',
      ],
    ),

    // Islamabad Capital Territory
    PakistanCityData(
      name: 'Islamabad',
      province: 'Islamabad Capital Territory',
      district: 'Islamabad',
      defaultLat: 33.6844,
      defaultLng: 73.0479,
      societies: [
        'Sector F-6 (Super Market)',
        'Sector F-7 (Jinnah Super)',
        'Sector F-8',
        'Sector F-10 (Markaz)',
        'Sector F-11',
        'Sector G-6 (Melody)',
        'Sector G-9 (Karachi Company)',
        'Sector G-10',
        'Sector G-11',
        'Sector I-8 (Markaz)',
        'Sector I-9 & I-10',
        'Sector E-7 & E-11',
        'DHA Islamabad (Phases 1-5)',
        'Bahria Enclave Islamabad',
        'PWD Housing Scheme',
        'Soan Garden',
        'Gulberg Greens Islamabad',
        'B-17 Multi Gardens',
      ],
    ),

    // Khyber Pakhtunkhwa
    PakistanCityData(
      name: 'Peshawar',
      province: 'Khyber Pakhtunkhwa',
      district: 'Peshawar',
      defaultLat: 34.0151,
      defaultLng: 71.5249,
      societies: [
        'Hayatabad (Phases 1-7)',
        'University Town',
        'Peshawar Cantt',
        'Warsak Road Corridor',
        'Regi Model Town',
        'Defense Officers Colony',
        'Shami Road Residences',
      ],
    ),
    PakistanCityData(
      name: 'Abbottabad',
      province: 'Khyber Pakhtunkhwa',
      district: 'Abbottabad',
      defaultLat: 34.1688,
      defaultLng: 73.2215,
      societies: [
        'Kakul Road',
        'Mandian Area',
        'Jinnahabad',
        'Abbottabad Cantt',
      ],
    ),
    PakistanCityData(
      name: 'Mardan',
      province: 'Khyber Pakhtunkhwa',
      district: 'Mardan',
      defaultLat: 34.1989,
      defaultLng: 72.0404,
      societies: [
        'Sheikh Maltoon Town',
        'Mardan Cantt',
        'Baghecha Dheri',
      ],
    ),

    // Balochistan
    PakistanCityData(
      name: 'Quetta',
      province: 'Balochistan',
      district: 'Quetta',
      defaultLat: 30.1798,
      defaultLng: 66.9750,
      societies: [
        'Quetta Cantt',
        'Jinnah Town',
        'Samungli Road',
        'Model Town Quetta',
        'Zarghoon Housing Scheme',
        'Chiltan Housing Society',
      ],
    ),
    PakistanCityData(
      name: 'Gwadar',
      province: 'Balochistan',
      district: 'Gwadar',
      defaultLat: 25.1264,
      defaultLng: 62.3226,
      societies: [
        'Marine Drive Area',
        'New Town Gwadar',
        'Sanghar Housing Scheme',
      ],
    ),

    // Azad Jammu and Kashmir
    PakistanCityData(
      name: 'Muzaffarabad',
      province: 'Azad Jammu and Kashmir',
      district: 'Muzaffarabad',
      defaultLat: 34.3700,
      defaultLng: 73.4711,
      societies: [
        'Upper Chatter',
        'Lower Plate',
        'Gojra Heights',
        'Chella Bandi',
      ],
    ),
    PakistanCityData(
      name: 'Mirpur',
      province: 'Azad Jammu and Kashmir',
      district: 'Mirpur',
      defaultLat: 33.1484,
      defaultLng: 73.7519,
      societies: [
        'Sector F-1 & F-2',
        'Sector C-1 to C-4',
        'Housing Scheme New City',
      ],
    ),

    // Gilgit-Baltistan
    PakistanCityData(
      name: 'Gilgit',
      province: 'Gilgit-Baltistan',
      district: 'Gilgit',
      defaultLat: 35.9221,
      defaultLng: 74.3087,
      societies: [
        'Jutial Gilgit',
        'River View Road',
        'Airport Road Area',
        'Kashrote',
      ],
    ),
    PakistanCityData(
      name: 'Skardu',
      province: 'Gilgit-Baltistan',
      district: 'Skardu',
      defaultLat: 35.2971,
      defaultLng: 75.6333,
      societies: [
        'Sadpara Road Area',
        'Kargil Chowk Vicinity',
        'Hussainabad Valley',
      ],
    ),
  ];

  /// Instant search matching query against cities, provinces, districts, and housing societies
  static List<PakistanLocationSuggestion> search(String query) {
    if (query.trim().isEmpty) {
      // Return top prominent urban locations in Pakistan
      return [
        const PakistanLocationSuggestion(
          title: 'Clifton (Blocks 1-9)',
          subtitle: 'Karachi South, Sindh',
          province: 'Sindh',
          district: 'Karachi South',
          city: 'Karachi',
          society: 'Clifton (Blocks 1-9)',
          latitude: 24.8138,
          longitude: 67.0299,
        ),
        const PakistanLocationSuggestion(
          title: 'DHA Phase 5 & 6',
          subtitle: 'Lahore, Punjab',
          province: 'Punjab',
          district: 'Lahore',
          city: 'Lahore',
          society: 'DHA Phase 5',
          latitude: 31.4697,
          longitude: 74.3976,
        ),
        const PakistanLocationSuggestion(
          title: 'Sector F-7 & F-6',
          subtitle: 'Islamabad, ICT',
          province: 'Islamabad Capital Territory',
          district: 'Islamabad',
          city: 'Islamabad',
          society: 'Sector F-7',
          latitude: 33.7215,
          longitude: 73.0565,
        ),
        const PakistanLocationSuggestion(
          title: 'Bahria Town (Phases 1-8)',
          subtitle: 'Rawalpindi / Islamabad Corridor, Punjab',
          province: 'Punjab',
          district: 'Rawalpindi',
          city: 'Rawalpindi',
          society: 'Bahria Town (Phases 1-8)',
          latitude: 33.5204,
          longitude: 73.1097,
        ),
        const PakistanLocationSuggestion(
          title: 'Hayatabad (Phases 1-7)',
          subtitle: 'Peshawar, Khyber Pakhtunkhwa',
          province: 'Khyber Pakhtunkhwa',
          district: 'Peshawar',
          city: 'Peshawar',
          society: 'Hayatabad (Phases 1-7)',
          latitude: 33.9856,
          longitude: 71.4361,
        ),
      ];
    }

    final q = query.toLowerCase().trim();
    final results = <PakistanLocationSuggestion>[];

    for (final city in cities) {
      // 1. Check if city or province matches
      final cityMatch = city.name.toLowerCase().contains(q);
      final provMatch = city.province.toLowerCase().contains(q);

      if (cityMatch || provMatch) {
        results.add(
          PakistanLocationSuggestion(
            title: city.name,
            subtitle: '${city.district}, ${city.province}',
            province: city.province,
            district: city.district,
            city: city.name,
            latitude: city.defaultLat,
            longitude: city.defaultLng,
          ),
        );
      }

      // 2. Check each society
      for (final society in city.societies) {
        if (society.toLowerCase().contains(q)) {
          // Society specific latitude perturbation around city center for distinct pins
          final hash = society.hashCode;
          final offsetLat = ((hash % 100) - 50) * 0.0008;
          final offsetLng = (((hash ~/ 100) % 100) - 50) * 0.0008;

          results.add(
            PakistanLocationSuggestion(
              title: society,
              subtitle: '${city.name}, ${city.province}',
              province: city.province,
              district: city.district,
              city: city.name,
              society: society,
              latitude: city.defaultLat + offsetLat,
              longitude: city.defaultLng + offsetLng,
            ),
          );
        }
      }
    }

    return results.take(15).toList();
  }
}
