import 'dart:async';
import 'dart:io' as io;

import 'package:tkt/debug/log/log.dart';
import 'package:tkt/connector/core/connector.dart';
import 'package:tkt/connector/core/connector_parameter.dart';
import 'package:tkt/connector/core/dio_connector.dart';
import 'package:tkt/models/ntust/ap_tree_json.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:html/dom.dart';
import 'package:html/parser.dart';

enum NTUSTLoginStatus { success, fail }

class NTUSTConnector {
  static const String host = "https://i.ntust.edu.tw";
  static const String ntustLoginUrl =
      "https://stuinfosys.ntust.edu.tw/NTUSTSSOServ/SSO/Login/CourseSelection";

  static const String subSystemTWUrl = "$host/student";
  static const String subSystemENUrl = "$host/EN/student";

  static Future<Map<String, dynamic>> login(
      String account, String password) async {
    bool loadStop = false;
    try {
      final WebUri ntustLoginUri = WebUri(ntustLoginUrl);
      final cookieManager = CookieManager.instance();
      final cookieJar = DioConnector.instance.cookiesManager;
      var headlessWebView = HeadlessInAppWebView(
        initialUrlRequest: URLRequest(url: ntustLoginUri),
        onLoadStop: (InAppWebViewController controller, Uri? url) async {
          loadStop = true;
        },
      );
      var webView = headlessWebView.webViewController;
      await headlessWebView.run();
      int time = 0;
      while (true) {
        time += 1;
        await Future.delayed(const Duration(milliseconds: 100));
        if (time > 100) {
          break;
        }
        if (loadStop) {
          loadStop = false;
          if (await webView?.getUrl() == ntustLoginUri) {
            await Future.delayed(const Duration(milliseconds: 100));
            await webView?.evaluateJavascript(
                source:
                    'document.getElementsByName("UserName")[0].value = "$account";');
            await webView?.evaluateJavascript(
                source:
                    'document.getElementsByName("Password")[0].value = "$password";');
            await webView?.evaluateJavascript(
                source: 'document.getElementById("btnLogIn").click();');
            Future.delayed(const Duration(seconds: 5)).then((value) {});
            Log.d("wait 5 sec");
          } else {
            try {
              await cookieJar.deleteAll();
            } catch (e) {
              Log.d(e);
            }
            String? result = await webView?.getHtml();
            var tagNode = parse(result);
            var nodes =
                tagNode.getElementsByClassName("validation-summary-errors");
            if (nodes.length == 1) {
              return {
                "status": NTUSTLoginStatus.fail,
                "message": nodes[0].text.replaceAll("\n", "")
              };
            } else {
              var cookies = await cookieManager.getCookies(url: ntustLoginUri);
              List<io.Cookie> ioCookies = [];
              bool add = false;
              for (var i in cookies) {
                  io.Cookie k = io.Cookie(i.name, i.value);
                  k.domain = ".ntust.edu.tw";
                  k.path = "/";
                  ioCookies.add(k);
                  add = true;
              }
              if (add) {
                await cookieJar.saveFromResponse(ntustLoginUri, ioCookies);
                return {"status": NTUSTLoginStatus.success};
              } else {
                return {"status": NTUSTLoginStatus.fail};
              }
            }
          }
        }
      }
    } catch (e, stack) {
      Log.eWithStack(e, stack);
    }
    return {"status": NTUSTLoginStatus.fail};
  }

  static Future<List<APTreeJson>> getSubSystem() async {
    String result;
    Document tagNode;
    Element? node;
    List<Element> nodes;
    try {
      String subSystemUrl = subSystemTWUrl;
      ConnectorParameter parameter = ConnectorParameter(subSystemUrl);
      result = await Connector.getDataByGet(parameter);
      tagNode = parse(result);
      node = tagNode.getElementById("service");
      if(node == null) {
        return [];
      }

      List<APTreeJson> resList = [];


      var serviceFunctions = node.children.where((element) => element.id.contains("service")).toList();
      for (var i in serviceFunctions) {
        List<APListJson> apList = [];
        var serviceId = i.id;

        if(serviceId == "commonly-used-service") {
          continue;
        }

        var links = i.getElementsByTagName("a");

        for(var link in links) {
          apList.add(APListJson(name: link.text, url: link.attributes["href"] ?? "", type: "link"));
        }

        var tree = APTreeJson(serviceId, apList);
        resList.add(tree);
      }
      return resList;
    } catch (e) {
      Log.e(e);
      return [];
    }
  }

  static Future<Map<String, String>?> getCalendarUrl() async {
    String result;
    Document tagNode;
    Element node;
    List<Element> nodes;
    Map<String, String> selects = {};
    try {
      String host = "https://www.academic.ntust.edu.tw";
      String url = "$host/p/404-1048-78935.php?Lang=zh-tw";
      ConnectorParameter parameter = ConnectorParameter(url);
      result = await Connector.getDataByGet(parameter);
      tagNode = parse(result);
      nodes = tagNode.getElementsByClassName("meditor");
      node = nodes[1].getElementsByTagName("ul").last;
      for (var i in node.getElementsByTagName("li")) {
        String url = i.getElementsByTagName("a").first.attributes["href"]!;
        if (i.text.contains("google")) {
          continue;
        }
        String key = i.text.split("(").first;
        selects[key] = "$host/$url";
      }
      return selects;
    } catch (e) {
      return null;
    }
  }
}