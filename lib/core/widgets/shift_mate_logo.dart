import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ShiftMateLogo extends StatelessWidget {
  final double size;
  final bool showText;
  final bool showSubtitle;

  const ShiftMateLogo({
    super.key,
    this.size = 200,
    this.showText = true,
    this.showSubtitle = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: size * 0.6,
          height: size * 0.6,
          child: CustomPaint(
            painter: _LogoPainter(),
            size: Size(size * 0.6, size * 0.6),
          ),
        ),
        if (showText) ...[
          const SizedBox(width: 12),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Shift',
                    style: GoogleFonts.inter(
                      fontSize: size * 0.22,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                    ),
                  ),
                  Text(
                    'Mate',
                    style: GoogleFonts.inter(
                      fontSize: size * 0.22,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF6c63ff),
                    ),
                  ),
                ],
              ),
              if (showSubtitle) ...[
                const SizedBox(height: 2),
                Text(
                  'Smart shift management',
                  style: GoogleFonts.inter(
                    fontSize: size * 0.09,
                    fontWeight: FontWeight.normal,
                    color: isDark ? Colors.white70 : const Color(0xFF64748B),
                  ),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }
}

class _LogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final scale = size.width / 200;

    // Draw dark circular background
    final circlePaint = Paint()
      ..color = const Color(0xFF1a1a2e)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, 72 * scale, circlePaint);

    // Draw purple arrow (up-right)
    final purplePaint = Paint()
      ..color = const Color(0xFF6c63ff)
      ..style = PaintingStyle.fill;

    final purpleArrow = _createPurpleArrowPath(center, scale);
    canvas.drawPath(purpleArrow, purplePaint);

    // Draw white arrow (down-left)
    final whitePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final whiteArrow = _createWhiteArrowPath(center, scale);
    canvas.drawPath(whiteArrow, whitePaint);
  }

  Path _createPurpleArrowPath(Offset center, double scale) {
    return Path()
      ..moveTo(center.dx - 28 * scale, center.dy - 10 * scale)
      ..lineTo(center.dx - 8 * scale, center.dy - 30 * scale)
      ..lineTo(center.dx + 12 * scale, center.dy - 10 * scale)
      ..lineTo(center.dx + 2 * scale, center.dy - 10 * scale)
      ..lineTo(center.dx + 2 * scale, center.dy + 10 * scale)
      ..lineTo(center.dx + 18 * scale, center.dy + 10 * scale)
      ..lineTo(center.dx + 18 * scale, center.dy + 20 * scale)
      ..lineTo(center.dx - 2 * scale, center.dy + 20 * scale)
      ..lineTo(center.dx - 2 * scale, center.dy + 0 * scale)
      ..lineTo(center.dx - 18 * scale, center.dy + 0 * scale)
      ..close();
  }

  Path _createWhiteArrowPath(Offset center, double scale) {
    return Path()
      ..moveTo(center.dx + 28 * scale, center.dy + 10 * scale)
      ..lineTo(center.dx + 8 * scale, center.dy + 30 * scale)
      ..lineTo(center.dx - 12 * scale, center.dy + 10 * scale)
      ..lineTo(center.dx - 2 * scale, center.dy + 10 * scale)
      ..lineTo(center.dx - 2 * scale, center.dy - 10 * scale)
      ..lineTo(center.dx - 18 * scale, center.dy - 10 * scale)
      ..lineTo(center.dx - 18 * scale, center.dy - 20 * scale)
      ..lineTo(center.dx + 2 * scale, center.dy - 20 * scale)
      ..lineTo(center.dx + 2 * scale, center.dy + 0 * scale)
      ..lineTo(center.dx + 18 * scale, center.dy + 0 * scale)
      ..close();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
