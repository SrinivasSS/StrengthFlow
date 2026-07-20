import Toybox.Application;
import Toybox.Lang;

// Tracks personal records (max weight per exercise) in persistent storage.
class PRTracker {

    private static const KEY = "prs";

    // Returns the stored best weight for an exercise, or 0 if none.
    static function getBestWeight(exercise as String) as Number {
        try {
            var prs = Application.Storage.getValue(KEY);
            if (prs != null && prs instanceof Dictionary) {
                var val = prs[exercise];
                if (val != null && val instanceof Number) {
                    return val;
                }
            }
        } catch (e) {}
        return 0;
    }

    // Records a set's weight. Returns true if it's a new PR.
    static function checkAndRecord(exercise as String, weight as Number) as Boolean {
        if (weight <= 0) { return false; }
        try {
            var prs = Application.Storage.getValue(KEY);
            if (prs == null || !(prs instanceof Dictionary)) {
                prs = {};
            }
            var prev = prs[exercise];
            var prevBest = (prev != null && prev instanceof Number) ? prev as Number : 0;

            if (weight > prevBest) {
                prs[exercise] = weight;
                Application.Storage.setValue(KEY, prs);
                return true;
            }
        } catch (e) {}
        return false;
    }
}
