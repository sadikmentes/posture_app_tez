import 'package:flutter/material.dart';

class ModernBackground extends StatefulWidget {
  final Widget child;

  const ModernBackground({super.key, required this.child});

  @override
  State<ModernBackground> createState() => _ModernBackgroundState();
}

class _ModernBackgroundState extends State<ModernBackground> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _visible = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFFFF0E7), Color(0xFFE9F6FF), Color(0xFFE9FFF7)],
            ),
          ),
          child: SizedBox.expand(),
        ),
        const Positioned(
          top: -80,
          right: -40,
          child: _GlowBubble(size: 220, color: Color(0x66FF8A5B)),
        ),
        const Positioned(
          bottom: -70,
          left: -50,
          child: _GlowBubble(size: 240, color: Color(0x553D6DFF)),
        ),
        const Positioned(
          top: 160,
          left: 190,
          child: _GlowBubble(size: 130, color: Color(0x4415B88E)),
        ),
        AnimatedSlide(
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeOutCubic,
          offset: _visible ? Offset.zero : const Offset(0, 0.03),
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 380),
            opacity: _visible ? 1 : 0,
            child: widget.child,
          ),
        ),
      ],
    );
  }
}

class _GlowBubble extends StatelessWidget {
  final double size;
  final Color color;

  const _GlowBubble({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color, color.withAlpha(0)]),
        ),
      ),
    );
  }
}
