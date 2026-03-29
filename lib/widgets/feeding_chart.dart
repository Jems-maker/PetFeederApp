import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'tailwind_card.dart';

class FeedingChart extends StatelessWidget {
  final Map<dynamic, dynamic>? logsData;
  
  const FeedingChart({super.key, required this.logsData});

  List<BarChartGroupData> _buildChartData() {
    if (logsData == null || logsData!.isEmpty) {
      return List.generate(7, (index) => BarChartGroupData(x: index, barRods: [BarChartRodData(toY: 0, color: Colors.orange)]));
    }

    final now = DateTime.now();
    // Count feeds per day for the last 7 days
    List<int> feedsPerDay = List.filled(7, 0);

    logsData!.forEach((key, value) {
      if (value['status'] == 'SUCCESS' && value['timestamp'] != null) {
        final logTime = value['timestamp'] is int ? value['timestamp'] : 0;
        final dt = DateTime.fromMillisecondsSinceEpoch(logTime);
        final difference = now.difference(dt).inDays;
        
        if (difference >= 0 && difference < 7) {
           // index 6 is today, index 0 is 6 days ago
           int index = 6 - difference;
           feedsPerDay[index]++;
        }
      }
    });

    return List.generate(7, (index) {
      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: feedsPerDay[index].toDouble(),
            color: index == 6 ? Colors.orange : Colors.orange.shade200, // Highlight today
            width: 16,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    
    return TailwindCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Weekly Feeding Activity", 
            style: TextStyle(
              fontSize: 18, 
              fontWeight: FontWeight.bold, 
              color: Colors.blueGrey[800],
            ),
          ),
          const SizedBox(height: 25),
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: 6, // dynamic max y can be set, but let's assume max 6 feeds a day
                barTouchData: BarTouchData(enabled: false),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final dt = now.subtract(Duration(days: 6 - value.toInt()));
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            DateFormat('E').format(dt)[0], // e.g., 'M', 'T', 'W'
                            style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 2,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: Colors.grey.shade200,
                      strokeWidth: 1,
                    );
                  },
                ),
                borderData: FlBorderData(show: false),
                barGroups: _buildChartData(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
