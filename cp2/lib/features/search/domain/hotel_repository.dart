import 'hotel_candidate.dart';

abstract interface class HotelRepository {
  Future<List<HotelCandidate>> searchHotels(
    String query, {
    Set<String> requiredTags = const {},
  });

  Future<List<HotelCandidate>> rankVisualCandidates(
    String imagePath, {
    CandidateSource source = CandidateSource.camera,
  });
}

class HotelRepositoryException implements Exception {
  const HotelRepositoryException(this.userMessage);

  final String userMessage;

  @override
  String toString() => userMessage;
}
