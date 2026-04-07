import 'package:flutter/material.dart';

class RatingWidget extends StatelessWidget {
  final double rating;
  final int count;
  final double size;
  final Color color;

  const RatingWidget({
    super.key,
    required this.rating,
    this.count = 0,
    this.size = 18,
    this.color = const Color(0xFFFF6B00),
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: List.generate(5, (index) {
            IconData icon;
            if (rating >= index + 1) {
              icon = Icons.star;
            } else if (rating >= index + 0.5) {
              icon = Icons.star_half;
            } else {
              icon = Icons.star_border;
            }
            return Icon(
              icon,
              size: size,
              color: color,
            );
          }),
        ),
        if (count > 0) ...[
          const SizedBox(width: 4),
          Text(
            '($count)',
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: size * 0.8,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ],
    );
  }
}
