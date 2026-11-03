# call_arg_q captures on native-call warmup beat 2. Beat 3 only sets
# opnd3_q; the opcode body's earliest result capture is the following edge.
# The operands therefore have two VM periods, with no extra execution beat.
# SRAM address preparation uses the original stack window, not call_arg_q.
# Simulation checks valid capture, instruction identity and operand age.
# Apply only after synthesis, once the generated VM clock is defined.
set native_arg_regs [get_cells -quiet -hierarchical -filter {NAME =~ *call_arg_q_reg* && IS_SEQUENTIAL}]
# Collection/clock validation runs in vivado_build.tcl, because XDC permits
# timing commands but does not support Tcl control-flow commands such as if.
set_multicycle_path 2 -setup -from $native_arg_regs -to [get_clocks vm_clk]
set_multicycle_path 1 -hold -from $native_arg_regs -to [get_clocks vm_clk]
