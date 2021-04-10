import 'package:flutter/material.dart';

class TrackedBox {
  final Rect shape;
  final int id;

  TrackedBox({@required this.shape, @required this.id});
}

class SelectableBox extends StatelessWidget {
  final Offset size;
  final bool isStart;
  final bool isEnd;
  final VoidCallback onTap;
  final Function(Offset) onMove;

  const SelectableBox(
      {Key key,
      @required this.size,
      this.isStart = false,
      this.isEnd = false,
      this.onTap,
      @required this.onMove})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onPanUpdate: (details) {
        onMove(details.delta);
      },
      child: Container(
        width: size.dx,
        height: size.dy,
        decoration: BoxDecoration(
            color: Colors.grey,
            border: isStart || isEnd
                ? Border.all(
                    color: isStart ? Colors.green : Colors.red, width: 4)
                : null),
      ),
    );
  }
}
