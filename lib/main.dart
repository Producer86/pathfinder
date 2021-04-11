import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:pathfinder/nav_node.dart';

import 'boxes.dart';
import 'edit_area.dart';
import 'nav_grid.dart';
import 'option_switch.dart';
import 'arrow.dart';
import 'nav_painter.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool showGrid = false;
  bool useDiagonals = false;
  double failFactor = 0.666;
  final failCtr = TextEditingController(text: '0.666');
  final connectRequests = StreamController<bool>();
  final deleteRequests = StreamController<bool>();

  void switchGrid(bool value) {
    setState(() {
      showGrid = value;
    });
  }

  void switchDiagonals(bool value) {
    setState(() {
      useDiagonals = value;
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
            // Options area at top
            Expanded(
              flex: 1,
              child: Material(
                elevation: 4,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    ElevatedButton(
                        onPressed: () => connectRequests.sink.add(true),
                        child: Text('Connect')),
                    ElevatedButton(
                        onPressed: () => deleteRequests.sink.add(true),
                        child: Text('Delete')),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        Text(
                          'FailFactor:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        SizedBox(
                          width: 15,
                        ),
                        SizedBox(
                          width: 50,
                          child: TextField(
                            onChanged: setFail,
                            controller: failCtr,
                            inputFormatters: [NumFormatter()],
                          ),
                        ),
                      ],
                    ),
                    OptionSwitch(
                        value: showGrid,
                        onChanged: switchGrid,
                        label: 'Show NavGrid'),
                    OptionSwitch(
                        value: useDiagonals,
                        onChanged: switchDiagonals,
                        label: 'Diagonals'),
                  ],
                ),
              ),
            ),
            // NavArea and box edit
            Expanded(
              flex: 10,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 10,
                    child: NavArea(
                      showGrid: showGrid,
                      useDiagonals: useDiagonals,
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

    // body of our arrow
    final path = Path();
    // arrow body starts from endPoint
    path.moveTo(endPoint.dx, endPoint.dy);

    // find nearest free node between the points
    final dirVec = endPoint - startPoint;
    final step = dirVec / dirVec.distance;
    // connect startPoint w nearest node in endPoint's direction
    final startNode = findNearestFreeNode(
        startPoint: startPoint,
        stepVec: step,
        maxDist2: dirVec.distanceSquared);
    bool useRoute = startNode != null;
    // if a route exists
    if (useRoute) {
      // connect endPoint w nearest node
      final endNode = findNearestFreeNode(
          startPoint: endPoint,
          stepVec: -step,
          maxDist2: dirVec.distanceSquared);

      // find route
      navGrid.reset();
      navGrid.solveAstar(startNode, endNode);

      // compare route length w the crow's flight, and decide if we
      // use it based on failFactor
      final straightDist =
          Offset(dirVec.dx / nodeW, dirVec.dy / nodeH).distance;
      if (endNode.global * widget.failFactor < straightDist) {
        path.lineTo(
            endNode.x * nodeW + nodeW / 2, endNode.y * nodeH + nodeH / 2);
        NavNode current = endNode;
        while (current.parent != null) {
          path.lineTo(current.parent.x * nodeW + nodeW / 2,
              current.parent.y * nodeH + nodeH / 2);
          current = current.parent;
        }
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

  NavNode findNearestFreeNode({
    @required Offset startPoint,
    @required Offset stepVec,
    @required double maxDist2,
  }) {
    var checkSpot = Offset(startPoint.dx, startPoint.dy) + stepVec;
    var result = navGrid.nodes[nodeIndex(checkSpot.dx, checkSpot.dy)];
    while (result.hasObstacle) {
      if (maxDist2 <= (checkSpot - startPoint).distanceSquared) {
        return null; // TODO
      }
      checkSpot += stepVec;
      result = navGrid.nodes[nodeIndex(checkSpot.dx, checkSpot.dy)];
    }
    return result;
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
