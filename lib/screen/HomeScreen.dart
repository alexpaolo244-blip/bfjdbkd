import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
// تم حذف سطر استيراد Facebook Ads من هنا
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
    // تم حذف سطر FacebookAudienceNetwork.init لضمان عدم وجود إعلانات فيسبوك
    Iterable mTabs = jsonDecode(getStringAsync(TABS));
    mTabList = mTabs.map((model) => TabsResponse.fromJson(model)).toList();
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
    // تم حذف استدعاء تحميل الإعلانات البينية
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
    init();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> init() async {
    String? referralCode = getReferralCodeFromNative();
    if (referralCode!.isNotEmpty) {
      mInitialUrl = referralCode;
    }

    if (getStringAsync(NAVIGATIONSTYLE) == NAVIGATION_STYLE_BOTTOM_NAVIGATION_SIDE_DRAWER) {
      Iterable mBottom = jsonDecode(getStringAsync(MENU_STYLE));
      mBottomMenuList = mBottom.map((model) => MenuStyleModel.fromJson(model)).toList();
    } else {
      Iterable mBottom = jsonDecode(getStringAsync(BOTTOMMENU));
      mBottomMenuList = mBottom.map((model) => MenuStyleModel.fromJson(model)).toList();
    }
    if (getStringAsync(NAVIGATIONSTYLE) == NAVIGATION_STYLE_BOTTOM_NAVIGATION || getStringAsync(NAVIGATIONSTYLE) == NAVIGATION_STYLE_BOTTOM_NAVIGATION_SIDE_DRAWER) {
      if (mBottomMenuList.isNotEmpty) {
        mInitialUrl = widget.mUrl;
      } else {
        mInitialUrl = getStringAsync(URL);
      }
    } else if (getStringAsync(NAVIGATIONSTYLE) == NAVIGATION_STYLE_TAB_BAR || getStringAsync(NAVIGATIONSTYLE) == NAVIGATION_STYLE_SIDE_DRAWER_TABS) {
      log(widget.mUrl);
      if (mTabList.isNotEmpty) {
        mInitialUrl = widget.mUrl;
        log(mInitialUrl);
      } else {
        mInitialUrl = getStringAsync(URL);
      }
    } else {
      mInitialUrl = getStringAsync(URL);
    }

    if (webViewController != null) {
      await webViewController!.loadUrl(urlRequest: URLRequest(url: WebUri(mInitialUrl!)));
    } else {
      log("sorry");
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
        log("--------------Show_exit");
        // تم حذف عرض الإعلانات البينية عند الخروج
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
                    initialUrlRequest: URLRequest(url: WebUri(mURL.isEmptyOrNull ? mInitialUrl.validate() : mURL!)),
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
                      javaScriptEnabled: getStringAsync(IS_JAVASCRIPT_ENABLE) == "true" ? true : false,
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
                      log("onLoadStart");
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
                      log("onLoadStop");
                      pullToRefreshController!.endRefreshing();
                      if (getStringAsync(IS_LOADER) == "true") appStore.setLoading(false);

                      await webViewController!.evaluateJavascript(source: """
                        if (typeof XMLHttpRequest.prototype.originalOpen === 'undefined') {
                          XMLHttpRequest.prototype.originalOpen = XMLHttpRequest.prototype.open;
                          XMLHttpRequest.prototype.open = function(method, url) {
                            this.originalOpen.apply(this, arguments);
                            if (url.includes('.mp3') || url.includes('.m4a')) {
                              this.setRequestHeader('Range', 'bytes=0-');
                            }
                          };
                        }
                      """);
                      if (getStringAsync(DISABLE_HEADER) == "true") {
                        webViewController!
                            .evaluateJavascript(source: "javascript:(function() { " + "var head = document.getElementsByTagName('header')[0];" + "head.parentNode.removeChild(head);" + "})()")
                            .then((value) => debugPrint('Page finished loading Javascript'))
                            .catchError((onError) => debugPrint('$onError'));
                      }

                      if (getStringAsync(DISABLE_FOOTER) == "true") {
                        webViewController!.evaluateJavascript(
                            source: "javascript:(function() {"
                                + "var footer = document.getElementsByTagName('footer')[0];"
                                + "if (footer) footer.parentNode.removeChild(footer);"
                                + "var customFooter = document.querySelector('section[data-ppt-blockid=\"footer1\"]');"
                                + "if (customFooter) customFooter.parentNode.removeChild(customFooter);"
                                + "console.log('Footer removed');"
                                + "})()"
                        ).then((value) => debugPrint('Footer removal script executed'))
                            .catchError((onError) => debugPrint('$onError'));
                      }
                      await webViewController!.evaluateJavascript(
                          source: """
                            console.log("WebView is ready.");
                            document.querySelectorAll('audio, video').forEach(media => {
                              media.setAttribute('preload', 'auto');
                              if(media.tagName === 'VIDEO') {
                                media.setAttribute('playsinline', 'true');
                                media.setAttribute('webkit-playsinline', 'true');
                              }
                            });
                          """
                      );
                      setState(() {});
                    },
                    onReceivedError: (InAppWebViewController controller, WebResourceRequest request, WebResourceError error) {
                      log("onLoadError");
                      if (getStringAsync(IS_LOADER) == "true") appStore.setLoading(false);
                      pullToRefreshController!.endRefreshing();
                      setState(() {});
                    },
                    shouldOverrideUrlLoading: (controller, navigationAction) async {
                      var uri = navigationAction.request.url;
                      var url = navigationAction.request.url.toString();
                      
                      if (url.startsWith('tg:') || url.contains('t.me') || url.contains('telegram.me')) {
                        try {
                          final username = _extractTelegramUsername(url);
                          if (username != null) {
                            final appUri = Uri.parse('tg://resolve?domain=$username');
                            if (await canLaunchUrl(appUri)) {
                              await launchUrl(appUri, mode: LaunchMode.externalNonBrowserApplication);
                            } else {
                              await launchUrl(Uri.parse('https://t.me/$username'), mode: LaunchMode.externalApplication);
                            }
                          }
                          return NavigationActionPolicy.CANCEL;
                        } catch (e) {
                          return NavigationActionPolicy.CANCEL;
                        }
                      }

                      if (url.contains("linkedin.com") || url.contains("whatsapp://") || url.contains("tel:") || url.contains("mailto:")) {
                        try {
                          await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                          return NavigationActionPolicy.CANCEL;
                        } catch (e) {
                          return NavigationActionPolicy.CANCEL;
                        }
                      }
                      return NavigationActionPolicy.ALLOW;
                    },
                    onDownloadStartRequest: (controller, downloadStartRequest) {
                      launchUrl(Uri.parse(downloadStartRequest.url.toString()), mode: LaunchMode.externalApplication);
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
            appBar: getStringAsync(NAVIGATIONSTYLE) != NAVIGATION_STYLE_FULL_SCREEN
                ? PreferredSize(
                    child: AppBarComponent(
                      onTap: (value) {
                        if (value == RIGHT_ICON_RELOAD) webViewController!.reload();
                        if (RIGHT_ICON_SHARE == value) Share.share(getStringAsync(SHARE_CONTENT));
                        if (LEFT_ICON_HOME == value) DashBoardScreen().launch(context);
                        if (LEFT_ICON_BACK_1 == value || LEFT_ICON_BACK_2 == value) _exitApp();
                      },
                    ),
                    preferredSize: Size.fromHeight((getStringAsync(NAVIGATIONSTYLE) == NAVIGATION_STYLE_TAB_BAR ||
                            getStringAsync(NAVIGATIONSTYLE) == NAVIGATION_STYLE_SIDE_DRAWER ||
                            getStringAsync(HEADERSTYLE) == HEADER_STYLE_CENTER ||
                            getStringAsync(NAVIGATIONSTYLE) == NAVIGATION_STYLE_BOTTOM_NAVIGATION_SIDE_DRAWER ||
                            getStringAsync(NAVIGATIONSTYLE) == NAVIGATION_STYLE_SIDE_DRAWER_TABS)
                        ? 60.0 : 0.0),
                  )
                : PreferredSize(child: SizedBox(), preferredSize: Size.fromHeight(0.0)),
            floatingActionButton: getStringAsync(IS_FLOATING) == "true" ? FloatingComponent() : SizedBox(),
            drawer: Drawer(
              child: SideMenuComponent(onTap: () {
                mInitialUrl = getStringAsync(URL).isNotEmpty ? getStringAsync(URL) : "https://www.google.com";
                webViewController!.reload();
              }),
            ).visible(getStringAsync(NAVIGATIONSTYLE) == NAVIGATION_STYLE_SIDE_DRAWER ||
                getStringAsync(NAVIGATIONSTYLE) == NAVIGATION_STYLE_BOTTOM_NAVIGATION_SIDE_DRAWER ||
                getStringAsync(NAVIGATIONSTYLE) == NAVIGATION_STYLE_SIDE_DRAWER_TABS),
            body: getStringAsync(NAVIGATIONSTYLE) == NAVIGATION_STYLE_TAB_BAR || getStringAsync(NAVIGATIONSTYLE) == NAVIGATION_STYLE_SIDE_DRAWER_TABS && appStore.mTabList.length != 0
                ? TabBarView(
                    physics: NeverScrollableScrollPhysics(),
                    children: [
                      for (int i = 0; i < mTabList.length; i++) mLoadWeb(mURL: mTabList[i].url),
                    ],
                  )
                : mLoadWeb(mURL: mInitialUrl),
            // تم تغيير showBannerAds() إلى SizedBox() لإلغاء مساحة الإعلان
            bottomNavigationBar: getStringAsync(NAVIGATIONSTYLE) == NAVIGATION_STYLE_BOTTOM_NAVIGATION || getStringAsync(NAVIGATIONSTYLE) == NAVIGATION_STYLE_BOTTOM_NAVIGATION_SIDE_DRAWER
                ? SizedBox.shrink()
                : SizedBox(), 
          ),
        ),
      );
    }

    return WillPopScope(
      onWillPop: _exitApp,
      child: getStringAsync(NAVIGATIONSTYLE) == NAVIGATION_STYLE_TAB_BAR || getStringAsync(NAVIGATIONSTYLE) == NAVIGATION_STYLE_SIDE_DRAWER_TABS
          ? DefaultTabController(
              length: appStore.mTabList.length,
              child: mBody(),
            )
          : mBody(),
    );
  }
}
