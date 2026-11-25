import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../theme/wl_tokens.dart';

/// Lucide icons used by Wardline (tokens.json → icon.set). One place, so a
/// screen never picks a random Material icon.
abstract final class WlIcons {
  static const IconData dashboard = LucideIcons.layoutDashboard;
  static const IconData patients = LucideIcons.users;
  static const IconData scan = LucideIcons.scanLine;
  static const IconData history = LucideIcons.history;
  static const IconData profile = LucideIcons.circleUser;
  static const IconData search = LucideIcons.search;
  static const IconData clear = LucideIcons.x;
  static const IconData close = LucideIcons.x;
  static const IconData check = LucideIcons.check;
  static const IconData chevronRight = LucideIcons.chevronRight;
  static const IconData chevronDown = LucideIcons.chevronDown;
  static const IconData back = LucideIcons.chevronLeft;
  static const IconData arrowRight = LucideIcons.arrowRight;
  static const IconData mapPin = LucideIcons.mapPin;
  static const IconData map = LucideIcons.map;
  static const IconData wifiOff = LucideIcons.wifiOff;
  static const IconData wifi = LucideIcons.wifi;
  static const IconData refresh = LucideIcons.refreshCw;
  static const IconData alert = LucideIcons.triangleAlert;
  static const IconData error = LucideIcons.circleAlert;
  static const IconData info = LucideIcons.info;
  static const IconData clock = LucideIcons.clock;
  static const IconData nfc = LucideIcons.nfc;
  static const IconData qr = LucideIcons.qrCode;
  static const IconData camera = LucideIcons.camera;
  static const IconData transfer = LucideIcons.arrowRightLeft;
  static const IconData status = LucideIcons.activity;
  static const IconData admission = LucideIcons.logIn;
  static const IconData bell = LucideIcons.bell;
  static const IconData settings = LucideIcons.settings;
  static const IconData logOut = LucideIcons.logOut;
  static const IconData filter = LucideIcons.slidersHorizontal;
  static const IconData building = LucideIcons.building2;
  static const IconData bed = LucideIcons.bedDouble;
  static const IconData user = LucideIcons.user;
  static const IconData shield = LucideIcons.shieldCheck;
  static const IconData timeline = LucideIcons.chartGantt;
  static const IconData layers = LucideIcons.layers;
  static const IconData route = LucideIcons.route;
  static const IconData list = LucideIcons.list;
  static const IconData eye = LucideIcons.eye;
  static const IconData lock = LucideIcons.lock;
  static const IconData mail = LucideIcons.mail;
  static const IconData motion = LucideIcons.zap;
  static const IconData tag = LucideIcons.tag;
  static const IconData printer = LucideIcons.printer;
  static const IconData play = LucideIcons.play;
  static const IconData chart = LucideIcons.chartColumn;
  static const IconData monitor = LucideIcons.monitor;
  static const IconData plus = LucideIcons.plus;
  static const IconData arrowUpDown = LucideIcons.arrowUpDown;

  /// Icon for a patient status (WlStatusStyle.lucideIcon).
  static IconData forStatus(PatientStatus status) => switch (status) {
    PatientStatus.admitted => LucideIcons.logIn,
    PatientStatus.inTreatment => LucideIcons.activity,
    PatientStatus.readyForDischarge => LucideIcons.circleCheck,
    PatientStatus.discharged => LucideIcons.logOut,
  };
}
