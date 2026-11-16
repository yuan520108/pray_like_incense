import 'package:dio/dio.dart';
import '../models/prayer_post.dart';

class WitnessService {
  final Dio _dio;

  WitnessService(this._dio);

  // 發送Witness
  Future<PrayerPost> createWitness({
    required String postId,
    required String content,
    String? imageUrl,
  }) async {
    try {
      final data = {
        'postId': postId,
        'content': content,
      };
      
      if (imageUrl != null && imageUrl.isNotEmpty) {
        data['imageUrl'] = imageUrl;
      }

      final response = await _dio.post('v1/witnesses', data: data);
      final witnessData = response.data['data']['item'];
      return PrayerPost.fromJson(witnessData);
    } catch (error) {
      throw Exception('Failed to create witness: $error');
    }
  }

  // 獲取特定貼文的所有Witness
  Future<List<PrayerPost>> getWitnessesForPost(String postId) async {
    try {
      final response = await _dio.get('v1/posts/$postId/witnesses');
      final witnessesData = response.data['data']['items'];
      return witnessesData
          .map<PrayerPost>((item) => PrayerPost.fromJson(item))
          .toList();
    } catch (error) {
      return [];
    }
  }
}