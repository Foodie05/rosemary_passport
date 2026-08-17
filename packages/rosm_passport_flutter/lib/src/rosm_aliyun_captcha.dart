import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'models.dart';
import 'rosm_passport_client.dart';

/// Executes the Aliyun Captcha 2.0 H5 challenge in a Flutter WebView.
///
/// The public prefix, scene ID, and region are fetched from the configured ROSM
/// issuer, so applications must not embed any captcha credentials.
class RosmAliyunCaptchaProvider {
  const RosmAliyunCaptchaProvider({this.title = '安全验证'});

  final String title;

  Future<String?> requestToken(
    BuildContext context,
    RosmPassportClient client,
  ) async {
    final config = await client.aliyunCaptchaConfig();
    if (config == null) {
      throw const RosmApiException(
        'captcha_not_configured',
        '当前 ROSM 服务未配置阿里云人机验证。',
      );
    }
    if (!context.mounted) return null;
    return Navigator.of(context).push<String>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _RosmAliyunCaptchaPage(
          config: config,
          title: title,
          baseUrl: client.issuer.replace(
            path: '/',
            query: null,
            fragment: null,
          ),
        ),
      ),
    );
  }
}

class RosmAliyunCaptchaConfig {
  const RosmAliyunCaptchaConfig({
    required this.prefix,
    required this.sceneId,
    this.region = 'cn',
  });

  factory RosmAliyunCaptchaConfig.fromJson(Map<String, dynamic> json) {
    return RosmAliyunCaptchaConfig(
      prefix: (json['prefix'] ?? '').toString().trim(),
      sceneId: (json['scene_id'] ?? '').toString().trim(),
      region: (json['region'] ?? 'cn').toString().trim(),
    );
  }

  final String prefix;
  final String sceneId;
  final String region;

  bool get isConfigured => prefix.isNotEmpty && sceneId.isNotEmpty;
}

class _RosmAliyunCaptchaPage extends StatefulWidget {
  const _RosmAliyunCaptchaPage({
    required this.config,
    required this.title,
    required this.baseUrl,
  });

  final RosmAliyunCaptchaConfig config;
  final String title;
  final Uri baseUrl;

  @override
  State<_RosmAliyunCaptchaPage> createState() => _RosmAliyunCaptchaPageState();
}

class _RosmAliyunCaptchaPageState extends State<_RosmAliyunCaptchaPage> {
  late final WebViewController _controller;
  var _loading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'RosmCaptcha',
        onMessageReceived: (message) {
          final token = message.message.trim();
          if (token.isNotEmpty && mounted) Navigator.of(context).pop(token);
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
          },
        ),
      )
      ..loadHtmlString(
        _pageHtml(widget.config),
        baseUrl: widget.baseUrl.toString(),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_loading) const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}

String _pageHtml(RosmAliyunCaptchaConfig config) {
  final globalConfig = jsonEncode({
    'region': config.region.isEmpty ? 'cn' : config.region,
    'prefix': config.prefix,
  });
  final sceneId = jsonEncode(config.sceneId);
  return '''<!doctype html>
<html><head><meta name="viewport" content="width=device-width, initial-scale=1">
<style>body{margin:0;padding:24px;font-family:-apple-system,BlinkMacSystemFont,sans-serif;background:#f6f8f3;color:#17352b}#rosm-captcha-trigger{width:100%;min-height:48px;border:0;border-radius:12px;background:#2f6b53;color:#fff;font-size:16px;font-weight:600}</style>
</head><body><p>请完成人机验证后继续。</p><button id="rosm-captcha-trigger">开始安全验证</button>
<script>window.AliyunCaptchaConfig=$globalConfig;</script>
<script src="https://o.alicdn.com/captcha-frontend/aliyunCaptcha/AliyunCaptcha.js"></script>
<script>window.addEventListener('load',function(){if(!window.initAliyunCaptcha){return;}window.initAliyunCaptcha({SceneId:$sceneId,mode:'popup',element:'#rosm-captcha-trigger',button:'#rosm-captcha-trigger',slideStyle:{width:360,height:40},success:function(captchaVerifyParam){window.RosmCaptcha.postMessage(captchaVerifyParam);},fail:function(){},close:function(){}});});</script>
</body></html>''';
}
