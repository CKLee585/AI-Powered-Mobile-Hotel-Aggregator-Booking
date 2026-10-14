import '../domain/hotel_candidate.dart';
import '../domain/hotel_repository.dart';

class MockHotelRepository implements HotelRepository {
  static const _hotels = <HotelCandidate>[
    HotelCandidate(
      id: 'sunway-resort',
      name: 'Sunway Resort Hotel',
      address: 'Persiaran Lagoon, Bandar Sunway, Selangor',
      rating: 4.8,
      matchConfidence: 0,
      tags: ['Clean rooms', 'Family-friendly', 'Non-smoking'],
    ),
    HotelCandidate(
      id: 'grand-hyatt-kl',
      name: 'Grand Hyatt Kuala Lumpur',
      address: 'Jalan Pinang, Kuala Lumpur City Centre',
      rating: 4.7,
      matchConfidence: 0,
      tags: ['Clean rooms', 'Quiet rooms', 'Non-smoking'],
    ),
    HotelCandidate(
      id: 'traders-kl',
      name: 'Traders Hotel Kuala Lumpur',
      address: 'Kuala Lumpur City Centre, Kuala Lumpur',
      rating: 4.6,
      matchConfidence: 0,
      tags: ['Quiet rooms', 'Family-friendly'],
    ),
    HotelCandidate(
      id: 'hilton-kl',
      name: 'Hilton Kuala Lumpur',
      address: 'Jalan Stesen Sentral, Kuala Lumpur Sentral',
      rating: 4.6,
      matchConfidence: 0,
      tags: ['Clean rooms', 'Non-smoking'],
    ),
    HotelCandidate(
      id: 'aloft-kl',
      name: 'Aloft Kuala Lumpur Sentral',
      address: 'Jalan Stesen Sentral, Kuala Lumpur Sentral',
      rating: 4.4,
      matchConfidence: 0,
      tags: ['Budget-friendly', 'Family-friendly'],
    ),
  ];

  @override
  Future<List<HotelCandidate>> searchHotels(
    String query, {
    Set<String> requiredTags = const {},
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 220));
    final normalized = query.trim().toLowerCase();

    final ranked = _hotels.map((hotel) {
      final name = hotel.name.toLowerCase();
      final address = hotel.address.toLowerCase();
      final passesTags = requiredTags.isEmpty ||
          requiredTags.every((tag) => hotel.tags.contains(tag));

      var score = 0.55;
      if (name == normalized) {
        score = 0.98;
      } else if (name.startsWith(normalized)) {
        score = 0.94;
      } else if (name.contains(normalized)) {
        score = 0.9;
      } else if (address.contains(normalized)) {
        score = 0.82;
      } else if (hotel.tags
          .any((tag) => tag.toLowerCase().contains(normalized))) {
        score = 0.76;
      }

      if (!passesTags) {
        score -= 0.25;
      }
      return hotel.withConfidence(score.clamp(0.05, 0.99));
    }).toList()
      ..sort(
        (first, second) =>
            second.matchConfidence.compareTo(first.matchConfidence),
      );

    return ranked.take(3).toList(growable: false);
  }

  @override
  Future<List<HotelCandidate>> rankVisualCandidates(
    String imagePath, {
    CandidateSource source = CandidateSource.camera,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 700));
    return <HotelCandidate>[
      _hotels[0].withConfidence(0.92),
      _hotels[2].withConfidence(0.81),
      _hotels[1].withConfidence(0.67),
    ];
  }
}
