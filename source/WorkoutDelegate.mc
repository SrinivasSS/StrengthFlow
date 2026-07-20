import Toybox.Lang;
import Toybox.WatchUi;

class WorkoutDelegate extends WatchUi.BehaviorDelegate {

    private var _view as WorkoutView;

    function initialize(view as WorkoutView) {
        BehaviorDelegate.initialize();
        _view = view;
    }

    // START/STOP — start or pause
    function onSelect() as Boolean {
        var state = _view.getState();
        if (state == STATE_READY) {
            _view.startWorkout();
        } else if (state == STATE_PAUSED) {
            // Shouldn't get here since menu is showing, but just in case
            _view.resumeWorkout();
        } else {
            _view.pauseWorkout();
        }
        return true;
    }

    // BACK / LAP — toggle between set and rest
    function onBack() as Boolean {
        var state = _view.getState();
        if (state == STATE_READY) {
            return false;
        } else if (state == STATE_SET_ACTIVE) {
            _view.endSet();
        } else if (state == STATE_REST) {
            _view.startSet();
        }
        return true;
    }

    // UP button — add rep
    function onPreviousPage() as Boolean {
        var state = _view.getState();
        if (state == STATE_SET_ACTIVE) {
            _view.addRep();
        }
        return true;
    }

    // DOWN button — open stats page (below main screen)
    function onNextPage() as Boolean {
        var state = _view.getState();
        if (state == STATE_SET_ACTIVE || state == STATE_REST) {
            var stats = new StatsView(_view.getExerciseName(), _view.getVolume(), WorkoutView.weightUnit());
            WatchUi.pushView(stats, new StatsDelegate(_view), WatchUi.SLIDE_UP);
        }
        return true;
    }

    // MENU (long press) — toggle auto-detect during workout
    function onMenu() as Boolean {
        var state = _view.getState();
        if (state != STATE_READY && state != STATE_PAUSED) {
            _view.toggleAutoDetect();
        }
        return true;
    }
}

class PauseMenuDelegate extends WatchUi.Menu2InputDelegate {

    private var _view as WorkoutView;

    function initialize(view as WorkoutView) {
        Menu2InputDelegate.initialize();
        _view = view;
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId() as Symbol;
        if (id == :resume) {
            WatchUi.popView(WatchUi.SLIDE_DOWN);
            _view.resumeWorkout();
        } else if (id == :save) {
            WatchUi.popView(WatchUi.SLIDE_DOWN);
            _view.endWorkout(false);
        } else if (id == :discard) {
            WatchUi.popView(WatchUi.SLIDE_DOWN);
            _view.discardWorkout();
        } else if (id == :debug) {
            WatchUi.pushView(new DebugView(_view.getRepDetector()), new DebugDelegate(), WatchUi.SLIDE_LEFT);
        } else if (id == :weight) {
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
            WatchUi.pushView(menu, new WeightPickerDelegate(_view, item), WatchUi.SLIDE_LEFT);
        } else if (id == :distance) {
            WatchUi.pushView(new DistancePicker(_view.getManualDistanceTenths()),
                new DistancePickerDelegate(_view), WatchUi.SLIDE_LEFT);
        } else if (id == :toggleAuto) {
            WatchUi.popView(WatchUi.SLIDE_DOWN);
            _view.toggleAutoDetect();
            _view.resumeWorkout();
        } else if (id == :quickSwitch) {
            // Show exercises from current group directly
            _view.setQuickSwitchMode(true);
            var groupName = _view.getGroupName();
            var exercises = getExercisesForGroup(groupName);
            var menu = new WatchUi.Menu2({:title => groupName});
            for (var i = 0; i < exercises.size(); i++) {
                if (!exercises[i].equals(_view.getExerciseName())) {
                    menu.addItem(new WatchUi.MenuItem(exercises[i], null, exercises[i], null));
                }
            }
            menu.addItem(new WatchUi.MenuItem("Other Groups...", null, :otherGroups, null));
            WatchUi.pushView(menu, new QuickSwitchDelegate(_view), WatchUi.SLIDE_LEFT);
        } else if (id == :switchExercise) {
            // Save and start fresh workout
            WatchUi.popView(WatchUi.SLIDE_DOWN);
            _view.endWorkout(true);
        }
    }

    function onBack() as Void {
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        _view.resumeWorkout();
    }
}

class WeightPickerDelegate extends WatchUi.Menu2InputDelegate {

    private var _view as WorkoutView;
    private var _sourceItem as WatchUi.MenuItem?;

    function initialize(view as WorkoutView, sourceItem as WatchUi.MenuItem) {
        Menu2InputDelegate.initialize();
        _view = view;
        _sourceItem = sourceItem;
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var weight = item.getId() as Number;
        _view.setWeight(weight);
        // Update the pause-menu Weight item's sublabel so it reflects the new value
        if (_sourceItem != null) {
            _sourceItem.setSubLabel(weight > 0 ? weight + " " + WorkoutView.weightUnit() : "Not set");
        }
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
    }

    function onBack() as Void {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
    }
}

class DistancePickerDelegate extends WatchUi.PickerDelegate {

    private var _view as WorkoutView;

    function initialize(view as WorkoutView) {
        PickerDelegate.initialize();
        _view = view;
    }

    function onAccept(values as Array) as Boolean {
        // values = [wholeMiles, dotIndex, tenths]
        var whole = values[0] as Number;
        var tenths = values[2] as Number;
        _view.setManualDistance(whole * 10 + tenths);
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        return true;
    }

    function onCancel() as Boolean {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        return true;
    }
}

class QuickSwitchDelegate extends WatchUi.Menu2InputDelegate {

    private var _view as WorkoutView;

    function initialize(view as WorkoutView) {
        Menu2InputDelegate.initialize();
        _view = view;
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId();
        if (id == :otherGroups) {
            ExercisePickerView.showGroupMenu();
            return;
        }

        // Quick switch — change name, pop switch menu + pause menu, resume
        var name = item.getLabel();
        _view.doQuickSwitch(name, _view.getGroupName());
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        _view.resumeWorkout();
    }

    function onBack() as Void {
        _view.setQuickSwitchMode(false);
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
    }
}

