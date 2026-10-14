import 'dart:convert';

import 'package:cp2/features/search/data/remote_hotel_repository.dart';
import 'package:cp2/features/search/domain/hotel_candidate.dart';
import 'package:cp2/features/search/domain/hotel_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('remote text search sends canonical filters and parses candidates',
      () async {
    late http.Request capturedRequest;
    final client = MockClient((request) async {
      capturedRequest = request;
      return http.Response(
        jsonEncode(<String, Object>{
          'mode': 'mock',
          'request_type': 'text',
          'ranking_version': 'week3-mock-v1',
          'candidates': <Object>[
            <String, Object>{
              'id': 'sunway-resort',
              'name': 'Sunway Resort Hotel',
              'address': 'Bandar Sunway, Selangor',
              'rating': 4.8,
              'match_confidence': 0.95,
              'tags': <String>['clean_rooms', 'non_smoking'],
            },
          ],
        }),
        200,
        headers: <String, String>{'content-type': 'application/json'},
      );
    });
    final repository = RemoteHotelRepository(
      baseUrl: 'http://10.0.2.2:8000/',
      client: client,
    );

    final candidates = await repository.searchHotels(
      'Sunway',
      requiredTags: <String>{'Clean rooms', 'Non-smoking'},
    );

    final requestBody =
        jsonDecode(capturedRequest.body) as Map<String, dynamic>;
    expect(capturedRequest.url.path, '/api/v1/search/text');
    expect(
      requestBody['required_tags'],
      containsAll(<String>['clean_rooms', 'non_smoking']),
    );
    expect(candidates.single.id, 'sunway-resort');
    expect(candidates.single.tags, <String>['Clean rooms', 'Non-smoking']);
  });

  test('remote visual request sends only a safe filename and source', () async {
    late Map<String, dynamic> capturedBody;
    final client = MockClient((request) async {
      capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
      return http.Response(
        jsonEncode(<String, Object>{
          'mode': 'mock',
          'request_type': 'gallery',
          'ranking_version': 'week3-mock-v1',
          'candidates': <Object>[],
        }),
        200,
      );
    });
    final repository = RemoteHotelRepository(
      baseUrl: 'http://10.0.2.2:8000',
      client: client,
    );

    await repository.rankVisualCandidates(
      '/private/user/photos/hotel.jpg',
      source: CandidateSource.gallery,
    );

    expect(capturedBody['source'], 'gallery');
    expect(capturedBody['image_reference'], 'hotel.jpg');
  });

  test('remote service failures become safe repository errors', () async {
    final client = MockClient((_) async => http.Response('{}', 503));
    final repository = RemoteHotelRepository(
      baseUrl: 'http://10.0.2.2:8000',
      client: client,
    );

    expect(
      repository.searchHotels('Sunway'),
      throwsA(
        isA<HotelRepositoryException>().having(
          (error) => error.userMessage,
          'message',
          'The selected hotel data service is not configured yet.',
        ),
      ),
    );
  });
}
