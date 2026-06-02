import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../errors/app_error.dart';
import 'supabase_service.dart';

final edgeFunctionServiceProvider = Provider<EdgeFunctionService>((ref) {
  return EdgeFunctionService(ref.watch(supabaseServiceProvider));
});

class EdgeFunctionService {
  const EdgeFunctionService(this.supabaseService);

  final SupabaseService supabaseService;

  Future<T> callFunction<T>(
    String functionName, {
    Map<String, dynamic> body = const {},
    T Function(Object? data)? parser,
  }) async {
    if (!supabaseService.isConfigured) {
      throw const AppError('Supabase is not configured yet.');
    }

    final session = supabaseService.currentSession;
    if (session == null) {
      throw const AppError('Please log in to continue.',
          code: 'UNAUTHENTICATED');
    }

    final FunctionResponse response;
    try {
      response = await supabaseService.client.functions.invoke(
        functionName,
        body: body,
        headers: {'Authorization': 'Bearer ${session.accessToken}'},
        method: HttpMethod.post,
      );
    } on FunctionException catch (error) {
      throw _appErrorFromFunctionException(error);
    } on AppError {
      rethrow;
    } catch (_) {
      // Network drop, timeout, or any non-HTTP failure reaching the function.
      throw const AppError(
        'Could not reach the server. Check your connection and try again.',
        code: 'NETWORK',
      );
    }

    final payload = response.data;
    if (payload is! Map) {
      if (parser != null) return parser(payload);
      return payload as T;
    }

    final success = payload['success'] == true;
    if (!success) {
      throw _appErrorFromPayload(payload);
    }

    final data = payload['data'];
    if (parser != null) return parser(data);
    return data as T;
  }

  AppError _appErrorFromFunctionException(FunctionException error) {
    final details = error.details;
    if (details is Map) {
      return _appErrorFromPayload(
        details,
        fallback:
            error.reasonPhrase ?? 'Something went wrong. Please try again.',
      );
    }

    final message = details?.toString().trim();
    return AppError(
      message == null || message.isEmpty
          ? error.reasonPhrase ?? 'Something went wrong. Please try again.'
          : message,
    );
  }

  AppError _appErrorFromPayload(
    Map payload, {
    String fallback = 'Something went wrong. Please try again.',
  }) {
    return AppError(
      payload['message']?.toString() ?? fallback,
      code: payload['error_code']?.toString(),
    );
  }

  Future<T> call<T>(
    String functionName, {
    Map<String, dynamic> body = const {},
    T Function(Object? data)? parser,
  }) {
    return callFunction<T>(
      functionName,
      body: body,
      parser: parser,
    );
  }
}
