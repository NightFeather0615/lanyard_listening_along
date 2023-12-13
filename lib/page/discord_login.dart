import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:lanyard_listening_along/config.dart';
import 'package:lanyard_listening_along/page/listening_along.dart';
import 'package:lanyard_listening_along/service/spotify_playback.dart';
import 'package:webview_windows/webview_windows.dart' as windows_webview;
import 'package:flutter_inappwebview/flutter_inappwebview.dart' as in_app_webview;
import 'package:window_manager/window_manager.dart';


class DiscordLoginPage extends StatefulWidget {
  const DiscordLoginPage({super.key});

  @override
  State<StatefulWidget> createState() => _DiscordLoginPage();
}

class _DiscordLoginPage extends State<DiscordLoginPage> {
  bool _isWebviewAvailable = false;
  final windows_webview.WebviewController _windowsWebviewController = windows_webview.WebviewController();
  final GlobalKey webViewKey = GlobalKey();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  StreamSubscription<dynamic>? _tokenInterceptSubscription;

  static const _getLocalStorageJs = """
const waitLocalStorageDelete = async () => {
  while (window.localStorage != undefined) {
    await new Promise(resolve => setTimeout(resolve, 500));
  }
  return;
};

(async function() {
  await waitLocalStorageDelete();
  const iframe = document.createElement('iframe');
  document.head.append(iframe);
  const pd = Object.getOwnPropertyDescriptor(iframe.contentWindow, 'localStorage');
  iframe.remove();
  Object.defineProperty(window, 'localStorage', pd);
})()
""";

  static const _clearLocalStorageJs = """
(function() {
  window.localStorage.clear();
})();
""";

  static const _httpHeaderInterceptJs = """
(function(setRequestHeader) {
  XMLHttpRequest.prototype.setRequestHeader = function(k, v) {
    if (k === "Authorization") {
      window.chrome.webview.postMessage(v);
    }
    setRequestHeader.call(this, k, v);
  };
})(XMLHttpRequest.prototype.setRequestHeader);
""";

  void _initWindowsWebview() async {
    if (await windows_webview.WebviewController.getWebViewVersion() == null) {
      setState(() {
        _isWebviewAvailable = false;
      });
      return;
    }

    await _windowsWebviewController.initialize();

    await _windowsWebviewController.clearCache();
    await _windowsWebviewController.clearCookies();

    await _windowsWebviewController.loadUrl(Config.discordLoginUrl);

    await _windowsWebviewController.executeScript(_getLocalStorageJs);
    await _windowsWebviewController.executeScript(_clearLocalStorageJs);
    await _windowsWebviewController.executeScript(_httpHeaderInterceptJs);

    _tokenInterceptSubscription = _windowsWebviewController.webMessage.listen((token) async {
      _tokenInterceptSubscription?.cancel();
      await _secureStorage.write(key: Config.discordTokenKey, value: token);
      await SpotifyPlayback.instance.token(token);
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const ListeningAlongPage())
        );
      }
    });

    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    
    if (Platform.isWindows) {
      Size loginWindowSize = const Size(860, 620);
      WindowManager.instance.setMinimumSize(loginWindowSize);
      WindowManager.instance.setMaximumSize(loginWindowSize);
      WindowManager.instance.setSize(loginWindowSize);
      WindowManager.instance.setTitle("${Config.appTitle} - Login to Discord");
    }

    if (Platform.isWindows) {
      _initWindowsWebview();
    }

    _secureStorage.read(key: Config.discordTokenKey).then((v) {
      if (v != null) {
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const ListeningAlongPage())
          );
        }
      }
    });
  }

  @override
  void dispose() {
    super.dispose();
    if (Platform.isWindows) {
      _windowsWebviewController.dispose();
    }
  }

  Widget? _getWebview() {
    if (Platform.isWindows) {
      if (_isWebviewAvailable) {
        return windows_webview.Webview(_windowsWebviewController);
      } else {
        return const Center(child: Text("webview2 error"),);
      }
    } else if (Platform.isIOS || Platform.isAndroid) {
      return SafeArea(
        child: in_app_webview.InAppWebView(
          key: webViewKey,
          initialOptions: in_app_webview.InAppWebViewGroupOptions(
            crossPlatform: in_app_webview.InAppWebViewOptions(
              useShouldInterceptAjaxRequest: true,
              clearCache: true
            )
          ),
          initialUrlRequest: in_app_webview.URLRequest(url: Uri.parse(Config.discordLoginUrl)),
          onWebViewCreated: (controller) async {

            await controller.clearCache();
            await controller.evaluateJavascript(source: _getLocalStorageJs);
            await controller.evaluateJavascript(source: _clearLocalStorageJs);
          },
          shouldInterceptAjaxRequest: (controller, ajaxRequest) async {
            if (ajaxRequest.headers != null) {
              String? token = ajaxRequest.headers?.getHeaders()["Authorization"];
              if (token != null) {
                await _secureStorage.write(key: Config.discordTokenKey, value: token);
                await SpotifyPlayback.instance.token(token);
                if (mounted) {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (context) => const ListeningAlongPage())
                  );
                }
              }
            }
            return ajaxRequest;
          },
        ),
      );
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _getWebview()
    );
  }
}
