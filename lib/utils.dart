import 'dart:io';

import 'package:lanyard_listening_along/config.dart';
import 'package:window_manager/window_manager.dart';


class Utils {
  static Future<void> setTitleSafe([String? status, bool includeAppTitle = false]) async {
    if (Platform.isWindows) {
      if (status == null) {
        await WindowManager.instance.setTitle(Config.appTitle);
      } else {
        await WindowManager.instance.setTitle("${includeAppTitle ? '${Config.appTitle} - ' : ''}$status");
      }
    }
  }
}