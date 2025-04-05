# motor.py
import time
import serial

class MotorController:
    def __init__(self, port='/dev/ttyUSB0', baudrate=115200, timeout=1):
        self.serial = serial.Serial(port, baudrate=baudrate, timeout=timeout)
        time.sleep(2)

    def send(self, cmd):
        self.serial.write((cmd + '\n').encode())
        time.sleep(0.05)
        return self.serial.readline().decode().strip()

    def forward(self, speed=None):
        if speed is not None:
            return self.send(f"5")  # or another mapped speed command
        return self.send("F")

    def backward(self, speed=None):
        if speed is not None:
            return self.send(f"2")  # or another mapped speed command
        return self.send("B")

    def left(self):
        return self.send("L")

    def right(self):
        return self.send("R")

    def stop(self):
        return self.send("S")

    def set_speed(self, level):
        return self.send(str(level))

    def get_status(self):
        return self.send("?")

    def emotion_happy(self):
        self.forward(200)         # Forward medium
        time.sleep(0.9)
        self.stop()
        time.sleep(0.9)
        self.forward(200)         # Forward again
        time.sleep(0.5)
        self.right()        # Spin right
        time.sleep(1.0)
        self.stop()
        return "Emotion: Happy"

    def emotion_sad(self):
        self.set_speed(80)
        self.backward()
        time.sleep(1.5)
        self.stop()
        time.sleep(1)
        self.left()
        time.sleep(0.6)
        self.stop()
        time.sleep(0.5)
        self.right()
        time.sleep(0.6)
        self.stop()
        return "Emotion: Sad"

    def close(self):
        self.serial.close()