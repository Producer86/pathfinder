import 'package:flutter/material.dart';

import 'NavNode.dart';

class NavGrid {
  final List<NavNode> nodes;
  final int width;
  final int height;
  final bool useDiagonals;

  NavGrid(this.width, this.height, {this.useDiagonals = false})
      : nodes = List<NavNode>.filled(width * height, null) {
    // create nodes
    for (var x = 0; x < width; x++) {
      for (var y = 0; y < height; y++) {
        nodes[y * width + x] = NavNode(x, y);
      }
    }
    // connect nodes into a grid
    for (var x = 0; x < width; x++) {
      for (var y = 0; y < height; y++) {
        final index = y * width + x;
        final neighbours = nodes[index].neighbours;
        // N
        if (y > 0) {
          neighbours.add(nodes[(y - 1) * width + x]);
        }
        // S
        if (y < height - 1) {
          neighbours.add(nodes[(y + 1) * width + x]);
        }
        // W
        if (x > 0) {
          neighbours.add(nodes[y * width + (x - 1)]);
        }
        // E
        if (x < width - 1) {
          neighbours.add(nodes[y * width + (x + 1)]);
        }
        if (useDiagonals) {
          // NW
          if (x > 0 && y > 0) {
            neighbours.add(nodes[(y - 1) * width + (x - 1)]);
          }
          // SW
          if (x > 0 && y < height - 1) {
            neighbours.add(nodes[(y + 1) * width + (x - 1)]);
          }
          // NE
          if (x < width - 1 && y > 0) {
            neighbours.add(nodes[(y - 1) * width + (x + 1)]);
          }
          // SE
          if (x < width - 1 && y < height - 1) {
            neighbours.add(nodes[(y + 1) * width + (x + 1)]);
          }
        }
      }
    }
  }

  void reset() {
    for (var x = 0; x < width; x++) {
      for (var y = 0; y < height; y++) {
        final node = nodes[y * width + x];
        node.global = double.infinity;
        node.local = double.infinity;
        node.parent = null;
        node.visited = false;
      }
    }
  }

  void clearObstacles() {
    for (var i = 0; i < nodes.length; i++) {
      nodes[i].hasObstacle = false;
    }
  }

  double distance2(NavNode a, NavNode b) {
    // we only use distances in comparison so we can speed things up by using just the squared
    return Offset(
            a.x.toDouble() - b.x.toDouble(), a.y.toDouble() - b.y.toDouble())
        .distanceSquared;
  }

  void solveAstar(NavNode startNode, NavNode endNode) {
    reset();
    NavNode current = startNode;
    current.local = 0;
    current.global = distance2(current, endNode);

    var nodesToTest = <NavNode>[];
    nodesToTest.add(startNode);

    // can be faster but suboptimal
    // while (nodesToTest.isNotEmpty && current != endNode) {
    while (nodesToTest.isNotEmpty) {
      // sort by globals
      nodesToTest.sort((a, b) => a.global.compareTo(b.global));
      // flush visited nodes
      nodesToTest = nodesToTest.skipWhile((node) => node.visited).toList();
      if (nodesToTest.isEmpty) break;

      current = nodesToTest[0];
      current.visited = true;

      for (var neighbour in current.neighbours) {
        // if neighbour wasnt vistied and free we want to check it later
        if (!neighbour.visited && !neighbour.hasObstacle) {
          nodesToTest.add(neighbour);
        }
        // check if we need to update local and global
        final newLocal = current.local + distance2(current, neighbour);
        if (newLocal < neighbour.local) {
          neighbour.parent = current;
          neighbour.local = newLocal;
          neighbour.global = neighbour.local + distance2(neighbour, endNode);
        }
      }
    }
  }
}
