import 'dart:ui';

class Arrow {
  final int startId;
  final int endId;
  final Offset start;
  final Offset end;
  final Path path;

  Arrow({this.startId, this.endId, this.start, this.end, this.path});
}
