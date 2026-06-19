import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

const String baseUrl = "http://172.20.10.4:5000";

void main() {
  runApp(const AIAttendanceApp());
}

class DashboardStats {
  final int attendanceRate;
  final int present;
  final int absent;
  final int alerts;

  DashboardStats({
    required this.attendanceRate,
    required this.present,
    required this.absent,
    required this.alerts,
  });

  factory DashboardStats.fromJson(Map<String, dynamic> json) {
    return DashboardStats(
      attendanceRate: json["attendance_rate"] ?? 0,
      present: json["present"] ?? 0,
      absent: json["absent"] ?? 0,
      alerts: json["alerts"] ?? 0,
    );
  }
}


class StudentRecord {
  final String date;
  final String time;
  final String status;
  final dynamic confidence;

  StudentRecord({
    required this.date,
    required this.time,
    required this.status,
    required this.confidence,
  });

  factory StudentRecord.fromJson(Map<String, dynamic> json) {
    return StudentRecord(
      date: json["date"] ?? "",
      time: json["time"] ?? "",
      status: json["status"] ?? "",
      confidence: json["confidence"] ?? 0,
    );
  }
}


class StudentProfile {
  final String name;
  final String regNo;
  final String course;
  final String className;
  final String phone;

  StudentProfile({
    required this.name,
    required this.regNo,
    required this.course,
    required this.className,
    required this.phone,
  });

  factory StudentProfile.fromJson(Map<String, dynamic> json) {
    return StudentProfile(
      name: json["name"] ?? "",
      regNo: json["reg_no"] ?? "",
      course: json["course"] ?? "",
      className: json["class_name"] ?? "",
      phone: json["phone"] ?? "",
    );
  }
}


class AttendanceChartPoint {
  final String date;
  final String status;

  AttendanceChartPoint({
    required this.date,
    required this.status,
  });

  factory AttendanceChartPoint.fromJson(Map<String, dynamic> json) {
    return AttendanceChartPoint(
      date: json["date"] ?? "",
      status: json["status"] ?? "",
    );
  }

  bool get isPresent => status.toLowerCase() == "present";
}

class AdminRecentAttendance {
  final String regNo;
  final String name;
  final String date;
  final String time;
  final String status;

  AdminRecentAttendance({
    required this.regNo,
    required this.name,
    required this.date,
    required this.time,
    required this.status,
  });

  factory AdminRecentAttendance.fromJson(Map<String, dynamic> json) {
    return AdminRecentAttendance(
      regNo: json["reg_no"] ?? "",
      name: json["name"] ?? "",
      date: json["date"] ?? "",
      time: json["time"] ?? "",
      status: json["status"] ?? "",
    );
  }
}

class AdminDashboardData {
  final int totalStudents;
  final int presentToday;
  final int absentToday;
  final int totalRecords;
  final List<AdminRecentAttendance> recent;

  AdminDashboardData({
    required this.totalStudents,
    required this.presentToday,
    required this.absentToday,
    required this.totalRecords,
    required this.recent,
  });

  factory AdminDashboardData.fromJson(Map<String, dynamic> json) {
    final recentList = json["recent"] as List? ?? [];

    return AdminDashboardData(
      totalStudents: json["total_students"] ?? 0,
      presentToday: json["present_today"] ?? 0,
      absentToday: json["absent_today"] ?? 0,
      totalRecords: json["total_records"] ?? 0,
      recent: recentList
          .map((e) => AdminRecentAttendance.fromJson(e))
          .toList(),
    );
  }
}

class AdminStudent {
  final String regNo;
  final String name;
  final String course;
  final String className;
  final String phone;

  AdminStudent({
    required this.regNo,
    required this.name,
    required this.course,
    required this.className,
    required this.phone,
  });

  factory AdminStudent.fromJson(Map<String, dynamic> json) {
    return AdminStudent(
      regNo: json["reg_no"] ?? "",
      name: json["name"] ?? "",
      course: json["course"] ?? "",
      className: json["class_name"] ?? "",
      phone: json["phone"] ?? "",
    );
  }
}


class AdminAttendanceRecord {
  final String regNo;
  final String name;
  final String date;
  final String time;
  final String status;
  final String latitude;
  final String longitude;
  final dynamic confidence;

  AdminAttendanceRecord({
    required this.regNo,
    required this.name,
    required this.date,
    required this.time,
    required this.status,
    required this.latitude,
    required this.longitude,
    required this.confidence,
  });

  factory AdminAttendanceRecord.fromJson(Map<String, dynamic> json) {
    return AdminAttendanceRecord(
      regNo: json["reg_no"] ?? "",
      name: json["name"] ?? "",
      date: json["date"] ?? "",
      time: json["time"] ?? "",
      status: json["status"] ?? "",
      latitude: (json["latitude"] ?? "").toString(),
      longitude: (json["longitude"] ?? "").toString(),
      confidence: json["confidence"] ?? 0,
    );
  }
}



class AdminAbsentStudent {
  final String regNo;
  final String name;

  AdminAbsentStudent({
    required this.regNo,
    required this.name,
  });

  factory AdminAbsentStudent.fromJson(Map<String, dynamic> json) {
    return AdminAbsentStudent(
      regNo: json["reg_no"] ?? "",
      name: json["name"] ?? "",
    );
  }
}

class AdminAlertsData {
  final List<AdminAbsentStudent> absentToday;

  AdminAlertsData({
    required this.absentToday,
  });

  factory AdminAlertsData.fromJson(Map<String, dynamic> json) {
    final absentList = json["absent_today"] as List? ?? [];

    return AdminAlertsData(
      absentToday:
      absentList.map((e) => AdminAbsentStudent.fromJson(e)).toList(),
    );
  }
}

class AIAttendanceApp extends StatelessWidget {
  const AIAttendanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI Attendance',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xffeef2ff),
        primaryColor: const Color(0xff6d5dfc),
      ),
      home: const LoginScreen(),
    );
  }
}

/* LOGIN */

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final usernameController = TextEditingController();
  final passwordController = TextEditingController();

  Future<void> login() async {
    final username = usernameController.text.trim();
    final password = passwordController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enter username and password")),
      );
      return;
    }

    try {
      final response = await http.post(
        Uri.parse("$baseUrl/api/login"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "username": username,
          "password": password,
        }),
      );

      final data = jsonDecode(response.body);

      if (data["success"] == true) {
        if (data["role"] == "admin") {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => const AdminMainScreen(),
            ),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => StudentMainScreen(
                name: data["name"] ?? "Student",
                regNo: data["reg_no"] ?? "",
              ),
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data["message"] ?? "Login failed")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Server error: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffeef2ff),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(26),
            child: Column(
              children: [
                Container(
                  width: 82,
                  height: 82,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(26),
                    gradient: const LinearGradient(
                      colors: [Color(0xff6d5dfc), Color(0xff8b5cf6)],
                    ),
                  ),
                  child: const Icon(
                    Icons.camera_alt_rounded,
                    color: Colors.white,
                    size: 38,
                  ),
                ),
                const SizedBox(height: 22),
                const Text(
                  "AI Attendance",
                  style: TextStyle(
                    fontSize: 31,
                    fontWeight: FontWeight.w900,
                    color: Color(0xff111827),
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  "Face Recognition • GPS • Smart Alerts",
                  style: TextStyle(color: Color(0xff64748b)),
                ),
                const SizedBox(height: 35),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: boxStyle(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Center(
                        child: Text(
                          "Welcome Back",
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(height: 25),
                      const Text(
                        "Username / Reg No",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: usernameController,
                        decoration: inputDecoration(
                          "Enter username",
                          Icons.person,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        "Password",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: passwordController,
                        obscureText: true,
                        decoration: inputDecoration(
                          "Enter password",
                          Icons.lock,
                        ),
                      ),
                      const SizedBox(height: 25),
                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton(
                          onPressed: login,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xff6d5dfc),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          child: const Text(
                            "Login",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/* MAIN SCREEN */

class StudentMainScreen extends StatefulWidget {
  final String name;
  final String regNo;

  const StudentMainScreen({
    super.key,
    required this.name,
    required this.regNo,
  });

  @override
  State<StudentMainScreen> createState() => _StudentMainScreenState();
}

class _StudentMainScreenState extends State<StudentMainScreen> {
  int currentIndex = 0;

  void changePage(int index) {
    setState(() {
      currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: AppSideDrawer(
        name: widget.name,
        regNo: widget.regNo,
        onTapPage: (index) {
          Navigator.pop(context);
          changePage(index);
        },
      ),
      body: SafeArea(
        child: Builder(
          builder: (innerContext) {
            final pages = [
              StudentHomePage(
                name: widget.name,
                regNo: widget.regNo,
                onMenuTap: () {
                  Scaffold.of(innerContext).openDrawer();
                },
                onNotificationTap: () {
                  changePage(3);
                },
                onQuickAction: changePage,
              ),
              MarkAttendancePage(regNo: widget.regNo),
              RecordsPage(regNo: widget.regNo),
              NotificationsPage(regNo: widget.regNo),
              ProfilePage(name: widget.name, regNo: widget.regNo),
            ];

            return pages[currentIndex];
          },
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(28),
            topRight: Radius.circular(28),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.10),
              blurRadius: 22,
              offset: const Offset(0, -8),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: currentIndex,
          onTap: changePage,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: const Color(0xff6d5dfc),
          unselectedItemColor: const Color(0xff94a3b8),
          backgroundColor: Colors.transparent,
          elevation: 0,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: "Home"),
            BottomNavigationBarItem(icon: Icon(Icons.camera_alt_rounded), label: "Mark"),
            BottomNavigationBarItem(icon: Icon(Icons.article_rounded), label: "Records"),
            BottomNavigationBarItem(icon: Icon(Icons.notifications_rounded), label: "Alerts"),
            BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: "Profile"),
          ],
        ),
      ),
    );
  }
}

/* DRAWER */

class AppSideDrawer extends StatelessWidget {
  final String name;
  final String regNo;
  final Function(int) onTapPage;

  const AppSideDrawer({
    super.key,
    required this.name,
    required this.regNo,
    required this.onTapPage,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xff6d5dfc), Color(0xff9b5cf6)],
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.white,
                  child: Icon(Icons.school, color: Color(0xff6d5dfc)),
                ),
                const SizedBox(height: 12),
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
                Text(
                  regNo,
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          drawerItem(Icons.home, "Dashboard", () => onTapPage(0)),
          drawerItem(Icons.camera_alt, "Mark Attendance", () => onTapPage(1)),
          drawerItem(Icons.article, "My Records", () => onTapPage(2)),
          drawerItem(Icons.notifications, "Notifications", () => onTapPage(3)),
          drawerItem(Icons.person, "Profile", () => onTapPage(4)),
          const Divider(),
          drawerItem(Icons.logout, "Logout", () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const LoginScreen()),
            );
          }, color: Colors.red),
        ],
      ),
    );
  }

  Widget drawerItem(
      IconData icon,
      String title,
      VoidCallback onTap, {
        Color color = const Color(0xff111827),
      }) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xff6d5dfc)),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
      onTap: onTap,
    );
  }
}

/* HOME WITH REAL STATS */

class StudentHomePage extends StatefulWidget {
  final String name;
  final String regNo;
  final VoidCallback onMenuTap;
  final VoidCallback onNotificationTap;
  final Function(int) onQuickAction;

  const StudentHomePage({
    super.key,
    required this.name,
    required this.regNo,
    required this.onMenuTap,
    required this.onNotificationTap,
    required this.onQuickAction,
  });

  @override
  State<StudentHomePage> createState() => _StudentHomePageState();
}

class _StudentHomePageState extends State<StudentHomePage> {
  DashboardStats? stats;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadStats();
  }

  Future<void> loadStats() async {
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/api/student_dashboard/${widget.regNo}"),
      );

      final data = jsonDecode(response.body);

      setState(() {
        stats = DashboardStats.fromJson(data);
        loading = false;
      });
    } catch (e) {
      setState(() {
        stats = DashboardStats(
          attendanceRate: 0,
          present: 0,
          absent: 0,
          alerts: 0,
        );
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = stats ??
        DashboardStats(
          attendanceRate: 0,
          present: 0,
          absent: 0,
          alerts: 0,
        );

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xffeef2ff), Color(0xfff8fafc)],
        ),
      ),
      child: RefreshIndicator(
        onRefresh: loadStats,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DashboardTopBar(
                onMenuTap: widget.onMenuTap,
                onNotificationTap: widget.onNotificationTap,
              ),
              const SizedBox(height: 22),
              HomeHeader(name: widget.name, regNo: widget.regNo),
              const SizedBox(height: 18),
              TodayCard(isMarked: s.present > 0),
              const SizedBox(height: 18),
              loading
                  ? const Center(child: CircularProgressIndicator())
                  : AttendanceRateCard(rate: s.attendanceRate),
              const SizedBox(height: 18),
              AttendanceChartCard(regNo: widget.regNo),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: SmallStatCard(
                      title: "Present",
                      value: "${s.present}",
                      color: Colors.green,
                      icon: Icons.check,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SmallStatCard(
                      title: "Absent",
                      value: "${s.absent}",
                      color: Colors.red,
                      icon: Icons.close,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SmallStatCard(
                      title: "Alerts",
                      value: "${s.alerts}",
                      color: Colors.orange,
                      icon: Icons.remove_red_eye,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 25),
              const SectionTitle(title: "Quick Actions"),
              ActionCard(
                icon: Icons.camera_alt,
                title: "Mark Attendance",
                subtitle: "Face scan + GPS location",
                color: Colors.green,
                onTap: () => widget.onQuickAction(1),
              ),
              ActionCard(
                icon: Icons.article,
                title: "My Records",
                subtitle: "View attendance history",
                color: Colors.blue,
                onTap: () => widget.onQuickAction(2),
              ),
              ActionCard(
                icon: Icons.person,
                title: "My Profile",
                subtitle: "View your profile",
                color: Colors.purple,
                onTap: () => widget.onQuickAction(4),
              ),
              ActionCard(
                icon: Icons.notifications,
                title: "Notifications",
                subtitle: "Smart alerts and updates",
                color: Colors.orange,
                onTap: () => widget.onQuickAction(3),
              ),
              const SizedBox(height: 20),
              const AIFeatureCard(),
              const SizedBox(height: 20),
              const AnnouncementCard(),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

/* HOME WIDGETS */

class DashboardTopBar extends StatelessWidget {
  final VoidCallback onMenuTap;
  final VoidCallback onNotificationTap;

  const DashboardTopBar({
    super.key,
    required this.onMenuTap,
    required this.onNotificationTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        roundIcon(Icons.menu, onMenuTap),
        Stack(
          children: [
            roundIcon(Icons.notifications, onNotificationTap),
            Positioned(
              right: 10,
              top: 10,
              child: Container(
                width: 9,
                height: 9,
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget roundIcon(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.07),
              blurRadius: 18,
            ),
          ],
        ),
        child: Icon(icon, color: const Color(0xff111827)),
      ),
    );
  }
}

class HomeHeader extends StatelessWidget {
  final String name;
  final String regNo;

  const HomeHeader({
    super.key,
    required this.name,
    required this.regNo,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(
        minHeight: 175,
      ),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xff6d5dfc), Color(0xff9b5cf6)],
        ),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.deepPurple.withOpacity(0.28),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Welcome,\n$name",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Stay consistent, stay on track!",
                  style: TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 68,
            height: 68,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.school,
              color: Color(0xff6d5dfc),
              size: 34,
            ),
          ),
        ],
      ),
    );
  }
}

class TodayCard extends StatelessWidget {
  final bool isMarked;

  const TodayCard({
    super.key,
    required this.isMarked,
  });

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final dateText =
        "${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: boxStyle(),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Today", style: TextStyle(color: Color(0xff64748b))),
              const SizedBox(height: 6),
              Text(
                dateText,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 17,
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: isMarked ? const Color(0xffdcfce7) : const Color(0xffffedd5),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              isMarked ? "Present" : "Not Marked",
              style: TextStyle(
                color: isMarked ? const Color(0xff15803d) : const Color(0xffc2410c),
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/* MARK ATTENDANCE */

class MarkAttendancePage extends StatefulWidget {
  final String regNo;

  const MarkAttendancePage({
    super.key,
    required this.regNo,
  });

  @override
  State<MarkAttendancePage> createState() => _MarkAttendancePageState();
}

class _MarkAttendancePageState extends State<MarkAttendancePage> {
  CameraController? cameraController;
  bool cameraReady = false;
  bool isMarking = false;

  String liveStatus = "Waiting";
  String attentionStatus = "Waiting";
  String gpsStatus = "Required";
  String message = "Start camera to scan your face";

  Future<void> startCamera() async {
    try {
      final cameras = await availableCameras();

      final frontCamera = cameras.firstWhere(
            (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      cameraController = CameraController(
        frontCamera,
        ResolutionPreset.low,
        enableAudio: false,
      );

      await cameraController!.initialize();

      setState(() {
        cameraReady = true;
        liveStatus = "Camera Active";
        attentionStatus = "Look at Camera";
        message = "Camera started. Keep your face inside the frame.";
      });
    } catch (e) {
      setState(() {
        message = "Camera error: $e";
      });
    }
  }

  Future<Position?> getCurrentPosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      setState(() {
        gpsStatus = "GPS Off";
        message = "Please turn on location services.";
      });
      return null;
    }

    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      setState(() {
        gpsStatus = "Denied";
        message = "Location permission is required.";
      });
      return null;
    }

    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    setState(() {
      gpsStatus = "Verified";
    });

    return position;
  }

  Future<void> captureAndMark() async {
    if (!cameraReady || cameraController == null) {
      setState(() {
        message = "Start camera first.";
      });
      return;
    }

    if (isMarking) return;

    setState(() {
      isMarking = true;
      liveStatus = "Live Verified";
      attentionStatus = "Good";
      message = "Getting GPS location...";
    });

    try {
      final position = await getCurrentPosition();

      if (position == null) {
        setState(() {
          isMarking = false;
        });
        return;
      }

      setState(() {
        message = "Capturing face...";
      });

      final picture = await cameraController!.takePicture();

      setState(() {
        message = "Sending to AI server...";
      });

      final request = http.MultipartRequest(
        "POST",
        Uri.parse("$baseUrl/api/recognize_face"),
      );

      request.fields["reg_no"] = widget.regNo;
      request.fields["liveness"] = "Live Verified";
      request.fields["attention"] = "Good";
      request.fields["latitude"] = position.latitude.toString();
      request.fields["longitude"] = position.longitude.toString();

      request.files.add(await http.MultipartFile.fromPath("image", picture.path));

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();
      final data = jsonDecode(responseBody);

      setState(() {
        message = data["message"] ?? "No response from server";
        isMarking = false;
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(data["message"] ?? "No response"),
          backgroundColor: data["recognized"] == true ? Colors.green : Colors.red,
        ),
      );
    } catch (e) {
      setState(() {
        isMarking = false;
        message = "Error: $e";
      });
    }
  }

  @override
  void dispose() {
    cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(22),
      child: Column(
        children: [
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              "AI Face Scan",
              style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(height: 8),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              "Scan face and verify GPS location",
              style: TextStyle(color: Color(0xff64748b)),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            height: 390,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(32),
            ),
            clipBehavior: Clip.antiAlias,
            child: cameraReady && cameraController != null
                ? Stack(
              children: [
                FullScreenCameraPreview(controller: cameraController!, borderRadius: 32),
                Center(
                  child: Container(
                    width: 240,
                    height: 240,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.greenAccent, width: 4),
                    ),
                  ),
                ),
              ],
            )
                : const Center(
              child: Icon(Icons.camera_alt_rounded, color: Colors.white, size: 70),
            ),
          ),
          const SizedBox(height: 18),
          card(
            child: Column(
              children: [
                statusRow(Icons.shield, "Liveness", liveStatus),
                statusRow(Icons.remove_red_eye, "Attention", attentionStatus),
                statusRow(Icons.location_on, "GPS Location", gpsStatus),
                const SizedBox(height: 12),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xff64748b),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton.icon(
              onPressed: startCamera,
              icon: const Icon(Icons.camera_alt),
              label: const Text("Start Camera"),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xff6d5dfc),
                foregroundColor: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton.icon(
              onPressed: isMarking ? null : captureAndMark,
              icon: const Icon(Icons.check_circle),
              label: Text(isMarking ? "Marking..." : "Capture & Mark Attendance"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black87,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget statusRow(IconData icon, String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xff6d5dfc)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.green,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

/* WIDGETS */


class AttendanceChartCard extends StatefulWidget {
  final String regNo;

  const AttendanceChartCard({
    super.key,
    required this.regNo,
  });

  @override
  State<AttendanceChartCard> createState() => _AttendanceChartCardState();
}

class _AttendanceChartCardState extends State<AttendanceChartCard> {
  bool loading = true;
  List<AttendanceChartPoint> points = [];

  @override
  void initState() {
    super.initState();
    loadChart();
  }

  Future<void> loadChart() async {
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/api/student_chart/${widget.regNo}"),
      );

      final List data = jsonDecode(response.body);

      setState(() {
        points = data.map((e) => AttendanceChartPoint.fromJson(e)).toList();
        loading = false;
      });
    } catch (e) {
      setState(() {
        points = [];
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final recentPoints = points.length > 7
        ? points.sublist(points.length - 7)
        : points;

    return card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.bar_chart, color: Color(0xff6d5dfc)),
              SizedBox(width: 8),
              Text(
                "Attendance Chart",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            "Recent attendance activity",
            style: TextStyle(
              color: Color(0xff64748b),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 18),
          if (loading)
            const Center(child: CircularProgressIndicator())
          else if (recentPoints.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  "No chart data yet.",
                  style: TextStyle(
                    color: Color(0xff64748b),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            )
          else
            Column(
              children: [
                SizedBox(
                  height: 150,
                  width: double.infinity,
                  child: CustomPaint(
                    painter: AttendanceBarChartPainter(recentPoints),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: recentPoints.map((p) {
                    final label = p.date.length >= 10
                        ? p.date.substring(5)
                        : p.date;
                    return Expanded(
                      child: Text(
                        label,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xff64748b),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class AttendanceBarChartPainter extends CustomPainter {
  final List<AttendanceChartPoint> points;

  AttendanceBarChartPainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    final axisPaint = Paint()
      ..color = const Color(0xffe2e8f0)
      ..strokeWidth = 2;

    final presentPaint = Paint()
      ..color = const Color(0xff6d5dfc);

    final absentPaint = Paint()
      ..color = const Color(0xffef4444);

    canvas.drawLine(
      Offset(0, size.height - 8),
      Offset(size.width, size.height - 8),
      axisPaint,
    );

    if (points.isEmpty) return;

    final slotWidth = size.width / points.length;
    final barWidth = slotWidth * 0.42;

    for (int i = 0; i < points.length; i++) {
      final point = points[i];
      final barHeight = point.isPresent ? size.height * 0.78 : size.height * 0.28;
      final left = (i * slotWidth) + (slotWidth - barWidth) / 2;
      final top = size.height - barHeight - 8;

      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(left, top, barWidth, barHeight),
        const Radius.circular(8),
      );

      canvas.drawRRect(rect, point.isPresent ? presentPaint : absentPaint);
    }
  }

  @override
  bool shouldRepaint(covariant AttendanceBarChartPainter oldDelegate) {
    return oldDelegate.points != points;
  }
}

class AttendanceRateCard extends StatelessWidget {
  final int rate;

  const AttendanceRateCard({
    super.key,
    required this.rate,
  });

  @override
  Widget build(BuildContext context) {
    return card(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "$rate%",
                  style: const TextStyle(
                    color: Color(0xff6d5dfc),
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const Text(
                  "Attendance Rate",
                  style: TextStyle(color: Color(0xff64748b)),
                ),
              ],
            ),
          ),
          const Icon(Icons.pie_chart, color: Color(0xff6d5dfc), size: 58),
        ],
      ),
    );
  }
}

class SmallStatCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;
  final IconData icon;

  const SmallStatCard({
    super.key,
    required this.title,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return card(
      child: Column(
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.w900),
          ),
          Text(title, style: const TextStyle(color: Color(0xff64748b), fontSize: 12)),
        ],
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String title;

  const SectionTitle({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
    );
  }
}

class ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback? onTap;

  const ActionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: card(
        margin: const EdgeInsets.only(top: 14),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(16)),
              child: Icon(icon, color: Colors.white),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: const TextStyle(color: Color(0xff64748b), fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Color(0xff94a3b8))
          ],
        ),
      ),
    );
  }
}

class AIFeatureCard extends StatelessWidget {
  const AIFeatureCard({super.key});

  @override
  Widget build(BuildContext context) {
    return card(
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "AI Features Enabled",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          SizedBox(height: 15),
          FeatureGrid(),
        ],
      ),
    );
  }
}

class FeatureGrid extends StatelessWidget {
  const FeatureGrid({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        Row(
          children: [
            Expanded(child: FeatureItem(icon: Icons.face, title: "Face Recognition")),
            SizedBox(width: 10),
            Expanded(child: FeatureItem(icon: Icons.remove_red_eye, title: "Liveness Check")),
          ],
        ),
        SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: FeatureItem(icon: Icons.location_on, title: "GPS Location")),
            SizedBox(width: 10),
            Expanded(child: FeatureItem(icon: Icons.notifications, title: "Smart Alerts")),
          ],
        ),
      ],
    );
  }
}

class FeatureItem extends StatelessWidget {
  final IconData icon;
  final String title;

  const FeatureItem({
    super.key,
    required this.icon,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xfff8fafc),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xff6d5dfc), size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: Color(0xff475569),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AnnouncementCard extends StatelessWidget {
  const AnnouncementCard({super.key});

  @override
  Widget build(BuildContext context) {
    return card(
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.orange,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.campaign, color: Colors.white),
          ),
          const SizedBox(width: 15),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Reminder", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                SizedBox(height: 4),
                Text(
                  "Please mark attendance before the class starts.",
                  style: TextStyle(color: Color(0xff64748b), fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Widget card({required Widget child, EdgeInsets? margin}) {
  return Container(
    margin: margin,
    padding: const EdgeInsets.all(18),
    decoration: boxStyle(),
    child: child,
  );
}

BoxDecoration boxStyle() {
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(24),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.08),
        blurRadius: 20,
        offset: const Offset(0, 10),
      ),
    ],
  );
}

InputDecoration inputDecoration(String hint, IconData icon) {
  return InputDecoration(
    prefixIcon: Icon(icon),
    hintText: hint,
    filled: true,
    fillColor: const Color(0xfff8fafc),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: BorderSide.none,
    ),
  );
}


class FullScreenCameraPreview extends StatelessWidget {
  final CameraController controller;
  final double borderRadius;

  const FullScreenCameraPreview({
    super.key,
    required this.controller,
    this.borderRadius = 24,
  });

  @override
  Widget build(BuildContext context) {
    final previewSize = controller.value.previewSize;

    if (previewSize == null) {
      return CameraPreview(controller);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: previewSize.height,
            height: previewSize.width,
            child: CameraPreview(controller),
          ),
        ),
      ),
    );
  }
}


/* OTHER PAGES */

class RecordsPage extends StatefulWidget {
  final String regNo;

  const RecordsPage({
    super.key,
    required this.regNo,
  });

  @override
  State<RecordsPage> createState() => _RecordsPageState();
}

class _RecordsPageState extends State<RecordsPage> {
  List<StudentRecord> records = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadRecords();
  }

  Future<void> loadRecords() async {
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/api/student_records/${widget.regNo}"),
      );

      final List data = jsonDecode(response.body);

      setState(() {
        records = data.map((e) => StudentRecord.fromJson(e)).toList();
        loading = false;
      });
    } catch (e) {
      setState(() {
        records = [];
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: loadRecords,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "My Records",
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "Your attendance history",
              style: TextStyle(color: Color(0xff64748b)),
            ),
            const SizedBox(height: 20),

            if (loading)
              const Center(child: CircularProgressIndicator())
            else if (records.isEmpty)
              card(
                child: const Center(
                  child: Text(
                    "No attendance records found.",
                    style: TextStyle(
                      color: Color(0xff64748b),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              )
            else
              Column(
                children: records.map((r) {
                  return card(
                    margin: const EdgeInsets.only(bottom: 14),
                    child: Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: const Color(0xffdcfce7),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(
                            Icons.check_circle,
                            color: Colors.green,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                r.status,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "${r.date}  •  ${r.time}",
                                style: const TextStyle(
                                  color: Color(0xff64748b),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          "${r.confidence}%",
                          style: const TextStyle(
                            color: Color(0xff6d5dfc),
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }
}

class AppNotification {
  final String title;
  final String message;
  final String type;

  AppNotification({
    required this.title,
    required this.message,
    required this.type,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      title: json["title"] ?? "",
      message: json["message"] ?? "",
      type: json["type"] ?? "info",
    );
  }
}

class NotificationsPage extends StatefulWidget {
  final String regNo;

  const NotificationsPage({
    super.key,
    required this.regNo,
  });

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  List<AppNotification> notifications = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadNotifications();
  }

  Future<void> loadNotifications() async {
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/api/student_notifications/${widget.regNo}"),
      );

      final List data = jsonDecode(response.body);

      setState(() {
        notifications = data.map((e) => AppNotification.fromJson(e)).toList();
        loading = false;
      });
    } catch (e) {
      setState(() {
        notifications = [
          AppNotification(
            title: "Connection Error",
            message: "Unable to load notifications from server.",
            type: "warning",
          ),
        ];
        loading = false;
      });
    }
  }

  Color getColor(String type) {
    if (type == "success") return Colors.green;
    if (type == "warning") return Colors.orange;
    return const Color(0xff6d5dfc);
  }

  IconData getIcon(String type) {
    if (type == "success") return Icons.check_circle;
    if (type == "warning") return Icons.warning;
    return Icons.notifications;
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: loadNotifications,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Notifications",
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "Smart attendance alerts and updates",
              style: TextStyle(color: Color(0xff64748b)),
            ),
            const SizedBox(height: 20),

            if (loading)
              const Center(child: CircularProgressIndicator())
            else
              Column(
                children: notifications.map((n) {
                  return card(
                    margin: const EdgeInsets.only(bottom: 14),
                    child: Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: getColor(n.type).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            getIcon(n.type),
                            color: getColor(n.type),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                n.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                n.message,
                                style: const TextStyle(
                                  color: Color(0xff64748b),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }
}

class ProfilePage extends StatefulWidget {
  final String name;
  final String regNo;

  const ProfilePage({
    super.key,
    required this.name,
    required this.regNo,
  });

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  StudentProfile? profile;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadProfile();
  }

  Future<void> loadProfile() async {
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/api/student_profile/${widget.regNo}"),
      );

      final data = jsonDecode(response.body);

      setState(() {
        profile = StudentProfile.fromJson(data);
        loading = false;
      });
    } catch (e) {
      setState(() {
        loading = false;
      });
    }
  }

  Widget profileTile(IconData icon, String title, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: boxStyle(),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xff6d5dfc)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xff64748b),
                    fontSize: 12,
                  ),
                ),
                Text(
                  value.isEmpty ? "Not added" : value,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final p = profile;

    if (p == null) {
      return const Center(child: Text("Unable to load profile"));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(22),
      child: Column(
        children: [
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xff6d5dfc), Color(0xff9b5cf6)],
              ),
              borderRadius: BorderRadius.circular(32),
              boxShadow: [
                BoxShadow(
                  color: Colors.deepPurple.withOpacity(0.28),
                  blurRadius: 28,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: Column(
              children: [
                const CircleAvatar(
                  radius: 55,
                  backgroundColor: Colors.white,
                  child: Icon(
                    Icons.school,
                    color: Color(0xff6d5dfc),
                    size: 50,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  p.name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  p.regNo,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 25),
          profileTile(Icons.badge, "Registration Number", p.regNo),
          profileTile(Icons.menu_book, "Course", p.course),
          profileTile(Icons.class_, "Class", p.className),
          profileTile(Icons.phone, "Phone", p.phone),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              },
              icon: const Icon(Icons.logout),
              label: const Text("Logout"),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xfffee2e2),
                foregroundColor: const Color(0xffdc2626),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}


/* ADMIN MAIN SCREEN */

class AdminMainScreen extends StatefulWidget {
  const AdminMainScreen({super.key});

  @override
  State<AdminMainScreen> createState() => _AdminMainScreenState();
}

class _AdminMainScreenState extends State<AdminMainScreen> {
  AdminDashboardData? dashboardData;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadAdminDashboard();
  }

  Future<void> loadAdminDashboard() async {
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/api/admin_dashboard"),
      );

      final data = jsonDecode(response.body);

      setState(() {
        dashboardData = AdminDashboardData.fromJson(data);
        loading = false;
      });
    } catch (e) {
      setState(() {
        dashboardData = AdminDashboardData(
          totalStudents: 0,
          presentToday: 0,
          absentToday: 0,
          totalRecords: 0,
          recent: [],
        );
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = dashboardData ??
        AdminDashboardData(
          totalStudents: 0,
          presentToday: 0,
          absentToday: 0,
          totalRecords: 0,
          recent: [],
        );

    return Scaffold(
      backgroundColor: const Color(0xffeef2ff),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 45, 20, 24),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xff111827), Color(0xff312e81)],
                ),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Color(0xff6366f1),
                    child: Icon(Icons.face, color: Colors.white, size: 34),
                  ),
                  SizedBox(height: 14),
                  Text(
                    "AI Attendance",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 20,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    "Admin Panel",
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
            adminDrawerItem(
              Icons.dashboard,
              "Dashboard",
              onTap: () => Navigator.pop(context),
            ),
            adminDrawerItem(
              Icons.people,
              "Students",
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AdminStudentsPage()),
                );
              },
            ),
            adminDrawerItem(
              Icons.assignment,
              "Attendance",
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AdminAttendancePage()),
                );
              },
            ),
            adminDrawerItem(
              Icons.notifications,
              "Alerts",
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AdminAlertsPage()),
                );
              },
            ),
            adminDrawerItem(
              Icons.download,
              "Reports",
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AdminReportsPage()),
                );
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text(
                "Logout",
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.w800,
                ),
              ),
              onTap: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              },
            ),
          ],
        ),
      ),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xff111827)),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Admin Dashboard",
              style: TextStyle(
                color: Color(0xff111827),
                fontWeight: FontWeight.w900,
                fontSize: 20,
              ),
            ),
            Text(
              "AI-Based Smart Attendance System",
              style: TextStyle(
                color: Color(0xff64748b),
                fontSize: 12,
              ),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 14),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xffeef2ff),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Row(
              children: [
                Icon(Icons.admin_panel_settings, color: Color(0xff4f46e5)),
                SizedBox(width: 6),
                Text(
                  "Admin",
                  style: TextStyle(
                    color: Color(0xff4f46e5),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          )
        ],
      ),
      body: RefreshIndicator(
        onRefresh: loadAdminDashboard,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (loading)
                const Padding(
                  padding: EdgeInsets.only(bottom: 18),
                  child: Center(child: CircularProgressIndicator()),
                ),
              Row(
                children: [
                  Expanded(
                    child: adminStatCard(
                      "Total Students",
                      "${data.totalStudents}",
                      Colors.blue,
                      Icons.people,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: adminStatCard(
                      "Present Today",
                      "${data.presentToday}",
                      Colors.green,
                      Icons.check_circle,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: adminStatCard(
                      "Absent Today",
                      "${data.absentToday}",
                      Colors.red,
                      Icons.person_off,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: adminStatCard(
                      "Total Records",
                      "${data.totalRecords}",
                      Colors.deepPurple,
                      Icons.storage,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              adminPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Attendance Overview",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      height: 180,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: const [
                          AdminChartBar(day: "Mon", heightFactor: .85),
                          AdminChartBar(day: "Tue", heightFactor: .65),
                          AdminChartBar(day: "Wed", heightFactor: .92),
                          AdminChartBar(day: "Thu", heightFactor: .75),
                          AdminChartBar(day: "Fri", heightFactor: .95),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              adminPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      "AI Features",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 14),
                    AdminFeatureItem(icon: Icons.face, title: "Face Recognition"),
                    AdminFeatureItem(icon: Icons.visibility, title: "Attention Detection"),
                    AdminFeatureItem(icon: Icons.security, title: "Anti-Spoofing"),
                    AdminFeatureItem(icon: Icons.location_on, title: "GPS Tracking"),
                    AdminFeatureItem(icon: Icons.notifications, title: "Smart Alerts"),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              adminPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Recent Attendance",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (data.recent.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(
                          child: Text(
                            "No recent attendance records.",
                            style: TextStyle(
                              color: Color(0xff64748b),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      )
                    else
                      Column(
                        children: data.recent.map((r) {
                          return adminRecentRow(
                            r.regNo,
                            r.name,
                            r.date,
                            r.time,
                            r.status,
                          );
                        }).toList(),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              adminPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Quick Actions",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        AdminQuickButton(
                          icon: Icons.person_add,
                          title: "Add Student",
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const AdminAddStudentPage()),
                            ).then((_) => loadAdminDashboard());
                          },
                        ),
                        AdminQuickButton(
                          icon: Icons.notifications,
                          title: "View Alerts",
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const AdminAlertsPage()),
                            );
                          },
                        ),
                        AdminQuickButton(
                          icon: Icons.download,
                          title: "Export CSV",
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const AdminReportsPage()),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Widget adminDrawerItem(IconData icon, String title, {VoidCallback? onTap}) {
  return ListTile(
    leading: Icon(icon, color: const Color(0xff4f46e5)),
    title: Text(
      title,
      style: const TextStyle(fontWeight: FontWeight.w800),
    ),
    onTap: onTap,
  );
}

Widget adminStatCard(String title, String value, Color color, IconData icon) {
  return Container(
    padding: const EdgeInsets.all(18),
    decoration: boxStyle(),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Icon(icon, color: Colors.white),
        ),
        const SizedBox(height: 14),
        Text(
          title,
          style: const TextStyle(
            color: Color(0xff64748b),
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w900,
            color: Color(0xff111827),
          ),
        ),
      ],
    ),
  );
}

Widget adminPanel({required Widget child}) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: boxStyle(),
    child: child,
  );
}

class AdminChartBar extends StatelessWidget {
  final String day;
  final double heightFactor;

  const AdminChartBar({
    super.key,
    required this.day,
    required this.heightFactor,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Expanded(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: FractionallySizedBox(
                heightFactor: heightFactor,
                child: Container(
                  width: 38,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xff22c55e), Color(0xff86efac)],
                    ),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(18),
                      topRight: Radius.circular(18),
                      bottomLeft: Radius.circular(6),
                      bottomRight: Radius.circular(6),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            day,
            style: const TextStyle(
              color: Color(0xff64748b),
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class AdminFeatureItem extends StatelessWidget {
  final IconData icon;
  final String title;

  const AdminFeatureItem({
    super.key,
    required this.icon,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xfff8fafc),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xff4f46e5)),
          const SizedBox(width: 12),
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

Widget adminRecentRow(String regNo, String name, String date, String time, String status) {
  return Container(
    padding: const EdgeInsets.symmetric(vertical: 12),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: Color(0xffe2e8f0))),
    ),
    child: Row(
      children: [
        Expanded(
          flex: 2,
          child: Text(regNo, style: const TextStyle(fontWeight: FontWeight.w800)),
        ),
        Expanded(
          flex: 2,
          child: Text(name),
        ),
        Expanded(
          flex: 2,
          child: Text(date, style: const TextStyle(color: Color(0xff64748b))),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xffdcfce7),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            status,
            style: const TextStyle(
              color: Color(0xff15803d),
              fontWeight: FontWeight.w900,
              fontSize: 12,
            ),
          ),
        ),
      ],
    ),
  );
}


class AdminAttendancePage extends StatefulWidget {
  const AdminAttendancePage({super.key});

  @override
  State<AdminAttendancePage> createState() => _AdminAttendancePageState();
}

class _AdminAttendancePageState extends State<AdminAttendancePage> {
  bool loading = true;
  List<AdminAttendanceRecord> records = [];
  String searchText = "";

  @override
  void initState() {
    super.initState();
    loadRecords();
  }

  Future<void> loadRecords() async {
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/api/admin_records"),
      );

      final List data = jsonDecode(response.body);

      setState(() {
        records = data.map((e) => AdminAttendanceRecord.fromJson(e)).toList();
        loading = false;
      });
    } catch (e) {
      setState(() {
        records = [];
        loading = false;
      });
    }
  }

  List<AdminAttendanceRecord> get filteredRecords {
    final q = searchText.trim().toLowerCase();
    if (q.isEmpty) return records;

    return records.where((r) {
      return r.regNo.toLowerCase().contains(q) ||
          r.name.toLowerCase().contains(q) ||
          r.date.toLowerCase().contains(q) ||
          r.status.toLowerCase().contains(q);
    }).toList();
  }

  Color statusColor(String status) {
    if (status.toLowerCase() == "present") return Colors.green;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    final shownRecords = filteredRecords;

    return Scaffold(
      backgroundColor: const Color(0xffeef2ff),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xff111827)),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Attendance Records",
              style: TextStyle(
                color: Color(0xff111827),
                fontWeight: FontWeight.w900,
                fontSize: 20,
              ),
            ),
            Text(
              "View all student attendance",
              style: TextStyle(
                color: Color(0xff64748b),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: loadRecords,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xff111827), Color(0xff312e81)],
                  ),
                  borderRadius: BorderRadius.circular(26),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.18),
                      blurRadius: 24,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 28,
                      backgroundColor: Color(0xff6366f1),
                      child: Icon(
                        Icons.assignment,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "${records.length}",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 30,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const Text(
                            "Total Attendance Records",
                            style: TextStyle(
                              color: Colors.white70,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: TextField(
                  onChanged: (value) {
                    setState(() {
                      searchText = value;
                    });
                  },
                  decoration: const InputDecoration(
                    icon: Icon(Icons.search, color: Color(0xff4f46e5)),
                    hintText: "Search by Reg No, Name, Date or Status",
                    border: InputBorder.none,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              adminPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            "All Records",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xffeef2ff),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                            "Showing ${shownRecords.length}",
                            style: const TextStyle(
                              color: Color(0xff4f46e5),
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (loading)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    else if (shownRecords.isEmpty)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: Text(
                            "No attendance records found.",
                            style: TextStyle(
                              color: Color(0xff64748b),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      )
                    else
                      Column(
                        children: shownRecords.map((r) {
                          return AdminAttendanceRecordCard(record: r);
                        }).toList(),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AdminAttendanceRecordCard extends StatelessWidget {
  final AdminAttendanceRecord record;

  const AdminAttendanceRecordCard({
    super.key,
    required this.record,
  });

  @override
  Widget build(BuildContext context) {
    final hasLocation = record.latitude.isNotEmpty && record.longitude.isNotEmpty;
    final statusIsPresent = record.status.toLowerCase() == "present";

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xfff8fafc),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xffe2e8f0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor:
                statusIsPresent ? const Color(0xffdcfce7) : const Color(0xfffee2e2),
                child: Icon(
                  statusIsPresent ? Icons.check_circle : Icons.cancel,
                  color: statusIsPresent ? Colors.green : Colors.red,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record.name.isEmpty ? "Unknown Student" : record.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      record.regNo,
                      style: const TextStyle(
                        color: Color(0xff64748b),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: statusIsPresent
                      ? const Color(0xffdcfce7)
                      : const Color(0xfffee2e2),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  record.status,
                  style: TextStyle(
                    color: statusIsPresent ? const Color(0xff15803d) : const Color(0xff991b1b),
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Icon(Icons.calendar_month, size: 18, color: Color(0xff4f46e5)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "${record.date}  •  ${record.time}",
                  style: const TextStyle(
                    color: Color(0xff475569),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.location_on, size: 18, color: Color(0xff4f46e5)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  hasLocation
                      ? "${record.latitude}, ${record.longitude}"
                      : "No GPS location saved",
                  style: const TextStyle(
                    color: Color(0xff64748b),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.analytics, size: 18, color: Color(0xff4f46e5)),
              const SizedBox(width: 8),
              Text(
                "Confidence: ${record.confidence}%",
                style: const TextStyle(
                  color: Color(0xff64748b),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class AdminStudentsPage extends StatefulWidget {
  const AdminStudentsPage({super.key});

  @override
  State<AdminStudentsPage> createState() => _AdminStudentsPageState();
}

class _AdminStudentsPageState extends State<AdminStudentsPage> {
  bool loading = true;
  List<AdminStudent> students = [];

  @override
  void initState() {
    super.initState();
    loadStudents();
  }

  Future<void> loadStudents() async {
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/api/admin_students"),
      );

      final List data = jsonDecode(response.body);

      setState(() {
        students = data.map((e) => AdminStudent.fromJson(e)).toList();
        loading = false;
      });
    } catch (e) {
      setState(() {
        students = [];
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffeef2ff),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xff111827)),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Students",
              style: TextStyle(
                color: Color(0xff111827),
                fontWeight: FontWeight.w900,
                fontSize: 20,
              ),
            ),
            Text(
              "Manage student details",
              style: TextStyle(
                color: Color(0xff64748b),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: loadStudents,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xff4f46e5), Color(0xff8b5cf6)],
                        ),
                        borderRadius: BorderRadius.circular(26),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.deepPurple.withOpacity(0.25),
                            blurRadius: 24,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          const CircleAvatar(
                            radius: 28,
                            backgroundColor: Colors.white,
                            child: Icon(
                              Icons.people,
                              color: Color(0xff4f46e5),
                              size: 30,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "${students.length}",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 30,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const Text(
                                "Total Students",
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              adminPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            "Student List",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const AdminAddStudentPage()),
                            ).then((_) => loadStudents());
                          },
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xffeef2ff),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.person_add, color: Color(0xff4f46e5), size: 17),
                                SizedBox(width: 6),
                                Text(
                                  "Add Student",
                                  style: TextStyle(
                                    color: Color(0xff4f46e5),
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (loading)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    else if (students.isEmpty)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: Text(
                            "No students found.",
                            style: TextStyle(
                              color: Color(0xff64748b),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      )
                    else
                      Column(
                        children: students.map((s) {
                          return AdminStudentCard(student: s);
                        }).toList(),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AdminStudentCard extends StatelessWidget {
  final AdminStudent student;

  const AdminStudentCard({
    super.key,
    required this.student,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xfff8fafc),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xffe2e8f0)),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xff4f46e5), Color(0xff8b5cf6)],
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(Icons.school, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  student.name.isEmpty ? "Unnamed Student" : student.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Reg No: ${student.regNo}",
                  style: const TextStyle(
                    color: Color(0xff64748b),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "${student.course.isEmpty ? 'No course' : student.course}  •  ${student.className.isEmpty ? 'No class' : student.className}",
                  style: const TextStyle(
                    color: Color(0xff64748b),
                    fontSize: 12,
                  ),
                ),
                if (student.phone.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    "Phone: ${student.phone}",
                    style: const TextStyle(
                      color: Color(0xff64748b),
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}





class AdminAddStudentPage extends StatefulWidget {
  const AdminAddStudentPage({super.key});

  @override
  State<AdminAddStudentPage> createState() => _AdminAddStudentPageState();
}

class _AdminAddStudentPageState extends State<AdminAddStudentPage> {
  final regNoController = TextEditingController();
  final nameController = TextEditingController();
  final courseController = TextEditingController();
  final classController = TextEditingController();
  final phoneController = TextEditingController();
  final passwordController = TextEditingController(text: "student123");

  CameraController? cameraController;
  bool cameraReady = false;
  bool addingStudent = false;
  bool capturing = false;
  bool training = false;

  int? studentId;
  int capturedImages = 0;
  String message = "Add student details first, then auto capture 50 face images.";

  Future<void> addStudent() async {
    final regNo = regNoController.text.trim();
    final name = nameController.text.trim();

    if (regNo.isEmpty || name.isEmpty) {
      showMsg("Registration number and name are required.", Colors.red);
      return;
    }

    setState(() {
      addingStudent = true;
      message = "Adding student...";
    });

    try {
      final response = await http.post(
        Uri.parse("$baseUrl/api/admin_add_student"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "reg_no": regNo,
          "name": name,
          "course": courseController.text.trim(),
          "class_name": classController.text.trim(),
          "phone": phoneController.text.trim(),
          "password": passwordController.text.trim().isEmpty
              ? "student123"
              : passwordController.text.trim(),
        }),
      );

      final data = jsonDecode(response.body);

      if (data["success"] == true) {
        setState(() {
          studentId = data["student_id"];
          message = data["message"] ?? "Student added. Start camera and auto capture 50 face images.";
        });

        showMsg("Student added successfully.", Colors.green);
      } else {
        setState(() {
          message = data["message"] ?? "Failed to add student.";
        });
        showMsg(message, Colors.red);
      }
    } catch (e) {
      setState(() {
        message = "Server error: $e";
      });
      showMsg(message, Colors.red);
    } finally {
      setState(() {
        addingStudent = false;
      });
    }
  }

  Future<void> startCamera() async {
    try {
      final cameras = await availableCameras();

      final frontCamera = cameras.firstWhere(
            (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      cameraController = CameraController(
        frontCamera,
        ResolutionPreset.low,
        enableAudio: false,
      );

      await cameraController!.initialize();

      setState(() {
        cameraReady = true;
        message = "Camera ready. Keep student's face inside the circle.";
      });
    } catch (e) {
      setState(() {
        message = "Camera error: $e";
      });
      showMsg(message, Colors.red);
    }
  }

  Future<void> captureFaceImages() async {
    if (studentId == null) {
      showMsg("Please add student details first.", Colors.red);
      return;
    }

    if (!cameraReady || cameraController == null) {
      showMsg("Start camera first.", Colors.red);
      return;
    }

    if (capturing) return;

    setState(() {
      capturing = true;
      capturedImages = 0;
      message = "Auto capturing 50 face images. Slowly turn face left, right, up and down.";
    });

    int successCount = 0;

    for (int i = 1; i <= 50; i++) {
      try {
        final image = await cameraController!.takePicture();

        final request = http.MultipartRequest(
          "POST",
          Uri.parse("$baseUrl/api/admin_upload_face"),
        );

        request.fields["student_id"] = studentId.toString();
        request.fields["image_no"] = i.toString();
        request.files.add(
          await http.MultipartFile.fromPath("image", image.path),
        );

        final response = await request.send();
        final responseBody = await response.stream.bytesToString();
        final data = jsonDecode(responseBody);

        if (data["success"] == true) {
          successCount++;
        }

        setState(() {
          capturedImages = successCount;
          message = "Auto capturing... $successCount / 50 face images. Move face slightly.";
        });

        await Future.delayed(const Duration(milliseconds: 650));
      } catch (e) {
        setState(() {
          message = "Capture error: $e";
        });
      }
    }

    setState(() {
      capturing = false;
      message = "Face capture completed. Captured $successCount / 50 images. Now train model.";
    });

    showMsg("Captured $successCount / 50 face images.", Colors.green);
  }

  Future<void> trainModel() async {
    setState(() {
      training = true;
      message = "Training model. Please wait...";
    });

    try {
      final response = await http.post(
        Uri.parse("$baseUrl/api/admin_train_model"),
      );

      final data = jsonDecode(response.body);

      setState(() {
        message = data["message"] ?? "Training completed.";
      });

      showMsg(
        data["message"] ?? "Training completed.",
        data["success"] == true ? Colors.green : Colors.red,
      );
    } catch (e) {
      setState(() {
        message = "Training error: $e";
      });
      showMsg(message, Colors.red);
    } finally {
      setState(() {
        training = false;
      });
    }
  }

  void clearForm() {
    regNoController.clear();
    nameController.clear();
    courseController.clear();
    classController.clear();
    phoneController.clear();
    passwordController.text = "student123";

    setState(() {
      studentId = null;
      capturedImages = 0;
      message = "Add student details first, then auto capture 50 face images.";
    });
  }

  void showMsg(String text, Color color) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: color,
      ),
    );
  }

  @override
  void dispose() {
    regNoController.dispose();
    nameController.dispose();
    courseController.dispose();
    classController.dispose();
    phoneController.dispose();
    passwordController.dispose();
    cameraController?.dispose();
    super.dispose();
  }

  Widget formField(
      String label,
      TextEditingController controller,
      IconData icon, {
        bool obscure = false,
      }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            obscureText: obscure,
            decoration: inputDecoration(label, icon),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canCapture = studentId != null;

    return Scaffold(
      backgroundColor: const Color(0xffeef2ff),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xff111827)),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Add Student",
              style: TextStyle(
                color: Color(0xff111827),
                fontWeight: FontWeight.w900,
                fontSize: 20,
              ),
            ),
            Text(
              "Details, face capture and model training",
              style: TextStyle(
                color: Color(0xff64748b),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            adminPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Student Details",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 16),
                  formField("Registration Number", regNoController, Icons.badge),
                  formField("Student Name", nameController, Icons.person),
                  formField("Course", courseController, Icons.menu_book),
                  formField("Class / Section", classController, Icons.class_),
                  formField("Phone", phoneController, Icons.phone),
                  formField("Login Password", passwordController, Icons.lock, obscure: true),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: addingStudent ? null : addStudent,
                      icon: const Icon(Icons.person_add),
                      label: Text(addingStudent ? "Adding..." : "Save Student"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xff4f46e5),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: clearForm,
                      icon: const Icon(Icons.refresh),
                      label: const Text("Clear Form"),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xff4f46e5),
                        side: const BorderSide(color: Color(0xff4f46e5)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            adminPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Face Images",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Auto captures 50 images. Ask the student to slowly look straight, left, right, up and down.",
                    style: TextStyle(
                      color: Color(0xff64748b),
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Captured Images: $capturedImages / 50",
                    style: const TextStyle(
                      color: Color(0xff64748b),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    height: 330,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(28),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: cameraReady && cameraController != null
                        ? Stack(
                      children: [
                        FullScreenCameraPreview(controller: cameraController!, borderRadius: 32),
                        Center(
                          child: Container(
                            width: 220,
                            height: 220,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.greenAccent,
                                width: 4,
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                        : const Center(
                      child: Icon(
                        Icons.camera_alt_rounded,
                        color: Colors.white,
                        size: 70,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: startCamera,
                          icon: const Icon(Icons.camera_alt),
                          label: const Text("Start Camera"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xff6d5dfc),
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: canCapture && !capturing ? captureFaceImages : null,
                          icon: const Icon(Icons.face),
                          label: Text(capturing ? "Capturing..." : "Auto Capture 50"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black87,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            adminPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Train Face Recognition Model",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message,
                    style: const TextStyle(
                      color: Color(0xff64748b),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: training ? null : trainModel,
                      icon: const Icon(Icons.model_training),
                      label: Text(training ? "Training..." : "Train Model"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AdminAlertsPage extends StatefulWidget {
  const AdminAlertsPage({super.key});

  @override
  State<AdminAlertsPage> createState() => _AdminAlertsPageState();
}

class _AdminAlertsPageState extends State<AdminAlertsPage> {
  bool loading = true;
  AdminAlertsData alerts = AdminAlertsData(absentToday: []);

  @override
  void initState() {
    super.initState();
    loadAlerts();
  }

  Future<void> loadAlerts() async {
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/api/admin_alerts"),
      );

      final data = jsonDecode(response.body);

      setState(() {
        alerts = AdminAlertsData.fromJson(data);
        loading = false;
      });
    } catch (e) {
      setState(() {
        alerts = AdminAlertsData(absentToday: []);
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final absentCount = alerts.absentToday.length;

    return Scaffold(
      backgroundColor: const Color(0xffeef2ff),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xff111827)),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Admin Alerts",
              style: TextStyle(
                color: Color(0xff111827),
                fontWeight: FontWeight.w900,
                fontSize: 20,
              ),
            ),
            Text(
              "Absent students and smart alerts",
              style: TextStyle(
                color: Color(0xff64748b),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: loadAlerts,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (loading)
                const Padding(
                  padding: EdgeInsets.only(bottom: 18),
                  child: Center(child: CircularProgressIndicator()),
                ),
              Row(
                children: [
                  Expanded(
                    child: adminAlertSummaryCard(
                      "Absent Today",
                      "$absentCount",
                      Colors.red,
                      Icons.person_off,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: adminAlertSummaryCard(
                      "System Alerts",
                      "$absentCount",
                      Colors.orange,
                      Icons.warning,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              adminPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.person_off, color: Colors.red),
                        SizedBox(width: 8),
                        Text(
                          "Absent Today",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "Students who have not marked attendance today.",
                      style: TextStyle(
                        color: Color(0xff64748b),
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (alerts.absentToday.isEmpty && !loading)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: Column(
                            children: [
                              Icon(
                                Icons.check_circle,
                                color: Colors.green,
                                size: 44,
                              ),
                              SizedBox(height: 10),
                              Text(
                                "No absent students today.",
                                style: TextStyle(
                                  color: Color(0xff64748b),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      Column(
                        children: alerts.absentToday.map((s) {
                          return AdminAbsentStudentCard(student: s);
                        }).toList(),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              adminPanel(
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info, color: Color(0xff4f46e5)),
                        SizedBox(width: 8),
                        Text(
                          "Alert Information",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    Text(
                      "This page currently shows absent students using your Flask /api/admin_alerts endpoint. You can later add low attendance warnings, GPS violations, and attention alerts.",
                      style: TextStyle(
                        color: Color(0xff64748b),
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Widget adminAlertSummaryCard(
    String title,
    String value,
    Color color,
    IconData icon,
    ) {
  return Container(
    padding: const EdgeInsets.all(18),
    decoration: boxStyle(),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Icon(icon, color: Colors.white),
        ),
        const SizedBox(height: 14),
        Text(
          title,
          style: const TextStyle(
            color: Color(0xff64748b),
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w900,
            color: Color(0xff111827),
          ),
        ),
      ],
    ),
  );
}

class AdminAbsentStudentCard extends StatelessWidget {
  final AdminAbsentStudent student;

  const AdminAbsentStudentCard({
    super.key,
    required this.student,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xfffff7ed),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xffffedd5)),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: const Color(0xfffee2e2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.person_off,
              color: Colors.red,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  student.name.isEmpty ? "Unknown Student" : student.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  student.regNo,
                  style: const TextStyle(
                    color: Color(0xff64748b),
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xfffee2e2),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Text(
              "Absent",
              style: TextStyle(
                color: Color(0xffb91c1c),
                fontWeight: FontWeight.w900,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}


class AdminReportsPage extends StatefulWidget {
  const AdminReportsPage({super.key});

  @override
  State<AdminReportsPage> createState() => _AdminReportsPageState();
}

class _AdminReportsPageState extends State<AdminReportsPage> {
  bool loading = false;
  String downloadUrl = "";
  String message = "Tap the button to generate the CSV export link.";

  Future<void> generateReportLink() async {
    setState(() {
      loading = true;
      message = "Preparing report...";
    });

    try {
      final response = await http.get(
        Uri.parse("$baseUrl/api/export_csv"),
      );

      final data = jsonDecode(response.body);

      if (data["success"] == true) {
        final urlPart = data["download_url"] ?? "/download_csv";
        final fullUrl = urlPart.toString().startsWith("http")
            ? urlPart.toString()
            : "$baseUrl$urlPart";

        setState(() {
          downloadUrl = fullUrl;
          message = "Report link generated successfully.";
          loading = false;
        });
      } else {
        setState(() {
          message = data["message"] ?? "Unable to generate report.";
          loading = false;
        });
      }
    } catch (e) {
      setState(() {
        message = "Server error: $e";
        loading = false;
      });
    }
  }

  Future<void> copyDownloadLink() async {
    if (downloadUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Generate the report link first.")),
      );
      return;
    }

    await Clipboard.setData(ClipboardData(text: downloadUrl));

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Download link copied.")),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffeef2ff),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xff111827)),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Reports",
              style: TextStyle(
                color: Color(0xff111827),
                fontWeight: FontWeight.w900,
                fontSize: 20,
              ),
            ),
            Text(
              "Export attendance CSV report",
              style: TextStyle(
                color: Color(0xff64748b),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xff4f46e5), Color(0xff8b5cf6)],
                ),
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.deepPurple.withOpacity(0.25),
                    blurRadius: 24,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: const Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.white,
                    child: Icon(
                      Icons.download,
                      color: Color(0xff4f46e5),
                      size: 32,
                    ),
                  ),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Attendance Report",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          "Download all attendance records as CSV",
                          style: TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            adminPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "CSV Export",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "This report includes Reg No, Name, Date, Time, Status, Liveness, Attention, Confidence, Latitude and Longitude.",
                    style: TextStyle(
                      color: Color(0xff64748b),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton.icon(
                      onPressed: loading ? null : generateReportLink,
                      icon: loading
                          ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                          : const Icon(Icons.file_download),
                      label: Text(
                        loading ? "Preparing..." : "Generate CSV Download Link",
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xff4f46e5),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xfff8fafc),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Text(
                      message,
                      style: const TextStyle(
                        color: Color(0xff64748b),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (downloadUrl.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xffeef2ff),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: SelectableText(
                        downloadUrl,
                        style: const TextStyle(
                          color: Color(0xff4f46e5),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: OutlinedButton.icon(
                        onPressed: copyDownloadLink,
                        icon: const Icon(Icons.copy),
                        label: const Text("Copy Download Link"),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xff4f46e5),
                          side: const BorderSide(color: Color(0xff4f46e5)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      "Paste this link in your phone browser to download the CSV file.",
                      style: TextStyle(
                        color: Color(0xff64748b),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 22),
            adminPanel(
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Report Details",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 14),
                  AdminFeatureItem(
                    icon: Icons.badge,
                    title: "Student registration numbers",
                  ),
                  AdminFeatureItem(
                    icon: Icons.calendar_today,
                    title: "Attendance dates and times",
                  ),
                  AdminFeatureItem(
                    icon: Icons.location_on,
                    title: "GPS latitude and longitude",
                  ),
                  AdminFeatureItem(
                    icon: Icons.verified,
                    title: "Face confidence and liveness status",
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class AdminQuickButton extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback? onTap;

  const AdminQuickButton({
    super.key,
    required this.icon,
    required this.title,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xff4f46e5), Color(0xff8b5cf6)],
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
