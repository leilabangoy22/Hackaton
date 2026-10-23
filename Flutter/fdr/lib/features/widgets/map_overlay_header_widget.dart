import 'package:flutter/material.dart';
import 'map_legend_widget.dart';

class MapOverlayHeaderWidget extends StatelessWidget {
  const MapOverlayHeaderWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 8,
          bottom: 16,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white.withOpacity(0.3),
              Colors.white,
            ],
          ),
        ),
        child: Column(
          children: [
            const Text(
              'Flood Map Overview',
              style: TextStyle(
                color: Colors.black,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'View reported flood zones in your area',
              style: TextStyle(
                color: Colors.black,
                fontSize: 14,
              ),
            ),
            // const SizedBox(height: 16),
            // const MapLegendWidget(),
          ],
        ),
      ),
    );
  }
}