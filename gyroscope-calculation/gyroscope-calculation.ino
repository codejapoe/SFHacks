#include <MeAuriga.h>
#include <Wire.h> // Required for Gyro according to the document

// --- Configuration ---
// Encoder setup (as per your code and document examples)
MeEncoderOnBoard Encoder_1(SLOT1);
MeEncoderOnBoard Encoder_2(SLOT2);

// Gyro setup (based on document example for onboard gyro)
// Port 1, Address 0x69 is standard for the onboard gyro mentioned in the doc
MeGyro gyro(1, 0x69);

// --- Balancing Variables ---
float currentAngleX = 0;   // Variable to store current front/back tilt angle
float targetAngle = 0.0; // Target angle for balancing (upright)

// --- PID Controller Variables ---
// !!! CRITICAL: THESE VALUES ARE PLACEHOLDERS AND MUST BE TUNED !!!
// The document explains PID conceptually but does not provide tuned values.
// Start with small values and tune experimentally.
float Kp = 2.0;  // Proportional Gain - Reacts to current error
float Ki = 0.1;  // Integral Gain - Accumulates past errors to eliminate steady-state error
float Kd = 0.5;  // Derivative Gain - Reacts to the rate of change of error (damping)

float error = 0;
float lastError = 0;
float integral = 0;
float derivative = 0;
int motorPower = 0; // Calculated motor power output (-255 to 255)

// --- Timing ---
unsigned long loopStartTime = 0;
unsigned long previousTime = 0; // For calculating dt

void setup() {
  // Start Serial communication (baud rate from examples)
  Serial.begin(115200);
  Serial.println("Starting Self-Balancing Robot Setup...");

  // Initialize Gyro (based on document example)
  gyro.begin();
  Serial.println("Gyro Initialized. Calibrating...");
  // Optional: Perform gyro calibration if needed, though the basic example doesn't show it prominently.
  // gyro.deviceCalibration(); // Mentioned in the doc, might help accuracy.
  delay(1000); // Allow time for calibration/settling
  Serial.println("Gyro Ready.");

  // Set PWM Frequency for motors (from document examples)
  // This setup is required for MeEncoderOnBoard PWM control modes.
  TCCR1A = _BV(WGM10);
  TCCR1B = _BV(CS11) | _BV(WGM12);
  TCCR2A = _BV(WGM21) | _BV(WGM20);
  TCCR2B = _BV(CS21);
  Serial.println("Motor PWM Frequency Set (8KHz).");

  // Ensure motors are stopped initially
  stopMotors();
  Serial.println("Motors Stopped.");

  previousTime = millis(); // Initialize timing variable
  Serial.println("Setup Complete. Entering Balancing Loop.");
}

void loop() {
  loopStartTime = millis();

  // --- 1. Read Sensor ---
  // Update Gyro Readings (based on document example)
  gyro.update();
  currentAngleX = gyro.getAngleX(); // Get the primary tilt angle (front/back)

  // --- 2. Calculate Control Signal (PID) ---
  calculateMotorPower();

  // --- 3. Actuate Motors ---
  // Apply calculated power to motors.
  // Use setMotorPwm for direct PWM control as suggested by motor examples for immediate response.
  // The sign (+/-) might need swapping depending on motor wiring and orientation.
  // For balancing, both motors typically get the same magnitude command.
  Encoder_1.setMotorPwm(motorPower);
  Encoder_2.setMotorPwm(motorPower);

  // --- 4. Optional: Debugging Output ---
  // Print essential values periodically for tuning. Printing too often can slow down the loop.
  static unsigned long lastPrintTime = 0;
  if (millis() - lastPrintTime > 100) { // Print every 100ms
    Serial.print("AngleX: "); Serial.print(currentAngleX);
    Serial.print(" | Err: "); Serial.print(error);
    Serial.print(" | P: "); Serial.print(Kp * error);
    Serial.print(" | I: "); Serial.print(Ki * integral);
    Serial.print(" | D: "); Serial.print(Kd * derivative);
    Serial.print(" | Pwr: "); Serial.println(motorPower);
    lastPrintTime = millis();
  }

  // --- Loop Timing Control ---
  // Ensure the loop runs at a relatively consistent rate if needed, though basic examples don't enforce this.
  // A delay might be needed if the loop runs too fast, but often it's better to run as fast as possible.
  // delay(10); // Example: Small delay, adjust as needed during tuning.
  
  // Note: The MeEncoderOnBoard::loop() function is essential if using setTarPWM, runSpeed, or moveTo methods,
  // as it handles the internal PID/ramping for those specific functions.
  // For direct setMotorPwm control used here for balancing, it might not be strictly necessary for the
  // balancing itself, but harmless to include if you might use other encoder functions later.
  Encoder_1.loop();
  Encoder_2.loop();
}

// --- PID Calculation Function ---
void calculateMotorPower() {
  // Calculate time difference (dt) for integral and derivative terms - basic approach
  unsigned long currentTime = millis();
  float dt = (currentTime - previousTime) / 1000.0; // Time difference in seconds
  previousTime = currentTime;
  
  // Avoid division by zero or huge dt on first loop
  if (dt <= 0 || dt > 0.5) dt = 0.01; // Assume a nominal dt if unreasonable

  error = targetAngle - currentAngleX; // Calculate the error (difference from vertical)

  // Integral term (accumulates error over time)
  integral += error * dt;
  // Optional: Anti-windup for integral term (prevent it from growing too large)
  integral = constrain(integral, -100, 100); // Adjust limits as needed during tuning

  // Derivative term (rate of change of error)
  derivative = (error - lastError) / dt;

  // PID Calculation: Sum of the three components
  motorPower = (Kp * error) + (Ki * integral) + (Kd * derivative);

  // Store error for next derivative calculation
  lastError = error;

  // Constrain motor power to valid PWM range (-255 to 255)
  // The MeEncoderOnBoard library functions typically accept -255 to 255.
  motorPower = constrain(motorPower, -255, 255);
}

// --- Motor Stop Function ---
void stopMotors() {
  // Use setMotorPwm for direct control, ensuring immediate stop
  Encoder_1.setMotorPwm(0);
  Encoder_2.setMotorPwm(0);
  motorPower = 0;   // Reset calculated power
  integral = 0;     // Reset integral term when stopped
  lastError = 0;    // Reset last error
  Serial.println("CMD: Motors Stopped, PID Reset.");
}

// --- Note on other functions (forward, backward, turn, processCommand) ---
// Your original functions for movement (forward, backward, turnLeft, turnRight)
// and command processing (processCommand) are not included in this basic balancing loop.
// Integrating movement requires modifying the 'targetAngle' based on commands
// or adding the movement command value to the PID output, which adds complexity
// beyond the direct examples in the reference document.