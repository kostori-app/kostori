import 'package:flutter_test/flutter_test.dart';
import 'package:kostori/network/app_dio.dart';

void main() {
  group('网络错误日志去重', () {
    test('未被网络层记录的异常不跳过', () {
      final err = DioException(
        requestOptions: RequestOptions(path: 'https://example.com/a'),
        type: DioExceptionType.connectionError,
      );
      expect(isNetworkErrorLogged(err), isFalse);
    });

    test('网络层记录过的异常会被识别', () {
      final options = RequestOptions(path: 'https://example.com/a');
      options.extra[loggedKey] = true;
      final err = DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
      );
      expect(isNetworkErrorLogged(err), isTrue);
    });

    test('非 Dio 异常一律视为未记录', () {
      expect(isNetworkErrorLogged(Exception('boom')), isFalse);
      expect(isNetworkErrorLogged('boom'), isFalse);
      expect(isNetworkErrorLogged(null), isFalse);
    });

    test('copyWith 传播的异常仍被识别为已记录', () {
      final options = RequestOptions(path: 'https://example.com/a');
      options.extra[loggedKey] = true;
      final err = DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
      );
      // 拦截器会用 copyWith 改写 message 后再抛出，标记在 extra 上需保留
      expect(isNetworkErrorLogged(err.copyWith(message: '重写后')), isTrue);
    });
  });
}
