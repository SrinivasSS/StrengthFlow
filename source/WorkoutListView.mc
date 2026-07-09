import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

class WorkoutListView extends WatchUi.View {

    private var _exercises as Array<String> = [
        "Bench Press",
        "Squat",
        "Deadlift",
        "Overhead Press",
        "Barbell Row",
        "Pull Up",
        "Dumbbell Curl"
    ];

    function initialize() {
        View.initialize();
    }

    function onLayout(dc as Dc) as Void {
    }

    function onUpdate(dc as Dc) as Void {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();

        var titleFont = Graphics.FONT_MEDIUM;
        dc.drawText(dc.getWidth() / 2, 10, titleFont, "Strength Tracker",
            Graphics.TEXT_JUSTIFY_CENTER);

        var y = 60;
        var font = Graphics.FONT_SMALL;
        for (var i = 0; i < _exercises.size(); i++) {
            dc.drawText(dc.getWidth() / 2, y, font, _exercises[i],
                Graphics.TEXT_JUSTIFY_CENTER);
            y += 30;
        }
    }
}

class WorkoutListDelegate extends WatchUi.BehaviorDelegate {

    function initialize() {
        BehaviorDelegate.initialize();
    }

    function onSelect() as Boolean {
        WatchUi.pushView(new ExerciseView("Bench Press"), new ExerciseDelegate(), WatchUi.SLIDE_LEFT);
        return true;
    }
}
