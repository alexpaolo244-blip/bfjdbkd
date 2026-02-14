import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../main.dart';
import 'package:nb_utils/nb_utils.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

import 'constant.dart';
import 'loader.dart';

Color hexStringToHexInt(String hex) {
  hex = hex.replaceFirst('#', '');
  hex = hex.length == 6 ? 'ff' + hex : hex;
  int val = int.parse(hex, radix: 16);
  return Color(val);
}

launchURLString(String openUrl) async {
  if (await canLaunchUrl(Uri.parse(openUrl))) {
    await launchUrl(Uri.parse(openUrl), mode: LaunchMode.externalApplication);
  } else {
    throw 'Could not launch $openUrl';
  }
}

class CustomTheme extends StatelessWidget {
  final Widget? child;

  CustomTheme({this.child});

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: appStore.isDarkModeOn!
          ? ThemeData.dark().copyWith(
              colorScheme: ColorScheme.fromSwatch().copyWith(secondary: appStore.primaryColors),
            )
          : ThemeData.light(),
      child: child!,
    );
  }
}

String? getReferralCodeFromNative() {
  const platform = const MethodChannel('mightyweb/channel');

  if (isMobile) {
    var referralCode = platform.invokeMethod('mightyweb/events');
    return referralCode.toString();
  } else {
    return '';
  }
}

Future<bool> checkWebRTCPermission() async {
  await Permission.microphone.request();
  await Permission.camera.request();
  if (Platform.isAndroid) {
    final status = await Permission.microphone.status;
    final status1 = await Permission.camera.status;
    if (status != PermissionStatus.granted && status1 != PermissionStatus.granted) {
      final result = await Permission.microphone.request();
      final result1 = await Permission.camera.request();
      if (result == PermissionStatus.granted && result1 == PermissionStatus.granted) {
        if (getStringAsync(IS_LOADER) == "true") appStore.setLoading(true);
        return true;
      }
    } else {
      return true;
    }
  } else {
    return true;
  }
  return false;
}

class HttpOverridesSkipCertificate extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) =>
      super.createHttpClient(context)
        ..badCertificateCallback =
            (X509Certificate cert, String host, int port) => true;
}

/// 🔥 تم تعطيل الإعلانات بالكامل

void loadInterstitialAds() {}

void counterShowInterstitialAd() {}

void showInterstitialAds() {}

Widget showBannerAds() {
  return SizedBox();
}
