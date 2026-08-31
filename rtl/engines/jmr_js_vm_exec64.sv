// Hierarchical opcode/native decoder. Same clk as jmr_js_vm.
// Enable when state==S_V64_EXEC. Case text from the parent always_ff.
import jmr_js_vm_pkg::*;
import jmr_value_pkg::*;
module jmr_js_vm_exec64 (
    input  logic clk,
    input  logic rst_n,
    input  logic enable,
    output logic leave_hold,
    input  logic hs_m_ip,
    input  logic hs_m_code,
    input  logic p_pf_block, // parent ctor-scan/redirect machinery armed
    input  logic hs_m_state,
    input  logic hs_m_vsp,
    input  logic hs_m_hp_cmd,
    input  logic hs_m_hp_v64,
    input  logic hs_m_hp_oid,
    input  logic hs_m_hp_aid,
    input  logic hs_m_hp_env,
    input  logic hs_m_hp_eid,
    input  logic hs_m_hp_slot,
    input  logic hs_m_hp_aslot,
    input  logic hs_m_hp_len,
    input  logic hs_m_hp_alen,
    input  logic hs_m_hp_lim,
    input  logic hs_m_hp_key,
    input  logic hs_m_hp_wval,
    input  logic hs_m_hp_rval,
    input  logic hs_m_hp_hit,
    input  logic hs_m_hp_ret,
    input  logic hs_m_hp_phase,
    input  logic hs_m_hp_proto,
    input  logic hs_m_hp_qn,
    input  logic hs_m_hp_qi,
    input  logic hs_m_hp_si,
    input  logic hs_m_hp_ss,
    input  logic hs_m_hp_tn,
    input  logic hs_m_hp_from_stack,
    input  logic hs_m_hp_make_arr,
    input  logic hs_m_hp_vbase,
    input  logic hs_m_hp_spr_w,
    input  logic hs_m_hp_spr_h,
    input  logic hs_m_hp_nat,
    input  logic hs_m_hp_tag,
    input  logic hs_m_hp_qk,
    input  logic hs_m_hp_qv,
    input  logic hs_m_hp_qt,
    input  logic hs_m_valloc_kind,
    input  logic hs_m_valloc_i,
    input  logic hs_m_valloc_arr_n,
    input  logic hs_m_valloc_retried,
    input  logic hs_m_vnat_dom,
    input  logic hs_m_vnat_base,
    input  logic hs_m_valloc_now_fn,
    input  logic hs_m_valloc_bind,
    input  logic hs_m_valloc_bind_src,
    input  logic hs_m_valloc_bind_this,
    input  logic hs_m_valloc_fn_entry,
    input  logic hs_m_valloc_fn_a1,
    input  logic hs_m_valloc_proto,
    input  logic hs_m_valloc_proto_fn,
    input  logic hs_m_valloc_metrics,
    input  logic hs_m_valloc_regex,
    input  logic hs_m_valloc_regex_pack,
    input  logic hs_m_vcall_value,
    input  logic hs_m_vcall_argc,
    input  logic hs_m_vcall_entry,
    input  logic hs_m_vcall_set_this,
    input  logic hs_m_vcall_this,
    input  logic hs_m_vcall_ctor_val,
    input  logic hs_m_vcsp,
    input  logic hs_m_vthis,
    input  logic hs_m_venv,
    input  logic hs_m_vraf_n,
    input  logic hs_m_vlistener_n,
    input  logic hs_m_vgc_halt_after,
    input  logic hs_m_vgc_wait_after,
    input  logic hs_m_vgc_clear_i,
    input  logic hs_m_vgc_qr,
    input  logic hs_m_vgc_qw,
    input  logic hs_m_vdraw_i,
    input  logic hs_m_vdraw_x,
    input  logic hs_m_vdraw_y,
    input  logic hs_m_vdraw_w,
    input  logic hs_m_vdraw_h,
    input  logic hs_m_vdraw_color,
    // Parent FOREACH walks vfe_i / pops nest; exec owns the FFs (CALL_METHOD
    // plants them). Without these pokes, parent vfe_* stay UNDEF and the
    // done path jumps to ip=0 until vfe_sp>=8 (INVADERS fault 3).
    input  logic hs_m_vfe_i,
    input  logic hs_m_vfe_pop,
    output logic aset_win_retried_q,
    output logic [7:0] bind_argc_q,
    output logic [11:0] bind_base_q,
    output logic [15:0] bind_ip_q,
    output logic [7:0] bind_k_q,
    output logic [1:0] bind_mode_q,
    output logic [7:0] bind_n_q,
    output logic bind_rd_arm_q,
    output logic [6:0] bind_ret_q,
    output logic [11:0] bind_src_q,
    output logic [11:0] bind_vsp_next_q,
    output logic [15:0] blit_sh_q,
    output logic [7:0] blit_si_q,
    output logic [15:0] blit_sw_q,
    output logic [15:0] blit_sx_q,
    output logic [15:0] blit_sy_q,
    output logic [2:0] cc_at_q,
    output logic signed [31:0] cc_av_q,
    output logic cc_bok_q,
    output logic [2:0] cc_bt_q,
    output logic signed [31:0] cc_bv_q,
    output logic [3:0] cc_d_q,
    output logic [15:0] cc_h_q,
    output logic [7:0] cc_len_q,
    output logic cc_second_q,
    output logic [1:0] cc_st_q,
    output logic [14:0] code_raddr_q,
    output logic [31:0] opw_out, // run-59: op word as EXEC sees it (captured)
    output logic [7:0] color_q,
    output logic [1:0] ctx_align_q,
    output logic ctx_smooth_q,
    output logic signed [31:0] ctx_sx_q,
    output logic signed [31:0] ctx_sy_q,
    output logic signed [31:0] ctx_tx_q,
    output logic signed [31:0] ctx_ty_q,
    output logic [15:0] dbg_di_hit_q,
    output logic [15:0] dbg_di_miss_q,
    output logic [15:0] dbg_div_n_q,
    output logic [15:0] dbg_json_ovf_q,
    output logic [15:0] dbg_path_ovf_q,
    output logic [7:0] fault_code_q,
    output logic [18:0] fb_dump_addr_q,
    output logic fb_dump_sel_q,
    output logic fb_swap_q,
    output logic [7:0] fill_style_i_q,
    output logic [7:0] stroke_style_i_q,
    output logic [11:0] hp_aid_q,
    output logic [7:0] hp_alen_q,
    output logic [6:0] hp_aslot_q,
    output logic [3:0] hp_cmd_q,
    output logic [9:0] hp_eid_q,
    output logic hp_env_q,
    output logic hp_from_stack_q,
    output logic hp_hit_q,
    output logic [15:0] hp_key_q,
    output logic [5:0] hp_len_q,
    output logic [7:0] hp_lim_q,
    output logic hp_make_arr_q,
    output logic [3:0] hp_nat_q,
    output logic [12:0] hp_oid_q,
    output logic [2:0] hp_phase_q,
    output logic [63:0] hp_proto_q,
    output logic [2:0] hp_qi_q,
    output logic [63:0] hp_qk_pack_q,
    output logic [2:0] hp_qn_q,
    output logic [11:0] hp_qt_pack_q,
    output logic [255:0] hp_qv_pack_q,
    output logic [6:0] hp_ret_q,
    output logic [63:0] hp_rval_q,
    output logic [12:0] hp_si_q,
    output logic [4:0] hp_slot_q,
    output logic [15:0] hp_spr_h_q,
    output logic [15:0] hp_spr_w_q,
    output logic [4:0] hp_ss_q,
    output logic [2:0] hp_tag_q,
    output logic [5:0] hp_tn_q,
    output logic hp_v64_q,
    output logic [11:0] hp_vbase_q,
    output logic [63:0] hp_wval_q,
    output logic imgd_armed_q,
    output logic [9:0] imgd_h_q,
    output logic [18:0] imgd_i_q,
    output logic [18:0] imgd_n_q,
    output logic imgd_v64_q,
    output logic [9:0] imgd_w_q,
    output logic [9:0] imgd_x_q,
    output logic [9:0] imgd_x0_q,
    output logic [9:0] imgd_y_q,
    output logic [9:0] imgd_y0_q,
    output logic [15:0] ip_q,
    output logic [11:0] jn_arr_q,
    output logic [15:0] jn_h_q,
    output logic [15:0] jn_i_q,
    output logic [10:0] jn_res_q,
    output logic [5:0] js_sp_q,
    output logic [2:0] json_pph_q,
    output logic [13:0] json_rp_q,
    output logic [13:0] json_src_q,
    output logic [13:0] json_srclen_q,
    output logic [13:0] json_wp_q,
    output logic looping_q,
    output logic machine_fault_q,
    output logic [63:0] minmax_acc_q,
    output logic [11:0] minmax_base_q,
    output logic minmax_is_min_q,
    output logic [7:0] minmax_k_q,
    output logic [7:0] minmax_n_q,
    output logic namcpy_armed_q,
    output logic namcpy_repl_q,
    output logic namcpy_v64_q,
    output logic [15:0] name_rdaddr_q,
    output logic path_active_q,
    // potential-bugs #49: the parent owns the pc_* arrays that S_PWALK /
    // S_PDO / S_LINE / S_CIRCLE / S_QSEG raster from, but nothing ever wrote
    // them (pc_n stuck at 0 => S_PWALK aborted on its first beat and every
    // path primitive painted nothing). Mirror this exec's writes out.
    // potential-bugs #54: JSON.stringify seeds vjs_val[0] via js_we into
    // exec's OWN copy; the parent S_V64_JSON arm walks the PARENT copy.
    // Mirror the write out (same shape as the #49 pc_we mirror).
    output logic js_we_q,
    output logic [4:0] js_waddr_q,
    output logic [7:0] js_i_wdata_q,
    output logic [2:0] js_ph_wdata_q,
    output logic [63:0] vjs_val_wdata_q,
    output logic pc_we_q,
    output logic [3:0] pc_waddr_q,
    output logic [1:0] pc_op_wdata_q,
    output logic signed [31:0] pc_a1_wdata_q,
    output logic signed [31:0] pc_a2_wdata_q,
    output logic signed [31:0] pc_a3_wdata_q,
    output logic signed [31:0] pc_a4_wdata_q,
    output logic signed [31:0] pc_a5_wdata_q,
    output logic pc_ccw_wdata_q,
    output logic [1:0] path_kind_q,
    output logic path_stroke_q,
    output logic [4:0] pc_n_q,
    output logic [4:0] pi_q,
    output logic repl_did_q,
    output logic repl_g_q,
    output logic [7:0] repl_nlen_q,
    output logic [7:0] repl_pat0_q,
    output logic [7:0] repl_pat1_q,
    output logic [7:0] repl_rch_q,
    output logic [9:0] rh_q,
    output logic running_q,
    output logic [9:0] rw_q,
    output logic [9:0] rx_q,
    output logic [9:0] ry_q,
    output logic signed [31:0] saved_sx_q,
    output logic signed [31:0] saved_sy_q,
    output logic signed [31:0] saved_tx_q,
    output logic signed [31:0] saved_ty_q,
    output logic [4:0] sq_i_q,
    output logic [47:0] sq_rad_q,
    output logic [25:0] sq_rem_q,
    output logic [23:0] sq_root_q,
    output logic [6:0] state_q,
    output logic [6:0] txt_bn_q,
    output logic [3:0] txt_ph_q,
    output logic signed [15:0] txt_px_q,
    output logic signed [15:0] txt_py_q,
    output logic [31:0] txt_val_q,
    output logic [2:0] txt_vt_q,
    output logic v64_concat_q,
    output logic v64_join_q,
    output logic v64_repl_q,
    output logic v64_sqrt_q,
    output logic [7:0] valloc_arr_n_q,
    output logic valloc_bind_q,
    output logic [12:0] valloc_bind_src_q,
    output logic [63:0] valloc_bind_this_q,
    output logic [7:0] valloc_fn_a1_q,
    output logic [15:0] valloc_fn_entry_q,
    output logic [13:0] valloc_i_q,
    output logic [1:0] valloc_kind_q,
    output logic valloc_metrics_q,
    output logic valloc_now_fn_q,
    output logic valloc_proto_q,
    output logic [12:0] valloc_proto_fn_q,
    output logic valloc_regex_q,
    output logic [31:0] valloc_regex_pack_q,
    output logic valloc_retried_q,
    output logic [13:0] varr_next_q,
    output logic [11:0] vcall_argc_q,
    output logic [63:0] vcall_ctor_val_q,
    output logic [15:0] vcall_entry_q,
    output logic vcall_set_this_q,
    output logic [63:0] vcall_this_q,
    output logic vcall_value_q,
    output logic [8:0] vconsole_n_q,
    output logic [7:0] vcsp_q,
    output logic [7:0] vdiv_count_q,
    output logic [52:0] vdiv_den_q,
    output logic signed [12:0] vdiv_exp_q,
    output logic [106:0] vdiv_num_q,
    output logic [106:0] vdiv_quot_q,
    output logic [53:0] vdiv_rem_q,
    output logic vdiv_sign_q,
    output logic [7:0] vdraw_color_q,
    output logic [9:0] vdraw_h_q,
    output logic [18:0] vdraw_i_q,
    output logic [9:0] vdraw_w_q,
    output logic [9:0] vdraw_x_q,
    output logic [9:0] vdraw_y_q,
    output logic [63:0] venv_q,
    output logic [9:0] venv_next_q,
    output logic [63:0] vfe_arr_q,
    output logic [11:0] vfe_base_q,
    output logic [63:0] vfe_fn_q,
    output logic [7:0] vfe_i_q,
    output logic [7:0] vfe_len_q,
    output logic [63:0] vfe_map_q,
    output logic [1:0] vfe_mode_q,
    output logic [15:0] vfe_ret_q,
    output logic [3:0] vfe_sp_q,
    output logic vfree_armed_q,
    output logic vfree_arr_long_q,
    output logic [13:0] vgc_clear_i_q,
    output logic vgc_halt_after_q,
    output logic [13:0] vgc_qr_q,
    output logic [13:0] vgc_qw_q,
    output logic [1:0] vgc_resume_q,
    output logic vgc_wait_after_q,
    output logic vjs_rd_arm_q,
    output logic [4:0] vlistener_n_q,
    output logic [15:0] vmetrics_w_q,
    output logic [11:0] vmod_count_q,
    output logic [52:0] vmod_den_q,
    output logic signed [12:0] vmod_exp_q,
    output logic [52:0] vmod_rem_q,
    output logic vmod_sign_q,
    output logic [11:0] vnat_base_q,
    output logic [2:0] vnat_dom_q,
    output logic vprom_copy_q,
    output logic vprom_done_q,
    output logic [6:0] vprom_ret_q,
    output logic [3:0] vraf_n_q,
    output logic [31:0] vrng_q,
    output logic [11:0] vsp_q,
    output logic vst_hold_win_q,
    output logic vst_refill_arm_q,
    output logic [3:0] vst_refill_i_q,
    output logic [6:0] vst_refill_ret_q,
    output logic [11:0] vst_waddr_q,
    output logic [63:0] vst_wdata_q,
    output logic vst_we_q,
    output logic [63:0] vthis_q,
    output logic [6:0] vtimer_n_q,
    output logic [31:0] vtimer_seq_q,
    output logic [9:0] x_q,
    output logic [9:0] y_q,
    output logic p_clr_busy_q,
    input  logic p_aset_win_retried,
    input  logic [7:0] p_bind_argc,
    input  logic [11:0] p_bind_base,
    input  logic [15:0] p_bind_ip,
    input  logic [7:0] p_bind_k,
    input  logic [1:0] p_bind_mode,
    input  logic [7:0] p_bind_n,
    input  logic p_bind_rd_arm,
    input  logic [6:0] p_bind_ret,
    input  logic [11:0] p_bind_src,
    input  logic [11:0] p_bind_vsp_next,
    input  logic [15:0] p_blit_sh,
    input  logic [7:0] p_blit_si,
    input  logic [15:0] p_blit_sw,
    input  logic [15:0] p_blit_sx,
    input  logic [15:0] p_blit_sy,
    input  logic [2:0] p_cc_at,
    input  logic signed [31:0] p_cc_av,
    input  logic p_cc_bok,
    input  logic [2:0] p_cc_bt,
    input  logic signed [31:0] p_cc_bv,
    input  logic [3:0] p_cc_d,
    input  logic [15:0] p_cc_h,
    input  logic [7:0] p_cc_len,
    input  logic p_cc_second,
    input  logic [1:0] p_cc_st,
    input  logic [14:0] p_code_raddr,
    input  logic [31:0] code_rdata,
    input  logic [7:0] p_color,
    input  logic [1:0] p_ctx_align,
    input  logic p_ctx_smooth,
    input  logic signed [31:0] p_ctx_sx,
    input  logic signed [31:0] p_ctx_sy,
    input  logic signed [31:0] p_ctx_tx,
    input  logic signed [31:0] p_ctx_ty,
    input  logic [15:0] p_dbg_di_hit,
    input  logic [15:0] p_dbg_di_miss,
    input  logic [15:0] p_dbg_div_n,
    input  logic [15:0] p_dbg_json_ovf,
    input  logic [15:0] p_dbg_path_ovf,
    input  logic [15:0] dbg_str_ovf,
    input  logic [7:0] p_fault_code,
    input  logic [18:0] p_fb_dump_addr,
    input  logic p_fb_dump_sel,
    input  logic p_fb_swap,
    input  logic [7:0] p_fill_style_i,
    input  logic [7:0] p_stroke_style_i,
    input  logic [11:0] p_hp_aid,
    input  logic [7:0] p_hp_alen,
    input  logic [6:0] p_hp_aslot,
    input  logic [3:0] p_hp_cmd,
    input  logic [9:0] p_hp_eid,
    input  logic p_hp_env,
    input  logic p_hp_from_stack,
    input  logic p_hp_hit,
    input  logic [15:0] p_hp_key,
    input  logic [5:0] p_hp_len,
    input  logic [7:0] p_hp_lim,
    input  logic p_hp_make_arr,
    input  logic [3:0] p_hp_nat,
    input  logic [12:0] p_hp_oid,
    input  logic [2:0] p_hp_phase,
    input  logic [63:0] p_hp_proto,
    input  logic [2:0] p_hp_qi,
    input  logic [63:0] p_hp_qk_pack,
    input  logic [2:0] p_hp_qn,
    input  logic [11:0] p_hp_qt_pack,
    input  logic [255:0] p_hp_qv_pack,
    input  logic [6:0] p_hp_ret,
    input  logic [63:0] p_hp_rval,
    input  logic [12:0] p_hp_si,
    input  logic [4:0] p_hp_slot,
    input  logic [15:0] p_hp_spr_h,
    input  logic [15:0] p_hp_spr_w,
    input  logic [4:0] p_hp_ss,
    input  logic [2:0] p_hp_tag,
    input  logic [5:0] p_hp_tn,
    input  logic p_hp_v64,
    input  logic [11:0] p_hp_vbase,
    input  logic [63:0] p_hp_wval,
    input  logic [15:0] id_ael,
    input  logic [15:0] id_arc,
    input  logic [15:0] id_assign,
    input  logic [15:0] id_beginpath,
    input  logic [15:0] id_bind,
    input  logic [15:0] id_black,
    input  logic [15:0] id_center,
    input  logic [15:0] id_clearrect,
    input  logic [15:0] id_closepath,
    input  logic [15:0] id_drawimage,
    input  logic [15:0] id_fill,
    input  logic [15:0] id_fillrect,
    input  logic [15:0] id_fillstyle,
    input  logic [15:0] id_font,
    input  logic [15:0] id_disp,
    input  logic [15:0] id_filltext,
    input  logic [15:0] id_filter,
    input  logic [15:0] id_slice, // #40 Array.slice
    input  logic [15:0] id_sort, // #41 Array.sort
    output logic vfe_sort_q,
    input  logic [15:0] id_reduce, // potential-bugs #39: Array.reduce
    output logic vfe_reduce_q,
    output logic vfe_findidx_q,
    input  logic [15:0] id_find,
    input  logic [15:0] id_findindex,
    input  logic [15:0] id_foreach,
    input  logic [15:0] id_getctx,
    input  logic [15:0] id_getimgdata,
    input  logic [15:0] id_gettime,
    input  logic [15:0] id_height,
    input  logic [15:0] id_hex_000,
    input  logic [15:0] id_hex_fff,
    input  logic [15:0] id_imgsmooth,
    input  logic [15:0] id_indexof,
    input  logic [15:0] id_join,
    input  logic [15:0] id_length,
    input  logic [15:0] id_lineto,
    input  logic [15:0] id_quadcurve,   // #38, needs #49 to be visible
    input  logic [15:0] id_map,
    input  logic [15:0] id_measuretext,
    input  logic [15:0] id_moveto,
    input  logic [15:0] id_now,
    input  logic [15:0] id_onload,
    input  logic [15:0] id_pop,
    input  logic [15:0] id_proto,
    input  logic [15:0] id_push,
    input  logic [15:0] id_putimgdata,
    input  logic [15:0] id_replace,
    input  logic [15:0] id_restore,
    input  logic [15:0] id_right,
    input  logic [15:0] id_save,
    input  logic [15:0] id_settransform,
    input  logic [15:0] id_splice,
    input  logic [15:0] id_src,
    input  logic [15:0] id_str_function,
    input  logic [15:0] id_str_number,
    input  logic [15:0] id_str_object,
    input  logic [15:0] id_str_string,
    input  logic [15:0] id_str_undef,
    input  logic [15:0] id_stroke,
    input  logic [15:0] id_strokestyle,
    input  logic [15:0] id_textalign,
    input  logic [15:0] id_textbaseline, // #37
    input  logic [15:0] id_top,
    input  logic [15:0] id_middle,
    input  logic [15:0] id_bottom,
    output logic [1:0] ctx_baseline_q,
    input  logic [15:0] id_translate,
    input  logic [15:0] id_unshift,
    input  logic [15:0] id_white,
    input  logic [15:0] id_width,
    input  logic p_imgd_armed,
    input  logic [9:0] p_imgd_h,
    input  logic [18:0] p_imgd_i,
    input  logic [18:0] p_imgd_n,
    input  logic p_imgd_v64,
    input  logic [9:0] p_imgd_w,
    input  logic [9:0] p_imgd_x,
    input  logic [9:0] p_imgd_x0,
    input  logic [9:0] p_imgd_y,
    input  logic [9:0] p_imgd_y0,
    input  logic [15:0] p_ip,
    input  logic [11:0] p_jn_arr,
    input  logic [15:0] p_jn_h,
    input  logic [15:0] p_jn_i,
    input  logic [10:0] p_jn_res,
    input  logic [5:0] joy_in,
    input  logic [5:0] p_js_sp,
    input  logic [2:0] p_json_pph,
    input  logic [13:0] p_json_rp,
    input  logic [13:0] p_json_src,
    input  logic [13:0] p_json_srclen,
    input  logic [13:0] p_json_wp,
    input  logic p_looping,
    input  logic p_machine_fault,
    input  logic [63:0] p_minmax_acc,
    input  logic [11:0] p_minmax_base,
    input  logic p_minmax_is_min,
    input  logic [7:0] p_minmax_k,
    input  logic [7:0] p_minmax_n,
    input  logic [4:0] n_cls,
    output logic cm_req_q,
    output logic [15:0] cm_key_q,
    output logic [15:0] cm_cls_q,
    input  logic cm_res_we,
    input  logic [15:0] cm_res_mip,
    output logic lsv_req_q,
    output logic [1:0] lsv_op_q,
    output logic [63:0] lsv_ev_q,
    output logic [63:0] lsv_fn_q,
    input  logic lsv_res_we,
    input  logic [2:0] lsv_res,
    input  logic [4:0] lsv_res_n, // new listener count (mask-apply cannot land while held)
    input  logic [15:0] n_consts,
    input  logic [15:0] n_ops,
    input  logic [4:0] n_spr,
    input  logic p_namcpy_armed,
    input  logic p_namcpy_repl,
    input  logic p_namcpy_v64,
    input  logic [15:0] p_name_rdaddr,
    input  logic [15:0] name_blen_rdata,
    input  logic [15:0] name_hash_rdata,
    // Parent-owned JS heap: rdata next clock. Do not combo-index mem[i].
    input  logic [7:0] name_rdata,
    input  logic [15:0] name_off_rdata,
    input  logic [63:0] vvars_rdata,
    input  logic vvar_valid_rdata,
    input  logic [4:0] venv_len_rdata,
    input  logic [11:0] venv_gen_rdata,
    input  logic venv_valid_rdata,
    input  logic [7:0] varr_len_rdata,
    input  logic varr_valid_rdata,
    input  logic [11:0] varr_gen_rdata,
    input  logic varr_long_rdata,
    input  logic [7:0] varr_lidx_rdata,
    input  logic [1:0] vobj_alloc_rdata,
    input  logic [11:0] vobj_gen_rdata,
    input  logic [63:0] vobj_proto_rdata,
    input  logic [15:0] vobj_cls_rdata,
    input  logic [5:0] vobj_len_rdata,
    input  logic [3:0] vobj_builtin_rdata,
    input  logic vfn_valid_rdata,
    input  logic [11:0] vfn_gen_rdata,
    input  logic [63:0] vfn_proto_rdata,
    input  logic [63:0] vfn_env_rdata,
    input  logic [5:0] vfn_nparam_rdata,
    input  logic [15:0] vfn_entry_rdata,
    input  logic [2:0] vfn_flags_rdata,
    input  logic [63:0] vfn_bound_this_rdata,
    input  logic [63:0] vconsts_rdata,
    input  logic [15:0] vframe_rip_rdata,
    input  logic [11:0] vframe_bsp_rdata,
    input  logic vframe_esc_rdata,
    input  logic [63:0] vframe_this_rdata,
    input  logic [63:0] vframe_env_rdata,
    input  logic [63:0] vframe_fn_rdata,
    input  logic [63:0] vframe_ctor_rdata,
    input  logic [7:0] fill_lut_rdata,
    input  logic vtimer_valid_rdata,
    input  logic signed [31:0] vtimer_id_rdata,
    input  logic [15:0] names_n,
    input  logic [15:0] ops_base,
    input  logic p_path_active,
    input  logic [1:0] p_path_kind,
    input  logic p_path_stroke,
    input  logic [4:0] p_pc_n,
    input  logic [4:0] p_pi,
    input  logic p_repl_did,
    input  logic p_repl_g,
    input  logic [7:0] p_repl_nlen,
    input  logic [7:0] p_repl_pat0,
    input  logic [7:0] p_repl_pat1,
    input  logic [7:0] p_repl_rch,
    input  logic [9:0] p_rh,
    input  logic p_running,
    input  logic [9:0] p_rw,
    input  logic [9:0] p_rx,
    input  logic [9:0] p_ry,
    input  logic signed [31:0] p_saved_sx,
    input  logic signed [31:0] p_saved_sy,
    input  logic signed [31:0] p_saved_tx,
    input  logic signed [31:0] p_saved_ty,
    input  logic [10:0] sp,
    input  logic [255:0] spr_hh_pack,
    input  logic [255:0] spr_nid_pack,
    input  logic [255:0] spr_ww_pack,
    input  logic [4:0] p_sq_i,
    input  logic [47:0] p_sq_rad,
    input  logic [25:0] p_sq_rem,
    input  logic [23:0] p_sq_root,
    input  logic [6:0] p_state,
    input  logic this_ok,
    input  logic [6:0] p_txt_bn,
    input  logic [3:0] p_txt_ph,
    input  logic signed [15:0] p_txt_px,
    input  logic signed [15:0] p_txt_py,
    input  logic [31:0] p_txt_val,
    input  logic [2:0] p_txt_vt,
    input  logic p_v64_concat,
    input  logic p_v64_join,
    input  logic p_v64_repl,
    input  logic p_v64_sqrt,
    input  logic [7:0] p_valloc_arr_n,
    input  logic p_valloc_bind,
    input  logic [12:0] p_valloc_bind_src,
    input  logic [63:0] p_valloc_bind_this,
    input  logic [7:0] p_valloc_fn_a1,
    input  logic [15:0] p_valloc_fn_entry,
    input  logic [13:0] p_valloc_i,
    input  logic [1:0] p_valloc_kind,
    input  logic p_valloc_metrics,
    input  logic p_valloc_now_fn,
    input  logic p_valloc_proto,
    input  logic [12:0] p_valloc_proto_fn,
    input  logic p_valloc_regex,
    input  logic [31:0] p_valloc_regex_pack,
    input  logic p_valloc_retried,
    input  logic [8:0] var_this,
    input  logic [13:0] p_varr_next,
    input  logic [11:0] p_vcall_argc,
    input  logic [63:0] p_vcall_ctor_val,
    input  logic [15:0] p_vcall_entry,
    input  logic p_vcall_set_this,
    input  logic [63:0] p_vcall_this,
    input  logic p_vcall_value,
    input  logic [8:0] p_vconsole_n,
    input  logic [7:0] p_vcsp,
    input  logic [7:0] p_vdiv_count,
    input  logic [52:0] p_vdiv_den,
    input  logic signed [12:0] p_vdiv_exp,
    input  logic [106:0] p_vdiv_num,
    input  logic [106:0] p_vdiv_quot,
    input  logic [53:0] p_vdiv_rem,
    input  logic p_vdiv_sign,
    input  logic [7:0] p_vdraw_color,
    input  logic [9:0] p_vdraw_h,
    input  logic [18:0] p_vdraw_i,
    input  logic [9:0] p_vdraw_w,
    input  logic [9:0] p_vdraw_x,
    input  logic [9:0] p_vdraw_y,
    input  logic [63:0] p_venv,
    input  logic [9:0] p_venv_next,
    input  logic [63:0] p_vfe_arr,
    input  logic [11:0] p_vfe_base,
    input  logic [63:0] p_vfe_fn,
    input  logic [7:0] p_vfe_i,
    input  logic [63:0] p_vfe_map,
    input  logic [1:0] p_vfe_mode,
    input  logic [15:0] p_vfe_ret,
    input  logic [3:0] p_vfe_sp,
    input  logic [13:0] vfn_next,
    input  logic [31:0] vframe_no,
    input  logic p_vfree_armed,
    input  logic p_vfree_arr_long,
    input  logic vfree_ok,
    input  logic [13:0] p_vgc_clear_i,
    input  logic p_vgc_halt_after,
    input  logic [13:0] p_vgc_qr,
    input  logic [13:0] p_vgc_qw,
    input  logic [1:0] p_vgc_resume,
    input  logic p_vgc_wait_after,
    input  logic p_vjs_rd_arm,
    input  logic [4:0] p_vlistener_n,
    input  logic [63:0] vmetrics,
    input  logic [15:0] p_vmetrics_w,
    input  logic [11:0] p_vmod_count,
    input  logic [52:0] p_vmod_den,
    input  logic signed [12:0] p_vmod_exp,
    input  logic [52:0] p_vmod_rem,
    input  logic p_vmod_sign,
    input  logic [11:0] p_vnat_base,
    input  logic [2:0] p_vnat_dom,
    input  logic [13:0] vobj_next,
    input  logic p_vprom_copy,
    input  logic p_vprom_done,
    input  logic [6:0] p_vprom_ret,
    input  logic [3:0] p_vraf_n,
    input  logic [31:0] p_vrng,
    input  logic [11:0] p_vsp,
    input  logic p_vst_hold_win,
    input  logic p_vst_refill_arm,
    input  logic [3:0] p_vst_refill_i,
    input  logic [6:0] p_vst_refill_ret,
    input  logic [11:0] p_vst_waddr,
    input  logic [63:0] p_vst_wdata,
    input  logic p_vst_we,
    input  logic [1023:0] vst_win_pack,
    input  logic [63:0] p_vthis,
    input  logic [6:0] p_vtimer_n,
    input  logic [31:0] p_vtimer_seq,
    input  logic [9:0] p_x,
    input  logic [9:0] p_y,
    output logic json_mem_we_q,
    output logic [12:0] json_mem_waddr_q,
    output logic [7:0] json_mem_wdata_q,
    // Parent-owned name SRAM: local raddr, registered *_q (never combo raddr ports).
    output logic [8:0] vvars_raddr_q,
    output logic [9:0] venv_raddr_q,
    output logic [11:0] varr_raddr_q,
    output logic [12:0] vobj_raddr_q,
    output logic [12:0] vfn_raddr_q,
    output logic [9:0] name_off_raddr_q,
    output logic [9:0] fill_lut_raddr_q,
    output logic [6:0] vframe_raddr_q,
    output logic [5:0] vtimer_raddr_q,
    output logic [9:0] vconsts_raddr_q,
    output logic [9:0] name_blen_raddr_q,
    output logic name_blen_we_q,
    output logic [9:0] name_blen_waddr_q,
    output logic [15:0] name_blen_wdata_q,
    output logic [9:0] name_hash_raddr_q,
    output logic name_hash_we_q,
    output logic [9:0] name_hash_waddr_q,
    output logic [15:0] name_hash_wdata_q,
    output logic name_has_we_q,
    output logic [9:0] name_has_waddr_q,
    output logic name_has_wdata_q,
    output logic varr_len_we_q,
    output logic [11:0] varr_len_waddr_q,
    output logic [7:0] varr_len_wdata_q,
    output logic varr_lidx_we_q,
    output logic [11:0] varr_lidx_waddr_q,
    output logic [7:0] varr_lidx_wdata_q,
    output logic varr_long_we_q,
    output logic [11:0] varr_long_waddr_q,
    output logic [31:0] varr_long_wdata_q,
    output logic varr_valid_we_q,
    output logic [11:0] varr_valid_waddr_q,
    output logic [31:0] varr_valid_wdata_q,
    output logic venv_gen_we_q,
    output logic [11:0] venv_gen_waddr_q,
    output logic [11:0] venv_gen_wdata_q,
    output logic venv_len_we_q,
    output logic [11:0] venv_len_waddr_q,
    output logic [4:0] venv_len_wdata_q,
    output logic venv_valid_we_q,
    output logic [11:0] venv_valid_waddr_q,
    output logic [31:0] venv_valid_wdata_q,
    output logic vobj_cls_we_q,
    output logic [11:0] vobj_cls_waddr_q,
    output logic [15:0] vobj_cls_wdata_q,
    output logic vvar_valid_we_q,
    output logic [11:0] vvar_valid_waddr_q,
    output logic [31:0] vvar_valid_wdata_q,
    output logic vvars_we_q,
    // sound(ch,freq,vol,frames,slide) nid 42 — registered poke to the PSG
    // (plan fpga_line-out_psg). snd_tgl flips per call; args hold until the
    // next call, so the PSG's 2FF toggle-sync samples a stable bus.
    output logic        snd_tgl,
    output logic [1:0]  snd_ch,
    output logic [15:0] snd_freq,
    output logic [3:0]  snd_vol,
    output logic [7:0]  snd_frames,
    output logic [7:0]  snd_slide,
    output logic [11:0] vvars_waddr_q,
    output logic [63:0] vvars_wdata_q,
    output logic vframe_we_q,
    output logic [6:0] vframe_waddr_q,
    output logic [15:0] vframe_rip_wdata_q,
    output logic [11:0] vframe_bsp_wdata_q,
    output logic vframe_esc_wdata_q,
    output logic [63:0] vframe_this_wdata_q,
    output logic [63:0] vframe_env_wdata_q,
    output logic [63:0] vframe_fn_wdata_q,
    output logic [63:0] vframe_ctor_wdata_q,
    // Scalar we into parent 1-D banks (no unpacked *_n mux).
    output logic vraf_we_q,
    output logic [2:0] vraf_waddr_q,
    output logic [63:0] vraf_wdata_q,
    output logic vtimer_we_q,
    output logic [5:0] vtimer_waddr_q,
    output logic vtimer_valid_wdata_q,
    output logic signed [31:0] vtimer_due_wdata_q,
    output logic [63:0] vtimer_fn_wdata_q,
    output logic signed [31:0] vtimer_id_wdata_q,
    output logic signed [63:0] vtimer_period_wdata_q,
    // Compact-remove rewrites all 16 FF slots via *_n. Add uses scalar we.
    output logic vst_win0_we_q,
    output logic [63:0] vst_win0_wdata_q,
    input  logic p_clr,
    input  logic p_we,
    input  logic [5:0] p_sel,
    input  logic [15:0] p_addr,
    input  logic [15:0] p_addr2,
    input  logic [63:0] p_data,
    input  logic [63:0] p_data2,
    input  logic [63:0] p_data3,
    input  logic [63:0] p_data4,
    input  logic [63:0] p_data5,
    input  logic p_frame_we,
    input  logic [6:0] p_frame_idx,
    input  logic [15:0] p_frame_rip,
    input  logic [11:0] p_frame_bsp,
    input  logic p_frame_esc,
    input  logic [63:0] p_frame_this,
    input  logic [63:0] p_frame_env,
    input  logic [63:0] p_frame_fn,
    input  logic [63:0] p_frame_ctor
);

    /* run-59 piece 0 (opw_q): EXEC and every non-fetch state read the op
       word from a register captured during S_FETCH_WAIT, not the live code
       BRAM output. Bit-identical today (nothing refetches mid-op); it
       frees the code port so piece 1 can prefetch op N+1 during EXEC
       without the immediates under op N shifting. */
    logic [31:0] opw_q /*verilator public_flat_rd*/;
    logic        opw_cap_n; // piece 1: central-skip capture pulse (comb)
    logic [31:0] dbg_pf_n /*verilator public_flat_rd*/; // skips taken
    logic [15:0] dbg_pf_last_ip /*verilator public_flat_rd*/; // ip of last skip (the op skipped INTO)
    logic        dbg_pfa_c, dbg_pfb_c, dbg_pfc_c; // cascade probes (comb)
    logic [14:0] pf_addr_s; // probe copy
    logic [31:0] dbg_pfa /*verilator public_flat_rd*/;
    logic [31:0] dbg_pfb /*verilator public_flat_rd*/;
    logic [31:0] dbg_pfc /*verilator public_flat_rd*/;
    logic [15:0] dbg_pf_addr /*verilator public_flat_rd*/;
    logic [15:0] dbg_pf_want /*verilator public_flat_rd*/;
    logic [15:0] dbg_pf_mask /*verilator public_flat_rd*/;
    logic [15:0] dbg_pf_want2 /*verilator public_flat_rd*/;
    logic        pf_ok; // port-streams-ip+1 provenance (see mirror + skip)
    logic        post_parent_q; // one-shot: first op after a PARENT-flow
                                // return must take the real fetch-wait (its
                                // beat carries ctor/heap return bookkeeping
                                // — pflip=10 forensics: the skip right after
                                // NEW_OBJ's return underflowed the stack 2
                                // ops later).
    // sound-native poke register: capture args + flip the toggle on the
    // execute beat. rst clears the toggle so the PSG's edge-detect can
    // never fire from a stale power-on level.
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            snd_tgl <= 1'b0; snd_ch <= '0; snd_freq <= '0;
            snd_vol <= '0; snd_frames <= '0; snd_slide <= '0;
        end else if (enable && snd_stb_c) begin
            snd_tgl    <= ~snd_tgl;
            snd_ch     <= snd_ch_c;
            snd_freq   <= snd_freq_c;
            snd_vol    <= snd_vol_c;
            snd_frames <= snd_frames_c;
            snd_slide  <= snd_slide_c;
        end
    end
    always_ff @(posedge clk) begin
        if (enable && opw_cap_n) begin
            dbg_pf_n <= dbg_pf_n + 32'd1;
            dbg_pf_last_ip <= ip_n;
        end
        if (enable && dbg_pfa_c) dbg_pfa <= dbg_pfa + 32'd1;
        if (enable && dbg_pfb_c) dbg_pfb <= dbg_pfb + 32'd1;
        if (enable && dbg_pfb_c && dbg_pf_want == 16'd0) begin
            dbg_pf_addr <= {1'b0, pf_addr_s};
            dbg_pf_want <= {1'b0, 15'(ops_base + ip_n)};
            dbg_pf_mask <= {15'd0, hs_m_code};
        end
        if (enable && dbg_pfc_c) dbg_pfc <= dbg_pfc + 32'd1;
    end
    always_ff @(posedge clk)
        // BEAT-gated (caught by the PF checker on first run: ungated, the
        // capture fired on every CORE clk and overwrote the current op's
        // word mid-beat). All beat registers gate on enable; so does this.
        // fetch-wait: ungated (code_rdata stable all beat; exec64's enable
        // is not asserted under parent-owned states — gating it starved the
        // FIRST op's capture entirely). Skip-capture: beat-edge only.
        if ((state == S_FETCH_WAIT) || (enable && opw_cap_n))
            opw_q <= code_rdata;
    wire [31:0] opw = (state == S_FETCH_WAIT) ? code_rdata : opw_q;
    assign opw_out = opw;
    // piece 1 fast-path class: the prefetched op's operand pre-latch needs
    // only code bits (or nothing) — no vsp-relative addressing, no heap or
    // parent flow at ENTRY. Everything else falls through to the real
    // S_FETCH_WAIT via the central override's address equality.
    function automatic logic pf_safe(input logic [7:0] op);
        pf_safe = (op == OP_LOAD_CONST) || (op == OP_LOAD_VAR) ||
                  (op == OP_STORE_VAR)  || (op == OP_LET_VAR)  ||
                  (op == OP_ADD) || (op == OP_SUB) || (op == OP_MUL) ||
                  (op == OP_DIV) || (op == OP_LT)  || (op == OP_GT)  ||
                  (op == OP_EQ)  || (op == OP_MOD) || (op == OP_NEG) ||
                  (op == OP_NOT) || (op == OP_BIT_OR) || (op == OP_BIT_AND) ||
                  (op == OP_POP) || (op == OP_DUP) ||
                  (op == OP_JUMP) || (op == OP_JIF);
    endfunction


    // Combo D-pins are local. Parent sees *_q only (never-fake-fpga-sim).
    // SRAM we/waddr/wdata are local; parent sees *_q (opcode comb assigns no ports).
    // Dedicated raddr comb writes these locals; always_ff *_q to parent.
    logic [8:0] vvars_raddr;
    logic [9:0] venv_raddr;
    logic [11:0] varr_raddr;
    logic [12:0] vobj_raddr;
    logic [12:0] vfn_raddr;
    logic [9:0] name_off_raddr;
    logic [9:0] fill_lut_raddr;
    logic [6:0] vframe_raddr;
    logic [5:0] vtimer_raddr;
    logic [9:0] vconsts_raddr;
    logic [9:0] name_blen_raddr;
    logic [9:0] name_hash_raddr;
    logic json_mem_we;
    logic [12:0] json_mem_waddr;
    logic [7:0] json_mem_wdata;
    logic name_blen_we;
    logic [9:0] name_blen_waddr;
    logic [15:0] name_blen_wdata;
    logic name_hash_we;
    logic [9:0] name_hash_waddr;
    logic [15:0] name_hash_wdata;
    logic name_has_we;
    logic [9:0] name_has_waddr;
    logic name_has_wdata;
    logic varr_len_we;
    logic [11:0] varr_len_waddr;
    logic [7:0] varr_len_wdata;
    logic varr_lidx_we;
    logic [11:0] varr_lidx_waddr;
    logic [7:0] varr_lidx_wdata;
    logic varr_long_we;
    logic [11:0] varr_long_waddr;
    logic [31:0] varr_long_wdata;
    logic varr_valid_we;
    logic [11:0] varr_valid_waddr;
    logic [31:0] varr_valid_wdata;
    logic venv_gen_we;
    logic [11:0] venv_gen_waddr;
    logic [11:0] venv_gen_wdata;
    logic venv_len_we;
    logic [11:0] venv_len_waddr;
    logic [4:0] venv_len_wdata;
    logic venv_valid_we;
    logic [11:0] venv_valid_waddr;
    logic [31:0] venv_valid_wdata;
    logic vobj_cls_we;
    logic [11:0] vobj_cls_waddr;
    logic [15:0] vobj_cls_wdata;
    logic vvar_valid_we;
    logic [11:0] vvar_valid_waddr;
    logic [31:0] vvar_valid_wdata;
    logic vvars_we;
    logic snd_stb_c; // comb: nid-42 executes this beat (registered below)
    logic [1:0]  snd_ch_c;
    logic [15:0] snd_freq_c;
    logic [3:0]  snd_vol_c;
    logic [7:0]  snd_frames_c;
    logic [7:0]  snd_slide_c;
    logic [11:0] vvars_waddr;
    logic [63:0] vvars_wdata;
    logic vframe_we;
    logic [6:0] vframe_waddr;
    logic [15:0] vframe_rip_wdata;
    logic [11:0] vframe_bsp_wdata;
    logic vframe_esc_wdata;
    logic [63:0] vframe_this_wdata;
    logic [63:0] vframe_env_wdata;
    logic [63:0] vframe_fn_wdata;
    logic [63:0] vframe_ctor_wdata;
    logic vraf_we;
    logic [2:0] vraf_waddr;
    logic [63:0] vraf_wdata;
    logic vtimer_we;
    logic [5:0] vtimer_waddr;
    logic vtimer_valid_wdata;
    logic signed [31:0] vtimer_due_wdata;
    logic [63:0] vtimer_fn_wdata;
    logic signed [31:0] vtimer_id_wdata;
    logic signed [63:0] vtimer_period_wdata;
    logic vst_win0_we;
    logic [63:0] vst_win0_wdata;
    logic cm_win_n;
    logic aset_win_retried_n;
    logic [7:0] bind_argc_n;
    logic [11:0] bind_base_n;
    logic [15:0] bind_ip_n;
    logic [7:0] bind_k_n;
    logic [1:0] bind_mode_n;
    logic [7:0] bind_n_n;
    logic bind_rd_arm_n;
    logic [6:0] bind_ret_n;
    logic [11:0] bind_src_n;
    logic [11:0] bind_vsp_next_n;
    logic [15:0] blit_sh_n;
    logic [7:0] blit_si_n;
    logic [15:0] blit_sw_n;
    logic [15:0] blit_sx_n;
    logic [15:0] blit_sy_n;
    logic [2:0] cc_at_n;
    logic signed [31:0] cc_av_n;
    logic cc_bok_n;
    logic [2:0] cc_bt_n;
    logic signed [31:0] cc_bv_n;
    logic [3:0] cc_d_n;
    logic [15:0] cc_h_n;
    logic [7:0] cc_len_n;
    logic cc_second_n;
    logic [1:0] cc_st_n;
    logic [14:0] code_raddr_n;
    logic [7:0] color_n;
    logic [1:0] ctx_align_n;
    logic ctx_smooth_n;
    logic signed [31:0] ctx_sx_n;
    logic signed [31:0] ctx_sy_n;
    logic signed [31:0] ctx_tx_n;
    logic signed [31:0] ctx_ty_n;
    logic [15:0] dbg_di_hit_n;
    logic [15:0] dbg_di_miss_n;
    logic [15:0] dbg_div_n_n;
    logic [15:0] dbg_json_ovf_n;
    logic [15:0] dbg_path_ovf_n;
    logic [7:0] fault_code_n;
    logic [18:0] fb_dump_addr_n;
    logic fb_dump_sel_n;
    logic fb_swap_n;
    logic [7:0] fill_style_i_n;
    logic [7:0] stroke_style_i_n;
    logic [11:0] hp_aid_n;
    logic [7:0] hp_alen_n;
    logic [6:0] hp_aslot_n;
    logic [3:0] hp_cmd_n;
    logic [9:0] hp_eid_n;
    logic hp_env_n;
    logic hp_from_stack_n;
    logic hp_hit_n;
    logic [15:0] hp_key_n;
    logic [5:0] hp_len_n;
    logic [7:0] hp_lim_n;
    logic hp_make_arr_n;
    logic [3:0] hp_nat_n;
    logic [12:0] hp_oid_n;
    logic [2:0] hp_phase_n;
    logic [63:0] hp_proto_n;
    logic [2:0] hp_qi_n;
    logic [2:0] hp_qn_n;
    logic [6:0] hp_ret_n;
    logic [63:0] hp_rval_n;
    logic [12:0] hp_si_n;
    logic [4:0] hp_slot_n;
    logic [15:0] hp_spr_h_n;
    logic [15:0] hp_spr_w_n;
    logic [4:0] hp_ss_n;
    logic [2:0] hp_tag_n;
    logic [5:0] hp_tn_n;
    logic hp_v64_n;
    logic [11:0] hp_vbase_n;
    logic [63:0] hp_wval_n;
    logic imgd_armed_n;
    logic [9:0] imgd_h_n;
    logic [18:0] imgd_i_n;
    logic [18:0] imgd_n_n;
    logic imgd_v64_n;
    logic [9:0] imgd_w_n;
    logic [9:0] imgd_x_n;
    logic [9:0] imgd_x0_n;
    logic [9:0] imgd_y_n;
    logic [9:0] imgd_y0_n;
    logic [15:0] ip_n;
    logic [11:0] jn_arr_n;
    logic [15:0] jn_h_n;
    logic [15:0] jn_i_n;
    logic [10:0] jn_res_n;
    logic [5:0] js_sp_n;
    logic [2:0] json_pph_n;
    logic [13:0] json_rp_n;
    logic [13:0] json_src_n;
    logic [13:0] json_srclen_n;
    logic [13:0] json_wp_n;
    logic looping_n;
    logic machine_fault_n;
    logic [63:0] minmax_acc_n;
    logic [11:0] minmax_base_n;
    logic minmax_is_min_n;
    logic [7:0] minmax_k_n;
    logic [7:0] minmax_n_n;
    logic namcpy_armed_n;
    logic namcpy_repl_n;
    logic namcpy_v64_n;
    logic [15:0] name_rdaddr_n;
    logic path_active_n;
    logic [1:0] path_kind_n;
    logic path_stroke_n;
    logic [4:0] pc_n_n;
    logic [4:0] pi_n;
    logic repl_did_n;
    logic repl_g_n;
    logic [7:0] repl_nlen_n;
    logic [7:0] repl_pat0_n;
    logic [7:0] repl_pat1_n;
    logic [7:0] repl_rch_n;
    logic [9:0] rh_n;
    logic running_n;
    logic [9:0] rw_n;
    logic [9:0] rx_n;
    logic [9:0] ry_n;
    logic signed [31:0] saved_sx_n;
    logic signed [31:0] saved_sy_n;
    logic signed [31:0] saved_tx_n;
    logic signed [31:0] saved_ty_n;
    logic [4:0] sq_i_n;
    logic [47:0] sq_rad_n;
    logic [25:0] sq_rem_n;
    logic [23:0] sq_root_n;
    logic [6:0] state_n;
    logic [6:0] txt_bn_n;
    logic [3:0] txt_ph_n;
    logic signed [15:0] txt_px_n;
    logic signed [15:0] txt_py_n;
    logic [31:0] txt_val_n;
    logic [2:0] txt_vt_n;
    logic v64_concat_n;
    logic v64_join_n;
    logic v64_repl_n;
    logic v64_sqrt_n;
    logic [7:0] valloc_arr_n_n;
    logic valloc_bind_n;
    logic [12:0] valloc_bind_src_n;
    logic [63:0] valloc_bind_this_n;
    logic [7:0] valloc_fn_a1_n;
    logic [15:0] valloc_fn_entry_n;
    logic [13:0] valloc_i_n;
    logic [1:0] valloc_kind_n;
    logic valloc_metrics_n;
    logic valloc_now_fn_n;
    logic valloc_proto_n;
    logic [12:0] valloc_proto_fn_n;
    logic valloc_regex_n;
    logic [31:0] valloc_regex_pack_n;
    logic valloc_retried_n;
    logic [13:0] varr_next_n;
    logic [11:0] vcall_argc_n;
    logic [63:0] vcall_ctor_val_n;
    // ALLOC p_frame_we plants the instance here (SRAM rdata lags RET combo).
    logic [63:0] ctor_cur_n;
    logic [7:0] ctor_csp_n;
    logic [15:0] vcall_entry_n;
    logic vcall_set_this_n;
    logic [63:0] vcall_this_n;
    logic vcall_value_n;
    logic [8:0] vconsole_n_n;
    logic [7:0] vcsp_n;
    logic [7:0] vdiv_count_n;
    logic [52:0] vdiv_den_n;
    logic signed [12:0] vdiv_exp_n;
    logic [106:0] vdiv_num_n;
    logic [106:0] vdiv_quot_n;
    logic [53:0] vdiv_rem_n;
    logic vdiv_sign_n;
    logic [7:0] vdraw_color_n;
    logic [9:0] vdraw_h_n;
    logic [18:0] vdraw_i_n;
    logic [9:0] vdraw_w_n;
    logic [9:0] vdraw_x_n;
    logic [9:0] vdraw_y_n;
    logic [63:0] venv_n;
    logic [9:0] venv_next_n;
    logic [63:0] vfe_arr_n;
    logic [11:0] vfe_base_n;
    logic [63:0] vfe_fn_n;
    logic [7:0] vfe_i_n;
    logic [7:0] vfe_len_n;
    logic [63:0] vfe_map_n;
    logic [1:0] vfe_mode_n;
    logic [15:0] vfe_ret_n;
    logic [3:0] vfe_sp_n;
    logic vfree_armed_n;
    logic vfree_arr_long_n;
    logic [13:0] vgc_clear_i_n;
    logic vgc_halt_after_n;
    logic [13:0] vgc_qr_n;
    logic [13:0] vgc_qw_n;
    logic [1:0] vgc_resume_n;
    logic vgc_wait_after_n;
    logic vjs_rd_arm_n;
    logic [4:0] vlistener_n_n;
    logic [15:0] vmetrics_w_n;
    logic [11:0] vmod_count_n;
    logic [52:0] vmod_den_n;
    logic signed [12:0] vmod_exp_n;
    logic [52:0] vmod_rem_n;
    logic vmod_sign_n;
    logic [11:0] vnat_base_n;
    logic [2:0] vnat_dom_n;
    logic vprom_copy_n;
    logic vprom_done_n;
    logic [6:0] vprom_ret_n;
    logic [3:0] vraf_n_n;
    logic [31:0] vrng_n;
    logic [11:0] vsp_n;
    logic vst_hold_win_n;
    logic vst_refill_arm_n;
    logic [3:0] vst_refill_i_n;
    logic [6:0] vst_refill_ret_n;
    logic [11:0] vst_waddr_n;
    logic [63:0] vst_wdata_n;
    logic vst_we_n;
    logic [63:0] vthis_n;
    logic [6:0] vtimer_n_n;
    logic [31:0] vtimer_seq_n;
    logic [9:0] x_n;
    logic [9:0] y_n;

    // 2026-08-22: the class tables left this exec. Method lookup is a
    // request to the parent's sequential scanner: cm_scan/cm_key/cm_cls
    // are exported as a level request; the parent walks its own tables
    // and answers on cm_res_we/cm_res_mip (comb inputs — a poke would be
    // overwritten by the *_n register updates in the same beat).
    // json_mem lives in parent (we_q). Combo next-state stays inside exec.
    logic hp_q_we;
    logic [1:0] hp_q_waddr;
    logic [15:0] hp_qk_wdata;
    logic [2:0] hp_qt_wdata;
    logic [63:0] hp_qv_wdata;
    logic js_we;
    logic [4:0] js_waddr;
    logic [7:0] js_i_wdata;
    logic [2:0] js_ph_wdata;
    logic [63:0] vjs_val_wdata;
    logic pc_we;
    logic [3:0] pc_waddr;
    // #49 mirror taps (combinational, same values the local arrays take).
    assign js_we_q        = js_we;
    assign js_waddr_q     = js_waddr;
    assign js_i_wdata_q   = js_i_wdata;
    assign js_ph_wdata_q  = js_ph_wdata;
    assign vjs_val_wdata_q = vjs_val_wdata;
    assign pc_we_q        = pc_we;
    assign pc_waddr_q     = pc_waddr;
    assign pc_op_wdata_q  = pc_op_wdata;
    assign pc_a1_wdata_q  = pc_a1_wdata;
    assign pc_a2_wdata_q  = pc_a2_wdata;
    assign pc_a3_wdata_q  = pc_a3_wdata;
    assign pc_a4_wdata_q  = pc_a4_wdata;
    assign pc_a5_wdata_q  = pc_a5_wdata;
    assign pc_ccw_wdata_q = pc_ccw_wdata;
    logic signed [31:0] pc_a1_wdata, pc_a2_wdata, pc_a3_wdata, pc_a4_wdata, pc_a5_wdata;
    logic pc_ccw_wdata;
    logic [1:0] pc_op_wdata;
    logic vfe_s_we;
    logic [2:0] vfe_s_waddr;
    logic [63:0] vfe_arr_s_wdata, vfe_fn_s_wdata, vfe_map_s_wdata;
    logic [11:0] vfe_base_s_wdata;
    logic [7:0] vfe_i_s_wdata;
    logic [7:0] vfe_len_s_wdata;
    logic [1:0] vfe_mode_s_wdata;
    logic [15:0] vfe_ret_s_wdata;
    // Parent SRAM raddr/rdata are module ports. Operand arm (opnd_q) waits
    // the registered rdata beat. Do not declare a second copy here.
    // leftover 3 clocks raddr_q on EXEC; parent rdata is the next clock after
    // that. One opnd beat presented the new raddr but LOAD_CONST still saw
    // the previous const (fillRect 8x8 → 10x8, n=f() not 7). Second beat
    // lets rdata settle. Extra clocks are silicon (never-fake-fpga-sim).
    logic opnd_q /*verilator public_flat_rd*/, opnd_n;
    logic opnd2_q /*verilator public_flat_rd*/, opnd2_n;
    // ALLOC (getElementById / FRAME_RAF env) freezes raddr_q. Parent
    // vfn_valid_rdata is the clock after raddr_q, and exec samples that
    // rdata one more clock after that (rAF fault 4 / 45 with vf0=1).
    logic opnd3_q /*verilator public_flat_rd*/, opnd3_n;
    // Class method lookup: one (c,m) per clock. Opcode comb must not
    // index cls_mip[][] (exec32 cm_scan twin).
    logic cm_scan /*verilator public_flat_rd*/, cm_scan_n, cm_armed, cm_armed_n, cm_done, cm_done_n;
    assign cm_req_q = cm_scan;
    assign cm_key_q = cm_key;
    assign cm_cls_q = cm_cls;
    // Listener ops (add/remove) are served by the PARENT's sequential
    // walk over its single table — the four exec-side table copies and
    // their one-beat 16-way scans are gone (census: ~26.9k LUTs).
    logic lsv_scan /*verilator public_flat_rd*/, lsv_scan_n;
    logic [1:0] lsv_op, lsv_op_n;
    logic [63:0] lsv_ev, lsv_ev_n, lsv_fn, lsv_fn_n, lsv_push, lsv_push_n;
    logic [11:0] lsv_base, lsv_base_n;
    assign lsv_req_q = lsv_scan;
    assign lsv_op_q = lsv_op;
    assign lsv_ev_q = lsv_ev;
    assign lsv_fn_q = lsv_fn;
    // 53-beat shift-add FP multiply engines (one per requester class):
    // OP_MUL (fpm_*) and the frame-clock Date.now product (nwm_*).
    logic         fpm_busy, fpm_req, fpm_req_n;
    logic [5:0]   fpm_cnt;
    logic [105:0] fpm_acc, fpm_mcand;
    logic [52:0]  fpm_mplier;
    logic         fpm_sign, fpm_sign_n;
    logic [10:0]  fpm_ea, fpm_eb, fpm_ea_n, fpm_eb_n;
    logic         fpm_start_n;
    logic [52:0]  fpm_ma_n, fpm_mb_n;
    logic         nwm_busy;
    logic [5:0]   nwm_cnt;
    logic [105:0] nwm_acc, nwm_mcand;
    logic [52:0]  nwm_mplier;
    logic [10:0]  nwm_ea, nwm_eb;
    logic         nwm_sign;
    logic [63:0]  now_v64_q;
    logic [31:0]  nwm_vf_q;
    // Method-lookup cache: 8 entries of (cls,key)->mip, misses (FFFF)
    // included — builtin calls (ctx.fillRect, arr.push) repeat the same
    // miss every frame. Hit answers in the same beat the CALL op runs, so
    // repeated calls cost exactly what the one-clock CAM did. Insert on
    // parent result; invalidate on p_clr and on class-table pokes.
    logic [15:0] cmc_cls [0:7];
    logic [15:0] cmc_key [0:7];
    logic [15:0] cmc_mip [0:7];
    logic [7:0]  cmc_valid;
    logic [2:0]  cmc_wp;
    logic        cmc_hit;
    logic [15:0] cmc_hit_mip;
    always_comb begin
        cmc_hit = 1'b0;
        cmc_hit_mip = 16'hFFFF;
        for (int k = 0; k < 8; k++)
            if (cmc_valid[k] && cmc_cls[k] == vobj_cls_rdata &&
                cmc_key[k] == opw[23:8]) begin
                cmc_hit = 1'b1;
                cmc_hit_mip = cmc_mip[k];
            end
    end
    logic [3:0] cm_c, cm_c_n, cm_m, cm_m_n;
    logic [15:0] cm_mip, cm_mip_n, cm_key, cm_key_n, cm_cls, cm_cls_n;
    // String.replace needs two name_hash_tbl keys; one SRAM port → extra beat.
    logic hash2_q /*verilator public_flat_rd*/, hash2_n;
    // venv_valid_rdata settle counter (parent Port A lag after a ctor
    // return pokes venv). Counts beats, then trusts the bit.
    logic [2:0] venvw_q /*verilator public_flat_rd*/, venvw_n;
    // Bring-up: which fault arm fired (source line of the assignment).
    logic [15:0] fault_site /*verilator public_flat_rd*/, fault_site_n;
    logic [6:0] tmr_i_q, tmr_i_n;
    logic [1:0] tmr_arm_q, tmr_arm_n; // #66b: 2-beat settle per slot
    logic tmr_found_q, tmr_found_n;
    logic [6:0] tmr_slot_q, tmr_slot_n;
    logic [11:0] clr_i;
    logic clr_busy;
    localparam int CLR_LIM = MAX_ARR;

    // Parent clr/poke + exec we into local copies. No opcode rewrite.
    // p_clr walks one index per clock (SRAM has no parallel clear).
    logic p_clr_busy;
    assign p_clr_busy = clr_busy | p_clr;

    // Working regs clock here. Parent sees *_q / leave_hold, not combo *_n.
    logic aset_win_retried;
    assign aset_win_retried_q = aset_win_retried;
    // CALL_METH fillRect: one SRAM window refill when obj_ok is false.
    logic cm_win /*verilator public_flat_rd*/;
    logic [7:0] bind_argc;
    assign bind_argc_q = bind_argc;
    logic [11:0] bind_base;
    assign bind_base_q = bind_base;
    logic [15:0] bind_ip;
    assign bind_ip_q = bind_ip;
    logic [7:0] bind_k;
    assign bind_k_q = bind_k;
    logic [1:0] bind_mode;
    assign bind_mode_q = bind_mode;
    logic [7:0] bind_n;
    assign bind_n_q = bind_n;
    logic bind_rd_arm;
    assign bind_rd_arm_q = bind_rd_arm;
    logic [6:0] bind_ret;
    assign bind_ret_q = bind_ret;
    logic [11:0] bind_src;
    assign bind_src_q = bind_src;
    logic [11:0] bind_vsp_next;
    assign bind_vsp_next_q = bind_vsp_next;
    logic [15:0] blit_sh;
    assign blit_sh_q = blit_sh;
    logic [7:0] blit_si;
    assign blit_si_q = blit_si;
    logic [15:0] blit_sw;
    assign blit_sw_q = blit_sw;
    logic [15:0] blit_sx;
    assign blit_sx_q = blit_sx;
    logic [15:0] blit_sy;
    assign blit_sy_q = blit_sy;
    logic [2:0] cc_at;
    assign cc_at_q = cc_at;
    logic signed [31:0] cc_av;
    assign cc_av_q = cc_av;
    logic cc_bok;
    assign cc_bok_q = cc_bok;
    logic [2:0] cc_bt;
    assign cc_bt_q = cc_bt;
    logic signed [31:0] cc_bv;
    assign cc_bv_q = cc_bv;
    logic [3:0] cc_d;
    assign cc_d_q = cc_d;
    logic [15:0] cc_h;
    assign cc_h_q = cc_h;
    logic [7:0] cc_len;
    assign cc_len_q = cc_len;
    logic cc_second;
    assign cc_second_q = cc_second;
    logic [1:0] cc_st;
    assign cc_st_q = cc_st;
    logic [14:0] code_raddr;
    assign code_raddr_q = code_raddr;
    logic [7:0] color;
    assign color_q = color;
    logic [1:0] ctx_align;
    assign ctx_align_q = ctx_align;
    // #37 textBaseline: 0=alphabetic 1=top 2=middle 3=bottom
    logic [1:0] ctx_baseline, ctx_baseline_n;
    assign ctx_baseline_q = ctx_baseline;
    logic ctx_smooth;
    assign ctx_smooth_q = ctx_smooth;
    logic signed [31:0] ctx_sx;
    assign ctx_sx_q = ctx_sx;
    logic signed [31:0] ctx_sy;
    assign ctx_sy_q = ctx_sy;
    logic signed [31:0] ctx_tx;
    assign ctx_tx_q = ctx_tx;
    logic signed [31:0] ctx_ty;
    assign ctx_ty_q = ctx_ty;
    logic [15:0] dbg_di_hit;
    assign dbg_di_hit_q = dbg_di_hit;
    logic [15:0] dbg_di_miss;
    assign dbg_di_miss_q = dbg_di_miss;
    logic [15:0] dbg_div_n;
    assign dbg_div_n_q = dbg_div_n;
    logic [15:0] dbg_json_ovf;
    assign dbg_json_ovf_q = dbg_json_ovf;
    logic [15:0] dbg_path_ovf;
    assign dbg_path_ovf_q = dbg_path_ovf;
    logic [7:0] fault_code /*verilator public_flat_rd*/;
    assign fault_code_q = fault_code;
    logic [18:0] fb_dump_addr;
    assign fb_dump_addr_q = fb_dump_addr;
    logic fb_dump_sel;
    assign fb_dump_sel_q = fb_dump_sel;
    logic fb_swap;
    assign fb_swap_q = fb_swap;
    logic [7:0] fill_style_i;
    assign fill_style_i_q = fill_style_i;
    logic [7:0] stroke_style_i;
    assign stroke_style_i_q = stroke_style_i;
    logic [11:0] hp_aid;
    assign hp_aid_q = hp_aid;
    logic [7:0] hp_alen;
    assign hp_alen_q = hp_alen;
    logic [6:0] hp_aslot;
    assign hp_aslot_q = hp_aslot;
    logic [3:0] hp_cmd;
    assign hp_cmd_q = hp_cmd;
    logic [9:0] hp_eid /*verilator public_flat_rd*/;
    assign hp_eid_q = hp_eid;
    logic hp_env;
    assign hp_env_q = hp_env;
    logic hp_from_stack;
    assign hp_from_stack_q = hp_from_stack;
    logic hp_hit;
    assign hp_hit_q = hp_hit;
    logic [15:0] hp_key /*verilator public_flat_rd*/;
    assign hp_key_q = hp_key;
    logic [5:0] hp_len;
    assign hp_len_q = hp_len;
    logic [7:0] hp_lim;
    assign hp_lim_q = hp_lim;
    logic hp_make_arr;
    assign hp_make_arr_q = hp_make_arr;
    logic [3:0] hp_nat;
    assign hp_nat_q = hp_nat;
    logic [12:0] hp_oid;
    assign hp_oid_q = hp_oid;
    logic [2:0] hp_phase;
    assign hp_phase_q = hp_phase;
    logic [63:0] hp_proto;
    assign hp_proto_q = hp_proto;
    logic [2:0] hp_qi;
    assign hp_qi_q = hp_qi;
    logic [15:0] hp_qk [0:3];
    logic [2:0] hp_qn;
    assign hp_qn_q = hp_qn;
    logic [2:0] hp_qt [0:3];
    logic [63:0] hp_qv [0:3];
    genvar gi_hpq;
    generate
        for (gi_hpq = 0; gi_hpq < 4; gi_hpq++) begin : g_hp_pack
            assign hp_qk_pack_q[16*gi_hpq +: 16] = hp_qk[gi_hpq];
            assign hp_qt_pack_q[3*gi_hpq +: 3] = hp_qt[gi_hpq];
            assign hp_qv_pack_q[64*gi_hpq +: 64] = hp_qv[gi_hpq];
        end
    endgenerate
    logic [6:0] hp_ret;
    assign hp_ret_q = hp_ret;
    logic [63:0] hp_rval;
    assign hp_rval_q = hp_rval;
    logic [12:0] hp_si;
    assign hp_si_q = hp_si;
    logic [4:0] hp_slot;
    assign hp_slot_q = hp_slot;
    logic [15:0] hp_spr_h;
    assign hp_spr_h_q = hp_spr_h;
    logic [15:0] hp_spr_w;
    assign hp_spr_w_q = hp_spr_w;
    logic [4:0] hp_ss;
    assign hp_ss_q = hp_ss;
    logic [2:0] hp_tag;
    assign hp_tag_q = hp_tag;
    logic [5:0] hp_tn;
    assign hp_tn_q = hp_tn;
    logic hp_v64;
    assign hp_v64_q = hp_v64;
    logic [11:0] hp_vbase;
    assign hp_vbase_q = hp_vbase;
    logic [63:0] hp_wval;
    assign hp_wval_q = hp_wval;
    logic imgd_armed;
    assign imgd_armed_q = imgd_armed;
    logic [9:0] imgd_h;
    assign imgd_h_q = imgd_h;
    logic [18:0] imgd_i;
    assign imgd_i_q = imgd_i;
    logic [18:0] imgd_n;
    assign imgd_n_q = imgd_n;
    logic imgd_v64;
    assign imgd_v64_q = imgd_v64;
    logic [9:0] imgd_w;
    assign imgd_w_q = imgd_w;
    logic [9:0] imgd_x;
    assign imgd_x_q = imgd_x;
    logic [9:0] imgd_x0;
    assign imgd_x0_q = imgd_x0;
    logic [9:0] imgd_y;
    assign imgd_y_q = imgd_y;
    logic [9:0] imgd_y0;
    assign imgd_y0_q = imgd_y0;
    logic [15:0] ip /*verilator public_flat_rd*/;
    assign ip_q = ip;
    logic [11:0] jn_arr;
    assign jn_arr_q = jn_arr;
    logic [15:0] jn_h;
    assign jn_h_q = jn_h;
    logic [15:0] jn_i;
    assign jn_i_q = jn_i;
    logic [10:0] jn_res;
    assign jn_res_q = jn_res;
    logic [7:0] js_i [0:JSON_STK-1];
    logic [2:0] js_ph [0:JSON_STK-1];
    logic [5:0] js_sp;
    assign js_sp_q = js_sp;
    logic [2:0] json_pph;
    assign json_pph_q = json_pph;
    logic [13:0] json_rp;
    assign json_rp_q = json_rp;
    logic [13:0] json_src;
    assign json_src_q = json_src;
    logic [13:0] json_srclen;
    assign json_srclen_q = json_srclen;
    logic [13:0] json_wp;
    assign json_wp_q = json_wp;
    logic looping;
    assign looping_q = looping;
    logic machine_fault /*verilator public_flat_rd*/;
    assign machine_fault_q = machine_fault;
    logic [63:0] minmax_acc;
    assign minmax_acc_q = minmax_acc;
    logic [11:0] minmax_base;
    assign minmax_base_q = minmax_base;
    logic minmax_is_min;
    assign minmax_is_min_q = minmax_is_min;
    logic [7:0] minmax_k;
    assign minmax_k_q = minmax_k;
    logic [7:0] minmax_n;
    assign minmax_n_q = minmax_n;
    logic namcpy_armed;
    assign namcpy_armed_q = namcpy_armed;
    logic namcpy_repl;
    assign namcpy_repl_q = namcpy_repl;
    logic namcpy_v64;
    assign namcpy_v64_q = namcpy_v64;
    logic [15:0] name_rdaddr;
    assign name_rdaddr_q = name_rdaddr;
    logic path_active;
    assign path_active_q = path_active;
    logic [1:0] path_kind;
    assign path_kind_q = path_kind;
    logic path_stroke;
    assign path_stroke_q = path_stroke;
    logic signed [31:0] pc_a1 [0:PATH_MAX-1];
    logic signed [31:0] pc_a2 [0:PATH_MAX-1];
    logic signed [31:0] pc_a3 [0:PATH_MAX-1];
    logic signed [31:0] pc_a4 [0:PATH_MAX-1];
    logic signed [31:0] pc_a5 [0:PATH_MAX-1];
    logic pc_ccw [0:PATH_MAX-1];
    logic [4:0] pc_n;
    assign pc_n_q = pc_n;
    logic [1:0] pc_op [0:PATH_MAX-1];
    logic [4:0] pi;
    assign pi_q = pi;
    logic repl_did;
    assign repl_did_q = repl_did;
    logic repl_g;
    assign repl_g_q = repl_g;
    logic [7:0] repl_nlen;
    assign repl_nlen_q = repl_nlen;
    logic [7:0] repl_pat0;
    assign repl_pat0_q = repl_pat0;
    logic [7:0] repl_pat1;
    assign repl_pat1_q = repl_pat1;
    logic [7:0] repl_rch;
    assign repl_rch_q = repl_rch;
    logic [9:0] rh;
    assign rh_q = rh;
    logic running;
    assign running_q = running;
    logic [9:0] rw;
    assign rw_q = rw;
    logic [9:0] rx;
    assign rx_q = rx;
    logic [9:0] ry;
    assign ry_q = ry;
    logic signed [31:0] saved_sx;
    assign saved_sx_q = saved_sx;
    logic signed [31:0] saved_sy;
    assign saved_sy_q = saved_sy;
    logic signed [31:0] saved_tx;
    assign saved_tx_q = saved_tx;
    logic signed [31:0] saved_ty;
    assign saved_ty_q = saved_ty;
    logic [4:0] sq_i;
    assign sq_i_q = sq_i;
    logic [47:0] sq_rad;
    assign sq_rad_q = sq_rad;
    logic [25:0] sq_rem;
    assign sq_rem_q = sq_rem;
    logic [23:0] sq_root;
    assign sq_root_q = sq_root;
    logic [6:0] state;
    assign state_q = state;
    logic [6:0] txt_bn;
    assign txt_bn_q = txt_bn;
    logic [3:0] txt_ph;
    assign txt_ph_q = txt_ph;
    logic signed [15:0] txt_px;
    assign txt_px_q = txt_px;
    logic signed [15:0] txt_py;
    assign txt_py_q = txt_py;
    logic [31:0] txt_val;
    assign txt_val_q = txt_val;
    logic [2:0] txt_vt;
    assign txt_vt_q = txt_vt;
    logic v64_concat;
    assign v64_concat_q = v64_concat;
    logic v64_join;
    assign v64_join_q = v64_join;
    logic v64_repl;
    assign v64_repl_q = v64_repl;
    logic v64_sqrt;
    assign v64_sqrt_q = v64_sqrt;
    logic [7:0] valloc_arr_n;
    assign valloc_arr_n_q = valloc_arr_n;
    logic valloc_bind;
    assign valloc_bind_q = valloc_bind;
    logic [12:0] valloc_bind_src;
    assign valloc_bind_src_q = valloc_bind_src;
    logic [63:0] valloc_bind_this;
    assign valloc_bind_this_q = valloc_bind_this;
    logic [7:0] valloc_fn_a1;
    assign valloc_fn_a1_q = valloc_fn_a1;
    logic [15:0] valloc_fn_entry;
    assign valloc_fn_entry_q = valloc_fn_entry;
    logic [13:0] valloc_i;
    assign valloc_i_q = valloc_i;
    logic [1:0] valloc_kind;
    assign valloc_kind_q = valloc_kind;
    logic valloc_metrics;
    assign valloc_metrics_q = valloc_metrics;
    logic valloc_now_fn;
    assign valloc_now_fn_q = valloc_now_fn;
    logic valloc_proto;
    assign valloc_proto_q = valloc_proto;
    logic [12:0] valloc_proto_fn;
    assign valloc_proto_fn_q = valloc_proto_fn;
    logic valloc_regex;
    assign valloc_regex_q = valloc_regex;
    logic [31:0] valloc_regex_pack;
    assign valloc_regex_pack_q = valloc_regex_pack;
    logic valloc_retried;
    assign valloc_retried_q = valloc_retried;
    logic [13:0] varr_next;
    assign varr_next_q = varr_next;
    logic [11:0] vcall_argc;
    assign vcall_argc_q = vcall_argc;
    logic [63:0] vcall_ctor_val;
    assign vcall_ctor_val_q = vcall_ctor_val;
    logic [63:0] ctor_cur;
    logic [7:0] ctor_csp;
    logic [15:0] vcall_entry;
    assign vcall_entry_q = vcall_entry;
    logic vcall_set_this;
    assign vcall_set_this_q = vcall_set_this;
    logic [63:0] vcall_this;
    assign vcall_this_q = vcall_this;
    logic vcall_value;
    assign vcall_value_q = vcall_value;
    logic [8:0] vconsole_n;
    assign vconsole_n_q = vconsole_n;
    logic [7:0] vcsp /*verilator public_flat_rd*/;
    assign vcsp_q = vcsp;
    logic [7:0] vdiv_count;
    assign vdiv_count_q = vdiv_count;
    logic [52:0] vdiv_den;
    assign vdiv_den_q = vdiv_den;
    logic signed [12:0] vdiv_exp;
    assign vdiv_exp_q = vdiv_exp;
    logic [106:0] vdiv_num;
    assign vdiv_num_q = vdiv_num;
    logic [106:0] vdiv_quot;
    assign vdiv_quot_q = vdiv_quot;
    logic [53:0] vdiv_rem;
    assign vdiv_rem_q = vdiv_rem;
    logic vdiv_sign;
    assign vdiv_sign_q = vdiv_sign;
    logic [7:0] vdraw_color;
    assign vdraw_color_q = vdraw_color;
    logic [9:0] vdraw_h;
    assign vdraw_h_q = vdraw_h;
    logic [18:0] vdraw_i;
    assign vdraw_i_q = vdraw_i;
    logic [9:0] vdraw_w;
    assign vdraw_w_q = vdraw_w;
    logic [9:0] vdraw_x;
    assign vdraw_x_q = vdraw_x;
    logic [9:0] vdraw_y;
    assign vdraw_y_q = vdraw_y;
    logic [63:0] venv;
    assign venv_q = venv;
    logic [9:0] venv_next;
    assign venv_next_q = venv_next;
    logic [63:0] vfe_arr;
    assign vfe_arr_q = vfe_arr;
    logic [63:0] vfe_arr_s [0:7];
    logic [11:0] vfe_base;
    assign vfe_base_q = vfe_base;
    logic [11:0] vfe_base_s [0:7];
    logic [63:0] vfe_fn;
    assign vfe_fn_q = vfe_fn;
    logic [63:0] vfe_fn_s [0:7];
    logic [7:0] vfe_i;
    assign vfe_i_q = vfe_i;
    logic [7:0] vfe_i_s [0:7];
    logic [7:0] vfe_len;
    assign vfe_len_q = vfe_len;
    logic [7:0] vfe_len_s [0:7];
    logic [63:0] vfe_map;
    assign vfe_map_q = vfe_map;
    logic [63:0] vfe_map_s [0:7];
    logic [1:0] vfe_mode;
    assign vfe_mode_q = vfe_mode;
    logic [1:0] vfe_mode_s [0:7];
    // #39 Array.reduce: 1-bit walk flavor; the accumulator rides vfe_map.
    logic vfe_reduce, vfe_reduce_n;
    assign vfe_reduce_q = vfe_reduce;
    logic vfe_reduce_s [0:7];
    logic vfe_reduce_s_wdata;
    // findIndex: find-mode walk whose result is the INDEX (or -1), not the
    // element. Same save/restore discipline as vfe_reduce.
    logic vfe_findidx, vfe_findidx_n;
    assign vfe_findidx_q = vfe_findidx;
    logic vfe_findidx_s [0:7];
    logic vfe_findidx_s_wdata;
    // #41 Array.sort: comparator walk; cmp result rides vfe_map.
    logic vfe_sort, vfe_sort_n;
    assign vfe_sort_q = vfe_sort;
    logic vfe_sort_s [0:7];
    logic vfe_sort_s_wdata;
    logic [15:0] vfe_ret;
    assign vfe_ret_q = vfe_ret;
    logic [15:0] vfe_ret_s [0:7];
    logic [3:0] vfe_sp;
    assign vfe_sp_q = vfe_sp;
    logic vfree_armed;
    assign vfree_armed_q = vfree_armed;
    logic vfree_arr_long;
    assign vfree_arr_long_q = vfree_arr_long;
    logic [13:0] vgc_clear_i;
    assign vgc_clear_i_q = vgc_clear_i;
    logic vgc_halt_after;
    assign vgc_halt_after_q = vgc_halt_after;
    logic [13:0] vgc_qr;
    assign vgc_qr_q = vgc_qr;
    logic [13:0] vgc_qw;
    assign vgc_qw_q = vgc_qw;
    logic [1:0] vgc_resume;
    assign vgc_resume_q = vgc_resume;
    logic vgc_wait_after;
    assign vgc_wait_after_q = vgc_wait_after;
    logic vjs_rd_arm;
    assign vjs_rd_arm_q = vjs_rd_arm;
    logic [63:0] vjs_val [0:JSON_STK-1];
    logic [4:0] vlistener_n;
    assign vlistener_n_q = vlistener_n;
    logic [15:0] vmetrics_w;
    assign vmetrics_w_q = vmetrics_w;
    logic [11:0] vmod_count;
    assign vmod_count_q = vmod_count;
    logic [52:0] vmod_den;
    assign vmod_den_q = vmod_den;
    logic signed [12:0] vmod_exp;
    assign vmod_exp_q = vmod_exp;
    logic [52:0] vmod_rem;
    assign vmod_rem_q = vmod_rem;
    logic vmod_sign;
    assign vmod_sign_q = vmod_sign;
    logic [11:0] vnat_base;
    assign vnat_base_q = vnat_base;
    logic [2:0] vnat_dom;
    assign vnat_dom_q = vnat_dom;
    logic vprom_copy;
    assign vprom_copy_q = vprom_copy;
    logic vprom_done;
    assign vprom_done_q = vprom_done;
    logic [6:0] vprom_ret;
    assign vprom_ret_q = vprom_ret;
    logic [3:0] vraf_n /*verilator public_flat_rd*/;
    assign vraf_n_q = vraf_n;
    logic [31:0] vrng;
    assign vrng_q = vrng;
    logic [11:0] vsp;
    assign vsp_q = vsp;
    logic vst_hold_win;
    assign vst_hold_win_q = vst_hold_win;
    logic vst_refill_arm;
    assign vst_refill_arm_q = vst_refill_arm;
    logic [3:0] vst_refill_i;
    assign vst_refill_i_q = vst_refill_i;
    logic [6:0] vst_refill_ret;
    assign vst_refill_ret_q = vst_refill_ret;
    logic [11:0] vst_waddr;
    assign vst_waddr_q = vst_waddr;
    logic [63:0] vst_wdata;
    assign vst_wdata_q = vst_wdata;
    logic vst_we;
    assign vst_we_q = vst_we;
    logic [63:0] vthis;
    assign vthis_q = vthis;
    logic [6:0] vtimer_n;
    assign vtimer_n_q = vtimer_n;
    logic [31:0] vtimer_seq;
    assign vtimer_seq_q = vtimer_seq;
    logic [9:0] x;
    assign x_q = x;
    logic [9:0] y;
    assign y_q = y;


    always_ff @(posedge clk) begin
        if (!rst_n) begin
            opnd_q <= 1'b0;
            opnd2_q <= 1'b0;
            opnd3_q <= 1'b0;
            hash2_q <= 1'b0;
            venvw_q <= 3'd0;
            tmr_i_q <= 7'd0;
            tmr_arm_q <= 2'd0;
            tmr_found_q <= 1'b0;
            tmr_slot_q <= 7'd0;
            clr_busy <= 1'b0;
            clr_i <= 12'd0;
            p_clr_busy_q <= 1'b0;
        end else if (p_clr) begin
            clr_busy <= 1'b1;
            clr_i <= 12'd0;
            cmc_valid <= 8'd0;
        end else if (clr_busy) begin
            // Parent HEAP_CLR owns the JS banks. This walk is only the
            // handshake delay (p_clr_busy) plus leftover class-table FFs.
            // class tables live in the parent now (no clr here)
            if (clr_i + 12'd1 >= 12'(CLR_LIM))
                clr_busy <= 1'b0;
            else
                clr_i <= clr_i + 12'd1;
        end else if (p_we) begin
            unique case (p_sel)
                6'd31, 6'd37, 6'd38, 6'd39: cmc_valid <= 8'd0; // tables changed
                default: ;
            endcase
        end
        if (cm_res_we && cm_scan) begin
            cmc_cls[cmc_wp] <= cm_cls;
            cmc_key[cmc_wp] <= cm_key;
            cmc_mip[cmc_wp] <= cm_res_mip;
            cmc_valid[cmc_wp] <= 1'b1;
            cmc_wp <= cmc_wp + 3'd1;
        end
        if (enable && !leave_hold) begin
            opnd_q <= opnd_n;
            opnd2_q <= opnd2_n;
            opnd3_q <= opnd3_n;
            hash2_q <= hash2_n;
            venvw_q <= venvw_n;
            tmr_i_q <= tmr_i_n;
            tmr_arm_q <= tmr_arm_n;
            tmr_found_q <= tmr_found_n;
            tmr_slot_q <= tmr_slot_n;
        end else begin
            opnd_q <= 1'b0;
            opnd2_q <= 1'b0;
            opnd3_q <= 1'b0;
            hash2_q <= 1'b0;
            venvw_q <= 3'd0;
            tmr_i_q <= 7'd0;
            tmr_arm_q <= 2'd0;
            tmr_found_q <= 1'b0;
            tmr_slot_q <= 7'd0;
        end
        p_clr_busy_q <= p_clr_busy;
        // Bring-up: sticky until the next fault (read by VMSTAT).
        if (!rst_n) fault_site <= 16'd0;
        else fault_site <= fault_site_n;
    end

    // Sequential cell so Vivado keep_hierarchy is not dissolved as combo-only.
    logic hier_keep;
    always_ff @(posedge clk) if (enable) hier_keep <= ~hier_keep;

    // EXEC working FFs. Combo *_n is the D pin. Parent must not mux *_n.
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            leave_hold <= 1'b0;
            ctor_cur <= V64_UNDEFINED;
            ctor_csp <= 8'd0;
            cm_scan <= 1'b0;
            cm_armed <= 1'b0;
            cm_done <= 1'b0;
            cmc_valid <= 8'd0;
            cmc_wp <= 3'd0;
            cm_c <= 4'd0;
            cm_m <= 4'd0;
            cm_mip <= 16'hFFFF;
            cm_key <= 16'd0;
            lsv_scan <= 1'b0; lsv_op <= 2'd0;
            fpm_busy <= 1'b0; fpm_req <= 1'b0; nwm_busy <= 1'b0;
            now_v64_q <= 64'd0; nwm_vf_q <= 32'hFFFFFFFF;
            lsv_ev <= 64'd0; lsv_fn <= 64'd0; lsv_push <= 64'd0; lsv_base <= 12'd0;
            cm_cls <= 16'd0;
            cm_win <= 1'b0;
            // Parent GOT_HDR sets identity scale; exec fillRect uses these
            // FFs (ctx_sx=0 after rst made every ctx.fillRect clip to 0 —
            // INVADERS splash 1893 swaps, FBRAW nz=0).
            ctx_sx <= FX_ONE;
            ctx_sy <= FX_ONE;
            saved_sx <= FX_ONE;
            saved_sy <= FX_ONE;
            ctx_tx <= 32'sd0;
            ctx_ty <= 32'sd0;
        // leave_hold beat: parent unique case (ALLOC/HEAP/BIND) pokes *_ff.
        // enable is still 1 (parent state=EXEC). Apply hs_m here or venv/hp_*
        // stay stale and STORE_VAR walks a self-parent env forever.
        end else if (enable && !leave_hold) begin
                aset_win_retried <= aset_win_retried_n;
                cm_win <= cm_win_n;
                bind_argc <= bind_argc_n;
                bind_base <= bind_base_n;
                bind_ip <= bind_ip_n;
                bind_k <= bind_k_n;
                bind_mode <= bind_mode_n;
                bind_n <= bind_n_n;
                bind_rd_arm <= bind_rd_arm_n;
                bind_ret <= bind_ret_n;
                bind_src <= bind_src_n;
                bind_vsp_next <= bind_vsp_next_n;
                cm_scan <= cm_scan_n;
                // FP mul engines: 106-bit accumulate, one add per beat (safe depth)
                if (fpm_start_n) begin
                    fpm_busy <= 1'b1;
                    fpm_cnt <= 6'd0;
                    fpm_acc <= 106'd0;
                    fpm_mcand <= 106'(fpm_ma_n);
                    fpm_mplier <= fpm_mb_n;
                    fpm_sign <= fpm_sign_n;
                    fpm_ea <= fpm_ea_n;
                    fpm_eb <= fpm_eb_n;
                end else if (fpm_busy) begin
                    if (fpm_mplier[0]) fpm_acc <= fpm_acc + fpm_mcand;
                    fpm_mcand <= fpm_mcand << 1;
                    fpm_mplier <= fpm_mplier >> 1;
                    fpm_cnt <= fpm_cnt + 6'd1;
                    if (fpm_cnt == 6'd52) fpm_busy <= 1'b0;
                end
                fpm_req <= fpm_req_n;
                if (nwm_busy) begin
                    if (nwm_mplier[0]) nwm_acc <= nwm_acc + nwm_mcand;
                    nwm_mcand <= nwm_mcand << 1;
                    nwm_mplier <= nwm_mplier >> 1;
                    nwm_cnt <= nwm_cnt + 6'd1;
                    if (nwm_cnt == 6'd52) begin
                        nwm_busy <= 1'b0;
                        now_v64_q <= v64_mul_pack(nwm_sign, nwm_ea, nwm_eb,
                            nwm_mplier[0] ? (nwm_acc + nwm_mcand) : nwm_acc);
                    end
                end else if (vframe_no != nwm_vf_q) begin
                    // frame clock product: v64_int32_number(vframe_no) x 16.666...
                    logic [63:0] nva;
                    nva = v64_int32_number(vframe_no);
                    nwm_vf_q <= vframe_no;
                    if (nva[62:0] == 63'd0) begin
                        now_v64_q <= {nva[63] ^ 1'b0, 63'd0};
                    end else begin
                        nwm_busy <= 1'b1;
                        nwm_cnt <= 6'd0;
                        nwm_acc <= 106'd0;
                        nwm_mcand <= 106'({(nva[62:52] != 0), nva[51:0]});
                        nwm_mplier <= {1'b1, 52'h0aaaaaaaaaab};
                        nwm_sign <= nva[63];
                        nwm_ea <= nva[62:52];
                        nwm_eb <= 11'h403;
                    end
                end
                lsv_scan <= lsv_scan_n;
                lsv_op <= lsv_op_n;
                lsv_ev <= lsv_ev_n;
                lsv_fn <= lsv_fn_n;
                lsv_push <= lsv_push_n;
                lsv_base <= lsv_base_n;
                cm_armed <= cm_armed_n;
                cm_done <= cm_done_n;
                cm_c <= cm_c_n;
                cm_m <= cm_m_n;
                cm_key <= cm_key_n;
                cm_cls <= cm_cls_n;
                cm_mip <= cm_mip_n;
                blit_sh <= blit_sh_n;
                blit_si <= blit_si_n;
                blit_sw <= blit_sw_n;
                blit_sx <= blit_sx_n;
                blit_sy <= blit_sy_n;
                cc_at <= cc_at_n;
                cc_av <= cc_av_n;
                cc_bok <= cc_bok_n;
                cc_bt <= cc_bt_n;
                cc_bv <= cc_bv_n;
                cc_d <= cc_d_n;
                cc_h <= cc_h_n;
                cc_len <= cc_len_n;
                cc_second <= cc_second_n;
                cc_st <= cc_st_n;
                code_raddr <= code_raddr_n;
                color <= color_n;
                ctx_align <= ctx_align_n;
                ctx_baseline <= ctx_baseline_n;
                ctx_smooth <= ctx_smooth_n;
                ctx_sx <= ctx_sx_n;
                ctx_sy <= ctx_sy_n;
                ctx_tx <= ctx_tx_n;
                ctx_ty <= ctx_ty_n;
                dbg_di_hit <= dbg_di_hit_n;
                dbg_di_miss <= dbg_di_miss_n;
                dbg_div_n <= dbg_div_n_n;
                dbg_json_ovf <= dbg_json_ovf_n;
                dbg_path_ovf <= dbg_path_ovf_n;
                fault_code <= fault_code_n;
                fb_dump_addr <= fb_dump_addr_n;
                fb_dump_sel <= fb_dump_sel_n;
                fb_swap <= fb_swap_n;
                fill_style_i <= fill_style_i_n;
                stroke_style_i <= stroke_style_i_n;
                hp_aid <= hp_aid_n;
                hp_alen <= hp_alen_n;
                hp_aslot <= hp_aslot_n;
                hp_cmd <= hp_cmd_n;
                hp_eid <= hp_eid_n;
                hp_env <= hp_env_n;
                hp_from_stack <= hp_from_stack_n;
                hp_hit <= hp_hit_n;
                hp_key <= hp_key_n;
                hp_len <= hp_len_n;
                hp_lim <= hp_lim_n;
                hp_make_arr <= hp_make_arr_n;
                hp_nat <= hp_nat_n;
                hp_oid <= hp_oid_n;
                hp_phase <= hp_phase_n;
                hp_proto <= hp_proto_n;
                hp_qi <= hp_qi_n;
                if (hp_q_we) begin
                    hp_qk[hp_q_waddr] <= hp_qk_wdata;
                    hp_qt[hp_q_waddr] <= hp_qt_wdata;
                    hp_qv[hp_q_waddr] <= hp_qv_wdata;
                end
                hp_qn <= hp_qn_n;
                hp_ret <= hp_ret_n;
                hp_rval <= hp_rval_n;
                hp_si <= hp_si_n;
                hp_slot <= hp_slot_n;
                hp_spr_h <= hp_spr_h_n;
                hp_spr_w <= hp_spr_w_n;
                hp_ss <= hp_ss_n;
                hp_tag <= hp_tag_n;
                hp_tn <= hp_tn_n;
                hp_v64 <= hp_v64_n;
                hp_vbase <= hp_vbase_n;
                hp_wval <= hp_wval_n;
                imgd_armed <= imgd_armed_n;
                imgd_h <= imgd_h_n;
                imgd_i <= imgd_i_n;
                imgd_n <= imgd_n_n;
                imgd_v64 <= imgd_v64_n;
                imgd_w <= imgd_w_n;
                imgd_x <= imgd_x_n;
                imgd_x0 <= imgd_x0_n;
                imgd_y <= imgd_y_n;
                imgd_y0 <= imgd_y0_n;
                ip <= ip_n;
                jn_arr <= jn_arr_n;
                jn_h <= jn_h_n;
                jn_i <= jn_i_n;
                jn_res <= jn_res_n;
                if (js_we) begin
                    js_i[js_waddr] <= js_i_wdata;
                    js_ph[js_waddr] <= js_ph_wdata;
                    vjs_val[js_waddr] <= vjs_val_wdata;
                end
                js_sp <= js_sp_n;
                json_pph <= json_pph_n;
                json_rp <= json_rp_n;
                json_src <= json_src_n;
                json_srclen <= json_srclen_n;
                json_wp <= json_wp_n;
                looping <= looping_n;
                machine_fault <= machine_fault_n;
                minmax_acc <= minmax_acc_n;
                minmax_base <= minmax_base_n;
                minmax_is_min <= minmax_is_min_n;
                minmax_k <= minmax_k_n;
                minmax_n <= minmax_n_n;
                namcpy_armed <= namcpy_armed_n;
                namcpy_repl <= namcpy_repl_n;
                namcpy_v64 <= namcpy_v64_n;
                name_rdaddr <= name_rdaddr_n;
                path_active <= path_active_n;
                path_kind <= path_kind_n;
                path_stroke <= path_stroke_n;
                if (pc_we) begin
                    pc_a1[pc_waddr] <= pc_a1_wdata;
                    pc_a2[pc_waddr] <= pc_a2_wdata;
                    pc_a3[pc_waddr] <= pc_a3_wdata;
                    pc_a4[pc_waddr] <= pc_a4_wdata;
                    pc_a5[pc_waddr] <= pc_a5_wdata;
                    pc_ccw[pc_waddr] <= pc_ccw_wdata;
                    pc_op[pc_waddr] <= pc_op_wdata;
                end
                pc_n <= pc_n_n;
                pi <= pi_n;
                repl_did <= repl_did_n;
                repl_g <= repl_g_n;
                repl_nlen <= repl_nlen_n;
                repl_pat0 <= repl_pat0_n;
                repl_pat1 <= repl_pat1_n;
                repl_rch <= repl_rch_n;
                rh <= rh_n;
                running <= running_n;
                rw <= rw_n;
                rx <= rx_n;
                ry <= ry_n;
                saved_sx <= saved_sx_n;
                saved_sy <= saved_sy_n;
                saved_tx <= saved_tx_n;
                saved_ty <= saved_ty_n;
                sq_i <= sq_i_n;
                sq_rad <= sq_rad_n;
                sq_rem <= sq_rem_n;
                sq_root <= sq_root_n;
                state <= state_n;
                txt_bn <= txt_bn_n;
                txt_ph <= txt_ph_n;
                txt_px <= txt_px_n;
                txt_py <= txt_py_n;
                txt_val <= txt_val_n;
                txt_vt <= txt_vt_n;
                v64_concat <= v64_concat_n;
                v64_join <= v64_join_n;
                v64_repl <= v64_repl_n;
                v64_sqrt <= v64_sqrt_n;
                valloc_arr_n <= valloc_arr_n_n;
                valloc_bind <= valloc_bind_n;
                valloc_bind_src <= valloc_bind_src_n;
                valloc_bind_this <= valloc_bind_this_n;
                valloc_fn_a1 <= valloc_fn_a1_n;
                valloc_fn_entry <= valloc_fn_entry_n;
                valloc_i <= valloc_i_n;
                valloc_kind <= valloc_kind_n;
                valloc_metrics <= valloc_metrics_n;
                valloc_now_fn <= valloc_now_fn_n;
                valloc_proto <= valloc_proto_n;
                valloc_proto_fn <= valloc_proto_fn_n;
                valloc_regex <= valloc_regex_n;
                valloc_regex_pack <= valloc_regex_pack_n;
                valloc_retried <= valloc_retried_n;
                varr_next <= varr_next_n;
                vcall_argc <= vcall_argc_n;
                vcall_ctor_val <= vcall_ctor_val_n;
                ctor_cur <= ctor_cur_n;
                ctor_csp <= ctor_csp_n;
                vcall_entry <= vcall_entry_n;
                vcall_set_this <= vcall_set_this_n;
                vcall_this <= vcall_this_n;
                vcall_value <= vcall_value_n;
                vconsole_n <= vconsole_n_n;
                // Parent ALLOC hs_vcsp/hs_vsp must win on the opnd beat:
                // vsp_n/vcsp_n would re-clock the pre-ALLOC value and drop
                // the MAKE_FN push (DONKEY CALL_VAL TOS=undef) / CALL_USER
                // frame (RET_VAL fault 2).
                // Sticky hs_m_vcsp (outer BIND p=1) must not win over
                // NEW_OBJ vcsp_n=+1 or RET_VAL vcsp_n=-1 — that kept exec
                // at 1, nested `new` wrote frame[0], Game RET fault 2.
                // vcsp already 0 + overlay p=1 + vcsp_n==0 re-raised the
                // popped forEach frame on RET (one_fe idle vret=fffc).
                // Raise-only when depth is already live; 0→1 is enable=0
                // FOREACH/ALLOC, not this EXEC beat.
                if (hs_m_vcsp && (p_vcsp != 8'd0) &&
                    (vcsp_n == vcsp) && (p_vcsp > vcsp) &&
                    (vcsp != 8'd0))
                    vcsp <= p_vcsp;
                else vcsp <= vcsp_n;
                vdiv_count <= vdiv_count_n;
                vdiv_den <= vdiv_den_n;
                vdiv_exp <= vdiv_exp_n;
                vdiv_num <= vdiv_num_n;
                vdiv_quot <= vdiv_quot_n;
                vdiv_rem <= vdiv_rem_n;
                vdiv_sign <= vdiv_sign_n;
                if (hs_m_venv) venv <= p_venv;
                else venv <= venv_n;
                vdraw_color <= vdraw_color_n;
                vdraw_h <= vdraw_h_n;
                vdraw_i <= vdraw_i_n;
                vdraw_w <= vdraw_w_n;
                vdraw_x <= vdraw_x_n;
                vdraw_y <= vdraw_y_n;
                venv_next <= venv_next_n;
                vfe_arr <= vfe_arr_n;
                if (vfe_s_we) begin
                    vfe_arr_s[vfe_s_waddr] <= vfe_arr_s_wdata;
                    vfe_base_s[vfe_s_waddr] <= vfe_base_s_wdata;
                    vfe_fn_s[vfe_s_waddr] <= vfe_fn_s_wdata;
                    vfe_i_s[vfe_s_waddr] <= vfe_i_s_wdata;
                    vfe_len_s[vfe_s_waddr] <= vfe_len_s_wdata;
                    vfe_map_s[vfe_s_waddr] <= vfe_map_s_wdata;
                    vfe_mode_s[vfe_s_waddr] <= vfe_mode_s_wdata;
                    vfe_reduce_s[vfe_s_waddr] <= vfe_reduce_s_wdata;
                    vfe_findidx_s[vfe_s_waddr] <= vfe_findidx_s_wdata;
                    vfe_sort_s[vfe_s_waddr] <= vfe_sort_s_wdata;
                    vfe_ret_s[vfe_s_waddr] <= vfe_ret_s_wdata;
                end
                vfe_base <= vfe_base_n;
                vfe_fn <= vfe_fn_n;
                vfe_i <= vfe_i_n;
                vfe_len <= vfe_len_n;
                vfe_map <= vfe_map_n;
                vfe_mode <= vfe_mode_n;
                vfe_reduce <= vfe_reduce_n;
                vfe_findidx <= vfe_findidx_n;
                vfe_sort <= vfe_sort_n;
                vfe_ret <= vfe_ret_n;
                vfe_sp <= vfe_sp_n;
                vfree_armed <= vfree_armed_n;
                vfree_arr_long <= vfree_arr_long_n;
                vgc_clear_i <= vgc_clear_i_n;
                vgc_halt_after <= vgc_halt_after_n;
                vgc_qr <= vgc_qr_n;
                vgc_qw <= vgc_qw_n;
                vgc_resume <= vgc_resume_n;
                vgc_wait_after <= vgc_wait_after_n;
                vjs_rd_arm <= vjs_rd_arm_n;
                // listener tables live only in the parent now (lsv service)
                vlistener_n <= vlistener_n_n;
                vmetrics_w <= vmetrics_w_n;
                vmod_count <= vmod_count_n;
                vmod_den <= vmod_den_n;
                vmod_exp <= vmod_exp_n;
                vmod_rem <= vmod_rem_n;
                vmod_sign <= vmod_sign_n;
                vnat_base <= vnat_base_n;
                vnat_dom <= vnat_dom_n;
                vprom_copy <= vprom_copy_n;
                vprom_done <= vprom_done_n;
                vprom_ret <= vprom_ret_n;
                vraf_n <= vraf_n_n;
                vrng <= vrng_n;
                if (hs_m_vsp) vsp <= p_vsp;
                else vsp <= vsp_n;
                vst_hold_win <= vst_hold_win_n;
                vst_refill_arm <= vst_refill_arm_n;
                vst_refill_i <= vst_refill_i_n;
                vst_refill_ret <= vst_refill_ret_n;
                vst_waddr <= vst_waddr_n;
                vst_wdata <= vst_wdata_n;
                vst_we <= vst_we_n;
                if (hs_m_vthis) vthis <= p_vthis;
                else vthis <= vthis_n;
                vtimer_n <= vtimer_n_n;
                vtimer_seq <= vtimer_seq_n;
                x <= x_n;
                y <= y_n;
                // Registered SRAM we: parent applies *_q on the leave_hold EXEC beat.
                json_mem_we_q <= json_mem_we;
                json_mem_waddr_q <= json_mem_waddr;
                json_mem_wdata_q <= json_mem_wdata;
                name_blen_we_q <= name_blen_we;
                name_blen_waddr_q <= name_blen_waddr;
                name_blen_wdata_q <= name_blen_wdata;
                name_hash_we_q <= name_hash_we;
                name_hash_waddr_q <= name_hash_waddr;
                name_hash_wdata_q <= name_hash_wdata;
                name_has_we_q <= name_has_we;
                name_has_waddr_q <= name_has_waddr;
                name_has_wdata_q <= name_has_wdata;
                varr_len_we_q <= varr_len_we;
                varr_len_waddr_q <= varr_len_waddr;
                varr_len_wdata_q <= varr_len_wdata;
                varr_lidx_we_q <= varr_lidx_we;
                varr_lidx_waddr_q <= varr_lidx_waddr;
                varr_lidx_wdata_q <= varr_lidx_wdata;
                varr_long_we_q <= varr_long_we;
                varr_long_waddr_q <= varr_long_waddr;
                varr_long_wdata_q <= varr_long_wdata;
                varr_valid_we_q <= varr_valid_we;
                varr_valid_waddr_q <= varr_valid_waddr;
                varr_valid_wdata_q <= varr_valid_wdata;
                venv_gen_we_q <= venv_gen_we;
                venv_gen_waddr_q <= venv_gen_waddr;
                venv_gen_wdata_q <= venv_gen_wdata;
                venv_len_we_q <= venv_len_we;
                venv_len_waddr_q <= venv_len_waddr;
                venv_len_wdata_q <= venv_len_wdata;
                venv_valid_we_q <= venv_valid_we;
                venv_valid_waddr_q <= venv_valid_waddr;
                venv_valid_wdata_q <= venv_valid_wdata;
                vobj_cls_we_q <= vobj_cls_we;
                vobj_cls_waddr_q <= vobj_cls_waddr;
                vobj_cls_wdata_q <= vobj_cls_wdata;
                vvar_valid_we_q <= vvar_valid_we;
                vvar_valid_waddr_q <= vvar_valid_waddr;
                vvar_valid_wdata_q <= vvar_valid_wdata;
                vvars_we_q <= vvars_we;
                vvars_waddr_q <= vvars_waddr;
                vvars_wdata_q <= vvars_wdata;
                vframe_we_q <= vframe_we;
                vframe_waddr_q <= vframe_waddr;
                vframe_rip_wdata_q <= vframe_rip_wdata;
                vframe_bsp_wdata_q <= vframe_bsp_wdata;
                vframe_esc_wdata_q <= vframe_esc_wdata;
                vframe_this_wdata_q <= vframe_this_wdata;
                vframe_env_wdata_q <= vframe_env_wdata;
                vframe_fn_wdata_q <= vframe_fn_wdata;
                vframe_ctor_wdata_q <= vframe_ctor_wdata;
                vraf_we_q <= vraf_we;
                vraf_waddr_q <= vraf_waddr;
                vraf_wdata_q <= vraf_wdata;
                vtimer_we_q <= vtimer_we;
                vtimer_waddr_q <= vtimer_waddr;
                vtimer_valid_wdata_q <= vtimer_valid_wdata;
                vtimer_due_wdata_q <= vtimer_due_wdata;
                vtimer_fn_wdata_q <= vtimer_fn_wdata;
                vtimer_id_wdata_q <= vtimer_id_wdata;
                vtimer_period_wdata_q <= vtimer_period_wdata;
                vst_win0_we_q <= vst_win0_we;
                vst_win0_wdata_q <= vst_win0_wdata;
                vvars_raddr_q <= vvars_raddr;
                venv_raddr_q <= venv_raddr;
                varr_raddr_q <= varr_raddr;
                vobj_raddr_q <= vobj_raddr;
                vfn_raddr_q <= vfn_raddr;
                name_off_raddr_q <= name_off_raddr;
                fill_lut_raddr_q <= fill_lut_raddr;
                vframe_raddr_q <= vframe_raddr;
                vtimer_raddr_q <= vtimer_raddr;
                vconsts_raddr_q <= vconsts_raddr;
                name_blen_raddr_q <= name_blen_raddr;
                name_hash_raddr_q <= name_hash_raddr;
                leave_hold <= (state_n != S_V64_EXEC);
                if (state_n != S_V64_EXEC || leave_hold) pf_ok <= 1'b0;
                else if (opw_cap_n) pf_ok <= 1'b1;
                // consume the post-parent one-shot at the first op-end
                if (state == S_V64_EXEC && state_n == S_FETCH_WAIT)
                    post_parent_q <= 1'b0;
        end else begin
            leave_hold <= 1'b0;
                // potential-bugs #66: parent vtimer_n is truth (see the
                // parent mirror); absorb it while frozen so fire-time
                // frees are visible to the setTimeout full-check.
                vtimer_n <= p_vtimer_n;
                json_mem_we_q <= 1'b0;
                name_blen_we_q <= 1'b0;
                name_hash_we_q <= 1'b0;
                name_has_we_q <= 1'b0;
                varr_len_we_q <= 1'b0;
                varr_lidx_we_q <= 1'b0;
                varr_long_we_q <= 1'b0;
                varr_valid_we_q <= 1'b0;
                venv_gen_we_q <= 1'b0;
                venv_len_we_q <= 1'b0;
                venv_valid_we_q <= 1'b0;
                vobj_cls_we_q <= 1'b0;
                vvar_valid_we_q <= 1'b0;
                vvars_we_q <= 1'b0;
                vframe_we_q <= 1'b0;
                vraf_we_q <= 1'b0;
                vtimer_we_q <= 1'b0;
                vst_win0_we_q <= 1'b0;
                if (hs_m_ip) ip <= p_ip;
                if (hs_m_code) code_raddr <= p_code_raddr;
                if (hs_m_state) begin
                    state <= p_state;
                    if (p_state == S_V64_EXEC) post_parent_q <= 1'b1;
                    /* pf_ok: TRUE only for the EXEC entry that came from
                       the parent's S_FETCH_WAIT dispatch — the one path
                       whose handover makes the code port stream ip+1
                       through EXEC (the parent-side mux applies it with
                       the parent-registered mask; OUR mirror of the
                       address lags a beat, so no local address compare
                       can verify it — provenance can). Re-entries from
                       ALLOC/event/call flows leave it 0. */
                    pf_ok <= (state == S_FETCH_WAIT && p_state == S_V64_EXEC);
                end
                if (hs_m_vsp) vsp <= p_vsp;
                if (hs_m_hp_cmd) hp_cmd <= p_hp_cmd;
                if (hs_m_hp_v64) hp_v64 <= p_hp_v64;
                if (hs_m_hp_oid) hp_oid <= p_hp_oid;
                if (hs_m_hp_aid) hp_aid <= p_hp_aid;
                if (hs_m_hp_env) hp_env <= p_hp_env;
                if (hs_m_hp_eid) hp_eid <= p_hp_eid;
                if (hs_m_hp_slot) hp_slot <= p_hp_slot;
                if (hs_m_hp_aslot) hp_aslot <= p_hp_aslot;
                if (hs_m_hp_len) hp_len <= p_hp_len;
                if (hs_m_hp_alen) hp_alen <= p_hp_alen;
                if (hs_m_hp_lim) hp_lim <= p_hp_lim;
                if (hs_m_hp_key) hp_key <= p_hp_key;
                if (hs_m_hp_wval) hp_wval <= p_hp_wval;
                if (hs_m_hp_rval) hp_rval <= p_hp_rval;
                if (hs_m_hp_hit) hp_hit <= p_hp_hit;
                if (hs_m_hp_ret) hp_ret <= p_hp_ret;
                if (hs_m_hp_phase) hp_phase <= p_hp_phase;
                if (hs_m_hp_proto) hp_proto <= p_hp_proto;
                if (hs_m_hp_qn) hp_qn <= p_hp_qn;
                if (hs_m_hp_qi) hp_qi <= p_hp_qi;
                if (hs_m_hp_si) hp_si <= p_hp_si;
                if (hs_m_hp_ss) hp_ss <= p_hp_ss;
                if (hs_m_hp_tn) hp_tn <= p_hp_tn;
                if (hs_m_hp_from_stack) hp_from_stack <= p_hp_from_stack;
                if (hs_m_hp_make_arr) hp_make_arr <= p_hp_make_arr;
                if (hs_m_hp_vbase) hp_vbase <= p_hp_vbase;
                if (hs_m_hp_spr_w) hp_spr_w <= p_hp_spr_w;
                if (hs_m_hp_spr_h) hp_spr_h <= p_hp_spr_h;
                if (hs_m_hp_nat) hp_nat <= p_hp_nat;
                if (hs_m_hp_tag) hp_tag <= p_hp_tag;
                if (hs_m_hp_qk) begin
                    hp_qk[0] <= p_hp_qk_pack[15:0];
                    hp_qk[1] <= p_hp_qk_pack[31:16];
                    hp_qk[2] <= p_hp_qk_pack[47:32];
                    hp_qk[3] <= p_hp_qk_pack[63:48];
                end
                if (hs_m_hp_qv) begin
                    hp_qv[0] <= p_hp_qv_pack[63:0];
                    hp_qv[1] <= p_hp_qv_pack[127:64];
                    hp_qv[2] <= p_hp_qv_pack[191:128];
                    hp_qv[3] <= p_hp_qv_pack[255:192];
                end
                if (hs_m_hp_qt) begin
                    hp_qt[0] <= p_hp_qt_pack[2:0];
                    hp_qt[1] <= p_hp_qt_pack[5:3];
                    hp_qt[2] <= p_hp_qt_pack[8:6];
                    hp_qt[3] <= p_hp_qt_pack[11:9];
                end
                if (hs_m_valloc_kind) valloc_kind <= p_valloc_kind;
                if (hs_m_valloc_i) valloc_i <= p_valloc_i;
                if (hs_m_valloc_arr_n) valloc_arr_n <= p_valloc_arr_n;
                if (hs_m_valloc_retried) valloc_retried <= p_valloc_retried;
                if (hs_m_vnat_dom) vnat_dom <= p_vnat_dom;
                if (hs_m_vnat_base) vnat_base <= p_vnat_base;
                if (hs_m_valloc_now_fn) valloc_now_fn <= p_valloc_now_fn;
                if (hs_m_valloc_bind) valloc_bind <= p_valloc_bind;
                if (hs_m_valloc_bind_src) valloc_bind_src <= p_valloc_bind_src;
                if (hs_m_valloc_bind_this) valloc_bind_this <= p_valloc_bind_this;
                if (hs_m_valloc_fn_entry) valloc_fn_entry <= p_valloc_fn_entry;
                if (hs_m_valloc_fn_a1) valloc_fn_a1 <= p_valloc_fn_a1;
                if (hs_m_valloc_proto) valloc_proto <= p_valloc_proto;
                if (hs_m_valloc_proto_fn) valloc_proto_fn <= p_valloc_proto_fn;
                if (hs_m_valloc_metrics) valloc_metrics <= p_valloc_metrics;
                if (hs_m_valloc_regex) valloc_regex <= p_valloc_regex;
                if (hs_m_valloc_regex_pack) valloc_regex_pack <= p_valloc_regex_pack;
                if (hs_m_vcall_value) vcall_value <= p_vcall_value;
                if (hs_m_vcall_argc) vcall_argc <= p_vcall_argc;
                if (hs_m_vcall_entry) vcall_entry <= p_vcall_entry;
                if (hs_m_vcall_set_this) vcall_set_this <= p_vcall_set_this;
                if (hs_m_vcall_this) vcall_this <= p_vcall_this;
                if (hs_m_vcall_ctor_val) vcall_ctor_val <= p_vcall_ctor_val;
                // GOT_HDR p_clr must drop leftover fault/vcsp. hs_vcsp(0)
                // is ignored by the !=0 guard, so PACMAN inherited INVADERS
                // fault=2 and bounced to READY in HEAP_CLR.
                if (p_clr) begin
                    machine_fault <= 1'b0;
                    fault_code <= 8'd0;
                    vcsp <= 8'd0;
                    cm_scan <= 1'b0;
                    cm_armed <= 1'b0;
                    cm_done <= 1'b0;
                    cm_mip <= 16'hFFFF;
                    ctor_cur <= V64_UNDEFINED;
                    ctor_csp <= 8'd0;
                    ctx_sx <= FX_ONE;
                    ctx_sy <= FX_ONE;
                    saved_sx <= FX_ONE;
                    saved_sy <= FX_ONE;
                    ctx_tx <= 32'sd0;
                    ctx_ty <= 32'sd0;
                    // Canvas state must not survive a title load. The parent
                    // clears its own ctx_align on RUN, but exec keeps the
                    // live copy — so a title that set textAlign="center"
                    // (DONKEY) left every later title centred. ASTEROID and
                    // PACMAN never set textAlign at all yet reported
                    // align=1, and ASTEROID's self-centred text drew half a
                    // string left of where it belonged.
                    ctx_align <= 2'd0;
                    ctx_baseline <= 2'd0;
                    fill_style_i <= 8'd0;
                    stroke_style_i <= 8'd0;
                    vfe_arr <= V64_UNDEFINED;
                    vfe_fn <= V64_UNDEFINED;
                    vfe_i <= 8'd0;
                    vfe_ret <= 16'd0;
                    vfe_base <= '0;
                    vfe_mode <= 2'd0;
                    vfe_map <= V64_UNDEFINED;
                    vfe_reduce <= 1'b0;
                    vfe_findidx <= 1'b0;
                    vfe_sort <= 1'b0;
                    vfe_len <= 8'd0;
                    vfe_sp <= 4'd0;
                // leave_hold EXEC: parent is still EXEC (casestate FOREACH
                // after RET 0xfffc / ALLOC). Sticky ALLOC hs_vcsp re-raised
                // the popped callback frame (one_fe nops fault 1, nested
                // forEach wrote frame[0]). HEAP/BIND pokes still land —
                // those states have enable=0. Do not skip hs_m_venv here
                // (STORE_VAR self-parent walk).
                // FOREACH done hs_vcsp(0) must land: the !=0 guard left
                // parent/exec depth stuck at ALLOC (vret=fffc after nops).
                end else if (hs_m_vcsp &&
                             !(enable && leave_hold) &&
                             ((p_vcsp != 8'd0 && p_vcsp >= vcsp) ||
                              (p_vcsp == 8'd0 && p_state == S_V64_FOREACH)))
                    vcsp <= p_vcsp;
                // FOREACH: parent state is FOREACH so enable=0. i++ must
                // land here or RET 0xfffc / nested CALL_METHOD save stale i.
                // Pop restores the exec nest stack (parent vfe_arr_s is empty).
                if (!p_clr && hs_m_vfe_pop && (vfe_sp != 4'd0)) begin
                    vfe_arr <= vfe_arr_s[vfe_sp - 4'd1];
                    vfe_fn <= vfe_fn_s[vfe_sp - 4'd1];
                    vfe_i <= vfe_i_s[vfe_sp - 4'd1];
                    vfe_len <= vfe_len_s[vfe_sp - 4'd1];
                    vfe_ret <= vfe_ret_s[vfe_sp - 4'd1];
                    vfe_base <= vfe_base_s[vfe_sp - 4'd1];
                    vfe_mode <= vfe_mode_s[vfe_sp - 4'd1];
                    vfe_map <= vfe_map_s[vfe_sp - 4'd1];
                    vfe_reduce <= vfe_reduce_s[vfe_sp - 4'd1];
                    vfe_findidx <= vfe_findidx_s[vfe_sp - 4'd1];
                    vfe_sort <= vfe_sort_s[vfe_sp - 4'd1];
                    vfe_sp <= vfe_sp - 4'd1;
                end else if (!p_clr && hs_m_vfe_i)
                    vfe_i <= p_vfe_i;
                // ALLOC kind 3 pulses p_frame_we on the CTOR_PAD beat
                // (enable=0). Same-cycle hs_vcall_ctor_val(UNDEF) must not
                // wipe this — RET_VAL samples ctor_cur, not lagged SRAM.
                // Not else-if vs hs_vcsp: ALLOC writes both the same beat.
                // Only OBJECT: CALL_USER p_frame_ctor=UNDEF must not steal
                // the instance (constructor that calls f() then RET).
                if (!p_clr && p_frame_we &&
                    p_frame_ctor[63:48] == V64_TAG_PREFIX &&
                    p_frame_ctor[47:44] == V64_KIND_OBJECT) begin
                    ctor_cur <= p_frame_ctor;
                    ctor_csp <= {1'b0, p_frame_idx} + 8'd1;
                    // LOAD_VAR __this reads vthis. hs_m_vthis from kind 3
                    // is visible next cycle; plant now so nested `this.n=n`
                    // is not UNDEF / the outer instance.
                    vthis <= p_frame_ctor;
                end
                // Kind 3 also pulses hs_vthis(UNDEF) for CALL_USER. Do not
                // wipe the instance we just planted (nested this.n=n).
                if (hs_m_vthis &&
                    !(p_vthis[63:48] == V64_TAG_PREFIX &&
                      p_vthis[47:44] == V64_KIND_UNDEFINED &&
                      ctor_cur[63:48] == V64_TAG_PREFIX &&
                      ctor_cur[47:44] == V64_KIND_OBJECT))
                    vthis <= p_vthis;
                if (hs_m_venv) venv <= p_venv;
                if (hs_m_vraf_n) vraf_n <= p_vraf_n;
                if (hs_m_vlistener_n) vlistener_n <= p_vlistener_n;
                if (hs_m_vgc_halt_after) vgc_halt_after <= p_vgc_halt_after;
                if (hs_m_vgc_wait_after) vgc_wait_after <= p_vgc_wait_after;
                if (hs_m_vgc_clear_i) vgc_clear_i <= p_vgc_clear_i;
                if (hs_m_vgc_qr) vgc_qr <= p_vgc_qr;
                if (hs_m_vgc_qw) vgc_qw <= p_vgc_qw;
                if (hs_m_vdraw_i) vdraw_i <= p_vdraw_i;
                if (hs_m_vdraw_x) vdraw_x <= p_vdraw_x;
                if (hs_m_vdraw_y) vdraw_y <= p_vdraw_y;
                if (hs_m_vdraw_w) vdraw_w <= p_vdraw_w;
                if (hs_m_vdraw_h) vdraw_h <= p_vdraw_h;
                if (hs_m_vdraw_color) vdraw_color <= p_vdraw_color;
        end
    end

    // Packed sprite dims from parent (not unpacked array ports).
    logic [15:0] spr_hh [0:MAX_SPR-1];
    logic [15:0] spr_nid [0:15];
    logic [15:0] spr_ww [0:MAX_SPR-1];
    genvar gi_e64spr;
    generate
        for (gi_e64spr = 0; gi_e64spr < MAX_SPR; gi_e64spr++) begin : g_e64_spr
            assign spr_hh[gi_e64spr] = spr_hh_pack[16*gi_e64spr +: 16];
            assign spr_nid[gi_e64spr] = spr_nid_pack[16*gi_e64spr +: 16];
            assign spr_ww[gi_e64spr] = spr_ww_pack[16*gi_e64spr +: 16];
        end
    endgenerate

    logic [10:0] eb;
    logic [51:0] fb;
    logic [52:0] mb;
    logic [15:0] q;
    logic sb;
    logic [55:0] sig;
    logic sr;
    logic sticky;
    logic [55:0] xb;
    // Parent ALLOC hs_vsp/hs_vcsp is visible this cycle; the exec FF lags
    // one beat (MAKE_FN+CALL_VAL TOS, CALL_USER RET_VAL vcsp).
    logic [11:0] vsp_hs;
    logic [7:0] vcsp_hs;
    logic [63:0] venv_hs;
    logic [63:0] vthis_hs;
    assign vsp_hs = hs_m_vsp ? p_vsp : vsp;
    assign vcsp_hs = hs_m_vcsp ? p_vcsp : vcsp;
    assign venv_hs = hs_m_venv ? p_venv : venv;
    assign vthis_hs = hs_m_vthis ? p_vthis : vthis;
    // Packed vst_win_pack port stays (no unpacked vst_peek[] port). Nested
    // vst_win_pack[i +: 64][11:0] is illegal SV (Synth 8-2599). Unpack once.
    logic [63:0] vst_s [0:15];
    genvar gi_vsts;
    generate
        for (gi_vsts = 0; gi_vsts < 16; gi_vsts++) begin : g_vst_s
            assign vst_s[gi_vsts] = vst_win_pack[64 * gi_vsts +: 64];
        end
    endgenerate
    `define VST_REL(addr) (((((vsp_hs)>(addr)) && (((vsp_hs)-(addr)-12'd1)<12'd16))) ? 4'((vsp_hs)-(addr)-12'd1) : 4'd0)
    `define VST_AT(addr) vst_s[`VST_REL(addr)]

    function automatic logic [7:0] sat8(input logic signed [31:0] v);
        if (v < 0) sat8 = 8'd0;
        else if (v > 255) sat8 = 8'd255;
        else sat8 = 8'(v);
    endfunction
    task automatic v64_add_task(
        input logic [63:0] aa,
        input logic [63:0] bb,
        output logic [63:0] result
    );
        logic sa, sb, sr;
        logic [10:0] ea, eb;
        logic [51:0] fa, fb;
        logic [52:0] ma, mb, mant;
        logic [55:0] xa, xb, sig;
        logic [56:0] sum;
        logic [53:0] rounded;
        integer er, diff;
        logic [10:0] ef;
        begin
            sa = aa[63]; sb = bb[63];
            ea = aa[62:52]; eb = bb[62:52];
            fa = aa[51:0]; fb = bb[51:0];
            if ((ea == 11'h7ff && fa != 0) ||
                (eb == 11'h7ff && fb != 0) ||
                (ea == 11'h7ff && eb == 11'h7ff && sa != sb)) begin
                result = V64_CANON_NAN;
            end else if (ea == 11'h7ff) begin
                result = {sa, 11'h7ff, 52'd0};
            end else if (eb == 11'h7ff) begin
                result = {sb, 11'h7ff, 52'd0};
            end else if (aa[62:0] == 0 && bb[62:0] == 0) begin
                result = {sa & sb, 63'd0};
            end else if (aa[62:0] == 0) begin
                result = bb;
            end else if (bb[62:0] == 0) begin
                result = aa;
            end else begin
                ma = {1'b0, fa};
                mb = {1'b0, fb};
                if (ea != 0) ma[52] = 1'b1;
                if (eb != 0) mb[52] = 1'b1;
                xa = {ma, 3'b000};
                xb = {mb, 3'b000};
                // Keep xa as the larger magnitude so subtraction has no sign
                // borrow and signed zero cancellation is deterministic.
                if (((ea == 0) ? 1 : ea) < ((eb == 0) ? 1 : eb) ||
                    (((ea == 0) ? 1 : ea) == ((eb == 0) ? 1 : eb) &&
                     ma < mb)) begin
                    sig = xa; xa = xb; xb = sig;
                    er = (eb == 0) ? 1 : eb;
                    diff = er - ((ea == 0) ? 1 : ea);
                    sr = sb;
                end else begin
                    er = (ea == 0) ? 1 : ea;
                    diff = er - ((eb == 0) ? 1 : eb);
                    sr = sa;
                end
                xb = v64_shr_sticky(xb, diff);
                if (sa == sb) begin
                    sum = {1'b0, xa} + {1'b0, xb};
                    if (sum[56]) begin
                        sig = sum[56:1];
                        sig[0] = sig[0] | sum[0];
                        er = er + 1;
                    end else
                        sig = sum[55:0];
                end else begin
                    // log-depth normalize: LZC + one barrel shift, clamped
                    // at the subnormal boundary (er floor 1) — replaces the
                    // 55-step loop-carried shift (the -250ns class).
                    integer lz, shn;
                    sig = xa - xb;
                    if (sig == 0)
                        sr = 1'b0;
                    lz = 0;
                    for (int k = 0; k <= 55; k++)
                        if (sig[k]) lz = 55 - k;
                    if (sig != 0) begin
                        shn = (er - 1 < lz) ? (er - 1) : lz;
                        if (shn < 0) shn = 0;
                        sig = sig << shn;
                        er = er - shn;
                    end
                end
                mant = sig[55:3];
                rounded = {1'b0, mant}
                        + (sig[2] && (sig[1] || sig[0] || mant[0]));
                if (rounded[53]) begin
                    mant = rounded[53:1];
                    er = er + 1;
                end else
                    mant = rounded[52:0];
                if (er >= 2047)
                    result = {sr, 11'h7ff, 52'd0};
                else if (mant == 0)
                    result = {sr, 63'd0};
                else begin
                    ef = (er == 1 && !mant[52]) ? 11'd0 : 11'(er);
                    result = {sr, ef, mant[51:0]};
                end
            end
        end
    endtask
    // Frame clock (performance.now / Date.now / getTime): all three
    // opcode branches compute the SAME product, so one shared instance
    // serves them — this removes two full 53x53 comb multipliers.
    // now_v64 comes from the nwm engine (now_v64_q), recomputed over 53
    // beats whenever vframe_no changes; consumers hold on nwm_busy.

    // Comb pack/normalize/round on a REGISTERED 106-bit product — the
    // 53x53 comb multiply itself (477 series CARRY4s, the -250ns path)
    // moved to 53-beat shift-add engines (2026-08-24).
    function automatic logic [63:0] v64_mul_pack(
        input logic sign,
        input logic [10:0] ea,
        input logic [10:0] eb,
        input logic [105:0] product
    );
        logic [10:0] ef;
        logic [52:0] q;
        logic [53:0] rounded;
        logic guard, sticky;
        integer p, er, shift;
        begin
            // highest set bit: priority scan (log-depth encoder form)
            p = -1;
            for (int k = 0; k < 106; k++)
                if (product[k])
                    p = k;
            er = ((ea == 0) ? 1 : ea)
               + ((eb == 0) ? 1 : eb) - 1023 + p - 104;
            shift = p - 52;
            ef = 11'(er);
            if (er <= 0) begin
                shift = shift + 1 - er;
                ef = 11'd0;
            end
            q = (shift >= 106) ? 53'd0 : 53'(product >> shift);
            guard = 1'b0;
            sticky = 1'b0;
            if (shift > 0 && shift <= 106) begin
                logic [105:0] below_mask;
                guard = product[shift - 1];
                // masked OR-reduce (tree form): sticky = any bit below guard
                below_mask = (106'd1 << (shift - 1)) - 106'd1;
                sticky = |(product & below_mask);
            end else if (shift > 106)
                sticky = |product;
            rounded = {1'b0, q} + (guard && (sticky || q[0]));
            if (ef != 0 && rounded[53]) begin
                q = rounded[53:1];
                er = er + 1;
                ef = 11'(er);
            end else
                q = rounded[52:0];
            if (er >= 2047)
                v64_mul_pack = {sign, 11'h7ff, 52'd0};
            else if (ef == 0 && q[52])
                v64_mul_pack = {sign, 11'd1, q[51:0]};
            else if (q == 0)
                v64_mul_pack = {sign, 63'd0};
            else
                v64_mul_pack = {sign, ef, q[51:0]};
        end
    endfunction
    // v64_mul_task deleted 2026-08-24: the comb 53x53 multiply moved to
    // the fpm/nwm shift-add engines; packing lives in v64_mul_pack.
    task automatic v64_array_index_task(
        input logic [63:0] value,
        output logic valid,
        output logic signed [32:0] index
    );
        logic [52:0] mant;
        logic [32:0] magnitude;
        integer unbiased;
        begin
            valid = value[62:52] != 11'h7ff;
            index = 33'sd0;
            if (valid && value[62:0] != 0 && value[62:52] != 0) begin
                mant = {1'b1, value[51:0]};
                unbiased = value[62:52] - 1023;
                if (unbiased >= 0) begin
                    if (unbiased > 31)
                        magnitude = 33'h1ffffffff;
                    else if (unbiased >= 52)
                        magnitude = 33'(mant << (unbiased - 52));
                    else
                        magnitude = 33'(mant >> (52 - unbiased));
                    index = value[63] ? -$signed(magnitude)
                                      : $signed(magnitude);
                end
            end
        end
    endtask
    task automatic v64_div_pack_task(
        input logic sign,
        input logic signed [12:0] exponent,
        input logic [106:0] quot,
        input logic [53:0] div_rem,
        output logic [63:0] result
    );
        logic [52:0] mant;
        logic [53:0] rounded;
        logic guard, sticky;
        integer top, unbiased, shift;
        begin
            top = quot[54] ? 54 : 53;
            unbiased = exponent + top - 54;
            shift = top - 52;
            if (unbiased < -1022)
                shift = shift + (-1022 - unbiased);
            mant = (shift >= 107) ? 53'd0 : 53'(quot >> shift);
            guard = 1'b0;
            sticky = |div_rem;
            if (shift > 0 && shift <= 107) begin
                guard = quot[shift - 1];
                for (int k = 0; k < 107; k++)
                    if (k < shift - 1)
                        sticky = sticky | quot[k];
            end else if (shift > 107) begin
                sticky = sticky | (|quot);
            end
            rounded = {1'b0, mant}
                    + (guard && (sticky || mant[0]));
            if (unbiased >= -1022) begin
                if (rounded[53]) begin
                    mant = rounded[53:1];
                    unbiased = unbiased + 1;
                end else
                    mant = rounded[52:0];
                if (unbiased > 1023)
                    result = {sign, 11'h7ff, 52'd0};
                else
                    result = {sign, 11'(unbiased + 1023), mant[51:0]};
            end else if (rounded[52]) begin
                result = {sign, 11'd1, 52'd0};
            end else if (rounded == 0) begin
                result = {sign, 63'd0};
            end else begin
                result = {sign, 11'd0, rounded[51:0]};
            end
        end
    endtask
    task automatic v64_mod_pack_task(
        input logic sign,
        input logic signed [12:0] exponent,
        input logic [52:0] remainder,
        output logic [63:0] result
    );
        logic [52:0] mant;
        logic [63:0] fraction;
        integer top, unbiased, shift;
        begin
            if (remainder == 0) begin
                result = {sign, 63'd0};
            end else begin
                top = 0;
                for (int k = 0; k < 53; k++)
                    if (remainder[k])
                        top = k;
                unbiased = exponent - 52 + top;
                if (unbiased >= -1022) begin
                    mant = remainder << (52 - top);
                    result = {sign, 11'(unbiased + 1023), mant[51:0]};
                end else begin
                    shift = exponent + 1022;
                    if (shift >= 0)
                        fraction = 64'(remainder) << shift;
                    else
                        fraction = 64'(remainder) >> (-shift);
                    result = {sign, 11'd0, fraction[51:0]};
                end
            end
        end
    endtask
    task automatic vst_wr(input logic [11:0] addr, input logic [63:0] data);
        vst_we_n = 1'b1;
        vst_waddr_n = addr;
        vst_wdata_n = data;
    endtask
    function automatic logic [9:0] clip_u(input logic signed [31:0] v, input int unsigned lim);
        if (v < 0) clip_u = 10'd0;
        else if (v >= lim) clip_u = 10'(lim - 1);
        else clip_u = 10'(v);
    endfunction
    // NEW: 16-bit clamp for blit source coords (ASET sheets exceed 10 bits)
    function automatic logic [15:0] clip_src(input logic signed [31:0] v);
        if (v < 0) clip_src = 16'd0;
        else if (v > 32'sd65535) clip_src = 16'd65535;
        else clip_src = 16'(v);
    endfunction
    function automatic logic [9:0] clip_sz(
        input logic signed [31:0] v,
        input logic [9:0] origin,
        input int unsigned lim
    );
        logic signed [31:0] room;
        room = lim - 32'(origin);
        if (v <= 0) clip_sz = 10'd0;
        else if (v > room) clip_sz = 10'(room);
        else clip_sz = 10'(v);
    endfunction
    function automatic logic signed [31:0] v64_to_fx(input logic [63:0] v);
        logic [10:0] exponent;
        logic [52:0] mant;
        logic [31:0] mag;
        begin
            exponent = v[62:52];
            mant = {1'b1, v[51:0]};
            mag = 32'd0;
            if (!v64_is_number(v) || exponent == 11'h7ff)
                mag = 32'd0;
            else if (exponent >= 11'd1059 && exponent < 11'd1091)
                mag = 32'(mant << (exponent - 11'd1059));
            else if (exponent >= 11'd1007 && exponent < 11'd1059)
                mag = 32'(mant >> (11'd1059 - exponent));
            v64_to_fx = v[63] ? -$signed(mag) : $signed(mag);
        end
    endfunction
    task automatic json_putc(input logic [7:0] ch);
        if (json_wp < 14'(JSON_CAP)) begin
            begin json_mem_we = 1'b1; json_mem_waddr = json_wp[12:0]; json_mem_wdata = ch; end
            json_wp_n = json_wp + 14'd1;
        end else dbg_json_ovf_n = dbg_json_ovf + 16'd1;
    endtask

    // Dedicated SRAM raddr comb — not the opcode decoder (never-fake-fpga-sim).
    // run-59 SPLIT: vconsts/vvars address from the INCOMING word
    // (code_rdata — the prefetch pre-latch; their rdata is consumed only
    // by single-beat first-touch ops in the fast path). Every other raddr
    // addresses from the CAPTURED word (opw) and stays stable through
    // EXEC — multi-beat consumers (vframe for call/return, varr walks,
    // venv) broke instantly when these moved mid-op (DONKEY rafcall=1).
    always_comb begin
        logic [11:0] cm_argc, cm_base;
        cm_argc = {4'd0, opw[31:24]};
        cm_base = (vsp_hs > cm_argc) ? (vsp_hs - cm_argc - 12'd1) : 12'd0;
        /* Phase-aware lookahead (suite caught the naive form: raddr_q
           free-runs every beat, so once the port streams N+1 mid-warmup,
           op N's own operand address was overwritten before N executed).
           Warmup/settle beats address the CURRENT op (opw); only the
           execute phase (both warmup flags set) pre-latches the incoming
           word's operands for the skip. */
`ifdef JMR_PF_SKIP
        vconsts_raddr = (opnd_q && opnd2_q) ? code_rdata[17:8] : opw[17:8];
        vvars_raddr   = (opnd_q && opnd2_q) ? code_rdata[16:8] : opw[16:8];
`else
        // PF off: bit-original — parent-owned flows (forEach FE walk) rely
        // on code_rdata addressing here while the port carries THEIR word.
        vconsts_raddr = code_rdata[17:8];
        vvars_raddr = code_rdata[16:8];
`endif
        venv_raddr = venv_hs[9:0];
        vtimer_raddr = tmr_i_q[5:0];
        vframe_raddr = (vcsp_hs != 8'd0) ? 7'(vcsp_hs - 8'd1) : 7'd0;
        fill_lut_raddr = `VST_AT(vsp - 12'd1)[9:0];
        name_hash_raddr = 10'd0;
        if (ip >= n_ops ||
            opw[7:0] == OP_RET_VAL)
            varr_raddr = (vfe_mode == 2'd2) ? vfe_map[11:0] : vfe_arr[11:0];
        else if (opw[7:0] == OP_ARR_GET)
            varr_raddr = `VST_AT(vsp - 12'd2)[11:0];
        else if (opw[7:0] == OP_SET_PROP)
            varr_raddr = `VST_AT(vsp - 12'd2)[11:0];
        else if (opw[7:0] == OP_ARR_SET)
            varr_raddr = `VST_AT(vsp - 12'd3)[11:0];
        else if (opw[7:0] == OP_CALL_METH)
            varr_raddr = `VST_AT(cm_base)[11:0];
        else
            varr_raddr = `VST_AT(vsp - 12'd1)[11:0];
        if (opw[7:0] == OP_CALL_METH) begin
            if (opw[23:8] == id_putimgdata ||
                opw[23:8] == id_drawimage)
                vobj_raddr = `VST_AT(cm_base + 12'd1)[12:0];
            else
                vobj_raddr = `VST_AT(cm_base)[12:0];
        end else if (opw[7:0] == OP_SET_PROP)
            // potential-bugs #67: SET_PROP's receiver is at vsp-2 (value on
            // top). Reading vobj_* at vsp-1 aimed the Image.src fast-path's
            // vobj_builtin check at the VALUE's string id, so the jmr:spr:N
            // match never fired: no FFC class, no sprite dims — DONKEY drew
            // no art (dihit=0) while the parent SET_PROP walk (which re-reads
            // by hp_oid) kept plain property writes working.
            vobj_raddr = `VST_AT(vsp - 12'd2)[12:0];
        else
            vobj_raddr = `VST_AT(vsp - 12'd1)[12:0];
        if (opw[7:0] == OP_CALL_METH)
            vfn_raddr = `VST_AT(cm_base)[12:0];
        else if (opw[7:0] == OP_CALL_VAL)
            vfn_raddr = `VST_AT(
                (vsp_hs > {4'd0, opw[23:8]})
                    ? (vsp_hs - {4'd0, opw[23:8]} - 12'd1)
                    : 12'd0
            )[12:0];
        else if (opw[7:0] == OP_CALL)
            // Same vsp_hs as CALL_VAL: parent hs_vsp (getContext ALLOC)
            // is TOS truth. exec vsp lags → rAF vfn_raddr hit the
            // previous slot (valid/gen miss, fault 4).
            vfn_raddr = `VST_AT(
                (vsp_hs > {4'd0, opw[31:24]})
                    ? (vsp_hs - {4'd0, opw[31:24]})
                    : 12'd0
            )[12:0];
        else
            vfn_raddr = vobj_raddr;
        if (hash2_q)
            vobj_raddr = vfn_proto_rdata[12:0];
        if (opw[7:0] == OP_ARR_GET)
            name_blen_raddr = `VST_AT(vsp - 12'd2)[9:0];
        else if (opw[7:0] == OP_CALL)
            name_blen_raddr = `VST_AT(
                (vsp_hs > {4'd0, opw[31:24]})
                    ? (vsp_hs - {4'd0, opw[31:24]})
                    : 12'd0
            )[9:0];
        else if (opw[7:0] == OP_CALL_METH &&
                 opw[23:8] == id_replace)
            // String.replace: the interned-haystack seeds (srclen, name
            // offset) are the RECEIVER's — the default aimed at the LAST
            // ARG (the replacement), so S_NAMCPY copied a garbage name
            // ("tick") instead of the string being replaced.
            name_blen_raddr = `VST_AT(cm_base)[9:0];
        else
            name_blen_raddr = `VST_AT(vsp - 12'd1)[9:0];
        name_off_raddr = name_blen_raddr;
        if (opw[7:0] == OP_CALL_METH &&
            opw[23:8] == id_replace) begin
            if (opnd_q)
                name_hash_raddr = `VST_AT(cm_base + 12'd2)[9:0];
            else
                name_hash_raddr = `VST_AT(cm_base + 12'd1)[9:0];
        end
        if (opw[7:0] == OP_CALL_METH &&
            opw[23:8] == id_indexof)
            // needle char: raddr settles during FETCH_WAIT, hash rdata is
            // valid on the dispatch beat (single-char interns hash to
            // their byte — same contract as the replace pattern char).
            name_hash_raddr = `VST_AT(vsp - 12'd1)[9:0];
    end

    always_comb begin
        aset_win_retried_n = aset_win_retried;
        cm_win_n = cm_win;
        bind_argc_n = bind_argc;
        bind_base_n = bind_base;
        bind_ip_n = bind_ip;
        bind_k_n = bind_k;
        bind_mode_n = bind_mode;
        bind_n_n = bind_n;
        bind_rd_arm_n = bind_rd_arm;
        bind_ret_n = bind_ret;
        bind_src_n = bind_src;
        bind_vsp_next_n = bind_vsp_next;
        blit_sh_n = blit_sh;
        blit_si_n = blit_si;
        blit_sw_n = blit_sw;
        blit_sx_n = blit_sx;
        blit_sy_n = blit_sy;
        cc_at_n = cc_at;
        cc_av_n = cc_av;
        cc_bok_n = cc_bok;
        cc_bt_n = cc_bt;
        cc_bv_n = cc_bv;
        cc_d_n = cc_d;
        cc_h_n = cc_h;
        cc_len_n = cc_len;
        cc_second_n = cc_second;
        cc_st_n = cc_st;
        code_raddr_n = code_raddr;
        color_n = color;
        ctx_align_n = ctx_align;
        ctx_baseline_n = ctx_baseline;
        ctx_smooth_n = ctx_smooth;
        ctx_sx_n = ctx_sx;
        ctx_sy_n = ctx_sy;
        ctx_tx_n = ctx_tx;
        ctx_ty_n = ctx_ty;
        dbg_di_hit_n = dbg_di_hit;
        dbg_di_miss_n = dbg_di_miss;
        dbg_div_n_n = dbg_div_n;
        dbg_json_ovf_n = dbg_json_ovf;
        dbg_path_ovf_n = dbg_path_ovf;
        fault_code_n = fault_code;
        fb_dump_addr_n = fb_dump_addr;
        fb_dump_sel_n = fb_dump_sel;
        // One-shot present. Holding this FF made parent see swap every
        // later EXEC cycle if it ever wired e64_fb_swap_q to mini_fb.
        fb_swap_n = 1'b0;
        fill_style_i_n = fill_style_i;
        stroke_style_i_n = stroke_style_i;
        cm_scan_n = 1'b0;
        fpm_start_n = 1'b0;
        fpm_req_n = fpm_req;
        fpm_sign_n = fpm_sign;
        fpm_ea_n = fpm_ea;
        fpm_eb_n = fpm_eb;
        fpm_ma_n = 53'd0;
        fpm_mb_n = 53'd0;
        lsv_scan_n = lsv_scan; // level holds until the result is consumed
        lsv_op_n = lsv_op;
        lsv_ev_n = lsv_ev;
        lsv_fn_n = lsv_fn;
        lsv_push_n = lsv_push;
        lsv_base_n = lsv_base;
        cm_armed_n = 1'b0;
        cm_done_n = cm_done;
        cm_c_n = cm_c;
        cm_m_n = cm_m;
        cm_mip_n = cm_mip;
        cm_key_n = cm_key;
        cm_cls_n = cm_cls;
        hp_aid_n = hp_aid;
        hp_alen_n = hp_alen;
        hp_aslot_n = hp_aslot;
        hp_cmd_n = hp_cmd;
        hp_eid_n = hp_eid;
        hp_env_n = hp_env;
        hp_from_stack_n = hp_from_stack;
        hp_hit_n = hp_hit;
        hp_key_n = hp_key;
        hp_len_n = hp_len;
        hp_lim_n = hp_lim;
        hp_make_arr_n = hp_make_arr;
        hp_nat_n = hp_nat;
        hp_oid_n = hp_oid;
        hp_phase_n = hp_phase;
        hp_proto_n = hp_proto;
        hp_qi_n = hp_qi;
        hp_qn_n = hp_qn;
        hp_ret_n = hp_ret;
        hp_rval_n = hp_rval;
        hp_si_n = hp_si;
        hp_slot_n = hp_slot;
        hp_spr_h_n = hp_spr_h;
        hp_spr_w_n = hp_spr_w;
        hp_ss_n = hp_ss;
        hp_tag_n = hp_tag;
        hp_tn_n = hp_tn;
        hp_v64_n = hp_v64;
        hp_vbase_n = hp_vbase;
        hp_wval_n = hp_wval;
        imgd_armed_n = imgd_armed;
        imgd_h_n = imgd_h;
        imgd_i_n = imgd_i;
        imgd_n_n = imgd_n;
        imgd_v64_n = imgd_v64;
        imgd_w_n = imgd_w;
        imgd_x_n = imgd_x;
        imgd_x0_n = imgd_x0;
        imgd_y_n = imgd_y;
        imgd_y0_n = imgd_y0;
        ip_n = ip;
        jn_arr_n = jn_arr;
        jn_h_n = jn_h;
        jn_i_n = jn_i;
        jn_res_n = jn_res;
        js_sp_n = js_sp;
        json_pph_n = json_pph;
        json_rp_n = json_rp;
        json_src_n = json_src;
        json_srclen_n = json_srclen;
        json_wp_n = json_wp;
        looping_n = looping;
        machine_fault_n = machine_fault;
        fault_site_n = fault_site;
        minmax_acc_n = minmax_acc;
        minmax_base_n = minmax_base;
        minmax_is_min_n = minmax_is_min;
        minmax_k_n = minmax_k;
        minmax_n_n = minmax_n;
        namcpy_armed_n = namcpy_armed;
        namcpy_repl_n = namcpy_repl;
        namcpy_v64_n = namcpy_v64;
        name_rdaddr_n = name_rdaddr;
        path_active_n = path_active;
        path_kind_n = path_kind;
        path_stroke_n = path_stroke;
        pc_n_n = pc_n;
        pi_n = pi;
        repl_did_n = repl_did;
        repl_g_n = repl_g;
        repl_nlen_n = repl_nlen;
        repl_pat0_n = repl_pat0;
        repl_pat1_n = repl_pat1;
        repl_rch_n = repl_rch;
        rh_n = rh;
        running_n = running;
        rw_n = rw;
        rx_n = rx;
        ry_n = ry;
        saved_sx_n = saved_sx;
        saved_sy_n = saved_sy;
        saved_tx_n = saved_tx;
        saved_ty_n = saved_ty;
        sq_i_n = sq_i;
        sq_rad_n = sq_rad;
        sq_rem_n = sq_rem;
        sq_root_n = sq_root;
        state_n = p_state;
        txt_bn_n = txt_bn;
        txt_ph_n = txt_ph;
        txt_px_n = txt_px;
        txt_py_n = txt_py;
        txt_val_n = txt_val;
        txt_vt_n = txt_vt;
        v64_concat_n = v64_concat;
        v64_join_n = v64_join;
        v64_repl_n = v64_repl;
        v64_sqrt_n = v64_sqrt;
        valloc_arr_n_n = valloc_arr_n;
        valloc_bind_n = valloc_bind;
        valloc_bind_src_n = valloc_bind_src;
        valloc_bind_this_n = valloc_bind_this;
        valloc_fn_a1_n = valloc_fn_a1;
        valloc_fn_entry_n = valloc_fn_entry;
        valloc_i_n = valloc_i;
        valloc_kind_n = valloc_kind;
        valloc_metrics_n = valloc_metrics;
        valloc_now_fn_n = valloc_now_fn;
        valloc_proto_n = valloc_proto;
        valloc_proto_fn_n = valloc_proto_fn;
        valloc_regex_n = valloc_regex;
        valloc_regex_pack_n = valloc_regex_pack;
        valloc_retried_n = valloc_retried;
        varr_next_n = varr_next;
        vcall_argc_n = vcall_argc;
        vcall_ctor_val_n = vcall_ctor_val;
        ctor_cur_n = ctor_cur;
        ctor_csp_n = ctor_csp;
        vcall_entry_n = vcall_entry;
        vcall_set_this_n = vcall_set_this;
        vcall_this_n = vcall_this;
        vcall_value_n = vcall_value;
        vconsole_n_n = vconsole_n;
        vcsp_n = vcsp;
        vdiv_count_n = vdiv_count;
        vdiv_den_n = vdiv_den;
        vdiv_exp_n = vdiv_exp;
        vdiv_num_n = vdiv_num;
        vdiv_quot_n = vdiv_quot;
        vdiv_rem_n = vdiv_rem;
        vdiv_sign_n = vdiv_sign;
        vdraw_color_n = vdraw_color;
        vdraw_h_n = vdraw_h;
        vdraw_i_n = vdraw_i;
        vdraw_w_n = vdraw_w;
        vdraw_x_n = vdraw_x;
        vdraw_y_n = vdraw_y;
        venv_n = venv_hs;
        venv_next_n = venv_next;
        vfe_arr_n = vfe_arr;
        vfe_base_n = vfe_base;
        vfe_fn_n = vfe_fn;
        vfe_i_n = vfe_i;
        vfe_len_n = vfe_len;
        vfe_map_n = vfe_map;
        vfe_mode_n = vfe_mode;
        vfe_reduce_n = vfe_reduce;
        vfe_findidx_n = vfe_findidx;
        vfe_sort_n = vfe_sort;
        vfe_ret_n = vfe_ret;
        vfe_sp_n = vfe_sp;
        vfree_armed_n = vfree_armed;
        vfree_arr_long_n = vfree_arr_long;
        vgc_clear_i_n = vgc_clear_i;
        vgc_halt_after_n = vgc_halt_after;
        vgc_qr_n = vgc_qr;
        vgc_qw_n = vgc_qw;
        vgc_resume_n = vgc_resume;
        vgc_wait_after_n = vgc_wait_after;
        vjs_rd_arm_n = vjs_rd_arm;
        vlistener_n_n = vlistener_n;
        vmetrics_w_n = vmetrics_w;
        vmod_count_n = vmod_count;
        vmod_den_n = vmod_den;
        vmod_exp_n = vmod_exp;
        vmod_rem_n = vmod_rem;
        vmod_sign_n = vmod_sign;
        vnat_base_n = vnat_base;
        vnat_dom_n = vnat_dom;
        vprom_copy_n = vprom_copy;
        vprom_done_n = vprom_done;
        vprom_ret_n = vprom_ret;
        vraf_n_n = vraf_n;
        vrng_n = vrng;
        vsp_n = vsp_hs;
        vst_hold_win_n = vst_hold_win;
        vst_refill_arm_n = vst_refill_arm;
        vst_refill_i_n = vst_refill_i;
        vst_refill_ret_n = vst_refill_ret;
        vst_waddr_n = vst_waddr;
        vst_wdata_n = vst_wdata;
        // Pulse: holding we replayed the previous write on opnd2 / CALL_VAL.
        vst_we_n = 1'b0;
        vthis_n = vthis_hs;
        vtimer_n_n = vtimer_n;
        vtimer_seq_n = vtimer_seq;
        x_n = x;
        y_n = y;
        // No whole-array combo copies. Scalar we; FFs hold.
        hp_q_we = 1'b0;
        hp_q_waddr = 2'd0;
        hp_qk_wdata = '0;
        hp_qt_wdata = '0;
        hp_qv_wdata = '0;
        js_we = 1'b0;
        js_waddr = '0;
        js_i_wdata = '0;
        js_ph_wdata = '0;
        vjs_val_wdata = '0;
        pc_we = 1'b0;
        pc_waddr = '0;
        pc_a1_wdata = '0;
        pc_a2_wdata = '0;
        pc_a3_wdata = '0;
        pc_a4_wdata = '0;
        pc_a5_wdata = '0;
        pc_ccw_wdata = 1'b0;
        pc_op_wdata = '0;
        vfe_s_we = 1'b0;
        vfe_s_waddr = '0;
        vfe_arr_s_wdata = '0;
        vfe_base_s_wdata = '0;
        vfe_fn_s_wdata = '0;
        vfe_i_s_wdata = '0;
        vfe_len_s_wdata = '0;
        vfe_map_s_wdata = '0;
        vfe_mode_s_wdata = '0;
        vfe_reduce_s_wdata = 1'b0;
        vfe_findidx_s_wdata = 1'b0;
        vfe_sort_s_wdata = 1'b0;
        vfe_ret_s_wdata = '0;
        json_mem_we = 1'b0;
        json_mem_waddr = '0;
        json_mem_wdata = '0;
        vraf_we = 1'b0;
        vraf_waddr = '0;
        vraf_wdata = '0;
        vtimer_we = 1'b0;
        vtimer_waddr = '0;
        vtimer_valid_wdata = 1'b0;
        vtimer_due_wdata = '0;
        vtimer_fn_wdata = '0;
        vtimer_id_wdata = '0;
        vtimer_period_wdata = '0;
        vst_win0_we = 1'b0;
        vst_win0_wdata = '0;
        opnd_n = 1'b0;
        opnd2_n = 1'b0;
        opnd3_n = 1'b0;
        hash2_n = 1'b0;
        venvw_n = 3'd0;
        tmr_i_n = 7'd0;
        tmr_found_n = 1'b0;
        tmr_slot_n = 7'd0;
        name_blen_we = 1'b0;
        name_blen_waddr = 10'd0;
        name_blen_wdata = 16'd0;
        name_hash_we = 1'b0;
        name_hash_waddr = 10'd0;
        name_hash_wdata = 16'd0;
        name_has_we = 1'b0;
        name_has_waddr = 10'd0;
        name_has_wdata = 1'b0;
        varr_len_we = 1'b0;
        varr_len_waddr = '0;
        varr_len_wdata = '0;
        varr_lidx_we = 1'b0;
        varr_lidx_waddr = '0;
        varr_lidx_wdata = '0;
        varr_long_we = 1'b0;
        varr_long_waddr = '0;
        varr_long_wdata = '0;
        varr_valid_we = 1'b0;
        varr_valid_waddr = '0;
        varr_valid_wdata = '0;
        venv_gen_we = 1'b0;
        venv_gen_waddr = '0;
        venv_gen_wdata = '0;
        venv_len_we = 1'b0;
        venv_len_waddr = '0;
        venv_len_wdata = '0;
        venv_valid_we = 1'b0;
        venv_valid_waddr = '0;
        venv_valid_wdata = '0;
        vobj_cls_we = 1'b0;
        vobj_cls_waddr = '0;
        vobj_cls_wdata = '0;
        vvar_valid_we = 1'b0;
        vvar_valid_waddr = '0;
        vvar_valid_wdata = '0;
        vvars_we = 1'b0;
        snd_stb_c = 1'b0;
        snd_ch_c = '0; snd_freq_c = '0; snd_vol_c = '0;
        snd_frames_c = '0; snd_slide_c = '0;
        vvars_waddr = '0;
        vvars_wdata = '0;
        vframe_we = 1'b0;
        vframe_waddr = '0;
        vframe_rip_wdata = '0;
        vframe_bsp_wdata = '0;
        vframe_esc_wdata = 1'b0;
        vframe_this_wdata = '0;
        vframe_env_wdata = '0;
        vframe_fn_wdata = '0;
        vframe_ctor_wdata = '0;
        if (enable && !leave_hold) begin
                    opnd_n = opnd_q;
                    opnd2_n = opnd2_q;
                    opnd3_n = opnd3_q;
                    tmr_i_n = tmr_i_q;
        tmr_arm_n = tmr_arm_q;
                    tmr_found_n = tmr_found_q;
                    tmr_slot_n = tmr_slot_q;
                    if (!opnd_q && tmr_i_q == 7'd0) begin
                        // Beat 1: clock raddr_q from this instruction.
                        opnd_n = 1'b1;
                        state_n = S_V64_EXEC;
                        // Leftover vst_we must not hold through opnd2: CALL_VAL
                        // then re-wrote MAKE_FN into TOS (nonempty IIFE fault 4).
                        vst_we_n = 1'b0;
                        /* run-59 prefetch v2 (built from the hs-trace, not the
                           handshake myth): exec64 SELF-dispatches here; opw_q
                           holds this op's word from the wait beats, so the
                           code port is free from this beat on — advance it to
                           ip+1 now. Word N+1 is on code_rdata through the
                           execute beats; the op-end override can then retire
                           the whole wait/warmup sequence for sequential flow. */
`ifdef JMR_PF_SKIP
                        code_raddr_n = 15'(ops_base + ip + 16'd1);
`endif
                    end else if (opnd_q && !opnd2_q && tmr_i_q == 7'd0) begin
                        // Beat 2: parent *_rdata catches raddr_q (leftover 3).
                        opnd_n = 1'b1;
                        opnd2_n = 1'b1;
                        state_n = S_V64_EXEC;
                        vst_we_n = 1'b0;
                    end else if (opnd_q && opnd2_q && !opnd3_q &&
                                tmr_i_q == 7'd0 &&
                                (opw[7:0] == OP_CALL ||
                                 opw[7:0] == OP_CALL_VAL ||
                                 opw[7:0] == OP_CALL_METH)) begin
                        // Beat 3: exec samples parent rdata after ALLOC
                        // freeze (getElementById / FRAME_RAF env). Two
                        // waits left rAF seeing !vfn_valid_rdata while
                        // slot 0 was already valid. Do not apply this to
                        // every opcode — that stalled FRAME at ~20 ops.
                        opnd_n = 1'b1;
                        opnd2_n = 1'b1;
                        opnd3_n = 1'b1;
                        state_n = S_V64_EXEC;
                        vst_we_n = 1'b0;
                    end else if (fpm_req) begin
                        // OP_MUL in the 53-beat engine: hold; complete on
                        // the beat busy drops (acc is final that beat).
                        opnd_n = 1'b1;
                        opnd2_n = 1'b1;
                        opnd3_n = 1'b1;
                        if (!fpm_busy) begin
                            logic [63:0] mres;
                            mres = v64_mul_pack(fpm_sign, fpm_ea, fpm_eb, fpm_acc);
                            fpm_req_n = 1'b0;
                            vst_wr(vsp - 12'd2, mres);
                            vsp_n = vsp - 12'd1;
                            ip_n = ip + 16'd1;
                            code_raddr_n = 15'(ops_base + ip + 16'd1);
                            state_n = S_FETCH_WAIT;
                        end else
                            state_n = S_V64_EXEC;
                    end else if (lsv_scan) begin
                        // held while the parent walks the listener table
                        opnd_n = 1'b1;
                        opnd2_n = 1'b1;
                        opnd3_n = 1'b1;
                        if (lsv_res_we) begin
                            lsv_scan_n = 1'b0;
                            if (lsv_res == 3'd0 || lsv_res == 3'd1) begin
                                vlistener_n_n = lsv_res_n;
                                vst_wr(lsv_base, lsv_push);
                                vsp_n = lsv_base + 12'd1;
                                ip_n = ip + 16'd1;
                                code_raddr_n = 15'(ops_base + ip + 16'd1);
                                state_n = S_FETCH_WAIT;
                            end else begin
                                // 2 = same-event cap, 3 = table full
                                machine_fault_n = 1'b1;
                                fault_code_n = 8'd3;
                                fault_site_n = 16'd8200 + 16'(lsv_res);
                                running_n = 1'b0;
                                state_n = S_DONE;
                            end
                        end else
                            state_n = S_V64_EXEC;
                    end else if (cm_scan) begin
                        // Hold with the request level up; the parent's
                        // sequential class scanner answers on cm_res_we.
                        opnd_n = 1'b1;
                        opnd2_n = 1'b1;
                        opnd3_n = 1'b1;
                        cm_key_n = cm_key;
                        cm_cls_n = cm_cls;
                        cm_scan_n = 1'b1; // hold the request level (2951 default-clears)
                        if (cm_res_we) begin
                            cm_mip_n = cm_res_mip;
                            cm_scan_n = 1'b0;
                            cm_armed_n = 1'b0;
                            cm_done_n = 1'b1;
                        end
                        state_n = S_V64_EXEC;
                    end else
                    // Small gated scalar island. Every opcode not implemented
                    // here faults with ERROR_UNSUPPORTED; it never falls into
                    // the legacy tagged/Q16 executor.
                    if (ip >= n_ops) begin
                        // PYTHON _execute_value64: falling off n_ops with a
                        // live call frame is an implicit RET_VAL undefined,
                        // not fault 2. Compiler emits RET_VAL at function
                        // ends, but JUMP to n_ops / IIFE-as-script still
                        // lands here (DONKEY vcsp=1, PACMAN vcsp=3).
                        if (vcsp_hs != 0) begin
                            if (vframe_rip_rdata == 16'hfffc &&
                                vfe_arr[63:48] == V64_TAG_PREFIX &&
                                vfe_arr[47:44] == V64_KIND_ARRAY &&
                                vfe_i != 8'd0 && vfe_i <= vfe_len) begin
                                // potential-bugs #6: a callback body that
                                // runs off n_ops (JUMP to n_ops / IIFE tail,
                                // no trailing RET_VAL) is an implicit
                                // `return undefined`, not the end of the
                                // program. The unguarded arm below sent EVERY
                                // 0xfffc frame to GC_CLEAR + halt_after, so
                                // the walk died mid-array and the later
                                // 0xfffc -> FOREACH arm (~3262) was dead
                                // code. Deleting that arm instead is wrong:
                                // 0xfffc would then fall into the
                                // `vsp_hs != vframe_bsp_rdata` fault 1, which
                                // is exactly the one_fe failure the arm was
                                // added for (falling off n_ops normally
                                // leaves the last expression above bsp).
                                // Guard on "the walk is still live": vfe_i is
                                // pre-incremented in S_V64_FOREACH, so
                                // mid-walk is 1..vfe_len inclusive, and the
                                // done path clears vfe_arr to UNDEFINED at
                                // vfe_sp==0. Same body as OP_RET_VAL 0xfffc
                                // (~4496) minus the find/filter TOS tests —
                                // an implicit return has no value.
                                if (vfe_reduce)
                                    vfe_map_n = V64_UNDEFINED; // #39
                                if (vfe_sort)
                                    vfe_map_n = 64'd0; // #41 cmp 0: no swap
                                vthis_n = vframe_this_rdata;
                                venv_n = vframe_env_rdata;
                                vcsp_n = vcsp_hs - 8'd1;
                                vsp_n = vframe_bsp_rdata;
                                if (vfe_mode == 2'd2 &&
                                    vfe_map[63:48] == V64_TAG_PREFIX &&
                                    vfe_map[47:44] == V64_KIND_ARRAY &&
                                    varr_valid_rdata &&
                                    (vfe_i - 8'd1) < varr_len_rdata)
                                begin
                                    hp_cmd_n = HP_ASETI;
                                    hp_v64_n = 1'b1;
                                    hp_from_stack_n = 1'b0;
                                    hp_aid_n = vfe_map[11:0];
                                    hp_aslot_n = 7'(vfe_i - 8'd1);
                                    hp_wval_n = V64_UNDEFINED;
                                    hp_ret_n = S_V64_FOREACH;
                                    state_n = S_HEAP_AWR;
                                end else
                                    state_n = S_V64_FOREACH;
                            end else if (vframe_rip_rdata == 16'hfffc) begin
                                // Leftover forEach frame after the walk
                                // continued at vfe_ret (one_fe nops fault 1
                                // blocked GC_CLEAR; rAF never parked).
                                vcsp_n = vcsp_hs - 8'd1;
                                vsp_n = 12'd0;
                                vgc_clear_i_n = 14'd0;
                                vgc_qr_n = 14'd0;
                                vgc_qw_n = 14'd0;
                                vgc_halt_after_n = 1'b1;
                                vgc_wait_after_n = (vraf_n != 0 ||
                                    vtimer_n != 0 || vlistener_n != 0);
                                state_n = S_V64_GC_CLEAR;
                            end else if (vsp_hs != vframe_bsp_rdata) begin
                            machine_fault_n = 1'b1;
                            fault_code_n = 8'd1;
                            fault_site_n = 16'd3198;
                            running_n = 1'b0;
                            state_n = S_DONE;
                            end else begin
                                // Same leaf-env recycle as OP_RET_VAL.
                                if (!vframe_esc_rdata &&
                                    venv[63:48] == V64_TAG_PREFIX &&
                                    venv[47:44] == V64_KIND_ENV &&
                                    venv[31:0] < ENV_DEPTH &&
                                    venv_valid_rdata &&
                                    venv_gen_rdata == venv[43:32] &&
                                    venv != vframe_env_rdata) begin
                                    begin venv_valid_we = 1'b1; venv_valid_waddr = venv[9:0]; venv_valid_wdata = 1'b0; end
                                    begin venv_len_we = 1'b1; venv_len_waddr = venv[9:0]; venv_len_wdata = 5'd0; end
                                    venv_gen_we = 1'b1; venv_gen_waddr = venv[9:0]; venv_gen_wdata =
                                        (venv_gen_rdata == 12'hfff)
                                        ? 12'd1
                                        : (venv_gen_rdata + 12'd1);
                                    if (venv_next > venv[9:0])
                                        venv_next_n = venv[9:0];
                                end
                                vthis_n = vframe_this_rdata;
                                venv_n = vframe_env_rdata;
                                vcsp_n = vcsp_hs - 8'd1;
                                if (vframe_rip_rdata ==
                                    16'hffff) begin
                                    vsp_n = vframe_bsp_rdata;
                                    state_n = S_V64_FRAME_RAF;
                                end else if (
                                    vframe_rip_rdata ==
                                    16'hfffe
                                ) begin
                                    vsp_n = vframe_bsp_rdata;
                                    state_n = S_V64_FRAME_TIMER;
                                end else if (
                                    vframe_rip_rdata ==
                                    16'hfffd
                                ) begin
                                    vsp_n = vframe_bsp_rdata;
                                    state_n = S_V64_FRAME_KEY;
                                end else if (
                                    vframe_rip_rdata ==
                                    16'hfffc
                                ) begin
                                    // implicit undefined: find/filter miss;
                                    // map stores undefined.
                                    if (vfe_reduce)
                                        vfe_map_n = V64_UNDEFINED; // #39
                                    if (vfe_sort)
                                        vfe_map_n = 64'd0; // #41
                                    vsp_n = vframe_bsp_rdata;
                                    if (vfe_mode == 2'd2 &&
                                        vfe_map[63:48] == V64_TAG_PREFIX &&
                                        vfe_map[47:44] == V64_KIND_ARRAY &&
                                        varr_valid_rdata &&
                                        (vfe_i - 8'd1) <
                                            varr_len_rdata)
                                    begin
                                        hp_cmd_n = HP_ASETI;
                                        hp_v64_n = 1'b1;
                                        hp_from_stack_n = 1'b0;
                                        hp_aid_n = vfe_map[11:0];
                                        hp_aslot_n = 7'(vfe_i - 8'd1);
                                        hp_wval_n = V64_UNDEFINED;
                                        hp_ret_n = S_V64_FOREACH;
                                        state_n = S_HEAP_AWR;
                                    end else
                                        state_n = S_V64_FOREACH;
                                end else begin
                                    vst_wr(vframe_bsp_rdata,
                                           V64_UNDEFINED);
                                    vsp_n =
                                        vframe_bsp_rdata + 12'd1;
                                    ip_n = vframe_rip_rdata;
                                    code_raddr_n = 15'(
                                        ops_base +
                                        vframe_rip_rdata
                                    );
                                    // Same win[1] refill as OP_RET_VAL.
                                    if (vframe_bsp_rdata
                                            >= 12'd1) begin
                                        vst_refill_i_n = 4'd1;
                                        vst_refill_arm_n = 1'b0;
                                        vst_refill_ret_n = S_FETCH_WAIT;
                                        vst_hold_win_n = 1'b1;
                                        vst_win0_we = 1'b1;
                                        vst_win0_wdata = V64_UNDEFINED;
                                        state_n = S_V64_WIN_FILL;
                                    end else
                                    state_n = S_FETCH_WAIT;
                                end
                            end
                        end else begin
                            // Script end. Leftover TOS (forEach done
                            // hs_vsp(base+1) then native CALL) is not a
                            // machine fault — PYTHON drops it. Faulting
                            // here skipped GC_CLEAR so rAF never parked
                            // (fe_then_raf IDLE raf=0, PACMAN nops).
                            vsp_n = 12'd0;
                            vgc_clear_i_n = 14'd0;
                            vgc_qr_n = 14'd0;
                            vgc_qw_n = 14'd0;
                            vgc_halt_after_n = 1'b1;
                            vgc_wait_after_n = (vraf_n != 0 ||
                                vtimer_n != 0 || vlistener_n != 0);
                            state_n = S_V64_GC_CLEAR;
                        end
                    end else begin
                        // Plain case: unique made Vivado build every opcode
                        // in parallel (~100 GB, no bitstream). Small unique
                        // cases elsewhere stay.
                        case (opw[7:0])
                            OP_LOAD_CONST: begin
                                if (vsp >= 12'(STACK_DEPTH)) begin
                                    machine_fault_n = 1'b1; fault_code_n = 8'd1; fault_site_n = 16'd3310;
                                    running_n = 1'b0; state_n = S_DONE;
                                end else if ((opw[31:24] == 8'd0 ||
                                             opw[31:24] == 8'd3) &&
                                             opw[23:8] >= n_consts) begin
                                    machine_fault_n = 1'b1; fault_code_n = 8'd5; fault_site_n = 16'd3315;
                                    running_n = 1'b0; state_n = S_DONE;
                                end else if (opw[31:24] == 8'd0 ||
                                             opw[31:24] == 8'd3) begin
                                    vst_wr(vsp, (vconsts_rdata[62:52] == 11'h7ff &&
                                         vconsts_rdata[51:0] != 0)
                                        ? V64_CANON_NAN
                                        : vconsts_rdata);
                                    vsp_n = vsp + 12'd1;
                                    ip_n = ip + 16'd1;
                                    code_raddr_n = 15'(ops_base + ip + 16'd1);
                                    state_n = S_FETCH_WAIT;
                                end else if (opw[31:24] == 8'd1 &&
                                             opw[23:8] < names_n) begin
                                    vst_wr(vsp, v64_handle(
                                        4'd4, 12'd0,
                                        {16'd0, opw[23:8]}
                                    ));
                                    vsp_n = vsp + 12'd1;
                                    ip_n = ip + 16'd1;
                                    code_raddr_n = 15'(ops_base + ip + 16'd1);
                                    state_n = S_FETCH_WAIT;
                                end else if (opw[31:24] == 8'd2) begin
                                    vst_wr(vsp, V64_UNDEFINED);
                                    vsp_n = vsp + 12'd1;
                                    ip_n = ip + 16'd1;
                                    code_raddr_n = 15'(ops_base + ip + 16'd1);
                                    state_n = S_FETCH_WAIT;
                                end else if (opw[31:24] == 8'd4) begin
                                    // RegExp stub — keep packed /pat/g from the
                                    // const pool so String.replace can read it.
                                    valloc_regex_n = 1'b1;
                                    valloc_regex_pack_n =
                                        vconsts_rdata[31:0];
                                    vnat_base_n = vsp;
                                    valloc_kind_n = 2'd0;
                                    valloc_i_n = vobj_next;
                                    valloc_retried_n = 1'b0;
                                    state_n = S_V64_ALLOC;
                                end else begin
                                    machine_fault_n = 1'b1; fault_code_n = 8'd5; fault_site_n = 16'd3355;
                                    running_n = 1'b0; state_n = S_DONE;
                                end
                            end
                            OP_LOAD_VAR: begin
                                if (vsp >= 12'(STACK_DEPTH)) begin
                                    machine_fault_n = 1'b1; fault_code_n = 8'd1; fault_site_n = 16'd3361;
                                    running_n = 1'b0; state_n = S_DONE;
                                end else if (opw[23:17] != 0) begin
                                    machine_fault_n = 1'b1; fault_code_n = 8'd5; fault_site_n = 16'd3364;
                                    running_n = 1'b0; state_n = S_DONE;
                                end else if (this_ok &&
                                             opw[16:8] == var_this) begin
                                    vst_wr(vsp, vthis);
                                    vsp_n = vsp + 12'd1;
                                    ip_n = ip + 16'd1;
                                    code_raddr_n =
                                        15'(ops_base + ip + 16'd1);
                                    state_n = S_FETCH_WAIT;
                                // a1==1: compiler global — skip env chain (vvars).
                                end else if (opw[31:24] == 8'd1) begin
                                    vst_wr(vsp, vvar_valid_rdata
                                            ? vvars_rdata
                                        : V64_UNDEFINED);
                                    vsp_n = vsp + 12'd1;
                                    ip_n = ip + 16'd1;
                                    code_raddr_n =
                                        15'(ops_base + ip + 16'd1);
                                    state_n = S_FETCH_WAIT;
                                end else if (venv[63:48] == 16'h7ff9 &&
                                             venv[47:44] == 4'd9) begin
                                    if (venv[31:0] >= ENV_DEPTH) begin
                                        machine_fault_n = 1'b1;
                                        fault_code_n = 8'd4;
                                        fault_site_n = 16'd60001;
                                        running_n = 1'b0;
                                        state_n = S_DONE;
                                    // venv_valid_rdata lags venv_raddr by a
                                    // parent Port A beat. After a ctor return
                                    // pokes venv, the same-cycle bit was the
                                    // PREVIOUS env's — a live env read 0 and
                                    // faulted 4 (PACMAN `new Stage()`; the
                                    // table really held valid=1). One settle
                                    // beat, then trust it. Extra clock is OK.
                                    end else if (!venv_valid_rdata &&
                                                 venvw_q < 3'd4) begin
                                        venvw_n = venvw_q + 3'd1;
                                        hash2_n = 1'b1;
                                        opnd_n = 1'b1;
                                        opnd2_n = 1'b1;
                                        state_n = S_V64_EXEC;
                                    end else if (!venv_valid_rdata) begin
                                        machine_fault_n = 1'b1;
                                        fault_code_n = 8'd4;
                                        fault_site_n = 16'd60002;
                                        running_n = 1'b0;
                                        state_n = S_DONE;
                                    end else begin
                                        hp_env_n = 1'b1;
                                        hp_cmd_n = HP_GETPROP;
                                        hp_v64_n = 1'b1;
                                        hp_eid_n = venv[9:0];
                                        hp_len_n = {1'b0, venv_len_rdata};
                                        // potential-bugs #55: the a1>=2 slot
                                        // hint used to seed the scan START,
                                        // but the parent env walk runs
                                        // hint..len-1 and never revisits the
                                        // skipped prefix. The compiler inliner
                                        // can rebind a name at a LOWER slot
                                        // than the callee body's hint (place's
                                        // `sz` at slot 0, inlined spawn hint
                                        // slot 1) — the walk then missed the
                                        // key, fell to the parent env / vvars
                                        // and returned undefined with no
                                        // fault (ASTEROID spawnRock fields).
                                        // PYTHON ignores the hint (dict by
                                        // name id). Never TRUST the hint —
                                        // but a VERIFIED first guess is
                                        // safe: phase 5 reads the hinted
                                        // slot, compares the key, and on
                                        // any mismatch the parent restarts
                                        // a full scan from slot 0 (no
                                        // prefix ever skipped). Local
                                        // reads were the top ENVWALK sink
                                        // (INVADERS crater loop dx/dy/r).
                                        hp_slot_n = (opw[31:24] >= 8'd2)
                                            ? 5'(opw[31:24] - 8'd2)
                                            : 5'd0;
                                        hp_key_n = {7'd0, opw[16:8]};
                                        hp_phase_n = (opw[31:24] >= 8'd2)
                                            ? 3'd5 : 3'd0;
                                        hp_hit_n = 1'b0;
                                        hp_ret_n = S_FETCH_WAIT;
                                        state_n = S_HEAP_WAIT;
                                    end
                                end else begin
                                    vst_wr(vsp, vvar_valid_rdata
                                            ? vvars_rdata
                                        : V64_UNDEFINED);
                                        vsp_n = vsp + 12'd1;
                                        ip_n = ip + 16'd1;
                                        code_raddr_n =
                                            15'(ops_base + ip + 16'd1);
                                        state_n = S_FETCH_WAIT;
                                end
                            end
                            OP_STORE_VAR, OP_LET_VAR: begin
                                if (vsp == 0) begin
                                    machine_fault_n = 1'b1; fault_code_n = 8'd1; fault_site_n = 16'd3423;
                                    running_n = 1'b0; state_n = S_DONE;
                                end else if (opw[23:17] != 0) begin
                                    machine_fault_n = 1'b1; fault_code_n = 8'd5; fault_site_n = 16'd3426;
                                    running_n = 1'b0; state_n = S_DONE;
                                end else if (this_ok &&
                                             opw[16:8] == var_this &&
                                             !(opw[7:0] == OP_LET_VAR &&
                                               opw[24])) begin
                                    if (opw[7:0] == OP_STORE_VAR ||
                                        !vvar_valid_rdata)
                                        vthis_n = `VST_AT(vsp - 12'd1);
                                    vsp_n = vsp - 12'd1;
                                    ip_n = ip + 16'd1;
                                    code_raddr_n =
                                        15'(ops_base + ip + 16'd1);
                                    state_n = S_FETCH_WAIT;
                                end else if (opw[7:0] == OP_STORE_VAR &&
                                             opw[31:24] == 8'd1) begin
                                    // a1==1 global store — skip env chain.
                                    vvars_we = 1'b1;
                                    vvars_waddr = opw[16:8];
                                    vvars_wdata = `VST_AT(vsp - 12'd1);
                                    begin vvar_valid_we = 1'b1;
                                        vvar_valid_waddr = opw[16:8];
                                        vvar_valid_wdata = 1'b1; end
                                    vsp_n = vsp - 12'd1;
                                    ip_n = ip + 16'd1;
                                    code_raddr_n =
                                        15'(ops_base + ip + 16'd1);
                                    state_n = S_FETCH_WAIT;
                                end else if (opw[7:0] == OP_LET_VAR &&
                                             opw[24] && vcsp_hs == 0) begin
                                        // Parent ALLOC hs_vcsp is visible this
                                        // cycle; exec vcsp FF lags (INVADERS
                                        // renderLeaderboard LET_VAR list).
                                        machine_fault_n = 1'b1;
                                    fault_code_n = 8'd2;
                                    fault_site_n = 16'd3456;
                                        running_n = 1'b0;
                                        state_n = S_DONE;
                                    // Settle beat before the flat-IIFE test:
                                    // a stale venv_valid 0 silently stored a
                                    // local into the global table instead.
                                    end else if (opw[7:0] == OP_LET_VAR &&
                                             opw[24] &&
                                             venv[63:48] == 16'h7ff9 &&
                                             venv[47:44] == 4'd9 &&
                                             venv[31:0] < ENV_DEPTH &&
                                             !venv_valid_rdata && !hash2_q) begin
                                        hash2_n = 1'b1;
                                        opnd_n = 1'b1;
                                        opnd2_n = 1'b1;
                                        state_n = S_V64_EXEC;
                                    end else if (opw[7:0] == OP_LET_VAR &&
                                             opw[24] &&
                                             (venv[63:48] != 16'h7ff9 ||
                                            venv[47:44] != 4'd9 ||
                                            venv[31:0] >= ENV_DEPTH ||
                                              !venv_valid_rdata)) begin
                                    // Flat IIFE: LET_VAR local with no ENV
                                    // stores the global (PYTHON / JSB a1 bit6).
                                    vvars_we = 1'b1; vvars_waddr = opw[16:8]; vvars_wdata =
                                        `VST_AT(vsp - 12'd1);
                                    begin vvar_valid_we = 1'b1; vvar_valid_waddr = opw[16:8]; vvar_valid_wdata = 1'b1; end
                                    vsp_n = vsp - 12'd1;
                                    ip_n = ip + 16'd1;
                                    code_raddr_n =
                                        15'(ops_base + ip + 16'd1);
                                    state_n = S_FETCH_WAIT;
                                end else if (venv[63:48] == 16'h7ff9 &&
                                             venv[47:44] == 4'd9) begin
                                    if (venv[31:0] >= ENV_DEPTH) begin
                                            machine_fault_n = 1'b1;
                                        fault_code_n = 8'd4;
                                        fault_site_n = 16'd60003;
                                            running_n = 1'b0;
                                            state_n = S_DONE;
                                    // Same Port A lag as LOAD_VAR above.
                                    end else if (!venv_valid_rdata &&
                                                 venvw_q < 3'd4) begin
                                        venvw_n = venvw_q + 3'd1;
                                        hash2_n = 1'b1;
                                        opnd_n = 1'b1;
                                        opnd2_n = 1'b1;
                                        state_n = S_V64_EXEC;
                                    end else if (!venv_valid_rdata) begin
                                            machine_fault_n = 1'b1;
                                        fault_code_n = 8'd4;
                                        fault_site_n = 16'd60004;
                                            running_n = 1'b0;
                                            state_n = S_DONE;
                                        end else begin
                                        hp_env_n = 1'b1;
                                        hp_cmd_n = HP_SETPROP;
                                        hp_v64_n = 1'b1;
                                        hp_eid_n = venv[9:0];
                                        hp_len_n = {1'b0, venv_len_rdata};
                                        // potential-bugs #55: the a1>=2 slot
                                        // hint used to seed the scan START,
                                        // but the parent env walk runs
                                        // hint..len-1 and never revisits the
                                        // skipped prefix. The compiler inliner
                                        // can rebind a name at a LOWER slot
                                        // than the callee body's hint (place's
                                        // `sz` at slot 0, inlined spawn hint
                                        // slot 1) — the walk then missed the
                                        // key, fell to the parent env / vvars
                                        // and returned undefined with no
                                        // fault (ASTEROID spawnRock fields).
                                        // PYTHON ignores the hint (dict by
                                        // name id). Always scan from 0 —
                                        // envs are <=16 slots, extra beats
                                        // are legal.
                                        hp_slot_n =
                                            (opw[7:0] != OP_LET_VAR &&
                                             opw[31:24] >= 8'd2)
                                            ? 5'(opw[31:24] - 8'd2)
                                            // LET_VAR local a1[7:1] = slot
                                            // hint + 1 (0 = none).
                                            : (opw[7:0] == OP_LET_VAR &&
                                               opw[24] &&
                                               opw[31:25] != 7'd0)
                                            ? 5'(opw[31:25] - 7'd1)
                                            : 5'd0;
                                        hp_key_n = {7'd0, opw[16:8]};
                                        hp_wval_n = `VST_AT(vsp - 12'd1);
                                        hp_hit_n = 1'b0;
                                        hp_phase_n = (opw[7:0] ==
                                            OP_LET_VAR && opw[24])
                                            // local LET: phase 6 = verified
                                            // slot-hint guess, else plain 2.
                                            ? (opw[31:25] != 7'd0
                                               ? 3'd6 : 3'd2)
                                            : (opw[7:0] == OP_LET_VAR)
                                            ? 3'd1
                                            // STORE_VAR a1>=2: verified
                                            // slot-hint first guess (see
                                            // LOAD_VAR phase 5 above).
                                            : (opw[31:24] >= 8'd2)
                                            ? 3'd5 : 3'd0;
                                        hp_ret_n = S_FETCH_WAIT;
                                        state_n = S_HEAP_WAIT;
                                        // Function bindings also land in vvars
                                        // so `requestAnimationFrame(fn)` can
                                        // resolve after the enclosing env is
                                        // recycled (PACMAN start/fn closure).
                                        if (`VST_AT(vsp - 12'd1)[63:48] ==
                                                16'h7ff9 &&
                                            `VST_AT(vsp - 12'd1)[47:44] ==
                                                4'd7) begin
                                            vvars_we = 1'b1;
                                            vvars_waddr = opw[16:8];
                                            vvars_wdata = `VST_AT(vsp - 12'd1);
                                            begin vvar_valid_we = 1'b1;
                                                vvar_valid_waddr =
                                                    opw[16:8];
                                                vvar_valid_wdata = 1'b1; end
                                        end
                                    end
                                            end else begin
                                            if (opw[7:0] == OP_STORE_VAR ||
                                        !vvar_valid_rdata) begin
                                            vvars_we = 1'b1; vvars_waddr = opw[16:8]; vvars_wdata =
                                            `VST_AT(vsp - 12'd1);
                                            begin vvar_valid_we = 1'b1; vvar_valid_waddr = opw[16:8]; vvar_valid_wdata = 1'b1; end
                                        end
                                        vsp_n = vsp - 12'd1;
                                        ip_n = ip + 16'd1;
                                        code_raddr_n =
                                            15'(ops_base + ip + 16'd1);
                                        state_n = S_FETCH_WAIT;
                                end
                            end
                            OP_MAKE_ARR: begin
                                if (opw[23:8] > ARR_CAP) begin
                                    machine_fault_n = 1'b1; fault_code_n = 8'd3; fault_site_n = 16'd3543;
                                    running_n = 1'b0; state_n = S_DONE;
                                end else if (vsp < opw[19:8] ||
                                             (opw[23:8] == 0 &&
                                              vsp >= 12'(STACK_DEPTH))) begin
                                    machine_fault_n = 1'b1; fault_code_n = 8'd1; fault_site_n = 16'd3548;
                                    running_n = 1'b0; state_n = S_DONE;
                                end else begin
                                    vnat_dom_n = 3'd0;
                                    // Latch length: S_V64_ALLOC must not re-read
                                    // opw (GC resume is thousands of
                                    // clocks later; combo >>8 is not [23:8]).
                                    valloc_arr_n_n = opw[15:8];
                                    valloc_kind_n = 2'd1;
                                    hp_phase_n = 3'd0;
                                    // PYTHON scans from 0 so holes before the
                                    // bump cursor are visible without a GC.
                                    valloc_i_n = (opw[23:8] > 16'(ARR_SHORT_CAP))
                                        ? 14'(MAX_ARR_SHORT)
                                        : 14'd0;
                                    valloc_retried_n = 1'b0;
                                    state_n = S_V64_ALLOC;
                                end
                            end
                            OP_MAKE_OBJ: begin
                                if (vsp >= 12'(STACK_DEPTH)) begin
                                    machine_fault_n = 1'b1; fault_code_n = 8'd1; fault_site_n = 16'd3569;
                                    running_n = 1'b0; state_n = S_DONE;
                                end else begin
                                    valloc_kind_n = 2'd0;
                                    valloc_i_n = vobj_next;
                                    valloc_retried_n = 1'b0;
                                    state_n = S_V64_ALLOC;
                                end
                            end
                            OP_CALL: begin
                                logic [7:0] nid, argc;
                                logic [11:0] base;
                                logic [63:0] result;
                                logic bad_fn, found_slot;
                                logic [6:0] free_slot;
                                logic signed [31:0] ms, frames, wanted;
                                nid = opw[15:8];
                                argc = opw[31:24];
                                // CALL_VAL already uses vsp_hs. Native rAF /
                                // fillRect must too or getContext's hs_vsp
                                // leaves the Fn/args off the combo window.
                                base = (vsp_hs > argc) ? (vsp_hs - argc)
                                                       : 12'd0;
                                result = V64_UNDEFINED;
                                bad_fn = 1'b0;
                                found_slot = 1'b0;
                                free_slot = 7'd0;
                                ms = 32'sd0;
                                frames = 32'sd1;
                                wanted = -32'sd1;
                                if (vsp_hs < argc) begin
                                    machine_fault_n = 1'b1;
                                    fault_code_n = 8'd1;
                                    fault_site_n = 16'd3595;
                                    running_n = 1'b0;
                                    state_n = S_DONE;
                                end else begin
                                    // Plain case: unique nid was the same
                                    // Vivado hang as the opcode switch.
                                    case (nid)
                                        8'd0: begin // bounded diagnostic sink
                                            // PYTHON: console.log is a ring —
                                            // overflow must not abort (DONKEY
                                            // Mario.update logs every frame).
                                            if (vconsole_n < 9'd256)
                                                vconsole_n_n = vconsole_n + 9'd1;
                                            vst_wr(base, result);
                                                vsp_n = base + 12'd1;
                                                ip_n = ip + 16'd1;
                                                code_raddr_n = 15'(ops_base + ip + 16'd1);
                                                state_n = S_FETCH_WAIT;
                                        end
                                        8'd1: begin // clear(back buffer, color)
                                            vdraw_color_n = (argc != 0)
                                                ? v64_to_uint32(`VST_AT(base))[7:0]
                                                : 8'd0;
                                            vdraw_i_n = 19'd0;
                                            vnat_base_n = base;
                                            state_n = S_V64_CLEAR;
                                        end
                                        8'd2: begin // fillRect(x,y,w,h[,color])
                                            if (argc < 4) begin
                                                machine_fault_n = 1'b1;
                                                fault_code_n = 8'd5;
                                                fault_site_n = 16'd3625;
                                                running_n = 1'b0;
                                                state_n = S_DONE;
                                            end else begin
                                                vdraw_x_n = v64_to_uint32(`VST_AT(base))[9:0];
                                                vdraw_y_n = v64_to_uint32(`VST_AT(base + 1))[9:0];
                                                vdraw_w_n = v64_to_uint32(`VST_AT(base + 2))[9:0];
                                                vdraw_h_n = v64_to_uint32(`VST_AT(base + 3))[9:0];
                                                vdraw_color_n = (argc > 4)
                                                    ? v64_to_uint32(`VST_AT(base + 4))[7:0]
                                                    : 8'hff;
                                                vdraw_i_n = 19'd0;
                                                vnat_base_n = base;
                                                state_n = S_V64_RECT;
                                            end
                                        end
                                        8'd3: begin
                                            fb_swap_n = 1'b1;
                                            vst_wr(base, result);
                                            vsp_n = base + 12'd1;
                                            ip_n = ip + 16'd1;
                                            code_raddr_n = 15'(ops_base + ip + 16'd1);
                                            state_n = S_FETCH_WAIT;
                                        end
                                        8'd4, 8'd5, 8'd6, 8'd8, 8'd9: begin
                                            // play_bits: left=4 right=8 fire=16 up=1 down=2
                                            result = v64_handle(
                                                V64_KIND_BOOL, 12'd0,
                                                {31'd0,
                                                 (nid == 8'd4) ? joy_in[2] :
                                                 (nid == 8'd5) ? joy_in[3] :
                                                 (nid == 8'd6) ? joy_in[4] :
                                                 (nid == 8'd8) ? joy_in[0] :
                                                 joy_in[1]}
                                            );
                                            vst_wr(base, result);
                                            vsp_n = base + 12'd1;
                                            ip_n = ip + 16'd1;
                                            code_raddr_n = 15'(ops_base + ip + 16'd1);
                                            state_n = S_FETCH_WAIT;
                                        end
                                        8'd7: begin // startLoop
                                            looping_n = 1'b1;
                                            vst_wr(base, result);
                                            vsp_n = base + 12'd1;
                                            ip_n = ip + 16'd1;
                                            code_raddr_n = 15'(ops_base + ip + 16'd1);
                                            state_n = S_FETCH_WAIT;
                                        end
                                        8'd10: begin // Math.floor
                                            result = (argc == 0)
                                                ? V64_CANON_NAN
                                                : v64_floor_number(`VST_AT(base));
                                            vst_wr(base, result);
                                            vsp_n = base + 12'd1;
                                            ip_n = ip + 16'd1;
                                            code_raddr_n = 15'(ops_base + ip + 16'd1);
                                            state_n = S_FETCH_WAIT;
                                        end
                                        8'd11: begin // Math.abs
                                            if (argc == 0) result = V64_CANON_NAN;
                                            else if (`VST_AT(base)[62:52] == 11'h7ff &&
                                                     `VST_AT(base)[51:0] != 0)
                                                result = V64_CANON_NAN;
                                            else
                                                result = {1'b0, `VST_AT(base)[62:0]};
                                            vst_wr(base, result);
                                            vsp_n = base + 12'd1;
                                            ip_n = ip + 16'd1;
                                            code_raddr_n = 15'(ops_base + ip + 16'd1);
                                            state_n = S_FETCH_WAIT;
                                        end
                                        8'd12, 8'd13: begin // Math.min/max
                                            minmax_acc_n = (nid == 8'd12)
                                                ? 64'h7ff0000000000000
                                                : 64'hfff0000000000000;
                                            minmax_is_min_n = (nid == 8'd12);
                                            minmax_k_n = 8'd0;
                                            minmax_n_n = argc;
                                            minmax_base_n = base;
                                            bind_rd_arm_n = 1'b0;
                                            state_n = S_V64_MINMAX;
                                        end
                                        8'd14: begin // deterministic LCG / 2^32
                                            logic [31:0] next_rng;
                                            next_rng = 32'(vrng * 32'd1664525 +
                                                           32'd1013904223);
                                            vrng_n = next_rng;
                                            vst_wr(base, v64_u32_fraction(next_rng));
                                            vsp_n = base + 12'd1;
                                            ip_n = ip + 16'd1;
                                            code_raddr_n = 15'(ops_base + ip + 16'd1);
                                            state_n = S_FETCH_WAIT;
                                        end
                                        8'd15: begin
                                            // PYTHON Math.sqrt — reuse tagged
                                            // S_SQRT (Q16.16) then v64_from_fx.
                                            begin
                                                logic [63:0] arg;
                                                logic signed [31:0] v;
                                                arg = (argc != 0)
                                                    ? `VST_AT(base) : V64_CANON_NAN;
                                                if (!v64_is_number(arg) ||
                                                    (arg[62:52] == 11'h7ff &&
                                                     arg[51:0] != 0)) begin
                                                    vst_wr(base, V64_CANON_NAN);
                                                    vsp_n = base + 12'd1;
                                                    ip_n = ip + 16'd1;
                                                    code_raddr_n =
                                                        15'(ops_base + ip + 16'd1);
                                                    state_n = S_FETCH_WAIT;
                                                end else if (arg[63] &&
                                                           arg[62:0] != 0) begin
                                                    vst_wr(base, V64_CANON_NAN);
                                                    vsp_n = base + 12'd1;
                                                    ip_n = ip + 16'd1;
                                                    code_raddr_n =
                                                        15'(ops_base + ip + 16'd1);
                                                    state_n = S_FETCH_WAIT;
                                                end else begin
                                                    v = v64_to_fx(arg);
                                                    if (v < 0) v = 32'sd0;
                                                    sq_rad_n = {v, 16'd0};
                                                    sq_rem_n = 26'd0;
                                                    sq_root_n = 24'd0;
                                                    sq_i_n = 5'd23;
                                                    v64_sqrt_n = 1'b1;
                                                    vnat_base_n = base;
                                                    state_n = S_SQRT;
                                                end
                                            end
                                        end
                                        8'd27: begin // requestAnimationFrame
                                            bad_fn = argc == 0 ||
                                                `VST_AT(base)[63:48] != 16'h7ff9 ||
                                                `VST_AT(base)[47:44] != 4'd7 ||
                                                `VST_AT(base)[31:0] >= MAX_OBJ ||
                                                !vfn_valid_rdata ||
                                                vfn_gen_rdata !=
                                                    `VST_AT(base)[43:32];
                                            // Exec vfn_valid/gen can lag parent
                                            // GC (dual copy). A tagged Fn handle
                                            // is enough to re-arm rAF (PACMAN
                                            // `requestAnimationFrame(fn)`).
                                            // FORBIDDEN 2026-08-17: skipping
                                            // vfn_valid/gen is the overnight
                                            // cheat. One heap; keep gen match.
                                            if (bad_fn) begin
                                                machine_fault_n = 1'b1;
                                                fault_code_n = 8'd4;
                                                fault_site_n = 16'd3774;
                                                running_n = 1'b0;
                                                state_n = S_DONE;
                                            end else if (vraf_n >= 4'd8) begin
                                                machine_fault_n = 1'b1;
                                                fault_code_n = 8'd3;
                                                fault_site_n = 16'd3779;
                                                running_n = 1'b0;
                                                state_n = S_DONE;
                                            end else begin
                                                vraf_we = 1'b1;
                                                vraf_waddr = vraf_n[2:0];
                                                vraf_wdata = `VST_AT(base);
                                                vraf_n_n = vraf_n + 4'd1;
                                                vst_wr(base, result);
                                                vsp_n = base + 12'd1;
                                                ip_n = ip + 16'd1;
                                                code_raddr_n = 15'(ops_base + ip + 16'd1);
                                                state_n = S_FETCH_WAIT;
                                            end
                                        end
                                        8'd38, 8'd39: begin
                                            // document/window.dispatchEvent
                                            // (Value64 — existed only in
                                            // exec32; DONKEY's synthetic boot
                                            // Enter silently no-opped). The
                                            // event object rides hp_wval to
                                            // the parent S_V64_DISPATCH type
                                            // walk + custom listener scan.
                                            if (argc != 12'd0 &&
                                                `VST_AT(base)[63:48] ==
                                                    16'h7ff9 &&
                                                `VST_AT(base)[47:44] ==
                                                    4'd5 &&
                                                `VST_AT(base)[31:0] <
                                                    MAX_OBJ) begin
                                                hp_wval_n = `VST_AT(base);
                                                vst_wr(base,
                                                    {16'h7ff9, 4'd3, 27'd0,
                                                     1'b1, 16'd0});
                                                vsp_n = base + 12'd1;
                                                ip_n = ip + 16'd1;
                                                code_raddr_n =
                                                    15'(ops_base + ip + 16'd1);
                                                state_n = S_V64_DISPATCH;
                                            end else begin
                                                // no/invalid event: false
                                                vst_wr(base,
                                                    {16'h7ff9, 4'd3, 27'd0,
                                                     1'b0, 16'd0});
                                                vsp_n = base + 12'd1;
                                                ip_n = ip + 16'd1;
                                                code_raddr_n =
                                                    15'(ops_base + ip + 16'd1);
                                                state_n = S_FETCH_WAIT;
                                            end
                                        end
                                        8'd28, 8'd29: begin // timeout / interval
                                            bad_fn = argc == 0 ||
                                                `VST_AT(base)[63:48] != 16'h7ff9 ||
                                                `VST_AT(base)[47:44] != 4'd7 ||
                                                `VST_AT(base)[31:0] >= MAX_OBJ ||
                                                !vfn_valid_rdata ||
                                                vfn_gen_rdata !=
                                                    `VST_AT(base)[43:32];
                                            if (argc > 1)
                                                ms = $signed(v64_to_uint32(`VST_AT(base + 1)));
                                            if (ms > 0)
                                                frames = (ms * 32'sd3 + 32'sd25) /
                                                         32'sd50;
                                            if (frames < 1)
                                                frames = 1;
                                            if (bad_fn) begin
                                                machine_fault_n = 1'b1;
                                                fault_code_n = 8'd4;
                                                fault_site_n = 16'd3811;
                                                running_n = 1'b0;
                                                state_n = S_DONE;
                                            end else if (vtimer_n >= 7'd64) begin
                                                machine_fault_n = 1'b1;
                                                fault_code_n = 8'd3;
                                                fault_site_n = 16'd3816;
                                                running_n = 1'b0;
                                                state_n = S_DONE;
                                            end else if (tmr_i_q < 7'd64) begin
                                                // #66b: the registered raddr
                                                // export + registered rdata
                                                // lag the cursor by TWO
                                                // beats — one-slot-per-clock
                                                // tested slot i against
                                                // valid[i-2], so every scan
                                                // after the first landed on
                                                // the same slot (all of a
                                                // frame's setTimeouts piled
                                                // into ONE slot; INVADERS
                                                // kill timers vanished).
                                                // Hold raddr two beats.
                                                tmr_found_n = tmr_found_q;
                                                tmr_slot_n = tmr_slot_q;
                                                if (tmr_arm_q != 2'd2)
                                                    tmr_arm_n = tmr_arm_q + 2'd1;
                                                else begin
                                                    tmr_arm_n = 2'd0;
                                                    tmr_i_n = tmr_i_q + 7'd1;
                                                    if (!tmr_found_q &&
                                                        !vtimer_valid_rdata)
                                                    begin
                                                        tmr_found_n = 1'b1;
                                                        tmr_slot_n = tmr_i_q;
                                                    end
                                                end
                                                state_n = S_V64_EXEC;
                                                opnd_n = 1'b1;
                                            end else if (!tmr_found_q) begin
                                                tmr_i_n = 7'd0;
                                                tmr_found_n = 1'b0;
                                                machine_fault_n = 1'b1;
                                                fault_code_n = 8'd3;
                                                fault_site_n = 16'd3836;
                                                running_n = 1'b0;
                                                state_n = S_DONE;
                                            end else begin
                                                tmr_i_n = 7'd0;
                                                tmr_found_n = 1'b0;
                                                vtimer_we = 1'b1;
                                                vtimer_waddr = tmr_slot_q[5:0];
                                                vtimer_valid_wdata = 1'b1;
                                                vtimer_due_wdata =
                                                    $signed(vframe_no) + frames;
                                                vtimer_id_wdata = $signed(vtimer_seq);
                                                vtimer_period_wdata =
                                                    (nid == 8'd29) ? 64'(frames) : -64'sd1;
                                                vtimer_fn_wdata = `VST_AT(base);
                                                vtimer_n_n = vtimer_n + 7'd1;
                                                vtimer_seq_n = vtimer_seq + 32'd1;
                                                vst_wr(base, v64_int32_number(vtimer_seq));
                                                vsp_n = base + 12'd1;
                                                ip_n = ip + 16'd1;
                                                code_raddr_n =
                                                    15'(ops_base + ip + 16'd1);
                                                state_n = S_FETCH_WAIT;
                                            end
                                        end
                                        8'd30, 8'd31: begin // clear timer
                                            if (argc != 0)
                                                wanted = $signed(
                                                    v64_to_uint32(`VST_AT(base))
                                                );
                                            if (tmr_i_q < 7'd64) begin
                                                // #66b: same 2-beat rdata lag
                                                // as the setTimeout scan —
                                                // clearTimeout matched (and
                                                // CLEARED) the wrong slot.
                                                if (tmr_arm_q != 2'd2)
                                                    tmr_arm_n = tmr_arm_q + 2'd1;
                                                else begin
                                                    tmr_arm_n = 2'd0;
                                                    tmr_i_n = tmr_i_q + 7'd1;
                                                    if (vtimer_valid_rdata &&
                                                        vtimer_id_rdata == wanted)
                                                    begin
                                                        vtimer_we = 1'b1;
                                                        vtimer_waddr = tmr_i_q[5:0];
                                                        vtimer_valid_wdata = 1'b0;
                                                        vtimer_n_n = vtimer_n - 7'd1;
                                                    end
                                                end
                                                state_n = S_V64_EXEC;
                                                opnd_n = 1'b1;
                                            end else begin
                                                tmr_i_n = 7'd0;
                                                vst_wr(base, result);
                                                vsp_n = base + 12'd1;
                                                ip_n = ip + 16'd1;
                                                code_raddr_n = 15'(ops_base + ip + 16'd1);
                                                state_n = S_FETCH_WAIT;
                                            end
                                        end
                                        8'd16, 8'd17, 8'd18: begin
                                            // getElementById / querySelector /
                                            // createElement → ELEMENT+style
                                            vnat_dom_n = 3'd1;
                                            vnat_base_n = base;
                                            valloc_kind_n = 2'd0;
                                            valloc_i_n = vobj_next;
                                            valloc_retried_n = 1'b0;
                                            state_n = S_V64_ALLOC;
                                        end
                                        8'd19, 8'd20: begin // addEventListener
                                            logic [63:0] ev, fn;
                                            ev = (argc != 0) ? `VST_AT(base) : V64_UNDEFINED;
                                            fn = (argc > 1) ? `VST_AT(base + 1) : V64_UNDEFINED;
                                            if (fn[63:48] != 16'h7ff9 ||
                                                fn[47:44] != 4'd7) begin
                                                machine_fault_n = 1'b1;
                                                fault_code_n = 8'd4;
                                                fault_site_n = 16'd3916;
                                                running_n = 1'b0;
                                                state_n = S_DONE;
                                            end else begin
                                                // parent walks its single table; hold here (lsv)
                                                lsv_scan_n = 1'b1;
                                                lsv_op_n = 2'd1;
                                                lsv_ev_n = ev;
                                                lsv_fn_n = fn;
                                                lsv_base_n = base;
                                                lsv_push_n = result;
                                                state_n = S_V64_EXEC;
                                            end
                                        end
                                        8'd21, 8'd22, 8'd32: begin
                                            // localStorage get/set/remove stub
                                            vst_wr(base, result);
                                            vsp_n = base + 12'd1;
                                            ip_n = ip + 16'd1;
                                            code_raddr_n = 15'(ops_base + ip + 16'd1);
                                            state_n = S_FETCH_WAIT;
                                        end
                                        8'd23: begin
                                            // JSON.parse: null/undefined → null
                                            // (getLeaderboard || []). Interned /
                                            // dynstr → nested Value64 arrays.
                                            if (argc == 0 ||
                                                `VST_AT(base)[63:48] == V64_TAG_PREFIX &&
                                                (`VST_AT(base)[47:44] == V64_KIND_UNDEFINED ||
                                                 `VST_AT(base)[47:44] == V64_KIND_NULL)) begin
                                                vst_wr(base, V64_NULL);
                                                vsp_n = base + 12'd1;
                                                ip_n = ip + 16'd1;
                                                code_raddr_n =
                                                    15'(ops_base + ip + 16'd1);
                                                state_n = S_FETCH_WAIT;
                                            end else if (`VST_AT(base)[63:48] == V64_TAG_PREFIX &&
                                                       `VST_AT(base)[47:44] == V64_KIND_STRING &&
                                                       `VST_AT(base)[15:0] < names_n) begin
                                                json_src_n = 14'd0;
                                                json_srclen_n =
                                                    name_blen_rdata[13:0];
                                                json_rp_n = 14'd0;
                                                js_sp_n = 6'd0;
                                                json_pph_n = 3'd0;
                                                vnat_base_n = base;
                                                if (name_blen_rdata == 16'd0) begin
                                                    vst_wr(base, V64_NULL);
                                                    vsp_n = base + 12'd1;
                                                    ip_n = ip + 16'd1;
                                                    code_raddr_n =
                                                        15'(ops_base + ip + 16'd1);
                                                    state_n = S_FETCH_WAIT;
                                                end else begin
                                                    name_rdaddr_n =
                                                        name_off_rdata;
                                                    json_wp_n = 14'd0;
                                                    namcpy_repl_n = 1'b0;
                                                    namcpy_v64_n = 1'b1;
                                                    namcpy_armed_n = 1'b0;
                                                    state_n = S_NAMCPY;
                                                end
                                            end else if (`VST_AT(base)[63:48] == V64_TAG_PREFIX &&
                                                       `VST_AT(base)[47:44] == V64_KIND_OBJECT &&
                                                       `VST_AT(base)[31:0] < MAX_OBJ &&
                                                       vobj_alloc_rdata == 2'd1 &&
                                                       vobj_builtin_rdata == 4'd7) begin
                                                vnat_base_n = base;
                                                hp_cmd_n = HP_OGETI;
                                                hp_v64_n = 1'b1;
                                                hp_oid_n = `VST_AT(base)[12:0];
                                                hp_slot_n = 5'd0;
                                                hp_qn_n = 3'd2;
                                                hp_qi_n = 3'd0;
                                                hp_nat_n = 4'd0;
                                                hp_vbase_n = base;
                                                hp_ret_n = S_V64_OGETI_NAT;
                                                state_n = S_HEAP_WAIT;
                                            end else begin
                                                vst_wr(base, V64_NULL);
                                                vsp_n = base + 12'd1;
                                                ip_n = ip + 16'd1;
                                                code_raddr_n =
                                                    15'(ops_base + ip + 16'd1);
                                                state_n = S_FETCH_WAIT;
                                            end
                                        end
                                        8'd24: begin
                                            // JSON.stringify → dynstr in json_mem
                                            json_wp_n = 14'd0;
                                            js_sp_n = 6'd1;
                                            vjs_rd_arm_n = 1'b0;
                                            js_we = 1'b1;
                                            js_waddr = 5'd0;
                                            vjs_val_wdata = (argc != 0)
                                                ? `VST_AT(base) : V64_UNDEFINED;
                                            js_i_wdata = 8'd0;
                                            js_ph_wdata = 3'd0;
                                            vnat_base_n = base;
                                            state_n = S_V64_JSON;
                                        end
                                        8'd25: begin // Date() stub object
                                            vnat_dom_n = 3'd6;
                                            vnat_base_n = base;
                                            valloc_kind_n = 2'd0;
                                            valloc_i_n = vobj_next;
                                            valloc_retried_n = 1'b0;
                                            state_n = S_V64_ALLOC;
                                        end
                                        8'd26: begin // Image() stub
                                            vnat_dom_n = 3'd4;
                                            vnat_base_n = base;
                                            valloc_kind_n = 2'd0;
                                            valloc_i_n = vobj_next;
                                            valloc_retried_n = 1'b0;
                                            state_n = S_V64_ALLOC;
                                        end
                                        8'd33: begin // unknown CALL_NATIVE no-op
                                            vst_wr(base, result);
                                            vsp_n = base + 12'd1;
                                            ip_n = ip + 16'd1;
                                            code_raddr_n = 15'(ops_base + ip + 16'd1);
                                            state_n = S_FETCH_WAIT;
                                        end
                                        8'd34: begin // Array(n) — length n, holes
                                            begin
                                                logic [31:0] aln;
                                                aln = 32'd0;
                                                if (argc != 0 &&
                                                    v64_is_number(`VST_AT(base)))
                                                    aln = v64_to_uint32(
                                                        `VST_AT(base));
                                                if (aln > ARR_CAP) begin
                                                    machine_fault_n = 1'b1;
                                                    fault_code_n = 8'd3;
                                                    fault_site_n = 16'd4065;
                                                    running_n = 1'b0;
                                                    state_n = S_DONE;
                                                end else begin
                                                    valloc_arr_n_n = aln[7:0];
                                                    vnat_dom_n = 3'd7;
                                                    vnat_base_n = base;
                                                    valloc_kind_n = 2'd1;
                                                    hp_phase_n = 3'd0;
                                                    valloc_i_n = (aln > ARR_SHORT_CAP)
                                                        ? 14'(MAX_ARR_SHORT)
                                                        : 14'd0;
                                                    valloc_retried_n = 1'b0;
                                                    state_n = S_V64_ALLOC;
                                                end
                                            end
                                        end
                                        8'd35: begin // performance.now
                                            logic [63:0] frame_number;
                                            frame_number = v64_int32_number(vframe_no);
                                            if (nwm_busy) begin
                                                opnd_n = 1'b1; opnd2_n = 1'b1; opnd3_n = 1'b1;
                                                state_n = S_V64_EXEC;
                                            end else begin
                                            result = now_v64_q;
                                            vst_wr(base, result);
                                            vsp_n = base + 12'd1;
                                            ip_n = ip + 16'd1;
                                            code_raddr_n = 15'(ops_base + ip + 16'd1);
                                            state_n = S_FETCH_WAIT;
                                            end
                                        end
                                        8'd36, 8'd37: begin
                                            // removeEventListener: parent compacts its single table
                                            // sequentially (#77's dual-copy sync is GONE — one table).
                                            logic [63:0] ev, fn;
                                            ev = (argc != 0) ? `VST_AT(base) : V64_UNDEFINED;
                                            fn = (argc > 1) ? `VST_AT(base + 1) : V64_UNDEFINED;
                                            lsv_scan_n = 1'b1;
                                            lsv_op_n = 2'd2;
                                            lsv_ev_n = ev;
                                            lsv_fn_n = fn;
                                            lsv_base_n = base;
                                            lsv_push_n = result;
                                            state_n = S_V64_EXEC;
                                        end
                                        8'd40: begin
                                            // PYTHON typeof — interned tag
                                            // (PACMAN Map.get hole checks).
                                            begin
                                                logic [15:0] tn;
                                                logic [63:0] arg;
                                                arg = (argc != 0)
                                                    ? `VST_AT(base) : V64_UNDEFINED;
                                                tn = id_str_object;
                                                if (v64_is_number(arg))
                                                    tn = (id_str_number != 16'hFFFF)
                                                        ? id_str_number
                                                        : id_str_object;
                                                else if (arg[63:48] == V64_TAG_PREFIX &&
                                                         arg[47:44] ==
                                                             V64_KIND_UNDEFINED)
                                                    tn = id_str_undef;
                                                else if (arg[63:48] == V64_TAG_PREFIX &&
                                                         arg[47:44] ==
                                                             V64_KIND_STRING)
                                                    tn = (id_str_string != 16'hFFFF)
                                                        ? id_str_string
                                                        : id_str_object;
                                                else if (arg[63:48] == V64_TAG_PREFIX &&
                                                         arg[47:44] ==
                                                             V64_KIND_FUNCTION)
                                                    tn = (id_str_function != 16'hFFFF)
                                                        ? id_str_function
                                                        : id_str_object;
                                                else if (id_str_object != 16'hFFFF)
                                                    tn = id_str_object;
                                                else
                                                    tn = 16'd0;
                                                vst_wr(base, v64_handle(
                                                    4'd4, 12'd0, {16'd0, tn}));
                                                vsp_n = base + 12'd1;
                                                ip_n = ip + 16'd1;
                                                code_raddr_n =
                                                    15'(ops_base + ip + 16'd1);
                                                state_n = S_FETCH_WAIT;
                                            end
                                        end
                                        8'd42: begin
                                            // sound(ch, freq, vol, frames, slide)
                                            // Always succeed. snd_stb_c registers
                                            // the args and flips snd_tgl for the
                                            // PSG PHY (absent PHY = silent).
                                            // Out-of-range values saturate at the
                                            // field width — a wild slide is a weird
                                            // noise, never a fault.
                                            snd_stb_c = 1'b1;
                                            snd_ch_c = 2'(v64_to_int32(
                                                `VST_AT(base + 1)));
                                            snd_freq_c = 16'(v64_to_int32(
                                                `VST_AT(base + 2)));
                                            snd_vol_c = 4'(v64_to_int32(
                                                `VST_AT(base + 3)));
                                            snd_frames_c = 8'(v64_to_int32(
                                                `VST_AT(base + 4)));
                                            snd_slide_c = 8'(v64_to_int32(
                                                `VST_AT(base + 5)));
                                            vst_wr(base, result);
                                            vsp_n = base + 12'd1;
                                            ip_n = ip + 16'd1;
                                            code_raddr_n = 15'(ops_base + ip + 16'd1);
                                            state_n = S_FETCH_WAIT;
                                        end
                                        default: begin
                                            machine_fault_n = 1'b1;
                                            fault_code_n = 8'd5;
                                            fault_site_n = 16'd4183;
                                            running_n = 1'b0;
                                            state_n = S_DONE;
                                        end
                                    endcase
                                end
                            end
                            OP_MAKE_FN: begin
                                if (vsp >= 12'(STACK_DEPTH)) begin
                                    machine_fault_n = 1'b1; fault_code_n = 8'd1; fault_site_n = 16'd4210;
                                    running_n = 1'b0; state_n = S_DONE;
                                end else begin
                                    // Latch entry/flags: S_V64_ALLOC must not
                                    // re-read opw (same class as
                                    // valloc_arr_n for OP_MAKE_ARR).
                                    valloc_fn_entry_n = opw[23:8];
                                    valloc_fn_a1_n = opw[31:24];
                                    valloc_kind_n = 2'd2;
                                    valloc_i_n = vfn_next;
                                    valloc_retried_n = 1'b0;
                                    state_n = S_V64_ALLOC;
                                end
                            end
                            OP_CALL_USER: begin
                                if (vcsp_hs >= CSTK) begin
                                    machine_fault_n = 1'b1; fault_code_n = 8'd2; fault_site_n = 16'd4226;
                                    running_n = 1'b0; state_n = S_DONE;
                                end else if (vsp_hs < opw[31:24]) begin
                                    machine_fault_n = 1'b1; fault_code_n = 8'd1; fault_site_n = 16'd4229;
                                    running_n = 1'b0; state_n = S_DONE;
                                end else begin
                                    vcall_value_n = 1'b0;
                                    vcall_entry_n = opw[23:8];
                                    vcall_argc_n = opw[31:24];
                                    vcall_set_this_n = 1'b0;
                                    vcall_ctor_val_n = V64_UNDEFINED;
                                    valloc_kind_n = 2'd3;
                                    valloc_i_n = venv_next;
                                    valloc_retried_n = 1'b0;
                                    // Latch return before ip_n=entry. ALLOC
                                    // used ip+1 after that clock (vret=entry+1).
                                    bind_ip_n = ip + 16'd1;
                                    // Clock entry now (same as exec32). Parent
                                    // CTOR_PAD/BIND hs_ip can miss, and ip
                                    // stays at CALL_USER → 128 nested frames.
                                    ip_n = opw[23:8];
                                    code_raddr_n = 15'(ops_base + opw[23:8]);
                                    // Parent ALLOC writes vframe[e64_vcsp-1].
                                    // Exec must own the depth or RET_VAL sees 0.
                                    vcsp_n = vcsp_hs + 8'd1;
                                    state_n = S_V64_ALLOC;
                                end
                            end
                            OP_CALL_VAL: begin
                                logic [15:0] argc;
                                logic [63:0] handle;
                                logic iife_flat;
                                logic [11:0] base_sp;
                                logic [7:0] nparam;
                                argc = opw[23:8];
                                handle = (vsp_hs > argc)
                                    ? `VST_AT(vsp_hs - argc - 12'd1)
                                    : V64_UNDEFINED;
                                iife_flat = (handle[63:48] == 16'h7ff9 &&
                                             handle[47:44] == 4'd7 &&
                                             handle[31:0] < MAX_OBJ &&
                                             vfn_valid_rdata &&
                                             vfn_gen_rdata ==
                                                handle[43:32] &&
                                             vfn_flags_rdata[1] &&
                                             (vfn_env_rdata[63:48] !=
                                                V64_TAG_PREFIX ||
                                              vfn_env_rdata[47:44] !=
                                                V64_KIND_ENV));
                                if (vcsp_hs >= CSTK) begin
                                    machine_fault_n = 1'b1; fault_code_n = 8'd2; fault_site_n = 16'd4276;
                                    running_n = 1'b0; state_n = S_DONE;
                                end else if (vsp_hs < argc + 16'd1) begin
                                    machine_fault_n = 1'b1; fault_code_n = 8'd1; fault_site_n = 16'd4279;
                                    running_n = 1'b0; state_n = S_DONE;
                                // The callee sits argc+1 deep. Computed args
                                // (ADD/MUL, a nested call) can leave that slot
                                // of the 16-deep TOS window stale or zeroed
                                // while the vstack SRAM holds the truth, so an
                                // untagged word here means "window lost it",
                                // not "not a function". Refill from SRAM once
                                // (cm_win survives leave_hold; opnd_q does
                                // not) and retry before faulting — same
                                // WIN_FILL retry fillRect used to do.
                                end else if (handle[63:48] != 16'h7ff9 &&
                                             !cm_win && vsp_hs >= 12'd1) begin
                                    cm_win_n = 1'b1;
                                    vst_refill_i_n = 4'd0;
                                    vst_refill_arm_n = 1'b0;
                                    vst_refill_ret_n = S_V64_EXEC;
                                    vst_hold_win_n = 1'b1;
                                    opnd_n = 1'b1;
                                    opnd2_n = 1'b1;
                                    state_n = S_V64_WIN_FILL;
                                end else if (handle[63:48] != 16'h7ff9 ||
                                             handle[47:44] != 4'd7 ||
                                             handle[31:0] >= MAX_OBJ ||
                                             !vfn_valid_rdata ||
                                             vfn_gen_rdata !=
                                                handle[43:32]) begin
                                    machine_fault_n = 1'b1; fault_code_n = 8'd4;
                                    cm_win_n = 1'b0;
                                    fault_site_n =
                                        (handle[63:48] != 16'h7ff9) ? 16'd60010 :
                                        (handle[47:44] != 4'd7)     ? 16'd60011 :
                                        (handle[31:0] >= MAX_OBJ)   ? 16'd60012 :
                                        (!vfn_valid_rdata)          ? 16'd60013 :
                                                                      16'd60014;
                                    running_n = 1'b0; state_n = S_DONE;
                                end else if (vfn_entry_rdata ==
                                           16'hfffa) begin
                                    // Date.now / performance.now native 35.
                                    logic [63:0] now_result;
                                    logic [11:0] now_base;
                                    now_base = vsp_hs - argc - 12'd1;
                                    if (nwm_busy) begin
                                        opnd_n = 1'b1; opnd2_n = 1'b1; opnd3_n = 1'b1;
                                        state_n = S_V64_EXEC;
                                    end else begin
                                    now_result = now_v64_q;
                                    vst_wr(now_base, now_result);
                                    vsp_n = now_base + 12'd1;
                                    ip_n = ip + 16'd1;
                                    code_raddr_n =
                                        15'(ops_base + ip + 16'd1);
                                    state_n = S_FETCH_WAIT;
                                    end
                                end else if (iife_flat) begin
                                    // JSB MAKE_FN a1 bit6: top-level IIFE is
                                    // a flat call (no ENV). Same ProgramImage
                                    // as PYTHON Value64.
                                    base_sp = vsp_hs - argc - 12'd1;
                                    nparam = {2'd0, vfn_nparam_rdata};
                                    vframe_we = 1'b1;
                                    vframe_waddr = vcsp_hs[6:0];
                                    vframe_rip_wdata = ip + 16'd1;
                                    vframe_bsp_wdata = base_sp;
                                    vframe_esc_wdata = 1'b0;
                                    vframe_this_wdata = vthis;
                                    vframe_env_wdata = venv;
                                    vframe_fn_wdata = handle;
                                    vframe_ctor_wdata = V64_UNDEFINED;
                                    vcsp_n = vcsp_hs + 8'd1;
                                    vthis_n = V64_UNDEFINED;
                                    bind_mode_n = 2'd0;
                                    bind_k_n = 8'd0;
                                    bind_n_n = nparam;
                                    bind_argc_n = argc;
                                    bind_base_n = base_sp;
                                    bind_src_n = vsp - argc;
                                    bind_vsp_next_n = base_sp + nparam;
                                    bind_ip_n = vfn_entry_rdata;
                                    bind_ret_n = S_FETCH_WAIT;
                                    bind_rd_arm_n = 1'b0;
                                    state_n = S_V64_BIND;
                                end else begin
                                    vcall_value_n = 1'b1;
                                    vcall_entry_n = 16'd0;
                                    vcall_argc_n = argc[11:0];
                                    vcall_set_this_n = 1'b0;
                                    vcall_ctor_val_n = V64_UNDEFINED;
                                    valloc_kind_n = 2'd3;
                                    valloc_i_n = venv_next;
                                    valloc_retried_n = 1'b0;
                                    // Same reserve as CALL_USER/NEW_OBJ:
                                    // kind 3 ALLOC writes e64-1. Without +1,
                                    // `constructor(){ this.n=f(); }` overwrote
                                    // the instance frame; f() RET then Game
                                    // RET_VAL saw vcsp=0 (fault 2).
                                    vcsp_n = vcsp_hs + 8'd1;
                                    state_n = S_V64_ALLOC;
                                end
                            end
                            OP_RET_VAL: begin
                                if (vsp_hs == 0) begin
                                    machine_fault_n = 1'b1; fault_code_n = 8'd1; fault_site_n = 16'd4354;
                                    running_n = 1'b0; state_n = S_DONE;
                                end else if (vcsp_hs == 0) begin
                                    machine_fault_n = 1'b1; fault_code_n = 8'd2; fault_site_n = 16'd4357;
                                    running_n = 1'b0; state_n = S_DONE;
                                end else begin
                                    // PYTHON pops result then checks sp==base.
                                    // Keep the top as the return value so one
                                    // extra (ctx.fillText in a method) still
                                    // returns; writeback below uses `VST_AT(vsp-1).
                                    // Leaf CALL_USER (palK/drawPix) must recycle
                                    // the env here — waiting for GC fills
                                    // ENV_DEPTH and burns ~10M clocks/paint.
                                    if (!vframe_esc_rdata &&
                                        venv[63:48] == V64_TAG_PREFIX &&
                                        venv[47:44] == V64_KIND_ENV &&
                                        venv[31:0] < ENV_DEPTH &&
                                        venv_valid_rdata &&
                                        venv_gen_rdata == venv[43:32] &&
                                        venv != vframe_env_rdata) begin
                                        begin venv_valid_we = 1'b1; venv_valid_waddr = venv[9:0]; venv_valid_wdata = 1'b0; end
                                        begin venv_len_we = 1'b1; venv_len_waddr = venv[9:0]; venv_len_wdata = 5'd0; end
                                        venv_gen_we = 1'b1; venv_gen_waddr = venv[9:0]; venv_gen_wdata =
                                            (venv_gen_rdata == 12'hfff)
                                            ? 12'd1
                                            : (venv_gen_rdata + 12'd1);
                                        if (venv_next > venv[9:0])
                                            venv_next_n = venv[9:0];
                                    end
                                    vthis_n = vframe_this_rdata;
                                    venv_n = vframe_env_rdata;
                                    vcsp_n = vcsp_hs - 8'd1;
                                    if (vframe_rip_rdata ==
                                        16'hffff) begin
                                        vsp_n = vframe_bsp_rdata;
                                        state_n = S_V64_FRAME_RAF;
                                    end else if (
                                        vframe_rip_rdata ==
                                        16'hfffe
                                    ) begin
                                        vsp_n = vframe_bsp_rdata;
                                        state_n = S_V64_FRAME_TIMER;
                                    end else if (
                                        vframe_rip_rdata ==
                                        16'hfffd
                                    ) begin
                                        vsp_n = vframe_bsp_rdata;
                                        state_n = S_V64_FRAME_KEY;
                                    end else if (
                                        vframe_rip_rdata ==
                                        16'hfffc
                                    ) begin
                                        // Array.find: truthy callback → that
                                        // element (vfe_i already advanced).
                                        if (vfe_sort) begin
                                            // #41: comparator result -> parent
                                            // S_V64_SORT phase 3 via vfe_map.
                                            vfe_map_n = `VST_AT(vsp - 12'd1);
                                            vsp_n = vframe_bsp_rdata;
                                            hp_phase_n = 3'd3;
                                            state_n = S_V64_SORT;
                                        end else if (vfe_reduce) begin
                                            // #39: callback return = new acc.
                                            vfe_map_n = `VST_AT(vsp - 12'd1);
                                            vsp_n = vframe_bsp_rdata;
                                            state_n = S_V64_FOREACH;
                                        end else if (vfe_mode == 2'd1 &&
                                            v64_truthy(`VST_AT(vsp - 12'd1)))
                                        begin
                                            hp_cmd_n = HP_AGETI;
                                            hp_v64_n = 1'b1;
                                            hp_aid_n = vfe_arr[11:0];
                                            hp_aslot_n = 7'(vfe_i - 8'd1);
                                            hp_alen_n = varr_len_rdata;
                                            hp_ret_n = S_V64_FE_ELEM;
                                            state_n = S_HEAP_WAIT;
                                    end else begin
                                            // map stores callback result;
                                            // filter keeps the source element.
                                            vsp_n =
                                                vframe_bsp_rdata;
                                            if (vfe_mode == 2'd2 &&
                                                vfe_map[63:48] == V64_TAG_PREFIX &&
                                                vfe_map[47:44] == V64_KIND_ARRAY &&
                                                varr_valid_rdata &&
                                                (vfe_i - 8'd1) <
                                                    varr_len_rdata)
                                            begin
                                                hp_cmd_n = HP_ASETI;
                                                hp_v64_n = 1'b1;
                                                hp_from_stack_n = 1'b0;
                                                hp_aid_n = vfe_map[11:0];
                                                hp_aslot_n = 7'(vfe_i - 8'd1);
                                                hp_wval_n = `VST_AT(vsp - 12'd1);
                                                hp_ret_n = S_V64_FOREACH;
                                                state_n = S_HEAP_AWR;
                                            end else if (vfe_mode == 2'd3 &&
                                                     v64_truthy(
                                                         `VST_AT(vsp - 12'd1)) &&
                                                     vfe_map[63:48] ==
                                                         V64_TAG_PREFIX &&
                                                     vfe_map[47:44] ==
                                                         V64_KIND_ARRAY &&
                                                     varr_valid_rdata)
                                            begin
                                                hp_cmd_n = HP_AGETI;
                                                hp_v64_n = 1'b1;
                                                hp_aid_n = vfe_arr[11:0];
                                                hp_aslot_n = 7'(vfe_i - 8'd1);
                                                hp_alen_n = varr_len_rdata;
                                                hp_ret_n = S_V64_FE_FILTER;
                                                state_n = S_HEAP_WAIT;
                                            end else
                                                state_n = S_V64_FOREACH;
                                        end
                                    end else begin
                                        // PYTHON RET_VAL: constructor frames
                                        // yield the instance, not undefined.
                                        // Always plant win[0]: bsp==0 skipped
                                        // win0_we, so `new M(); this.x=200`
                                        // left SET_PROP 200 in the TOS window
                                        // (leave_hold EXEC does not shift).
                                        begin
                                            logic [63:0] ret_v;
                                            // ctor_cur is ALLOC p_frame_we (instance)
                                            // for this frame (ctor_csp). SRAM rdata can
                                            // still be UNDEF at this combo. Do not use
                                            // ctor_cur on nested CALL_USER RET.
                                            ret_v = (ctor_csp != 8'd0 &&
                                                 vcsp_hs == ctor_csp &&
                                                 ctor_cur[63:48] ==
                                                 V64_TAG_PREFIX &&
                                                 ctor_cur[47:44] ==
                                                 V64_KIND_OBJECT)
                                                ? ctor_cur
                                                : (vframe_ctor_rdata[63:48] ==
                                                 V64_TAG_PREFIX &&
                                                 vframe_ctor_rdata[47:44] ==
                                                 V64_KIND_OBJECT)
                                                ? vframe_ctor_rdata
                                                : `VST_AT(vsp - 12'd1);
                                            vst_wr(vframe_bsp_rdata, ret_v);
                                            vst_win0_we = 1'b1;
                                            vst_win0_wdata = ret_v;
                                            if (vcsp_hs == ctor_csp) begin
                                                ctor_cur_n = V64_UNDEFINED;
                                                ctor_csp_n = 8'd0;
                                            end
                                        end
                                        vsp_n =
                                            vframe_bsp_rdata + 12'd1;
                                        ip_n = vframe_rip_rdata;
                                        code_raddr_n = 15'(
                                            ops_base +
                                            vframe_rip_rdata
                                        );
                                        // Same TOS-window hole as MAKE_ARRAY:
                                        // SET_PROP/ARRAY_SET peek win[1]. A
                                        // callee that grew then shrank
                                        // (MAKE_ARRAY 28, nested forEach)
                                        // can RET with old vsp < base+17
                                        // while win[1] is leftover (the
                                        // receiver under item.path=finder()).
                                        // PYTHON's stack is deep; refill
                                        // whenever a slot sits under the
                                        // return value (base >= 1).
                                        if (vframe_bsp_rdata
                                                >= 12'd1) begin
                                            vst_refill_i_n = 4'd1;
                                            vst_refill_arm_n = 1'b0;
                                            vst_refill_ret_n = S_FETCH_WAIT;
                                            vst_hold_win_n = 1'b1;
                                            state_n = S_V64_WIN_FILL;
                                        end else
                                        state_n = S_FETCH_WAIT;
                                    end
                                end
                            end
                            OP_ARR_GET: begin
                                if (vsp < 12'd2) begin
                                    machine_fault_n = 1'b1; fault_code_n = 8'd1; fault_site_n = 16'd4522;
                                    running_n = 1'b0; state_n = S_DONE;
                                end else begin
                                    logic [63:0] handle;
                                    logic index_valid;
                                    logic signed [32:0] array_index;
                                    handle = `VST_AT(vsp - 12'd2);
                                    v64_array_index_task(
                                        `VST_AT(vsp - 12'd1),
                                        index_valid, array_index
                                    );
                                    if (handle[63:48] == 16'h7ff9 &&
                                        handle[47:44] == 4'd4 &&
                                        handle[31:0] < 32'd1024) begin
                                        // PYTHON: interned "str"[i] is one char.
                                        // name_mem is BRAM — result in S_V64_STRIDX.
                                        // Non-Number index → undefined (not 255).
                                        if (!index_valid) begin
                                            vst_wr(vsp - 12'd2, V64_UNDEFINED);
                                            vsp_n = vsp - 12'd1;
                                            ip_n = ip + 16'd1;
                                            code_raddr_n =
                                                15'(ops_base + ip + 16'd1);
                                            state_n = S_FETCH_WAIT;
                                        end else if (!hash2_q) begin
                                            // name_blen/name_off Port A lag.
                                            // Same-cycle bounds used stale 0
                                            // → every interned row[col] was
                                            // undefined (INVADERS bitmaps).
                                            hash2_n = 1'b1;
                                            opnd_n = 1'b1;
                                            opnd2_n = 1'b1;
                                            state_n = S_V64_EXEC;
                                        end else if (array_index < 0 ||
                                            array_index >=
                                                {17'd0, name_blen_rdata}) begin
                                            vst_wr(vsp - 12'd2, V64_UNDEFINED);
                                            vsp_n = vsp - 12'd1;
                                            ip_n = ip + 16'd1;
                                            code_raddr_n =
                                                15'(ops_base + ip + 16'd1);
                                            state_n = S_FETCH_WAIT;
                                        end else begin
                                            name_rdaddr_n =
                                                name_off_rdata +
                                                16'(array_index);
                                            vsp_n = vsp - 12'd1;
                                            ip_n = ip + 16'd1;
                                            state_n = S_V64_STRIDX;
                                        end
                                    end else if (handle[63:48] == 16'h7ff9 &&
                                        (handle[47:44] == V64_KIND_OBJECT ||
                                         handle[47:44] == V64_KIND_ELEMENT) &&
                                        handle[31:0] < MAX_OBJ)
                                    begin
                                        // PYTHON: obj[computed] uses interned
                                        // keys (`_events[eventType]`). Parent
                                        // HEAP keeps gen — exec copies lag.
                                        begin
                                            logic [15:0] okey;
                                            logic ofound;
                                            logic [63:0] oresult;
                                            okey = 16'hFFFF;
                                            ofound = 1'b0;
                                            oresult = V64_UNDEFINED;
                                            if (`VST_AT(vsp - 12'd1)[63:48] ==
                                                    V64_TAG_PREFIX &&
                                                `VST_AT(vsp - 12'd1)[47:44] ==
                                                    4'd4 &&
                                                `VST_AT(vsp - 12'd1)[31:0] <
                                                    32'd1024)
                                                okey = `VST_AT(vsp - 12'd1)[15:0];
                                            if (okey == 16'hFFFF) begin
                                                vst_wr(vsp - 12'd2, V64_UNDEFINED);
                                                vsp_n = vsp - 12'd1;
                                                ip_n = ip + 16'd1;
                                                code_raddr_n =
                                                    15'(ops_base + ip + 16'd1);
                                                state_n = S_FETCH_WAIT;
                                            end else begin
                                                hp_cmd_n = HP_GETIDX;
                                                hp_v64_n = 1'b1;
                                                hp_oid_n = handle[12:0];
                                                hp_key_n = okey;
                                                hp_len_n = vobj_len_rdata;
                                                hp_slot_n = 5'd0;
                                                hp_phase_n = 3'd1;
                                                hp_proto_n = V64_UNDEFINED;
                                                state_n = S_HEAP_WAIT;
                                            end
                                        end
                                    end else if (handle[63:48] != 16'h7ff9 ||
                                        handle[47:44] != 4'd6 ||
                                        handle[31:0] >= MAX_ARR ||
                                        !varr_valid_rdata) begin
                                        // JS: Number[index] is undefined, not a type fault.
                                        // Do not gate on exec varr_gen: poke 45
                                        // never stamps gen after GC reuse, so
                                        // [i] returned undefined (DONKEY
                                        // standRight[0] → sprite 0,0 faces left).
                                        vst_wr(vsp - 12'd2, V64_UNDEFINED);
                                        vsp_n = vsp - 12'd1;
                                        ip_n = ip + 16'd1;
                                        code_raddr_n = 15'(ops_base + ip + 16'd1);
                                        state_n = S_FETCH_WAIT;
                                    end else if (!hash2_q) begin
                                        hash2_n = 1'b1;
                                        opnd_n = 1'b1;
                                        opnd2_n = 1'b1;
                                        state_n = S_V64_EXEC;
                                    end else if (!index_valid ||
                                                 array_index < 0 ||
                                                 array_index >=
                                                    {25'd0, varr_len_rdata})
                                    begin
                                        // PYTHON/JS: arr[undefined] / arr[-1]
                                        // is undefined. Do not slice [6:0]
                                        // (that turned -1 into slot 127).
                                        vst_wr(vsp - 12'd2, V64_UNDEFINED);
                                        vsp_n = vsp - 12'd1;
                                        ip_n = ip + 16'd1;
                                        code_raddr_n = 15'(ops_base + ip + 16'd1);
                                        state_n = S_FETCH_WAIT;
                                    end else begin
                                        hp_cmd_n = HP_ARRGET;
                                        hp_v64_n = 1'b1;
                                        hp_env_n = 1'b0;
                                        hp_aid_n = handle[11:0];
                                        hp_aslot_n = array_index[6:0];
                                        hp_alen_n = varr_len_rdata;
                                        state_n = S_HEAP_WAIT;
                                    end
                                end
                            end
                            OP_ARR_SET: begin
                                if (vsp < 12'd3) begin
                                    machine_fault_n = 1'b1; fault_code_n = 8'd1; fault_site_n = 16'd4658;
                                    running_n = 1'b0; state_n = S_DONE;
                                end else begin
                                    logic [63:0] handle;
                                    logic index_valid;
                                    logic signed [32:0] array_index;
                                    handle = `VST_AT(vsp - 12'd3);
                                    v64_array_index_task(
                                        `VST_AT(vsp - 12'd2),
                                        index_valid, array_index
                                    );
                                    if (handle[63:48] == 16'h7ff9 &&
                                        (handle[47:44] == V64_KIND_OBJECT ||
                                         handle[47:44] == V64_KIND_ELEMENT) &&
                                        handle[31:0] < MAX_OBJ)
                                    begin
                                        // PYTHON: obj[computed]=value interned
                                        // keys (`_events[eventType] = {}`).
                                        // Parent HEAP keeps gen.
                                        begin
                                            logic [15:0] okey;
                                            logic ofound;
                                            okey = 16'hFFFF;
                                            ofound = 1'b0;
                                            if (`VST_AT(vsp - 12'd2)[63:48] ==
                                                    V64_TAG_PREFIX &&
                                                `VST_AT(vsp - 12'd2)[47:44] ==
                                                    4'd4 &&
                                                `VST_AT(vsp - 12'd2)[31:0] <
                                                    32'd1024)
                                                okey = `VST_AT(vsp - 12'd2)[15:0];
                                            if (okey == 16'hFFFF) begin
                                                vst_wr(vsp - 12'd3, `VST_AT(vsp - 12'd1));
                                                vsp_n = vsp - 12'd2;
                                                ip_n = ip + 16'd1;
                                                code_raddr_n =
                                                    15'(ops_base + ip + 16'd1);
                                                state_n = S_FETCH_WAIT;
                                            end else begin
                                                hp_cmd_n = HP_SETIDX;
                                                hp_v64_n = 1'b1;
                                                hp_oid_n = handle[12:0];
                                                hp_key_n = okey;
                                                hp_wval_n = `VST_AT(vsp - 12'd1);
                                                hp_len_n = vobj_len_rdata;
                                                hp_slot_n = 5'd0;
                                                hp_phase_n = 3'd0;
                                                state_n = S_HEAP_WAIT;
                                            end
                                        end
                                    end else if (handle[63:48] != 16'h7ff9 ||
                                        handle[47:44] != 4'd6 ||
                                        handle[31:0] >= MAX_ARR ||
                                        !varr_valid_rdata) begin
                                        // PYTHON: primitive[index]= is a no-op.
                                        // Exec varr_gen lags GC reuse (same as GET).
                                        vst_wr(vsp - 12'd3, `VST_AT(vsp - 12'd1));
                                        vsp_n = vsp - 12'd2;
                                        ip_n = ip + 16'd1;
                                        code_raddr_n =
                                            15'(ops_base + ip + 16'd1);
                                        state_n = S_FETCH_WAIT;
                                    end else if (!index_valid) begin
                                        // 0xF1 = non-Number index (undefined/NaN/object).
                                        // First miss: reload TOS window from BRAM
                                        // (PACMAN splash+Enter: getImageData then
                                        // finder ARRAY_SET saw leftover win[1]).
                                        // Second miss: real non-Number — still fault.
                                        if (!aset_win_retried) begin
                                            aset_win_retried_n = 1'b1;
                                            vst_refill_i_n = 4'd0;
                                            vst_refill_arm_n = 1'b0;
                                            vst_refill_ret_n = S_FETCH_WAIT;
                                            vst_hold_win_n = 1'b1;
                                            state_n = S_V64_WIN_FILL;
                                        end else begin
                                        machine_fault_n = 1'b1; fault_code_n = 8'hF1;
                                        running_n = 1'b0; state_n = S_DONE;
                                        end
                                    end else if (array_index < 0) begin
                                        machine_fault_n = 1'b1; fault_code_n = 8'hF2;
                                        running_n = 1'b0; state_n = S_DONE;
                                    end else if (array_index >= ARR_CAP) begin
                                        machine_fault_n = 1'b1; fault_code_n = 8'hF3;
                                        running_n = 1'b0; state_n = S_DONE;
                                    end else if (!varr_long_rdata &&
                                                 array_index >= ARR_SHORT_CAP &&
                                                 !vprom_done && !p_vprom_done) begin
                                        hp_aid_n = handle[11:0];
                                        valloc_i_n = 14'd0;
                                        vprom_copy_n = 1'b0;
                                        vprom_ret_n = S_V64_EXEC;
                                        state_n = S_ARR_PROMOTE;
                                    end else begin
                                        aset_win_retried_n = 1'b0;
                                        vprom_done_n = 1'b0;
                                        hp_cmd_n = HP_ARRSET;
                                        hp_v64_n = 1'b1;
                                        hp_env_n = 1'b0;
                                        hp_from_stack_n = 1'b0;
                                        hp_aid_n = handle[11:0];
                                        hp_rval_n = `VST_AT(vsp - 12'd1);
                                        hp_wval_n = `VST_AT(vsp - 12'd1);
                                        if (array_index > varr_len_rdata)
                                        begin
                                            hp_aslot_n = varr_len_rdata[6:0];
                                            hp_lim_n = array_index[7:0];
                                            hp_wval_n = V64_UNDEFINED;
                                            varr_len_we = 1'b1; varr_len_waddr = handle[11:0]; varr_len_wdata =
                                                array_index[7:0] + 8'd1;
                                            state_n = S_HEAP_FILL;
                                        end else begin
                                            if (array_index >=
                                                    varr_len_rdata)
                                                varr_len_we = 1'b1; varr_len_waddr = handle[11:0]; varr_len_wdata =
                                                    array_index[7:0] + 8'd1;
                                            hp_aslot_n = array_index[6:0];
                                            state_n = S_HEAP_AWR;
                                        end
                                    end
                                end
                            end
                            OP_GET_PROP: begin
                                if (vsp == 0) begin
                                    machine_fault_n = 1'b1; fault_code_n = 8'd1; fault_site_n = 16'd4782;
                                    running_n = 1'b0; state_n = S_DONE;
                                end else begin
                                    logic [63:0] handle, result;
                                    logic found;
                                    handle = `VST_AT(vsp - 12'd1);
                                    found = 1'b0;
                                    result = V64_UNDEFINED;
                                    if (handle[63:48] == 16'h7ff9 &&
                                        handle[47:44] == 4'd6 &&
                                        handle[31:0] < MAX_ARR &&
                                        varr_valid_rdata) begin
                                        // Exec varr_gen lags GC reuse. Gating
                                        // .length on it made xs.length / cells.length
                                        // undefined (INVADERS resetBunkers).
                                        if (!hash2_q) begin
                                            hash2_n = 1'b1;
                                            opnd_n = 1'b1;
                                            opnd2_n = 1'b1;
                                            state_n = S_V64_EXEC;
                                        end else begin
                                        if (opw[23:8] == id_length)
                                            result = v64_int32_number(
                                                {24'd0, varr_len_rdata}
                                            );
                                        vst_wr(vsp - 12'd1, result);
                                        vst_win0_we = 1'b1;
                                        vst_win0_wdata = result;
                                        ip_n = ip + 16'd1;
                                        code_raddr_n =
                                            15'(ops_base + ip + 16'd1);
                                        state_n = S_FETCH_WAIT;
                                        end
                                    end else if (handle[63:48] == 16'h7ff9 &&
                                                 handle[47:44] == 4'd4 &&
                                                 handle[31:0] < 32'd1024) begin
                                        // potential-bugs #14: a bare `.now`
                                        // property READ used to S_V64_ALLOC a
                                        // native-35 function object. Removed:
                                        // `Date.now()` / `performance.now()`
                                        // compile to LOAD_VAR + CALL_METHOD
                                        // (compiler `_call` bare-ID dotted
                                        // path), and that arm already returns
                                        // the vframe_no timestamp in place
                                        // with no ALLOC (~6357). The only
                                        // property read in any title is
                                        // PACMAN.HTML:25 `if (!Date.now)`,
                                        // which PYTHON also answers undefined
                                        // (js_vm.py handles `now` only on the
                                        // method path). Its polyfill body is
                                        // then executed but inert: `Date.now =`
                                        // and `window.* =` are SET_PROP on a
                                        // primitive, a sloppy-mode no-op here,
                                        // and every call site is a bare
                                        // requestAnimationFrame() -> nid 27.
                                        // Falls through to the shared string
                                        // GET_PROP path, which returns
                                        // V64_UNDEFINED for anything but
                                        // `.length`.
                                        if (!hash2_q) begin
                                            // name_blen_rdata lags raddr_q.
                                            // Extra clock OK. Hold opnd so
                                            // the 2-beat SRAM settle does
                                            // not restart.
                                            hash2_n = 1'b1;
                                            opnd_n = 1'b1;
                                            opnd2_n = 1'b1;
                                            state_n = S_V64_EXEC;
                                        end else begin
                                            if (opw[23:8] == id_length)
                                                result = v64_int32_number(
                                                    {16'd0, name_blen_rdata}
                                                );
                                            vst_wr(vsp - 12'd1, result);
                                            // Same TOS plant as array .length.
                                            // hold_win would skip the next
                                            // LOAD_CONST shift (CALL_METH lost
                                            // the canvas; splash sprites gone).
                                            vst_win0_we = 1'b1;
                                            vst_win0_wdata = result;
                                            ip_n = ip + 16'd1;
                                            code_raddr_n =
                                                15'(ops_base + ip + 16'd1);
                                            state_n = S_FETCH_WAIT;
                                        end
                                    end else if (handle[63:48] == 16'h7ff9 &&
                                                 handle[47:44] == 4'd7 &&
                                                 handle[31:0] < MAX_OBJ &&
                                                 vfn_valid_rdata &&
                                                 vfn_gen_rdata ==
                                                     handle[43:32]) begin
                                        // PYTHON: every function has .prototype
                                        // (Stage.prototype.createItem).
                                        if (opw[23:8] == id_proto) begin
                                            if (!hash2_q) begin
                                                hash2_n = 1'b1;
                                                opnd_n = 1'b1;
                                                state_n = S_V64_EXEC;
                                            end else if (vfn_proto_rdata[63:48] ==
                                                    V64_TAG_PREFIX &&
                                                vfn_proto_rdata[47:44] ==
                                                    V64_KIND_OBJECT &&
                                                vfn_proto_rdata[31:0] <
                                                    MAX_OBJ &&
                                                vobj_alloc_rdata
                                                    == 2'd1 &&
                                                vobj_gen_rdata
                                                    == vfn_proto_rdata[43:32])
                                            begin
                                                vst_wr(vsp - 12'd1, vfn_proto_rdata);
                                                ip_n = ip + 16'd1;
                                                code_raddr_n =
                                                    15'(ops_base + ip + 16'd1);
                                                state_n = S_FETCH_WAIT;
                                            end else begin
                                                valloc_proto_n = 1'b1;
                                                valloc_proto_fn_n = handle[12:0];
                                                vnat_base_n = vsp - 12'd1;
                                                valloc_kind_n = 2'd0;
                                                valloc_i_n = vobj_next;
                                                valloc_retried_n = 1'b0;
                                                state_n = S_V64_ALLOC;
                                            end
                                        end else begin
                                            vst_wr(vsp - 12'd1, V64_UNDEFINED);
                                            ip_n = ip + 16'd1;
                                            code_raddr_n =
                                                15'(ops_base + ip + 16'd1);
                                            state_n = S_FETCH_WAIT;
                                        end
                                    end else if (!(handle[63:48] == 16'h7ff9 &&
                                        (((handle[47:44] == 4'd5 ||
                                           handle[47:44] == V64_KIND_ELEMENT) &&
                                          handle[31:0] < MAX_OBJ) ||
                                         (handle[47:44] == 4'd6 &&
                                          handle[31:0] < MAX_ARR)))) begin
                                        // Primitive GET_PROP: canvas width/height
                                        // defaults. Not a live object/array.
                                        if (opw[23:8] == id_width)
                                            result = v64_int32_number(32'd640);
                                        else if (opw[23:8] == id_height)
                                            result = v64_int32_number(32'd480);
                                        else if (id_disp != 16'hFFFF &&
                                                 opw[23:8] == id_disp)
                                            // `if (document.dispatchEvent)`:
                                            // document is a seeded primitive
                                            // on v64 (no DOM object); the
                                            // native exists, so the guard
                                            // must read truthy.
                                            result = {16'h7ff9, 4'd3, 27'd0,
                                                      1'b1, 16'd0};
                                        vst_wr(vsp - 12'd1, result);
                                        ip_n = ip + 16'd1;
                                        code_raddr_n =
                                            15'(ops_base + ip + 16'd1);
                                        state_n = S_FETCH_WAIT;
                                    end else if (handle[47:44] ==
                                                     V64_KIND_ELEMENT &&
                                                 id_disp != 16'hFFFF &&
                                                 opw[23:8] ==
                                                     id_disp) begin
                                        // `if (document.dispatchEvent)`
                                        // guard: elements answer truthy
                                        // (the walk would find nothing —
                                        // dispatchEvent is a native, not a
                                        // stored property — so the guard
                                        // read undefined and DONKEY's
                                        // synthetic boot Enter never even
                                        // called the native).
                                        vst_wr(vsp - 12'd1,
                                            {16'h7ff9, 4'd3, 27'd0, 1'b1,
                                             16'd0});
                                        ip_n = ip + 16'd1;
                                        code_raddr_n =
                                            15'(ops_base + ip + 16'd1);
                                        state_n = S_FETCH_WAIT;
                                    end else if ((handle[47:44] == 4'd5 ||
                                                  handle[47:44] == V64_KIND_ELEMENT) &&
                                        handle[31:0] < MAX_OBJ) begin
                                        // Object/ELEMENT handle: parent HEAP
                                        // checks alloc+gen (one physical
                                        // heap). Exec copies can lag GC/poke.
                                        hp_cmd_n = HP_GETPROP;
                                        hp_v64_n = 1'b1;
                                        hp_env_n = 1'b0;
                                        hp_oid_n = handle[12:0];
                                        hp_key_n = opw[23:8];
                                        hp_len_n = vobj_len_rdata;
                                        hp_slot_n = 5'd0;
                                        hp_phase_n = 3'd0;
                                        hp_proto_n = vobj_proto_rdata;
                                        // Latch handle gen — do not re-read TOS
                                        // in S_HEAP_CMP (window can be a
                                        // different word → false stale).
                                        hp_spr_w_n = {4'd0, handle[43:32]};
                                        state_n = S_HEAP_WAIT;
                                    end else begin
                                        vst_wr(vsp - 12'd1, V64_UNDEFINED);
                                        ip_n = ip + 16'd1;
                                        code_raddr_n =
                                            15'(ops_base + ip + 16'd1);
                                        state_n = S_FETCH_WAIT;
                                    end
                                end
                            end
                            OP_SET_PROP: begin
                                if (vsp < 12'd2) begin
                                    machine_fault_n = 1'b1; fault_code_n = 8'd1; fault_site_n = 16'd4946;
                                    running_n = 1'b0; state_n = S_DONE;
                                end else begin
                                    logic [63:0] handle;
                                    logic found;
                                    handle = `VST_AT(vsp - 12'd2);
                                    found = 1'b0;
                                    if (handle[63:48] == 16'h7ff9 &&
                                        handle[47:44] == 4'd6 &&
                                        handle[31:0] < MAX_ARR &&
                                        varr_valid_rdata &&
                                        opw[23:8] == id_length) begin
                                        // Exec varr_gen lags GC reuse (bunkers.length=0).
                                        logic [31:0] new_len;
                                        new_len = v64_to_uint32(`VST_AT(vsp - 12'd1));
                                        if (new_len > ARR_CAP) begin
                                            machine_fault_n = 1'b1;
                                            fault_code_n = 8'd3;
                                            fault_site_n = 16'd4945;
                                            running_n = 1'b0;
                                            state_n = S_DONE;
                                        end else begin
                                            begin varr_len_we = 1'b1; varr_len_waddr = handle[11:0]; varr_len_wdata = new_len[7:0]; end
                                            vst_wr(vsp - 12'd2, `VST_AT(vsp - 12'd1));
                                            vsp_n = vsp - 12'd1;
                                            ip_n = ip + 16'd1;
                                            code_raddr_n =
                                                15'(ops_base + ip + 16'd1);
                                            if (new_len > varr_len_rdata)
                                            begin
                                                hp_cmd_n = HP_AFILL;
                                                hp_v64_n = 1'b1;
                                                hp_from_stack_n = 1'b0;
                                                hp_aid_n = handle[11:0];
                                                hp_aslot_n =
                                                    varr_len_rdata[6:0];
                                                hp_lim_n = new_len[7:0];
                                                hp_wval_n = V64_UNDEFINED;
                                                hp_ret_n = S_FETCH_WAIT;
                                                state_n = S_HEAP_FILL;
                                            end else
                                                state_n = S_FETCH_WAIT;
                                        end
                                    end else if (handle[63:48] != 16'h7ff9 ||
                                        (handle[47:44] != 4'd5 &&
                                         handle[47:44] != V64_KIND_ELEMENT) ||
                                        handle[31:0] >= MAX_OBJ)
                                    begin
                                        // PYTHON: SET_PROP on a primitive is a
                                        // sloppy-mode no-op. Live object and
                                        // ELEMENT handles go to parent HEAP.
                                        vst_wr(vsp - 12'd2, `VST_AT(vsp - 12'd1));
                                        vsp_n = vsp - 12'd1;
                                        ip_n = ip + 16'd1;
                                        code_raddr_n =
                                            15'(ops_base + ip + 16'd1);
                                        state_n = S_FETCH_WAIT;
                                    end else begin
                                        if (opw[23:8] == id_fillstyle ||
                                            opw[23:8] == id_strokestyle) begin
                                            // PYTHON: fillStyle and strokeStyle
                                            // are independent. Sharing one latch
                                            // made fillRect black poison stroke
                                            // (ASTEROID rocks invisible).
                                            logic [63:0] style_val;
                                            logic [7:0] parsed;
                                            style_val = `VST_AT(vsp - 12'd1);
                                            if (v64_is_number(style_val))
                                                parsed =
                                                    v64_to_uint32(style_val)[7:0];
                                            else if (style_val[63:48] == 16'h7ff9 &&
                                                     style_val[47:44] == 4'd4 &&
                                                     style_val[15:0] < 16'd1024 &&
                                                     fill_lut_rdata != 8'hFF)
                                                parsed =
                                                    fill_lut_rdata;
                                            else if (style_val[15:0] == id_black ||
                                                     style_val[15:0] == id_hex_000)
                                                parsed = 8'd0;
                                            else if (style_val[15:0] == id_white ||
                                                     style_val[15:0] == id_hex_fff)
                                                parsed = 8'd1;
                                            else
                                                parsed = 8'd1;
                                            if (opw[23:8] == id_strokestyle)
                                                stroke_style_i_n = parsed;
                                            else
                                                fill_style_i_n = parsed;
                                        end
                                        if (opw[23:8] == id_textalign) begin
                                            // PYTHON ctx.textAlign — fillText
                                            // shifts the pen (center / right).
                                            ctx_align_n =
                                                (`VST_AT(vsp - 12'd1)[15:0] ==
                                                 id_center) ? 2'd1
                                                : (`VST_AT(vsp - 12'd1)[15:0] ==
                                                   id_right) ? 2'd2
                                                : 2'd0;
                                        end
                                        if (id_textbaseline != 16'hFFFF &&
                                            opw[23:8] ==
                                                id_textbaseline) begin
                                            // #37 ctx.textBaseline. Unknown
                                            // strings are IGNORED (browser
                                            // behavior): PACMAN writes
                                            // 'center' (invalid) after 'top'
                                            // and 'bottom' and relies on the
                                            // earlier value sticking.
                                            ctx_baseline_n =
                                                (`VST_AT(vsp - 12'd1)[15:0] ==
                                                 id_top) ? 2'd1
                                                : (`VST_AT(vsp - 12'd1)[15:0] ==
                                                   id_middle) ? 2'd2
                                                : (`VST_AT(vsp - 12'd1)[15:0] ==
                                                   id_bottom) ? 2'd3
                                                : ctx_baseline;
                                        end
                                        if (opw[23:8] == id_imgsmooth) begin
                                            // PYTHON ctx.imageSmoothingEnabled
                                            // Indexed blit is nearest either way.
                                            begin
                                                logic [63:0] sm;
                                                sm = `VST_AT(vsp - 12'd1);
                                                if (sm[63:48] == 16'h7ff9 &&
                                                    sm[47:44] == 4'd3)
                                                    ctx_smooth_n = sm[0];
                                                else if (v64_is_number(sm))
                                                    ctx_smooth_n =
                                                        (v64_to_uint32(sm) != 32'd0);
                                                else
                                                    ctx_smooth_n = 1'b1;
                                            end
                                        end
                                        if (id_font != 16'hFFFF &&
                                            opw[23:8] == id_font &&
                                            `VST_AT(vsp - 12'd1)[63:48] ==
                                                16'h7ff9 &&
                                            `VST_AT(vsp - 12'd1)[47:44] ==
                                                4'd4 &&
                                            `VST_AT(vsp - 12'd1)[15:0] <
                                                16'd1024) begin
                                            // ctx.font = "NNpx ..." — parse
                                            // the px size in the parent
                                            // S_FONTPX walk (dead since the
                                            // tagged entry was removed; every
                                            // v64 fillText drew at the 8px
                                            // default scale). The intern id
                                            // rides hp_key; the property
                                            // itself is not heap-stored
                                            // (ctx.font is write-only in the
                                            // titles). Stack/ip settled here.
                                            hp_key_n =
                                                `VST_AT(vsp - 12'd1)[15:0];
                                            vst_wr(vsp - 12'd2,
                                                   `VST_AT(vsp - 12'd1));
                                            vsp_n = vsp - 12'd1;
                                            ip_n = ip + 16'd1;
                                            code_raddr_n =
                                                15'(ops_base + ip + 16'd1);
                                            state_n = S_FONTPX;
                                        end else begin
                                        hp_cmd_n = HP_SETPROP;
                                        hp_v64_n = 1'b1;
                                        hp_env_n = 1'b0;
                                        hp_oid_n = handle[12:0];
                                        hp_key_n = opw[23:8];
                                        hp_wval_n = `VST_AT(vsp - 12'd1);
                                        hp_len_n = vobj_len_rdata;
                                        hp_slot_n = 5'd0;
                                        hp_phase_n = 3'd0;
                                        hp_tag_n = 3'd0;
                                        // Latch handle gen for parent CMP
                                        // (phase 3 Image.src overwrites spr_w).
                                        hp_spr_w_n = {4'd0, handle[43:32]};
                                        if (opw[23:8] == id_src &&
                                            vobj_builtin_rdata == 4'd2 &&
                                            `VST_AT(vsp - 12'd1)[63:48] ==
                                                V64_TAG_PREFIX &&
                                            `VST_AT(vsp - 12'd1)[47:44] ==
                                                4'd4) begin
                                            // PYTHON Image.src jmr:spr:N
                                            // also writes width/height (gun size).
                                            for (int k = 0; k < 16; k++)
                                                if (`VST_AT(vsp - 12'd1)[15:0] ==
                                                        spr_nid[k[3:0]]) begin
                                                    vobj_cls_we = 1'b1; vobj_cls_waddr = handle[12:0]; vobj_cls_wdata =
                                                        16'hFFC0 | k[15:0];
                                                    hp_spr_w_n = spr_ww[k[3:0]];
                                                    hp_spr_h_n = spr_hh[k[3:0]];
                                                    hp_phase_n = 3'd3;
                                                end
                                        end
                                        if (opw[23:8] == id_onload &&
                                            `VST_AT(vsp - 12'd1)[63:48] ==
                                                V64_TAG_PREFIX &&
                                            `VST_AT(vsp - 12'd1)[47:44] ==
                                                4'd7)
                                            hp_phase_n = 3'd6;
                                        // Latch fillStyle for fillRect intern;
                                        // still HEAP SETPROP so GET/stroke see it.
                                        state_n = S_HEAP_WAIT;
                                        end // else (not ctx.font)
                                    end
                                end
                            end
                            OP_NEW_OBJ: begin
                                if (vcsp_hs >= CSTK) begin
                                    machine_fault_n = 1'b1; fault_code_n = 8'd2; fault_site_n = 16'd5106;
                                    running_n = 1'b0; state_n = S_DONE;
                                end else if (vsp_hs < opw[31:24]) begin
                                    machine_fault_n = 1'b1; fault_code_n = 8'd1; fault_site_n = 16'd5109;
                                    running_n = 1'b0; state_n = S_DONE;
                                end else if (opw[31:24] == 8'd0 &&
                                             vsp_hs >= 12'(STACK_DEPTH)) begin
                                    machine_fault_n = 1'b1; fault_code_n = 8'd1; fault_site_n = 16'd5113;
                                        running_n = 1'b0; state_n = S_DONE;
                                    end else begin
                                    // Latch argc: ALLOC/CTOR_* re-read of
                                    // opw[31:24] after HEAP was a1=1
                                    // (LET_VAR) → vsp-1 wrap 4095 (INVADERS
                                    // new Player after renderLeaderboard).
                                    // Latch class intern the same way:
                                    // GET_PROP HEAP before nested `new Item`
                                    // left opw as Game, so ALLOC
                                    // scanned Game's ctor (ip=1) again
                                    // (PACMAN vcsp=126 / snippet vret=39).
                                    // IIFE CALL_VAL leaves vcall_value=1;
                                    // kind 3 would BIND as a call. Nested
                                    // `new` also needs exec vcsp+1 so ALLOC
                                    // writes vframe[e64-1], not frame[0].
                                    vcall_value_n = 1'b0;
                                    vcall_entry_n = opw[23:8];
                                    vcall_argc_n = {4'd0, opw[31:24]};
                                    vcsp_n = vcsp_hs + 8'd1;
                                    valloc_kind_n = 2'd0;
                                    valloc_i_n = vobj_next;
                                    valloc_retried_n = 1'b0;
                                    state_n = S_V64_ALLOC;
                                end
                            end
                            OP_CALL_METH: begin
                                logic [11:0] argc, base;
                                logic [63:0] receiver;
                                logic [15:0] mip;
                                logic obj_ok, arr_ok;
                                logic [7:0] paint_color;
                                logic [4:0] same_n;
                                logic dup;
                                logic [63:0] ev, fn;
                                argc = {4'd0, opw[31:24]};
                                // raddr comb already uses vsp_hs (cm_base).
                                // Body must match or forEach/fillText/getContext
                                // read NOS after parent hs_vsp.
                                base = (vsp_hs > argc)
                                    ? (vsp_hs - argc - 12'd1) : 12'd0;
                                receiver = (vsp_hs > argc)
                                    ? `VST_AT(base)
                                    : V64_UNDEFINED;
                                mip = 16'hFFFF;
                                // Object or ELEMENT (PYTHON canvas/DOM). Exec
                                // alloc/gen copies lag parent HEAP — gating
                                // intern on them dropped ctx.fillRect /
                                // drawImage. Parent HEAP keeps gen.
                                obj_ok = (receiver[63:48] == V64_TAG_PREFIX &&
                                          (receiver[47:44] == V64_KIND_OBJECT ||
                                           receiver[47:44] == V64_KIND_ELEMENT) &&
                                          receiver[31:0] < MAX_OBJ);

                                // Keep valid; do not gate on exec varr_gen
                                // (GC reuse: handle gen=2, exec copy still 1
                                // → push/forEach no-op. INVADERS cells.push,
                                // PACMAN maps.forEach).
                                arr_ok = (receiver[63:48] == V64_TAG_PREFIX &&
                                          receiver[47:44] == V64_KIND_ARRAY &&
                                          receiver[31:0] < MAX_ARR &&
                                          varr_valid_rdata);
                                paint_color = 8'd0;
                                same_n = 5'd0;
                                dup = 1'b0;
                                ev = V64_UNDEFINED;
                                fn = V64_UNDEFINED;
                                if (vcsp >= CSTK) begin
                                    machine_fault_n = 1'b1; fault_code_n = 8'd2; fault_site_n = 16'd5180;
                                    running_n = 1'b0; state_n = S_DONE;
                                end else if (vsp_hs < argc + 12'd1) begin
                                    machine_fault_n = 1'b1; fault_code_n = 8'd1; fault_site_n = 16'd5183;
                                    running_n = 1'b0; state_n = S_DONE;
                                end else if (opw[23:8] == id_assign &&
                                           argc >= 12'd1) begin
                                    // Object.assign(target, ...src) sequential
                                    // SRAM (no 32×32 combo mux).
                                    begin
                                        logic [63:0] tgt, sv0;
                                        logic tgt_ok, src0_ok;
                                        tgt = `VST_AT(base + 12'd1);
                                        tgt_ok = (tgt[63:48] == V64_TAG_PREFIX &&
                                                  (tgt[47:44] == V64_KIND_OBJECT ||
                                                   tgt[47:44] == V64_KIND_ELEMENT) &&
                                                  tgt[31:0] < MAX_OBJ);
                                        sv0 = `VST_AT(base + 12'd2);
                                        src0_ok = (argc >= 12'd2 &&
                                                   sv0[63:48] == V64_TAG_PREFIX &&
                                                   (sv0[47:44] == V64_KIND_OBJECT ||
                                                    sv0[47:44] == V64_KIND_ELEMENT) &&
                                                   sv0[31:0] < MAX_OBJ);
                                        vst_wr(base, tgt);
                                        ip_n = ip + 16'd1;
                                        code_raddr_n =
                                            15'(ops_base + ip + 16'd1);
                                        if (tgt_ok && src0_ok) begin
                                            // Keep vsp until HP_ASSIGN finishes
                                            // so later sources stay in the TOS
                                            // window. Collapsing here made
                                            // Object.assign(this, settings,
                                            // params) copy `this` instead of
                                            // params (PACMAN Item times /
                                            // orientation / update).
                                            hp_cmd_n = HP_ASSIGN;
                                            hp_v64_n = 1'b1;
                                            hp_oid_n = tgt[12:0];
                                            hp_si_n = sv0[12:0];
                                            hp_ss_n = 5'd0;
                                            // phase 4: the parent reads the
                                            // TARGET length with a settled
                                            // read first. Latching
                                            // vobj_len_rdata here took a
                                            // stale value (the previous
                                            // item's length): appends began
                                            // at that offset, hit the
                                            // 32-slot cap, and the late
                                            // props (type/draw/update) were
                                            // dropped — PACMAN's ghosts and
                                            // player never drew.
                                            hp_phase_n = 3'd4;
                                            hp_tn_n = vobj_len_rdata;
                                            hp_qi_n = 3'd0;
                                            hp_qn_n = argc[2:0] - 3'd1;
                                            hp_vbase_n = base + 12'd2;
                                            hp_ret_n = S_FETCH_WAIT;
                                            state_n = S_HEAP_WAIT;
                                        end else begin
                                            vsp_n = base + 12'd1;
                                            state_n = S_FETCH_WAIT;
                                        end
                                    end
                                end else if (arr_ok &&
                                           opw[23:8] == id_push) begin
                                    if (varr_len_rdata + argc[7:0] >
                                            ARR_CAP[7:0]) begin
                                        machine_fault_n = 1'b1;
                                        fault_code_n = 8'd3;
                                        fault_site_n = 16'd5218;
                                        running_n = 1'b0; state_n = S_DONE;
                                    end else if (!varr_long_rdata &&
                                        (varr_len_rdata + argc[7:0] >
                                            ARR_SHORT_CAP[7:0]) &&
                                        !vprom_done && !p_vprom_done) begin
                                        hp_aid_n = receiver[11:0];
                                        valloc_i_n = 14'd0;
                                        vprom_copy_n = 1'b0;
                                        vprom_ret_n = S_V64_EXEC;
                                        state_n = S_ARR_PROMOTE;
                                    end else begin
                                        vprom_done_n = 1'b0;
                                        varr_len_we = 1'b1; varr_len_waddr = receiver[11:0]; varr_len_wdata =
                                            varr_len_rdata + argc[7:0];
                                        vst_wr(base, v64_int32_number(
                                            {24'd0, varr_len_rdata} +
                                            {20'd0, argc}
                                        ));
                                        vsp_n = base + 12'd1;
                                        ip_n = ip + 16'd1;
                                        code_raddr_n =
                                            15'(ops_base + ip + 16'd1);
                                        if (argc == 12'd0)
                                            state_n = S_FETCH_WAIT;
                                        else begin
                                            hp_cmd_n = HP_AFILL;
                                            hp_v64_n = 1'b1;
                                            hp_from_stack_n = 1'b1;
                                            hp_make_arr_n = 1'b0;
                                            hp_aid_n = receiver[11:0];
                                            hp_aslot_n =
                                                varr_len_rdata[6:0];
                                            hp_lim_n =
                                                varr_len_rdata[7:0] +
                                                argc[7:0];
                                            hp_vbase_n = base + 12'd1 -
                                                {4'd0, varr_len_rdata};
                                            hp_ret_n = S_FETCH_WAIT;
                                            state_n = S_HEAP_FILL;
                                        end
                                    end
                                end else if (arr_ok &&
                                           (id_pop != 16'hFFFF &&
                                            opw[23:8] == id_pop)) begin
                                    // PYTHON Array.pop: return last element
                                    // (undefined if empty) and shrink length.
                                    begin
                                        logic [7:0] al;
                                        al = varr_len_rdata;
                                        ip_n = ip + 16'd1;
                                        code_raddr_n =
                                            15'(ops_base + ip + 16'd1);
                                        vnat_base_n = base;
                                        if (al == 8'd0) begin
                                            vst_wr(base, V64_UNDEFINED);
                                            vsp_n = base + 12'd1;
                                            state_n = S_FETCH_WAIT;
                                        end else begin
                                            varr_len_we = 1'b1; varr_len_waddr = receiver[11:0]; varr_len_wdata =
                                                al - 8'd1;
                                            hp_cmd_n = HP_AGETI;
                                            hp_v64_n = 1'b1;
                                            hp_aid_n = receiver[11:0];
                                            hp_aslot_n = al[6:0] - 7'd1;
                                            hp_alen_n = al;
                                            hp_ret_n = S_FETCH_WAIT;
                                            state_n = S_HEAP_WAIT;
                                        end
                                    end
                                end else if (arr_ok &&
                                           id_sort != 16'hFFFF &&
                                           opw[23:8] == id_sort) begin
                                    // #41 Array.sort(cmp) — parent bubble
                                    // walk S_V64_SORT; one comparator call
                                    // per compare via the FE plumbing.
                                    if (vfe_sp >= 4'd8) begin
                                        machine_fault_n = 1'b1;
                                        fault_code_n = 8'd3;
                                        fault_site_n = 16'd5299;
                                        running_n = 1'b0; state_n = S_DONE;
                                    end else if (argc == 12'd0 ||
                                               varr_len_rdata < 8'd2) begin
                                        // no comparator (or nothing to do):
                                        // return the receiver unchanged.
                                        vst_wr(base, receiver);
                                        vsp_n = base + 12'd1;
                                        ip_n = ip + 16'd1;
                                        code_raddr_n =
                                            15'(ops_base + ip + 16'd1);
                                        state_n = S_FETCH_WAIT;
                                    end else begin
                                        vfe_s_we = 1'b1;
                                        vfe_s_waddr = vfe_sp[2:0];
                                        vfe_arr_s_wdata = vfe_arr;
                                        vfe_fn_s_wdata = vfe_fn;
                                        vfe_i_s_wdata = vfe_i;
                                        vfe_len_s_wdata = vfe_len;
                                        vfe_ret_s_wdata = vfe_ret;
                                        vfe_base_s_wdata = vfe_base;
                                        vfe_mode_s_wdata = vfe_mode;
                                        vfe_map_s_wdata = vfe_map;
                                        vfe_reduce_s_wdata = vfe_reduce;
                                        vfe_sort_s_wdata = vfe_sort;
                                        vfe_sp_n = vfe_sp + 4'd1;
                                        vfe_arr_n = receiver;
                                        vfe_fn_n = `VST_AT(base + 12'd1);
                                        vfe_i_n = 8'd0;
                                        vfe_len_n = varr_len_rdata;
                                        vfe_ret_n = ip + 16'd1;
                                        vfe_base_n = base;
                                        vfe_mode_n = 2'd0;
                                        vfe_reduce_n = 1'b0;
                                        vfe_sort_n = 1'b1;
                                        vfe_map_n = V64_UNDEFINED;
                                        vsp_n = base + 12'd2;
                                        vnat_base_n = base;
                                        hp_phase_n = 3'd0;
                                        state_n = S_V64_SORT;
                                    end
                                end else if (arr_ok &&
                                           id_slice != 16'hFFFF &&
                                           opw[23:8] == id_slice) begin
                                    // #40 Array.slice(start,end) — result
                                    // array via the S_FREE_ARR scan (same
                                    // re-decode flow as filter/map), then
                                    // the parent S_V64_SLICE copy walk.
                                    if (!vfree_armed) begin
                                        vfree_armed_n = 1'b1;
                                        vfree_arr_long_n =
                                            varr_long_rdata ||
                                            (varr_len_rdata >
                                                ARR_SHORT_CAP[7:0]);
                                        valloc_i_n =
                                            (varr_long_rdata ||
                                             (varr_len_rdata >
                                                ARR_SHORT_CAP[7:0]))
                                            ? 14'(MAX_ARR_SHORT) : 14'd0;
                                        hp_ret_n = S_FETCH_WAIT;
                                        state_n = S_FREE_ARR;
                                    end else if (!vfree_ok) begin
                                        vfree_armed_n = 1'b0;
                                        if (!valloc_retried) begin
                                            vgc_clear_i_n = 14'd0;
                                            vgc_qr_n = 14'd0;
                                            vgc_qw_n = 14'd0;
                                            vgc_halt_after_n = 1'b0;
                                            vgc_resume_n = 2'd1;
                                            state_n = S_V64_GC_CLEAR;
                                        end else begin
                                            machine_fault_n = 1'b1;
                                            fault_code_n = 8'd3;
                                            fault_site_n = 16'd5340;
                                            running_n = 1'b0;
                                            state_n = S_DONE;
                                        end
                                    end else begin
                                        logic [13:0] sfree;
                                        logic signed [31:0] s0, s1;
                                        logic [7:0] scnt;
                                        vfree_armed_n = 1'b0;
                                        sfree = valloc_i;
                                        valloc_retried_n = 1'b0;
                                        s0 = (argc >= 12'd1)
                                            ? v64_to_int32(`VST_AT(base + 1))
                                            : 32'sd0;
                                        s1 = (argc >= 12'd2)
                                            ? v64_to_int32(`VST_AT(base + 2))
                                            : 32'($signed({24'd0,
                                                varr_len_rdata}));
                                        if (s0 < 0)
                                            s0 = s0 + 32'($signed({24'd0,
                                                varr_len_rdata}));
                                        if (s1 < 0)
                                            s1 = s1 + 32'($signed({24'd0,
                                                varr_len_rdata}));
                                        if (s0 < 0) s0 = 32'sd0;
                                        if (s1 < 0) s1 = 32'sd0;
                                        if (s0 > 32'($signed({24'd0,
                                                varr_len_rdata})))
                                            s0 = 32'($signed({24'd0,
                                                varr_len_rdata}));
                                        if (s1 > 32'($signed({24'd0,
                                                varr_len_rdata})))
                                            s1 = 32'($signed({24'd0,
                                                varr_len_rdata}));
                                        scnt = (s1 > s0)
                                            ? 8'(s1 - s0) : 8'd0;
                                        begin varr_valid_we = 1'b1; varr_valid_waddr = sfree[11:0]; varr_valid_wdata = 1'b1; end
                                        varr_len_we = 1'b1;
                                        varr_len_waddr = sfree[11:0];
                                        varr_len_wdata = scnt;
                                        varr_long_we = 1'b1;
                                        varr_long_waddr = sfree[11:0];
                                        varr_long_wdata =
                                            vfree_arr_long ||
                                            (sfree >= 14'(MAX_ARR_SHORT));
                                        if (vfree_arr_long ||
                                            (sfree >= 14'(MAX_ARR_SHORT)))
                                        begin
                                            varr_lidx_we = 1'b1;
                                            varr_lidx_waddr = sfree[11:0];
                                            varr_lidx_wdata = sfree[7:0];
                                        end
                                        varr_next_n = sfree + 14'd1;
                                        vst_wr(base, v64_handle(
                                            4'd6, varr_gen_rdata,
                                            {20'd0, sfree[11:0]}));
                                        vsp_n = base + 12'd1;
                                        if (scnt == 8'd0) begin
                                            ip_n = ip + 16'd1;
                                            code_raddr_n =
                                                15'(ops_base + ip + 16'd1);
                                            state_n = S_FETCH_WAIT;
                                        end else begin
                                            hp_aid_n = receiver[11:0];
                                            hp_aslot_n = s0[6:0];
                                            hp_lim_n = 8'(s1);
                                            hp_oid_n = sfree[12:0];
                                            state_n = S_V64_SLICE;
                                        end
                                    end
                                end else if (id_disp != 16'hFFFF &&
                                           opw[23:8] == id_disp &&
                                           argc >= 12'd1 &&
                                           `VST_AT(vsp - 12'd1)[63:48] ==
                                               16'h7ff9 &&
                                           `VST_AT(vsp - 12'd1)[47:44] ==
                                               4'd5 &&
                                           `VST_AT(vsp - 12'd1)[31:0] <
                                               MAX_OBJ) begin
                                    // dispatchEvent(ev) — Value64 (existed
                                    // only in exec32; DONKEY's synthetic
                                    // boot Enter was silently dropped, the
                                    // "Enter twice" quirk). The REAL event
                                    // object rides hp_wval to the parent
                                    // S_V64_DISPATCH slot walk (finds
                                    // .type), then the FRAME_KEY listener
                                    // scan runs in custom mode and resumes
                                    // the program. Result true; stack and
                                    // ip settled here.
                                    hp_wval_n = `VST_AT(vsp - 12'd1);
                                    vst_wr(base,
                                        {16'h7ff9, 4'd3, 27'd0, 1'b1, 16'd0});
                                    vsp_n = base + 12'd1;
                                    ip_n = ip + 16'd1;
                                    code_raddr_n =
                                        15'(ops_base + ip + 16'd1);
                                    state_n = S_V64_DISPATCH;
                                end else if (arr_ok &&
                                           (opw[23:8] == id_foreach ||
                                            (id_find != 16'hFFFF &&
                                             opw[23:8] == id_find) ||
                                            (id_findindex != 16'hFFFF &&
                                             opw[23:8] == id_findindex) ||
                                            opw[23:8] == id_map ||
                                            (id_filter != 16'hFFFF &&
                                             opw[23:8] == id_filter) ||
                                            (id_reduce != 16'hFFFF &&
                                             opw[23:8] == id_reduce)))
                                begin
                                    if (vfe_sp >= 4'd8) begin
                                        machine_fault_n = 1'b1;
                                        fault_code_n = 8'd3;
                                        fault_site_n = 16'd5298;
                                        running_n = 1'b0; state_n = S_DONE;
                                    end else begin
                                        logic [13:0] free_a;
                                        logic found_a;
                                        logic [1:0] md;
                                        found_a = 1'b0;
                                        free_a = 14'd0;
                                        md = ((id_find != 16'hFFFF &&
                                               opw[23:8] == id_find) ||
                                              (id_findindex != 16'hFFFF &&
                                               opw[23:8] ==
                                                   id_findindex))
                                            ? 2'd1
                                            : (opw[23:8] == id_map)
                                            ? 2'd2
                                            : (id_filter != 16'hFFFF &&
                                               opw[23:8] == id_filter)
                                            ? 2'd3 : 2'd0;
                                        if ((md == 2'd2 || md == 2'd3) &&
                                            !vfree_armed) begin
                                            vfree_armed_n = 1'b1;
                                            vfree_arr_long_n =
                                                varr_long_rdata ||
                                                (varr_len_rdata >
                                                    ARR_SHORT_CAP[7:0]);
                                            valloc_i_n =
                                                (varr_long_rdata ||
                                                 (varr_len_rdata >
                                                    ARR_SHORT_CAP[7:0]))
                                                ? 14'(MAX_ARR_SHORT) : 14'd0;
                                            hp_ret_n = S_FETCH_WAIT;
                                            state_n = S_FREE_ARR;
                                        end else if ((md == 2'd2 || md == 2'd3) &&
                                            !vfree_ok) begin
                                            vfree_armed_n = 1'b0;
                                            // Same collect-then-retry as
                                            // S_V64_ALLOC. Immediate fault=3
                                            // froze PACMAN once Array.map
                                            // temps filled MAX_ARR.
                                            if (!valloc_retried) begin
                                                vgc_clear_i_n = 14'd0;
                                                vgc_qr_n = 14'd0;
                                                vgc_qw_n = 14'd0;
                                                vgc_halt_after_n = 1'b0;
                                                vgc_resume_n = 2'd1;
                                                state_n = S_V64_GC_CLEAR;
                                            end else begin
                                            machine_fault_n = 1'b1;
                                            fault_code_n = 8'd3;
                                            fault_site_n = 16'd5344;
                                            running_n = 1'b0;
                                            state_n = S_DONE;
                                            end
                                        end else begin
                                            vfree_armed_n = 1'b0;
                                            free_a = valloc_i;
                                            valloc_retried_n = 1'b0;
                                        vfe_s_we = 1'b1;
                                        vfe_s_waddr = vfe_sp[2:0];
                                        vfe_arr_s_wdata = vfe_arr;
                                        vfe_fn_s_wdata = vfe_fn;
                                        vfe_i_s_wdata = vfe_i;
                                        vfe_len_s_wdata = vfe_len;
                                        vfe_ret_s_wdata = vfe_ret;
                                        vfe_base_s_wdata = vfe_base;
                                        vfe_mode_s_wdata = vfe_mode;
                                        vfe_map_s_wdata = vfe_map;
                                        vfe_reduce_s_wdata = vfe_reduce;
                                        // #39: reduce(cb, init) — cb is at
                                        // base+1 (NOT vsp-1: init sits above
                                        // it); the accumulator rides vfe_map
                                        // (GC-marked with the map shadow).
                                        vfe_reduce_n =
                                            (id_reduce != 16'hFFFF &&
                                             opw[23:8] == id_reduce);
                                        vfe_findidx_s_wdata = vfe_findidx;
                                        vfe_findidx_n =
                                            (id_findindex != 16'hFFFF &&
                                             opw[23:8] ==
                                                 id_findindex);
                                        vfe_sort_n = 1'b0;
                                        vfe_sort_s_wdata = vfe_sort;
                                        vfe_sp_n = vfe_sp + 4'd1;
                                        vfe_arr_n = receiver;
                                        vfe_fn_n = (argc != 0)
                                            ? `VST_AT(base + 12'd1)
                                            : V64_UNDEFINED;
                                        vfe_i_n = 8'd0;
                                        vfe_len_n = varr_len_rdata;
                                        vfe_ret_n = ip + 16'd1;
                                        vfe_base_n = base;
                                        vfe_mode_n = md;
                                        if (md == 2'd2 || md == 2'd3) begin
                                            begin varr_valid_we = 1'b1; varr_valid_waddr = free_a[11:0]; varr_valid_wdata = 1'b1; end
                                            varr_len_we = 1'b1; varr_len_waddr = free_a[11:0]; varr_len_wdata =
                                                (md == 2'd2)
                                                ? varr_len_rdata
                                                : 8'd0;
                                            varr_long_we = 1'b1; varr_long_waddr = free_a[11:0]; varr_long_wdata =
                                                vfree_arr_long ||
                                                (free_a >= 14'(MAX_ARR_SHORT));
                                            if (vfree_arr_long ||
                                                (free_a >= 14'(MAX_ARR_SHORT)))
                                            begin
                                                varr_lidx_we = 1'b1; varr_lidx_waddr = free_a[11:0]; varr_lidx_wdata =
                                                    free_a[7:0];
                                            end
                                            varr_next_n = free_a + 14'd1;
                                            vfe_map_n = v64_handle(
                                                4'd6, varr_gen_rdata,
                                                {20'd0, free_a[11:0]}
                                            );
                                            vnat_base_n = base;
                                            if (md == 2'd2 &&
                                                varr_len_rdata != 8'd0)
                                            begin
                                                hp_cmd_n = HP_AFILL;
                                                hp_v64_n = 1'b1;
                                                hp_from_stack_n = 1'b0;
                                                hp_aid_n = free_a[11:0];
                                                hp_aslot_n = 7'd0;
                                                hp_lim_n = varr_len_rdata;
                                                hp_wval_n = V64_UNDEFINED;
                                                hp_ret_n = S_V64_FOREACH;
                                                state_n = S_HEAP_FILL;
                                            end else
                                                state_n = S_V64_FOREACH;
                                        end else begin
                                            vfe_map_n =
                                                (id_reduce != 16'hFFFF &&
                                                 opw[23:8] == id_reduce
                                                 && argc >= 12'd2)
                                                ? `VST_AT(base + 12'd2)
                                                : V64_UNDEFINED;
                                            // #39: drop the init arg — the
                                            // iteration pushes assume vsp is
                                            // base+2 ([recv, cb]); leaving
                                            // init on the stack misaligned
                                            // iteration 1's binding by one.
                                            if (id_reduce != 16'hFFFF &&
                                                opw[23:8] == id_reduce
                                                && argc >= 12'd2)
                                                vsp_n = base + 12'd2;
                                            vnat_base_n = base;
                                            state_n = S_V64_FOREACH;
                                        end
                                    end
                                    end
                                end else if (opw[23:8] == id_getctx) begin
                                    vnat_dom_n = 3'd3;
                                    vnat_base_n = base;
                                    valloc_kind_n = 2'd0;
                                    valloc_i_n = vobj_next;
                                    valloc_retried_n = 1'b0;
                                    state_n = S_V64_ALLOC;
                                end else if (argc >= 12'd4 &&
                                           (opw[23:8] == id_fillrect ||
                                            opw[23:8] == id_clearrect)) begin
                                    // One host canvas. Do not require obj_ok:
                                    // ADD/MUL/LOAD_VAR can shift the TOS
                                    // window off the context (computed
                                    // fillRect never ran; literal bars did).
                                    // RECT_LD reads x/y/w/h from SRAM.
                                    cm_win_n = 1'b0;
                                    if (opw[23:8] != id_clearrect)
                                        paint_color = fill_style_i;
                                    // PYTHON _xf: always apply axis scale + translate
                                    // (identity sx=1, tx=0 is a no-op; save/translate
                                    // then fillRect must not skip tx).
                                    vdraw_x_n = clip_u(32'(
                                        ($signed(v64_to_int32(`VST_AT(base + 1)))
                                         * ctx_sx) >>> 16) + ctx_tx, MW);
                                    vdraw_y_n = clip_u(32'(
                                        ($signed(v64_to_int32(`VST_AT(base + 2)))
                                         * ctx_sy) >>> 16) + ctx_ty, MH);
                                    vdraw_w_n = clip_sz(32'(
                                        ($signed(v64_to_int32(`VST_AT(base + 3)))
                                         * ctx_sx) >>> 16), 10'd0, MW);
                                    vdraw_h_n = clip_sz(32'(
                                        ($signed(v64_to_int32(`VST_AT(base + 4)))
                                         * ctx_sy) >>> 16), 10'd0, MH);
                                    vdraw_color_n = (opw[23:8] == id_clearrect)
                                        ? 8'd0 : paint_color;
                                    vdraw_i_n = 19'd0;
                                    vnat_base_n = base;
                                    vst_hold_win_n = 1'b0;
                                    // Do not latch x/y/w/h from VST_AT: after
                                    // drawBitmap ADD/MUL the TOS window can
                                    // still hold the last literal bar
                                    // (vdraw stuck at 70,68,500,7). Parent
                                    // RECT_LD reads the four args from SRAM.
                                    state_n = S_V64_RECT_LD;
                                end else if (obj_ok && argc >= 12'd4 &&
                                           opw[23:8] == id_getimgdata) begin
                                    // PYTHON ctx.getImageData — copy back buffer
                                    // (PACMAN map.cache). Unknown-method used to
                                    // return the context, which is truthy, so
                                    // later frames putImageData'd nothing.
                                    begin
                                        logic signed [31:0] gx, gy, gw, gh;
                                        logic [9:0] x0, y0, ww, hh;
                                        gx = v64_to_int32(`VST_AT(base + 12'd1));
                                        gy = v64_to_int32(`VST_AT(base + 12'd2));
                                        gw = v64_to_int32(`VST_AT(base + 12'd3));
                                        gh = v64_to_int32(`VST_AT(base + 12'd4));
                                        x0 = clip_u(gx, MW);
                                        y0 = clip_u(gy, MH);
                                        ww = clip_sz(gw, x0, MW);
                                        hh = clip_sz(gh, y0, MH);
                                        imgd_x0_n = x0; imgd_y0_n = y0;
                                        imgd_w_n = ww; imgd_h_n = hh;
                                        imgd_x_n = x0; imgd_y_n = y0;
                                        imgd_i_n = 19'd0;
                                        imgd_n_n = (32'(ww) * 32'(hh) > 32'(FB_PIXELS))
                                            ? 19'(FB_PIXELS) : 19'(32'(ww) * 32'(hh));
                                        imgd_armed_n = 1'b0;
                                        imgd_v64_n = 1'b1;
                                        vnat_base_n = base;
                                        ip_n = ip + 16'd1;
                                        fb_dump_sel_n = 1'b1;
                                        fb_dump_addr_n = 19'(y0) * 19'(MW) + 19'(x0);
                                        state_n = S_IMGD_GET;
                                    end
                                end else if (obj_ok && argc >= 12'd1 &&
                                           opw[23:8] == id_putimgdata) begin
                                    begin
                                        logic [63:0] src;
                                        src = `VST_AT(base + 12'd1);
                                        if (src[63:48] == V64_TAG_PREFIX &&
                                            src[47:44] == V64_KIND_OBJECT &&
                                            src[31:0] < MAX_OBJ &&
                                            vobj_cls_rdata == CLS_IMGD) begin
                                            imgd_x0_n = (argc >= 12'd2)
                                                ? clip_u(v64_to_int32(
                                                    `VST_AT(base + 12'd2)), MW)
                                                : 10'd0;
                                            imgd_y0_n = (argc >= 12'd3)
                                                ? clip_u(v64_to_int32(
                                                    `VST_AT(base + 12'd3)), MH)
                                                : 10'd0;
                                            vnat_base_n = base;
                                            ip_n = ip + 16'd1;
                                            hp_cmd_n = HP_OGETI;
                                            hp_v64_n = 1'b1;
                                            hp_oid_n = src[12:0];
                                            hp_slot_n = 5'd0;
                                            hp_qn_n = 3'd2;
                                            hp_qi_n = 3'd0;
                                            hp_nat_n = 4'd1;
                                            hp_vbase_n = base;
                                            hp_ret_n = S_V64_OGETI_NAT;
                                            state_n = S_HEAP_WAIT;
                                        end else begin
                                            vst_wr(base, V64_UNDEFINED);
                                            vsp_n = base + 12'd1;
                                            ip_n = ip + 16'd1;
                                            code_raddr_n =
                                                15'(ops_base + ip + 16'd1);
                                            state_n = S_FETCH_WAIT;
                                        end
                                    end
                                end else if (obj_ok &&
                                           vobj_builtin_rdata == 4'd5 &&
                                           opw[23:8] == id_save) begin
                                    // PYTHON ctx.save — one-deep transform stack.
                                    saved_tx_n = ctx_tx; saved_ty_n = ctx_ty;
                                    saved_sx_n = ctx_sx; saved_sy_n = ctx_sy;
                                    vst_wr(base, V64_UNDEFINED);
                                    vsp_n = base + 12'd1;
                                    ip_n = ip + 16'd1;
                                    code_raddr_n =
                                        15'(ops_base + ip + 16'd1);
                                    state_n = S_FETCH_WAIT;
                                end else if (obj_ok &&
                                           vobj_builtin_rdata == 4'd5 &&
                                           opw[23:8] == id_restore) begin
                                    ctx_tx_n = saved_tx; ctx_ty_n = saved_ty;
                                    ctx_sx_n = saved_sx; ctx_sy_n = saved_sy;
                                    vst_wr(base, V64_UNDEFINED);
                                    vsp_n = base + 12'd1;
                                    ip_n = ip + 16'd1;
                                    code_raddr_n =
                                        15'(ops_base + ip + 16'd1);
                                    state_n = S_FETCH_WAIT;
                                end else if (obj_ok && argc >= 12'd2 &&
                                           vobj_builtin_rdata == 4'd5 &&
                                           opw[23:8] == id_translate) begin
                                    // PYTHON ctx.translate — Player.drawImage(-w/2,-h/2)
                                    // lands on position after this.
                                    ctx_tx_n = ctx_tx + v64_to_int32(`VST_AT(base + 1));
                                    ctx_ty_n = ctx_ty + v64_to_int32(`VST_AT(base + 2));
                                    vst_wr(base, V64_UNDEFINED);
                                    vsp_n = base + 12'd1;
                                    ip_n = ip + 16'd1;
                                    code_raddr_n =
                                        15'(ops_base + ip + 16'd1);
                                    state_n = S_FETCH_WAIT;
                                end else if (obj_ok && argc >= 12'd6 &&
                                           opw[23:8] == id_settransform) begin
                                    // PYTHON setTransform(a,b,c,d,e,f) — axis scale.
                                    begin
                                        logic signed [31:0] sx, sy;
                                        sx = v64_to_fx(`VST_AT(base + 1));
                                        sy = v64_to_fx(`VST_AT(base + 4));
                                        ctx_sx_n = (sx == 32'sd0) ? FX_ONE : sx;
                                        ctx_sy_n = (sy == 32'sd0) ? FX_ONE : sy;
                                        ctx_tx_n = v64_to_int32(`VST_AT(base + 5));
                                        ctx_ty_n = v64_to_int32(`VST_AT(base + 6));
                                        vst_wr(base, V64_UNDEFINED);
                                        vsp_n = base + 12'd1;
                                        ip_n = ip + 16'd1;
                                        code_raddr_n =
                                            15'(ops_base + ip + 16'd1);
                                        state_n = S_FETCH_WAIT;
                                    end
                                end else if (argc >= 12'd3 &&
                                           opw[23:8] == id_drawimage) begin
                                    // PYTHON ctx.drawImage — ASET blit when
                                    // Image.src was jmr:spr:N (vobj_cls FFC).
                                    begin
                                        logic [63:0] img;
                                        logic [7:0] si;
                                        logic spr_ok;
                                        img = `VST_AT(base + 1);
                                        si = 8'(vobj_cls_rdata[3:0]);
                                        spr_ok = (img[63:48] == V64_TAG_PREFIX &&
                                                  img[47:44] == V64_KIND_OBJECT &&
                                                  img[31:0] < MAX_OBJ &&
                                                  vobj_cls_rdata[15:4] ==
                                                      12'hFFC &&
                                                  {1'b0, si} < {4'd0, n_spr});
                                        if (spr_ok) begin
                                            dbg_di_hit_n = dbg_di_hit + 16'd1;
                                            blit_si_n = si;
                                            if (argc >= 12'd9) begin
                                                blit_sx_n = clip_src(
                                                    $signed(v64_to_int32(
                                                        `VST_AT(base + 2))));
                                                blit_sy_n = clip_src(
                                                    $signed(v64_to_int32(
                                                        `VST_AT(base + 3))));
                                                blit_sw_n = clip_src(
                                                    $signed(v64_to_int32(
                                                        `VST_AT(base + 4))));
                                                blit_sh_n = clip_src(
                                                    $signed(v64_to_int32(
                                                        `VST_AT(base + 5))));
                                                rx_n = clip_u(32'(
                                                    ($signed(v64_to_int32(
                                                        `VST_AT(base + 6)))
                                                     * ctx_sx) >>> 16) + ctx_tx, MW);
                                                ry_n = clip_u(32'(
                                                    ($signed(v64_to_int32(
                                                        `VST_AT(base + 7)))
                                                     * ctx_sy) >>> 16) + ctx_ty, MH);
                                                rw_n = clip_sz(32'(
                                                    ($signed(v64_to_int32(
                                                        `VST_AT(base + 8)))
                                                     * ctx_sx) >>> 16), 10'd0, MW);
                                                rh_n = clip_sz(32'(
                                                    ($signed(v64_to_int32(
                                                        `VST_AT(base + 9)))
                                                     * ctx_sy) >>> 16), 10'd0, MH);
                                            end else begin
                                                blit_sx_n = 16'd0; blit_sy_n = 16'd0;
                                                blit_sw_n = spr_ww[si[3:0]];
                                                blit_sh_n = spr_hh[si[3:0]];
                                                rx_n = clip_u(32'(
                                                    ($signed(v64_to_int32(
                                                        `VST_AT(base + 2)))
                                                     * ctx_sx) >>> 16) + ctx_tx, MW);
                                                ry_n = clip_u(32'(
                                                    ($signed(v64_to_int32(
                                                        `VST_AT(base + 3)))
                                                     * ctx_sy) >>> 16) + ctx_ty, MH);
                                                if (argc >= 12'd5) begin
                                                    rw_n = clip_sz(32'(
                                                        ($signed(v64_to_int32(
                                                            `VST_AT(base + 4)))
                                                         * ctx_sx) >>> 16),
                                                        10'd0, MW);
                                                    rh_n = clip_sz(32'(
                                                        ($signed(v64_to_int32(
                                                            `VST_AT(base + 5)))
                                                         * ctx_sy) >>> 16),
                                                        10'd0, MH);
                                                end else begin
                                                    // Natural-size drawImage
                                                    // must still honor the
                                                    // setTransform scale —
                                                    // this branch took the
                                                    // sprite w/h raw while
                                                    // the explicit-dw/dh one
                                                    // multiplied by ctx_sx
                                                    // (2x transform drew 1x).
                                                    rw_n = clip_sz(32'(
                                                        ($signed({16'd0,
                                                            spr_ww[si[3:0]]})
                                                         * ctx_sx) >>> 16),
                                                        10'd0, MW);
                                                    rh_n = clip_sz(32'(
                                                        ($signed({16'd0,
                                                            spr_hh[si[3:0]]})
                                                         * ctx_sy) >>> 16),
                                                        10'd0, MH);
                                                end
                                            end
                                            x_n = 10'd0; y_n = 10'd0;
                                            vst_wr(base, V64_UNDEFINED);
                                            vsp_n = base + 12'd1;
                                            ip_n = ip + 16'd1;
                                            state_n = S_BLIT;
                                        end else begin
                                            dbg_di_miss_n = dbg_di_miss + 16'd1;
                                            vst_wr(base, V64_UNDEFINED);
                                            vsp_n = base + 12'd1;
                                            ip_n = ip + 16'd1;
                                            code_raddr_n =
                                                15'(ops_base + ip + 16'd1);
                                            state_n = S_FETCH_WAIT;
                                        end
                                    end
                                end else if (obj_ok && argc >= 12'd3 &&
                                           opw[23:8] == id_filltext) begin
                                    // Reuse S_TXT_LD / S_TXT_DRAW (same glyphs as
                                    // the tagged VM). PYTHON String(t): intern
                                    // or ToString(number). txt_vt=5 used to
                                    // bump dbg_str_ovf and sticky-fault SCORE.
                                    color_n = fill_style_i;
                                    if (`VST_AT(base + 1)[63:48] == V64_TAG_PREFIX &&
                                        `VST_AT(base + 1)[47:44] == 4'd4)
                                        begin
                                            txt_val_n = {16'd0, `VST_AT(base + 1)[15:0]};
                                            txt_vt_n = 3'd3;
                                        end
                                    else if (v64_is_number(`VST_AT(base + 1))) begin
                                        txt_val_n = v64_to_int32(`VST_AT(base + 1));
                                        txt_vt_n = 3'd0;
                                    end
                                    else begin
                                        txt_val_n = 32'd0;
                                        txt_vt_n = 3'd0;
                                    end
                                    txt_ph_n = 4'd0;
                                    // PYTHON _xf: fillText pen uses the same axis
                                    // scale + translate as fillRect/drawImage
                                    // (`Press Enter` at world y=500 on glass).
                                    txt_px_n = 16'(
                                        ($signed(v64_to_int32(`VST_AT(base + 2)))
                                         * ctx_sx >>> 16) + ctx_tx);
                                    txt_py_n = 16'(
                                        ($signed(v64_to_int32(`VST_AT(base + 3)))
                                         * ctx_sy >>> 16) + ctx_ty);
                                    vst_wr(base, V64_UNDEFINED);
                                    vsp_n = base + 12'd1;
                                    ip_n = ip + 16'd1;
                                    code_raddr_n =
                                        15'(ops_base + ip + 16'd1);
                                    state_n = S_TXT_LD;
                                end else if (obj_ok &&
                                           opw[23:8] == id_measuretext) begin
                                    // PYTHON _nat_measure_text: len * 8 px.
                                    begin
                                        logic [15:0] tl;
                                        logic [63:0] txt;
                                        logic dyn;
                                        tl = 16'd0;
                                        dyn = 1'b0;
                                        txt = (argc != 0) ? `VST_AT(base + 12'd1)
                                            : V64_UNDEFINED;
                                        if (txt[63:48] == V64_TAG_PREFIX &&
                                            txt[47:44] == 4'd4 &&
                                            txt[31:0] < 32'd1024)
                                            // potential-bugs #36: name_blen is
                                            // u16 (TXT/NAME bytes), so the
                                            // [7:0] slice wrapped any intern
                                            // 256 bytes or longer to a short
                                            // width. PYTHON _nat_measure_text
                                            // is len*8*_font_scale; the font
                                            // scale still needs #45 (exec64
                                            // has no ctx_font_px).
                                            tl = name_blen_rdata;
                                        else if (txt[63:48] == V64_TAG_PREFIX &&
                                                 txt[47:44] == V64_KIND_OBJECT &&
                                                 txt[31:0] < MAX_OBJ &&
                                                 vobj_builtin_rdata == 4'd7)
                                            dyn = 1'b1;
                                        ip_n = ip + 16'd1;
                                        code_raddr_n =
                                            15'(ops_base + ip + 16'd1);
                                        hp_vbase_n = base;
                                        if (dyn) begin
                                            hp_cmd_n = HP_OGETI;
                                            hp_v64_n = 1'b1;
                                            hp_oid_n = txt[12:0];
                                            hp_slot_n = 5'd0;
                                            hp_qn_n = 3'd2;
                                            hp_qi_n = 3'd0;
                                            hp_nat_n = 4'd2;
                                            hp_ret_n = S_V64_OGETI_NAT;
                                            state_n = S_HEAP_WAIT;
                                        end else begin
                                            vmetrics_w_n = (tl << 3);
                                            if (vmetrics[63:48] == V64_TAG_PREFIX &&
                                                vmetrics[47:44] == V64_KIND_OBJECT &&
                                                vmetrics[31:0] < MAX_OBJ &&
                                                vobj_alloc_rdata == 2'd1)
                                            begin
                                                vst_wr(base, vmetrics);
                                                vsp_n = base + 12'd1;
                                                hp_cmd_n = HP_OSETI;
                                                hp_v64_n = 1'b1;
                                                hp_oid_n = vmetrics[12:0];
                                                hp_slot_n = 5'd0;
                                                hp_qn_n = 3'd1;
                                                hp_qi_n = 3'd0;
                                                hp_q_we = 1'b1;
                                                hp_q_waddr = 2'd0;
                                                hp_qk_wdata = id_width;
                                                hp_qv_wdata =
                                                    v64_int32_number({16'd0, tl << 3});
                                                hp_qt_wdata = 3'd0;
                                                hp_ret_n = S_FETCH_WAIT;
                                                state_n = S_HEAP_WR;
                                            end else begin
                                                valloc_metrics_n = 1'b1;
                                                vnat_base_n = base;
                                                valloc_kind_n = 2'd0;
                                                valloc_i_n = vobj_next;
                                                valloc_retried_n = 1'b0;
                                                state_n = S_V64_ALLOC;
                                            end
                                        end
                                    end
                                end else if (arr_ok &&
                                           opw[23:8] == id_fill) begin
                                    // Array.fill(v) — not ctx.fill(). PYTHON
                                    // writes every slot and returns the array.
                                    begin
                                        logic [7:0] al;
                                        logic [63:0] fv;
                                        al = varr_len_rdata;
                                        fv = (argc != 0)
                                            ? `VST_AT(base + 12'd1)
                                            : V64_UNDEFINED;
                                        vst_wr(base, receiver);
                                        vsp_n = base + 12'd1;
                                        ip_n = ip + 16'd1;
                                        code_raddr_n =
                                            15'(ops_base + ip + 16'd1);
                                        if (al != 8'd0) begin
                                            hp_cmd_n = HP_AFILL;
                                            hp_v64_n = 1'b1;
                                            hp_from_stack_n = 1'b0;
                                            hp_aid_n = receiver[11:0];
                                            hp_aslot_n = 7'd0;
                                            hp_lim_n = al;
                                            hp_wval_n = fv;
                                            hp_ret_n = S_FETCH_WAIT;
                                            state_n = S_HEAP_FILL;
                                        end else
                                            state_n = S_FETCH_WAIT;
                                    end
                                end else if (arr_ok &&
                                           opw[23:8] == id_unshift) begin
                                    begin
                                        logic [7:0] al;
                                        al = varr_len_rdata;
                                        if (al < ARR_CAP[7:0] &&
                                            !varr_long_rdata &&
                                            (al + 8'd1 > ARR_SHORT_CAP[7:0]) &&
                                            !vprom_done && !p_vprom_done) begin
                                            hp_aid_n = receiver[11:0];
                                            valloc_i_n = 14'd0;
                                            vprom_copy_n = 1'b0;
                                            vprom_ret_n = S_V64_EXEC;
                                            state_n = S_ARR_PROMOTE;
                                        end else if (al < ARR_CAP[7:0]) begin
                                            vprom_done_n = 1'b0;
                                            varr_len_we = 1'b1; varr_len_waddr = receiver[11:0]; varr_len_wdata =
                                                al + 8'd1;
                                            vst_wr(base, v64_int32_number(
                                                {24'd0, al} + 32'd1
                                            ));
                                            vsp_n = base + 12'd1;
                                            ip_n = ip + 16'd1;
                                            code_raddr_n =
                                                15'(ops_base + ip + 16'd1);
                                            if (al == 8'd0) begin
                                                hp_cmd_n = HP_ASETI;
                                                hp_v64_n = 1'b1;
                                                hp_from_stack_n = 1'b0;
                                                hp_aid_n = receiver[11:0];
                                                hp_aslot_n = 7'd0;
                                                hp_wval_n = (argc != 0)
                                                    ? `VST_AT(base + 12'd1)
                                                    : V64_UNDEFINED;
                                                hp_ret_n = S_FETCH_WAIT;
                                                state_n = S_HEAP_AWR;
                                            end else begin
                                                hp_cmd_n = HP_UNSHIFT;
                                                hp_v64_n = 1'b1;
                                                hp_from_stack_n = 1'b0;
                                                hp_aid_n = receiver[11:0];
                                                hp_aslot_n = al[6:0] - 7'd1;
                                                hp_alen_n = al;
                                                hp_rval_n = (argc != 0)
                                                    ? `VST_AT(base + 12'd1)
                                                    : V64_UNDEFINED;
                                                hp_phase_n = 3'd0;
                                                hp_ret_n = S_FETCH_WAIT;
                                                state_n = S_HEAP_WAIT;
                                            end
                                        end else begin
                                            vst_wr(base, v64_int32_number(
                                                {24'd0, al} + 32'd1
                                            ));
                                            vsp_n = base + 12'd1;
                                            ip_n = ip + 16'd1;
                                            code_raddr_n =
                                                15'(ops_base + ip + 16'd1);
                                            state_n = S_FETCH_WAIT;
                                        end
                                    end
                                end else if (arr_ok &&
                                           opw[23:8] == id_splice) begin
                                    logic [7:0] st, cnt, al;
                                    al = varr_len_rdata;
                                    st = (argc >= 12'd1)
                                        ? v64_to_uint32(`VST_AT(base + 1))[7:0]
                                        : 8'd0;
                                    cnt = (argc >= 12'd2)
                                        ? v64_to_uint32(`VST_AT(base + 2))[7:0]
                                        : 8'd1;
                                    if (st < al && cnt != 8'd0) begin
                                        varr_len_we = 1'b1; varr_len_waddr = receiver[11:0]; varr_len_wdata =
                                            (al > cnt) ? (al - cnt) : 8'd0;
                                        vst_wr(base, V64_UNDEFINED);
                                        vsp_n = base + 12'd1;
                                        ip_n = ip + 16'd1;
                                        code_raddr_n =
                                            15'(ops_base + ip + 16'd1);
                                        hp_cmd_n = HP_SPLICE;
                                        hp_v64_n = 1'b1;
                                        hp_from_stack_n = 1'b0;
                                        hp_aid_n = receiver[11:0];
                                        hp_aslot_n = st[6:0] + cnt[6:0];
                                        hp_alen_n = al;
                                        hp_lim_n = {1'b0, cnt};
                                        hp_ret_n = S_FETCH_WAIT;
                                        state_n = S_HEAP_WAIT;
                                    end else begin
                                        vst_wr(base, V64_UNDEFINED);
                                        vsp_n = base + 12'd1;
                                        ip_n = ip + 16'd1;
                                        code_raddr_n =
                                            15'(ops_base + ip + 16'd1);
                                        state_n = S_FETCH_WAIT;
                                    end
                                end else if (arr_ok &&
                                           opw[23:8] == id_join) begin
                                    // arr.join('') — maze wall-shape switch.
                                    jn_arr_n = receiver[11:0];
                                    jn_i_n = 16'd0; jn_h_n = 16'd0;
                                    jn_res_n = 11'(base);
                                    v64_join_n = 1'b1;
                                    cc_bok_n = 1'b1; txt_bn_n = 7'd0;
                                    vst_wr(base, V64_UNDEFINED);
                                    vsp_n = base + 12'd1;
                                    ip_n = ip + 16'd1;
                                    state_n = S_JOIN;
                                end else if (arr_ok &&
                                           opw[23:8] == id_indexof) begin
                                    begin
                                        logic [7:0] al;
                                        al = varr_len_rdata;
                                        ip_n = ip + 16'd1;
                                        code_raddr_n =
                                            15'(ops_base + ip + 16'd1);
                                        hp_vbase_n = base;
                                        if (al == 8'd0) begin
                                            vst_wr(base, v64_int32_number(-32'sd1));
                                            vsp_n = base + 12'd1;
                                            state_n = S_FETCH_WAIT;
                                        end else begin
                                            hp_cmd_n = HP_AGETI;
                                            hp_v64_n = 1'b1;
                                            hp_aid_n = receiver[11:0];
                                            hp_aslot_n = 7'd0;
                                            hp_alen_n = al;
                                            hp_wval_n = (argc != 0)
                                                ? `VST_AT(base + 12'd1)
                                                : V64_UNDEFINED;
                                            hp_ret_n = S_V64_IDXSCAN;
                                            state_n = S_HEAP_WAIT;
                                        end
                                    end
                                end else if (opw[23:8] == id_indexof &&
                                    ((receiver[63:48] == V64_TAG_PREFIX &&
                                      receiver[47:44] == 4'd4 &&
                                      receiver[31:0] < 32'd1024) ||
                                     (receiver[63:48] == V64_TAG_PREFIX &&
                                      receiver[47:44] == V64_KIND_OBJECT &&
                                      receiver[31:0] < MAX_OBJ &&
                                      vobj_builtin_rdata == 4'd7)))
                                begin
                                    // PYTHON String.indexOf — ToString(needle)
                                    // (`JSON.stringify(data).indexOf(0)`).
                                    begin
                                        logic [7:0] needle_b;
                                        logic [15:0] hay_off, hay_len;
                                        logic intern_hay;
                                        needle_b = 8'h00;
                                        if (argc != 0 &&
                                            v64_is_number(`VST_AT(base + 12'd1)))
                                            needle_b = 8'h30 +
                                                v64_to_uint32(`VST_AT(base + 12'd1))[7:0];
                                        else if (argc != 0 &&
                                                 `VST_AT(base + 12'd1)[63:48] ==
                                                     V64_TAG_PREFIX &&
                                                 `VST_AT(base + 12'd1)[47:44] ==
                                                     4'd4 &&
                                                 `VST_AT(base + 12'd1)[31:0] <
                                                     32'd1024)
                                            needle_b =
                                                name_hash_rdata[7:0];
                                        intern_hay = (receiver[47:44] == 4'd4);
                                        ip_n = ip + 16'd1;
                                        code_raddr_n =
                                            15'(ops_base + ip + 16'd1);
                                        hp_vbase_n = base;
                                        hp_key_n = {8'd0, needle_b};
                                        hp_wval_n = {56'd0, needle_b};
                                        if (intern_hay) begin
                                            // Sequential: S_NAMCPY then S_IDXSTR.
                                            // Combo for(k) on name_mem is Synth 8-3391
                                            // (16 ports, 32 KB — will not infer BRAM).
                                            hay_off = name_off_rdata;
                                            hay_len = {8'd0, name_blen_rdata[7:0]};
                                            if (hay_len == 16'd0) begin
                                                vst_wr(base, v64_int32_number(-32'sd1));
                                                vsp_n = base + 12'd1;
                                                state_n = S_FETCH_WAIT;
                                            end else begin
                                                name_rdaddr_n = hay_off;
                                                json_src_n = 14'd0;
                                                json_srclen_n = hay_len[13:0];
                                                json_rp_n = 14'd0;
                                                json_wp_n = 14'd0;
                                                hp_v64_n = 1'b1;
                                                hp_nat_n = 4'd3;
                                                namcpy_repl_n = 1'b0;
                                                namcpy_v64_n = 1'b0;
                                                namcpy_armed_n = 1'b0;
                                                state_n = S_NAMCPY;
                                            end
                                        end else begin
                                            hp_cmd_n = HP_OGETI;
                                            hp_v64_n = 1'b1;
                                            hp_oid_n = receiver[12:0];
                                            hp_slot_n = 5'd0;
                                            hp_qn_n = 3'd2;
                                            hp_qi_n = 3'd0;
                                            hp_nat_n = 4'd3;
                                            hp_phase_n = 3'd0;
                                            hp_ret_n = S_V64_OGETI_NAT;
                                            state_n = S_HEAP_WAIT;
                                        end
                                    end
                                end else if (opw[23:8] == id_replace &&
                                           argc >= 12'd2 &&
                                    ((receiver[63:48] == V64_TAG_PREFIX &&
                                      receiver[47:44] == 4'd4 &&
                                      receiver[31:0] < 32'd1024) ||
                                     (receiver[63:48] == V64_TAG_PREFIX &&
                                      receiver[47:44] == V64_KIND_OBJECT &&
                                      receiver[31:0] < MAX_OBJ &&
                                      vobj_builtin_rdata == 4'd7)))
                                begin
                                    // PYTHON String.replace — dynstr or interned
                                    // haystack, packed RegExp or digit pattern.
                                    begin
                                        logic [63:0] pat, replv;
                                        logic intern_hay;
                                        pat = `VST_AT(base + 12'd1);
                                        replv = `VST_AT(base + 12'd2);
                                        intern_hay = (receiver[47:44] == 4'd4);
                                        if (!hash2_q) begin
                                            // Beat 1: rdata is pat. Arm replv for next clock.
                                            vnat_base_n = base;
                                            v64_repl_n = 1'b1;
                                            repl_g_n = 1'b0;
                                            repl_nlen_n = 8'd1;
                                            repl_pat1_n = 8'd0;
                                            repl_did_n = 1'b0;
                                            if (pat[63:48] == V64_TAG_PREFIX &&
                                                pat[47:44] == 4'd4 &&
                                                pat[31:0] < 32'd1024)
                                                // 1-char interned names hash
                                                // to their byte; blen_rdata
                                                // now carries the RECEIVER's
                                                // length so it cannot gate
                                                // the pattern any more.
                                                repl_pat0_n = name_hash_rdata[7:0];
                                            else if (v64_is_number(pat))
                                                repl_pat0_n = 8'h30 +
                                                    v64_to_uint32(pat)[7:0];
                                            else
                                                repl_pat0_n = 8'd0;
                                            hash2_n = 1'b1;
                                            opnd_n = 1'b1;
                                            state_n = S_V64_EXEC;
                                        end else if (!opnd2_q) begin
                                            // Beat 2: raddr now points at
                                            // the REPLACEMENT (opnd_q=1);
                                            // its rdata lands next beat.
                                            // Consuming here read the
                                            // PATTERN's row — a regex
                                            // object pattern gave a junk
                                            // char ('c' became '0').
                                            hash2_n = 1'b1;
                                            opnd_n = 1'b1;
                                            opnd2_n = 1'b1;
                                            state_n = S_V64_EXEC;
                                        end else begin
                                        vnat_base_n = base;
                                        v64_repl_n = 1'b1;
                                        repl_g_n = 1'b0;
                                        repl_nlen_n = 8'd1;
                                        repl_pat1_n = 8'd0;
                                        repl_did_n = 1'b0;
                                        if (replv[63:48] == V64_TAG_PREFIX &&
                                            replv[47:44] == 4'd4 &&
                                            replv[31:0] < 32'd1024)
                                            // blen_rdata carries the
                                            // RECEIVER's length here — do
                                            // not gate the replacement on
                                            // it. 1-char interns hash to
                                            // their byte; multi-char takes
                                            // hash[7:0] (same limitation
                                            // as patterns).
                                            repl_rch_n = name_hash_rdata[7:0];
                                        else if (v64_is_number(replv))
                                            repl_rch_n = 8'h30 +
                                                v64_to_uint32(replv)[7:0];
                                        else
                                            repl_rch_n = 8'h30;
                                        ip_n = ip + 16'd1;
                                        if (pat[63:48] == V64_TAG_PREFIX &&
                                            pat[47:44] == V64_KIND_OBJECT &&
                                            pat[31:0] < MAX_OBJ) begin
                                            // Any object-typed pattern: the
                                            // exec cannot settle a builtin
                                            // read on the pattern here (the
                                            // rdata is the RECEIVER's), so
                                            // route every object pattern
                                            // through the parent's nat=5
                                            // slot-0 read. In practice only
                                            // RegExp objects are passed as
                                            // patterns; a non-regex object
                                            // reads garbage chars and simply
                                            // never matches.
                                            hp_cmd_n = HP_OGETI;
                                            hp_v64_n = 1'b1;
                                            hp_oid_n = pat[12:0];
                                            hp_slot_n = 5'd0;
                                            hp_qn_n = 3'd1;
                                            hp_qi_n = 3'd0;
                                            hp_nat_n = 4'd5;
                                            hp_phase_n = intern_hay ? 3'd0 : 3'd1;
                                            hp_si_n = receiver[12:0];
                                            hp_ret_n = S_V64_OGETI_NAT;
                                            if (intern_hay) begin
                                                json_src_n = 14'd0;
                                                json_srclen_n =
                                                    {6'd0, name_blen_rdata[7:0]};
                                                json_rp_n = 14'd0;
                                                name_rdaddr_n =
                                                    name_off_rdata;
                                                json_wp_n = 14'd0;
                                                namcpy_repl_n = 1'b1;
                                                namcpy_v64_n = 1'b0;
                                                namcpy_armed_n = 1'b0;
                                            end
                                            state_n = S_HEAP_WAIT;
                                        end else if (!intern_hay) begin
                                            hp_cmd_n = HP_OGETI;
                                            hp_v64_n = 1'b1;
                                            hp_oid_n = receiver[12:0];
                                            hp_slot_n = 5'd0;
                                            hp_qn_n = 3'd2;
                                            hp_qi_n = 3'd0;
                                            hp_nat_n = 4'd4;
                                            hp_ret_n = S_V64_OGETI_NAT;
                                            state_n = S_HEAP_WAIT;
                                        end else begin
                                            json_src_n = 14'd0;
                                            json_srclen_n =
                                                {6'd0, name_blen_rdata[7:0]};
                                            json_rp_n = 14'd0;
                                            name_rdaddr_n =
                                                name_off_rdata;
                                            json_wp_n = 14'd0;
                                            namcpy_repl_n = 1'b1;
                                            namcpy_v64_n = 1'b0;
                                            namcpy_armed_n = 1'b0;
                                            state_n = S_NAMCPY;
                                        end
                                        end
                                    end
                                end else if (opw[23:8] == id_beginpath ||
                                           opw[23:8] == id_closepath) begin
                                    if (opw[23:8] == id_beginpath)
                                        pc_n_n = 5'd0;
                                    path_kind_n = 2'd0;
                                    vst_wr(base, V64_UNDEFINED);
                                    vsp_n = base + 12'd1;
                                    ip_n = ip + 16'd1;
                                    code_raddr_n =
                                        15'(ops_base + ip + 16'd1);
                                    state_n = S_FETCH_WAIT;
                                end else if (opw[23:8] == id_arc &&
                                           argc >= 12'd3) begin
                                    if (pc_n < 5'(PATH_MAX)) begin
                                        pc_we = 1'b1;
                                        pc_waddr = pc_n[3:0];
                                        pc_op_wdata = 2'd3;
                                        pc_a1_wdata =
                                            v64_to_fx(`VST_AT(base + 12'd1));
                                        pc_a2_wdata =
                                            v64_to_fx(`VST_AT(base + 12'd2));
                                        pc_a3_wdata =
                                            v64_to_fx(`VST_AT(base + 12'd3));
                                        pc_a4_wdata = (argc > 12'd3)
                                            ? v64_to_fx(`VST_AT(base + 12'd4))
                                            : 32'sd0;
                                        pc_a5_wdata = (argc > 12'd4)
                                            ? v64_to_fx(`VST_AT(base + 12'd5))
                                            : 32'sd0;
                                        pc_ccw_wdata = (argc > 12'd5)
                                            && v64_truthy(`VST_AT(base + 12'd6));
                                        pc_n_n = pc_n + 5'd1;
                                    end else
                                        dbg_path_ovf_n = dbg_path_ovf + 16'd1;
                                    vst_wr(base, V64_UNDEFINED);
                                    vsp_n = base + 12'd1;
                                    ip_n = ip + 16'd1;
                                    code_raddr_n =
                                        15'(ops_base + ip + 16'd1);
                                    state_n = S_FETCH_WAIT;
                                end else if ((opw[23:8] == id_moveto ||
                                            opw[23:8] == id_lineto) &&
                                           argc >= 12'd2) begin
                                    if (pc_n < 5'(PATH_MAX)) begin
                                        pc_we = 1'b1;
                                        pc_waddr = pc_n[3:0];
                                        pc_op_wdata =
                                            (opw[23:8] == id_moveto)
                                            ? 2'd0 : 2'd1;
                                        pc_a1_wdata =
                                            v64_to_fx(`VST_AT(base + 12'd1));
                                        pc_a2_wdata =
                                            v64_to_fx(`VST_AT(base + 12'd2));
                                        pc_n_n = pc_n + 5'd1;
                                    end else
                                        dbg_path_ovf_n = dbg_path_ovf + 16'd1;
                                    vst_wr(base, V64_UNDEFINED);
                                    vsp_n = base + 12'd1;
                                    ip_n = ip + 16'd1;
                                    code_raddr_n =
                                        15'(ops_base + ip + 16'd1);
                                    state_n = S_FETCH_WAIT;
                                end else if (id_quadcurve != 16'hFFFF &&
                                           opw[23:8] == id_quadcurve &&
                                           argc >= 12'd4) begin
                                    // potential-bugs #38: exec32 twin (~4402).
                                    // pc_op 2 = quadratic; parent S_QSEG already
                                    // subdivides it. Only useful once #49 makes
                                    // the parent read this buffer.
                                    if (pc_n < 5'(PATH_MAX)) begin
                                        pc_we = 1'b1;
                                        pc_waddr = pc_n[3:0];
                                        pc_op_wdata = 2'd2;
                                        pc_a1_wdata =
                                            v64_to_fx(`VST_AT(base + 12'd1));
                                        pc_a2_wdata =
                                            v64_to_fx(`VST_AT(base + 12'd2));
                                        pc_a3_wdata =
                                            v64_to_fx(`VST_AT(base + 12'd3));
                                        pc_a4_wdata =
                                            v64_to_fx(`VST_AT(base + 12'd4));
                                        pc_n_n = pc_n + 5'd1;
                                    end else
                                        dbg_path_ovf_n = dbg_path_ovf + 16'd1;
                                    vst_wr(base, V64_UNDEFINED);
                                    vsp_n = base + 12'd1;
                                    ip_n = ip + 16'd1;
                                    code_raddr_n =
                                        15'(ops_base + ip + 16'd1);
                                    state_n = S_FETCH_WAIT;
                                end else if (opw[23:8] == id_fill ||
                                           opw[23:8] == id_stroke) begin
                                    color_n = (opw[23:8] == id_stroke)
                                        ? stroke_style_i : fill_style_i;
                                    path_stroke_n =
                                        (opw[23:8] == id_stroke);
                                    vst_wr(base, V64_UNDEFINED);
                                    vsp_n = base + 12'd1;
                                    ip_n = ip + 16'd1;
                                    pi_n = 5'd0;
                                    path_active_n = 1'b1;
                                    state_n = S_PWALK;
                                end else if (opw[23:8] == id_ael) begin
                                    ev = (argc != 0) ? `VST_AT(base + 1)
                                        : V64_UNDEFINED;
                                    fn = (argc > 1) ? `VST_AT(base + 2)
                                        : V64_UNDEFINED;
                                    if (fn[63:48] != 16'h7ff9 ||
                                        fn[47:44] != 4'd7) begin
                                        machine_fault_n = 1'b1;
                                        fault_code_n = 8'd4;
                                        fault_site_n = 16'd6215;
                                        running_n = 1'b0; state_n = S_DONE;
                                    end else begin
                                        lsv_scan_n = 1'b1;
                                        lsv_op_n = 2'd1;
                                        lsv_ev_n = ev;
                                        lsv_fn_n = fn;
                                        lsv_base_n = base;
                                        lsv_push_n = V64_UNDEFINED;
                                        state_n = S_V64_EXEC;
                                    end
                                end else if (opw[23:8] == id_gettime ||
                                           opw[23:8] == id_now ||
                                           (receiver[63:48] == V64_TAG_PREFIX &&
                                            receiver[47:44] == V64_KIND_OBJECT &&
                                            receiver[31:0] < MAX_OBJ &&
                                            vobj_alloc_rdata == 2'd1 &&
                                            vobj_gen_rdata ==
                                                receiver[43:32] &&
                                            vobj_builtin_rdata == 4'd3 &&
                                            argc == 12'd0)) begin
                                    // Date.getTime / .now — frame clock
                                    // (same mul as native 35 / PYTHON).
                                    // Builtin-3 + argc 0 is intern-miss safe
                                    // (exec32 obj_cls FFFD twin).
                                    begin
                                        logic [63:0] ts;
                                        if (nwm_busy) begin
                                            opnd_n = 1'b1; opnd2_n = 1'b1; opnd3_n = 1'b1;
                                            state_n = S_V64_EXEC;
                                        end else begin
                                        ts = now_v64_q;
                                        vst_wr(base, ts);
                                        vsp_n = base + 12'd1;
                                        ip_n = ip + 16'd1;
                                        code_raddr_n =
                                            15'(ops_base + ip + 16'd1);
                                        state_n = S_FETCH_WAIT;
                                        end
                                    end
                                end else if (opw[23:8] == id_bind &&
                                    receiver[63:48] == V64_TAG_PREFIX &&
                                    receiver[47:44] == V64_KIND_FUNCTION &&
                                    receiver[31:0] < MAX_OBJ &&
                                    vfn_valid_rdata &&
                                    vfn_gen_rdata ==
                                        receiver[43:32]) begin
                                    // PYTHON Function.prototype.bind
                                    valloc_bind_n = 1'b1;
                                    valloc_bind_src_n = receiver[12:0];
                                    valloc_bind_this_n = (argc != 0)
                                        ? `VST_AT(base + 12'd1)
                                        : V64_UNDEFINED;
                                    vnat_base_n = base;
                                    valloc_kind_n = 2'd2;
                                    valloc_i_n = vfn_next;
                                    valloc_retried_n = 1'b0;
                                    state_n = S_V64_ALLOC;
                                end else if (receiver[63:48] == V64_TAG_PREFIX &&
                                           (receiver[47:44] == V64_KIND_OBJECT ||
                                            receiver[47:44] == V64_KIND_ELEMENT) &&
                                           receiver[31:0] < MAX_OBJ) begin
                                    if (!cm_done && !cmc_hit) begin
                                        cm_scan_n = 1'b1;
                                        cm_armed_n = 1'b0;
                                        cm_done_n = 1'b0;
                                        cm_c_n = 4'd0;
                                        cm_m_n = 4'd0;
                                        cm_mip_n = 16'hFFFF;
                                        cm_key_n = opw[23:8];
                                        cm_cls_n = vobj_cls_rdata;
                                        state_n = S_V64_EXEC;
                                    end else begin
                                    mip = cm_done ? cm_mip : cmc_hit_mip;
                                    cm_done_n = 1'b0;
                                    if (mip != 16'hFFFF) begin
                                        bind_mode_n = 2'd1;
                                        bind_k_n = 8'd0;
                                        bind_n_n = argc;
                                        bind_argc_n = argc;
                                        bind_base_n = base;
                                        bind_src_n = base + 12'd1;
                                        bind_vsp_next_n = vsp - 12'd1;
                                        bind_ret_n = S_V64_ALLOC;
                                        bind_rd_arm_n = 1'b0;
                                        vcall_value_n = 1'b0;
                                        vcall_entry_n = mip;
                                        vcall_argc_n = argc;
                                        vcall_set_this_n = 1'b1;
                                        vcall_this_n = receiver;
                                        vcall_ctor_val_n = V64_UNDEFINED;
                                        valloc_kind_n = 2'd3;
                                        valloc_i_n = venv_next;
                                        valloc_retried_n = 1'b0;
                                        // BIND then kind 3 ALLOC. Reserve like
                                        // CALL_USER or ALLOC writes e64-1 over
                                        // the live constructor/method frame.
                                        vcsp_n = vcsp_hs + 8'd1;
                                        state_n = S_V64_BIND;
                                    end else begin
                                        hp_cmd_n = HP_LOOKFN;
                                        hp_v64_n = 1'b1;
                                        hp_oid_n = receiver[12:0];
                                        hp_key_n = opw[23:8];
                                        hp_len_n = vobj_len_rdata;
                                        hp_slot_n = 5'd0;
                                        hp_phase_n = 3'd0;
                                        hp_proto_n = vobj_proto_rdata;
                                        hp_hit_n = 1'b0;
                                        hp_ret_n = S_V64_METH;
                                        hp_spr_w_n = {4'd0, receiver[43:32]};
                                        vnat_base_n = base;
                                        vcall_argc_n = argc;
                                        vcall_this_n = receiver;
                                        state_n = S_HEAP_WAIT;
                                    end
                                    end
                                end else begin
                                    vst_wr(base, V64_UNDEFINED);
                                    vsp_n = base + 12'd1;
                                    ip_n = ip + 16'd1;
                                    code_raddr_n =
                                        15'(ops_base + ip + 16'd1);
                                    state_n = S_FETCH_WAIT;
                                end
                            end
                            OP_ADD, OP_SUB, OP_MUL: begin
                                if (vsp < 12'd2) begin
                                    machine_fault_n = 1'b1; fault_code_n = 8'd1; fault_site_n = 16'd6381;
                                    running_n = 1'b0; state_n = S_DONE;
                                end else if (opw[7:0] == OP_ADD &&
                                    ((`VST_AT(vsp - 12'd2)[63:48] == V64_TAG_PREFIX &&
                                      `VST_AT(vsp - 12'd2)[47:44] == 4'd4) ||
                                     (`VST_AT(vsp - 12'd1)[63:48] == V64_TAG_PREFIX &&
                                      `VST_AT(vsp - 12'd1)[47:44] == 4'd4))) begin
                                    // PYTHON: string + ToString(other). Reuse
                                    // tagged S_CONCAT intern find-or-alloc.
                                    cc_av_n = (`VST_AT(vsp - 12'd2)[63:48] ==
                                              V64_TAG_PREFIX &&
                                              `VST_AT(vsp - 12'd2)[47:44] == 4'd4)
                                        ? $signed({16'd0, `VST_AT(vsp - 12'd2)[15:0]})
                                        : $signed(v64_to_uint32(`VST_AT(vsp - 12'd2)));
                                    cc_at_n = (`VST_AT(vsp - 12'd2)[63:48] ==
                                              V64_TAG_PREFIX &&
                                              `VST_AT(vsp - 12'd2)[47:44] == 4'd4)
                                        ? 3'd3 : 3'd0;
                                    cc_bv_n = (`VST_AT(vsp - 12'd1)[63:48] ==
                                              V64_TAG_PREFIX &&
                                              `VST_AT(vsp - 12'd1)[47:44] == 4'd4)
                                        ? $signed({16'd0, `VST_AT(vsp - 12'd1)[15:0]})
                                        : $signed(v64_to_uint32(`VST_AT(vsp - 12'd1)));
                                    cc_bt_n = (`VST_AT(vsp - 12'd1)[63:48] ==
                                              V64_TAG_PREFIX &&
                                              `VST_AT(vsp - 12'd1)[47:44] == 4'd4)
                                        ? 3'd3 : 3'd0;
                                    cc_second_n = 1'b0; cc_st_n = 2'd0;
                                    cc_h_n = 16'd0; cc_len_n = 8'd0; cc_d_n = 4'd0;
                                    cc_bok_n = 1'b1; txt_bn_n = 7'd0;
                                    v64_concat_n = 1'b1;
                                    jn_res_n = 11'(vsp - 12'd2);
                                    vsp_n = vsp - 12'd1;
                                    ip_n = ip + 16'd1;
                                    code_raddr_n =
                                        15'(ops_base + ip + 16'd1);
                                    state_n = S_CONCAT;
                                end else begin
                                    // PYTHON ToNumber: non-Number → +0
                                    // (`timestamp - previous` on first rAF).
                                    logic [63:0] aa, bb, arithmetic_result;
                                    aa = v64_is_number(`VST_AT(vsp - 12'd2))
                                        ? `VST_AT(vsp - 12'd2) : 64'd0;
                                    bb = v64_is_number(`VST_AT(vsp - 12'd1))
                                        ? `VST_AT(vsp - 12'd1) : 64'd0;
                                    if (opw[7:0] == OP_ADD ||
                                        opw[7:0] == OP_SUB) begin
                                        if (opw[7:0] == OP_ADD)
                                            v64_add_task(aa, bb, arithmetic_result);
                                        else
                                            v64_add_task(aa,
                                                         {~bb[63], bb[62:0]},
                                                         arithmetic_result);
                                        vst_wr(vsp - 12'd2, arithmetic_result);
                                        vsp_n = vsp - 12'd1;
                                        ip_n = ip + 16'd1;
                                        code_raddr_n = 15'(ops_base + ip + 16'd1);
                                        state_n = S_FETCH_WAIT;
                                    end else begin
                                        // OP_MUL: specials resolve comb and
                                        // complete now; the general product
                                        // runs 53 beats in the fpm engine
                                        // (exec holds via fpm_req).
                                        logic msign;
                                        logic [10:0] mea, meb;
                                        msign = aa[63] ^ bb[63];
                                        mea = aa[62:52]; meb = bb[62:52];
                                        if ((mea == 11'h7ff && aa[51:0] != 0) ||
                                            (meb == 11'h7ff && bb[51:0] != 0) ||
                                            ((mea == 11'h7ff || meb == 11'h7ff) &&
                                             (aa[62:0] == 0 || bb[62:0] == 0))) begin
                                            arithmetic_result = V64_CANON_NAN;
                                            vst_wr(vsp - 12'd2, arithmetic_result);
                                            vsp_n = vsp - 12'd1;
                                            ip_n = ip + 16'd1;
                                            code_raddr_n = 15'(ops_base + ip + 16'd1);
                                            state_n = S_FETCH_WAIT;
                                        end else if (mea == 11'h7ff || meb == 11'h7ff) begin
                                            arithmetic_result = {msign, 11'h7ff, 52'd0};
                                            vst_wr(vsp - 12'd2, arithmetic_result);
                                            vsp_n = vsp - 12'd1;
                                            ip_n = ip + 16'd1;
                                            code_raddr_n = 15'(ops_base + ip + 16'd1);
                                            state_n = S_FETCH_WAIT;
                                        end else if (aa[62:0] == 0 || bb[62:0] == 0) begin
                                            arithmetic_result = {msign, 63'd0};
                                            vst_wr(vsp - 12'd2, arithmetic_result);
                                            vsp_n = vsp - 12'd1;
                                            ip_n = ip + 16'd1;
                                            code_raddr_n = 15'(ops_base + ip + 16'd1);
                                            state_n = S_FETCH_WAIT;
                                        end else begin
                                            fpm_sign_n = msign;
                                            fpm_ea_n = mea;
                                            fpm_eb_n = meb;
                                            fpm_ma_n = {(mea != 11'd0), aa[51:0]};
                                            fpm_mb_n = {(meb != 11'd0), bb[51:0]};
                                            fpm_start_n = 1'b1;
                                            fpm_req_n = 1'b1;
                                            state_n = S_V64_EXEC;
                                        end
                                    end
                                end
                            end
                            OP_DIV: begin
                                if (vsp < 12'd2) begin
                                    machine_fault_n = 1'b1; fault_code_n = 8'd1; fault_site_n = 16'd6443;
                                    running_n = 1'b0; state_n = S_DONE;
                                end else begin
                                    // PYTHON ToNumber: non-Number → +0.
                                    logic [63:0] aa, bb, immediate_result;
                                    logic [52:0] ma, mb, na, nb;
                                    logic [5:0] sha, shb;
                                    logic immediate;
                                    aa = v64_is_number(`VST_AT(vsp - 12'd2))
                                        ? `VST_AT(vsp - 12'd2) : 64'd0;
                                    bb = v64_is_number(`VST_AT(vsp - 12'd1))
                                        ? `VST_AT(vsp - 12'd1) : 64'd0;
                                    immediate = 1'b1;
                                    immediate_result = V64_CANON_NAN;
                                    if ((aa[62:52] == 11'h7ff && aa[51:0] != 0) ||
                                        (bb[62:52] == 11'h7ff && bb[51:0] != 0) ||
                                        ((aa[62:0] == 0 && bb[62:0] == 0)) ||
                                        (aa[62:52] == 11'h7ff &&
                                         bb[62:52] == 11'h7ff)) begin
                                        immediate_result = V64_CANON_NAN;
                                    end else if (aa[62:52] == 11'h7ff ||
                                                 bb[62:0] == 0) begin
                                        immediate_result =
                                            {aa[63] ^ bb[63], 11'h7ff, 52'd0};
                                    end else if (aa[62:0] == 0 ||
                                                 bb[62:52] == 11'h7ff) begin
                                        immediate_result =
                                            {aa[63] ^ bb[63], 63'd0};
                                    end else if (bb[51:0] == 52'd0 &&
                                                 aa[62:52] != 11'd0 &&
                                                 bb[62:52] != 11'd0) begin
                                        // 1-cycle / 2^k (tagged OP_DIV /2 twin).
                                        // INVADERS bunker hitAt is cell/2 per
                                        // brick × invaders × bunkers; 107-cycle
                                        // restoring DIV made the laser crawl.
                                        begin
                                            logic signed [12:0] rexp;
                                            rexp = $signed({2'b0, aa[62:52]})
                                                 - $signed({2'b0, bb[62:52]})
                                                 + 13'sd1023;
                                            if (rexp <= 0)
                                                immediate_result =
                                                    {aa[63] ^ bb[63], 63'd0};
                                            else if (rexp >= 13'sd2047)
                                                immediate_result =
                                                    {aa[63] ^ bb[63], 11'h7ff,
                                                     52'd0};
                                            else
                                                immediate_result =
                                                    {aa[63] ^ bb[63],
                                                     rexp[10:0], aa[51:0]};
                                        end
                                    end else begin
                                        immediate = 1'b0;
                                        ma = {(aa[62:52] != 0), aa[51:0]};
                                        mb = {(bb[62:52] != 0), bb[51:0]};
                                        sha = v64_norm_shift(ma);
                                        shb = v64_norm_shift(mb);
                                        na = ma << sha;
                                        nb = mb << shb;
                                        vdiv_num_n = {na, 54'd0};
                                        vdiv_den_n = nb;
                                        vdiv_rem_n = 54'd0;
                                        vdiv_quot_n = 107'd0;
                                        vdiv_count_n = 8'd107;
                                        vdiv_exp_n =
                                            v64_unbiased_exp(aa[62:52], sha)
                                          - v64_unbiased_exp(bb[62:52], shb);
                                        vdiv_sign_n = aa[63] ^ bb[63];
                                        dbg_div_n_n = dbg_div_n + 16'd1;
                                    end
                                    if (immediate) begin
                                        vst_wr(vsp - 12'd2, immediate_result);
                                        vsp_n = vsp - 12'd1;
                                        ip_n = ip + 16'd1;
                                        code_raddr_n = 15'(ops_base + ip + 16'd1);
                                        state_n = S_FETCH_WAIT;
                                    end else begin
                                        state_n = S_V64_DIV;
                                    end
                                end
                            end
                            OP_MOD: begin
                                if (vsp < 12'd2) begin
                                    machine_fault_n = 1'b1; fault_code_n = 8'd1; fault_site_n = 16'd6527;
                                    running_n = 1'b0; state_n = S_DONE;
                                end else begin
                                    logic [63:0] aa, bb, immediate_result;
                                    logic [52:0] ma, mb, na, nb, initial_rem;
                                    logic [5:0] sha, shb;
                                    logic signed [12:0] ea, eb;
                                    logic immediate;
                                    integer distance;
                                    // PYTHON ToNumber: non-Number → +0
                                    // (`this.times % 2` when GET_PROP misses).
                                    aa = v64_is_number(`VST_AT(vsp - 12'd2))
                                        ? `VST_AT(vsp - 12'd2) : 64'd0;
                                    bb = v64_is_number(`VST_AT(vsp - 12'd1))
                                        ? `VST_AT(vsp - 12'd1) : 64'd0;
                                    immediate = 1'b1;
                                    immediate_result = V64_CANON_NAN;
                                    if ((aa[62:52] == 11'h7ff && aa[51:0] != 0) ||
                                        (bb[62:52] == 11'h7ff && bb[51:0] != 0) ||
                                        aa[62:52] == 11'h7ff ||
                                        bb[62:0] == 0) begin
                                        immediate_result = V64_CANON_NAN;
                                    end else if (aa[62:0] == 0 ||
                                                 bb[62:52] == 11'h7ff) begin
                                        immediate_result = aa;
                                    end else begin
                                        ma = {(aa[62:52] != 0), aa[51:0]};
                                        mb = {(bb[62:52] != 0), bb[51:0]};
                                        sha = v64_norm_shift(ma);
                                        shb = v64_norm_shift(mb);
                                        na = ma << sha;
                                        nb = mb << shb;
                                        ea = v64_unbiased_exp(aa[62:52], sha);
                                        eb = v64_unbiased_exp(bb[62:52], shb);
                                        if (ea < eb || (ea == eb && na < nb)) begin
                                            immediate_result = aa;
                                        end else begin
                                            initial_rem = (na >= nb) ? na - nb : na;
                                            distance = ea - eb;
                                            if (distance == 0) begin
                                                v64_mod_pack_task(
                                                    aa[63], eb, initial_rem,
                                                    immediate_result
                                                );
                                            end else begin
                                                immediate = 1'b0;
                                                vmod_rem_n = initial_rem;
                                                vmod_den_n = nb;
                                                vmod_count_n = 12'(distance);
                                                vmod_exp_n = eb;
                                                vmod_sign_n = aa[63];
                                            end
                                        end
                                    end
                                    if (immediate) begin
                                        vst_wr(vsp - 12'd2, immediate_result);
                                        vsp_n = vsp - 12'd1;
                                        ip_n = ip + 16'd1;
                                        code_raddr_n = 15'(ops_base + ip + 16'd1);
                                        state_n = S_FETCH_WAIT;
                                    end else begin
                                        state_n = S_V64_MOD;
                                    end
                                end
                            end
                            OP_BIT_OR, OP_BIT_AND: begin
                                if (vsp < 12'd2) begin
                                    machine_fault_n = 1'b1; fault_code_n = 8'd1; fault_site_n = 16'd6594;
                                    running_n = 1'b0; state_n = S_DONE;
                                end else begin
                                    logic [31:0] left_int, right_int, bit_result;
                                    // ToInt32: BOOL true|false, not a Number-only fault
                                    left_int = v64_to_int32(`VST_AT(vsp - 12'd2));
                                    right_int = v64_to_int32(`VST_AT(vsp - 12'd1));
                                    bit_result = (opw[7:0] == OP_BIT_OR)
                                               ? left_int | right_int
                                               : left_int & right_int;
                                    vst_wr(vsp - 12'd2, v64_int32_number(bit_result));
                                    vsp_n = vsp - 12'd1;
                                    ip_n = ip + 16'd1;
                                    code_raddr_n = 15'(ops_base + ip + 16'd1);
                                    state_n = S_FETCH_WAIT;
                                end
                            end
                            OP_LT, OP_GT, OP_EQ: begin
                                if (vsp < 12'd2) begin
                                    machine_fault_n = 1'b1; fault_code_n = 8'd1; fault_site_n = 16'd6613;
                                    running_n = 1'b0; state_n = S_DONE;
                                end else begin
                                    logic [63:0] aa, bb;
                                    // PYTHON ToNumber: non-Number → +0 for LT/GT
                                    // (`this.jumpHeight >= 750` before first jump).
                                    // EQ keeps identity (PYTHON does not ToNumber).
                                    aa = (opw[7:0] != OP_EQ &&
                                          !v64_is_number(`VST_AT(vsp - 12'd2)))
                                        ? 64'd0 : `VST_AT(vsp - 12'd2);
                                    bb = (opw[7:0] != OP_EQ &&
                                          !v64_is_number(`VST_AT(vsp - 12'd1)))
                                        ? 64'd0 : `VST_AT(vsp - 12'd1);
                                    vst_wr(vsp - 12'd2, {16'h7ff9, 4'd3, 12'd0, 31'd0,
                                         (opw[7:0] == OP_EQ)
                                         ? v64_equal(aa, bb)
                                         : (opw[7:0] == OP_LT)
                                         ? v64_less(aa, bb)
                                         : v64_less(bb, aa)});
                                    vsp_n = vsp - 12'd1;
                                    ip_n = ip + 16'd1;
                                    code_raddr_n = 15'(ops_base + ip + 16'd1);
                                    state_n = S_FETCH_WAIT;
                                end
                            end
                            OP_JUMP: begin
                                if (opw[23:8] > n_ops) begin
                                    machine_fault_n = 1'b1; fault_code_n = 8'd5; fault_site_n = 16'd6640;
                                    running_n = 1'b0; state_n = S_DONE;
                                end else begin
                                    ip_n = opw[23:8];
                                    code_raddr_n = 15'(ops_base + opw[23:8]);
                                    state_n = S_FETCH_WAIT;
                                end
                            end
                            OP_JIF: begin
                                if (vsp == 0) begin
                                    machine_fault_n = 1'b1; fault_code_n = 8'd1; fault_site_n = 16'd6650;
                                    running_n = 1'b0; state_n = S_DONE;
                                end else if (opw[23:8] > n_ops) begin
                                    machine_fault_n = 1'b1; fault_code_n = 8'd5; fault_site_n = 16'd6653;
                                    running_n = 1'b0; state_n = S_DONE;
                                end else begin
                                    vsp_n = vsp - 12'd1;
                                    if (!v64_truthy(`VST_AT(vsp - 12'd1))) begin
                                        ip_n = opw[23:8];
                                        code_raddr_n = 15'(ops_base + opw[23:8]);
                                    end else begin
                                        ip_n = ip + 16'd1;
                                        code_raddr_n = 15'(ops_base + ip + 16'd1);
                                    end
                                    state_n = S_FETCH_WAIT;
                                end
                            end
                            OP_POP: begin
                                if (vsp == 0) begin
                                    machine_fault_n = 1'b1; fault_code_n = 8'd1; fault_site_n = 16'd6669;
                                    running_n = 1'b0; state_n = S_DONE;
                                end else begin
                                    vsp_n = vsp - 12'd1;
                                    ip_n = ip + 16'd1;
                                    code_raddr_n = 15'(ops_base + ip + 16'd1);
                                    state_n = S_FETCH_WAIT;
                                end
                            end
                            OP_DUP: begin
                                if (vsp == 0 || vsp >= 12'(STACK_DEPTH)) begin
                                    machine_fault_n = 1'b1; fault_code_n = 8'd1; fault_site_n = 16'd6680;
                                    running_n = 1'b0; state_n = S_DONE;
                                end else begin
                                    vst_wr(vsp, `VST_AT(vsp - 12'd1));
                                    vsp_n = vsp + 12'd1;
                                    ip_n = ip + 16'd1;
                                    code_raddr_n = 15'(ops_base + ip + 16'd1);
                                    state_n = S_FETCH_WAIT;
                                end
                            end
                            OP_NEG, OP_NOT: begin
                                if (vsp == 0) begin
                                    machine_fault_n = 1'b1; fault_code_n = 8'd1; fault_site_n = 16'd6692;
                                    running_n = 1'b0; state_n = S_DONE;
                                end else if (opw[7:0] == OP_NEG &&
                                             !v64_is_number(`VST_AT(vsp - 12'd1))) begin
                                    machine_fault_n = 1'b1; fault_code_n = 8'd5; fault_site_n = 16'd6696;
                                    running_n = 1'b0; state_n = S_DONE;
                                end else begin
                                    if (opw[7:0] == OP_NEG)
                                        vst_wr(vsp - 12'd1, (`VST_AT(vsp - 12'd1)[62:52] == 11'h7ff &&
                                             `VST_AT(vsp - 12'd1)[51:0] != 0)
                                            ? V64_CANON_NAN
                                            : {~`VST_AT(vsp - 12'd1)[63],
                                               `VST_AT(vsp - 12'd1)[62:0]});
                                    else
                                        vst_wr(vsp - 12'd1, {16'h7ff9, 4'd3, 12'd0, 31'd0,
                                             !v64_truthy(`VST_AT(vsp - 12'd1))});
                                    ip_n = ip + 16'd1;
                                    code_raddr_n = 15'(ops_base + ip + 16'd1);
                                    state_n = S_FETCH_WAIT;
                                end
                            end
                            // OP_RETURN (14): V1 wall — the compiler has
                            // never emitted it (programs end at ip>=n_ops /
                            // RET_VAL); a stale .JSB carrying it now faults 5.
                            default: begin
                                machine_fault_n = 1'b1;
                                fault_code_n = 8'd5;
                                fault_site_n = 16'd6709;
                                running_n = 1'b0;
                                state_n = S_DONE;
                            end
                        endcase
                    end
        end
        // Parent name SRAM clear: one index/clock while p_clr walks (enable=0).
        // Trail poke 17/40 is consumed in the parent from p_we (not this combo).
        if (clr_busy && (clr_i < 12'd1024)) begin
            name_blen_we = 1'b1;
            name_blen_waddr = clr_i[9:0];
            name_blen_wdata = 16'd0;
            name_hash_we = 1'b1;
            name_hash_waddr = clr_i[9:0];
            name_hash_wdata = 16'd0;
            name_has_we = 1'b1;
            name_has_waddr = clr_i[9:0];
            name_has_wdata = 1'b0;
        end

        /* ===== run-59 piece 1: central S_FETCH_WAIT skip =====
           Every op-end funnels through state_n = S_FETCH_WAIT; this one
           stanza retires the wait beat when — and only when —
           (a) the op ended inside EXEC (parent between-op work like
               dc_arm / boot_clr / hp_env-clear happens only after parent
               flows, which end in parent states and never match here),
           (b) the site asked for exactly the address the port has been
               prefetching since EXEC entry (any branch, ctor jump,
               WIN_FILL detour, or parent redirect differs -> real wait),
           (c) the incoming opcode is in the fast-path class, and
           (d) no vvars write (this beat's comb intent OR last beat's
               in-flight _q) collides with an incoming LOAD_VAR read.
           The capture pulse rolls opw_q to the new word at this edge. */
        opw_cap_n = 1'b0;
`ifdef JMR_PF_SKIP
        begin
            logic [14:0] pf_addr;
            /* The prefetch address as the BRAM actually sees it THIS beat:
               the parent's handover (hs_code at dispatch) is visible via
               the hs mask one beat before our mirror latches it — without
               looking through the mask, single-beat ops (the whole fast
               path) compared a stale code_raddr and the skip never fired
               (caught by a digit-identical fclk on the first live test). */
            pf_addr = hs_m_code ? p_code_raddr : code_raddr;
            pf_addr_s = pf_addr;
            dbg_pfa_c = (state == S_V64_EXEC && state_n == S_FETCH_WAIT) &&
                        ip_n == 16'(ip + 16'd1) &&
                        (code_raddr == 15'(ops_base + ip_n));
            dbg_pfb_c = dbg_pfa_c && post_parent_q; // blocked-by-oneshot count
            dbg_pfc_c = dbg_pfa_c && vfe_mode == 2'd0 &&
                        !((code_rdata[7:0] == OP_LOAD_VAR) &&
                          ((vvars_we   && vvars_waddr[8:0]   == code_rdata[16:8]) ||
                           (vvars_we_q && vvars_waddr_q[8:0] == code_rdata[16:8])));
        /* (cascade probes, DONKEY in-game: pfa=170k op-ends, pfb=0 —
           most single-beat ops end via a common tail that never touches
           code_raddr_n, so equality against the prefetch could never
           hold. Sequentiality is checked on ip_n directly; the port is
           checked against the handover; an op that deliberately
           redirects the code port with ip_n==ip+1 is excluded by the
           code_raddr_n clause.) */
        if (state == S_V64_EXEC && state_n == S_FETCH_WAIT &&
            opw[7:0] != OP_LET_VAR && // ctor_after_let keys on LET_VAR ends:
                                      // its redirect rides the fetch path we
                                      // bypass (pflip=10 forensics: the skip
                                      // FROM the post-ctor LET_VAR faulted;
                                      // every provenance scheme was blind to
                                      // it). Prologue-only cost.
            !post_parent_q &&
            !p_pf_block && vfe_mode == 2'd0 &&
            opnd_q && opnd2_q &&
            ip_n == 16'(ip + 16'd1) &&
            ip_n < n_ops &&  // never skip past end-of-script (the ip>=n_ops
                             // end check lives in the fetch path we bypass)
            code_raddr == 15'(ops_base + ip_n) &&
            pf_safe(code_rdata[7:0]) &&
            !((code_rdata[7:0] == OP_LOAD_VAR) &&
              ((vvars_we   && vvars_waddr[8:0]   == code_rdata[16:8]) ||
               (vvars_we_q && vvars_waddr_q[8:0] == code_rdata[16:8])))) begin
            state_n = S_V64_EXEC;
            code_raddr_n = 15'(ops_base + ip_n + 16'd1); // next prefetch
            opw_cap_n = 1'b1;
            /* land at warmup beat 2: beat-1's raddr clocking happened via
               the decode comb on the incoming word during our execute
               beats; the operand rdata regs need one settle beat. This
               retires the lh + fetch beats: 4-beat ops become 2. */
            opnd_n = 1'b1;
            opnd2_n = 1'b0;
            opnd3_n = 1'b0;
            /* NOTE: do NOT clear vst_we_n here (first attempt did, and
               erased the finishing op's own push — LET_VAR then stored 0:
               the VARPEEK trace). Beat-1's hygiene clears LEFTOVER intent
               at op START; at op END the write must land via _q on the
               settle beat, and beat-2's own vst_we_n=0 prevents re-apply. */
            /* Boundary services the parent's S_FETCH_WAIT arm performs
               (found by A/B: DONKEY never armed rAF with skips on):
               vprom_done retires at every instruction boundary — sticky,
               it re-spins the promote/push exactly as the 6254 comment's
               INVADERS-after-Space hang describes. Perform it here. */
            vprom_done_n = 1'b0;
        end
        end
`endif
    end
    `undef VST_AT
    `undef VST_REL
endmodule
