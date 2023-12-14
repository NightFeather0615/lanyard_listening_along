import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:lanyard_listening_along/config.dart';
import 'package:lanyard_listening_along/page/listening_along.dart';
import 'package:lanyard_listening_along/service/spotify_playback.dart';
import 'package:lanyard_listening_along/utils.dart';
import 'package:lanyard_listening_along/widget/error_message.dart';
import 'package:path_provider/path_provider.dart';
import 'package:webview_windows/webview_windows.dart' as webview2;
import 'package:window_manager/window_manager.dart';


class DiscordLoginPage extends StatefulWidget {
  const DiscordLoginPage({
    super.key
  });

  @override
  State<StatefulWidget> createState() => _DiscordLoginPage();
}

class _DiscordLoginPage extends State<DiscordLoginPage> {
  bool? _isWebView2Available;
  final webview2.WebviewController _windowsWebviewController = webview2.WebviewController();

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

  Future<void> _initWindowsWebview() async {
    if (await webview2.WebviewController.getWebViewVersion() == null) {
      await Utils.setTitleSafe("WebView2 not installed");
      setState(() {
        _isWebView2Available = false;
      });
      return;
    } else {
      _isWebView2Available = true;
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

    await Utils.setTitleSafe("Login to Discord");

    if (mounted) setState(() {});
  }

  Future<void> _initWebView() async {
    if (Platform.isWindows) {
      Size loginWindowSize = const Size(860, 620);
      await WindowManager.instance.setMinimumSize(loginWindowSize);
      await WindowManager.instance.setMaximumSize(loginWindowSize);
      await WindowManager.instance.setSize(loginWindowSize);
    }

    if (Platform.isWindows) {
      await _initWindowsWebview();
    }
  }

  Future<void> _setupWebView2() async {
    HttpClient httpClient = HttpClient();
    Directory cacheDir = await getApplicationCacheDirectory();
    File setupFile = File("${cacheDir.path}\\MicrosoftEdgeWebview2Setup.exe");
    HttpClientResponse res = await (
      await httpClient.getUrl(Uri.parse(Config.evergreenBootstrapperUrl))
    ).close();
    await setupFile.writeAsBytes(
      await consolidateHttpClientResponseBytes(res)
    );
    await Process.run(setupFile.path, []);
  }

  @override
  void initState() {
    super.initState();

    _initWebView();

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

  Widget _getWebview() {
    if (Platform.isWindows) {
      if (_isWebView2Available == null) {
        return const Center(child: CircularProgressIndicator(),);
      }
      if (_isWebView2Available!) {
        return webview2.Webview(
          _windowsWebviewController
        );
      } else {
        return ErrorMessage(
          title: "WebView2 not installed",
          description: const TextSpan(
            text: "Click the button below to set up WebView2, you may need to restart app or system to take effect"
          ),
          actionName: "Setup",
          onAction: () async {
            await _setupWebView2();
          },
        );
      }
    } else if (Platform.isIOS || Platform.isAndroid) {
      return SafeArea(
        child: InAppWebView(
          initialOptions: InAppWebViewGroupOptions(
            crossPlatform: InAppWebViewOptions(
              useShouldInterceptAjaxRequest: true,
              clearCache: true
            )
          ),
          initialUrlRequest: URLRequest(url: Uri.parse(Config.discordLoginUrl)),
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

    return const ErrorMessage(title: "Platform Unsupported");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _getWebview()
    );
  }
}
