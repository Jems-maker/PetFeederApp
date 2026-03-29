import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firebase_service.dart';
import 'package:intl/intl.dart';
import '../widgets/tailwind_card.dart';
import '../widgets/feeding_chart.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  int? _userCreatedAt;

  @override
  void initState() {
    super.initState();
    _fetchUserCreationTime();
  }

  void _fetchUserCreationTime() async {
    // If we have it locally from login/register, great. If not, fetch.
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final snapshot = await FirebaseDatabase.instance.ref('users/${user.uid}/createdAt').get();
      if (snapshot.exists) {
        if (mounted) {
           setState(() {
             _userCreatedAt = DateTime.parse(snapshot.value.toString()).millisecondsSinceEpoch;
           });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("History & Analytics", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.orange, 
        foregroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false, // If it's a root tab
      ),
      body: _userCreatedAt == null 
        ? const Center(child: CircularProgressIndicator(color: Colors.orange))
        : StreamBuilder(
            stream: _firebaseService.logsQuery.onValue,
            builder: (context, AsyncSnapshot<DatabaseEvent> snapshot) {
              if (snapshot.hasError) {
                return const Center(child: Text('Something went wrong'));
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: Colors.orange));
              }
              
              final rawData = snapshot.data?.snapshot.value;
              Map<dynamic, dynamic>? dataMap;
              
              if (rawData != null && rawData is Map) {
                dataMap = rawData;
              }

              // Parse and Filter Data
              final List<Map<String, dynamic>> filteredList = [];
              int successCount = 0;
              int failedCount = 0;

              if (dataMap != null) {
                dataMap.forEach((key, value) {
                  final timestamp = value['timestamp'] as int?;
                  if (timestamp != null && timestamp >= _userCreatedAt!) {
                     final status = value['status'];
                     filteredList.add({
                       'timestamp': timestamp,
                       'status': status,
                     });
                     
                     if (status == 'SUCCESS') {
                       successCount++;
                     } else {
                       failedCount++;
                     }
                  }
                });
              }

              // Sort descending
              filteredList.sort((a, b) => b['timestamp'].compareTo(a['timestamp']));

              // Calculate Consistency
              final total = successCount + failedCount;
              final consistency = total == 0 ? 0.0 : (successCount / total) * 100;

              return SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Analytics Header - Consistency
                      TailwindCard(
                        padding: const EdgeInsets.all(25),
                        color: Colors.orange.shade400,
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(color: Colors.white24, shape: BoxShape.circle),
                              child: const Icon(Icons.analytics, color: Colors.white, size: 32),
                            ),
                            const SizedBox(width: 20),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text("Consistency Score", style: TextStyle(color: Colors.white70, fontSize: 16)),
                                Text(
                                  "${consistency.toStringAsFixed(1)}%",
                                  style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Weekly Chart
                      FeedingChart(logsData: dataMap),

                      const SizedBox(height: 25),
                      Text(
                        "Daily Feeding Logs",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey[800]),
                      ),
                      const SizedBox(height: 15),

                      if (filteredList.isEmpty)
                        TailwindCard(
                          child: const Center(
                            child: Padding(
                              padding: EdgeInsets.all(20.0),
                              child: Text("No feeding history available.", style: TextStyle(color: Colors.grey)),
                            ),
                          ),
                        )
                      else
                        ListView.builder(
                          physics: const NeverScrollableScrollPhysics(),
                          shrinkWrap: true,
                          itemCount: filteredList.length,
                          itemBuilder: (context, index) {
                            final item = filteredList[index];
                            final timestamp = item['timestamp'];
                            final status = item['status'];
                            final formattedDate = DateFormat('MMM d, yyyy • h:mm a').format(
                              DateTime.fromMillisecondsSinceEpoch(timestamp),
                            );

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12.0),
                              child: TailwindCard(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: status == 'SUCCESS' ? Colors.green.shade50 : Colors.red.shade50,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        status == 'SUCCESS' ? Icons.check : Icons.close,
                                        color: status == 'SUCCESS' ? Colors.green : Colors.red,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 15),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            status == 'SUCCESS' ? "Successful Feed" : "Failed Feed",
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                              color: status == 'SUCCESS' ? Colors.green[800] : Colors.red[800],
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(formattedDate, style: const TextStyle(color: Colors.grey)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),

                      const SizedBox(height: 100), // Bottom nav clearance
                    ],
                  ),
                ),
              );
            },
          ),
    );
  }
}
