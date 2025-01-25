import 'package:kostori/network/app_dio.dart';
import 'package:kostori/utils/utils.dart';

import 'interceptor.dart';

class Request {
  static final Request _instance = Request._internal();
  static late final Dio dio;

  factory Request() => _instance;

  static void setOptionsHeaders() {
    dio.options.headers['referer'] = '';
    dio.options.headers['user-agent'] = Utils.getRandomUA();
  }

  Request._internal() {
    //BaseOptions、Options、RequestOptions 都可以配置参数，优先级别依次递增，且可以根据优先级别覆盖参数
    BaseOptions options = BaseOptions(
      //请求基地址,可以包含子路径
      baseUrl: '',
      //连接服务器超时时间，单位是毫秒.
      connectTimeout: const Duration(milliseconds: 12000),
      //响应流上前后两次接受到数据的间隔，单位为毫秒。
      receiveTimeout: const Duration(milliseconds: 12000),
      //Http请求头.
      headers: {},
    );

    // enableSystemProxy = setting.get(SettingBoxKey.enableSystemProxy,
    //     defaultValue: false) as bool;

    dio = Dio(options);
    // debugPrint('Dio 初始化完成');

    // if (enableSystemProxy) {
    //   setProxy();
    //   debugPrint('系统代理启用');
    // }

    // 拦截器
    dio.interceptors.add(ApiInterceptor());

    // 日志拦截器 输出请求、响应内容
    dio.interceptors.add(LogInterceptor(
      request: false,
      requestHeader: false,
      responseHeader: false,
    ));

    dio.transformer = BackgroundTransformer();
    dio.options.validateStatus = (int? status) {
      return status! >= 200 && status < 300;
    };
  }

  Future<Response> get(url,
      {data, options, cancelToken, extra, bool shouldRethrow = false}) async {
    Response response;
    final Options options = Options();
    ResponseType resType = ResponseType.json;
    if (extra != null) {
      resType = extra!['resType'] ?? ResponseType.json;
      if (extra['ua'] != null) {
        options.headers = {'user-agent': headerUa(type: extra['ua'])};
      }
      if (extra['customError'] != null) {
        options.extra = {'customError': extra['customError']};
      }
    }
    options.responseType = resType;
    try {
      response = await dio.get(
        url,
        queryParameters: data,
        options: options,
        cancelToken: cancelToken,
      );
      return response;
    } on DioException catch (e) {
      if (shouldRethrow) {
        rethrow;
      }
      Response errResponse = Response(
        data: {
          'message': await ApiInterceptor.dioError(e)
        }, // 将自定义 Map 数据赋值给 Response 的 data 属性
        statusCode: 200,
        requestOptions: RequestOptions(),
      );
      return errResponse;
    }
  }

  Future<Response> post(url,
      {data,
      queryParameters,
      options,
      cancelToken,
      extra,
      bool shouldRethrow = false}) async {
    // print('post-data: $data');
    Response response;
    try {
      response = await dio.post(
        url,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
      // print('post success: ${response.data}');
      return response;
    } on DioException catch (e) {
      if (shouldRethrow) {
        rethrow;
      }
      Response errResponse = Response(
        data: {
          'message': await ApiInterceptor.dioError(e)
        }, // 将自定义 Map 数据赋值给 Response 的 data 属性
        statusCode: 200,
        requestOptions: RequestOptions(),
      );
      return errResponse;
    }
  }

  String headerUa({type = 'mob'}) {
    return Utils.getRandomUA();
  }
}
