import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

// Flat, de-duplicated list of exercise names across all built-in groups,
// used when re-assigning a stored set's exercise. Cheap enough for a menu.
function allExerciseNames() as Array {
    var groups = ["Chest + Triceps", "Back + Biceps", "Shoulders + Arms",
                  "Legs", "Abs", "Cardio"];
    var out = [] as Array;
    for (var g = 0; g < groups.size(); g++) {
        var ex = getExercisesForGroup(groups[g]);
        for (var i = 0; i < ex.size(); i++) {
            var name = ex[i];
            var dup = false;
            for (var j = 0; j < out.size(); j++) {
                if ((out[j] as String).equals(name)) { dup = true; break; }
            }
            if (!dup) { out.add(name); }
        }
    }
    return out;
}

// === History list: shows past workouts as a menu (newest first) ===
// Selecting a workout opens its detail; long-press/menu offers "Clear All".
class HistoryMenu {

    static function show() as Void {
        var menu = new WatchUi.Menu2({:title => "History"});
        var ids = WorkoutHistory.getIdsNewestFirst();

        if (ids.size() == 0) {
            menu.addItem(new WatchUi.MenuItem("No workouts yet", "Finish one to see it here", :none, null));
        } else {
            for (var i = 0; i < ids.size(); i++) {
                var id = ids[i] as Number;
                var w = WorkoutHistory.get(id);
                if (w == null) { continue; }
                var date = WorkoutHistory.shortDate(w);
                var sets = w["sets"] as Array;
                var isCardio = w.hasKey("cardio") && (w["cardio"] as Boolean);
                // Prefer the group name; fall back to the first exercise for
                // older entries saved before the group was stored.
                var title = "Workout";
                if (w.hasKey("group") && !(w["group"] as String).equals("")) {
                    title = w["group"] as String;
                } else if (sets.size() > 0) {
                    title = (sets[0] as Dictionary)["e"] as String;
                }
                var sub;
                if (isCardio) {
                    // Cardio: duration + distance (or floors) + calories.
                    sub = HistoryMenu.formatMinSec(w["secs"] as Number);
                    var dist = w.hasKey("dist") ? w["dist"] as Number : 0;
                    var floors = w.hasKey("floors") ? w["floors"] as Number : 0;
                    if (dist > 0) {
                        sub += " • " + (dist / 10.0).format("%.1f") + " mi";
                    } else if (floors > 0) {
                        sub += " • " + floors + " floors";
                    }
                } else {
                    sub = sets.size() + " sets";
                    var vol = w["vol"] as Number;
                    if (vol > 0) {
                        sub += " • " + vol + " " + WorkoutView.weightUnit();
                    }
                }
                menu.addItem(new WatchUi.MenuItem(date + " · " + title, sub, id, null));
            }
            menu.addItem(new WatchUi.MenuItem("Clear All History", WorkoutHistory.count() + " workouts", :clearAll, null));
        }

        WatchUi.pushView(menu, new HistoryMenuDelegate(), WatchUi.SLIDE_LEFT);
    }

    static function formatMinSec(seconds as Number) as String {
        var m = seconds / 60;
        var s = seconds % 60;
        return m.format("%d") + ":" + s.format("%02d");
    }
}

class HistoryMenuDelegate extends WatchUi.Menu2InputDelegate {

    function initialize() {
        Menu2InputDelegate.initialize();
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId();
        if (id == :none) {
            return;
        }
        if (id == :clearAll) {
            // Confirm before wiping.
            WatchUi.pushView(
                new WatchUi.Confirmation("Delete all workout history?"),
                new ClearAllConfirmDelegate(),
                WatchUi.SLIDE_LEFT);
            return;
        }
        if (id instanceof Number) {
            WorkoutDetailView.show(id as Number);
        }
    }
}

class ClearAllConfirmDelegate extends WatchUi.ConfirmationDelegate {
    function initialize() {
        ConfirmationDelegate.initialize();
    }
    function onResponse(response as WatchUi.Confirm) as Boolean {
        if (response == WatchUi.CONFIRM_YES) {
            WorkoutHistory.deleteAll();
            // Pop the confirmation and the (now-stale) history menu.
            WatchUi.popView(WatchUi.SLIDE_RIGHT);
            WatchUi.popView(WatchUi.SLIDE_RIGHT);
        }
        return true;
    }
}

// === Workout detail: scrollable per-set breakdown for one workout ===
class WorkoutDetailView extends WatchUi.View {

    private var _id as Number;
    private var _workout as Dictionary?;
    private var _scroll as Number = 0;

    static function show(id as Number) as Void {
        var v = new WorkoutDetailView(id);
        WatchUi.pushView(v, new WorkoutDetailDelegate(v, id), WatchUi.SLIDE_LEFT);
    }

    function initialize(id as Number) {
        View.initialize();
        _id = id;
        _workout = WorkoutHistory.get(id);
    }

    function reload() as Void {
        _workout = WorkoutHistory.get(_id);
    }

    function getId() as Number { return _id; }

    function scrollDown() as Void { _scroll += 40; WatchUi.requestUpdate(); }
    function scrollUp() as Void {
        if (_scroll > 0) { _scroll -= 40; WatchUi.requestUpdate(); }
    }

    function onUpdate(dc as Dc) as Void {
        var w = dc.getWidth();
        var cx = w / 2;
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        if (_workout == null) {
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, dc.getHeight() / 2, Graphics.FONT_SMALL, "Deleted",
                Graphics.TEXT_JUSTIFY_CENTER);
            return;
        }

        var y = 50 - _scroll;

        // Header: date + group name + totals
        dc.setColor(0x00CC66, Graphics.COLOR_TRANSPARENT);
        var header = WorkoutHistory.shortDate(_workout);
        if (_workout.hasKey("group") && !(_workout["group"] as String).equals("")) {
            header += " · " + (_workout["group"] as String);
        }
        dc.drawText(cx, y, Graphics.FONT_SMALL, header, Graphics.TEXT_JUSTIFY_CENTER);
        y += 32;

        var secs = _workout["secs"] as Number;
        var isCardio = _workout.hasKey("cardio") && (_workout["cardio"] as Boolean);

        if (isCardio) {
            // Cardio summary: duration, distance/floors, avg HR, calories.
            var hr = _workout.hasKey("hr") ? _workout["hr"] as Number : 0;
            var cal = _workout.hasKey("cal") ? _workout["cal"] as Number : 0;
            var dist = _workout.hasKey("dist") ? _workout["dist"] as Number : 0;
            var floors = _workout.hasKey("floors") ? _workout["floors"] as Number : 0;

            drawStatRow(dc, cx, y, "Time", formatTime(secs)); y += 30;
            if (dist > 0) {
                drawStatRow(dc, cx, y, "Distance", (dist / 10.0).format("%.1f") + " mi"); y += 30;
            } else if (floors > 0) {
                drawStatRow(dc, cx, y, "Floors", floors.toString()); y += 30;
            }
            if (hr > 0) { drawStatRow(dc, cx, y, "Avg HR", hr + " bpm"); y += 30; }
            if (cal > 0) { drawStatRow(dc, cx, y, "Calories", cal.toString()); y += 30; }
        } else {
            var vol = _workout["vol"] as Number;
            dc.setColor(0x999999, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, y, Graphics.FONT_XTINY,
                formatTime(secs) + (vol > 0 ? "  •  " + vol + " " + WorkoutView.weightUnit() : ""),
                Graphics.TEXT_JUSTIFY_CENTER);
            y += 30;

            // Per-set rows
            var sets = _workout["sets"] as Array;
            for (var i = 0; i < sets.size(); i++) {
                var s = sets[i] as Dictionary;
                var name = s["e"] as String;
                var reps = s["r"] as Number;
                var wt = s["w"] as Number;

                dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
                dc.drawText(20, y, Graphics.FONT_XTINY, (i + 1) + ". " + name,
                    Graphics.TEXT_JUSTIFY_LEFT);
                var detail = wt > 0 ? reps + " × " + wt : reps + " reps";
                dc.setColor(0xFFAA00, Graphics.COLOR_TRANSPARENT);
                dc.drawText(w - 20, y, Graphics.FONT_XTINY, detail,
                    Graphics.TEXT_JUSTIFY_RIGHT);
                y += 26;
            }
        }

        y += 10;
        dc.setColor(0x555555, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, y, Graphics.FONT_XTINY, "MENU: edit / delete",
            Graphics.TEXT_JUSTIFY_CENTER);
    }

    private function drawStatRow(dc as Dc, cx as Number, y as Number,
                                 label as String, value as String) as Void {
        dc.setColor(0x999999, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx - 10, y, Graphics.FONT_XTINY, label, Graphics.TEXT_JUSTIFY_RIGHT);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx + 10, y, Graphics.FONT_XTINY, value, Graphics.TEXT_JUSTIFY_LEFT);
    }

    private function formatTime(seconds as Number) as String {
        var m = seconds / 60;
        var s = seconds % 60;
        return m.format("%d") + ":" + s.format("%02d");
    }
}

class WorkoutDetailDelegate extends WatchUi.BehaviorDelegate {

    private var _view as WorkoutDetailView;
    private var _id as Number;

    function initialize(view as WorkoutDetailView, id as Number) {
        BehaviorDelegate.initialize();
        _view = view;
        _id = id;
    }

    function onNextPage() as Boolean { _view.scrollDown(); return true; }
    function onPreviousPage() as Boolean { _view.scrollUp(); return true; }

    // MENU (long press) → edit/delete options for this workout
    function onMenu() as Boolean {
        showEditMenu();
        return true;
    }

    function onSelect() as Boolean {
        showEditMenu();
        return true;
    }

    private function showEditMenu() as Void {
        var menu = new WatchUi.Menu2({:title => "Edit Workout"});
        var w = WorkoutHistory.get(_id);
        if (w != null) {
            var sets = w["sets"] as Array;
            for (var i = 0; i < sets.size(); i++) {
                var s = sets[i] as Dictionary;
                var name = s["e"] as String;
                var reps = s["r"] as Number;
                var wt = s["w"] as Number;
                var sub = wt > 0 ? reps + " × " + wt : reps + " reps";
                menu.addItem(new WatchUi.MenuItem(name, sub, i, null));
            }
        }
        menu.addItem(new WatchUi.MenuItem("Delete Whole Workout", null, :deleteAll, null));
        WatchUi.pushView(menu, new EditWorkoutDelegate(_view, _id), WatchUi.SLIDE_UP);
    }
}

// Top-level edit menu: pick a set to edit, or delete the whole workout.
class EditWorkoutDelegate extends WatchUi.Menu2InputDelegate {

    private var _view as WorkoutDetailView;
    private var _id as Number;

    function initialize(view as WorkoutDetailView, id as Number) {
        Menu2InputDelegate.initialize();
        _view = view;
        _id = id;
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId();
        if (id == :deleteAll) {
            WorkoutHistory.deleteWorkout(_id);
            // Pop edit menu + detail view, back to history list.
            WatchUi.popView(WatchUi.SLIDE_RIGHT);
            WatchUi.popView(WatchUi.SLIDE_RIGHT);
            return;
        }
        if (id instanceof Number) {
            showSetMenu(id as Number);
        }
    }

    // Per-set actions: edit name / reps / weight, or delete this set.
    private function showSetMenu(setIndex as Number) as Void {
        var w = WorkoutHistory.get(_id);
        if (w == null) { return; }
        var sets = w["sets"] as Array;
        if (setIndex < 0 || setIndex >= sets.size()) { return; }
        var s = sets[setIndex] as Dictionary;
        var name = s["e"] as String;
        var reps = s["r"] as Number;
        var wt = s["w"] as Number;

        var menu = new WatchUi.Menu2({:title => name});
        menu.addItem(new WatchUi.MenuItem("Exercise", name, :name, null));
        menu.addItem(new WatchUi.MenuItem("Reps", reps.toString(), :reps, null));
        menu.addItem(new WatchUi.MenuItem("Weight",
            wt > 0 ? wt + " " + WorkoutView.weightUnit() : "None", :weight, null));
        menu.addItem(new WatchUi.MenuItem("Delete Set", null, :delete, null));
        WatchUi.pushView(menu, new SetEditDelegate(_view, _id, setIndex), WatchUi.SLIDE_LEFT);
    }
}

// Actions for a single set.
class SetEditDelegate extends WatchUi.Menu2InputDelegate {

    private var _view as WorkoutDetailView;
    private var _id as Number;
    private var _setIndex as Number;

    function initialize(view as WorkoutDetailView, id as Number, setIndex as Number) {
        Menu2InputDelegate.initialize();
        _view = view;
        _id = id;
        _setIndex = setIndex;
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId();

        if (id == :delete) {
            WorkoutHistory.deleteSet(_id, _setIndex);
            _view.reload();
            // Pop set-menu + edit-menu back to the detail view.
            WatchUi.popView(WatchUi.SLIDE_RIGHT);
            WatchUi.popView(WatchUi.SLIDE_RIGHT);
            if (WorkoutHistory.get(_id) == null) {
                // Workout emptied — drop back to the history list.
                WatchUi.popView(WatchUi.SLIDE_RIGHT);
            } else {
                WatchUi.requestUpdate();
            }
            return;
        }

        if (id == :reps) {
            var menu = new WatchUi.Menu2({:title => "Reps"});
            for (var r = 1; r <= 30; r++) {
                menu.addItem(new WatchUi.MenuItem(r.toString(), null, r, null));
            }
            WatchUi.pushView(menu, new ValuePickerDelegate(_view, _id, _setIndex, "r"),
                WatchUi.SLIDE_LEFT);
            return;
        }

        if (id == :weight) {
            var unit = WorkoutView.weightUnit();
            var menu = new WatchUi.Menu2({:title => "Weight (" + unit + ")"});
            var weights;
            if (WorkoutView.useKg()) {
                weights = [0, 2, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 60, 70, 80, 90, 100, 110, 120, 140];
            } else {
                weights = [0, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55, 60, 65, 70, 75, 80, 85, 90, 95, 100, 110, 120, 135, 150, 175, 200, 225, 250, 275, 300];
            }
            for (var i = 0; i < weights.size(); i++) {
                var label = weights[i] == 0 ? "None" : weights[i].toString();
                menu.addItem(new WatchUi.MenuItem(label, null, weights[i], null));
            }
            WatchUi.pushView(menu, new ValuePickerDelegate(_view, _id, _setIndex, "w"),
                WatchUi.SLIDE_LEFT);
            return;
        }

        if (id == :name) {
            // Pick a new exercise name from the full list.
            var names = allExerciseNames();
            var menu = new WatchUi.Menu2({:title => "Exercise"});
            for (var i = 0; i < names.size(); i++) {
                menu.addItem(new WatchUi.MenuItem(names[i], null, names[i], null));
            }
            WatchUi.pushView(menu, new ValuePickerDelegate(_view, _id, _setIndex, "e"),
                WatchUi.SLIDE_LEFT);
            return;
        }
    }
}

// Applies a chosen value (reps/weight/name) to the set and unwinds the menus.
class ValuePickerDelegate extends WatchUi.Menu2InputDelegate {

    private var _view as WorkoutDetailView;
    private var _id as Number;
    private var _setIndex as Number;
    private var _field as String;

    function initialize(view as WorkoutDetailView, id as Number,
                        setIndex as Number, field as String) {
        Menu2InputDelegate.initialize();
        _view = view;
        _id = id;
        _setIndex = setIndex;
        _field = field;
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        WorkoutHistory.updateSet(_id, _setIndex, _field, item.getId());
        _view.reload();
        // Pop value-picker + set-menu + edit-menu → back to detail view.
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        WatchUi.requestUpdate();
    }
}
