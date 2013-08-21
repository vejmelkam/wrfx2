
all: compile


BEAMFILES = ebin/utils.beam \
        ebin/plist.beam \
        ebin/time-arith.beam \
        ebin/grib-retr.beam \
        ebin/grib-srv.beam \
        ebin/grib-man.beam \
        ebin/log-stream.beam \
        ebin/log-srv.beam \
	ebin/task-exec.beam \
        ebin/grib-app.beam


ebin/%.beam: src/%.jxa
	joxa -p ebin -o ebin -c $<

compile: $(BEAMFILES)


clean:
	rm -f ebin/*.beam
