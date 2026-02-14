import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:nb_utils/nb_utils.dart';

import '../utils/common.dart';
import '../utils/constant.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  InAppWebViewController? webViewController;
  PullToRefreshController? pullToRefreshController;

  @override
  void initState() {
    super.initState();

    pullToRefreshController = PullToRefreshController(
      settings: PullToRefreshSettings(
        color: appStore.primaryColors,
      ),
      onRefresh: () async {
        if (webViewController != null) {
          webViewController!.reload();
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: InAppWebView(
          initialUrlRequest: URLRequest(
            url: WebUri(APP_URL),
          ),
          initialSettings: InAppWebViewSettings(
            javaScriptEnabled: true,
            mediaPlaybackRequiresUserGesture: false,
            useShouldOverrideUrlLoading: true,
            allowsInlineMediaPlayback: true,
            useHybridComposition: true,
          ),
          pullToRefreshController: pullToRefreshController,
          onWebViewCreated: (controller) {
            webViewController = controller;
          },
          onLoadStop: (controller, url) async {
            pullToRefreshController?.endRefreshing();
          },
          onLoadError: (controller, url, code, message) {
            pullToRefreshController?.endRefreshing();
          },
          shouldOverrideUrlLoading:
              (controller, navigationAction) async {
            return NavigationActionPolicy.ALLOW;
          },
        ),
      ),
    );
  }
}
