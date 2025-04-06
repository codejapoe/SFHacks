#include <MeAuriga.h>

// Encoder setup
MeEncoderOnBoard Encoder_1(SLOT1);
MeEncoderOnBoard Encoder_2(SLOT2);
// Ultrasonic sensor setup on PORT_6 (as per previous request)
MeUltrasonicSensor ultrasonic_sensor(PORT_10);

// Variables
bool systemActive = true;    // System always active by default
int currentSpeed = 100;      // Current motor speed (0-255)
unsigned long lastActivityTime = 0;
const unsigned long WATCHDOG_TIMEOUT = 15000;  // 15 second timeout

// Forward declarations of functions to fix scope issues
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

  // Start hardware serial (baud rate from previous examples)
  Serial.begin(115200);

  // Initial state
  stopMotors();

  Serial.println("BOOT:READY");
  Serial.println("System is ACTIVE by default");
  Serial.println("Added 'U' command for Ultrasonic distance."); // Info message

  lastActivityTime = millis();
}

void loop() {
  // Check for watchdog timeout
  if (millis() - lastActivityTime > WATCHDOG_TIMEOUT) {
    Serial.println("WATCHDOG: Timeout - stopping motors");
    stopMotors();
    lastActivityTime = millis(); // Reset the timer
  }

  // Check for serial commands
  if (Serial.available()) {
    // Read only the first character as the command
    char command = Serial.read();
    // Consume any remaining characters on the line (like newline)
    while(Serial.available() && Serial.peek() != '\n') {
        Serial.read();
    }
    if(Serial.peek() == '\n') Serial.read(); // Read the newline too

    // For commands needing a value, it would need a different parsing logic.
    // For now, value is unused for letter commands based on original code.
    int value = 0; // Reset value, not used for U command

    processCommand(command, value);
  }

  // Required for encoder operation using setTarPWM
  Encoder_1.loop();
  Encoder_2.loop();

  // Optionally print speed data (can be commented out if not needed)
  static unsigned long lastPrintTime = 0;
  if (millis() - lastPrintTime > 1000) {  // Print once per second
    // Serial.print("Speed 1: "); // Commented out to reduce noise, enable if needed
    // Serial.print(Encoder_1.getCurrentSpeed());
    // Serial.print(" ,Speed 2: ");
    // Serial.println(Encoder_2.getCurrentSpeed());
    lastPrintTime = millis();
  }
}

void processCommand(char command, int value) {
  lastActivityTime = millis();  // Reset watchdog timer
  String response = ""; // Initialize response string

  // Echo command for verification (optional, can be noisy)
  // Serial.print("CMD RX: ");
  // Serial.println(command);

  // Process numeric commands from original Auriga code
  // Note: Your original code read a value AFTER the command character.
  // Numeric commands might need adjusted parsing if used alongside single-char commands.
  // For simplicity, this keeps the structure but value is ignored for 'U'.
  if (command >= '0' && command <= '8') {
    switch (command) {
      case '0': // Stop
        stopMotors();
        response = "ACK:STOP";
        break;
      // Note: The value parsing logic might need refinement if you send e.g. "1 60"
      case '1': // Back slow
        backward(value > 0 ? value : 60); // Using value if provided, else default
        response = "ACK:BWD:SLOW:" + String(value > 0 ? value : 60);
        break;
      case '2': // Back medium
        backward(100);
        response = "ACK:BWD:MED";
        break;
      case '3': // Back fast
        backward(150); // Increased speed slightly for distinction
        response = "ACK:BWD:FAST";
        break;
      case '4': // Forward slow
        forward(60);
        response = "ACK:FWD:SLOW";
        break;
      case '5': // Forward medium
        forward(100);
        response = "ACK:FWD:MED";
        break;
      case '6': // Forward fast
        forward(150); // Increased speed slightly for distinction
        response = "ACK:FWD:FAST";
        break;
      case '7': // Left slow
        turnLeft(80); // Slightly slower turn for control
        response = "ACK:LEFT";
        break;
      case '8': // Right slow
        turnRight(80); // Slightly slower turn for control
        response = "ACK:RIGHT";
        break;
      default:
         response = "ERR:INVALID_NUM"; // Should not happen with check '0'-'8'
         break;
    }
  }
  // Additional letter-based commands
  else {
    // Convert command to uppercase for case-insensitivity
    command = toupper(command);

    switch (command) {
      case 'F': // Forward
        forward();
        response = "ACK:FWD";
        break;
      case 'B': // Backward
        backward();
        response = "ACK:BWD";
        break;
      case 'L': // Left
        turnLeft();
        response = "ACK:LEFT";
        break;
      case 'R': // Right
        turnRight();
        response = "ACK:RIGHT";
        break;
      case 'S': // Stop
        stopMotors();
        response = "ACK:STOP";
        break;

      // --- NEW: Ultrasonic Command ---
      case 'U':
        { // Use braces to create a local scope for the distance variable
          float distance = ultrasonic_sensor.distanceCm(); // Read distance using the function from the doc
          response = "DIST:"; // Start response string
          response += String(distance); // Append distance value
          response += "cm"; // Append unit
        }
        break;
      // --- End of New Command ---

      case 'X': // Status indicator (keep as is)
        response = "ACK:SYS:ON";
        break;
      case '?': // Status (keep as is)
        response = "STAT:ON:SPD:" + String(map(currentSpeed, 50, 150, 0, 9)); // Adjusted speed range mapping
        break;
      default:
        response = "ERR:INVALID_CMD"; // Error for unknown letter commands
        break;
    }
  }

  // Log response to serial for debugging/confirmation
  if (response.length() > 0) {
      Serial.println(response);
  }
}

// --- Motor control functions ---
// Using setTarPWM based on your original code which smoothly ramps speed.
// setTarPWM requires Encoder_1.loop() and Encoder_2.loop() in the main loop.
// Signs adjusted for typical differential drive forward/backward/turn
void forward(int speed) {
  currentSpeed = constrain(speed, 0, 255);
  Encoder_1.setTarPWM(-currentSpeed); // Motor 1 backward relative to chassis
  Encoder_2.setTarPWM(currentSpeed);  // Motor 2 forward relative to chassis
}

void backward(int speed) {
  currentSpeed = constrain(speed, 0, 255);
  Encoder_1.setTarPWM(currentSpeed);  // Motor 1 forward
  Encoder_2.setTarPWM(-currentSpeed); // Motor 2 backward
}

void turnRight(int speed) { // Turn in place to the right
  currentSpeed = constrain(speed, 0, 255);
  Encoder_1.setTarPWM(-currentSpeed); // Motor 1 backward
  Encoder_2.setTarPWM(-currentSpeed); // Motor 2 backward (relative to chassis, pushes right side forward)
}

void turnLeft(int speed) { // Turn in place to the left
  currentSpeed = constrain(speed, 0, 255);
  Encoder_1.setTarPWM(currentSpeed); // Motor 1 forward
  Encoder_2.setTarPWM(currentSpeed); // Motor 2 forward (relative to chassis, pushes left side forward)
}

void stopMotors() {
  Encoder_1.setTarPWM(0); // Target PWM = 0
  Encoder_2.setTarPWM(0);
  // It might take a moment to ramp down with setTarPWM.
  // For an immediate stop, you could use:
  // Encoder_1.setMotorPwm(0);
  // Encoder_2.setMotorPwm(0);
}

// This function only updates the variable, doesn't change motor state directly
void setSpeed(int speed) {
  currentSpeed = constrain(speed, 0, 255);
  Serial.print("INFO: Speed variable set to "); Serial.println(currentSpeed);
}