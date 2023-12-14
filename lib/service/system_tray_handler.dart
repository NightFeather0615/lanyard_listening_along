import "dart:io";

import "package:hive/hive.dart";
import "package:lanyard_listening_along/config.dart";
import "package:system_tray/system_tray.dart";
import "package:url_launcher/url_launcher.dart";
import "package:window_manager/window_manager.dart";


class SystemTrayHandler {
  SystemTrayHandler._();

  static SystemTrayHandler? _instance;
  late final SystemTray systemTray;
  final Menu contextMenu = Menu();
  final Box _prefs = Hive.box("sharedPrefs");

  static SystemTrayHandler get instance {
    if (_instance == null) {
      _instance = SystemTrayHandler._();
      _instance!.systemTray = SystemTray();
    }
    return _instance!;
  }

  String _getTrayImagePath(String imageName) {
    return Platform.isWindows ? "assets/$imageName.ico" : "assets/$imageName.png";
  }

  Future<void> initSystemTray() async {
    await systemTray.initSystemTray(
      title: Config.appTitle,
      toolTip: "Listening along on Spotify using Lanyard API",
      iconPath: _getTrayImagePath("app_icon")
    );

    systemTray.registerSystemTrayEventHandler((eventName) async {
      if (eventName == kSystemTrayEventClick) {
        if (await WindowManager.instance.isVisible()) {
          await WindowManager.instance.hide();
        } else {
          await WindowManager.instance.show();
        }
      } else if (eventName == kSystemTrayEventRightClick) {
        await systemTray.popUpContextMenu();
      }
    });

    await contextMenu.buildFrom([
      MenuItemCheckbox(
        label: "Check for updates",
        name: "checkUpdate",
        checked: _prefs.get("checkUpdate", defaultValue: true),
        onClicked: (menuItem) async {
          MenuItemCheckbox? checkUpdateCheckbox = contextMenu.findItemByName<MenuItemCheckbox>("checkUpdate");

          await checkUpdateCheckbox?.setCheck(!checkUpdateCheckbox.checked);
          await _prefs.put("checkUpdate", checkUpdateCheckbox!.checked);
        },
      ),
      MenuSeparator(),
      MenuItemLabel(
        label: "GitHub",
        onClicked: (menuItem) async {
          if (await canLaunchUrl(Uri.parse(Config.githubRepoUrl))) {
            await launchUrl(Uri.parse(Config.githubRepoUrl));
          }
        }
      ),
    ]);

    await systemTray.setContextMenu(contextMenu);
  }
}
