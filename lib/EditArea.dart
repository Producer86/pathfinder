import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class EditArea extends StatefulWidget {
  @override
  _EditAreaState createState() => _EditAreaState();
}

class _EditAreaState extends State<EditArea> {
  double width = 100;
  double height = 100;

  TextEditingController wCtr;
  TextEditingController hCtr;

  @override
  void initState() {
    super.initState();
    wCtr = TextEditingController(text: width.toString());
    hCtr = TextEditingController(text: height.toString());
  }

  void setWidth(String w) {
    final n = double.tryParse(w);
    if (n != null) {
      setState(() {
        width = n;
      });
    }
  }

  void setHeight(String h) {
    final n = double.tryParse(h);
    if (n != null) {
      setState(() {
        height = n;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey[200],
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Draggable<Offset>(
            data: Offset(width, height),
            child: Container(
              width: width,
              height: height,
              color: Colors.grey,
              child: Center(),
            ),
            feedback: Container(
              width: width,
              height: height,
              color: Colors.grey,
              child: Center(),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              SizedBox(width: 10),
              Expanded(child: Text('width')),
              Expanded(
                child: TextField(
                  controller: wCtr,
                  keyboardType: TextInputType.number,
                  onChanged: setWidth,
                  inputFormatters: [NumFormatter()],
                ),
              ),
              SizedBox(
                width: 10,
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              SizedBox(width: 10),
              Expanded(child: Text('height')),
              Expanded(
                child: TextField(
                  controller: hCtr,
                  keyboardType: TextInputType.number,
                  onChanged: setHeight,
                  inputFormatters: [NumFormatter()],
                ),
              ),
              SizedBox(
                width: 10,
              ),
            ],
          )
        ],
      ),
    );
  }
}

class NumFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final newText = newValue.text.replaceAll(RegExp(r'[^0-9.]'), '');
    return TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: newText.length));
  }
}
