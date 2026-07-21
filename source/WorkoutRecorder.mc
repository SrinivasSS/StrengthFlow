import Toybox.Lang;
import Toybox.System;
import Toybox.ActivityRecording;
import Toybox.Activity;
import Toybox.FitContributor;

class WorkoutRecorder {

    private var _session as ActivityRecording.Session?;
    private var _isRecording as Boolean = false;
    private var _isCardio as Boolean = false;

    // FitContributor developer fields. These surface in Garmin Connect (web +
    // export) as "Connect IQ" data on each lap/session. They are NOT the native
    // strength "set" message (that is closed to Connect IQ apps), so they will
    // not populate Garmin's native exercise breakdown -- they appear as
    // developer data fields instead. All creation is guarded: if a device
    // rejects a field (older watches are spotty on STRING fields especially),
    // we null it out and simply skip writing, rather than crash.
    private var _fExercise as FitContributor.Field?;
    private var _fReps as FitContributor.Field?;
    private var _fWeight as FitContributor.Field?;
    private var _fVolume as FitContributor.Field?;

    // Field IDs must be unique per message type.
    private const FID_EXERCISE = 0;
    private const FID_REPS = 1;
    private const FID_WEIGHT = 2;
    private const FID_VOLUME = 3;

    function start(name as String) as Void {
        startStrength(name);
    }

    function startStrength(name as String) as Void {
        if (!(Toybox has :ActivityRecording)) {
            return;
        }

        _session = ActivityRecording.createSession({
            :name => name,
            :sport => Activity.SPORT_TRAINING,
            :subSport => Activity.SUB_SPORT_STRENGTH_TRAINING
        });

        if (_session != null) {
            if (_session.isRecording()) {
                _session.stop();
                _session.discard();
                _session = null;

                _session = ActivityRecording.createSession({
                    :name => name,
                    :sport => Activity.SPORT_TRAINING,
                    :subSport => Activity.SUB_SPORT_STRENGTH_TRAINING
                });
            }

            if (_session != null) {
                createFields(_session);
                _session.start();
                _isRecording = true;
                _isCardio = false;
            }
        }
    }

    function startCardio(exerciseName as String) as Void {
        if (!(Toybox has :ActivityRecording)) { return; }

        var sport = Activity.SPORT_TRAINING;
        var subSport = Activity.SUB_SPORT_CARDIO_TRAINING;

        if (exerciseName.equals("Treadmill Run")) {
            sport = Activity.SPORT_RUNNING;
            subSport = Activity.SUB_SPORT_TREADMILL;
        } else if (exerciseName.equals("Elliptical")) {
            sport = Activity.SPORT_FITNESS_EQUIPMENT;
            subSport = Activity.SUB_SPORT_ELLIPTICAL;
        } else if (exerciseName.equals("Stairmaster")) {
            sport = Activity.SPORT_FITNESS_EQUIPMENT;
            subSport = Activity.SUB_SPORT_STAIR_CLIMBING;
        }

        _session = ActivityRecording.createSession({
            :name => exerciseName,
            :sport => sport,
            :subSport => subSport
        });

        if (_session != null) {
            if (_session.isRecording()) {
                _session.stop();
                _session.discard();
                _session = null;

                _session = ActivityRecording.createSession({
                    :name => exerciseName,
                    :sport => sport,
                    :subSport => subSport
                });
            }

            if (_session != null) {
                _session.start();
                _isRecording = true;
                _isCardio = true;
            }
        }
    }

    // Create per-lap and per-session developer fields. Each is independently
    // guarded so one unsupported field type doesn't block the others.
    private function createFields(session as ActivityRecording.Session) as Void {
        if (!(Toybox has :FitContributor)) { return; }
        if (!(session has :createField)) { return; }

        // Exercise name per set (STRING, LAP). Most fragile field -- isolate it.
        try {
            _fExercise = session.createField(
                "exercise", FID_EXERCISE, FitContributor.DATA_TYPE_STRING,
                { :mesgType => FitContributor.MESG_TYPE_LAP, :count => 24 });
        } catch (e) {
            _fExercise = null;
        }

        // Reps per set (UINT16, LAP).
        try {
            _fReps = session.createField(
                "reps", FID_REPS, FitContributor.DATA_TYPE_UINT16,
                { :mesgType => FitContributor.MESG_TYPE_LAP });
        } catch (e) {
            _fReps = null;
        }

        // Weight per set (UINT16, LAP).
        try {
            var wUnit = WorkoutView.weightUnit();
            _fWeight = session.createField(
                "weight", FID_WEIGHT, FitContributor.DATA_TYPE_UINT16,
                { :mesgType => FitContributor.MESG_TYPE_LAP, :units => wUnit });
        } catch (e) {
            _fWeight = null;
        }

        // Total volume for the whole workout (UINT32, SESSION).
        try {
            _fVolume = session.createField(
                "total_volume", FID_VOLUME, FitContributor.DATA_TYPE_UINT32,
                { :mesgType => FitContributor.MESG_TYPE_SESSION,
                  :units => WorkoutView.weightUnit() });
        } catch (e) {
            _fVolume = null;
        }
    }

    // Record one completed set. Field values are written into the CURRENT lap,
    // then addLap() closes that lap so each set becomes its own lap in the FIT.
    function recordSet(reps as Number, exerciseName as String, weight as Number) as Void {
        try {
            if (_session != null && _isRecording && !_isCardio) {
                if (_fExercise != null) {
                    // Trim to the declared count to avoid an overflow throw.
                    var name = exerciseName;
                    if (name.length() > 24) {
                        name = name.substring(0, 24);
                    }
                    _fExercise.setData(name);
                }
                if (_fReps != null) {
                    _fReps.setData(reps);
                }
                if (_fWeight != null && weight >= 0) {
                    _fWeight.setData(weight);
                }
                _session.addLap();
            }
        } catch (e) {}
    }

    // Set the session-level total volume just before saving.
    function setTotalVolume(volume as Number) as Void {
        try {
            if (_fVolume != null && volume >= 0) {
                _fVolume.setData(volume);
            }
        } catch (e) {}
    }

    function save() as Void {
        try {
            if (_session != null && _isRecording) {
                _session.stop();
                _session.save();
            }
        } catch (e) {}
        _isRecording = false;
        _session = null;
        _fExercise = null;
        _fReps = null;
        _fWeight = null;
        _fVolume = null;
    }

    function discard() as Void {
        try {
            if (_session != null) {
                _session.stop();
                _session.discard();
            }
        } catch (e) {}
        _isRecording = false;
        _session = null;
        _fExercise = null;
        _fReps = null;
        _fWeight = null;
        _fVolume = null;
    }

    function isRecording() as Boolean {
        return _isRecording;
    }

    function isCardioMode() as Boolean {
        return _isCardio;
    }

    function setCurrentExercise(exerciseName as String) as Void {
    }
}
