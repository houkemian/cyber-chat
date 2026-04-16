class ApiEndpoints {
  ApiEndpoints._();

  // TODO: align with build flavor/env system.
  static const String httpBaseUrl = 'http://localhost:8000';
  static const String wsBaseUrl = 'ws://localhost:8000';

  static const String authBase = '$httpBaseUrl/api/auth';
  static const String chatWsBase = '$wsBaseUrl/api/ws';
}
