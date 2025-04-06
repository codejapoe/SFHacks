#include <MeAuriga.h>

// Encoder setup
MeEncoderOnBoard Encoder_1(SLOT1);
MeEncoderOnBoard Encoder_2(SLOT2);
// Ultrasonic sensor setup - Using PORT_10 as in your buggy code
// Ensure the sensor is actually plugged into PORT_10.
MeUltrasonicSensor ultrasonic_sensor(PORT_10);

// --- Configuration ---
const float STOP_DISTANCE_CM = 20.0; // Stop if closer than 20cm
const unsigned long WATCHDOG_TIMEOUT = 15000;  // 15 second timeout

// Variables
int currentSpeed = 100;      // Default motor speed (0-255) for commands without explicit speed
unsigned long lastActivityTime = 0;
bool isStoppedByObstacle = false; // Flag to track if we stopped due to distance

// Forward declarations
void forward(int speed = 100);
void backward(int speed = 100);
void turnLeft(int speed = 100);
void turnRight(int speed = 100);
void stopMotors();
void setSpeed(int speed);
void processCommand(char command, int value);

void setup() {
  // Set PWM 8KHz for Auriga (from document examples)
  TCCR1A = _BV(WGM10);
  TCCR1B = _BV(CS11) | _BV(WGM12);
  TCCR2A = _BV(WGM21) | _BV(WGM20);
  TCCR2B = _BV(CS21);

  // Start hardware serial
  Serial.begin(115200);

  // Initial state
  stopMotors(); // Use the modified stopMotors for immediate effect

  Serial.println("BOOT:READY");
  Serial.println("Obstacle Avoidance Active.");
  Serial.print("Stop Distance: "); Serial.print(STOP_DISTANCE_CM); Serial.println(" cm");

  lastActivityTime = millis();
}

void loop() {
  // --- 1. Check for Obstacle ---
  float distance = ultrasonic_sensor.distanceCm(); // Read current distance

  // Use range from document (3cm-400cm), treat < 3cm as very close
  if (distance < STOP_DISTANCE_CM && distance >= 0) { // Check if too close (and reading is valid)
    if (!isStoppedByObstacle) { // Only print and stop if not already stopped by obstacle
       Serial.print("OBSTACLE! Distance: "); Serial.print(distance); Serial.println(" cm. Stopping.");
       stopMotors(); // Force stop using immediate PWM command
       isStoppedByObstacle = true; // Set the flag
    }
    // We don't process commands or run encoder loops if stopped by obstacle
    lastActivityTime = millis(); // Keep watchdog happy while stopped
    delay(50); // Small delay to prevent spamming stop command
    return; // Skip the rest of the loop
  }
  else {
     // If we were stopped by an obstacle but it's now clear
     if (isStoppedByObstacle) {
        Serial.println("Obstacle Cleared. Resuming.");
        isStoppedByObstacle = false; // Clear the flag
        // Motors remain stopped until a new command is received.
        // Or optionally, you could resume the last command here if needed (more complex).
     }
  }

  // --- 2. Watchdog Check (only if not stopped by obstacle) ---
  if (millis() - lastActivityTime > WATCHDOG_TIMEOUT) {
    Serial.println("WATCHDOG: Timeout - stopping motors");
    stopMotors();
    lastActivityTime = millis(); // Reset the timer
  }

  // --- 3. Process Serial Commands (only if not stopped by obstacle) ---
  if (Serial.available()) {
    char command = Serial.read();
    while(Serial.available() && Serial.peek() != '\n') { Serial.read(); }
    if(Serial.peek() == '\n') Serial.read();
    int value = 0; // Value parsing would need more logic if used with numeric commands

    processCommand(command, value);
    // Don't reset lastActivityTime here, processCommand does it
  }

  // --- 4. Run Encoder Loops (only if not stopped by obstacle) ---
  // Required for setTarPWM to work when a command IS active
  Encoder_1.loop();
  Encoder_2.loop();

  // Optional Debugging - print speed etc. (only if not stopped by obstacle)
  static unsigned long lastPrintTime = 0;
  if (millis() - lastPrintTime > 1000) {
    // Serial.print("Current Target Speed Var: "); Serial.println(currentSpeed);
    // Add other debug info if needed
    lastPrintTime = millis();
  }
}

// Process commands received via Serial
void processCommand(char command, int value) {
  lastActivityTime = millis(); // Reset watchdog timer on any valid command attempt
  String response = "";

  // Cannot process movement commands if stopped by obstacle
  if (isStoppedByObstacle) {
      Serial.println("WARN: Cannot process command while stopped by obstacle.");
      return; // Exit function early
  }

  command = toupper(command); // Make command case-insensitive

  // Handle movement commands (F, B, L, R, 0-8)
  if (String("FBLR012345678").indexOf(command) != -1) {
      Serial.print("CMD RX: "); Serial.println(command); // Acknowledge command reception
      switch (command) {
          case 'F': forward(); response = "ACK:FWD"; break;
          case 'B': backward(); response = "ACK:BWD"; break;
          case 'L': turnLeft(); response = "ACK:LEFT"; break;
          case 'R': turnRight(); response = "ACK:RIGHT"; break;
          // Numeric commands (simplified, may need value parsing adjustments)
          case '0': stopMotors(); response = "ACK:STOP"; break;
          case '1': backward(60); response = "ACK:BWD:S"; break;
          case '2': backward(100); response = "ACK:BWD:M"; break;
          case '3': backward(150); response = "ACK:BWD:F"; break;
          case '4': forward(60); response = "ACK:FWD:S"; break;
          case '5': forward(100); response = "ACK:FWD:M"; break;
          case '6': forward(150); response = "ACK:FWD:F"; break;
          case '7': turnLeft(80); response = "ACK:LEFT:S"; break;
          case '8': turnRight(80); response = "ACK:RIGHT:S"; break;
      }
  }
  // Handle non-movement commands
  else {
      switch (command) {
          case 'S': // Explicit Stop command
              Serial.print("CMD RX: "); Serial.println(command);
              stopMotors();
              response = "ACK:STOP";
              break;
          // Removed 'U' command for distance, as it's now checked continuously
          case 'X': // Status indicator
              response = "ACK:SYS:ON";
              break;
          case '?': // Status
              response = "STAT:ON:SPD_VAR:" + String(currentSpeed); // Report speed variable
              break;
          default:
              response = "ERR:INVALID_CMD";
              break;
      }
  }

  if (response.length() > 0) {
      Serial.println(response);
  }
}

// --- Motor control functions ---
// These now only SET the target PWM. The loop's distance check can override them.
void forward(int speed) {
  currentSpeed = constrain(speed, 0, 255);
  Encoder_1.setTarPWM(-currentSpeed);
  Encoder_2.setTarPWM(currentSpeed);
}

void backward(int speed) {
  currentSpeed = constrain(speed, 0, 255);
  Encoder_1.setTarPWM(currentSpeed);
  Encoder_2.setTarPWM(-currentSpeed);
}

void turnRight(int speed) {
  currentSpeed = constrain(speed, 0, 255);
  Encoder_1.setTarPWM(-currentSpeed);
  Encoder_2.setTarPWM(-currentSpeed);
}

void turnLeft(int speed) {
  currentSpeed = constrain(speed, 0, 255);
  Encoder_1.setTarPWM(currentSpeed);
  Encoder_2.setTarPWM(currentSpeed);
}

// --- IMMEDIATE Motor Stop Function ---
void stopMotors() {
  // Use setMotorPwm for immediate stop, overriding any setTarPWM ramp.
  // This is crucial for obstacle avoidance.
  Encoder_1.setMotorPwm(0);
  Encoder_2.setMotorPwm(0);
  // Also reset the target PWM in case the obstacle clears
  Encoder_1.setTarPWM(0);
  Encoder_2.setTarPWM(0);
  // Serial.println("DEBUG: stopMotors() called (setMotorPwm(0))"); // Optional debug
}

// Function to set the speed variable (doesn't move motors directly)
void setSpeed(int speed) {
  currentSpeed = constrain(speed, 0, 255);
  Serial.print("INFO: Speed variable set to "); Serial.println(currentSpeed);
}