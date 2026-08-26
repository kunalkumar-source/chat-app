import 'package:flutter/material.dart';

/// Reusable animated typing indicator widget with bouncing dots (WhatsApp / iMessage style).
class TypingDotsIndicator extends StatefulWidget {
  final Color dotColor;
  final double dotSize;

  const TypingDotsIndicator({
    super.key,
    this.dotColor = const Color(0xFF666666),
    this.dotSize = 6.0,
  });

  @override
  State<TypingDotsIndicator> createState() => _TypingDotsIndicatorState();
}

class _TypingDotsIndicatorState extends State<TypingDotsIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _buildDot(int index) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        // Offset phases for each of the 3 dots
        final double delay = index * 0.2;
        final double value = (_controller.value - delay) % 1.0;
        final double bounce = (value < 0.5)
            ? (1.0 - (value * 2 - 0.5).abs() * 2).clamp(0.0, 1.0)
            : 0.0;

        return Transform.translate(
          offset: Offset(0, -bounce * 4.0),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 2.0),
            width: widget.dotSize,
            height: widget.dotSize,
            decoration: BoxDecoration(
              color: widget.dotColor.withValues(alpha: 0.4 + (bounce * 0.6)),
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildDot(0),
        _buildDot(1),
        _buildDot(2),
      ],
    );
  }
}
