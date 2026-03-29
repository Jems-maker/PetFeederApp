#include <WiFi.h>
#include <FirebaseESP32.h>
#include <ESP32Servo.h>
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>
#include <WebServer.h>
#include <time.h>

WebServer server(80);

// 1. Define WiFi Credentials
#define WIFI_SSID "PetFeeder"
#define WIFI_PASSWORD "secret123"

// 2. Define Firebase Credentials
#define FIREBASE_HOST "YOUR_FIREBASE_PROJECT_ID.firebaseio.com"
#define FIREBASE_AUTH "YOUR_FIREBASE_DATABASE_SECRET"

// 3. Define Servo Pin
#define SERVO_PIN 18

FirebaseData firebaseData;
FirebaseAuth auth;
FirebaseConfig config;
Servo myservo;

bool deviceConnected = false;
bool isOnline = false;

class MyServerCallbacks: public BLEServerCallbacks {
    void onConnect(BLEServer* pServer) {
      deviceConnected = true;
      Serial.println("BLE Client Connected");
    };

    void onDisconnect(BLEServer* pServer) {
      deviceConnected = false;
      Serial.println("BLE Client Disconnected");
      pServer->getAdvertising()->start();
      Serial.println("BLE Advertising restarted");
    }
};

void setupBLE() {
  BLEDevice::init("ESP32_PetFeeder");
  BLEServer *pServer = BLEDevice::createServer();
  pServer->setCallbacks(new MyServerCallbacks());
  
  BLEService *pService = pServer->createService("4fafc201-1fb5-459e-8fcc-c5c9c331914b");
  pService->start();
  
  BLEAdvertising *pAdvertising = BLEDevice::getAdvertising();
  pAdvertising->addServiceUUID("4fafc201-1fb5-459e-8fcc-c5c9c331914b");
  pAdvertising->setScanResponse(true);
  pAdvertising->setMinPreferred(0x06);
  
  BLEDevice::startAdvertising();
  Serial.println("BLE Setup done, waiting for connections.");
}


void setup() {
  Serial.begin(115200);

  // Initialize BLE
  setupBLE();
  
  // Set Wi-Fi to both Access Point (for app discovery) and Station (for internet)
  WiFi.mode(WIFI_AP_STA);
  WiFi.softAP("ESP32_PetFeeder", "12345678"); // 12345678 is the default password

  // Connect to home router
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  Serial.print("Connecting to Wi-Fi");
  
  // Add a 10-second timeout so it DOES NOT freeze if the Wi-Fi is wrong!
  int attempts = 0;
  while (WiFi.status() != WL_CONNECTED && attempts < 20) {
    Serial.print(".");
    delay(500);
    attempts++;
  }
  Serial.println();

  if (WiFi.status() == WL_CONNECTED) {
    isOnline = true;
    Serial.print("Connected with IP: ");
    Serial.println(WiFi.localIP());

    // Connect to Firebase ONLY if internet works
    config.database_url = FIREBASE_HOST;
    config.signer.tokens.legacy_token = FIREBASE_AUTH;
    Firebase.begin(&config, &auth);
    Firebase.reconnectWiFi(true);
    
    // Initialize NTP time for scheduling (GMT+8)
    configTime(8 * 3600, 0, "pool.ntp.org", "time.nist.gov");
  } else {
    isOnline = false;
    Serial.println("Wi-Fi failed! Continuing in Offline/App Mode.");
    // Fix missing hotspot by disabling the constantly searching Station mode
    WiFi.disconnect(true);
    WiFi.mode(WIFI_AP);
    delay(100);
    WiFi.softAPConfig(IPAddress(192, 168, 4, 1), IPAddress(192, 168, 4, 1), IPAddress(255, 255, 255, 0));
    WiFi.softAP("ESP32_PetFeeder", "12345678");
  }

  // Attach Servo
  myservo.attach(SERVO_PIN);
  myservo.write(0); // Initial position

  // Start Offline Web Server
  server.on("/feed", HTTP_GET, []() {
    Serial.println("Offline Command Received! Serving request.");
    server.send(200, "text/plain", "SUCCESS: Pet Fed via Offline Mode!");
    feedPet();
  });
  server.begin();
  Serial.println("Offline Web Server Started on Port 80 (IP: 192.168.4.1)");
}

void loop() {
  // 1. Listen for Offline App Commands (Direct Wi-Fi Hotspot)
  server.handleClient();

  // 2. Listen for Online App Commands and Schedules
  if (isOnline) {
    if (Firebase.getString(firebaseData, "/feed_command/status")) {
      String status = firebaseData.stringData();
      if (status == "PENDING") {
        feedPet();
      }
    } else {
      // Avoid spamming offline errors, but keeping log active
      Serial.println(firebaseData.errorReason());
    }

    // 3. Check for Schedule every 30 seconds
    static unsigned long lastScheduleCheck = 0;
    if (millis() - lastScheduleCheck > 30000) {
      lastScheduleCheck = millis();

      struct tm timeinfo;
      if (getLocalTime(&timeinfo, 10)) { // 10ms timeout to avoid lag
        char timeBuff[10];
        strftime(timeBuff, sizeof(timeBuff), "%H:%M", &timeinfo);
        String currentTime = String(timeBuff);

        const char* slots[] = {"morning", "noon", "afternoon"};
        for (int i = 0; i < 3; i++) {
          String path = String("/schedule/") + slots[i];
          if (Firebase.getBool(firebaseData, path + "/enabled")) {
            bool enabled = firebaseData.boolData();
            if (enabled) {
              if (Firebase.getString(firebaseData, path + "/time")) {
                String slotTime = firebaseData.stringData();
                if (slotTime == currentTime) {
                  static int lastFedMinute = -1;
                  if (timeinfo.tm_min != lastFedMinute) {
                    Serial.println("Schedule Triggered: " + String(slots[i]));
                    feedPet();
                    lastFedMinute = timeinfo.tm_min;
                  }
                }
              }
            }
          }
        }
      }
    }
  }

  delay(1000); 
}

void feedPet() {
  Serial.println("Feeding...");
  
  if (isOnline) {
    // Update status to PROCESSING
    Firebase.setString(firebaseData, "/feed_command/status", "PROCESSING");
  }

  // Rotate Servo
  myservo.write(90);
  delay(1000); // Wait for food to dispense
  myservo.write(0); 

  if (isOnline) {
    // Update status to SUCCESS
    Firebase.setString(firebaseData, "/feed_command/status", "SUCCESS");
  }
}
