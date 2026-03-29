import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'tailwind_card.dart';

class SuccessPieChart extends StatelessWidget {
  final Map<dynamic, dynamic>? logsData;
  final int? userCreatedAt;

  const SuccessPieChart({super.key, required this.logsData, this.userCreatedAt});

  @override
  Widget build(BuildContext context) {
    int success = 0;
    int failed = 0;

    if (logsData != null) {
      logsData!.forEach((key, value) {
        final timestamp = value['timestamp'] as int?;
        if (timestamp != null) {
          bool isAfterCreation = true;
          if (userCreatedAt != null && timestamp <= userCreatedAt!) {
              isAfterCreation = false;
          }
          if (isAfterCreation) {
             if (value['status'] == 'SUCCESS') {
               success++;
             } else {
               failed++;
             }
          }
        }
      });
    }

    final total = success + failed;
    if (total == 0) {
      return TailwindCard(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
             Text("Feeding Success Rate", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey[800])),
             const SizedBox(height: 20),
             const SizedBox(
               height: 150,
               child: Center(child: Text("No data available yet.", style: TextStyle(color: Colors.grey))),
             )
          ],
        )
      );
    }

    final successPercent = (success / total * 100).toStringAsFixed(1);
    final failPercent = (failed / total * 100).toStringAsFixed(1);

    return TailwindCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Feeding Success Rate", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey[800])),
              Icon(Icons.pie_chart, color: Colors.orange.shade300),
            ],
          ),
          const SizedBox(height: 25),
          SizedBox(
            height: 180,
            child: Row(
              children: [
                Expanded(
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 30,
                      sections: [
                        PieChartSectionData(
                          color: Colors.green.shade400,
                          value: success.toDouble(),
                          title: '$successPercent%',
                          radius: 50,
                          titleStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        if (failed > 0)
                          PieChartSectionData(
                            color: Colors.red.shade400,
                            value: failed.toDouble(),
                            title: '$failPercent%',
                            radius: 40,
                            titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 15),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLegendScale("Successful", Colors.green.shade400, success),
                    const SizedBox(height: 10),
                    _buildLegendScale("Failed", Colors.red.shade400, failed),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendScale(String title, Color color, int count) {
    return Row(
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text("$title ($count)", style: const TextStyle(fontSize: 14, color: Colors.black87, fontWeight: FontWeight.w500)),
      ],
    );
  }
}
