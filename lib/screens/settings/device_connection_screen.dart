import 'package:flutter/material.dart';
import '../../utils/translations.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:wifi_scan/wifi_scan.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
import 'dart:io';
import 'package:wifi_iot/wifi_iot.dart';

class DeviceConnectionScreen extends StatefulWidget {
  const DeviceConnectionScreen({super.key});

  @override
  State<DeviceConnectionScreen> createState() => _DeviceConnectionScreenState();
}

class _DeviceConnectionScreenState extends State<DeviceConnectionScreen> {
  bool _isBluetooth = true; // true = Bluetooth, false = Wifi
  bool _isScanning = false;
  
  // Bluetooth Data
  List<ScanResult> _bluetoothDevices = [];
  StreamSubscription? _bleSubscription;
  StreamSubscription? _bleScanSubscription;

  // Usage: We process ScanResult to show unique devices by ID
  
  // Wi-Fi Data
  List<WiFiAccessPoint> _wifiNetworks = [];
  StreamSubscription<List<WiFiAccessPoint>>? _wifiSubscription;

  @override
  void initState() {
    super.initState();
    _checkPermissionsAndScan();
  }

  @override
  void dispose() {
    _stopScan();
    _bleSubscription?.cancel();
    _bleScanSubscription?.cancel();
    _wifiSubscription?.cancel();
    super.dispose();
  }

  Future<void> _checkPermissionsAndScan() async {
    // Request permissions based on Android version
    Map<Permission, PermissionStatus> statuses = await [
      Permission.location,
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      // Permission.nearbyWifiDevices, // Removed to prevent AssertionError on some Android versions
    ].request();

    // Check if critical permissions are granted
    bool locationGranted = statuses[Permission.location]?.isGranted ?? false;
    bool bluetoothGranted = (statuses[Permission.bluetoothScan]?.isGranted ?? false) || 
                            (statuses[Permission.bluetooth]?.isGranted ?? false); 

    if (locationGranted && bluetoothGranted) {
      _startScan();
    } else {
       if (mounted) {
         bool permanentlyDenied = statuses.values.any((status) => status.isPermanentlyDenied);
         if (permanentlyDenied) {
            _showPermissionDialog();
         } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Permissions are required for scanning.')),
            );
         }
       }
    }
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_t('permissions_required')),
        content: Text(_t('permissions_explanation')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(_t('cancel')),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: Text(_t('open_settings')),
          ),
        ],
      ),
    );
  }

  void _startScan() async {
    if (_isScanning) return;

    setState(() {
      _isScanning = true;
      if (_isBluetooth) {
        _bluetoothDevices = [];
      } else {
        _wifiNetworks = [];
      }
    });

    if (_isBluetooth) {
      await _startBleScan();
    } else {
      await _startWifiScan();
    }
  }

  void _stopScan() {
    if (_isBluetooth) {
      FlutterBluePlus.stopScan();
    }
    // WiFi scan stops automatically after one run usually, but we reset state
    if (mounted) {
      setState(() {
        _isScanning = false;
      });
    }
  }

  // --- Bluetooth Logic ---
  Future<void> _startBleScan() async {
    // Check if Bluetooth is On
    if (FlutterBluePlus.adapterStateNow != BluetoothAdapterState.on) {
        try {
          if (Platform.isAndroid) {
             await FlutterBluePlus.turnOn();
          } else {
             // For iOS, we can't turn it on programmatically
             if (mounted) {
                 ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please turn on Bluetooth')),
                 );
             }
             setState(() => _isScanning = false); // Stop fast
             return;
          }
        } catch (e) {
           if (mounted) {
             ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Could not turn on Bluetooth: $e')),
             );
             setState(() => _isScanning = false); 
           }
           return;
        }
    }

    try {
      // Listen to scan results
      _bleSubscription?.cancel();
      _bleSubscription = FlutterBluePlus.scanResults.listen((results) {
        if (mounted) {
          setState(() {
            _bluetoothDevices = results;
          });
        }
      });

      _bleScanSubscription?.cancel();
      _bleScanSubscription = FlutterBluePlus.isScanning.listen((isScanning) {
        if (mounted) {
           setState(() {
             _isScanning = isScanning;
           });
        }
      });

      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));
    } catch (e) {
      print("BLE Scan Error: $e");
      if (mounted) {
        setState(() => _isScanning = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Scan Error: $e")));
      }
    }
  }



  // --- Wi-Fi Logic ---
  Future<void> _startWifiScan() async {
    try {
      final can = await WiFiScan.instance.canStartScan(askPermissions: true);
      if (can != CanStartScan.yes) {
         if (mounted) {
            setState(() => _isScanning = false);
            
            String errorMsg;
            switch (can) {
              case CanStartScan.noLocationPermissionRequired:
                errorMsg = "Location permission is required.";
                break;
              case CanStartScan.noLocationPermissionDenied:
                 errorMsg = "Location permission is denied.";
                 break;
              case CanStartScan.noLocationServiceDisabled:
                 errorMsg = "Location service is disabled. Please turn it on.";
                 break;
              case CanStartScan.failed:
                 errorMsg = "Scan failed for unknown reason.";
                 break;
              default:
                 errorMsg = "Cannot start Wi-Fi scan: $can";
            }

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(errorMsg),
                action: (can == CanStartScan.noLocationServiceDisabled || 
                         can == CanStartScan.noLocationPermissionDenied) 
                    ? SnackBarAction(
                        label: _t('open_settings'),
                        onPressed: openAppSettings,
                      )
                    : null,
              ),
            );
         }
         return;
      }

      await WiFiScan.instance.startScan();
      
      // Stream is safer
      _wifiSubscription?.cancel();
      _wifiSubscription = WiFiScan.instance.onScannedResultsAvailable.listen((result) {
        if (mounted) {
          setState(() {
            _wifiNetworks = result;
            _isScanning = false; // Scan finished
          });
        }
      });
      
      // Fallback if stream doesn't trigger (sometimes happens)
      await Future.delayed(const Duration(seconds: 5));
      if (_isScanning && mounted) {
         final results = await WiFiScan.instance.getScannedResults();
         setState(() {
           _wifiNetworks = results;
           _isScanning = false;
         });
      }

    } catch (e) {
      print("WiFi Scan Error: $e");
      if (mounted) {
         setState(() => _isScanning = false);
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("WiFi Error: $e")));
      }
    }
  }

  void _toggleMode(bool isBluetooth) {
    if (_isBluetooth != isBluetooth) {
      _stopScan();
      setState(() {
        _isBluetooth = isBluetooth;
        _bluetoothDevices = [];
        _wifiNetworks = [];
      });
      _startScan();
    }
  }

  String _t(String key) {
    final locale = Localizations.localeOf(context).languageCode;
    return AppTranslations.get(locale, key);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_t('device_connection'), style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: _isScanning 
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Icon(Icons.refresh),
            onPressed: _startScan,
          ),
        ],
      ),
      body: Column(
        children: [
          // Toggle Header
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.orange.shade50,
            child: Row(
              children: [
                Expanded(
                  child: _buildToggleButton(
                    label: _t('bluetooth'),
                    icon: Icons.bluetooth,
                    isSelected: _isBluetooth,
                    onTap: () => _toggleMode(true),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildToggleButton(
                    label: _t('wifi'),
                    icon: Icons.wifi,
                    isSelected: !_isBluetooth,
                    onTap: () => _toggleMode(false),
                  ),
                ),
              ],
            ),
          ),

          // Device List
          Expanded(
            child: _buildList(),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    if (_isBluetooth) {
      // Filter devices to only show those containing "ESP" (case-insensitive)
      final espDevices = _bluetoothDevices.where((r) {
        final name = r.device.platformName;
        return name.toUpperCase().contains('ESP');
      }).toList();

      if (espDevices.isEmpty && !_isScanning) {
        return _buildEmptyState();
      }
      return ListView.builder(
        itemCount: espDevices.length,
        padding: const EdgeInsets.all(8),
        itemBuilder: (context, index) {
          final result = espDevices[index];
          final name = result.device.platformName.isNotEmpty ? result.device.platformName : "Unknown Device";
          return Card(
             margin: const EdgeInsets.only(bottom: 8),
             shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
             child: ListTile(
               leading: const Icon(Icons.bluetooth, color: Colors.blue),
               title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
               subtitle: Text("${result.device.remoteId} (${result.rssi} dBm)"),
               trailing: ElevatedButton(
                 onPressed: () => _connectBle(result.device),
                 style: ElevatedButton.styleFrom(
                   backgroundColor: Colors.orange,
                   foregroundColor: Colors.white,
                   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                 ),
                 child: Text(_t('connect')),
               ),
             ),
          );
        },
      );
    } else {
      // Wi-Fi
      // Filter networks to only show those containing "ESP" (case-insensitive)
      final espWifi = _wifiNetworks.where((net) {
        return net.ssid.toUpperCase().contains('ESP');
      }).toList();

      if (espWifi.isEmpty && !_isScanning) {
        return _buildEmptyState();
      }
      return ListView.builder(
        itemCount: espWifi.length,
        padding: const EdgeInsets.all(8),
        itemBuilder: (context, index) {
          final network = espWifi[index];
          return Card(
             margin: const EdgeInsets.only(bottom: 8),
             shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
             child: ListTile(
               leading: const Icon(Icons.wifi, color: Colors.green),
               title: Text(network.ssid.isNotEmpty ? network.ssid : "Hidden Network", style: const TextStyle(fontWeight: FontWeight.bold)),
               subtitle: Text("Level: ${network.level} dBm"),
               trailing: ElevatedButton(
                 onPressed: () => _connectWifi(network),
                 style: ElevatedButton.styleFrom(
                   backgroundColor: Colors.orange,
                   foregroundColor: Colors.white,
                   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                 ),
                 child: Text(_t('connect')),
               ), 
             ),
          );
        },
      );
    }
  }

  Future<void> _connectBle(BluetoothDevice device) async {
    _showLoadingModal("Connecting to ${device.platformName}...");
    try {
      await device.connect(autoConnect: false); 
      if (mounted) {
        Navigator.pop(context); // Close loading modal
        _showSuccessModal("Connected", "Successfully connected to ${device.platformName.isNotEmpty ? device.platformName : "Device"}!");
      }
    } catch (e) {
       if (mounted) {
         Navigator.pop(context); // Close loading modal
         _showErrorModal("Connection Failed", "Could not connect to ${device.platformName}: $e");
       }
    }
  }

  Future<void> _connectWifi(WiFiAccessPoint network) async {
    final TextEditingController pwController = TextEditingController(text: "12345678");
    bool? shouldConnect = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Connect to ${network.ssid}"),
        content: TextField(
          controller: pwController,
          decoration: const InputDecoration(labelText: "Password"),
          obscureText: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(_t('cancel'))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text(_t('connect'))),
        ]
      )
    );

    if (shouldConnect != true) return;

    _showLoadingModal("Connecting to ${network.ssid}...");
    
    try {
      bool result = await WiFiForIoTPlugin.connect(
        network.ssid,
        password: pwController.text,
        joinOnce: true,
        security: NetworkSecurity.WPA,
        withInternet: false,
      );
      
      if (!mounted) return;
      Navigator.pop(context); // close loading modal

      if (result) {
        _showSuccessModal("Connected!", "Successfully connected to ${network.ssid}.");
      } else {
        _showErrorModal("Connection Failed", "Could not connect to ${network.ssid}. Please check the password or try again.");
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // close loading modal
      _showErrorModal("Error", "An error occurred: $e");
    }
  }

  void _showLoadingModal(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: Colors.orange),
            const SizedBox(height: 20),
            Text(message, style: const TextStyle(fontSize: 16)),
          ],
        ),
      ),
    );
  }

  void _showSuccessModal(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
             const Icon(Icons.check_circle, color: Colors.green, size: 60),
             const SizedBox(height: 20),
             Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
             const SizedBox(height: 10),
             Text(message, textAlign: TextAlign.center),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(_t('ok'), style: const TextStyle(color: Colors.orange)),
          )
        ]
      ),
    );
  }

  void _showErrorModal(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
             const Icon(Icons.cancel, color: Colors.red, size: 60), // X logo for error
             const SizedBox(height: 20),
             Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
             const SizedBox(height: 10),
             Text(message, textAlign: TextAlign.center),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(_t('ok'), style: const TextStyle(color: Colors.orange)),
          )
        ]
      ),
    );
  }

  Widget _buildEmptyState() {
     return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(_isBluetooth ? Icons.bluetooth_disabled : Icons.wifi_off, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            Text(_t('no_devices_found'), style: const TextStyle(color: Colors.grey)),
          ],
        ),
      );
  }

  Widget _buildToggleButton({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: isSelected ? Colors.orange : Colors.white,
          borderRadius: BorderRadius.circular(25),
          border: Border.all(color: Colors.orange),
          boxShadow: isSelected
              ? [BoxShadow(color: Colors.orange.withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 4))]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isSelected ? Colors.white : Colors.orange),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.orange,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
