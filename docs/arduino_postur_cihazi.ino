#include <ArduinoBLE.h>
#include <Wire.h>
#include <LSM6DS3.h>
#include <math.h>

LSM6DS3 imu(I2C_MODE, 0x6A);

BLEService nusService("6E400001-B5A3-F393-E0A9-E50E24DCCA9E");
BLECharacteristic txChar("6E400003-B5A3-F393-E0A9-E50E24DCCA9E", BLENotify, 40);
BLECharacteristic rxChar("6E400002-B5A3-F393-E0A9-E50E24DCCA9E", BLEWrite | BLEWriteWithoutResponse, 20);

const unsigned long ACTIVE_SEND_INTERVAL_MS = 500;
const unsigned long STILLNESS_TIME_MS = 900000UL;

const float FILTER_ALPHA = 0.18f;
const float ANGLE_DEADBAND_DEG = 0.7f;
const float MOTION_THRESHOLD_DEG = 2.0f;
const float WAKE_THRESHOLD_DEG = 2.5f;

const float BAD_POSTURE_THRESHOLD_DEG = 15.0f;
const float GOOD_POSTURE_THRESHOLD_DEG = 10.0f;
const unsigned long BAD_POSTURE_CONFIRM_MS = 3000;
const unsigned long GOOD_POSTURE_CONFIRM_MS = 2000;

const unsigned long CALIBRATION_TIME_MS = 4000;
const int CALIBRATION_SAMPLE_DELAY_MS = 25;

float pitchOffset = 0.0f;
float rollOffset = 0.0f;

float filtPitch = 0.0f;
float filtRoll = 0.0f;
float stablePitch = 0.0f;
float stableRoll = 0.0f;
float lastMotionPitch = 0.0f;
float lastMotionRoll = 0.0f;

bool filterInitialized = false;
bool idleMode = false;

enum PostureState { POSTURE_GOOD, POSTURE_BAD };
PostureState postureState = POSTURE_GOOD;

bool pendingBad = false;
bool pendingGood = false;
unsigned long badStart = 0;
unsigned long goodStart = 0;

unsigned long lastSendTime = 0;
unsigned long lastMotionTime = 0;

void readAnglesRaw(float &pitch, float &roll) {
  float ax = imu.readFloatAccelX();
  float ay = imu.readFloatAccelY();
  float az = imu.readFloatAccelZ();

  roll = atan2(ay, az) * 180.0f / PI;
  pitch = atan2(-ax, sqrtf(ay * ay + az * az)) * 180.0f / PI;
}

float normalizeAngle(float angle) {
  while (angle > 180.0f) angle -= 360.0f;
  while (angle < -180.0f) angle += 360.0f;
  return angle;
}

float applyDeadband(float current, float previous) {
  return (fabsf(current - previous) < ANGLE_DEADBAND_DEG) ? previous : current;
}

void updateAngles(float &pitch, float &roll) {
  float rawPitch, rawRoll;
  readAnglesRaw(rawPitch, rawRoll);

  float p = normalizeAngle(rawPitch - pitchOffset);
  float r = normalizeAngle(rawRoll - rollOffset);

  if (!filterInitialized) {
    filtPitch = stablePitch = p;
    filtRoll = stableRoll = r;
    filterInitialized = true;
  } else {
    filtPitch = FILTER_ALPHA * p + (1.0f - FILTER_ALPHA) * filtPitch;
    filtRoll = FILTER_ALPHA * r + (1.0f - FILTER_ALPHA) * filtRoll;
    stablePitch = applyDeadband(filtPitch, stablePitch);
    stableRoll = applyDeadband(filtRoll, stableRoll);
  }

  pitch = stablePitch;
  roll = stableRoll;
}

void sendText(const char *txt) {
  txChar.writeValue((uint8_t *)txt, strlen(txt));
  Serial.println(txt);
}

void sendStatus(float p, float r, const char *state) {
  char msg[40];
  snprintf(msg, sizeof(msg), "%.1f,%.1f,%s", p, r, state);
  txChar.writeValue((uint8_t *)msg, strlen(msg));
  Serial.println(msg);
}

void calibrateIMU() {
  float sumP = 0.0f;
  float sumR = 0.0f;
  int count = 0;

  unsigned long start = millis();
  while (millis() - start < CALIBRATION_TIME_MS) {
    float p, r;
    readAnglesRaw(p, r);
    sumP += p;
    sumR += r;
    count++;
    delay(CALIBRATION_SAMPLE_DELAY_MS);
  }

  if (count > 0) {
    pitchOffset = sumP / count;
    rollOffset = sumR / count;
  }

  filterInitialized = false;
}

void handleRxCommand() {
  if (!rxChar.written()) return;

  int len = rxChar.valueLength();
  if (len <= 0) return;

  char cmd[32] = {0};
  int copyLen = (len < 31) ? len : 31;
  memcpy(cmd, rxChar.value(), copyLen);
  cmd[copyLen] = '\0';

  String s = String(cmd);
  s.trim();
  s.toUpperCase();

  Serial.print("RX: ");
  Serial.println(s);

  if (s == "CAL") {
    sendText("CAL_START");
    calibrateIMU();

    postureState = POSTURE_GOOD;
    pendingBad = false;
    pendingGood = false;
    idleMode = false;
    lastMotionTime = millis();

    sendText("CAL_OK");
  } else if (s == "PING") {
    sendText("PONG");
  } else if (s == "RESET") {
    pitchOffset = 0.0f;
    rollOffset = 0.0f;
    filterInitialized = false;
    sendText("RESET_OK");
  }
}

void updatePosture(float pitch) {
  float angle = fabsf(pitch);
  unsigned long now = millis();

  if (postureState == POSTURE_GOOD) {
    if (angle >= BAD_POSTURE_THRESHOLD_DEG) {
      if (!pendingBad) {
        pendingBad = true;
        badStart = now;
      } else if (now - badStart >= BAD_POSTURE_CONFIRM_MS) {
        postureState = POSTURE_BAD;
        pendingBad = false;
        sendText("BAD_POSTURE");
      }
    } else {
      pendingBad = false;
    }
  } else {
    if (angle <= GOOD_POSTURE_THRESHOLD_DEG) {
      if (!pendingGood) {
        pendingGood = true;
        goodStart = now;
      } else if (now - goodStart >= GOOD_POSTURE_CONFIRM_MS) {
        postureState = POSTURE_GOOD;
        pendingGood = false;
        sendText("GOOD_POSTURE");
      }
    } else {
      pendingGood = false;
    }
  }
}

void setup() {
  Serial.begin(115200);
  delay(500);

  if (imu.begin() != 0) {
    Serial.println("IMU init failed");
    while (1) delay(10);
  }

  if (!BLE.begin()) {
    Serial.println("BLE failed");
    while (1) delay(10);
  }

  BLE.setLocalName("Postur_Duzeltici");
  BLE.setAdvertisedService(nusService);
  nusService.addCharacteristic(txChar);
  nusService.addCharacteristic(rxChar);
  BLE.addService(nusService);
  BLE.advertise();

  calibrateIMU();
  Serial.println("Ready");
}

void loop() {
  BLEDevice central = BLE.central();

  if (!central) {
    BLE.poll();
    delay(10);
    return;
  }

  Serial.print("Connected: ");
  Serial.println(central.address());
  lastMotionTime = millis();

  while (central.connected()) {
    BLE.poll();
    handleRxCommand();

    float pitch, roll;
    updateAngles(pitch, roll);

    unsigned long now = millis();
    float delta = max(
      fabsf(pitch - lastMotionPitch),
      fabsf(roll - lastMotionRoll)
    );

    if (delta > MOTION_THRESHOLD_DEG) {
      lastMotionTime = now;
      lastMotionPitch = pitch;
      lastMotionRoll = roll;
    }

    if (!idleMode && now - lastMotionTime > STILLNESS_TIME_MS) {
      idleMode = true;
      sendText("IDLE");
    }

    if (idleMode && delta > WAKE_THRESHOLD_DEG) {
      idleMode = false;
      sendText("WAKE");
    }

    if (!idleMode && now - lastSendTime > ACTIVE_SEND_INTERVAL_MS) {
      lastSendTime = now;
      updatePosture(pitch);
      sendStatus(pitch, roll, postureState == POSTURE_BAD ? "BAD" : "GOOD");
    }

    delay(20);
  }

  Serial.println("Disconnected");
  idleMode = false;
  filterInitialized = false;
}
