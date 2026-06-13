import 'package:flutter/material.dart';

const djinnBackgroundColor = Color(0xFFF6F7F9);
const djinnPrimaryColor = Color(0xFF155EEF);

class DjinnBrandMark extends StatelessWidget {
  const DjinnBrandMark({super.key, this.size = 32});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/branding/djinn_logo.png',
      key: const ValueKey('djinn-brand-mark'),
      width: size,
      height: size,
      filterQuality: FilterQuality.high,
      errorBuilder: (context, error, stackTrace) => SizedBox.square(
        dimension: size,
        child: CustomPaint(painter: _DjinnBrandPainter()),
      ),
    );
  }
}

class DjinnLoadingScreen extends StatelessWidget {
  const DjinnLoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      key: ValueKey('djinn-loading-screen'),
      backgroundColor: djinnBackgroundColor,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DjinnBrandMark(size: 72),
            SizedBox(height: 20),
            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 2.6),
            ),
          ],
        ),
      ),
    );
  }
}

class DjinnAppBarTitle extends StatelessWidget {
  const DjinnAppBarTitle({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      key: const ValueKey('djinn-header-logo'),
      mainAxisSize: MainAxisSize.min,
      children: [
        const DjinnBrandMark(size: 28),
        const SizedBox(width: 10),
        Text(title),
      ],
    );
  }
}

class _DjinnBrandPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final radius = Radius.circular(size.width * 0.24);
    final background = Paint()..color = const Color(0xFF0F172A);
    canvas.drawRRect(RRect.fromRectAndRadius(rect, radius), background);

    final halo = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF38BDF8), Color(0xFF7C3AED)],
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.075
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromLTWH(
        size.width * 0.18,
        size.height * 0.18,
        size.width * 0.64,
        size.height * 0.64,
      ),
      -1.35,
      4.65,
      false,
      halo,
    );

    final stem = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.09
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(size.width * 0.38, size.height * 0.28),
      Offset(size.width * 0.38, size.height * 0.72),
      stem,
    );
    canvas.drawLine(
      Offset(size.width * 0.38, size.height * 0.28),
      Offset(size.width * 0.58, size.height * 0.28),
      stem,
    );
    canvas.drawLine(
      Offset(size.width * 0.38, size.height * 0.72),
      Offset(size.width * 0.58, size.height * 0.72),
      stem,
    );

    final sparkle = Paint()..color = const Color(0xFFFDE68A);
    canvas.drawCircle(
      Offset(size.width * 0.69, size.height * 0.25),
      size.width * 0.045,
      sparkle,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
