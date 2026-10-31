import 'package:http/http.dart' as http;

class BackendHealthService {
  const BackendHealthService();

  Future<String> check(String baseUrl) async {
    final uri = Uri.parse('${baseUrl.replaceAll(RegExp(r'/+$'), '')}/health');
    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 12));
      if (response.statusCode == 200) return 'Backend is reachable.';
      return 'Backend returned HTTP ${response.statusCode}.';
    } catch (_) {
      return 'Could not reach the backend. Check the URL and connection.';
    }
  }
}
