import 'package:cloud_functions/cloud_functions.dart';

class CommunityService {
  static Future<Map<String, dynamic>> call(String name, Map<String, dynamic> data) async {
    final result = await FirebaseFunctions.instanceFor(region: 'asia-south1')
        .httpsCallable(name, options: HttpsCallableOptions(timeout: const Duration(seconds: 25))).call(data);
    return Map<String, dynamic>.from(result.data as Map);
  }

  static String error(Object error) {
    if (error is FirebaseFunctionsException &&
        ['invalid-argument', 'failed-precondition', 'permission-denied', 'unauthenticated', 'resource-exhausted'].contains(error.code)) {
      return error.message ?? 'Please check your details and try again.';
    }
    return 'Could not complete this right now. Your details are kept; please retry.';
  }
}
