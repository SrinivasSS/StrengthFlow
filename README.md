# StrengthFlow

A full-featured strength and cardio workout tracker for Garmin watches. Tracks reps (with accelerometer-based auto-counting), sets, rest periods, heart rate, calories, distance, and floors -- all recorded as native FIT activities that sync to Garmin Connect.

## Features

### Workout Tracking
- **Auto rep counting** -- accelerometer-based detection with adaptive per-exercise learning
- **Auto set/rest detection** -- learns from your manual transitions, then auto-detects movement vs. stillness
- **Manual rep adjustment** -- UP button to add, or toggle auto-detect off for full manual control
- **Rest timer** -- automatic timing between sets with vibration alerts
- **Set history** -- tracks reps and duration per set across the entire workout

### Cardio Mode
- **Distance tracking** (miles) for treadmill, elliptical, rowing, cycling
- **Floor counting** for Stairmaster (via barometric altimeter)
- **Correct FIT sport types** -- Treadmill Run, Elliptical, Stair Climbing each get their native sport/sub-sport

### Progress Tracking
- **Total volume** -- weight x reps accumulated across the whole session
- **Personal Records** -- best weight per exercise saved long-term; a new PR triggers a celebration vibration and shows on the rest screen
- **Last-session recall** -- previous weight & reps for the current exercise, shown on the ready and stats screens
- **Stats screen** -- press DOWN mid-workout for LAST TIME / PERSONAL BEST / VOLUME TODAY
- **Per-set weight** -- log weight via the pause menu; supports kg or lb (toggle in settings)

### On-Watch History
- **Workout history** -- the last 30 strength workouts are saved on the watch (date, exercises, sets, reps, weight, volume) and browsable from the main menu -- no phone required
- **Full per-set breakdown** -- open any past workout to see every set with its exercise name, reps, and weight
- **Edit past workouts** -- change a set's exercise, reps, or weight (recomputes volume), delete individual sets, delete a whole workout, or clear all history
- **Storage guardrails** -- a ring buffer keeps the most recent workouts; under storage pressure the oldest are dropped first so the current workout is always preserved whole

### Health Metrics
- **Real-time heart rate** with zone-based color coding (5 zones from Garmin user profile)
- **Calories** from native Activity API
- **Average and peak HR** tracked throughout workout

### Exercise Library (100+ exercises)
- **Chest + Triceps** -- Bench Press, Incline Press, Chest Fly, Tricep Dip, Tricep Extension, Skull Crusher, and more
- **Back + Biceps** -- Deadlift, Barbell Row, Pull Up, Lat Pulldown, Seated Row, Curls, and more
- **Shoulders + Arms** -- Overhead Press, Lateral Raise, Front Raise, Face Pull, Wrist Curl, and more
- **Legs** -- Squat, Leg Press, Lunges, Leg Curl, Leg Extension, Romanian Deadlift, Hip Thrust, and more
- **Abs** -- Crunch, Plank, Hanging Leg Raise, Cable Crunch, Ab Rollout, Russian Twist, and more
- **Cardio** -- Treadmill Run, Elliptical, Stairmaster, HIIT, Jump Rope, Rowing Machine, Cycling, Battle Ropes, and more
- **Isolations** -- Per-muscle targeting (Chest, Back, Shoulders, Triceps, Biceps, Forearms, Quads, Hamstrings, Glutes, Calves)
- **Free Workout** -- No exercise preset, just track

### Smart UX
- **Recent exercises first** -- your most-used exercises appear at the top of each group
- **Recent groups** -- last 3 used groups shown at top of main menu
- **Custom groups** -- define up to 3 custom exercise groups via Garmin Connect Mobile settings
- **Save & Switch** -- save current workout and immediately pick a new exercise without leaving the session flow
- **Workout summary** -- per-exercise volume bars, per-set detail, scrollable

### Activity Recording
- Saves as native FIT file to Garmin Connect
- Strength Training with lap markers per set
- Cardio activities with correct sport classification
- Orphan session detection and cleanup (handles previous crash leftovers)

### Haptic Feedback
- Workout start vibration
- Rep detection tick
- Set end double-pulse
- Set start double-pulse
- Workout complete triple-pulse

## Screenshots

Screenshots are in the `build/` folder:

| File | Description |
|------|-------------|
| `build/screenshot_1_menu.png` | Group/exercise picker menu |
| `build/screenshot_2_set.png` | Active set view (reps, HR, calories, elapsed) |
| `build/screenshot_3_rest.png` | Rest timer between sets |
| `build/screenshot_4_summary.png` | Workout complete summary |
| `build/screenshot_5_pause.png` | Pause menu with options |
| `build/screenshot_7_stats.png` | Stats screen (last time, PR, volume today) |
| `build/screenshot_8_rest_pr.png` | Rest screen showing personal record |
| `build/hero_1440x720.png` | Connect IQ store hero banner |
| `build/icon_256.png` | App icon (256px) |
| `build/icon_512.png` | App icon (512px) |

## Building

### Prerequisites

- [Connect IQ SDK](https://developer.garmin.com/connect-iq/sdk/) (4.x or later)
- A device file for your target (included in SDK)

### Build Commands

```bash
# Build for Epix Pro 47mm (default development target)
monkeyc -d epix2pro47mm -f monkey.jungle -o build/StrengthFlow.prg -y /path/to/developer_key.der

# Build release package for Connect IQ Store
monkeyc -e -f monkey.jungle -o build/StrengthFlow.iq -y /path/to/developer_key.der -r

# Build with type checking (recommended during development)
monkeyc -d epix2pro47mm -f monkey.jungle -o build/StrengthFlow.prg -y /path/to/developer_key.der -l 3
```

### Simulator

```bash
# Launch in Connect IQ simulator
connectiq &
monkeydo build/StrengthFlow.prg epix2pro47mm
```

## Installation

### Side-load via USB

1. Build the `.prg` file for your specific device
2. Connect your watch via USB
3. Copy the `.prg` to `GARMIN/APPS/` on the watch
4. Disconnect and the app appears in your activity list

### Connect IQ Store

1. Build the `.iq` package (release build)
2. Upload to [developer.garmin.com](https://developer.garmin.com) app management
3. Users install via Garmin Connect Mobile or the Connect IQ store on the watch

## Supported Devices (64 products)

### Epix
epix2, epix2pro42mm, epix2pro47mm, epix2pro51mm

### Fenix
fenix7, fenix7s, fenix7x, fenix7pro, fenix7spro, fenix7xpro, fenix7pronowifi, fenix7xpronowifi, fenix843mm, fenix847mm, fenix8pro47mm, fenix8solar47mm, fenix8solar51mm, fenixe

### Forerunner
fr165, fr165m, fr255, fr255m, fr255s, fr255sm, fr265, fr265s, fr55, fr57042mm, fr57047mm, fr745, fr945, fr945lte, fr955, fr965, fr970

### Tactix / MARQ / D2
d2mach1, d2mach2, d2mach2pro, marq2, marq2aviator

### Venu
venu, venu2, venu2plus, venu2s, venu3, venu3s, venu441mm, venu445mm, venusq2, venusq2m

### Vivoactive
vivoactive4, vivoactive4s, vivoactive5, vivoactive6

### Instinct
instinct2, instinct2s, instinct2x, instinct3amoled45mm, instinct3amoled50mm, instinct3solar45mm, instinctcrossover, instinctcrossoveramoled

### Enduro
enduro, enduro3

## Controls / Button Mapping

### During Active Set
| Button | Action |
|--------|--------|
| START/STOP | Pause workout (opens pause menu) |
| BACK/LAP | End set, start rest |
| DOWN | End set, start rest |
| UP | Add rep (+1) |
| MENU (long press) | Toggle auto-detect on/off |

### During Rest
| Button | Action |
|--------|--------|
| START/STOP | Pause workout |
| BACK/LAP | Start next set |
| DOWN | Start next set |

### Pause Menu
| Option | Action |
|--------|--------|
| Resume | Continue workout where you left off |
| Save & Switch | Save this workout, pick new exercise |
| Auto-Detect: ON/OFF | Toggle accelerometer-based rep/set detection |
| Save | End and save workout to Garmin Connect |
| Discard | Delete workout without saving |

### Summary View
| Button | Action |
|--------|--------|
| START or BACK | Dismiss summary |
| UP/DOWN | Scroll through set details |

## Settings

Configured via **Garmin Connect Mobile** app (under the StrengthFlow app settings):

| Setting | Description |
|---------|-------------|
| Custom Group 1 Name | Name for your first custom exercise group |
| Custom Group 1 Exercises | Comma-separated list of exercise names |
| Custom Group 2 Name | Name for your second custom group |
| Custom Group 2 Exercises | Comma-separated exercises |
| Custom Group 3 Name | Name for your third custom group |
| Custom Group 3 Exercises | Comma-separated exercises |

Example: Set name to "Push Day" and exercises to "Bench Press, Overhead Press, Tricep Dip, Lateral Raise"

## Architecture

```
source/
  StrengthTrackerApp.mc    -- App entry point, launches ExercisePickerView
  ExercisePickerView.mc    -- Group menu, exercise menu, recent/custom group logic,
                              ExerciseHistory (storage), CustomGroups (settings parser)
  WorkoutView.mc           -- Main workout UI: ready/active/rest states, draws all metrics,
                              manages timer, orchestrates RepDetector + HealthMonitor + Recorder
  WorkoutDelegate.mc       -- Button handling during workout, PauseMenuDelegate for pause menu
  RepDetector.mc           -- Accelerometer processing: rep counting (learning + counting modes),
                              auto set/rest detection, threshold persistence per exercise
  HealthMonitor.mc         -- HR, calories, distance, floors, HR zone calculation from Activity API
  WorkoutRecorder.mc       -- FIT session management: create, start, lap, save, discard,
                              orphan detection, sport type selection
  SummaryView.mc           -- Post-workout summary: exercise breakdown bars, per-set detail,
                              scrollable, SummaryDelegate handles dismiss + optional restart
  DebugView.mc             -- Live sensor debug overlay: deviation, thresholds, sample log
```

### Key Data Flow

1. **ExercisePickerView** -- user picks group then exercise
2. **launchWorkout()** -- pushes WorkoutView + WorkoutDelegate
3. **WorkoutView.startWorkout()** -- starts HealthMonitor, WorkoutRecorder, RepDetector, timer
4. **RepDetector** -- reads accelerometer at 25Hz (batch) or 10Hz (poll fallback), detects reps and set/rest transitions
5. **WorkoutView.endWorkout()** -- saves FIT, pushes SummaryView
6. **SummaryDelegate.dismiss()** -- pops back; if restartAfter=true, shows group menu again

### Permissions Required
- **Fit** -- read activity data (HR, calories, distance)
- **FitContributor** -- write custom fields to FIT files
- **Sensor** -- accelerometer access for rep detection
- **SensorHistory** -- historical sensor data
- **UserProfile** -- HR zone boundaries
