// 通用取色对话框：返回选中的 Color（取消时为 null）

import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kostori/components/components.dart';
import 'package:kostori/i18n/strings.g.dart';
import 'package:kostori/utils/utils.dart';

class ColorPickPage extends StatefulWidget {
  final Color initialColor;

  const ColorPickPage({super.key, required this.initialColor});

  @override
  State<ColorPickPage> createState() => _ColorPickPageState();
}

class _ColorPickPageState extends State<ColorPickPage> {
  late Color pickerColor;
  late TextEditingController controller;

  @override
  void initState() {
    super.initState();
    pickerColor = widget.initialColor;
    controller = TextEditingController(text: Utils.colorToHex(pickerColor));
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void _onTextChanged(String value) {
    final color = Utils.hexToColor(value);
    if (color != null) {
      setState(() {
        pickerColor = color;
        controller.text = Utils.colorToHex(color);
        controller.selection = TextSelection.fromPosition(
          TextPosition(offset: controller.text.length),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ContentDialog(
      title: t.selectColor,
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ColorPicker(
              color: pickerColor,
              onColorChanged: (Color color) {
                pickerColor = color;
                controller.text = Utils.colorToHex(color);
              },
              pickersEnabled: <ColorPickerType, bool>{
                ColorPickerType.wheel: true,
                ColorPickerType.primary: true,
                ColorPickerType.accent: true,
              },
              pickerTypeLabels: <ColorPickerType, String>{
                ColorPickerType.wheel: t.colorWheel,
                ColorPickerType.primary: t.primary,
                ColorPickerType.accent: t.accent,
                ColorPickerType.custom: t.custom,
              },
              copyPasteBehavior: const ColorPickerCopyPasteBehavior(
                copyButton: true,
                pasteButton: true,
                longPressMenu: true,
                secondaryMenu: true,
                secondaryOnDesktopLongOnDevice: true,
              ),
              enableShadesSelection: true,
              enableTonalPalette: true,
              enableOpacity: true,
              showColorCode: true,
              showColorName: true,
              showMaterialName: true,
              showRecentColors: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: t.enterHexColorCode,
                border: const OutlineInputBorder(),
              ),
              maxLength: 9,
              onSubmitted: _onTextChanged,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'#[0-9a-fA-F]*')),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(pickerColor),
          child: Text(t.apply),
        ),
      ],
    );
  }
}
