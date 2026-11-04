# Built-in Finder rollback

Source snapshot before wiring the JavaScript Finder into RTL. Includes the
current local Python and RTL edits; this is not another Git repository.
The working M trial and later N trial bits remain in their original build
folders. Extract only intended files from the ZIP when reverting; preserve
newer user edits. The program Finder build will retain a built-in option.

`jmr_js_sim_server.before-program-finder` is the normal simulator executable
before this change. Copy it back to `sim/sim_build_synth/jmr_js_sim_server` to
compare the previous implementation; also copy `simulator_roms/classic_*.hex` into that directory. The old binary
needs its original label ROM layout.
Do not use this executable as evidence that newer RTL was tested. The current
source can also build the retained desktop with PROGRAM_FINDER=0; see
../../docs/PROGRAM_FINDER_RTL.md.
