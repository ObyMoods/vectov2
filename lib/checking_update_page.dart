import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';

class CheckingUpdatePage extends StatefulWidget {
  final Widget nextPage;

  const CheckingUpdatePage({super.key, required this.nextPage});

  @override
  State<CheckingUpdatePage> createState() => _CheckingUpdatePageState();
}

class _CheckingUpdatePageState extends State<CheckingUpdatePage>
    with SingleTickerProviderStateMixin {
  double progress = 0;
  String status = "Initializing...";

  final List<String> steps = [
    "Checking version...",
    "Validating system...",
    "Syncing data...",
    "Preparing update...",
  ];

  @override
  void initState() {
    super.initState();
    startFakeCheck();
  }

  void startFakeCheck() {
    int stepIndex = 0;

    Timer.periodic(const Duration(milliseconds: 700), (timer) {
      setState(() {
        progress += 0.25;
        status = steps[stepIndex];
      });

      stepIndex++;

      if (progress >= 1.0) {
        timer.cancel();

        Future.delayed(const Duration(milliseconds: 400), () {
          if (!mounted) return;

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => widget.nextPage),
          );
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF020617),
      body: Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
            child: Container(
              width: MediaQuery.of(context).size.width * 0.8,
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ICON + ANIMATION
                  TweenAnimationBuilder(
                    tween: Tween<double>(begin: 0.8, end: 1.1),
                    duration: const Duration(milliseconds: 800),
                    curve: Curves.easeInOut,
                    builder: (_, value, child) {
                      return Transform.scale(
                        scale: value,
                        child: const Icon(
                          Icons.system_update_alt,
                          size: 60,
                          color: Colors.cyanAccent,
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 20),

                  const Text(
                    "Checking Update",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    status,
                    style: TextStyle(
                      color: Colors.grey.shade400,
                      fontSize: 13,
                    ),
                  ),

                  const SizedBox(height: 20),

                  // PROGRESS BAR
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 8,
                      backgroundColor: Colors.white10,
                      valueColor: const AlwaysStoppedAnimation(
                        Colors.cyanAccent,
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  Text(
                    "${(progress * 100).toInt()}%",
                    style: TextStyle(color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}