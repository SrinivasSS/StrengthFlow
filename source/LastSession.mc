import Toybox.Application;
import Toybox.Lang;

// Remembers the last-logged weight and reps per exercise across workouts.
class LastSession {

    private static const KEY = "last_session";

    // Returns { "weight" => Number, "reps" => Number } for an exercise, or null.
    static function get(exercise as String) as Dictionary? {
        try {
            var all = Application.Storage.getValue(KEY);
            if (all != null && all instanceof Dictionary) {
                var val = all[exercise];
                if (val != null && val instanceof Dictionary) {
                    return val as Dictionary;
                }
            }
        } catch (e) {}
        return null;
    }

    // Store the most recent set for an exercise.
    static function record(exercise as String, weight as Number, reps as Number) as Void {
        if (reps <= 0) { return; }
        try {
            var all = Application.Storage.getValue(KEY);
            if (all == null || !(all instanceof Dictionary)) {
                all = {};
            }
            all[exercise] = { "weight" => weight, "reps" => reps };
            Application.Storage.setValue(KEY, all);
        } catch (e) {}
    }

    // Formatted "8 x 135" or "12 reps" (bodyweight) or "" if none.
    static function summary(exercise as String, unit as String) as String {
        var d = get(exercise);
        if (d == null) { return ""; }
        var w = d["weight"] as Number;
        var r = d["reps"] as Number;
        if (w > 0) {
            return r + " x " + w + " " + unit;
        }
        return r + " reps";
    }
}
