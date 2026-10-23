
import 'package:flutter/material.dart';

class MapLegendWidget extends StatelessWidget {
  const MapLegendWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 12,
        runSpacing: 8,
        children: [
          _buildLegendItem(
            Colors.red,
            '!',
            'High Risk Area',
          ),
          _buildLegendItem(
            Colors.green,
            '!',
            'Safest Area',
          ),
          _buildLegendItem(
            Colors.orange,
            '',
            'Medium Severity',
          ),
          _buildLegendItem(
            Colors.yellow,
            '',
            'Low Severity',
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(
    Color color,
    String symbol,
    String label,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 18,
          height: 18,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
          child: symbol.isNotEmpty
              ? Text(
                  symbol,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                )
              : null,
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
