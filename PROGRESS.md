# StrengthFlow -- Development Progress

## What Has Been Built

### v2.3.0 (Current)
Adds on-watch workout history:
- **`WorkoutHistory`** (`source/WorkoutHistory.mc`) -- persists finished strength workouts to `Application.Storage`. Layout avoids the ~8KB-per-value cap: `wh_index` holds an array of ids, each `wh_<id>` holds one workout. Ring buffer keeps `MAX_WORKOUTS=30`.
- **Storage guardrails** -- eviction-first policy: the current workout is always saved whole; older workouts are dropped to free space (count cap + evict-on-write-failure retry loop). A last-resort `MAX_SETS=120` clamp only trips for a pathological single workout; exercise names trimmed to 24 chars.
- **History UI** (`source/HistoryView.mc`) -- `HistoryMenu` (list, newest first) -> `WorkoutDetailView` (scrollable per-set breakdown) -> edit menu -> per-set menu (edit Exercise/Reps/Weight via pickers, or Delete Set) plus Delete Whole Workout and Clear All (with confirmation).
- **Menu entry** -- "History" added to the main group menu; saved in `endWorkout` for non-cardio workouts.
- Multi-level menu nav uses sequential `popView` (proven safe pattern, same as QuickSwitch); value pickers pop 3x back to the detail view which reloads from storage.

#### KEY FINDING: exercise names in Garmin Connect are impossible from a watch app
Extensively researched (6 agents, Garmin official docs + FIT SDK source + forums). Confirmed conclusively:
- Garmin's native strength "Sets" view is driven by the FIT `set` message (global msg **225**), which holds exercise category/name, reps, weight. It is writable ONLY by the full FIT SDK (C/Java/Python/etc.) off-watch -- NEVER by Connect IQ.
- Connect IQ `ActivityRecording.Session` has 8 methods, none write sets. `FitContributor` is limited to SESSION(18)/LAP(19)/RECORD(20). No `addSet()` exists; Garmin has declined the request for ~9 years and closed the cloud set-write API to third parties in 2025.
- We DO write `exercise`/`reps`/`weight` as FitContributor LAP developer fields (confirmed present via decoding an exported FIT). But Garmin Connect does NOT render lap developer fields for strength activities (Sets view has no lap table). **Tested Option B** (record as generic/running to force a laps table): even from a store install with a guaranteed splits table, the columns did NOT show on the phone. Option B is dead.
- The ONLY way to get native exercise names into Connect is Rack's method: a companion phone app builds a full FIT with `set` messages and pushes it over the CIQ BLE channel. That's a separate multi-platform project, deferred.
- **Conclusion:** on-watch history (this release) is the reliable, in-our-control answer for reviewing exercise names. FIT export also contains them for external tools.

### v2.2.2
Everything in v2.0.0 plus the "progress tracking" release:
- **Total volume tracking** -- weight x reps accumulated across the whole session, shown in the summary and on the stats screen (`WorkoutView._totalVolume`)
- **Personal Record (PR) tracking** -- best weight per exercise saved long-term in `Application.Storage` (`PRTracker`, key `"prs"`); a PR triggers a distinct vibration and is displayed on the rest screen
- **Last-session recall** -- previous weight & reps per exercise (`LastSession`, key `"last_session"`) shown on the ready screen and stats screen
- **Stats screen** (`StatsView`) -- press DOWN during a workout to see LAST TIME / PERSONAL BEST / VOLUME TODAY for the current exercise. BACK from this screen also toggles set/rest so navigation is consistent with the main screen
- **Optional rest timer** -- configurable target rest with a vibration alert when it expires (settings: `restTimerEnabled`, `restTimerSeconds`)
- **kg / lb unit toggle** -- setting `useKg`; weight picker increments and all displays adapt (`WorkoutView.weightUnit()` / `useKg()`)
- **Per-set weight input** -- weight logged via the pause menu weight picker, shown next to the exercise name

### v2.0.0
A fully functional strength and cardio workout tracker that:
- Counts reps automatically via accelerometer with per-exercise adaptive learning
- Detects set/rest transitions automatically after learning from manual usage
- Records native FIT activities (Strength Training, Treadmill Run, Elliptical, Stair Climbing)
- Shows real-time HR with zone colors, calories, elapsed time, total time
- Supports 100+ exercises across 7 muscle groups plus cardio and isolations
- Allows mid-workout exercise switching via "Save & Switch" (cardio) and quick-switch (strength)
- Persists recent exercises and groups for quick access
- Supports up to 3 custom exercise groups configured via Garmin Connect Mobile
- Works across 94 Garmin devices (Epix, Fenix, Forerunner, Venu, Vivoactive, Instinct, Enduro, MARQ, D2)

### v1.0.0 (Initial Scaffold)
Basic structure with single-exercise tracking.

---

## The Rep Detection Journey

### What Was Tried

**Attempt 1: Simple threshold on raw magnitude**
- Read `Sensor.getInfo().accel` which returns milli-g values (x, y, z)
- Magnitude at rest is approximately 1000 (1g gravity)
- Tried a fixed threshold on magnitude deviation -- too noisy, false positives everywhere

**Attempt 2: Variance-based detection**
- Computed local variance over sliding window
- Problem: variance catches any movement (arm adjustments, repositioning), not rep-shaped signals

**Attempt 3: Smoothed signal + global mean deviation (current working approach)**
- Exponential smoothing: `smoothedMag = smoothedMag * 0.8 + mag * 0.2`
- Deviation from frozen global mean used as the signal
- Peak-then-valley detection: a rep = peak above threshold followed by return below return threshold
- **Learning mode**: first manual set observes peaks to calibrate thresholds
- **Counting mode**: uses learned thresholds with peak-valley-peak pattern

### What the Real Watch Data Showed

From actual Epix Pro Gen 2 on-wrist testing:
- **Rest deviation**: 10-20 (arm on lap, sitting between sets)
- **Active set deviation**: 150+ during movement
- **Observed peaks**: 86-173 range (varies by exercise)
- **Observed valleys**: 18-25 (brief return between reps)

### How Learned Thresholds Work

- `peakThreshold = 50% of average observed peak` (floor at 30)
- `returnThreshold = 70% of peakThreshold`
- Thresholds are persisted per exercise in `Application.Storage` with key `"rep_" + exerciseName`
- On subsequent workouts, stored thresholds are loaded and learning is skipped
- If no stored data, enters learning mode for the first set

### Sensor API Details

- `Sensor.registerSensorDataListener` (batch mode, 25Hz) is tried first -- gives higher-quality data
- Falls back to `Sensor.getInfo()` polling at 100ms (10Hz) for devices that don't support batch
- If batch mode works, polling timer is stopped to avoid double-counting
- Accelerometer values are in milli-g: at rest, magnitude ~1000

---

## UI Iteration History

### The Round Display Positioning Problem

**What broke:**
- Percentage-based positioning (`cy * 0.3`, etc.) produced inconsistent results because `cy` is screen center, not a meaningful anchor
- Using `cy - offset` and `cy + offset` for vertical distribution caused text to clip into the curved bezel on 454px round displays
- Elements that looked fine in the simulator were cut off on the physical Epix Pro

**What was tried and failed:**
- `cy`-relative calculations for all zones -- elements clustered too close together or overflowed
- Dynamic font sizing based on screen height -- Connect IQ font constants don't scale, and the set of available fonts is fixed

**What works (current approach):**
- **Hardcoded pixel positions** tuned for 454px Epix Pro display
- 5-zone vertical layout: top (45-75), upper (108-133), center (155-265), lower (288-313), bottom (345-350)
- This isn't perfect for smaller displays but readable on all AMOLED round watches in the 416-454px range

### Font Learnings

- `FONT_NUMBER_THAI_HOT` -- too big, clips on round displays, looks comical for rep count
- `FONT_NUMBER_HOT` -- works well for the main rep/distance number (center zone)
- `FONT_NUMBER_MEDIUM` -- used for rest timer (slightly smaller, fits with surrounding text)
- `FONT_XTINY` -- used for labels and secondary data (HR, CAL, ELAPSED, etc.)
- `FONT_SMALL` -- used for set/rest state header and exercise name
- `FONT_MEDIUM` -- used for exercise name on ready screen

### Visual Design

- Green accent bar at top during active set, blue during rest
- Hexagonal borders around data fields (HR, CAL, ELAPSED, TOTAL, SETS)
- Clock time at bottom with "AUTO" indicator when auto-detect is enabled
- Color coding: green for active/reps, blue for rest, orange for calories, zone-colored HR

---

## ActivityRecording / FIT Challenges

### Session Crashes

**Problem**: App crashes during development left orphaned recording sessions. On next launch, `ActivityRecording.createSession()` would return the orphaned session (still in "recording" state) instead of creating a new one.

**Symptoms**: Calling `.start()` on what you think is a fresh session would throw an exception because it was already recording.

**Solution (current code)**:
```
_session = ActivityRecording.createSession({...});
if (_session.isRecording()) {
    // Orphan found -- discard it
    _session.stop();
    _session.discard();
    _session = null;
    // Create a genuinely new session
    _session = ActivityRecording.createSession({...});
}
_session.start();
```

### FitContributor DATA_TYPE_STRING Crash

**Problem**: Attempted to use `FitContributor` to write exercise names as string fields into the FIT file. `createField()` with `DATA_TYPE_STRING` caused an immediate crash on the device.

**Root cause**: Connect IQ's FitContributor does not reliably support string data types. The documentation implies it works but in practice it crashes on most devices.

**Resolution**: Removed all FitContributor string field usage. Exercise names are not stored in the FIT file -- the app just records laps (one per set) with the native Strength Training sport type. Exercise detail lives only in the on-watch summary view.

### Orphan Session Details

- `createSession()` is not a pure constructor -- it can return an existing session from a previous crash
- You cannot distinguish "new session" from "orphaned session" by any property except `isRecording()`
- Always check `isRecording()` immediately after `createSession()` before calling `.start()`
- After discarding an orphan, the next `createSession()` call returns a genuinely fresh session

---

## The Exercise Switching Saga

### The Problem

Users want to switch from one exercise to another mid-workout (e.g., finish bench press, move to tricep dips) without losing the current workout data.

### What Was Tried and Failed

**Attempt 1: `WatchUi.switchToView()` from PauseMenuDelegate**
- Called `switchToView(new WorkoutView(...), new WorkoutDelegate(...), SLIDE_LEFT)` directly from `Menu2InputDelegate.onSelect()`
- **Crash**: `switchToView` is not allowed from within a `Menu2InputDelegate` callback. The view stack is in an inconsistent state during menu processing.

**Attempt 2: `popView` then `pushView` chain from PauseMenuDelegate**
- Called `popView` (to close menu), then immediately `popView` (to close old WorkoutView), then `pushView` (new WorkoutView)
- **Crash**: Multiple `popView` calls in sequence from a menu delegate cause a stack corruption. The first `popView` closes the menu, but the delegate context is now invalid for the second call.

**Attempt 3: Timer-delayed view switch**
- Set a flag, `popView` the menu, then in the next timer tick do the switch
- **Problem**: Race conditions, sometimes the timer fires before the menu is fully dismissed, causing the same crash.

### The Working Approach (Current)

**Save & Switch uses the same `endWorkout` path as normal Save, with a flag:**

1. PauseMenuDelegate calls `popView` (closes menu) then `_view.endWorkout(true)` -- the `true` means "restart after"
2. `endWorkout` saves the recording, pushes SummaryView with `restartAfter=true`
3. SummaryDelegate checks `_restartAfter` on dismiss:
   - If false: just `popView` (returns to exercise picker underneath)
   - If true: `popView` then calls `ExercisePickerView.showGroupMenu()` which pushes the group menu

This works because:
- Only one `popView` per callback
- The actual navigation to the new exercise happens from SummaryDelegate (a BehaviorDelegate, not Menu2InputDelegate)
- The view stack stays consistent at every step

---

## Auto Set/Rest Detection

### How It Works

1. **Learning phase**: User manually ends sets and starts sets (via BACK/DOWN buttons)
2. On each manual transition, the current average variance is recorded as either "rest level" or "active level"
3. After 2 manual transitions (one set-end + one set-start), auto-detection enables
4. **Detection**: variance below 25% of the rest-to-active range = rest; above 75% = active

### Tuning Parameters
- **80 frames of stillness** required before triggering auto-rest (prevents false rest during brief pauses)
- **25 frames of movement** required before triggering auto-set start (prevents false starts from arm repositioning)
- **15-second cooldown** after any transition (prevents oscillation between states)
- Decay: if variance is in the middle zone, still/move counters decay slowly (prevents accumulation from noise)

### What It Cannot Do Yet
- Cannot detect rest if you're actively walking between stations (movement masks the transition)
- First workout for any exercise always requires manual transitions until learning completes
- Thresholds for set/rest detection are NOT persisted (only rep thresholds are) -- each workout re-learns

---

## Known Issues and Bugs

### Active Issues
1. **UI hardcoded for 454px** -- smaller displays (390px Venu, 360px Vivoactive) may have clipped or overlapping text
2. **Auto set/rest thresholds not persisted** -- must re-learn every workout
3. **Cardio exercises don't get auto-rest** -- auto-detect is disabled for cardio mode entirely
4. **FitContributor not used** -- exercise names and rep counts are not embedded in the FIT file, only laps
5. **item.getSubLabel() unavailable** -- Menu2 MenuItem's `getSubLabel()` was attempted for dynamic menu updating but is not available in the Monkey C API, caused compile errors

### Resolved (v2.2.2)
1. **Weight tracking** -- weight is now logged per set via the pause-menu picker (preset increments, kg/lb aware). Powers volume + PR tracking.
2. **UI redesign** -- moved from hex-bordered layout to a grid layout with an HR-zone arc across the top half, hero cell, 2x2 data grid, and clock at the bottom
3. **Weight showed "Not set" after selecting** -- fixed by passing the source MenuItem into `WeightPickerDelegate` and calling `setSubLabel`
4. **Stats screen BACK inconsistency** -- BACK on the stats screen now closes it AND toggles set/rest, matching the main screen

### Resolved Crashes
1. **switchToView from Menu2InputDelegate** -- resolved by using Save path + SummaryDelegate restart
2. **Multiple popView calls** -- resolved by single-popView-per-callback discipline
3. **FitContributor DATA_TYPE_STRING** -- resolved by removing all string field usage
4. **Orphaned ActivityRecording sessions** -- resolved by isRecording() check on createSession()
5. **RepDetector start before workout started** -- wrapped in try/catch, only starts when workout begins

---

## What Is Working Well

- Rep detection with learning is surprisingly accurate after the first manual set
- Haptic feedback pattern is distinctive without being annoying
- Recent-exercise sorting makes repeated workouts fast to start
- Save & Switch flow feels natural for superset/circuit training
- Orphan detection handles crash recovery gracefully
- Heart rate zone coloring gives good at-a-glance intensity feedback
- FIT recording creates a proper activity in Garmin Connect with correct duration

---

## What Needs Fixing Next

1. **Responsive UI** -- detect screen size and adjust pixel positions / font choices
2. **Persist auto set/rest thresholds** -- store rest/active variance per exercise like rep thresholds
3. **Rep count in FIT** -- investigate FitContributor numeric fields (DATA_TYPE_UINT16) for rep count per lap
4. **Better cardio metrics** -- pace, speed, steps/min for treadmill
5. **Workout templates** -- save a sequence of exercises as a "routine" to follow
6. **Plate calculator** -- given a target weight + bar, show which plates to load (no CIQ competitor has this)

---

## Future Feature Ideas

- **Superset mode** -- pair two exercises, alternate between them with shared rest
- **Timer-based sets** -- for planks, wall sits, farmer walks (count seconds, not reps)
- **Workout history** -- view past workouts on-watch (not just in Garmin Connect)
- **1RM estimate** -- Epley/Brzycki estimate from weight x reps, tracked over time
- **Warm-up set calculator** -- suggest warm-up sets ramping to the working weight
- **Body weight input** -- for calorie accuracy and relative strength tracking
- **Rep tempo tracking** -- detect eccentric/concentric phase timing
- **Voice/audio cues** -- if headphones connected, announce rep count
- **Connect IQ data fields** -- expose live set/rep data as a data field for custom watch faces
- **Multi-set auto-counting** -- after learning, auto-count reps from set 2 onward without manual first set

---

## Technical Notes for Anyone Picking This Up

### Monkey C Gotchas
- `Array.slice(1, null)` is how you drop the first element -- there's no `shift()` or `removeAt()`
- `instanceof` checks must be used before casting (e.g., `if (stored instanceof Array)`) or you get runtime type errors
- `has` operator checks for module/method existence (e.g., `Attention has :vibrate`) -- required for device compatibility
- String comparison must use `.equals()`, not `==` (which compares references)
- No ternary operator -- use if/else
- Function references use `method(:functionName)` syntax

### View Stack Rules
- Never call `switchToView` from a `Menu2InputDelegate` -- it crashes
- Never call multiple `popView` in the same callback
- `pushView` from a `Menu2InputDelegate.onSelect()` is safe (e.g., pushing a sub-menu or DebugView)
- `popView` + one other navigation call is the maximum per callback

### Sensor API
- `Sensor.registerSensorDataListener` gives batch data (array of samples per callback) -- much better for rep detection
- `Sensor.getInfo().accel` gives a single sample at call time -- works as fallback
- Both return milli-g values: `[x, y, z]` where at rest the magnitude is ~1000
- Not all devices support `registerSensorDataListener` -- the try/catch fallback to polling is essential

### ActivityRecording
- `createSession()` is device-global, not app-scoped -- orphans from previous crashes persist
- Always check `isRecording()` immediately after getting a session
- `addLap()` creates a lap marker in the FIT file -- one per set for strength training
- `.save()` must be called after `.stop()` -- calling save while recording crashes
- The session object becomes invalid after save/discard -- null it out

### Application.Storage vs Application.Properties
- `Storage` -- app-controlled read/write data (recent exercises, learned thresholds). Persists across app updates.
- `Properties` -- user settings configured via Garmin Connect Mobile. Read-only from app code. Defined in `resources/settings/`.

### Building for Multiple Devices
- The manifest lists all supported devices -- the compiler builds one PRG per device when building release
- API level 3.2.0 is the minimum -- this excludes very old devices but covers everything from ~2020 onward
- The `.iq` package contains all device variants for store upload
