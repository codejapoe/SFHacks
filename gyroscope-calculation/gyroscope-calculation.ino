#include <MeAuriga.h>
#include <Wire.h> // Required for Gyro according to the document

// --- Configuration ---
MeEncoderOnBoard Encoder_1(SLOT1);
MeEncoderOnBoard Encoder_2(SLOT2);
MeGyro gyro(1, 0x69);

// --- Balancing Variables ---
float currentAngleX = 0;
float targetAngle = 0.0; // Target angle, now tunable via Serial ('T' command)

// --- PID Controller Variables ---
// Initial values can still be set here, but they can be overridden via Serial.
float Kp = 60.0;  // Tunable via Serial ('P' command)
float Ki = 0.1;  // Tunable via Serial ('I' command)
float Kd = 1.3;  // Tunable via Serial ('D' command)

float error = 0;
float lastError = 0;
float integral = 0;
float derivative = 0;
int motorPower = 0;

// --- Timing ---
unsigned long loopStartTime = 0;
unsigned long previousTime = 0;

// --- Function Declarations ---
void calculateMotorPower();
void stopMotors();
void handleSerialCommands(); // New function to handle serial input

void setup() {
  Serial.begin(115200);
  Serial.println("Starting Self-Balancing Robot Setup...");
  Serial.println("Initializing Gyro...");
  gyro.begin();
  // gyro.deviceCalibration(); // Optional calibration
  delay(1000);
  Serial.println("Gyro Ready.");

  Serial.println("Setting Motor PWM Frequency...");
  TCCR1A = _BV(WGM10);
  TCCR1B = _BV(CS11) | _BV(WGM12);
  TCCR2A = _BV(WGM21) | _BV(WGM20);
  TCCR2B = _BV(CS21);
  Serial.println("Motor PWM Ready.");

  stopMotors(); // Ensure motors are stopped

  previousTime = millis();
  Serial.println("\nSetup Complete. Entering Balancing Loop.");
  Serial.println("--- Serial Tuning Commands ---");
  Serial.println("P<value> : Set Kp (e.g., P2.5)");
  Serial.println("I<value> : Set Ki (e.g., I0.05)");
  Serial.println("D<value> : Set Kd (e.g., D0.8)");
  Serial.println("T<value> : Set Target Angle (e.g., T-0.2)");
  Serial.println("S         : Stop motors and reset PID");
  Serial.println("?         : Print current PID values");
  Serial.println("------------------------------\n");
}

void loop() {
  loopStartTime = millis();

  // --- NEW: Handle Serial Commands ---
  // Check for incoming commands to adjust PID values
  handleSerialCommands();

  // --- 1. Read Sensor ---
  gyro.update();
  currentAngleX = gyro.getAngleX();

  // --- 2. Calculate Control Signal (PID) ---
  calculateMotorPower();

  // --- 3. Actuate Motors ---
  // IMPORTANT: Check motor direction during testing.
  // If it accelerates falling over, swap the signs (e.g., use +motorPower for both).
  Encoder_1.setMotorPwm(motorPower);
  Encoder_2.setMotorPwm(-motorPower); // Often both motors need the same sign for forward/backward balancing correction. Test this!

  // --- 4. Optional: Debugging Output ---
  static unsigned long lastPrintTime = 0;
  if (millis() - lastPrintTime > 100) { // Print every 100ms
    // Reduced print frequency slightly to make tuning output clearer
    Serial.print("AngX:"); Serial.print(currentAngleX, 2); // Print with 2 decimal places
    // Serial.print(" | Err:"); Serial.print(error, 2); // Optional: Error details
    Serial.print(" | Pwr:"); Serial.print(motorPower);
    // Serial.print(" | Kp:"); Serial.print(Kp); // Optional: PID values check
    // Serial.print(" Ki:"); Serial.print(Ki);
    // Serial.print(" Kd:"); Serial.print(Kd);
    // Serial.print(" Tgt:"); Serial.print(targetAngle);
    Serial.println(); // Newline for readability
    lastPrintTime = millis();
  }

  // Required MeEncoderOnBoard loop calls if using certain modes, harmless to keep
  Encoder_1.loop();
  Encoder_2.loop();
}

// --- PID Calculation Function ---
void calculateMotorPower() {
  unsigned long currentTime = millis();
  float dt = (currentTime - previousTime) / 1000.0;
  previousTime = currentTime;

  if (dt <= 0 || dt > 0.5) dt = 0.01; // Basic dt sanity check

  error = targetAngle - currentAngleX;
  integral += error * dt;
  integral = constrain(integral, -100, 100); // Integral anti-windup

  // Add check for valid dt before division
  if (dt > 0) {
      derivative = (error - lastError) / dt;
  } else {
      derivative = 0; // Avoid division by zero
  }

  motorPower = (Kp * error) + (Ki * integral) + (Kd * derivative);
  lastError = error;
  motorPower = constrain(motorPower, -255, 255);
}

// --- Motor Stop Function ---
void stopMotors() {
  Encoder_1.setMotorPwm(0);
  Encoder_2.setMotorPwm(0);
  motorPower = 0;
  integral = 0;
  lastError = 0; // Reset PID state variables
  derivative = 0; // Also reset derivative
  Serial.println("CMD: Motors Stopped, PID Reset.");
}

// --- NEW: Serial Command Handler ---
void handleSerialCommands() {
  if (Serial.available() > 0) {
    String input = Serial.readStringUntil('\n');
    input.trim(); // Remove leading/trailing whitespace

    if (input.length() > 0) {
      char command = input.charAt(0);
      String valueStr = input.substring(1);
      float value = valueStr.toFloat(); // Convert remaining string to float

      switch (command) {
        case 'P':
        case 'p':
          Kp = value;
          Serial.print("CMD: Set Kp = "); Serial.println(Kp);
          break;
        case 'I':
        case 'i':
          Ki = value;
          // Reset integral when Ki changes to prevent sudden jumps
          integral = 0;
          Serial.print("CMD: Set Ki = "); Serial.println(Ki);
          Serial.println("     (Integral term reset)");
          break;
        case 'D':
        case 'd':
          Kd = value;
          Serial.print("CMD: Set Kd = "); Serial.println(Kd);
          break;
        case 'T':
        case 't':
          targetAngle = value;
          Serial.print("CMD: Set Target Angle = "); Serial.println(targetAngle);
          break;
        case 'S':
        case 's':
          stopMotors(); // Use the existing stop function
          break;
        case '?':
          Serial.println("--- Current PID Values ---");
          Serial.print("Kp = "); Serial.println(Kp);
          Serial.print("Ki = "); Serial.println(Ki);
          Serial.print("Kd = "); Serial.println(Kd);
          Serial.print("Target Angle = "); Serial.println(targetAngle);
          Serial.println("--------------------------");
          break;
        default:
          Serial.print("ERR: Unknown command: "); Serial.println(input);
          break;
      }
    }
  }
}