import 'dart:io';

import 'package:lanyard_listening_along/config.dart';
import 'package:system_tray/system_tray.dart';
import 'package:window_manager/window_manager.dart';


class SystemTrayHandler {
  SystemTrayHandler._();

  static SystemTrayHandler? _instance;
  late final SystemTray systemTray;
  final Menu _menuSimple = Menu();

  static SystemTrayHandler get instance {
    if (_instance == null) {
      _instance = SystemTrayHandler._();
      _instance!.systemTray = SystemTray();
    }
    return _instance!;
  }

  String _getTrayImagePath(String imageName) {
    return Platform.isWindows ? 'assets/$imageName.ico' : 'assets/$imageName.png';
  }

  Future<void> initSystemTray() async {
    await systemTray.initSystemTray(
      title: Config.appTitle,
      toolTip: "Listening along on Spotify using Lanyard API",
      iconPath: _getTrayImagePath('app_icon')
    );

    systemTray.registerSystemTrayEventHandler((eventName) async {
      if (eventName == kSystemTrayEventClick) {
        if (await WindowManager.instance.isVisible()) {
          await WindowManager.instance.hide();
        } else {
          await WindowManager.instance.show();
        }
      }
    });

    await systemTray.setContextMenu(_menuSimple);
  }
}
