import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class AgUiClient {
  final String baseUrl;
  final String demoUser;

  AgUiClient({
    this.baseUrl = 'http://127.0.0.1:8080',
    this.demoUser = 'flutter-developer',
  });

  Stream<Map<String, dynamic>> sendRun({
  String? threadId,
  String? runId,
  String? userPrompt,
  List<Map<String, dynamic>>? resumePayload,
}) async* {
  final uri = Uri.parse('$baseUrl/api/agui');
  final request = http.Request('POST', uri);

  request.headers.addAll({
    'Content-Type': 'application/json',
    'Accept': 'text/event-stream',
    'X-Demo-User': demoUser,
  });

  final Map<String, dynamic> body = {};

  // Always use non-empty valid threadId
  if (threadId != null && threadId.trim().isNotEmpty) {
    body['threadId'] = threadId.trim();
  }

  // Include runId if provided
  if (runId != null && runId.trim().isNotEmpty) {
    body['runId'] = runId.trim();
  }

  if (userPrompt != null && userPrompt.trim().isNotEmpty) {
    body['messages'] = [
      {'role': 'user', 'content': userPrompt.trim()}
    ];
  }

  if (resumePayload != null && resumePayload.isNotEmpty) {
    body['resume'] = resumePayload;
  }

  final jsonString = jsonEncode(body);
  print("--> OUTGOING AG-UI JSON: $jsonString");

  request.body = jsonString;

  final response = await http.Client().send(request);

  if (response.statusCode != 200) {
    final responseBody = await response.stream.bytesToString();
    print("--> BACKEND ERROR ${response.statusCode} RESPONSE: $responseBody");
    throw Exception('AG-UI HTTP Error ${response.statusCode}: $responseBody');
  }

  await for (final line in response.stream.toStringStream().transform(const LineSplitter())) {
    if (line.startsWith('data: ')) {
      final jsonStr = line.substring(6).trim();
      if (jsonStr.isNotEmpty) {
        yield jsonDecode(jsonStr) as Map<String, dynamic>;
      }
    }
  }
}

  Future<Map<String, dynamic>> verifyMpin({
    required String threadId,
    required String interruptId,
    required String mpin,
  }) async {
    final uri = Uri.parse('$baseUrl/api/confirmations/verify');
    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'X-Demo-User': demoUser,
      },
      body: jsonEncode({
        'threadId': threadId,
        'interruptId': interruptId,
        'mpin': mpin,
      }),
    );

    final decoded = jsonDecode(response.body);
    return {
      'statusCode': response.statusCode,
      'body': decoded,
    };
  }
}