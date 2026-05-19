import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class WebsitePreviewScreen extends StatefulWidget {
  final String htmlContent;

  const WebsitePreviewScreen({
    super.key,
    required this.htmlContent,
  });

  @override
  State<WebsitePreviewScreen> createState() =>
      _WebsitePreviewScreenState();
}

class _WebsitePreviewScreenState
    extends State<WebsitePreviewScreen> {

  late final WebViewController controller;

  @override
  void initState() {
    super.initState();

    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadHtmlString(widget.htmlContent);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Website Preview"),
      ),
      body: WebViewWidget(
        controller: controller,
      ),
    );
  }
}