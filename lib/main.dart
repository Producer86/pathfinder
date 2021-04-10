import 'dart:async';
import 'dart:developer';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pathfinder/NavNode.dart';

import 'Boxes.dart';
import 'EditArea.dart';
import 'NavGrid.dart';
import 'OptionSwitch.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool showGrid = false;
  bool diagonal = false;
  double failFactor = 0.5;
  final connectRequests = StreamController<bool>();
  final deleteRequests = StreamController<bool>();
  final failCtr = TextEditingController(text: '0.5');

  void switchGrid(bool value) {
    setState(() {
      showGrid = value;
    });
  }

  void switchDiagonals(bool value) {
    setState(() {
      diagonal = value;
    });
  }

  void setFail(String value) {
    final n = double.tryParse(value);
    if (n != null) {
      setState(() {
        failFactor = n;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pathfinder Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: Scaffold(
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 1,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  ElevatedButton(
                      onPressed: () => connectRequests.sink.add(true),
                      child: Text('Connect')),
                  ElevatedButton(
                      onPressed: () => deleteRequests.sink.add(true),
                      child: Text('Delete')),
                  Text('FailFactor'),
                  SizedBox(
                    width: 50,
                    child: TextField(
                      onChanged: setFail,
                      controller: failCtr,
                      inputFormatters: [NumFormatter()],
                    ),
                  ),
                  OptionSwitch(
                      value: showGrid,
                      onChanged: switchGrid,
                      label: 'Show NavGrid'),
                  OptionSwitch(
                      value: diagonal,
                      onChanged: switchDiagonals,
                      label: 'Diagonals'),
                ],
              ),
            ),
            Expanded(
              flex: 10,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 10,
                    child: NavArea(
                      showGrid: showGrid,
                      useDiagonals: diagonal,
                      failFactor: failFactor,
                      deleteRequests: deleteRequests.stream,
                      connectRequests: connectRequests.stream,
                    ),
                  ),
                  Expanded(flex: 2, child: EditArea()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    connectRequests.close();
    deleteRequests.close();
    super.dispose();
  }
}

class NavArea extends StatefulWidget {
  final bool showGrid;
  final bool useDiagonals;
  final double failFactor;
  final Stream<bool> deleteRequests;
  final Stream<bool> connectRequests;

  NavArea({
    Key key,
    @required this.showGrid,
    @required this.useDiagonals,
    @required this.deleteRequests,
    @required this.connectRequests,
    @required this.failFactor,
  }) : super(key: key);

  @override
  _NavAreaState createState() => _NavAreaState();
}

class _NavAreaState extends State<NavArea> {
  NavGrid navGrid;
  int startId = -1;
  int endId = -1;
  bool startNext = true;
  double nodeW = 10;
  double nodeH = 10;
  int rows = 20;
  int cols = 20;
  final boxes = <int, TrackedBox>{};
  List<Arrow> arrows = <Arrow>[];
  int idCounter = 0;
  RenderBox containBox;
  StreamSubscription<bool> connectSub;
  StreamSubscription<bool> deleteSub;

  @override
  void initState() {
    super.initState();
    buildGrid();

    WidgetsBinding.instance.addPostFrameCallback(_afterLayout);

    connectSub = widget.connectRequests.listen((event) {
      connectBoxes();
    });

    deleteSub = widget.deleteRequests.listen((event) {
      deleteBox();
    });
  }

  @override
  void didUpdateWidget(covariant NavArea oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback(_afterLayout);
    if (oldWidget.useDiagonals != widget.useDiagonals) {
      boxes.clear();
      arrows.clear();
      buildGrid();
    }
  }

  @override
  Widget build(BuildContext context) {
    return DragTarget<Offset>(
      builder: (context, candidateData, rejectedData) => Stack(
        children: [
          CustomPaint(
            painter: NavAreaPainter(
                arrows: arrows,
                nodeWidth: nodeW,
                nodeHeight: nodeH,
                grid: navGrid,
                showGrid: widget.showGrid),
          ),
          GestureDetector(
            onTapUp: widget.showGrid ? setObstacle : null,
          ),
          ...boxes.values.map(
            (box) => Positioned(
              left: box.shape.left,
              top: box.shape.top,
              child: SelectableBox(
                size: Offset(box.shape.width, box.shape.height),
                onTap: () => selectBox(box.id),
                onMove: (delta) => moveBox(box.id, delta),
                isStart: startId == box.id,
                isEnd: endId == box.id,
              ),
            ),
          ),
        ],
      ),
      onAcceptWithDetails: acceptBox,
    );
  }

  @override
  void dispose() {
    deleteSub.cancel();
    connectSub.cancel();
    super.dispose();
  }

  void buildGrid() {
    navGrid = NavGrid(rows, cols, useDiagonals: widget.useDiagonals);
  }

  // switch obstacle for the clicked node
  void setObstacle(TapUpDetails details) {
    final selectedNodeX = details.localPosition.dx ~/ nodeW;
    final selectedNodeY = details.localPosition.dy ~/ nodeH;
    if (selectedNodeX >= 0 &&
        selectedNodeX < navGrid.width &&
        selectedNodeY >= 0 &&
        selectedNodeY < navGrid.height) {
      final index = selectedNodeY * navGrid.width + selectedNodeX;
      setState(() {
        navGrid.nodes[index].hasObstacle = !navGrid.nodes[index].hasObstacle;
        rebuildArrows();
      });
    }
  }

  // put a new box on the area
  void acceptBox(DragTargetDetails<Offset> details) {
    final localTL = containBox.globalToLocal(details.offset);
    setState(() {
      final newBoxShape = Rect.fromLTWH(
          localTL.dx, localTL.dy, details.data.dx, details.data.dy);
      boxes[idCounter] = TrackedBox(shape: newBoxShape, id: idCounter++);
      mapBoxToGrid(newBoxShape, value: true);
      rebuildArrows();
    });
  }

  void moveBox(int id, Offset delta) {
    final old = boxes[id];
    boxes[id] =
        TrackedBox(shape: old.shape.translate(delta.dx, delta.dy), id: id);
    scanBoxes();
    rebuildArrows();
  }

  void selectBox(int id) {
    setState(() {
      if (startId == id) {
        startNext = true;
        startId = -1;
      } else if (endId == id) {
        startNext = false;
        endId = -1;
      } else if (startNext) {
        startId = id;
        startNext = !startNext;
      } else {
        endId = id;
        startNext = !startNext;
      }
    });
  }

  void scanBoxes() {
    setState(() {
      navGrid.clearObstacles();
      for (var box in boxes.values) {
        mapBoxToGrid(box.shape, value: true);
      }
    });
  }

  void rebuildArrows() {
    final oldArrows = arrows.sublist(0);
    arrows.clear();
    for (var arrow in oldArrows) {
      startId = arrow.startId;
      endId = arrow.endId;
      connectBoxes();
    }
    setState(() {
      startId = -1;
      endId = -1;
    });
  }

  void connectBoxes() {
    if (startId < 0 || endId < 0) return;

    final startBox = boxes[startId].shape;
    final endBox = boxes[endId].shape;

    Offset startPoint;
    Offset endPoint;
    // choose closest sides
    final dir = (endBox.center - startBox.center).direction;
    if (dir > -pi / 4 && dir < pi / 4) {
      // E
      startPoint = startBox.centerRight;
      endPoint = endBox.centerLeft;
    } else if (dir > pi / 4 && dir < 3 * pi / 4) {
      // S
      startPoint = startBox.bottomCenter;
      endPoint = endBox.topCenter;
    } else if (dir < -pi / 4 && dir > -3 * pi / 4) {
      // N
      startPoint = startBox.topCenter;
      endPoint = endBox.bottomCenter;
    } else {
      // W
      startPoint = startBox.centerLeft;
      endPoint = endBox.centerRight;
    }

    bool useRoute = true;
    // find nearest free node between the points
    final dirVec = endPoint - startPoint;
    final step = dirVec / dirVec.distance;
    // connect startPoint w nearest node
    // but no line yet, we draw from end to start
    var checkSpot = Offset(startPoint.dx, startPoint.dy) + step;
    var startNode = navGrid.nodes[nodeIndex(checkSpot.dx, checkSpot.dy)];
    while (startNode.hasObstacle) {
      // if weve already reached the goal no point using the route
      if (dirVec.distanceSquared <= (checkSpot - startPoint).distanceSquared) {
        useRoute = false;
        break;
      }
      checkSpot += step;
      startNode = navGrid.nodes[nodeIndex(checkSpot.dx, checkSpot.dy)];
    }
    // connect endPoint w nearest node
    checkSpot = Offset(endPoint.dx, endPoint.dy) - step;
    var endNode = navGrid.nodes[nodeIndex(checkSpot.dx, checkSpot.dy)];
    while (endNode.hasObstacle) {
      if (dirVec.distanceSquared <= (checkSpot - endPoint).distanceSquared) {
        useRoute = false;
        break;
      }
      checkSpot -= step;
      endNode = navGrid.nodes[nodeIndex(checkSpot.dx, checkSpot.dy)];
    }

    if (useRoute) {
      // fill the body of the arrow
      navGrid.reset();
      navGrid.solveAstar(startNode, endNode);

      // compare route length w the crow's flight, and decide if we
      // use it based on failFactor
      final routeLength = endNode.global * max(nodeW, nodeH);
      print(routeLength);
      print(dirVec.distance);
      if (routeLength * widget.failFactor > dirVec.distance) {
        useRoute = false;
      }
    }

    // start path
    final path = Path();
    // start drawing the line
    path.moveTo(endPoint.dx, endPoint.dy);
    if (useRoute) {
      path.lineTo(endNode.x * nodeW + nodeW / 2, endNode.y * nodeH + nodeH / 2);
      NavNode current = endNode;
      while (current.parent != null) {
        path.lineTo(current.parent.x * nodeW + nodeW / 2,
            current.parent.y * nodeH + nodeH / 2);
        current = current.parent;
      }
    }
    // connect the starting point
    path.lineTo(startPoint.dx, startPoint.dy);

    setState(() {
      arrows.add(Arrow(
          startId: startId,
          endId: endId,
          start: startPoint,
          end: endPoint,
          path: path));
    });
  }

  // returns the nodes' index in point(x,y)
  int nodeIndex(double x, double y) {
    return (y ~/ nodeH) * navGrid.width + x ~/ nodeW;
  }

  // delete 1. end, 2. start selected box
  void deleteBox() {
    if (endId > -1) {
      boxes.remove(endId);
      startNext = false;

      arrows = arrows
          .where((arrow) => arrow.startId != endId && arrow.endId != endId)
          .toList();
      endId = -1;
      scanBoxes();
    } else if (startId > -1) {
      boxes.remove(startId);
      startNext = true;
      arrows = arrows
          .where((arrow) => arrow.startId != startId && arrow.endId != startId)
          .toList();
      startId = -1;
      scanBoxes();
      rebuildArrows();
    }
  }

  // set grid nodes under a box to value
  void mapBoxToGrid(Rect box, {bool value = true}) {
    final left = max(box.left ~/ nodeW, 0);
    final top = max(box.top ~/ nodeH, 0);
    final width =
        max(min(navGrid.width - 1, (box.left + box.width) ~/ nodeW) - left, 0);
    final height =
        max(min(navGrid.height - 1, (box.top + box.height) ~/ nodeH) - top, 0);
    for (var x = left; x <= left + width; x++) {
      for (var y = top; y <= top + height; y++) {
        navGrid.nodes[y * navGrid.width + x].hasObstacle = value;
      }
    }
  }

  // figure out our size so we can set node sizes properly
  void _afterLayout(Duration time) {
    containBox = (context.findRenderObject() as RenderBox);
    if (containBox.hasSize) {
      final size = containBox.size;
      setState(() {
        nodeW = size.width / navGrid.width;
        nodeH = size.height / navGrid.height;
      });
    }
  }
}

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

class Arrow {
  final int startId;
  final int endId;
  final Offset start;
  final Offset end;
  final Path path;

  Arrow({this.startId, this.endId, this.start, this.end, this.path});
}
