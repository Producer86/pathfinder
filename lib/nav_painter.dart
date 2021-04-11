import 'package:flutter/material.dart';

import 'nav_grid.dart';
import 'arrow.dart';

class NavAreaPainter extends CustomPainter {
  static const nodeBorder = 2;
  final NavGrid grid;
  final double nodeWidth;
  final double nodeHeight;
  final bool showGrid;
  final List<Arrow> arrows;
  final nonVisitedPaint = Paint()
    ..color = Colors.blue.withAlpha(128)
    ..style = PaintingStyle.fill;
  final visitedPaint = Paint()
    ..color = Colors.blue
    ..style = PaintingStyle.fill;
  final filledPaint = Paint()
    ..color = Colors.amber
    ..style = PaintingStyle.fill;
  final connectionPaint = Paint()
    ..color = Colors.green.withAlpha(128)
    ..style = PaintingStyle.fill
    ..strokeWidth = 6;
  final pathPaint = Paint()
    ..color = Colors.black
    ..style = PaintingStyle.stroke
    ..strokeWidth = 6;

  NavAreaPainter(
      {@required this.arrows,
      @required this.nodeWidth,
      @required this.nodeHeight,
      @required this.grid,
      @required this.showGrid});

  @override
  void paint(Canvas canvas, Size size) {
    if (showGrid) {
      // draw neighbours
      for (var x = 0; x < grid.width; x++) {
        for (var y = 0; y < grid.height; y++) {
          final index = y * grid.width + x;
          final top = y * nodeHeight;
          final left = x * nodeWidth;
          final width = nodeWidth;
          final height = nodeHeight;
          for (var neighbour in grid.nodes[index].neighbours) {
            final c1 = Offset(left + width / 2, top + height / 2);
            final c2 = Offset(neighbour.x * width + width / 2,
                neighbour.y * height + height / 2);
            canvas.drawLine(c1, c2, connectionPaint);
          }
        }
      }
      // draw node
      for (var x = 0; x < grid.width; x++) {
        for (var y = 0; y < grid.height; y++) {
          final index = y * grid.width + x;
          final top = y * nodeHeight;
          final left = x * nodeWidth;
          final width = nodeWidth - nodeBorder;
          final height = nodeHeight - nodeBorder;
          canvas.drawRect(
              Rect.fromLTWH(left, top, width, height),
              grid.nodes[index].hasObstacle
                  ? filledPaint
                  : grid.nodes[index].visited
                      ? visitedPaint
                      : nonVisitedPaint);
        }
      }
    }
    // draw arrows
    for (var arrow in arrows) {
      canvas.drawCircle(arrow.start, 10, pathPaint);
      canvas.drawRect(
          Rect.fromCenter(center: arrow.end, width: 10, height: 10), pathPaint);
      canvas.drawPath(arrow.path, pathPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
