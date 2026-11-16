class PrayerPost {
  final String postId;
  final String userId;
  final String? authorName;
  final String? avatarUrl;
  final String? title;
  final String content;
  final String? category;
  final String privacy;
  final DateTime createdAt;
  final int amenCount;
  final int commentCount;
  final int witnessCount;
  final bool amened;
  final bool witnessed;

  PrayerPost({
    required this.postId,
    required this.userId,
    required this.authorName,
    required this.avatarUrl,
    required this.title,
    required this.content,
    required this.category,
    required this.privacy,
    required this.createdAt,
    required this.amenCount,
    required this.commentCount,
    required this.witnessCount,
    required this.amened,
    required this.witnessed,
  });

  factory PrayerPost.fromJson(Map<String, dynamic> json) {
    return PrayerPost(
      postId: json['postId'] as String,
      userId: json['userId'] as String,
      authorName: json['author']?['displayName'] as String?,
      avatarUrl: json['author']?['avatarUrl'] as String?,
      title: json['title'] as String?,
      content: json['content'] as String,
      category: json['category'] as String?,
      privacy: json['privacy'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      amenCount: json['amenCount'] as int,
      commentCount: json['commentCount'] as int,
      witnessCount: json['witnessCount'] as int,
      amened: json['amened'] as bool,
      witnessed: json['witnessed'] as bool,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'postId': postId,
      'userId': userId,
      'author': {
        'displayName': authorName,
        'avatarUrl': avatarUrl,
      },
      'title': title,
      'content': content,
      'category': category,
      'privacy': privacy,
      'createdAt': createdAt.toIso8601String(),
      'amenCount': amenCount,
      'commentCount': commentCount,
      'witnessCount': witnessCount,
      'amened': amened,
      'witnessed': witnessed,
    };
  }
}