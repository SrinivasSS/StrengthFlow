import Toybox.Lang;
import Toybox.System;
import Toybox.ActivityRecording;
import Toybox.Activity;

class WorkoutRecorder {

    private var _session as ActivityRecording.Session?;
    private var _isRecording as Boolean = false;
    private var _isCardio as Boolean = false;

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

    function recordSet(reps as Number, exerciseName as String) as Void {
        try {
            if (_session != null && _isRecording && !_isCardio) {
                _session.addLap();
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
