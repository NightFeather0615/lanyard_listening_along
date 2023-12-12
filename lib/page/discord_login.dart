import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:lanyard_listening_along/config.dart';
import 'package:lanyard_listening_along/page/listening_along.dart';
import 'package:lanyard_listening_along/service/spotify_playback.dart';
import 'package:webview_windows/webview_windows.dart';
import 'package:window_manager/window_manager.dart';


class DiscordLoginPage extends StatefulWidget {
  const DiscordLoginPage({super.key});

  @override
  State<StatefulWidget> createState() => _DiscordLoginPage();
}

class _DiscordLoginPage extends State<DiscordLoginPage> {
  final WebviewController _webviewController = WebviewController();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  StreamSubscription<dynamic>? _tokenInterceptSubscription;

  void _initWebview() async {
    await _webviewController.initialize();

    await _webviewController.clearCache();
    await _webviewController.clearCookies();

    await _webviewController.loadUrl(Config.discordLoginUrl);

    await _webviewController.executeScript("""
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
""");
    await _webviewController.executeScript("""
window.localStorage.clear();

(function(setRequestHeader) {
  XMLHttpRequest.prototype.setRequestHeader = function(k, v) {
    if (k === "Authorization") {
      window.chrome.webview.postMessage(v);
    }
    setRequestHeader.call(this, k, v);
  };
})(XMLHttpRequest.prototype.setRequestHeader);
""");

    _tokenInterceptSubscription = _webviewController.webMessage.listen((token) async {
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
    
    if (Platform.isWindows || Platform.isMacOS) {
      Size loginWindowSize = const Size(860, 620);
      WindowManager.instance.setMinimumSize(loginWindowSize);
      WindowManager.instance.setMaximumSize(loginWindowSize);
      WindowManager.instance.setSize(loginWindowSize);
      WindowManager.instance.setTitle("${Config.appTitle} - Login to Discord");
    }

    _initWebview();

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
    _webviewController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Webview(
        _webviewController
      )
    );
  }
}
