import 'dart:convert';
import 'package:dio/dio.dart';
import 'models.dart';
import 'app_config.dart';

class ApiService {
  // URL manifest da AppConfig — non hardcodato
  static const String _manifestUrl = AppConfig.manifestUrl;

  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));

  Future<PackageManifest> scaricaManifest() async {
    try {
      final response = await _dio.get(_manifestUrl);
      // Fix GitHub Gist: serve text/plain invece di application/json
      final data = response.data is String
          ? jsonDecode(response.data)
          : response.data;
      return PackageManifest.fromJson(data);
    } on DioException catch (e) {
      throw Exception('Errore download manifest: ${e.message}');
    }
  }
}