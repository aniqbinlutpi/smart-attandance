import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ResetAttendanceButton extends StatelessWidget {
  const ResetAttendanceButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.delete_forever, color: Colors.red),
      tooltip: 'Reset Today\'s Attendance',
      onPressed: () async {
        final userId = Supabase.instance.client.auth.currentUser?.id;
        if (userId == null) return;

        try {
          // Delete ALL data for a complete reset
          final client = Supabase.instance.client;

          // 1. Delete logs
          await client.from('face_scan_logs').delete().eq('user_id', userId);

          // 2. Force CLOSE active sessions (since DELETE might be blocked by RLS)
          // We update check_out_time to "now" to unblock the check-in status
          await client
              .from('attendance')
              .update({
                'check_out_time': DateTime.now().toUtc().toIso8601String(),
              })
              .eq('user_id', userId)
              .isFilter('check_out_time', null);

          // 3. Clear face data in users table (Correct location)
          await client.from('users').update({
            'face_embeddings': null,
            'face_registered': false,
            'face_registered_at': null,
          }).eq('id', userId);

          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                    'RESET SUCCESS: Active sessions closed & Face data cleared.'),
                backgroundColor: Colors.green,
              ),
            );

            // Force re-navigation to refresh state
            Navigator.of(context).pushReplacementNamed('/');
          }
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error: $e')),
            );
          }
        }
      },
    );
  }
}
