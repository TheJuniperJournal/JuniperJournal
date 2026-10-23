import '../supabase_database.dart';

class AssessmentsRepo {
  Future<Map<String, dynamic>> session(String id) async =>
      Map<String, dynamic>.from(
        await SupabaseDatabase.instance.client.rpc(
          'assessment_session',
          params: {'p_id': id},
        ),
      );
  Future<Map<String, dynamic>> save(
    String id,
    Map<String, dynamic> answer, {
    required bool submit,
  }) async => Map<String, dynamic>.from(
    await SupabaseDatabase.instance.client.rpc(
      'save_assessment_response',
      params: {'p_id': id, 'p_answer': answer, 'p_submit': submit},
    ),
  );
}
