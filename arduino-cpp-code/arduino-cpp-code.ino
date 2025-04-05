#include <MeAuriga.h>

// Encoder setup
MeEncoderOnBoard Encoder_1(SLOT1);
MeEncoderOnBoard Encoder_2(SLOT2);

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
  // Set PWM 8KHz for Auriga
  TCCR1A = _BV(WGM10);
  TCCR1B = _BV(CS11) | _BV(WGM12);
  TCCR2A = _BV(WGM21) | _BV(WGM20);
  TCCR2B = _BV(CS21);
  
  // Start hardware serial
  Serial.begin(115200);
  
  // Initial state
  stopMotors();
  
  Serial.println("BOOT:READY");
  Serial.println("System is ACTIVE by default");
  
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
    char command = Serial.read();
    int value = 0;
    
    // Check if there's more data (for speed values)
    if (Serial.available()) {
      String valueStr = Serial.readString();
      value = valueStr.toInt();
    }
    
    processCommand(command, value);
  }
  
  // Required for encoder operation
  Encoder_1.loop();
  Encoder_2.loop();
  
  // Optionally print speed data (can be commented out if not needed)
  static unsigned long lastPrintTime = 0;
  if (millis() - lastPrintTime > 1000) {  // Print once per second
    Serial.print("Speed 1: ");
    Serial.print(Encoder_1.getCurrentSpeed());
    Serial.print(" ,Speed 2: ");
    Serial.println(Encoder_2.getCurrentSpeed());
    lastPrintTime = millis();
  }
}

void processCommand(char command, int value) {
  lastActivityTime = millis();  // Reset watchdog timer
  String response;
  
  // Echo command for verification
  Serial.print("CMD: ");
  Serial.println(command);
  
  // Process numeric commands from original Auriga code
  if (command >= '0' && command <= '8') {
    switch (command) {
      case '0': // Stop
        stopMotors();
        response = "ACK:STOP";
        break;
        
      case '1': // Back slow with variable speed
        backward(value > 0 ? value : 60);
        response = "ACK:BWD:SLOW:" + String(value > 0 ? value : 100);
        break;
        
      case '2': // Back medium
        backward(100);
        response = "ACK:BWD:MED";
        break;
        
      case '3': // Back fast
        backward(100);
        response = "ACK:BWD:FAST";
        break;
        
      case '4': // Forward slow
        forward(100);
        response = "ACK:FWD:SLOW";
        break;
        
      case '5': // Forward medium
        forward(100);
        response = "ACK:FWD:MED";
        break;
        
      case '6': // Forward fast
        forward(100);
        response = "ACK:FWD:FAST";
        break;
        
      case '7': // Left slow
        turnLeft(100);
        response = "ACK:LEFT";
        break;
        
      case '8': // Right slow
        turnRight(100);
        response = "ACK:RIGHT";
        break;
    }
  }
  // Additional letter-based commands from the original code
  else {
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
        
      case 'X': // Status indicator
        response = "ACK:SYS:ON";
        break;
        
      case '?': // Status
        response = "STAT:ON:SPD:" + String(map(currentSpeed, 50, 255, 0, 9));
        break;
        
      default:
        response = "ERR:INVALID";
        break;
    }
  }
  
  // Log response to serial for debugging
  Serial.println(response);
}

// Motor control functions
void forward(int speed) {
  currentSpeed = constrain(speed, 0, 255);
  Encoder_1.setTarPWM(currentSpeed);
  Encoder_2.setTarPWM(-currentSpeed);
}

void backward(int speed) {
  currentSpeed = constrain(speed, 0, 255);
  Encoder_1.setTarPWM(-currentSpeed);
  Encoder_2.setTarPWM(currentSpeed);
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

void stopMotors() {
  Encoder_1.setTarPWM(0);
  Encoder_2.setTarPWM(0);
}

void setSpeed(int speed) {
  currentSpeed = constrain(speed, 0, 255);
  // Note: This only sets the speed value, you'll need to reissue movement commands
}