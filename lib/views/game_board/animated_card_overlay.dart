import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../models/uno_card.dart';
import '../widgets/uno_card_widget.dart';

class FlyingCardAnimation extends StatefulWidget {
  final UnoCard card;
  final Offset startOffset;
  final Offset endOffset;
  final VoidCallback onCompleted;

  const FlyingCardAnimation({
    super.key,
    required this.card,
    required this.startOffset,
    required this.endOffset,
    required this.onCompleted,
  });

  @override
  State<FlyingCardAnimation> createState() => _FlyingCardAnimationState();
}

class _FlyingCardAnimationState extends State<FlyingCardAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _curvedAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _curvedAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutQuad,
    );

    _controller.forward().then((_) {
      widget.onCompleted();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _curvedAnimation,
      builder: (context, child) {
        final currentOffset = Offset.lerp(
          widget.startOffset,
          widget.endOffset,
          _curvedAnimation.value,
        )!;

        // Slight arc upward in flight
        final arcHeight = math.sin(_curvedAnimation.value * math.pi) * -40.0;
        final rotation = (_curvedAnimation.value * 0.4) - 0.2;

        return Positioned(
          left: currentOffset.dx,
          top: currentOffset.dy + arcHeight,
          child: Transform.rotate(
            angle: rotation,
            child: UnoCardWidget(
              card: widget.card,
              width: 90,
              height: 135,
            ),
          ),
        );
      },
    );
  }
}
