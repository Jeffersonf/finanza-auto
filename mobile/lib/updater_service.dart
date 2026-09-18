import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

class AppUpdateInfo {
  final String version;
  final int buildNumber;
  final String releaseTag;
  final String downloadUrl;
  final String releaseNotes;
  final String releasedAt;
  final bool hasUpdate;

  const AppUpdateInfo({
    required this.version,
    required this.buildNumber,
    required this.releaseTag,
    required this.downloadUrl,
    required this.releaseNotes,
    required this.releasedAt,
    required this.hasUpdate,
  });

  factory AppUpdateInfo.fromJson(
    Map<String, dynamic> json, {
    required String currentVersion,
    required int currentBuild,
  }) {
    final remoteVersion = (json['version'] ?? '').toString().replaceFirst('v', '').trim();
    final remoteBuild = int.tryParse(json['buildNumber']?.toString() ?? '0') ?? 0;
    final hasUpdate = _isNewer(remoteVersion, remoteBuild, currentVersion, currentBuild);

    return AppUpdateInfo(
      version: remoteVersion,
      buildNumber: remoteBuild,
      releaseTag: json['releaseTag']?.toString() ?? 'v',
      downloadUrl: json['downloadUrl']?.toString() ??
          'https://github.com/Jeffersonf/finanza-auto/releases/latest/download/app-release.apk',
      releaseNotes: json['releaseNotes']?.toString() ?? 'Melhorias de desempenho e correcoes visuais.',
      releasedAt: json['releasedAt']?.toString() ?? '',
      hasUpdate: hasUpdate,
    );
  }

  static bool _isNewer(String remote, int remoteBuild, String current, int currentBuild) {
    if (remote.isEmpty) return false;
    final rParts = remote.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final cParts = current.split('.').map((e) => int.tryParse(e) ?? 0).toList();

    while (rParts.length < 3) {
      rParts.add(0);
    }
    while (cParts.length < 3) {
      cParts.add(0);
    }

    for (var i = 0; i < 3; i++) {
      if (rParts[i] > cParts[i]) return true;
      if (rParts[i] < cParts[i]) return false;
    }
    return remoteBuild > currentBuild;
  }
}

class UpdaterService {
  static const _channel = MethodChannel('com.jeffersonf.finanza_auto/updater');
  static const cloudflareVersionUrl = 'https://finanza-auto.jeffef.workers.dev/version.json';
  static const rawVersionUrl = 'https://raw.githubusercontent.com/Jeffersonf/finanza-auto/main/version.json';
  static const releasesApiUrl = 'https://api.github.com/repos/Jeffersonf/finanza-auto/releases/latest';

  static Future<AppUpdateInfo?> checkUpdate({
    required String currentVersion,
    required int currentBuild,
  }) async {
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 8);

      // 1. Tenta pegar primeiro do Cloudflare Worker (Instantâneo, zero delay de CDN)
      try {
        final cfUri = Uri.parse(cloudflareVersionUrl).replace(queryParameters: {
          't': DateTime.now().millisecondsSinceEpoch.toString(),
        });
        final request = await client.getUrl(cfUri);
        request.headers.set('User-Agent', 'FinanzaAutoApp/$currentVersion');
        request.headers.set('Cache-Control', 'no-cache, no-store, must-revalidate');
        request.headers.set('Pragma', 'no-cache');
        final response = await request.close();
        if (response.statusCode == 200) {
          final body = await response.transform(utf8.decoder).join();
          final data = json.decode(body) as Map<String, dynamic>;
          return AppUpdateInfo.fromJson(
            data,
            currentVersion: currentVersion,
            currentBuild: currentBuild,
          );
        }
      } catch (_) {}

      // 2. Tenta pegar de version.json no GitHub raw (sem rate-limit, com cache-buster)
      try {
        final versionUri = Uri.parse(rawVersionUrl).replace(queryParameters: {
          't': DateTime.now().millisecondsSinceEpoch.toString(),
        });
        final request = await client.getUrl(versionUri);
        request.headers.set('User-Agent', 'FinanzaAutoApp/$currentVersion');
        request.headers.set('Cache-Control', 'no-cache, no-store, must-revalidate');
        request.headers.set('Pragma', 'no-cache');
        final response = await request.close();
        if (response.statusCode == 200) {
          final body = await response.transform(utf8.decoder).join();
          final data = json.decode(body) as Map<String, dynamic>;
          return AppUpdateInfo.fromJson(
            data,
            currentVersion: currentVersion,
            currentBuild: currentBuild,
          );
        }
      } catch (_) {}

      // 3. Fallback para a API de Releases do GitHub
      try {
        final request = await client.getUrl(Uri.parse(releasesApiUrl));
        request.headers.set('User-Agent', 'FinanzaAutoApp');
        final response = await request.close();
        if (response.statusCode == 200) {
          final body = await response.transform(utf8.decoder).join();
          final data = json.decode(body) as Map<String, dynamic>;
          final tag = (data['tag_name'] ?? '').toString();
          final ver = tag.replaceFirst('v', '');
          String apkUrl = 'https://github.com/Jeffersonf/finanza-auto/releases/latest/download/app-release.apk';
          final assets = data['assets'] as List<dynamic>?;
          if (assets != null) {
            for (final a in assets) {
              if (a is Map && (a['name'] ?? '').toString().endsWith('.apk')) {
                apkUrl = a['browser_download_url'] ?? apkUrl;
                break;
              }
            }
          }
          return AppUpdateInfo.fromJson(
            {
              'version': ver,
              'buildNumber': 0,
              'releaseTag': tag,
              'downloadUrl': apkUrl,
              'releaseNotes': data['body'] ?? 'Nova versao disponivel no GitHub.',
              'releasedAt': data['published_at'] ?? '',
            },
            currentVersion: currentVersion,
            currentBuild: currentBuild,
          );
        }
      } catch (_) {}

      client.close();
    } catch (_) {}
    return null;
  }

  static Future<String?> downloadApk(
    String downloadUrl, {
    String version = '',
    int buildNumber = 0,
    required void Function(double progress) onProgress,
  }) async {
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 20);
      
      // Cache-buster na URL apenas se não for link assinado de redirecionamento (AWS S3 / Azure Blob)
      final uri = Uri.parse(downloadUrl);
      final isAwsOrSigned = downloadUrl.contains('X-Amz-Signature') ||
          downloadUrl.contains('release-assets.githubusercontent.com') ||
          downloadUrl.contains('objects.githubusercontent.com') ||
          downloadUrl.contains('sig=') ||
          downloadUrl.contains('jwt=');
      final requestUri = isAwsOrSigned
          ? uri
          : uri.replace(queryParameters: {
              ...uri.queryParameters,
              't': DateTime.now().millisecondsSinceEpoch.toString(),
            });

      final request = await client.getUrl(requestUri);
      request.headers.set('User-Agent', 'FinanzaAutoApp/${version.isNotEmpty ? version : "latest"}');
      request.headers.set('Cache-Control', 'no-cache, no-store, must-revalidate');
      request.headers.set('Pragma', 'no-cache');
      final response = await request.close();

      // Trata possíveis redirecionamentos do GitHub Releases (302)
      if (response.isRedirect) {
        final redirectUri = response.headers.value(HttpHeaders.locationHeader);
        if (redirectUri != null) {
          return downloadApk(
            redirectUri,
            version: version,
            buildNumber: buildNumber,
            onProgress: onProgress,
          );
        }
      }

      if (response.statusCode != 200) {
        return null;
      }

      final contentLength = response.contentLength;
      final tempDir = await getTemporaryDirectory();

      // Limpa APKs antigos na pasta temporária para não ocupar espaço nem reutilizar cache
      try {
        final list = tempDir.listSync();
        for (final item in list) {
          if (item is File && item.path.endsWith('.apk')) {
            await item.delete();
          }
        }
      } catch (_) {}

      // Nome do arquivo 100% exclusivo com versão, build e timestamp
      final stamp = DateTime.now().millisecondsSinceEpoch;
      final cleanVer = version.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
      final targetFile = File('${tempDir.path}/finanza-auto-v${cleanVer}_b${buildNumber}_$stamp.apk');

      final sink = targetFile.openWrite();
      var received = 0;

      await for (final chunk in response) {
        received += chunk.length;
        sink.add(chunk);
        if (contentLength > 0) {
          onProgress(received / contentLength);
        }
      }

      await sink.flush();
      await sink.close();
      client.close();

      // Validação de integridade: se contentLength foi informado e os bytes recebidos forem menores, arquivo está corrompido/incompleto
      if (contentLength > 0 && received < contentLength) {
        try {
          if (await targetFile.exists()) {
            await targetFile.delete();
          }
        } catch (_) {}
        return null;
      }

      return targetFile.path;
    } catch (e) {
      return null;
    }
  }

  static Future<bool> canRequestPackageInstalls() async {
    try {
      final res = await _channel.invokeMethod<bool>('canRequestPackageInstalls');
      return res ?? true;
    } catch (_) {
      return true;
    }
  }

  static Future<void> openInstallPermissionSettings() async {
    try {
      await _channel.invokeMethod<bool>('openInstallPermissionSettings');
    } catch (_) {}
  }

  static Future<bool> installApk(String filePath) async {
    try {
      final res = await _channel.invokeMethod<bool>('installApk', {'filePath': filePath});
      return res ?? false;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> downloadAndInstallApk({
    required String downloadUrl,
    String version = '',
    int buildNumber = 0,
    void Function(double progress)? onProgress,
  }) async {
    final path = await downloadApk(
      downloadUrl,
      version: version,
      buildNumber: buildNumber,
      onProgress: onProgress ?? (_) {},
    );
    if (path != null) {
      final canInstall = await canRequestPackageInstalls();
      if (!canInstall) {
        await openInstallPermissionSettings();
      }
      final success = await installApk(path);
      if (!success) {
        await openInBrowser(downloadUrl);
      }
      return success;
    } else {
      await openInBrowser(downloadUrl);
      return false;
    }
  }

  static Future<void> openInBrowser(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }
}
