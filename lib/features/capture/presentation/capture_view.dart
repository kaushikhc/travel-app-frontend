import 'package:flutter/material.dart';

class CaptureView extends StatelessWidget {
  const CaptureView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Simulated Camera Preview
          Positioned.fill(
            child: Container(
              color: Colors.grey[900],
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.camera_alt_outlined, size: 64, color: Colors.white.withValues(alpha: 0.5)),
                    const SizedBox(height: 16),
                    Text(
                      'Camera Viewfinder',
                      style: theme.textTheme.titleMedium?.copyWith(color: Colors.white.withValues(alpha: 0.5)),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Camera Overlays (Gridlines)
          Positioned.fill(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(
                2,
                (_) => Container(
                  width: 1,
                  color: Colors.white.withValues(alpha: 0.15),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(
                2,
                (_) => Container(
                  height: 1,
                  color: Colors.white.withValues(alpha: 0.15),
                ),
              ),
            ),
          ),

          // Camera Top Controls
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.flash_off_rounded, color: Colors.white),
                  onPressed: () {},
                ),
                IconButton(
                  icon: const Icon(Icons.hdr_on_rounded, color: Colors.white),
                  onPressed: () {},
                ),
                IconButton(
                  icon: const Icon(Icons.settings_rounded, color: Colors.white),
                  onPressed: () {},
                ),
              ],
            ),
          ),

          // Camera Bottom Trigger Controls
          Positioned(
            bottom: 32,
            left: 0,
            right: 0,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.photo_library_outlined, color: Colors.white, size: 28),
                      onPressed: () {},
                    ),
                    // Capture Trigger Button
                    GestureDetector(
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Photo Captured!')),
                        );
                      },
                      child: Container(
                        height: 76,
                        width: 76,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 4),
                        ),
                        child: Container(
                          margin: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.flip_camera_ios_outlined, color: Colors.white, size: 28),
                      onPressed: () {},
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
