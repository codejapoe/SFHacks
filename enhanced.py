import cv2
import numpy as np
import mediapipe as mp
import threading
import time
import random
from motor import MotorController

# Initialize motor controller
try:
    emo = MotorController(port="/dev/ttyUSB0")
    motor_available = True
    print("Motor controller connected successfully")
except Exception as e:
    motor_available = False
    print(f"Failed to connect to motor controller: {e}")
    print("Running in simulation mode without motors")

# Enhanced emotion-based action system
class EmotionalBehavior:
    def __init__(self, motor_controller=None):
        self.motor = motor_controller
        self.motor_available = motor_controller is not None
        self.last_action_time = 0
        self.attention_history = []  # Track attention over time
        self.emotion_history = []    # Track emotions over time
        self.interaction_level = 0   # 0-10 scale of how engaged the robot should be
        self.serial_error_count = 0  # Track serial errors
        self.personality_traits = {
            "curiosity": 7,    # 1-10 scale
            "excitability": 6, # 1-10 scale
            "shyness": 4       # 1-10 scale
        }
        
    # Update this method in the EmotionalBehavior class
    def update_interaction_level(self, attention_state, emotions_detected):
        # Add latest attention to history (keep last 50 frames)
        # Increase weight for "Watching" state to make it more sensitive
        attention_value = 3 if attention_state == "Watching" else (1 if attention_state == "Not Watching" else 0.5)
        self.attention_history.append(attention_value)
        if len(self.attention_history) > 50:
            self.attention_history.pop(0)
            
        # Calculate engagement with higher sensitivity to presence
        # This makes the system engage more easily even when the user is far away
        attention_score = sum(self.attention_history) / (len(self.attention_history) * 1.2) * 10
        
        # Adjust based on detected emotions - more sensitive overall
        emotion_factor = 1.2  # Base factor increased from 1.0 to be more sensitive
        if "Happy" in emotions_detected:
            emotion_factor += 0.5  # Increased from 0.4
        if "Surprised" in emotions_detected:
            emotion_factor += 0.4  # Increased from 0.3
        if "Interested" in emotions_detected:
            emotion_factor += 0.4  # Increased from 0.3
        # Add response to any detected emotion, even neutral
        if len(emotions_detected) > 0:
            emotion_factor += 0.2  # New: respond to any emotion detection
            
        # Calculate final interaction level - with a higher minimum threshold
        target_level = min(10, max(3, attention_score * emotion_factor))  # Minimum level of 3 instead of 0
        
        # Faster increases when being watched directly
        if attention_state == "Watching":
            self.interaction_level = min(10, self.interaction_level + 0.6)  # Faster increase
        # Slower decreases when not watching
        elif attention_state == "Not Watching":
            self.interaction_level = max(2, self.interaction_level - 0.05)  # Slower decrease, minimum of 2
        # Even when no user, maintain some minimal attentiveness
        else:  # No User state
            self.interaction_level = max(1, self.interaction_level - 0.1)  # Maintain minimal level
                
        return self.interaction_level

    def _find_person_action(self, intensity=1.0):
        """Execute a smoother search pattern to find people"""
        print(f"Executing person-finding action (intensity: {intensity:.1f})")
        if self.motor_available:
            try:
                # Calculate a slower, smoother rotation speed
                rotation_speed = int(30 + intensity * 20)  # Lower speed for smoother motion
                
                # Perform a single smooth scan from left to right
                # Start with left rotation
                self.motor.left()
                # Longer continuous rotation instead of stop-start
                scan_time = 1.5 * intensity  # Longer scan time for smoother motion
                time.sleep(scan_time)
                self.motor.stop()
                time.sleep(0.2)  # Brief pause
                
                # Then scan right
                self.motor.right()
                # Scan back with slightly longer time to cover full area
                time.sleep(scan_time * 1.2)
                self.motor.stop()
                time.sleep(0.2)  # Brief pause
                
                # Return to center (half the time of right scan)
                self.motor.left()
                time.sleep((scan_time * 1.2) / 2)
                self.motor.stop()
                
                self.serial_error_count = 0  # Reset error count on success
            except serial.serialutil.SerialException as e:
                self.serial_error_count += 1
                print(f"Serial error during person-finding action: {e}")
                if self.serial_error_count >= 3:
                    print("Multiple serial errors detected - switching to simulation mode")
                    self.motor_available = False
                time.sleep(3.0 * intensity)  # Simulate action time even on error
        else:
            print(f"SIMULATED: Smoothly scanning for people")
            time.sleep(3.0 * intensity)
        return True

    def approach_person(self, proximity=1.0):
        """Move toward a detected person
        
        Args:
            proximity: Float 0.0-1.0, where 1.0 means the person is far and 0.0 means very close
        """
        print(f"Approaching person (proximity factor: {proximity:.1f})")
        if self.motor_available:
            try:
                # Move forward at a speed proportional to the distance
                # When person is far (proximity near 1.0), move faster
                # When person is close (proximity near 0.0), move slower or stop
                if proximity > 0.3:  # Only approach if person isn't too close
                    approach_speed = int(30 + proximity * 40)  # 30-70 speed range
                    approach_time = min(1.5, proximity * 2.0)  # Maximum 1.5 seconds of movement
                    
                    self.motor.forward(approach_speed)
                    time.sleep(approach_time)
                    self.motor.stop()
                    self.serial_error_count = 0  # Reset error count on success
            except serial.serialutil.SerialException as e:
                self.serial_error_count += 1
                print(f"Serial error during person approach: {e}")
                if self.serial_error_count >= 3:
                    print("Multiple serial errors detected - switching to simulation mode")
                    self.motor_available = False
                time.sleep(min(1.5, proximity * 2.0))  # Simulate action time even on error
        else:
            print(f"SIMULATED: Approaching person at speed {int(30 + proximity * 40)} for {min(1.5, proximity * 2.0)} seconds")
            time.sleep(min(1.5, proximity * 2.0))
        return True

    def execute_action(self, action_type, intensity=1.0):
        """Execute a robot action with given intensity (0.0-1.0)"""
        current_time = time.time()
        
        # Don't allow actions too frequently, except for follow actions which need to be continuous
        if action_type != "follow_user" and current_time - self.last_action_time < 3:
            return False
            
        self.last_action_time = current_time
        
        if action_type == "happy":
            return self._happy_action(intensity)
        elif action_type == "curious":
            return self._curious_action(intensity)
        elif action_type == "surprised":
            return self._surprised_action(intensity)
        elif action_type == "seek_attention":
            return self._seek_attention_action(intensity)
        elif action_type == "follow_user":  # Add this new action type
            return self._follow_user_action(intensity)
        return False
    
    def _happy_action(self, intensity):
        print(f"Executing happy action (intensity: {intensity:.1f})")
        if self.motor_available:
            try:
                # Small dance with intensity-based speed
                speed = int(70 + (intensity * 30))
                self.motor.forward(speed)
                time.sleep(0.5 * intensity)
                self.motor.stop()
                time.sleep(0.2)
                # Use left/right without speed parameter
                self.motor.left()
                time.sleep(0.3 * intensity)
                self.motor.right()
                time.sleep(0.3 * intensity)
                self.motor.stop()
                self.serial_error_count = 0  # Reset error count on success
            except serial.serialutil.SerialException as e:
                self.serial_error_count += 1
                print(f"Serial error during happy action: {e}")
                if self.serial_error_count >= 3:
                    print("Multiple serial errors detected - switching to simulation mode")
                    self.motor_available = False
                time.sleep(1.0 * intensity)  # Simulate action time even on error
        else:
            print(f"SIMULATED: Happy dance with speed {int(70 + (intensity * 30))}")
            time.sleep(1.0 * intensity)
        return True
    
    def _curious_action(self, intensity):
        print(f"Executing curious action (intensity: {intensity:.1f})")
        if self.motor_available:
            try:
                # Gentle forward movement with a subtle head tilt (if hardware supports it)
                speed = int(40 + (intensity * 20))
                self.motor.forward(speed)
                time.sleep(0.6 * intensity)
                self.motor.stop()
                time.sleep(0.3)
                self.motor.left()
                time.sleep(0.2)
                self.motor.right()
                time.sleep(0.2)
                self.motor.stop()
                self.serial_error_count = 0  # Reset error count on success
            except serial.serialutil.SerialException as e:
                self.serial_error_count += 1
                print(f"Serial error during curious action: {e}")
                if self.serial_error_count >= 3:
                    print("Multiple serial errors detected - switching to simulation mode")
                    self.motor_available = False
                time.sleep(1.0 * intensity)  # Simulate action time even on error
        else:
            print(f"SIMULATED: Curious investigation at speed {int(40 + (intensity * 20))}")
            time.sleep(1.0 * intensity)
        return True
    
    def _surprised_action(self, intensity):
        print(f"Executing surprised action (intensity: {intensity:.1f})")
        if self.motor_available:
            try:
                # Quick backward motion
                speed = int(50 + (intensity * 50))
                self.motor.backward(speed)
                time.sleep(0.3 * intensity)
                self.motor.stop()
                time.sleep(0.2)
                # Then small motion forward (like recovering from surprise)
                self.motor.forward(30)
                time.sleep(0.2)
                self.motor.stop()
                self.serial_error_count = 0  # Reset error count on success
            except serial.serialutil.SerialException as e:
                self.serial_error_count += 1
                print(f"Serial error during surprised action: {e}")
                if self.serial_error_count >= 3:
                    print("Multiple serial errors detected - switching to simulation mode")
                    self.motor_available = False
                time.sleep(0.5 * intensity)  # Simulate action time even on error
        else:
            print(f"SIMULATED: Surprised reaction at speed {int(50 + (intensity * 50))}")
            time.sleep(0.5 * intensity)
        return True
    
    def _seek_attention_action(self, intensity):
        print(f"Executing attention-seeking action (intensity: {intensity:.1f})")
        if self.motor_available:
            try:
                # Series of movements to attract attention
                for _ in range(int(1 + intensity * 2)):
                    direction = random.choice(["left", "right"])
                    if direction == "left":
                        self.motor.left()
                    else:
                        self.motor.right()
                    time.sleep(0.3)
                    self.motor.stop()
                    time.sleep(0.2)
                
                # Small forward movement
                self.motor.forward(50)
                time.sleep(0.5)
                self.motor.stop()
                self.serial_error_count = 0  # Reset error count on success
            except serial.serialutil.SerialException as e:
                self.serial_error_count += 1
                print(f"Serial error during attention-seeking action: {e}")
                if self.serial_error_count >= 3:
                    print("Multiple serial errors detected - switching to simulation mode")
                    self.motor_available = False
                time.sleep(1.5 * intensity)  # Simulate action time even on error
        else:
            print(f"SIMULATED: Seeking attention with {int(1 + intensity * 2)} movements")
            time.sleep(1.5 * intensity)
        return True

    def _follow_user_action(self, intensity=1.0):
        """
        Execute actions to follow a person
        
        Args:
            intensity: Float 0.0-1.0, controls speed and responsiveness
        """
        print(f"Following user (intensity: {intensity:.1f})")
        if self.motor_available:
            try:
                # Move forward at a moderate speed
                follow_speed = int(40 + intensity * 20)  # 40-60 speed range
                
                # Brief forward motion
                self.motor.forward(follow_speed)
                time.sleep(0.3)  # Short movement to avoid overshooting
                self.motor.stop()
                
                self.serial_error_count = 0  # Reset error count on success
            except serial.serialutil.SerialException as e:
                self.serial_error_count += 1
                print(f"Serial error during follow action: {e}")
                if self.serial_error_count >= 3:
                    print("Multiple serial errors detected - switching to simulation mode")
                    self.motor_available = False
                time.sleep(0.3)  # Simulate action time even on error
        else:
            print(f"SIMULATED: Following user at speed {int(40 + intensity * 20)}")
            time.sleep(0.3)
        return True
    
        
# Import serial module for exception handling
import serial

# Initialize MediaPipe Face Detection and Hand solutions
mp_face_detection = mp.solutions.face_detection
mp_hands = mp.solutions.hands
mp_drawing = mp.solutions.drawing_utils
mp_drawing_styles = mp.solutions.drawing_styles

# Load OpenCV face detector as backup
face_cascade = cv2.CascadeClassifier(cv2.data.haarcascades + 'haarcascade_frontalface_default.xml')

# Initialize the detectors
face_detection = mp_face_detection.FaceDetection(min_detection_confidence=0.5)
hands = mp_hands.Hands(
    static_image_mode=False,
    max_num_hands=2,
    min_detection_confidence=0.5,
    min_tracking_confidence=0.5
)

# Initialize facial landmark detection for better emotion analysis
mp_face_mesh = mp.solutions.face_mesh
face_mesh = mp_face_mesh.FaceMesh(
    max_num_faces=1,
    refine_landmarks=True,
    min_detection_confidence=0.5,
    min_tracking_confidence=0.5
)

# Initialize behavior controller with error handling for serial connection
try:
    behavior = EmotionalBehavior(emo if motor_available else None)
    print("Behavior controller initialized successfully")
except Exception as e:
    print(f"Error initializing behavior controller: {e}")
    behavior = EmotionalBehavior(None)
    print("Falling back to simulation mode")

# Start webcam
cap = cv2.VideoCapture(0)
cap.set(cv2.CAP_PROP_FRAME_WIDTH, 640)
cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 480)

print("Starting webcam. Press 'q' to quit.")

# Enhanced gesture recognition function
def get_gesture(hand_landmarks):
    # Get finger tip and pip positions
    tips = [8, 12, 16, 20]  # Index, middle, ring, pinky tip
    pips = [6, 10, 14, 18]  # Corresponding pip joints
    
    # Check if fingers are open (extended)
    fingers_open = []
    
    # Special case for thumb
    thumb_tip = hand_landmarks.landmark[4]
    thumb_ip = hand_landmarks.landmark[3]
    thumb_open = thumb_tip.x < thumb_ip.x  # For right hand
    fingers_open.append(thumb_open)
    
    # Check other fingers
    for tip, pip in zip(tips, pips):
        # If tip is higher than pip, finger is open
        if hand_landmarks.landmark[tip].y < hand_landmarks.landmark[pip].y:
            fingers_open.append(True)
        else:
            fingers_open.append(False)
            
    # Interpret gestures
    if sum(fingers_open) == 0:
        return "Fist"
    elif fingers_open[1] and not any(fingers_open[0:1] + fingers_open[2:]):
        return "Point"
    elif all(fingers_open):
        return "Open Hand"
    elif fingers_open[0] and fingers_open[1] and not any(fingers_open[2:]):
        return "Peace"
    elif fingers_open[0] and fingers_open[4] and not any(fingers_open[1:4]):
        return "Rock on"
    elif fingers_open[1] and fingers_open[2] and fingers_open[3] and not fingers_open[0] and not fingers_open[4]:
        return "3 Fingers"
    else:
        return "Unknown"

# Enhanced version that analyzes hand movements over time for more nuanced gestures
class GestureAnalyzer:
    def __init__(self):
        self.gesture_history = []
        self.last_positions = []
        self.gesture_start_time = None
        self.current_dynamic_gesture = None
        
    def update(self, hand_landmarks, current_time):
        # Get basic gesture
        static_gesture = get_gesture(hand_landmarks)
        
        # Get hand position (using wrist as reference)
        wrist = hand_landmarks.landmark[0]
        current_pos = (wrist.x, wrist.y, wrist.z)
        
        # Calculate velocity if we have history
        velocity = (0, 0, 0)
        if self.last_positions:
            last_pos = self.last_positions[-1]
            velocity = (
                current_pos[0] - last_pos[0],
                current_pos[1] - last_pos[1],
                current_pos[2] - last_pos[2]
            )
        
        # Update history
        self.gesture_history.append((static_gesture, current_pos, velocity, current_time))
        self.last_positions.append(current_pos)
        
        # Limit history length
        if len(self.gesture_history) > 30:  # 1 second of history at 30fps
            self.gesture_history.pop(0)
            self.last_positions.pop(0)
            
        # Detect dynamic gestures
        dynamic_gesture = self._detect_dynamic_gesture()
        
        return {
            "static": static_gesture,
            "dynamic": dynamic_gesture,
            "velocity": velocity
        }
    
    def _detect_dynamic_gesture(self):
        # Need enough history for dynamic gestures
        if len(self.gesture_history) < 10:
            return None
            
        # Get recent gestures and movements
        recent_gestures = [g[0] for g in self.gesture_history[-10:]]
        
        # Check horizontal wave
        if "Open Hand" in recent_gestures:
            # Get x velocities
            x_velocities = [abs(g[2][0]) for g in self.gesture_history[-10:]]
            y_velocities = [abs(g[2][1]) for g in self.gesture_history[-10:]]
            
            # If consistent horizontal motion with low vertical motion
            if (sum(x_velocities) > 0.5 and 
                sum(y_velocities) < 0.3 and
                max(x_velocities) > 0.05):
                return "Wave"
                
        # Check "come here" gesture
        if "Open Hand" in recent_gestures:
            # Z velocities (towards/away from camera)
            z_velocities = [g[2][2] for g in self.gesture_history[-10:]]
            
            # If pulling motion (negative z values)
            if sum(z_velocities) < -0.3:
                return "Come Here"
                
        # Check "go away" gesture
        if "Open Hand" in recent_gestures:
            # Z velocities (towards/away from camera)
            z_velocities = [g[2][2] for g in self.gesture_history[-10:]]
            
            # If pushing motion (positive z values)
            if sum(z_velocities) > 0.3:
                return "Go Away"
        
        return None

# Function to determine if user is watching the camera (improved)
# Improved function to better detect when someone is looking directly at the robot
def is_user_watching(detection, mesh_results, frame_shape):
    # Using MediaPipe face detection landmarks to determine presence and gaze
    if detection:
        # Get face keypoints
        keypoints = detection.location_data.relative_keypoints
        
        # Get eye positions (indexes 0 and 1 are the right and left eyes)
        right_eye = keypoints[0]
        left_eye = keypoints[1]
        
        # Get nose position (index 2)
        nose = keypoints[2]
        
        # Calculate eye positions
        ih, iw, _ = frame_shape
        right_eye_x, right_eye_y = int(right_eye.x * iw), int(right_eye.y * ih)
        left_eye_x, left_eye_y = int(left_eye.x * iw), int(left_eye.y * ih)
        nose_x, nose_y = int(nose.x * iw), int(nose.y * ih)
        
        # Horizontal symmetry check (if eyes are roughly at same height)
        eye_height_diff = abs(right_eye_y - left_eye_y)
        
        # Calculate face orientation score - higher means more directly facing camera
        # Normalize values by image size
        eye_symmetry_score = 1.0 - (eye_height_diff / (ih * 0.1))
        eye_symmetry_score = max(0, min(1, eye_symmetry_score))
        
        # Check if face is in center part of frame - expanded center region
        # Calculate distance from center with greater tolerance
        center_x, center_y = iw/2, ih/2
        nose_center_distance = ((nose_x - center_x)**2 + (nose_y - center_y)**2)**0.5
        max_distance = ((iw/2)**2 + (ih/2)**2)**0.5
        # More generous center scoring
        center_score = 1.0 - (nose_center_distance / (max_distance * 1.3))  # 30% more tolerant
        center_score = max(0, center_score)
        
        # Use face mesh for more precise gaze detection if available
        precise_gaze_score = 0.6  # Higher default value
        if mesh_results and mesh_results.multi_face_landmarks:
            face_landmarks = mesh_results.multi_face_landmarks[0]
            
            # Get eye landmarks for more precise detection
            left_eye_corner = face_landmarks.landmark[168]
            right_eye_corner = face_landmarks.landmark[398]
            
            # Calculate eye width ratio with more tolerance
            left_x, right_x = left_eye_corner.x, right_eye_corner.x
            eye_width_ratio = abs(right_x - left_x) / 0.15
            
            # Map to 0-1 range with more generous thresholds
            if eye_width_ratio < 0.6:  # Lower threshold
                precise_gaze_score = (eye_width_ratio / 0.6) * 0.8  # Scale to allow detection
            elif eye_width_ratio > 1.4:  # Higher threshold
                precise_gaze_score = 0.8 - ((eye_width_ratio - 1.4) / 0.8) * 0.4
            else:
                precise_gaze_score = 0.8  # Higher score for facing camera
        
        # Combine scores with higher weights for center position
        if mesh_results and mesh_results.multi_face_landmarks:
            final_score = (precise_gaze_score * 0.5) + (center_score * 0.35) + (eye_symmetry_score * 0.15)
        else:
            final_score = (center_score * 0.7) + (eye_symmetry_score * 0.3)
        
        # Lower threshold for "watching" to be more responsive
        return final_score > 0.45  # Lowered from 0.6
    
    return False
def estimate_distance(face_box):
    """
    Estimates the distance to a face based on the bounding box size.
    
    Args:
        face_box: The bounding box from MediaPipe face detection
        
    Returns:
        (float, str): A tuple containing:
            - distance_estimate: A value between 0.0-1.0 where 0.0 is very close and 1.0 is far
            - distance_category: A string label ("Near", "Medium", "Far")
    """
    # Calculate the area of the face box as a percentage of the entire frame
    face_area = face_box.width * face_box.height
    
    # Convert area to distance estimate (inverted, so 0.0 is close and 1.0 is far)
    # We use a non-linear mapping to improve sensitivity at different distances
    if face_area > 0.25:  # Very large face (more than 25% of frame)
        distance_estimate = 0.0
        distance_category = "Very Near"
    elif face_area > 0.1:  # Large face (10-25% of frame)
        # Map 0.1-0.25 to 0.2-0.0 range
        distance_estimate = 0.2 - ((face_area - 0.1) * 0.8)
        distance_category = "Near"
    elif face_area > 0.03:  # Medium face (3-10% of frame)
        # Map 0.03-0.1 to 0.6-0.2 range
        distance_estimate = 0.6 - ((face_area - 0.03) * 5.7)
        distance_category = "Medium"
    elif face_area > 0.005:  # Small face (0.5-3% of frame)
        # Map 0.005-0.03 to 0.9-0.6 range
        distance_estimate = 0.9 - ((face_area - 0.005) * 12)
        distance_category = "Far"
    else:  # Very small face (less than 0.5% of frame)
        distance_estimate = 1.0
        distance_category = "Very Far"
    
    return distance_estimate, distance_category
# Enhanced emotion detection class for more accurate and varied emotions
class EmotionDetector:
    def __init__(self):
        self.emotions = ["Neutral", "Happy", "Surprised", "Sad", "Angry", "Confused", "Interested"]
        self.emotion_timestamps = {emotion: 0 for emotion in self.emotions}
        self.emotion_durations = {emotion: 0 for emotion in self.emotions}
        self.emotion_confidence = {emotion: 0.0 for emotion in self.emotions}
        self.current_emotion = "Neutral"
        self.last_detection = "Neutral"  # Add this line to fix the error
        self.last_detection_time = time.time()
        
        # In a real system, you would integrate with a proper emotion detection model here
        # For this demo, we'll use more sophisticated simulated detection
        
    def detect_emotion(self, face_mesh_results, frame, frame_count):
        """Improved emotion detection with better neutral/sad detection and stability buffer"""
        current_time = time.time()
        
        # Core emotions
        self.emotions = ["Neutral", "Happy", "Surprised", "Sad", "Interested"]
        
        # Reset all confidence values
        for emotion in self.emotions:
            self.emotion_confidence[emotion] = 0.0
        
        # Set a strong baseline for neutral
        self.emotion_confidence["Neutral"] = 0.65  # Increased neutral baseline
        
        # Only try to detect emotions if we have facial landmarks
        if face_mesh_results and face_mesh_results.multi_face_landmarks:
            face_landmarks = face_mesh_results.multi_face_landmarks[0]  # Use first face
            
            # Get frame dimensions
            h, w, _ = frame.shape
            
            # ------ KEY LANDMARKS ------
            
            # Mouth corners
            mouth_left = (int(face_landmarks.landmark[61].x * w), int(face_landmarks.landmark[61].y * h))
            mouth_right = (int(face_landmarks.landmark[291].x * w), int(face_landmarks.landmark[291].y * h))
            
            # Mouth top and bottom
            mouth_top = (int(face_landmarks.landmark[13].x * w), int(face_landmarks.landmark[13].y * h))
            mouth_bottom = (int(face_landmarks.landmark[14].x * w), int(face_landmarks.landmark[14].y * h))
            
            # Eyes
            left_eye_top = (int(face_landmarks.landmark[159].x * w), int(face_landmarks.landmark[159].y * h))
            left_eye_bottom = (int(face_landmarks.landmark[145].x * w), int(face_landmarks.landmark[145].y * h))
            right_eye_top = (int(face_landmarks.landmark[386].x * w), int(face_landmarks.landmark[386].y * h))
            right_eye_bottom = (int(face_landmarks.landmark[374].x * w), int(face_landmarks.landmark[374].y * h))
            
            # Eyebrows
            left_eyebrow = (int(face_landmarks.landmark[105].x * w), int(face_landmarks.landmark[105].y * h))
            right_eyebrow = (int(face_landmarks.landmark[334].x * w), int(face_landmarks.landmark[334].y * h))
            
            # Additional points for mouth curvature
            mouth_center_top = (int(face_landmarks.landmark[13].x * w), int(face_landmarks.landmark[13].y * h))
            mouth_center_bottom = (int(face_landmarks.landmark[14].x * w), int(face_landmarks.landmark[14].y * h))
            
            # ------ MEASUREMENTS ------
            
            # 1. Smile/frown detection - check if mouth corners are higher or lower than mouth center
            mouth_center_y = (mouth_center_top[1] + mouth_center_bottom[1]) / 2
            left_corner_delta = mouth_center_y - mouth_left[1]  # Positive = upturned (happy), Negative = downturned (sad)
            right_corner_delta = mouth_center_y - mouth_right[1]
            mouth_curvature = (left_corner_delta + right_corner_delta) / 2
            
            # 2. Eye openness
            left_eye_height = abs(left_eye_top[1] - left_eye_bottom[1])
            right_eye_height = abs(right_eye_top[1] - right_eye_bottom[1])
            eye_openness = (left_eye_height + right_eye_height) / 2
            
            # 3. Mouth openness
            mouth_openness = abs(mouth_top[1] - mouth_bottom[1])
            
            # 4. Eyebrow height
            left_brow_height = abs(left_eyebrow[1] - left_eye_top[1])
            right_brow_height = abs(right_eyebrow[1] - right_eye_top[1])
            brow_height = (left_brow_height + right_brow_height) / 2
            
            # 5. Mouth flatness (horizontal line) - good indicator of neutral
            mouth_flatness = 1.0 - abs(mouth_curvature) / 5.0  # Higher value = flatter mouth
            
            # ------ EMOTION SCORING ------
            # Happy - requires clear upturned corners
            if mouth_curvature > 2.0:  # Clear smile threshold
                smile_score = mouth_curvature / 10.0
                self.emotion_confidence["Happy"] = min(1.0, smile_score)
            else:
                self.emotion_confidence["Happy"] = 0.0

            # Sad - requires clear downturned corners
            if mouth_curvature < -1.0:  # Frown threshold
                frown_score = abs(mouth_curvature) / 8.0
                self.emotion_confidence["Sad"] = min(1.0, frown_score)
            else:
                # Mild sadness - slightly downturned or flat mouth with lowered brows
                if mouth_curvature < 0 and brow_height < 10:
                    mild_sad = abs(mouth_curvature) / 15.0 + (1.0 - brow_height/15.0) * 0.3
                    self.emotion_confidence["Sad"] = min(0.7, mild_sad)  # Cap mild sadness
                else:
                    self.emotion_confidence["Sad"] = 0.0

            # Surprised - requires raised eyebrows AND wide eyes
            if brow_height > 12 and eye_openness > 10:
                surprise_score = (brow_height / 20) * 0.6 + (eye_openness / 15) * 0.4
                self.emotion_confidence["Surprised"] = min(1.0, surprise_score)
            else:
                self.emotion_confidence["Surprised"] = 0.0

            # Interested - now more selective, requires specific cues
            if brow_height > 8 and brow_height < 12 and eye_openness > 8 and eye_openness < 12:
                # Calculate interest only when mouth is relatively neutral (not smiling/frowning)
                if abs(mouth_curvature) < 2.0:
                    interested_score = (eye_openness / 20) * 0.5 + (brow_height / 25) * 0.5
                    # Apply a stronger threshold
                    if interested_score > 0.4:
                        self.emotion_confidence["Interested"] = min(0.7, interested_score)
                    else:
                        self.emotion_confidence["Interested"] = 0.0
                else:
                    self.emotion_confidence["Interested"] = 0.0
            else:
                self.emotion_confidence["Interested"] = 0.0

            # Neutral - high when mouth is flat, eyes normal, and no strong expressions
            # Enhanced neutral detection based on mouth flatness
            neutral_score = mouth_flatness * 0.7

            # Reduce other emotions if we have high neutrality
            if mouth_flatness > 0.7:  # Very flat mouth suggests neutral
                for emotion in self.emotions:
                    if emotion != "Neutral":
                        self.emotion_confidence[emotion] *= 0.5  # Dampen other emotions

            self.emotion_confidence["Neutral"] = max(0.4, neutral_score)

            # This ensures we don't show interest alongside stronger emotions
            if (self.emotion_confidence["Happy"] > 0.5 or 
                self.emotion_confidence["Surprised"] > 0.5 or 
                self.emotion_confidence["Sad"] > 0.5):
                # Zero out interest when other emotions are strong
                self.emotion_confidence["Interested"] = 0.0
        
        # Add minimal randomness (very small)
        for emotion in self.emotions:
            self.emotion_confidence[emotion] += random.random() * 0.02 - 0.01
            self.emotion_confidence[emotion] = max(0, min(1, self.emotion_confidence[emotion]))
        
        # Buffer to prevent rapid switching - emotion history
        if not hasattr(self, 'emotion_history'):
            self.emotion_history = []
        
        # Get top two emotions
        emotions_sorted = sorted(self.emotion_confidence.items(), key=lambda x: x[1], reverse=True)
        top_emotion, second_emotion = emotions_sorted[0], emotions_sorted[1]
        
        # Add to history buffer (keep last 5 frames)
        self.emotion_history.append(top_emotion[0])
        if len(self.emotion_history) > 5:
            self.emotion_history.pop(0)
        
        # Only change emotion if it's been detected consistently or is very strong
        if top_emotion[1] > 0.75:  # Very confident detection
            selected_emotion = top_emotion[0]
        else:
            # Count occurrences in history
            emotion_counts = {}
            for e in self.emotion_history:
                emotion_counts[e] = emotion_counts.get(e, 0) + 1
            
            # Need at least 3/5 frames to confirm emotion
            most_common = max(emotion_counts.items(), key=lambda x: x[1])
            if most_common[1] >= 3:
                selected_emotion = most_common[0]
            else:
                # Default to neutral when uncertain
                selected_emotion = "Neutral"
        
        self.current_emotion = selected_emotion
        
        # Handle emotion duration for stability
        if self.current_emotion != self.last_detection:
            if self.last_detection != "Neutral":
                self.emotion_timestamps[self.last_detection] = 0
                self.emotion_durations[self.last_detection] = 0
            
            if self.current_emotion != "Neutral":
                self.emotion_timestamps[self.current_emotion] = current_time
        
        if self.current_emotion != "Neutral":
            self.emotion_durations[self.current_emotion] = current_time - self.emotion_timestamps[self.current_emotion]
        
        self.last_detection = self.current_emotion
        self.last_detection_time = current_time
        
        return {
            "dominant": self.current_emotion,
            "confidence": self.emotion_confidence[self.current_emotion],
            "all_emotions": self.emotion_confidence,
            "duration": self.emotion_durations.get(self.current_emotion, 0)
        }
        
    def get_active_emotions(self, threshold=0.4):
        """Return all emotions above the threshold confidence with special rules for Interested"""
        active = []
        
        # First get all emotions above threshold
        for emotion, conf in self.emotion_confidence.items():
            if conf >= threshold:
                # For Interested, use a higher threshold
                if emotion == "Interested":
                    if conf >= 0.55:  # Higher threshold specifically for Interested
                        active.append(emotion)
                else:
                    active.append(emotion)
        
        # If any primary emotion is active, don't show Interested as secondary
        if ("Happy" in active or "Surprised" in active or "Sad" in active) and "Interested" in active:
            active.remove("Interested")
            
        return active

# Initialize gesture analyzers and emotion detector
gesture_analyzer = GestureAnalyzer()
emotion_detector = EmotionDetector()

# Main processing variables
attention_state = "No User"
last_frame_time = time.time()
frame_count = 0

# Enhanced state tracking for more lifelike behavior
last_behavior_time = time.time()
behavior_cooldown = 5.0  # seconds between automatic behaviors
last_attention_seeking_time = 0
attention_seeking_threshold = 30.0  # seconds without attention before seeking it

# Add your new variables here:
person_search_cooldown = 15.0  # Seconds between active searches
last_person_search_time = 0
person_search_mode = False
consecutive_no_detection = 0
face_position_x = None
face_size = None  # To track approximate distance to person
last_person_approach_time = 0
person_approach_cooldown = 8.0  # Seconds between approach actions

following_mode = False
following_start_time = None
follow_check_interval = 0.5  # Check conditions every half second
last_follow_check = 0

while True:
    ret, frame = cap.read()
    if not ret:
        print("Failed to grab frame")
        break
    
    # Calculate FPS
    current_time = time.time()
    elapsed = current_time - last_frame_time
    last_frame_time = current_time
    fps = 1.0 / elapsed if elapsed > 0 else 0
    
    # Flip the frame horizontally for a more natural feel
    frame = cv2.flip(frame, 1)
    
    # Convert to RGB for MediaPipe
    rgb_frame = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
    
    # Process with face detection and face mesh
    face_results = face_detection.process(rgb_frame)
    # Face mesh is more computationally expensive, so only run if a face is detected
    mesh_results = None
    if face_results.detections:
        mesh_results = face_mesh.process(rgb_frame)
    
    # Display base frame with status
    status_bar_height = 40
    status_bar = np.zeros((status_bar_height, frame.shape[1], 3), dtype=np.uint8)
    
    # Process face detection results to determine if user is watching
    user_detected = False
    is_watching = False
    
    if face_results.detections:
        user_detected = True
        main_detection = face_results.detections[0]  # Use first detected face
        is_watching = is_user_watching(main_detection, mesh_results, frame.shape)
        
        # Determine attention state
        if is_watching:
            attention_state = "Watching"
        else:
            attention_state = "Not Watching"
    else:
        attention_state = "No User"
    
    # Set status bar color based on attention state
    if attention_state == "No User":
        status_color = (128, 128, 128)  # Grey
    elif attention_state == "Not Watching":
        status_color = (0, 0, 255)  # Red
    else:  # Watching
        status_color = (0, 255, 0)  # Green
    
    status_bar[:] = status_color
    
    # Detect emotion and update behavior system
    emotion_result = emotion_detector.detect_emotion(mesh_results, frame, frame_count)
    active_emotions = emotion_detector.get_active_emotions()
    
    # Update robot's interaction level based on attention and emotions
    interaction_level = behavior.update_interaction_level(attention_state, active_emotions)
    
    # Add text to status bar with more information
    cv2.putText(status_bar, f"Status: {attention_state} | Emotion: {emotion_result['dominant']} | Engagement: {interaction_level:.1f}", 
               (10, 25), cv2.FONT_HERSHEY_SIMPLEX, 0.6, (255, 255, 255), 2)
    
    # Process face mesh for display
    if mesh_results is not None and mesh_results.multi_face_landmarks:
        for face_landmarks in mesh_results.multi_face_landmarks:
            # Draw face mesh with lighter lines for less cluttered display
            mp_drawing.draw_landmarks(
                frame,
                face_landmarks,
                mp_face_mesh.FACEMESH_CONTOURS,
                landmark_drawing_spec=mp_drawing.DrawingSpec(color=(80, 110, 10), thickness=1, circle_radius=1),
                connection_drawing_spec=mp_drawing.DrawingSpec(color=(80, 256, 121), thickness=1)
            )
            
            # Display emotion information
            h, w, _ = frame.shape
            # Get a point near the forehead for text
            forehead_landmark = face_landmarks.landmark[10]  # Forehead point
            forehead_x = int(forehead_landmark.x * w)
            forehead_y = int(forehead_landmark.y * h) - 30
            
            # Display the dominant emotion and confidence
            cv2.putText(frame, f"{emotion_result['dominant']} ({emotion_result['confidence']:.2f})", 
                      (forehead_x, forehead_y), cv2.FONT_HERSHEY_SIMPLEX, 0.6, (0, 255, 0), 2)
            
            # Display secondary emotions
            secondary_emotions = [e for e, c in emotion_result['all_emotions'].items() 
                               if c > 0.3 and e != emotion_result['dominant']]
            if secondary_emotions:
                text = "Also: " + ", ".join(secondary_emotions)
                cv2.putText(frame, text, (forehead_x, forehead_y + 25), 
                          cv2.FONT_HERSHEY_SIMPLEX, 0.5, (0, 255, 0), 1)
    
    # Process hands for gesture recognition
    hand_results = hands.process(rgb_frame)
    
    if hand_results.multi_hand_landmarks:
        for hand_landmarks in hand_results.multi_hand_landmarks:
            # Draw hand landmarks
            mp_drawing.draw_landmarks(
                frame,
                hand_landmarks,
                mp_hands.HAND_CONNECTIONS,
                mp_drawing_styles.get_default_hand_landmarks_style(),
                mp_drawing_styles.get_default_hand_connections_style()
            )
            
            # Analyze gestures with enhanced detection
            gesture_result = gesture_analyzer.update(hand_landmarks, current_time)
            
            # Display static and dynamic gestures
            h, w, _ = frame.shape
            cx = int(hand_landmarks.landmark[0].x * w)
            cy = int(hand_landmarks.landmark[0].y * h)
            
            # Display static gesture
            cv2.putText(frame, gesture_result["static"], (cx-20, cy-20),
                      cv2.FONT_HERSHEY_SIMPLEX, 0.6, (255, 0, 255), 2)
                      
            # Display dynamic gesture if detected
            if gesture_result["dynamic"]:
                cv2.putText(frame, gesture_result["dynamic"], (cx-20, cy+30),
                          cv2.FONT_HERSHEY_SIMPLEX, 0.6, (255, 0, 255), 2)
                
                # Respond to dynamic gestures
                if gesture_result["dynamic"] == "Wave" and attention_state == "Watching":
                    if current_time - behavior.last_action_time > 3:
                        threading.Thread(target=behavior.execute_action, 
                                       args=("happy", 0.7)).start()
                
                elif gesture_result["dynamic"] == "Come Here" and attention_state == "Watching":
                    if current_time - behavior.last_action_time > 3:
                        threading.Thread(target=behavior.execute_action, 
                                       args=("curious", 0.8)).start()
            
            # Check for "Open Hand" gesture to trigger following mode
            if gesture_result["static"] == "Open Hand" and attention_state == "Watching":
                current_time = time.time()
                
                # Check if we should enter following mode
                if not following_mode:
                    print("Open hand detected - activating following mode")
                    following_mode = True
                    following_start_time = current_time
                    # Flash status as visual indicator that following mode is activated
                    status_bar[:] = (0, 255, 255)  # Yellow flash
                    
                # Reset the timer while hand remains open
                last_follow_check = current_time
    
    # Behavior decision making with person finding
    if attention_state == "Watching":
        # Reset counters and timers when being watched
        consecutive_no_detection = 0
        person_search_mode = False
        last_attention_seeking_time = current_time
        
        # Increase responsiveness to direct watching
        watching_duration = 0
        if hasattr(behavior, 'watching_start_time'):
            watching_duration = current_time - behavior.watching_start_time
        else:
            behavior.watching_start_time = current_time
        
        # Calculate face position and size when face is detected
        if face_results.detections:
            detection = face_results.detections[0]  # Use first detected face
            face_box = detection.location_data.relative_bounding_box
            frame_height, frame_width, _ = frame.shape
            
            # Calculate face center position (0.0-1.0 range)
            face_center_x = face_box.xmin + (face_box.width / 2)
            face_position_x = face_center_x
            
            # Calculate face size as proportion of frame (proxy for distance)
            face_size = face_box.width * face_box.height
            
            # Estimate distance to face
            distance_estimate, distance_category = estimate_distance(face_box)
            
            # Display distance estimation on frame
            dist_text = f"Distance: {distance_category} ({distance_estimate:.2f})"
            cv2.putText(frame, dist_text, (10, frame_height - 50), 
                      cv2.FONT_HERSHEY_SIMPLEX, 0.6, (0, 255, 255), 2)
            
            # Only approach if not in following mode
            if not following_mode:
                # Decide if we should approach the person (not too close already and cooldown passed)
                if (distance_estimate > 0.3 and  # Not too close
                    current_time - last_person_approach_time > person_approach_cooldown):
                    
                    # Only approach when person is centered
                    if 0.25 < face_position_x < 0.75:
                        print(f"Person detected, approaching (distance: {distance_category}, factor: {distance_estimate:.2f})")
                        threading.Thread(target=behavior.approach_person, 
                                      args=(distance_estimate,)).start()
                        last_person_approach_time = current_time
                
                # If person is off-center, rotate to center them
                elif (current_time - behavior.last_action_time > 3 and
                      (face_position_x < 0.25 or face_position_x > 0.75)):
                    
                    if face_position_x < 0.25:  # Person is to the left
                        if behavior.motor_available:
                            behavior.motor.left()
                            time.sleep(0.2)
                            behavior.motor.stop()
                        else:
                            print("SIMULATED: Turning left to center person")
                    else:  # Person is to the right
                        if behavior.motor_available:
                            behavior.motor.right()
                            time.sleep(0.2)
                            behavior.motor.stop()
                        else:
                            print("SIMULATED: Turning right to center person")
                    
                    behavior.last_action_time = current_time
        
        # Only run emotional responses if not in following mode
        if not following_mode:
            # React immediately when someone starts watching (first 2 seconds)
            if watching_duration < 2 and current_time - behavior.last_action_time > 2:
                print("User just started watching - immediate greeting")
                intensity = min(0.7, 0.4 + (interaction_level / 20))
                threading.Thread(target=behavior.execute_action, 
                              args=("happy", intensity)).start()
            
            # Periodic engagement while being watched
            elif watching_duration > 5 and current_time - behavior.last_action_time > 7:
                # Choose an action based on detected emotion and personality
                if "Happy" in active_emotions:
                    print("Responding to happy user with happy action")
                    threading.Thread(target=behavior.execute_action, 
                                  args=("happy", min(0.9, emotion_result["confidence"]))).start()
                elif "Surprised" in active_emotions:
                    print("Responding to surprised user")
                    threading.Thread(target=behavior.execute_action, 
                                  args=("surprised", min(0.8, emotion_result["confidence"]))).start()
                else:
                    # Random curious actions while being watched
                    if random.random() < 0.3:  # 30% chance for a subtle movement
                        print("Curious response to watching user")
                        threading.Thread(target=behavior.execute_action, 
                                      args=("curious", 0.5)).start()
                    
            # React to strong emotions (kept from original)
            elif emotion_result["dominant"] == "Happy" and emotion_result["confidence"] > 0.6:
                if current_time - behavior.last_action_time > 5:
                    threading.Thread(target=behavior.execute_action, 
                                  args=("happy", emotion_result["confidence"])).start()
                    
            elif emotion_result["dominant"] == "Surprised" and emotion_result["confidence"] > 0.7:
                if current_time - behavior.last_action_time > 5:
                    threading.Thread(target=behavior.execute_action, 
                                  args=("surprised", emotion_result["confidence"])).start()

    elif attention_state == "Not Watching":
        # Reset watching timer when no longer watching
        if hasattr(behavior, 'watching_start_time'):
            delattr(behavior, 'watching_start_time')
        
        # Exit following mode if active
        if following_mode:
            print("Exiting following mode - user not watching")
            following_mode = False
        
        # If we detect a face but they're not watching,
        # this means someone is present but not engaging
        if face_results.detections:
            consecutive_no_detection = 0
            
            # Occasionally try to regain attention
            if (current_time - last_attention_seeking_time > attention_seeking_threshold and
                current_time - behavior.last_action_time > behavior_cooldown):
                threading.Thread(target=behavior.execute_action, 
                              args=("seek_attention", 0.5)).start()
                last_attention_seeking_time = current_time
        else:
            # No face detected despite being in "not watching" state
            # This can happen if the face moved out of frame
            consecutive_no_detection += 1
            
            # After a few frames with no detection, switch to search mode
            if consecutive_no_detection > 15:  # About half a second at 30fps
                person_search_mode = True

    else:  # No User state
        # Reset watching timer when no user
        if hasattr(behavior, 'watching_start_time'):
            delattr(behavior, 'watching_start_time')
            
        # Exit following mode if active
        if following_mode:
            print("Exiting following mode - no user detected")
            following_mode = False
        
        # Increment the no-detection counter
        consecutive_no_detection += 1
        
        # After continuous no detection, enter search mode
        if consecutive_no_detection > 30:  # About 1 second at 30fps
            person_search_mode = True
        
        # Execute idle behaviors
        behavior.execute_action("idle")

    # Person search mode activation
    if person_search_mode and not following_mode:  # Don't search if following
        # Check if search cooldown has elapsed
        if current_time - last_person_search_time > person_search_cooldown:
            print("No person detected for a while, starting search pattern")
            threading.Thread(target=behavior._find_person_action, 
                          args=(0.7,)).start()
            last_person_search_time = current_time
            person_search_mode = False  # Reset search mode after initiating search

    # Execute following behavior if in following mode
    if following_mode:
        # Update the status bar to show following mode is active
        cv2.putText(frame, "FOLLOWING MODE", (frame.shape[1] - 200, 30), 
                  cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 255, 255), 2)
                  
        # Check if it's time to verify conditions still hold
        if current_time - last_follow_check > follow_check_interval:
            # If hand isn't open anymore or user not watching, exit following mode
            if not (hand_results.multi_hand_landmarks and 
                    attention_state == "Watching"):
                print("Exiting following mode - hand gesture changed or user not watching")
                following_mode = False
            last_follow_check = current_time
        
        # Only execute following behavior if face is detected
        if face_results.detections:
            detection = face_results.detections[0]
            face_box = detection.location_data.relative_bounding_box
            
            # Update face position variables
            face_center_x = face_box.xmin + (face_box.width / 2)
            face_position_x = face_center_x
            
            # Estimate distance
            distance_estimate, _ = estimate_distance(face_box)
            
            # Log the current following state occasionally
            if frame_count % 30 == 0:  # Log once per second at 30fps
                print(f"Following mode active - distance: {distance_estimate:.2f}, position: {face_position_x:.2f}")
            
            # First, rotate to center the person if needed
            if face_position_x < 0.3:  # Person is too far left
                if behavior.motor_available:
                    behavior.motor.left()
                    time.sleep(0.2)
                    behavior.motor.stop()
                else:
                    print("SIMULATED: Turning left to center person while following")
            elif face_position_x > 0.7:  # Person is too far right
                if behavior.motor_available:
                    behavior.motor.right()
                    time.sleep(0.2)
                    behavior.motor.stop()
                else:
                    print("SIMULATED: Turning right to center person while following")
            # Then move forward if person is centered and not too close
            elif 0.3 <= face_position_x <= 0.7 and distance_estimate > 0.25:
                # Execute follow action with intensity based on distance
                # Closer = slower, farther = faster
                follow_intensity = min(0.9, distance_estimate * 1.2)
                threading.Thread(target=behavior.execute_action, 
                              args=("follow_user", follow_intensity)).start()

    # Combine status bar and frame
    display_frame = np.vstack([status_bar, frame])

    # Display the resulting frame
    cv2.imshow('Emotion-Controlled Robot', display_frame)

    # Increment frame count
    frame_count += 1

    # Break on 'q' key press
    if cv2.waitKey(1) & 0xFF == ord('q'):
        break