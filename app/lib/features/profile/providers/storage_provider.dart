import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/supabase_service.dart';
import '../../auth/providers/auth_provider.dart';

final userStorageUsedProvider = FutureProvider.autoDispose<int>((ref) async {
  final profile = ref.watch(currentUserProfileProvider);
  if (profile == null) return 0;

  final supabase = ref.read(supabaseServiceProvider);
  if (!supabase.isConfigured || supabase.currentSession == null) return 0;

  final rows = await supabase.client
      .from('media_files')
      .select('file_size_bytes')
      .eq('uploader_id', profile.id)
      .eq('upload_status', 'completed')
      .eq('is_deleted', false);

  int total = 0;
  for (final row in rows as List) {
    total += (row['file_size_bytes'] as num?)?.toInt() ?? 0;
  }
  return total;
});
