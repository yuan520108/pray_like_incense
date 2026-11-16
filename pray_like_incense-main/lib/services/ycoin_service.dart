import 'package:dio/dio.dart';
import '../models/prayer_post.dart';

class YCoinService {
  final Dio _dio;

  YCoinService(this._dio);

  // 獲取用戶Y幣餘額
  Future<int> getYCoinBalance(String userId) async {
    try {
      final response = await _dio.get('v1/users/$userId/ycoin');
      final data = response.data;
      return data['balance'] as int;
    } catch (error) {
      // 如果獲取失敗，返回預設值
      return 0;
    }
  }

  // 更新Y幣餘額（當用戶執行互動操作時）
  Future<void> updateYCoinBalance(String userId, int amount) async {
    try {
      await _dio.post('v1/users/$userId/ycoin/update', data: {
        'amount': amount,
      });
    } catch (error) {
      // 記錄錯誤但不中斷操作
      print('Failed to update Y coin balance: $error');
    }
  }

  // 處理貼文互動時的Y幣變化
  Future<void> handlePostInteraction(String userId, String action) async {
    int amount = 0;
    
    switch (action) {
      case 'create_post':
        amount = 10; // 發布貼文獲得10 Y幣
        break;
      case 'amen':
        amount = 1; // 按讚獲得1 Y幣
        break;
      case 'comment':
        amount = 2; // 評論獲得2 Y幣
        break;
      case 'witness':
        amount = 5; // Witness獲得5 Y幣
        break;
      case 'edit_post':
        amount = 3; // 編輯貼文獲得3 Y幣
        break;
      default:
        return; // 不處理未知操作
    }
    
    await updateYCoinBalance(userId, amount);
  }
}