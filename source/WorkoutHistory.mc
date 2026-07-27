import Toybox.Application;
import Toybox.Lang;
import Toybox.Time;
import Toybox.Time.Gregorian;

// Persists finished workouts on-watch so the user can review past sessions
// (exercise names, sets, reps, weight, volume) without relying on Garmin
// Connect -- which cannot display third-party exercise names.
//
// Storage layout (avoids the ~8KB-per-value cap by splitting keys):
//   "wh_index" -> Array of workout ids (Numbers), oldest first
//   "wh_<id>"  -> Dictionary for one workout
// A ring buffer keeps at most MAX_WORKOUTS; the oldest rolls off.
class WorkoutHistory {

    private static const INDEX_KEY = "wh_index";
    private static const MAX_WORKOUTS = 30;      // ring-buffer count cap
    private static const MAX_SETS = 120;         // LAST-RESORT per-workout safety only
    private static const MAX_NAME_LEN = 24;      // trim long exercise names
    private static const SAVE_RETRIES = 8;       // evict-oldest retries on storage failure

    // Save a finished workout. `sets` is the WorkoutView set-history array
    // (each entry has exercise/reps/weight/duration). Returns quietly on error.
    //
    // Storage policy: the CURRENT workout is preserved whole. To make room we
    // dump OLDER history, never the new session. Guardrails, in priority order:
    //  1. Free space by eviction — enforce the count cap and, if a write still
    //     fails under storage pressure, drop the oldest workouts and retry.
    //  2. Last-resort size cap — only if a SINGLE workout is itself pathological
    //     (> MAX_SETS sets, which alone could exceed the ~8KB per-value limit)
    //     do we clip it. Normal 15-30 set workouts are never touched.
    //     Exercise names are trimmed (cheap, always safe).
    static function save(sets as Array, totalSeconds as Number, volume as Number,
                         avgHR as Number, calories as Number, group as String) as Void {
        if (sets == null || sets.size() == 0) { return; }

        // Compact the per-set data. We keep ALL sets of the current workout;
        // MAX_SETS is only a last-resort clamp for a pathological session
        // that alone would exceed the per-value storage limit.
        var storedSets = [] as Array<Dictionary>;
        var limit = sets.size() < MAX_SETS ? sets.size() : MAX_SETS;
        for (var i = 0; i < limit; i++) {
            var s = sets[i] as Dictionary;
            var name = s.hasKey("exercise") ? s["exercise"] as String : "";
            if (name.length() > MAX_NAME_LEN) {
                name = name.substring(0, MAX_NAME_LEN);
            }
            storedSets.add({
                "e" => name,
                "r" => s.hasKey("reps") ? s["reps"] : 0,
                "w" => s.hasKey("weight") ? s["weight"] : 0,
                "d" => s.hasKey("duration") ? s["duration"] : 0
            });
        }

        writeWorkout({
            "date" => nowStamp(),
            "secs" => totalSeconds,
            "vol" => volume,
            "hr" => avgHR,
            "cal" => calories,
            "group" => group,
            "cardio" => false,
            "sets" => storedSets
        });
    }

    // Save a cardio session as a summary entry (no sets). `name` is the cardio
    // exercise (e.g. "Treadmill Run"); it doubles as the history title/group.
    static function saveCardio(name as String, totalSeconds as Number,
                               avgHR as Number, calories as Number,
                               distanceTenths as Number, floors as Number) as Void {
        writeWorkout({
            "date" => nowStamp(),
            "secs" => totalSeconds,
            "vol" => 0,
            "hr" => avgHR,
            "cal" => calories,
            "group" => name,
            "cardio" => true,
            "dist" => distanceTenths,   // tenths of a mile
            "floors" => floors,
            "sets" => [] as Array<Dictionary>
        });
    }

    // Shared writer: assigns an id, enforces the count cap, writes with
    // evict-oldest-on-failure retry, and updates the index. Never throws.
    private static function writeWorkout(workout as Dictionary) as Void {
        try {
            var index = getIndex();

            // New id = (last id + 1), or 1 if empty. Ids only ever increase, so
            // per-workout keys never collide even after older ones roll off.
            var newId = 1;
            if (index.size() > 0) {
                newId = (index[index.size() - 1] as Number) + 1;
            }
            workout["id"] = newId;

            // Enforce the count cap up front (before writing the new one).
            while (index.size() >= MAX_WORKOUTS) {
                var oldId = index[0] as Number;
                Application.Storage.deleteValue("wh_" + oldId);
                index = index.slice(1, null);
            }

            // Write, retrying by evicting the oldest if storage is full. If it
            // still won't fit, abort without touching the index.
            var wrote = false;
            for (var attempt = 0; attempt <= SAVE_RETRIES && !wrote; attempt++) {
                try {
                    Application.Storage.setValue("wh_" + newId, workout);
                    wrote = true;
                } catch (ex) {
                    if (index.size() > 0) {
                        var evict = index[0] as Number;
                        Application.Storage.deleteValue("wh_" + evict);
                        index = index.slice(1, null);
                    } else {
                        break;  // nothing left to evict; give up
                    }
                }
            }

            if (wrote) {
                index.add(newId);
                Application.Storage.setValue(INDEX_KEY, index);
            }
        } catch (e) {}
    }

    // List of workout ids, newest first, for the history list screen.
    static function getIdsNewestFirst() as Array {
        var index = getIndex();
        var out = [] as Array;
        for (var i = index.size() - 1; i >= 0; i--) {
            out.add(index[i]);
        }
        return out;
    }

    // Full workout dictionary for a given id, or null.
    static function get(id as Number) as Dictionary? {
        try {
            var w = Application.Storage.getValue("wh_" + id);
            if (w != null && w instanceof Dictionary) {
                return w as Dictionary;
            }
        } catch (e) {}
        return null;
    }

    static function count() as Number {
        return getIndex().size();
    }

    // Delete an entire workout by id.
    static function deleteWorkout(id as Number) as Void {
        try {
            Application.Storage.deleteValue("wh_" + id);
            var index = getIndex();
            var out = [] as Array;
            for (var i = 0; i < index.size(); i++) {
                if ((index[i] as Number) != id) {
                    out.add(index[i]);
                }
            }
            Application.Storage.setValue(INDEX_KEY, out);
        } catch (e) {}
    }

    // Delete a single set (by index) from a stored workout, recomputing volume.
    // If it was the last set, the whole workout is removed.
    static function deleteSet(id as Number, setIndex as Number) as Void {
        try {
            var w = get(id);
            if (w == null) { return; }
            var sets = w["sets"] as Array;
            if (setIndex < 0 || setIndex >= sets.size()) { return; }

            var out = [] as Array<Dictionary>;
            var vol = 0;
            for (var i = 0; i < sets.size(); i++) {
                if (i == setIndex) { continue; }
                var s = sets[i] as Dictionary;
                out.add(s);
                vol += (s["w"] as Number) * (s["r"] as Number);
            }

            if (out.size() == 0) {
                deleteWorkout(id);
                return;
            }
            w["sets"] = out;
            w["vol"] = vol;
            Application.Storage.setValue("wh_" + id, w);
        } catch (e) {}
    }

    // Update one field of a stored set ("e" name / "r" reps / "w" weight),
    // recomputing the workout's total volume. Silently no-ops on bad input.
    static function updateSet(id as Number, setIndex as Number,
                              field as String, value) as Void {
        try {
            var w = get(id);
            if (w == null) { return; }
            var sets = w["sets"] as Array;
            if (setIndex < 0 || setIndex >= sets.size()) { return; }

            var s = sets[setIndex] as Dictionary;
            s[field] = value;
            sets[setIndex] = s;

            // Recompute volume across all sets.
            var vol = 0;
            for (var i = 0; i < sets.size(); i++) {
                var e = sets[i] as Dictionary;
                vol += (e["w"] as Number) * (e["r"] as Number);
            }
            w["sets"] = sets;
            w["vol"] = vol;
            Application.Storage.setValue("wh_" + id, w);
        } catch (e) {}
    }

    // Wipe all history.
    static function deleteAll() as Void {
        try {
            var index = getIndex();
            for (var i = 0; i < index.size(); i++) {
                Application.Storage.deleteValue("wh_" + (index[i] as Number));
            }
            Application.Storage.setValue(INDEX_KEY, [] as Array);
        } catch (e) {}
    }

    // "Jul 22" style short date from a stored {y,m,d} stamp.
    static function shortDate(workout as Dictionary) as String {
        var months = ["Jan","Feb","Mar","Apr","May","Jun",
                      "Jul","Aug","Sep","Oct","Nov","Dec"];
        try {
            var d = workout["date"] as Dictionary;
            var m = d["m"] as Number;
            var day = d["d"] as Number;
            if (m >= 1 && m <= 12) {
                return months[m - 1] + " " + day;
            }
        } catch (e) {}
        return "--";
    }

    // --- internals ---

    private static function getIndex() as Array {
        try {
            var idx = Application.Storage.getValue(INDEX_KEY);
            if (idx != null && idx instanceof Array) {
                return idx as Array;
            }
        } catch (e) {}
        return [] as Array;
    }

    // Compact date stamp {y,m,d} using the device clock.
    private static function nowStamp() as Dictionary {
        try {
            var info = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
            return { "y" => info.year, "m" => info.month, "d" => info.day };
        } catch (e) {}
        return { "y" => 0, "m" => 0, "d" => 0 };
    }
}
