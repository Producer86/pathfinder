import 'dart:async';

import 'package:flutter/material.dart';

import 'edit_area.dart';
import 'nav_area.dart';
import 'option_switch.dart';

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
