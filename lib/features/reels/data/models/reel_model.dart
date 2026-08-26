class ReelModel {
  final String id;
  final String videoUrl;
  final String imageUrl;
  final String caption;
  final String location;
  final String music;
  final String authorUsername;
  final String authorAvatar;

  ReelModel({
    required this.id,
    required this.videoUrl,
    required this.imageUrl,
    required this.caption,
    required this.location,
    required this.music,
    required this.authorUsername,
    required this.authorAvatar,
  });

  factory ReelModel.fromJson(Map<String, dynamic> json, String baseUrl) {
    final author = json['author'] as Map<String, dynamic>?;
    
    String fixUrl(String? url) {
      if (url == null) return '';
      if (url.startsWith('http')) return url;
      return '$baseUrl$url';
    }

    return ReelModel(
      id: json['id'] ?? '',
      videoUrl: fixUrl(json['videoUrl']),
      imageUrl: fixUrl(json['imageUrl']),
      caption: json['caption'] ?? '',
      location: json['location'] ?? '',
      music: json['music'] ?? '',
      authorUsername: author?['username'] ?? 'unknown',
      authorAvatar: fixUrl(author?['avatarUrl']),
    );
  }

  factory ReelModel.fromMap(Map<String, dynamic> map) {
    return ReelModel(
      id: map['id'],
      videoUrl: map['videoUrl'],
      imageUrl: map['imageUrl'],
      caption: map['caption'],
      location: map['location'],
      music: map['music'],
      authorUsername: map['authorUsername'],
      authorAvatar: map['authorAvatar'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'videoUrl': videoUrl,
      'imageUrl': imageUrl,
      'caption': caption,
      'location': location,
      'music': music,
      'authorUsername': authorUsername,
      'authorAvatar': authorAvatar,
    };
  }
}
