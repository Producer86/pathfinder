import 'package:flutter/material.dart';

class OptionSwitch extends StatelessWidget {
  final bool value;
  final Function(bool) onChanged;
  final String label;

  const OptionSwitch(
      {Key key,
      @required this.value,
      @required this.onChanged,
      @required this.label})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Text(label),
        SizedBox(
          width: 10,
        ),
        Switch(value: value, onChanged: onChanged)
      ],
    );
  }
}
