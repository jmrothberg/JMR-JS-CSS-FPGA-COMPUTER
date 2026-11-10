# Paired with the common-assert / core-qualified audio-release topology.
# These are the only asynchronous boundary pins. Stage1 Q -> stage2 D and
# stage2 Q -> every leaf reset remain fully timed.
set audio_reset_first_d [get_pins -quiet -hierarchical -regexp {^mrst_sync_reg\[0\]/D$}]
set audio_reset_sync_clr [get_pins -quiet -hierarchical -regexp {^mrst_sync_reg\[[01]\]/CLR$}]
if {[llength $audio_reset_first_d] != 1} {error "Audio reset CDC: expected exactly one first-stage D pin"}
if {[llength $audio_reset_sync_clr] != 2} {error "Audio reset CDC: expected exactly two synchronizer CLR pins"}
set_false_path -to $audio_reset_first_d
set_false_path -to $audio_reset_sync_clr
