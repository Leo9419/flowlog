import 'package:flutter/material.dart';

const List<Color> kPresetColors = [
  Color(0xFF3F6AD8),
  Color(0xFF2ECC71),
  Color(0xFFF39C12),
  Color(0xFFE74C3C),
  Color(0xFF9B59B6),
  Color(0xFF95A5A6),
];

Future<Color?> showColorPickerSheet(BuildContext context, {Color? selected}) {
  return showModalBottomSheet<Color>(
    context: context,
    builder: (context) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: kPresetColors.map((color) {
              final isSelected = selected?.value == color.value;
              return InkWell(
                onTap: () => Navigator.of(context).pop(color),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color,
                    border: Border.all(
                      color: isSelected ? Colors.black87 : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      );
    },
  );
}
