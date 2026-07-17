import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

class ExercisePickerView extends WatchUi.View {

    function initialize() {
        View.initialize();
    }

    function onShow() as Void {
        showGroupMenu();
    }

    function onUpdate(dc as Dc) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
    }

    static function showGroupMenu() as Void {
        var menu = new WatchUi.Menu2({:title => "StrengthFlow"});

        // Show recent groups at top
        var recentGroups = ExerciseHistory.getRecentGroups();
        for (var i = 0; i < recentGroups.size(); i++) {
            menu.addItem(new WatchUi.MenuItem(recentGroups[i], "Recent", recentGroups[i], null));
        }

        // Custom groups from settings
        var customGroups = CustomGroups.getGroups();
        for (var i = 0; i < customGroups.size(); i++) {
            var group = customGroups[i];
            var name = group["name"] as String;
            var exercises = group["exercises"] as Array<String>;
            menu.addItem(new WatchUi.MenuItem(name, exercises.size() + " exercises", name, null));
        }

        menu.addItem(new WatchUi.MenuItem("Cardio", "10 exercises", :cardio, null));
        menu.addItem(new WatchUi.MenuItem("Chest + Triceps", "6 exercises", :chest, null));
        menu.addItem(new WatchUi.MenuItem("Back + Biceps", "7 exercises", :back, null));
        menu.addItem(new WatchUi.MenuItem("Shoulders + Arms", "6 exercises", :shoulders, null));
        menu.addItem(new WatchUi.MenuItem("Legs", "7 exercises", :legs, null));
        menu.addItem(new WatchUi.MenuItem("Abs", "6 exercises", :abs, null));
        menu.addItem(new WatchUi.MenuItem("Isolations", "Target one muscle", :bodyparts, null));
        menu.addItem(new WatchUi.MenuItem("Free Workout", "No exercise set", :free, null));
        WatchUi.pushView(menu, new GroupMenuDelegate(), WatchUi.SLIDE_UP);
    }
}

class ExercisePickerDelegate extends WatchUi.BehaviorDelegate {

    function initialize() {
        BehaviorDelegate.initialize();
    }

    function onSelect() as Boolean {
        ExercisePickerView.showGroupMenu();
        return true;
    }
}

class GroupMenuDelegate extends WatchUi.Menu2InputDelegate {

    function initialize() {
        Menu2InputDelegate.initialize();
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId();

        if (id == :free) {
            launchWorkout("Free Workout", "Free Workout");
            return;
        }

        if (id == :bodyparts) {
            var bpMenu = new WatchUi.Menu2({:title => "Isolations"});
            bpMenu.addItem(new WatchUi.MenuItem("Chest", "4 exercises", :chestOnly, null));
            bpMenu.addItem(new WatchUi.MenuItem("Back", "4 exercises", :backOnly, null));
            bpMenu.addItem(new WatchUi.MenuItem("Shoulders", "4 exercises", :shouldersOnly, null));
            bpMenu.addItem(new WatchUi.MenuItem("Triceps", "3 exercises", :triceps, null));
            bpMenu.addItem(new WatchUi.MenuItem("Biceps", "3 exercises", :biceps, null));
            bpMenu.addItem(new WatchUi.MenuItem("Forearms", "3 exercises", :forearms, null));
            bpMenu.addItem(new WatchUi.MenuItem("Quads", "4 exercises", :quads, null));
            bpMenu.addItem(new WatchUi.MenuItem("Hamstrings", "3 exercises", :hamstrings, null));
            bpMenu.addItem(new WatchUi.MenuItem("Glutes", "3 exercises", :glutes, null));
            bpMenu.addItem(new WatchUi.MenuItem("Calves", "2 exercises", :calves, null));
            WatchUi.pushView(bpMenu, new GroupMenuDelegate(), WatchUi.SLIDE_LEFT);
            return;
        }

        // String ID = recent group or custom group
        if (id instanceof String) {
            var groupName = id as String;
            var exercises = getExercisesForGroupName(groupName);
            if (exercises.size() == 0) {
                exercises = CustomGroups.getExercisesForGroup(groupName);
            }
            // Sort by recently used exercises
            exercises = ExerciseHistory.sortByRecent(exercises);
            var menu = new WatchUi.Menu2({:title => groupName});
            for (var i = 0; i < exercises.size(); i++) {
                menu.addItem(new WatchUi.MenuItem(exercises[i], null, exercises[i], null));
            }
            WatchUi.pushView(menu, new ExerciseMenuDelegate(groupName), WatchUi.SLIDE_LEFT);
            return;
        }

        var exercises = getExercisesForGroup(id as Symbol);
        var title = item.getLabel();

        // Sort exercises: recently used ones first
        exercises = ExerciseHistory.sortByRecent(exercises);

        var menu = new WatchUi.Menu2({:title => title});
        for (var i = 0; i < exercises.size(); i++) {
            menu.addItem(new WatchUi.MenuItem(exercises[i], null, exercises[i], null));
        }
        WatchUi.pushView(menu, new ExerciseMenuDelegate(title), WatchUi.SLIDE_LEFT);
    }

    function onBack() as Void {
        System.exit();
    }

    private function getExercisesForGroupName(name as String) as Array<String> {
        if (name.equals("Chest + Triceps")) {
            return ["Bench Press", "Incline Press", "Chest Fly", "Tricep Dip", "Tricep Extension", "Skull Crusher"];
        } else if (name.equals("Back + Biceps")) {
            return ["Deadlift", "Barbell Row", "Pull Up", "Lat Pulldown", "Seated Row", "Dumbbell Curl", "Hammer Curl"];
        } else if (name.equals("Shoulders + Arms")) {
            return ["Overhead Press", "Lateral Raise", "Front Raise", "Face Pull", "Wrist Curl", "Reverse Curl"];
        } else if (name.equals("Legs")) {
            return ["Squat", "Leg Press", "Lunges", "Leg Curl", "Leg Extension", "Calf Raise", "Romanian Deadlift"];
        } else if (name.equals("Cardio")) {
            return ["Treadmill Run", "Elliptical", "Stairmaster", "HIIT", "Jump Rope", "Burpees", "Mountain Climbers", "Jumping Jacks", "Box Jumps", "Battle Ropes", "Kettlebell Swing"];
        } else if (name.equals("Abs")) {
            return ["Crunch", "Plank", "Hanging Leg Raise", "Cable Crunch", "Ab Rollout", "Russian Twist"];
        } else if (name.equals("Chest")) {
            return ["Bench Press", "Incline Press", "Chest Fly", "Cable Crossover"];
        } else if (name.equals("Back")) {
            return ["Deadlift", "Barbell Row", "Pull Up", "Lat Pulldown"];
        } else if (name.equals("Shoulders")) {
            return ["Overhead Press", "Lateral Raise", "Front Raise", "Face Pull"];
        } else if (name.equals("Triceps")) {
            return ["Tricep Dip", "Tricep Extension", "Skull Crusher"];
        } else if (name.equals("Biceps")) {
            return ["Dumbbell Curl", "Hammer Curl", "Barbell Curl"];
        } else if (name.equals("Forearms")) {
            return ["Wrist Curl", "Reverse Curl", "Farmer Walk"];
        } else if (name.equals("Quads")) {
            return ["Squat", "Leg Press", "Leg Extension", "Lunges"];
        } else if (name.equals("Hamstrings")) {
            return ["Romanian Deadlift", "Leg Curl", "Good Morning"];
        } else if (name.equals("Glutes")) {
            return ["Hip Thrust", "Bulgarian Split Squat", "Glute Bridge"];
        } else if (name.equals("Calves")) {
            return ["Calf Raise", "Seated Calf Raise"];
        }
        return [];
    }

    private function getExercisesForGroup(id as Symbol) as Array<String> {
        if (id == :chest) {
            return ["Bench Press", "Incline Press", "Decline Press", "Chest Fly", "Cable Crossover", "Push Up", "Dip", "Tricep Dip", "Tricep Extension", "Skull Crusher", "Tricep Pushdown", "Close Grip Bench"];
        } else if (id == :back) {
            return ["Deadlift", "Barbell Row", "Pull Up", "Chin Up", "Lat Pulldown", "Seated Row", "T-Bar Row", "Face Pull", "Dumbbell Curl", "Hammer Curl", "Barbell Curl", "Preacher Curl"];
        } else if (id == :shoulders) {
            return ["Overhead Press", "Dumbbell Press", "Lateral Raise", "Front Raise", "Rear Delt Fly", "Face Pull", "Upright Row", "Shrug", "Wrist Curl", "Reverse Curl", "Farmer Walk"];
        } else if (id == :legs) {
            return ["Squat", "Front Squat", "Leg Press", "Lunges", "Bulgarian Split Squat", "Leg Curl", "Leg Extension", "Romanian Deadlift", "Hip Thrust", "Calf Raise", "Goblet Squat", "Step Up"];
        } else if (id == :cardio) {
            return ["Treadmill Run", "Elliptical", "Stairmaster", "HIIT", "Jump Rope", "Rowing Machine", "Cycling", "Burpees", "Mountain Climbers", "Jumping Jacks", "Box Jumps", "Battle Ropes", "Kettlebell Swing"];
        } else if (id == :abs) {
            return ["Crunch", "Plank", "Hanging Leg Raise", "Cable Crunch", "Ab Rollout", "Russian Twist", "Bicycle Crunch", "Dead Bug", "V-Up", "Woodchop"];
        } else if (id == :chestOnly) {
            return ["Bench Press", "Incline Press", "Decline Press", "Chest Fly", "Cable Crossover", "Push Up", "Dip", "Pec Deck"];
        } else if (id == :backOnly) {
            return ["Deadlift", "Barbell Row", "Pull Up", "Chin Up", "Lat Pulldown", "Seated Row", "T-Bar Row", "Single Arm Row"];
        } else if (id == :triceps) {
            return ["Tricep Dip", "Tricep Extension", "Skull Crusher", "Tricep Pushdown", "Close Grip Bench", "Overhead Extension"];
        } else if (id == :biceps) {
            return ["Dumbbell Curl", "Hammer Curl", "Barbell Curl", "Preacher Curl", "Concentration Curl", "Cable Curl"];
        } else if (id == :shouldersOnly) {
            return ["Overhead Press", "Dumbbell Press", "Lateral Raise", "Front Raise", "Rear Delt Fly", "Face Pull", "Upright Row", "Shrug"];
        } else if (id == :forearms) {
            return ["Wrist Curl", "Reverse Curl", "Farmer Walk", "Plate Pinch", "Dead Hang"];
        } else if (id == :quads) {
            return ["Squat", "Front Squat", "Leg Press", "Leg Extension", "Lunges", "Goblet Squat", "Step Up"];
        } else if (id == :hamstrings) {
            return ["Romanian Deadlift", "Leg Curl", "Good Morning", "Nordic Curl", "Stiff Leg Deadlift"];
        } else if (id == :glutes) {
            return ["Hip Thrust", "Bulgarian Split Squat", "Glute Bridge", "Cable Kickback", "Sumo Deadlift"];
        } else if (id == :calves) {
            return ["Calf Raise", "Seated Calf Raise", "Donkey Calf Raise"];
        }
        return [];
    }
}

class ExerciseMenuDelegate extends WatchUi.Menu2InputDelegate {

    private var _groupName as String;

    function initialize(groupName as String) {
        Menu2InputDelegate.initialize();
        _groupName = groupName;
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var name = item.getLabel();
        ExerciseHistory.recordUsage(name);
        ExerciseHistory.recordGroup(_groupName);
        launchWorkout(name, _groupName);
    }

    function onBack() as Void {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
    }
}

// Persists recent exercise choices using Application.Storage
class ExerciseHistory {

    private static const STORAGE_KEY = "recent_exercises";
    private static const GROUP_KEY = "last_group";
    private static const MAX_RECENT = 5;

    static function recordGroup(groupName as String) as Void {
        Application.Storage.setValue(GROUP_KEY, groupName);

        // Track recent groups list
        var groups = getRecentGroups();
        var filtered = [] as Array<String>;
        for (var i = 0; i < groups.size(); i++) {
            if (!groups[i].equals(groupName)) {
                filtered.add(groups[i]);
            }
        }
        filtered = ([groupName] as Array<String>).addAll(filtered);
        if (filtered.size() > 3) {
            filtered = filtered.slice(0, 3);
        }
        Application.Storage.setValue("recent_groups", filtered);
    }

    static function getRecentGroups() as Array<String> {
        var stored = Application.Storage.getValue("recent_groups");
        if (stored != null && stored instanceof Array) {
            return stored as Array<String>;
        }
        return [] as Array<String>;
    }

    static function getLastGroup() as String {
        var stored = Application.Storage.getValue(GROUP_KEY);
        if (stored != null && stored instanceof String) {
            return stored as String;
        }
        return "Workout";
    }

    static function recordUsage(name as String) as Void {
        var recent = getRecent();

        // Remove if already exists
        var filtered = [] as Array<String>;
        for (var i = 0; i < recent.size(); i++) {
            if (!recent[i].equals(name)) {
                filtered.add(recent[i]);
            }
        }

        // Add to front
        filtered = ([name] as Array<String>).addAll(filtered);

        // Trim to max
        if (filtered.size() > MAX_RECENT) {
            filtered = filtered.slice(0, MAX_RECENT);
        }

        Application.Storage.setValue(STORAGE_KEY, filtered);
    }

    static function getRecent() as Array<String> {
        var stored = Application.Storage.getValue(STORAGE_KEY);
        if (stored != null && stored instanceof Array) {
            return stored as Array<String>;
        }
        return [] as Array<String>;
    }

    static function sortByRecent(exercises as Array<String>) as Array<String> {
        var recent = getRecent();
        var recentFirst = [] as Array<String>;
        var rest = [] as Array<String>;

        for (var i = 0; i < exercises.size(); i++) {
            var found = false;
            for (var j = 0; j < recent.size(); j++) {
                if (exercises[i].equals(recent[j])) {
                    found = true;
                    break;
                }
            }
            if (found) {
                recentFirst.add(exercises[i]);
            } else {
                rest.add(exercises[i]);
            }
        }

        return recentFirst.addAll(rest);
    }
}

// Reads custom groups from app settings (configured via Garmin Connect Mobile)
class CustomGroups {

    static function getGroups() as Array<Dictionary> {
        var groups = [] as Array<Dictionary>;

        for (var i = 1; i <= 3; i++) {
            var nameKey = "customGroup" + i + "Name";
            var exKey = "customGroup" + i + "Exercises";
            var name = Application.Properties.getValue(nameKey);
            var exStr = Application.Properties.getValue(exKey);

            if (name != null && name instanceof String && !(name as String).equals("")) {
                var exercises = parseCommaSeparated(exStr);
                if (exercises.size() > 0) {
                    groups.add({
                        "name" => name as String,
                        "exercises" => exercises
                    });
                }
            }
        }
        return groups;
    }

    static function getExercisesForGroup(groupName as String) as Array<String> {
        var groups = getGroups();
        for (var i = 0; i < groups.size(); i++) {
            if ((groups[i]["name"] as String).equals(groupName)) {
                return groups[i]["exercises"] as Array<String>;
            }
        }
        return [];
    }

    private static function parseCommaSeparated(value) as Array<String> {
        var result = [] as Array<String>;
        if (value == null || !(value instanceof String)) {
            return result;
        }
        var str = value as String;
        if (str.equals("")) {
            return result;
        }

        var start = 0;
        for (var i = 0; i < str.length(); i++) {
            if (str.substring(i, i + 1).equals(",")) {
                var item = str.substring(start, i);
                item = trim(item);
                if (!item.equals("")) {
                    result.add(item);
                }
                start = i + 1;
            }
        }
        // Last item
        var last = str.substring(start, str.length());
        last = trim(last);
        if (!last.equals("")) {
            result.add(last);
        }
        return result;
    }

    private static function trim(str as String) as String {
        var start = 0;
        var end = str.length();
        while (start < end && str.substring(start, start + 1).equals(" ")) {
            start++;
        }
        while (end > start && str.substring(end - 1, end).equals(" ")) {
            end--;
        }
        return str.substring(start, end);
    }
}

function launchWorkout(exerciseName as String, groupName as String) as Void {
    var view = new WorkoutView(exerciseName, groupName);
    WatchUi.pushView(view, new WorkoutDelegate(view), WatchUi.SLIDE_LEFT);
}
