import 'package:flutter/material.dart';

class NavNode {
  bool hasObstacle = false;
  bool visited = false;
  double global = double.infinity;
  double local = double.infinity;
  final int x;
  final int y;
  final List<NavNode> neighbours = <NavNode>[];
  NavNode parent;

  NavNode(this.x, this.y);
}
