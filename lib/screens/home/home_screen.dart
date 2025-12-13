import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/attendance_provider.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_strings.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    // Schedule load after build completes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAttendance();
    });
  }

  Future<void> _loadAttendance() async {
    final authProvider = context.read<AuthProvider>();
    final attendanceProvider = context.read<AttendanceProvider>();

    if (authProvider.user != null) {
      await attendanceProvider.fetchAttendance(authProvider.user!.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      const DashboardPage(),
      const AttendancePage(),
      const ProfilePage(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.appName),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {
              // TODO: Navigate to notifications
            },
          ),
        ],
      ),
      body: pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        selectedItemColor: AppColors.primary,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: AppStrings.home,
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.check_circle_outline),
            activeIcon: Icon(Icons.check_circle),
            label: AppStrings.attendance,
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: AppStrings.profile,
          ),
        ],
      ),
    );
  }
}

// Dashboard Page
class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<AuthProvider, AttendanceProvider>(
      builder: (context, authProvider, attendanceProvider, _) {
        final stats = attendanceProvider.getStatistics();

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: AppColors.primaryLight,
                        child: Text(
                          authProvider.user?.name
                                  .substring(0, 1)
                                  .toUpperCase() ??
                              'U',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Welcome back,',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(color: AppColors.textSecondary),
                            ),
                            Text(
                              authProvider.user?.name ?? 'User',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Statistics
              Text(
                'Attendance Overview',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      title: 'Present',
                      value: stats['present'].toString(),
                      color: AppColors.present,
                      icon: Icons.check_circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      title: 'Late',
                      value: stats['late'].toString(),
                      color: AppColors.late,
                      icon: Icons.access_time,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      title: 'Absent',
                      value: stats['absent'].toString(),
                      color: AppColors.absent,
                      icon: Icons.cancel,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      title: 'Rate',
                      value: '${stats['attendanceRate']}%',
                      color: AppColors.info,
                      icon: Icons.trending_up,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;
  final IconData icon;

  const _StatCard({
    required this.title,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 12),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
            ),
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

// Attendance Page (Placeholder)
class AttendancePage extends StatelessWidget {
  const AttendancePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Attendance Page - To be implemented'));
  }
}

// Profile Page
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  Future<void> _handleLogout(BuildContext context) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await context.read<AuthProvider>().signOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        final user = authProvider.user;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const SizedBox(height: 20),

              // Profile Avatar
              CircleAvatar(
                radius: 60,
                backgroundColor: AppColors.primaryLight,
                child: user?.photoUrl != null
                    ? ClipOval(
                        child: Image.network(
                          user!.photoUrl!,
                          width: 120,
                          height: 120,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Text(
                              user.name.substring(0, 1).toUpperCase(),
                              style: const TextStyle(
                                fontSize: 48,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            );
                          },
                        ),
                      )
                    : Text(
                        user?.name.substring(0, 1).toUpperCase() ?? 'U',
                        style: const TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
              ),
              const SizedBox(height: 16),

              // User Name
              Text(
                user?.name ?? 'User',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 4),

              // User Email
              Text(
                user?.email ?? '',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
              const SizedBox(height: 8),

              // User Role Badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  user?.role.toUpperCase() ?? 'STUDENT',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Profile Info Card
              Card(
                child: Column(
                  children: [
                    if (user?.department != null)
                      ListTile(
                        leading: const Icon(Icons.business),
                        title: const Text('Department'),
                        subtitle: Text(user!.department!),
                      ),
                    if (user?.studentId != null)
                      ListTile(
                        leading: const Icon(Icons.badge),
                        title: const Text('Student ID'),
                        subtitle: Text(user!.studentId!),
                      ),
                    ListTile(
                      leading: const Icon(Icons.email),
                      title: const Text('Email'),
                      subtitle: Text(user?.email ?? ''),
                    ),
                    ListTile(
                      leading: const Icon(Icons.admin_panel_settings),
                      title: const Text('Role'),
                      subtitle: Text(user?.role ?? 'student'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Action Buttons
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    // TODO: Navigate to edit profile
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Edit profile - Coming soon!'),
                      ),
                    );
                  },
                  icon: const Icon(Icons.edit),
                  label: const Text('Edit Profile'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Logout Button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: authProvider.isLoading
                      ? null
                      : () => _handleLogout(context),
                  icon: authProvider.isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.logout),
                  label: Text(
                    authProvider.isLoading ? 'Logging out...' : 'Logout',
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: BorderSide(color: AppColors.error),
                    padding: const EdgeInsets.all(16),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
