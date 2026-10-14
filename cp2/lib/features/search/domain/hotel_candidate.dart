class HotelCandidate {
  const HotelCandidate({
    required this.id,
    required this.name,
    required this.address,
    required this.rating,
    required this.matchConfidence,
    required this.tags,
  });

  final String id;
  final String name;
  final String address;
  final double rating;
  final double matchConfidence;
  final List<String> tags;

  factory HotelCandidate.fromJson(Map<String, dynamic> json) {
    final rawTags = json['tags'];
    if (rawTags is! List) {
      throw const FormatException('Candidate tags must be a list.');
    }

    return HotelCandidate(
      id: _readString(json, 'id'),
      name: _readString(json, 'name'),
      address: _readString(json, 'address'),
      rating: _readNumber(json, 'rating'),
      matchConfidence: _readNumber(json, 'match_confidence'),
      tags: rawTags
          .map((tag) => _displayTag(tag.toString()))
          .toList(growable: false),
    );
  }

  HotelCandidate withConfidence(double confidence) {
    return HotelCandidate(
      id: id,
      name: name,
      address: address,
      rating: rating,
      matchConfidence: confidence,
      tags: tags,
    );
  }
}

String _readString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.isEmpty) {
    throw FormatException('Candidate $key must be a non-empty string.');
  }
  return value;
}

double _readNumber(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! num) {
    throw FormatException('Candidate $key must be numeric.');
  }
  return value.toDouble();
}

String _displayTag(String value) => switch (value) {
      'clean_rooms' => 'Clean rooms',
      'quiet_rooms' => 'Quiet rooms',
      'family_friendly' => 'Family-friendly',
      'safety_secure' => 'Safety/Secure',
      'non_smoking' => 'Non-smoking',
      'budget_friendly' => 'Budget-friendly',
      _ => value,
    };

enum CandidateSource {
  text,
  camera,
  gallery;

  String get label => switch (this) {
        CandidateSource.text => 'text search',
        CandidateSource.camera => 'camera image',
        CandidateSource.gallery => 'gallery image',
      };
}
