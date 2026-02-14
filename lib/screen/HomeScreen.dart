import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
// تم حذف سطر استيراد Facebook Ads نهائياً
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../app_localizations.dart';
import '../component/AppBarComponent.dart';
import '../component/FloatingComponent.dart';
import '../component/SideMenuComponent.dart';
import '../main.dart';
import '../model/MainResponse.dart';
import '../screen/DashboardScreen.dart';
import '../utils/AppWidget.dart';
import '../utils/common.dart';
import '../utils/constant.dart';
import '../utils/loader.dart';
import 'package:nb_utils/nb_utils.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:store_redirect/store_redirect.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_in_app_messaging/firebase_in_app_messaging.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'QRScannerScreen.dart';

class HomeScreen extends StatefulWidget {
  static String tag = '/HomeScreen';

  final String? mUrl, title;

  HomeScreen({this.mUrl, this.title});

  @override
  _HomeScreenState createState() => new _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  InAppWebViewController? webViewController;
  ReceivePort port = ReceivePort();
  PullToRefreshController? pullToRefreshController;

  List<TabsResponse> mTabList = [];
  List<MenuStyleModel> mBottomMenuList = [];

  String? mInitialUrl;

  bool isWasConnectionLoss = false;
  bool mIsPermissionGrant = false;


  void _getInstanceId() async {
    await Firebase.initializeApp();
    FirebaseInAppMessaging.instance.triggerEvent("");
    FirebaseMessaging.instance.getInitialMessage();
  }

  @override
  void initState() {
    WidgetsBinding.instance.addObserver(this);
    super.initState();
    // تم حذف سطر FacebookAudienceNetwork.init تماماً
    _getInstanceId();
    if (getStringAsync(IS_WEBRTC) == "true") {
      checkWebRTCPermission();
    }
    pullToRefreshController = PullToRefreshController(
      settings: PullToRefreshSettings(color: appStore.primaryColors, enabled: getStringAsync(IS_PULL_TO_REFRESH) == "true" ? true : false),
      onRefresh: () async {
        if (Platform.isAndroid) {
          webViewController?.reload();
        } else if (Platform.isIOS) {
          webViewController?.loadUrl(urlRequest: URLRequest(url: await webViewController?.getUrl()));
        }
      },
    );
    init();
  }

  Future<bool> checkPermission() async {
    if (Platform.isAndroid) {
      final status = await Permission.storage.status;
      if (status != PermissionStatus.granted) {
        final result = await Permission.storage.request();
        if (result == PermissionStatus.granted) {
          mIsPermissionGrant = true;
          setState(() {});
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

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> init() async {
    // إجبار التطبيق على فتح موقعك الشخصي مباشرة وتجاهل أي روابط خارجية
    mInitialUrl = "https://zarship.com/"; 

    if (webViewController != null) {
      await webViewController!.loadUrl(urlRequest: URLRequest(url: WebUri(mInitialUrl!)));
    } else {
      log("Controller not initialized yet");
    }
  }

  @override
  void didUpdateWidget(HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    setState(() {
      init();
    });
  }

  String? _extractTelegramUsername(String url) {
    final RegExp usernameRegex = RegExp(
      r'(?:https?://)?(?:www\.)?(?:t\.me|telegram\.me)[/]?([\w-]+)',
      caseSensitive: false,
    );
    final match = usernameRegex.firstMatch(url);
    return match?.group(1);
  }
  @override
  Widget build(BuildContext context) {
    var appLocalization = AppLocalizations.of(context);
    Future<bool> _exitApp() async {
      String? currentUrl = (await webViewController?.getUrl())?.toString();
      if (await webViewController!.canGoBack() && currentUrl != mInitialUrl) {
        webViewController!.goBack();
        return false;
      } else {
        if (getStringAsync(IS_Exit_POP_UP) == "true") {
          return mConfirmationDialog(() {
            Navigator.of(context).pop(false);
          }, context, appLocalization);
        } else {
          exit(0);
        }
      }
    }

    Widget mLoadWeb({String? mURL}) {
      return Stack(
        children: [
          FutureBuilder(
              future: Future.delayed(Duration(milliseconds: 200)),
              builder: (context, snapshot) {
                return InAppWebView(
                    initialUrlRequest: URLRequest(url: WebUri(mURL.isEmptyOrNull ? mInitialUrl! : mURL!)),
                    initialSettings: InAppWebViewSettings(
                      mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
                      allowBackgroundAudioPlaying: true,
                      transparentBackground: true,
                      useShouldOverrideUrlLoading: true,
                      userAgent: getStringAsync(USER_AGENT),
                      mediaPlaybackRequiresUserGesture: false,
                      allowsAirPlayForMediaPlayback: true,
                      allowFileAccessFromFileURLs: true,
                      useOnDownloadStart: true,
                      javaScriptCanOpenWindowsAutomatically: true,
                      javaScriptEnabled: true,
                      supportZoom: getStringAsync(IS_ZOOM_FUNCTIONALITY) == "true" ? true : false,
                      incognito: getStringAsync(IS_COOKIE) == "true" ? true : false,
                      clearCache: getStringAsync(IS_COOKIE) == "true" ? true : false,
                      useHybridComposition: true,
                      allowsInlineMediaPlayback: true,
                    ),
                    pullToRefreshController: pullToRefreshController,
                    onWebViewCreated: (controller) {
                      webViewController = controller;
                    },
                    onLoadStart: (controller, url) {
                      if (getStringAsync(IS_LOADER) == "true") appStore.setLoading(true);
                      setState(() {});
                    },
                    onProgressChanged: (controller, progress) {
                      if (progress == 100) {
                        pullToRefreshController!.endRefreshing();
                        if (getStringAsync(IS_LOADER) == "true") appStore.setLoading(false);
                        setState(() {});
                      }
                    },
                    onLoadStop: (controller, url) async {
                      pullToRefreshController!.endRefreshing();
                      if (getStringAsync(IS_LOADER) == "true") appStore.setLoading(false);
                      setState(() {});
                    },
                    shouldOverrideUrlLoading: (controller, navigationAction) async {
                      var url = navigationAction.request.url.toString();
                      if (url.contains("whatsapp://") || url.contains("tel:") || url.contains("mailto:") || url.contains("t.me")) {
                        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                        return NavigationActionPolicy.CANCEL;
                      }
                      return NavigationActionPolicy.ALLOW;
                    }).visible(isWasConnectionLoss == false);
              }),
          Container(color: Colors.white, height: context.height(), width: context.width(), child: Loaders(name: appStore.loaderValues).center()).visible(appStore.isLoading)
        ],
      );
    }
    Widget mBody() {
      return Container(
        color:appStore.primaryColors,
        child: SafeArea(
          child: Scaffold(
            drawerEdgeDragWidth: 0,
            appBar: PreferredSize(
              child: AppBarComponent(
                onTap: (value) {
                  if (value == RIGHT_ICON_RELOAD) webViewController!.reload();
                  if (RIGHT_ICON_SHARE == value) Share.share(getStringAsync(SHARE_CONTENT));
                  if (LEFT_ICON_HOME == value) DashBoardScreen().launch(context);
                  if (LEFT_ICON_BACK_1 == value || LEFT_ICON_BACK_2 == value) _exitApp();
                },
              ),
              preferredSize: Size.fromHeight(60.0),
            ),
            floatingActionButton: getStringAsync(IS_FLOATING) == "true" ? FloatingComponent() : SizedBox(),
            body: mLoadWeb(mURL: mInitialUrl),
            // تم إلغاء مساحة الإعلان نهائياً هنا
            bottomNavigationBar: SizedBox.shrink(), 
          ),
        ),
      );
    }

    return WillPopScope(
      onWillPop: _exitApp,
      child: mBody(),
    );
  }
}
