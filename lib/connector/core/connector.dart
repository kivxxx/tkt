import 'package:dio/dio.dart';
import 'package:sprintf/sprintf.dart';
import 'package:tkt/debug/log/log.dart';

import 'connector_parameter.dart';
import 'dio_connector.dart';

class Connector {
  static Future<String> getDataByPost(ConnectorParameter parameter) async {
    try {
      String result = await DioConnector.instance.getDataByPost(parameter);
      return result;
    } catch (e) {
      rethrow;
    }
  }

  static Future<dynamic> getJsonByPost(ConnectorParameter parameter) async {
    try {
      Response result =
          await DioConnector.instance.getDataByPostResponse(parameter);
      return result.data;
    } catch (e) {
      rethrow;
    }
  }

  static Future<String> getDataByGet(ConnectorParameter parameter) async {
    try {
      String result = await DioConnector.instance.getDataByGet(parameter);
      return result;
    } catch (e) {
      rethrow;
    }
  }

  static Future<Response> getDataByGetResponse(
      ConnectorParameter parameter) async {
    Response result;
    try {
      result = await DioConnector.instance.getDataByGetResponse(parameter);
      return result;
    } catch (e) {
      rethrow;
    }
  }

  static Future<String> getRedirects(ConnectorParameter parameter,
      {usePost = false}) async {
    Response? result;
    Options options = Options(followRedirects: false);
    int redirectsTime = 0;
    try {
      while (redirectsTime <= 4) {
        Uri uri = Uri.parse(parameter.url);
        if (usePost) {
          result = await DioConnector.instance.getDataByPostResponse(parameter);
        } else {
          result = await DioConnector.instance.getDataByGetResponse(parameter);
        }
        usePost = false;
        if (result.statusCode != 302) {
          break;
        }
        String location = result.headers.value("location") ?? "";
        if (location.contains("http")) {
          parameter = ConnectorParameter(location);
        } else {
          parameter = ConnectorParameter("https://${uri.host}$location");
        }
        Log.d("redirects: ${parameter.url}");
      }
      if (redirectsTime == 4) {
        throw Exception("redirectsTime");
      }
      return result.toString();
    } catch (e) {
      rethrow;
    }
  }

  static Future<Response> getDataByPostResponse(
      ConnectorParameter parameter) async {
    Response result;
    try {
      result = await DioConnector.instance.getDataByPostResponse(parameter);
      return result;
    } catch (e) {
      rethrow;
    }
  }

  static void printHeader(Map<String, String> headers) {
    for (String key in headers.keys) {
      Log.d(sprintf("%s : %s", [key, headers[key]]));
    }
  }

  static String uriAddQuery(String url, Map<String, dynamic> queryParameters) {
    if (!url.contains('?')) {
      url += "?";
    }
    for (var i in queryParameters.keys) {
      url += '&$i=${queryParameters[i]}';
    }
    return url;
  }
}
