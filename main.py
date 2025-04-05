# control.py
from motor import MotorController
import time 

emo = MotorController(port="/dev/ttyUSB0")

# Basic Movement

def happy():
    emo.forward(100)
    print("forward")
    time.sleep(1)
    print("sleep")
    
    emo.stop()
    print("stop")

    time.sleep(3)

    print("sleep")
    emo.forward(100)
    print("forward")

    time.sleep(1)
    print("sleep")

    emo.stop()
    print("stop")

    
happy()

