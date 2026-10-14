import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/hotel_candidate.dart';
import '../domain/hotel_repository.dart';

class RemoteHotelRepository implements HotelRepository {
  RemoteHotelRepository({
    required String baseUrl,
    http.Client? client,
    this.requestTimeout = const Duration(seconds: 8),
  })  : _baseUrl = baseUrl.replaceFirst(RegExp(r'/$'), ''),
        _client = client ?? http.Client();

  final String _baseUrl;
  final http.Client _client;
  final Duration requestTimeout;

  static const _filterKeys = <String, String>{
    'Clean rooms': 'clean_rooms',
    'Quiet rooms': 'quiet_rooms',
    'Family-friendly': 'family_friendly',
    'Safety/Secure': 'safety_secure',
    'Non-smoking': 'non_smoking',
    'Budget-friendly': 'budget_friendly',
  };

  @override
  Future<List<HotelCandidate>> searchHotels(
    String query, {
    Set<String> requiredTags = const {},
  }) {
    return _postCandidates(
      '/api/v1/search/text',
      <String, Object>{
        'query': query,
        'required_tags': requiredTags
            .map((tag) => _filterKeys[tag] ?? tag)
            .toList(growable: false),
        'limit': 3,
      },
    );
  }

  @override
  Future<List<HotelCandidate>> rankVisualCandidates(
    String imagePath, {
    CandidateSource source = CandidateSource.camera,
  }) {
    return _postCandidates(
      '/api/v1/candidates',
      <String, Object>{
        'source': source.name,
        'image_reference': _safeFilename(imagePath),
        'visual_hints': const <String>[],
        'limit': 3,
      },
    );
  }

  Future<List<HotelCandidate>> _postCandidates(
    String path,
    Map<String, Object> body,
  ) async {
    try {
      final response = await _client
          .post(
            Uri.parse('$_baseUrl$path'),
            headers: <String, String>{
              'Content-Type': 'application/json',
              'X-Request-ID':
                  'flutter-${DateTime.now().microsecondsSinceEpoch}',
            },
            body: jsonEncode(body),
          )
          .timeout(requestTimeout);

      if (response.statusCode != 200) {
        throw HotelRepositoryException(_errorMessage(response));
      }

      final payload = jsonDecode(response.body);
      if (payload is! Map<String, dynamic>) {
        throw const FormatException('API response must be a JSON object.');
      }
      final rawCandidates = payload['candidates'];
      if (rawCandidates is! List) {
        throw const FormatException('API response has no candidate list.');
      }

      return rawCandidates.map((candidate) {
        if (candidate is! Map<String, dynamic>) {
          throw const FormatException('Candidate data must be a JSON object.');
        }
        return HotelCandidate.fromJson(candidate);
      }).toList(growable: false);
    } on HotelRepositoryException {
      rethrow;
    } on TimeoutException {
      throw const HotelRepositoryException(
        'The hotel service took too long to respond. Please try again.',
      );
    } on FormatException {
      throw const HotelRepositoryException(
        'The hotel service returned data in an unexpected format.',
      );
    } on http.ClientException {
      throw const HotelRepositoryException(
        'The hotel service cannot be reached. Check that the local API is running.',
      );
    }
  }

  String _errorMessage(http.Response response) {
    if (response.statusCode == 422) {
      return 'Check the search text and selected filters, then try again.';
    }
    if (response.statusCode == 503) {
      return 'The selected hotel data service is not configured yet.';
    }
    return 'The hotel service could not complete this request.';
  }

  String _safeFilename(String imagePath) {
    final normalizedPath = imagePath.replaceAll('\\', '/');
    final filename = normalizedPath.split('/').last.trim();
    return filename.isEmpty ? 'selected-hotel-image.jpg' : filename;
  }
}
