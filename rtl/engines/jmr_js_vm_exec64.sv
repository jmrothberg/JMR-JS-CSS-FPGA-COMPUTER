// Hierarchical opcode/native decoder. Same clk as jmr_js_vm.
// Enable when state==S_V64_EXEC. Case text from the parent always_ff.
import jmr_js_vm_pkg::*;
import jmr_value_pkg::*;
module jmr_js_vm_exec64 (
    input  logic clk,
    input  logic enable,
    input  logic aset_win_retried,
    input  logic [7:0] bind_argc,
    input  logic [11:0] bind_base,
    input  logic [15:0] bind_ip,
    input  logic [7:0] bind_k,
    input  logic [1:0] bind_mode,
    input  logic [7:0] bind_n,
    input  logic bind_rd_arm,
    input  logic [6:0] bind_ret,
    input  logic [11:0] bind_src,
    input  logic [11:0] bind_vsp_next,
    input  logic [15:0] blit_sh,
    input  logic [7:0] blit_si,
    input  logic [15:0] blit_sw,
    input  logic [15:0] blit_sx,
    input  logic [15:0] blit_sy,
    input  logic [2:0] cc_at,
    input  logic signed [31:0] cc_av,
    input  logic cc_bok,
    input  logic [2:0] cc_bt,
    input  logic signed [31:0] cc_bv,
    input  logic [3:0] cc_d,
    input  logic [15:0] cc_h,
    input  logic [7:0] cc_len,
    input  logic cc_second,
    input  logic [1:0] cc_st,
    input  logic [15:0] cls_mip [0:MAX_CLS-1][0:MAX_CMETH-1],
    input  logic [15:0] cls_mname [0:MAX_CLS-1][0:MAX_CMETH-1],
    input  logic [15:0] cls_name [0:MAX_CLS-1],
    input  logic [4:0] cls_nmeth [0:MAX_CLS-1],
    input  logic [14:0] code_raddr,
    input  logic [31:0] code_rdata,
    input  logic [7:0] color,
    input  logic [1:0] ctx_align,
    input  logic ctx_smooth,
    input  logic signed [31:0] ctx_sx,
    input  logic signed [31:0] ctx_sy,
    input  logic signed [31:0] ctx_tx,
    input  logic signed [31:0] ctx_ty,
    input  logic [15:0] dbg_di_hit,
    input  logic [15:0] dbg_di_miss,
    input  logic [15:0] dbg_div_n,
    input  logic [15:0] dbg_json_ovf,
    input  logic [15:0] dbg_path_ovf,
    input  logic [15:0] dbg_str_ovf,
    input  logic [7:0] fault_code,
    input  logic [18:0] fb_dump_addr,
    input  logic fb_dump_sel,
    input  logic fb_swap,
    input  logic [7:0] fill_lut [0:1023],
    input  logic [7:0] fill_style_i,
    input  logic [11:0] hp_aid,
    input  logic [7:0] hp_alen,
    input  logic [6:0] hp_aslot,
    input  logic [3:0] hp_cmd,
    input  logic [9:0] hp_eid,
    input  logic hp_env,
    input  logic hp_from_stack,
    input  logic hp_hit,
    input  logic [15:0] hp_key,
    input  logic [5:0] hp_len,
    input  logic [7:0] hp_lim,
    input  logic hp_make_arr,
    input  logic [3:0] hp_nat,
    input  logic [12:0] hp_oid,
    input  logic [2:0] hp_phase,
    input  logic [63:0] hp_proto,
    input  logic [2:0] hp_qi,
    input  logic [15:0] hp_qk [0:3],
    input  logic [2:0] hp_qn,
    input  logic [2:0] hp_qt [0:3],
    input  logic [63:0] hp_qv [0:3],
    input  logic [6:0] hp_ret,
    input  logic [63:0] hp_rval,
    input  logic [12:0] hp_si,
    input  logic [4:0] hp_slot,
    input  logic [15:0] hp_spr_h,
    input  logic [15:0] hp_spr_w,
    input  logic [4:0] hp_ss,
    input  logic [2:0] hp_tag,
    input  logic [5:0] hp_tn,
    input  logic hp_v64,
    input  logic [11:0] hp_vbase,
    input  logic [63:0] hp_wval,
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
    input  logic [15:0] id_filltext,
    input  logic [15:0] id_filter,
    input  logic [15:0] id_find,
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
    input  logic [15:0] id_translate,
    input  logic [15:0] id_unshift,
    input  logic [15:0] id_white,
    input  logic [15:0] id_width,
    input  logic imgd_armed,
    input  logic [9:0] imgd_h,
    input  logic [18:0] imgd_i,
    input  logic [18:0] imgd_n,
    input  logic imgd_v64,
    input  logic [9:0] imgd_w,
    input  logic [9:0] imgd_x,
    input  logic [9:0] imgd_x0,
    input  logic [9:0] imgd_y,
    input  logic [9:0] imgd_y0,
    input  logic [15:0] ip,
    input  logic [11:0] jn_arr,
    input  logic [15:0] jn_h,
    input  logic [15:0] jn_i,
    input  logic [10:0] jn_res,
    input  logic [5:0] joy_in,
    input  logic [7:0] js_i [0:JSON_STK-1],
    input  logic [2:0] js_ph [0:JSON_STK-1],
    input  logic [5:0] js_sp,
    input  logic [7:0] json_mem [0:JSON_CAP-1],
    input  logic [2:0] json_pph,
    input  logic [13:0] json_rp,
    input  logic [13:0] json_src,
    input  logic [13:0] json_srclen,
    input  logic [13:0] json_wp,
    input  logic looping,
    input  logic machine_fault,
    input  logic [63:0] minmax_acc,
    input  logic [11:0] minmax_base,
    input  logic minmax_is_min,
    input  logic [7:0] minmax_k,
    input  logic [7:0] minmax_n,
    input  logic [4:0] n_cls,
    input  logic [15:0] n_consts,
    input  logic [15:0] n_ops,
    input  logic [4:0] n_spr,
    input  logic namcpy_armed,
    input  logic namcpy_repl,
    input  logic namcpy_v64,
    input  logic [15:0] name_blen [0:1023],
    input  logic [15:0] name_hash_tbl [0:1023],
    input  logic [7:0] name_len_tbl [0:1023],
    input  logic [7:0] name_mem [0:NAME_CAP-1],
    input  logic [15:0] name_off [0:1023],
    input  logic [15:0] name_rdaddr,
    input  logic [15:0] names_n,
    input  logic [15:0] ops_base,
    input  logic path_active,
    input  logic [1:0] path_kind,
    input  logic path_stroke,
    input  logic signed [31:0] pc_a1 [0:PATH_MAX-1],
    input  logic signed [31:0] pc_a2 [0:PATH_MAX-1],
    input  logic signed [31:0] pc_a3 [0:PATH_MAX-1],
    input  logic signed [31:0] pc_a4 [0:PATH_MAX-1],
    input  logic signed [31:0] pc_a5 [0:PATH_MAX-1],
    input  logic pc_ccw [0:PATH_MAX-1],
    input  logic [4:0] pc_n,
    input  logic [1:0] pc_op [0:PATH_MAX-1],
    input  logic [4:0] pi,
    input  logic repl_did,
    input  logic repl_g,
    input  logic [7:0] repl_nlen,
    input  logic [7:0] repl_pat0,
    input  logic [7:0] repl_pat1,
    input  logic [7:0] repl_rch,
    input  logic [9:0] rh,
    input  logic running,
    input  logic [9:0] rw,
    input  logic [9:0] rx,
    input  logic [9:0] ry,
    input  logic signed [31:0] saved_sx,
    input  logic signed [31:0] saved_sy,
    input  logic signed [31:0] saved_tx,
    input  logic signed [31:0] saved_ty,
    input  logic [10:0] sp,
    input  logic [15:0] spr_hh [0:MAX_SPR-1],
    input  logic [15:0] spr_nid [0:15],
    input  logic [15:0] spr_ww [0:MAX_SPR-1],
    input  logic [4:0] sq_i,
    input  logic [47:0] sq_rad,
    input  logic [25:0] sq_rem,
    input  logic [23:0] sq_root,
    input  logic signed [31:0] stack [0:STACK_DEPTH-1],
    input  logic [6:0] state,
    input  logic this_ok,
    input  logic [6:0] txt_bn,
    input  logic [3:0] txt_ph,
    input  logic signed [15:0] txt_px,
    input  logic signed [15:0] txt_py,
    input  logic [31:0] txt_val,
    input  logic [2:0] txt_vt,
    input  logic v64_concat,
    input  logic v64_join,
    input  logic v64_repl,
    input  logic v64_sqrt,
    input  logic [7:0] valloc_arr_n,
    input  logic valloc_bind,
    input  logic [12:0] valloc_bind_src,
    input  logic [63:0] valloc_bind_this,
    input  logic [7:0] valloc_fn_a1,
    input  logic [15:0] valloc_fn_entry,
    input  logic [13:0] valloc_i,
    input  logic [1:0] valloc_kind,
    input  logic valloc_metrics,
    input  logic valloc_now_fn,
    input  logic valloc_proto,
    input  logic [12:0] valloc_proto_fn,
    input  logic valloc_regex,
    input  logic [31:0] valloc_regex_pack,
    input  logic valloc_retried,
    input  logic [8:0] var_this,
    input  logic [11:0] varr_gen [0:MAX_ARR-1],
    input  logic [7:0] varr_len [0:MAX_ARR-1],
    input  logic [7:0] varr_lidx [0:MAX_ARR-1],
    input  logic varr_long [0:MAX_ARR-1],
    input  logic [13:0] varr_next,
    input  logic varr_valid [0:MAX_ARR-1],
    input  logic [11:0] vcall_argc,
    input  logic [63:0] vcall_ctor_val,
    input  logic [15:0] vcall_entry,
    input  logic vcall_set_this,
    input  logic [63:0] vcall_this,
    input  logic vcall_value,
    input  logic [8:0] vconsole_n,
    input  logic [63:0] vconsts [0:MAX_CONSTS-1],
    input  logic [7:0] vcsp,
    input  logic [7:0] vdiv_count,
    input  logic [52:0] vdiv_den,
    input  logic signed [12:0] vdiv_exp,
    input  logic [106:0] vdiv_num,
    input  logic [106:0] vdiv_quot,
    input  logic [53:0] vdiv_rem,
    input  logic vdiv_sign,
    input  logic [7:0] vdraw_color,
    input  logic [9:0] vdraw_h,
    input  logic [18:0] vdraw_i,
    input  logic [9:0] vdraw_w,
    input  logic [9:0] vdraw_x,
    input  logic [9:0] vdraw_y,
    input  logic [63:0] venv,
    input  logic [11:0] venv_gen [0:ENV_DEPTH-1],
    input  logic [4:0] venv_len [0:ENV_DEPTH-1],
    input  logic [9:0] venv_next,
    input  logic venv_valid [0:ENV_DEPTH-1],
    input  logic [63:0] vfe_arr,
    input  logic [63:0] vfe_arr_s [0:7],
    input  logic [11:0] vfe_base,
    input  logic [11:0] vfe_base_s [0:7],
    input  logic [63:0] vfe_fn,
    input  logic [63:0] vfe_fn_s [0:7],
    input  logic [7:0] vfe_i,
    input  logic [7:0] vfe_i_s [0:7],
    input  logic [63:0] vfe_map,
    input  logic [63:0] vfe_map_s [0:7],
    input  logic [1:0] vfe_mode,
    input  logic [1:0] vfe_mode_s [0:7],
    input  logic [15:0] vfe_ret,
    input  logic [15:0] vfe_ret_s [0:7],
    input  logic [3:0] vfe_sp,
    input  logic [15:0] vfn_entry [0:MAX_OBJ-1],
    input  logic [63:0] vfn_env [0:MAX_OBJ-1],
    input  logic [2:0] vfn_flags [0:MAX_OBJ-1],
    input  logic [11:0] vfn_gen [0:MAX_OBJ-1],
    input  logic [13:0] vfn_next,
    input  logic [5:0] vfn_nparam [0:MAX_OBJ-1],
    input  logic [63:0] vfn_proto [0:MAX_OBJ-1],
    input  logic vfn_valid [0:MAX_OBJ-1],
    input  logic [11:0] vframe_base_sp [0:CSTK-1],
    input  logic [63:0] vframe_ctor [0:CSTK-1],
    input  logic [63:0] vframe_env [0:CSTK-1],
    input  logic vframe_escaped [0:CSTK-1],
    input  logic [63:0] vframe_fn [0:CSTK-1],
    input  logic [31:0] vframe_no,
    input  logic [15:0] vframe_return_ip [0:CSTK-1],
    input  logic [63:0] vframe_this [0:CSTK-1],
    input  logic vfree_armed,
    input  logic vfree_arr_long,
    input  logic vfree_ok,
    input  logic [13:0] vgc_clear_i,
    input  logic vgc_halt_after,
    input  logic [13:0] vgc_qr,
    input  logic [13:0] vgc_qw,
    input  logic [1:0] vgc_resume,
    input  logic vgc_wait_after,
    input  logic vjs_rd_arm,
    input  logic [63:0] vjs_val [0:JSON_STK-1],
    input  logic [63:0] vlistener_ev [0:15],
    input  logic [63:0] vlistener_fn [0:15],
    input  logic [4:0] vlistener_n,
    input  logic vlong_used [0:MAX_ARR_LONG-1],
    input  logic [63:0] vmetrics,
    input  logic [15:0] vmetrics_w,
    input  logic [11:0] vmod_count,
    input  logic [52:0] vmod_den,
    input  logic signed [12:0] vmod_exp,
    input  logic [52:0] vmod_rem,
    input  logic vmod_sign,
    input  logic [11:0] vnat_base,
    input  logic [2:0] vnat_dom,
    input  logic [1:0] vobj_alloc [0:MAX_OBJ-1],
    input  logic [3:0] vobj_builtin [0:MAX_OBJ-1],
    input  logic [15:0] vobj_cls [0:MAX_OBJ-1],
    input  logic [11:0] vobj_gen [0:MAX_OBJ-1],
    input  logic [5:0] vobj_len [0:MAX_OBJ-1],
    input  logic [13:0] vobj_next,
    input  logic [63:0] vobj_proto [0:MAX_OBJ-1],
    input  logic vprom_copy,
    input  logic vprom_done,
    input  logic [6:0] vprom_ret,
    input  logic [63:0] vraf [0:7],
    input  logic [3:0] vraf_n,
    input  logic [31:0] vrng,
    input  logic [11:0] vsp,
    input  logic vst_hold_win,
    input  logic vst_refill_arm,
    input  logic [3:0] vst_refill_i,
    input  logic [6:0] vst_refill_ret,
    input  logic [11:0] vst_waddr,
    input  logic [63:0] vst_wdata,
    input  logic vst_we,
    input  logic [63:0] vst_win [0:15],
    input  logic [63:0] vst_peek [0:15],
    input  logic [63:0] vthis,
    input  logic signed [31:0] vtimer_due [0:63],
    input  logic [63:0] vtimer_fn [0:63],
    input  logic signed [31:0] vtimer_id [0:63],
    input  logic [6:0] vtimer_n,
    input  logic signed [63:0] vtimer_period [0:63],
    input  logic [31:0] vtimer_seq,
    input  logic vtimer_valid [0:63],
    input  logic vvar_valid [0:MAX_VARS-1],
    input  logic [63:0] vvars [0:MAX_VARS-1],
    input  logic [9:0] x,
    input  logic [9:0] y,
    output logic aset_win_retried_n,
    output logic [7:0] bind_argc_n,
    output logic [11:0] bind_base_n,
    output logic [15:0] bind_ip_n,
    output logic [7:0] bind_k_n,
    output logic [1:0] bind_mode_n,
    output logic [7:0] bind_n_n,
    output logic bind_rd_arm_n,
    output logic [6:0] bind_ret_n,
    output logic [11:0] bind_src_n,
    output logic [11:0] bind_vsp_next_n,
    output logic [15:0] blit_sh_n,
    output logic [7:0] blit_si_n,
    output logic [15:0] blit_sw_n,
    output logic [15:0] blit_sx_n,
    output logic [15:0] blit_sy_n,
    output logic [2:0] cc_at_n,
    output logic signed [31:0] cc_av_n,
    output logic cc_bok_n,
    output logic [2:0] cc_bt_n,
    output logic signed [31:0] cc_bv_n,
    output logic [3:0] cc_d_n,
    output logic [15:0] cc_h_n,
    output logic [7:0] cc_len_n,
    output logic cc_second_n,
    output logic [1:0] cc_st_n,
    output logic [14:0] code_raddr_n,
    output logic [7:0] color_n,
    output logic [1:0] ctx_align_n,
    output logic ctx_smooth_n,
    output logic signed [31:0] ctx_sx_n,
    output logic signed [31:0] ctx_sy_n,
    output logic signed [31:0] ctx_tx_n,
    output logic signed [31:0] ctx_ty_n,
    output logic [15:0] dbg_di_hit_n,
    output logic [15:0] dbg_di_miss_n,
    output logic [15:0] dbg_div_n_n,
    output logic [15:0] dbg_json_ovf_n,
    output logic [15:0] dbg_path_ovf_n,
    output logic [7:0] fault_code_n,
    output logic [18:0] fb_dump_addr_n,
    output logic fb_dump_sel_n,
    output logic fb_swap_n,
    output logic [7:0] fill_style_i_n,
    output logic [11:0] hp_aid_n,
    output logic [7:0] hp_alen_n,
    output logic [6:0] hp_aslot_n,
    output logic [3:0] hp_cmd_n,
    output logic [9:0] hp_eid_n,
    output logic hp_env_n,
    output logic hp_from_stack_n,
    output logic hp_hit_n,
    output logic [15:0] hp_key_n,
    output logic [5:0] hp_len_n,
    output logic [7:0] hp_lim_n,
    output logic hp_make_arr_n,
    output logic [3:0] hp_nat_n,
    output logic [12:0] hp_oid_n,
    output logic [2:0] hp_phase_n,
    output logic [63:0] hp_proto_n,
    output logic [2:0] hp_qi_n,
    output logic [2:0] hp_qn_n,
    output logic [6:0] hp_ret_n,
    output logic [63:0] hp_rval_n,
    output logic [12:0] hp_si_n,
    output logic [4:0] hp_slot_n,
    output logic [15:0] hp_spr_h_n,
    output logic [15:0] hp_spr_w_n,
    output logic [4:0] hp_ss_n,
    output logic [2:0] hp_tag_n,
    output logic [5:0] hp_tn_n,
    output logic hp_v64_n,
    output logic [11:0] hp_vbase_n,
    output logic [63:0] hp_wval_n,
    output logic imgd_armed_n,
    output logic [9:0] imgd_h_n,
    output logic [18:0] imgd_i_n,
    output logic [18:0] imgd_n_n,
    output logic imgd_v64_n,
    output logic [9:0] imgd_w_n,
    output logic [9:0] imgd_x_n,
    output logic [9:0] imgd_x0_n,
    output logic [9:0] imgd_y_n,
    output logic [9:0] imgd_y0_n,
    output logic [15:0] ip_n,
    output logic [11:0] jn_arr_n,
    output logic [15:0] jn_h_n,
    output logic [15:0] jn_i_n,
    output logic [10:0] jn_res_n,
    output logic [5:0] js_sp_n,
    output logic [2:0] json_pph_n,
    output logic [13:0] json_rp_n,
    output logic [13:0] json_src_n,
    output logic [13:0] json_srclen_n,
    output logic [13:0] json_wp_n,
    output logic looping_n,
    output logic machine_fault_n,
    output logic [63:0] minmax_acc_n,
    output logic [11:0] minmax_base_n,
    output logic minmax_is_min_n,
    output logic [7:0] minmax_k_n,
    output logic [7:0] minmax_n_n,
    output logic namcpy_armed_n,
    output logic namcpy_repl_n,
    output logic namcpy_v64_n,
    output logic [15:0] name_rdaddr_n,
    output logic path_active_n,
    output logic [1:0] path_kind_n,
    output logic path_stroke_n,
    output logic [4:0] pc_n_n,
    output logic [4:0] pi_n,
    output logic repl_did_n,
    output logic repl_g_n,
    output logic [7:0] repl_nlen_n,
    output logic [7:0] repl_pat0_n,
    output logic [7:0] repl_pat1_n,
    output logic [7:0] repl_rch_n,
    output logic [9:0] rh_n,
    output logic running_n,
    output logic [9:0] rw_n,
    output logic [9:0] rx_n,
    output logic [9:0] ry_n,
    output logic signed [31:0] saved_sx_n,
    output logic signed [31:0] saved_sy_n,
    output logic signed [31:0] saved_tx_n,
    output logic signed [31:0] saved_ty_n,
    output logic [4:0] sq_i_n,
    output logic [47:0] sq_rad_n,
    output logic [25:0] sq_rem_n,
    output logic [23:0] sq_root_n,
    output logic [6:0] state_n,
    output logic [6:0] txt_bn_n,
    output logic [3:0] txt_ph_n,
    output logic signed [15:0] txt_px_n,
    output logic signed [15:0] txt_py_n,
    output logic [31:0] txt_val_n,
    output logic [2:0] txt_vt_n,
    output logic v64_concat_n,
    output logic v64_join_n,
    output logic v64_repl_n,
    output logic v64_sqrt_n,
    output logic [7:0] valloc_arr_n_n,
    output logic valloc_bind_n,
    output logic [12:0] valloc_bind_src_n,
    output logic [63:0] valloc_bind_this_n,
    output logic [7:0] valloc_fn_a1_n,
    output logic [15:0] valloc_fn_entry_n,
    output logic [13:0] valloc_i_n,
    output logic [1:0] valloc_kind_n,
    output logic valloc_metrics_n,
    output logic valloc_now_fn_n,
    output logic valloc_proto_n,
    output logic [12:0] valloc_proto_fn_n,
    output logic valloc_regex_n,
    output logic [31:0] valloc_regex_pack_n,
    output logic valloc_retried_n,
    output logic [13:0] varr_next_n,
    output logic [11:0] vcall_argc_n,
    output logic [63:0] vcall_ctor_val_n,
    output logic [15:0] vcall_entry_n,
    output logic vcall_set_this_n,
    output logic [63:0] vcall_this_n,
    output logic vcall_value_n,
    output logic [8:0] vconsole_n_n,
    output logic [7:0] vcsp_n,
    output logic [7:0] vdiv_count_n,
    output logic [52:0] vdiv_den_n,
    output logic signed [12:0] vdiv_exp_n,
    output logic [106:0] vdiv_num_n,
    output logic [106:0] vdiv_quot_n,
    output logic [53:0] vdiv_rem_n,
    output logic vdiv_sign_n,
    output logic [7:0] vdraw_color_n,
    output logic [9:0] vdraw_h_n,
    output logic [18:0] vdraw_i_n,
    output logic [9:0] vdraw_w_n,
    output logic [9:0] vdraw_x_n,
    output logic [9:0] vdraw_y_n,
    output logic [63:0] venv_n,
    output logic [9:0] venv_next_n,
    output logic [63:0] vfe_arr_n,
    output logic [11:0] vfe_base_n,
    output logic [63:0] vfe_fn_n,
    output logic [7:0] vfe_i_n,
    output logic [63:0] vfe_map_n,
    output logic [1:0] vfe_mode_n,
    output logic [15:0] vfe_ret_n,
    output logic [3:0] vfe_sp_n,
    output logic vfree_armed_n,
    output logic vfree_arr_long_n,
    output logic [13:0] vgc_clear_i_n,
    output logic vgc_halt_after_n,
    output logic [13:0] vgc_qr_n,
    output logic [13:0] vgc_qw_n,
    output logic [1:0] vgc_resume_n,
    output logic vgc_wait_after_n,
    output logic vjs_rd_arm_n,
    output logic [4:0] vlistener_n_n,
    output logic [15:0] vmetrics_w_n,
    output logic [11:0] vmod_count_n,
    output logic [52:0] vmod_den_n,
    output logic signed [12:0] vmod_exp_n,
    output logic [52:0] vmod_rem_n,
    output logic vmod_sign_n,
    output logic [11:0] vnat_base_n,
    output logic [2:0] vnat_dom_n,
    output logic vprom_copy_n,
    output logic vprom_done_n,
    output logic [6:0] vprom_ret_n,
    output logic [3:0] vraf_n_n,
    output logic [31:0] vrng_n,
    output logic [11:0] vsp_n,
    output logic vst_hold_win_n,
    output logic vst_refill_arm_n,
    output logic [3:0] vst_refill_i_n,
    output logic [6:0] vst_refill_ret_n,
    output logic [11:0] vst_waddr_n,
    output logic [63:0] vst_wdata_n,
    output logic vst_we_n,
    output logic [63:0] vthis_n,
    output logic [6:0] vtimer_n_n,
    output logic [31:0] vtimer_seq_n,
    output logic [9:0] x_n,
    output logic [9:0] y_n,
    output logic [15:0] hp_qk_n [0:3],
    output logic [2:0] hp_qt_n [0:3],
    output logic [63:0] hp_qv_n [0:3],
    output logic [7:0] js_i_n [0:JSON_STK-1],
    output logic [2:0] js_ph_n [0:JSON_STK-1],
    output logic signed [31:0] pc_a1_n [0:PATH_MAX-1],
    output logic signed [31:0] pc_a2_n [0:PATH_MAX-1],
    output logic signed [31:0] pc_a3_n [0:PATH_MAX-1],
    output logic signed [31:0] pc_a4_n [0:PATH_MAX-1],
    output logic signed [31:0] pc_a5_n [0:PATH_MAX-1],
    output logic pc_ccw_n [0:PATH_MAX-1],
    output logic [1:0] pc_op_n [0:PATH_MAX-1],
    output logic [63:0] vfe_arr_s_n [0:7],
    output logic [11:0] vfe_base_s_n [0:7],
    output logic [63:0] vfe_fn_s_n [0:7],
    output logic [7:0] vfe_i_s_n [0:7],
    output logic [63:0] vfe_map_s_n [0:7],
    output logic [1:0] vfe_mode_s_n [0:7],
    output logic [15:0] vfe_ret_s_n [0:7],
    output logic [11:0] vframe_base_sp_n [0:CSTK-1],
    output logic [63:0] vframe_ctor_n [0:CSTK-1],
    output logic [63:0] vframe_env_n [0:CSTK-1],
    output logic vframe_escaped_n [0:CSTK-1],
    output logic [63:0] vframe_fn_n [0:CSTK-1],
    output logic [15:0] vframe_return_ip_n [0:CSTK-1],
    output logic [63:0] vframe_this_n [0:CSTK-1],
    output logic [63:0] vjs_val_n [0:JSON_STK-1],
    output logic [63:0] vlistener_ev_n [0:15],
    output logic [63:0] vlistener_fn_n [0:15],
    output logic vlong_used_n [0:MAX_ARR_LONG-1],
    output logic [63:0] vraf_arr_n [0:7],
    output logic [63:0] vst_win_n [0:15],
    output logic signed [31:0] vtimer_due_n [0:63],
    output logic [63:0] vtimer_fn_n [0:63],
    output logic signed [31:0] vtimer_id_n [0:63],
    output logic signed [63:0] vtimer_period_n [0:63],
    output logic vtimer_valid_n [0:63],
    output logic json_mem_we,
    output logic [12:0] json_mem_waddr,
    output logic [7:0] json_mem_wdata,
    output logic varr_len_we,
    output logic [11:0] varr_len_waddr,
    output logic [7:0] varr_len_wdata,
    output logic varr_lidx_we,
    output logic [11:0] varr_lidx_waddr,
    output logic [7:0] varr_lidx_wdata,
    output logic varr_long_we,
    output logic [11:0] varr_long_waddr,
    output logic [31:0] varr_long_wdata,
    output logic varr_valid_we,
    output logic [11:0] varr_valid_waddr,
    output logic [31:0] varr_valid_wdata,
    output logic venv_gen_we,
    output logic [11:0] venv_gen_waddr,
    output logic [11:0] venv_gen_wdata,
    output logic venv_len_we,
    output logic [11:0] venv_len_waddr,
    output logic [4:0] venv_len_wdata,
    output logic venv_valid_we,
    output logic [11:0] venv_valid_waddr,
    output logic [31:0] venv_valid_wdata,
    output logic vobj_cls_we,
    output logic [11:0] vobj_cls_waddr,
    output logic [15:0] vobj_cls_wdata,
    output logic vvar_valid_we,
    output logic [11:0] vvar_valid_waddr,
    output logic [31:0] vvar_valid_wdata,
    output logic vvars_we,
    output logic [11:0] vvars_waddr,
    output logic [63:0] vvars_wdata
);

    // Sequential cell so Vivado keep_hierarchy is not dissolved as combo-only.
    logic hier_keep;
    always_ff @(posedge clk) if (enable) hier_keep <= ~hier_keep;

    logic [10:0] eb;
    logic [51:0] fb;
    logic [52:0] mb;
    logic [15:0] q;
    logic sb;
    logic [55:0] sig;
    logic sr;
    logic sticky;
    logic [55:0] xb;
    `define VST_REL(addr) (((((vsp)>(addr)) && (((vsp)-(addr)-12'd1)<12'd16))) ? 4'((vsp)-(addr)-12'd1) : 4'd0)
    `define VST_AT(addr) vst_peek[`VST_REL(addr)]

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
                    sig = xa - xb;
                    if (sig == 0)
                        sr = 1'b0;
                    for (int k = 0; k < 55; k++) begin
                        if (sig[55] == 1'b0 && sig != 0 && er > 1) begin
                            sig = sig << 1;
                            er = er - 1;
                        end
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
    task automatic v64_mul_task(
        input logic [63:0] aa,
        input logic [63:0] bb,
        output logic [63:0] result
    );
        logic sign;
        logic [10:0] ea, eb, ef;
        logic [51:0] fa, fb;
        logic [52:0] ma, mb, q;
        logic [53:0] rounded;
        logic [105:0] product;
        logic guard, sticky;
        integer p, er, shift;
        begin
            sign = aa[63] ^ bb[63];
            ea = aa[62:52]; eb = bb[62:52];
            fa = aa[51:0]; fb = bb[51:0];
            if ((ea == 11'h7ff && fa != 0) ||
                (eb == 11'h7ff && fb != 0) ||
                ((ea == 11'h7ff || eb == 11'h7ff) &&
                 (aa[62:0] == 0 || bb[62:0] == 0))) begin
                result = V64_CANON_NAN;
            end else if (ea == 11'h7ff || eb == 11'h7ff) begin
                result = {sign, 11'h7ff, 52'd0};
            end else if (aa[62:0] == 0 || bb[62:0] == 0) begin
                result = {sign, 63'd0};
            end else begin
                ma = {1'b0, fa};
                mb = {1'b0, fb};
                if (ea != 0) ma[52] = 1'b1;
                if (eb != 0) mb[52] = 1'b1;
                product = 106'(ma) * 106'(mb);
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
                    guard = product[shift - 1];
                    for (int k = 0; k < 106; k++)
                        if (k < shift - 1)
                            sticky = sticky | product[k];
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
                    result = {sign, 11'h7ff, 52'd0};
                else if (ef == 0 && q[52])
                    result = {sign, 11'd1, q[51:0]};
                else if (q == 0)
                    result = {sign, 63'd0};
                else
                    result = {sign, ef, q[51:0]};
            end
        end
    endtask
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

    always_comb begin
        aset_win_retried_n = aset_win_retried;
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
        fb_swap_n = fb_swap;
        fill_style_i_n = fill_style_i;
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
        state_n = state;
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
        venv_n = venv;
        venv_next_n = venv_next;
        vfe_arr_n = vfe_arr;
        vfe_base_n = vfe_base;
        vfe_fn_n = vfe_fn;
        vfe_i_n = vfe_i;
        vfe_map_n = vfe_map;
        vfe_mode_n = vfe_mode;
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
        vsp_n = vsp;
        vst_hold_win_n = vst_hold_win;
        vst_refill_arm_n = vst_refill_arm;
        vst_refill_i_n = vst_refill_i;
        vst_refill_ret_n = vst_refill_ret;
        vst_waddr_n = vst_waddr;
        vst_wdata_n = vst_wdata;
        vst_we_n = vst_we;
        vthis_n = vthis;
        vtimer_n_n = vtimer_n;
        vtimer_seq_n = vtimer_seq;
        x_n = x;
        y_n = y;
        hp_qk_n = hp_qk;
        hp_qt_n = hp_qt;
        hp_qv_n = hp_qv;
        js_i_n = js_i;
        js_ph_n = js_ph;
        pc_a1_n = pc_a1;
        pc_a2_n = pc_a2;
        pc_a3_n = pc_a3;
        pc_a4_n = pc_a4;
        pc_a5_n = pc_a5;
        pc_ccw_n = pc_ccw;
        pc_op_n = pc_op;
        vfe_arr_s_n = vfe_arr_s;
        vfe_base_s_n = vfe_base_s;
        vfe_fn_s_n = vfe_fn_s;
        vfe_i_s_n = vfe_i_s;
        vfe_map_s_n = vfe_map_s;
        vfe_mode_s_n = vfe_mode_s;
        vfe_ret_s_n = vfe_ret_s;
        vframe_base_sp_n = vframe_base_sp;
        vframe_ctor_n = vframe_ctor;
        vframe_env_n = vframe_env;
        vframe_escaped_n = vframe_escaped;
        vframe_fn_n = vframe_fn;
        vframe_return_ip_n = vframe_return_ip;
        vframe_this_n = vframe_this;
        vjs_val_n = vjs_val;
        vlistener_ev_n = vlistener_ev;
        vlistener_fn_n = vlistener_fn;
        vlong_used_n = vlong_used;
        vraf_arr_n = vraf;
        vst_win_n = vst_win;
        vtimer_due_n = vtimer_due;
        vtimer_fn_n = vtimer_fn;
        vtimer_id_n = vtimer_id;
        vtimer_period_n = vtimer_period;
        vtimer_valid_n = vtimer_valid;
        json_mem_we = 1'b0;
        json_mem_waddr = '0;
        json_mem_wdata = '0;
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
        vvars_waddr = '0;
        vvars_wdata = '0;
        if (enable) begin
                    // Small gated scalar island. Every opcode not implemented
                    // here faults with ERROR_UNSUPPORTED; it never falls into
                    // the legacy tagged/Q16 executor.
                    if (ip >= n_ops) begin
                        // PYTHON _execute_value64: falling off n_ops with a
                        // live call frame is an implicit RET_VAL undefined,
                        // not fault 2. Compiler emits RET_VAL at function
                        // ends, but JUMP to n_ops / IIFE-as-script still
                        // lands here (DONKEY vcsp=1, PACMAN vcsp=3).
                        if (vcsp != 0) begin
                            if (vsp != vframe_base_sp[vcsp - 8'd1]) begin
                            machine_fault_n = 1'b1;
                            fault_code_n = 8'd1;
                            running_n = 1'b0;
                            state_n = S_DONE;
                            end else begin
                                // Same leaf-env recycle as OP_RET_VAL.
                                if (!vframe_escaped[vcsp - 8'd1] &&
                                    venv[63:48] == V64_TAG_PREFIX &&
                                    venv[47:44] == V64_KIND_ENV &&
                                    venv[31:0] < ENV_DEPTH &&
                                    venv_valid[venv[9:0]] &&
                                    venv_gen[venv[9:0]] == venv[43:32] &&
                                    venv != vframe_env[vcsp - 8'd1]) begin
                                    begin venv_valid_we = 1'b1; venv_valid_waddr = venv[9:0]; venv_valid_wdata = 1'b0; end
                                    begin venv_len_we = 1'b1; venv_len_waddr = venv[9:0]; venv_len_wdata = 5'd0; end
                                    venv_gen_we = 1'b1; venv_gen_waddr = venv[9:0]; venv_gen_wdata =
                                        (venv_gen[venv[9:0]] == 12'hfff)
                                        ? 12'd1
                                        : (venv_gen[venv[9:0]] + 12'd1);
                                    if (venv_next > venv[9:0])
                                        venv_next_n = venv[9:0];
                                end
                                vthis_n = vframe_this[vcsp - 8'd1];
                                venv_n = vframe_env[vcsp - 8'd1];
                                vcsp_n = vcsp - 8'd1;
                                if (vframe_return_ip[vcsp - 8'd1] ==
                                    16'hffff) begin
                                    vsp_n = vframe_base_sp[vcsp - 8'd1];
                                    state_n = S_V64_FRAME_RAF;
                                end else if (
                                    vframe_return_ip[vcsp - 8'd1] ==
                                    16'hfffe
                                ) begin
                                    vsp_n = vframe_base_sp[vcsp - 8'd1];
                                    state_n = S_V64_FRAME_TIMER;
                                end else if (
                                    vframe_return_ip[vcsp - 8'd1] ==
                                    16'hfffd
                                ) begin
                                    vsp_n = vframe_base_sp[vcsp - 8'd1];
                                    state_n = S_V64_FRAME_KEY;
                                end else if (
                                    vframe_return_ip[vcsp - 8'd1] ==
                                    16'hfffc
                                ) begin
                                    // implicit undefined: find/filter miss;
                                    // map stores undefined.
                                    vsp_n = vframe_base_sp[vcsp - 8'd1];
                                    if (vfe_mode == 2'd2 &&
                                        vfe_map[63:48] == V64_TAG_PREFIX &&
                                        vfe_map[47:44] == V64_KIND_ARRAY &&
                                        varr_valid[vfe_map[11:0]] &&
                                        (vfe_i - 8'd1) <
                                            varr_len[vfe_map[11:0]])
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
                                    vst_wr(vframe_base_sp[vcsp - 8'd1],
                                           V64_UNDEFINED);
                                    vsp_n =
                                        vframe_base_sp[vcsp - 8'd1] + 12'd1;
                                    ip_n = vframe_return_ip[vcsp - 8'd1];
                                    code_raddr_n = 15'(
                                        ops_base +
                                        vframe_return_ip[vcsp - 8'd1]
                                    );
                                    // Same win[1] refill as OP_RET_VAL.
                                    if (vframe_base_sp[vcsp - 8'd1]
                                            >= 12'd1) begin
                                        vst_refill_i_n = 4'd1;
                                        vst_refill_arm_n = 1'b0;
                                        vst_refill_ret_n = S_FETCH_WAIT;
                                        vst_hold_win_n = 1'b1;
                                        vst_win_n[0] = V64_UNDEFINED;
                                        state_n = S_V64_WIN_FILL;
                                    end else
                                    state_n = S_FETCH_WAIT;
                                end
                            end
                        end else if (vsp != 0) begin
                            machine_fault_n = 1'b1;
                            fault_code_n = 8'd1;
                            running_n = 1'b0;
                            state_n = S_DONE;
                        end else begin
                            vgc_clear_i_n = 14'd0;
                            vgc_qr_n = 14'd0;
                            vgc_qw_n = 14'd0;
                            vgc_halt_after_n = 1'b1;
                            vgc_wait_after_n = (vraf_n != 0 || vtimer_n != 0);
                            state_n = S_V64_GC_CLEAR;
                        end
                    end else begin
                        // Plain case: unique made Vivado build every opcode
                        // in parallel (~100 GB, no bitstream). Small unique
                        // cases elsewhere stay.
                        case (code_rdata[7:0])
                            OP_LOAD_CONST: begin
                                if (vsp >= 12'(STACK_DEPTH)) begin
                                    machine_fault_n = 1'b1; fault_code_n = 8'd1;
                                    running_n = 1'b0; state_n = S_DONE;
                                end else if ((code_rdata[31:24] == 8'd0 ||
                                             code_rdata[31:24] == 8'd3) &&
                                             code_rdata[23:8] >= n_consts) begin
                                    machine_fault_n = 1'b1; fault_code_n = 8'd5;
                                    running_n = 1'b0; state_n = S_DONE;
                                end else if (code_rdata[31:24] == 8'd0 ||
                                             code_rdata[31:24] == 8'd3) begin
                                    vst_wr(vsp, (vconsts[code_rdata[17:8]][62:52] == 11'h7ff &&
                                         vconsts[code_rdata[17:8]][51:0] != 0)
                                        ? V64_CANON_NAN
                                        : vconsts[code_rdata[17:8]]);
                                    vsp_n = vsp + 12'd1;
                                    ip_n = ip + 16'd1;
                                    code_raddr_n = 15'(ops_base + ip + 16'd1);
                                    state_n = S_FETCH_WAIT;
                                end else if (code_rdata[31:24] == 8'd1 &&
                                             code_rdata[23:8] < names_n) begin
                                    vst_wr(vsp, v64_handle(
                                        4'd4, 12'd0,
                                        {16'd0, code_rdata[23:8]}
                                    ));
                                    vsp_n = vsp + 12'd1;
                                    ip_n = ip + 16'd1;
                                    code_raddr_n = 15'(ops_base + ip + 16'd1);
                                    state_n = S_FETCH_WAIT;
                                end else if (code_rdata[31:24] == 8'd2) begin
                                    vst_wr(vsp, V64_UNDEFINED);
                                    vsp_n = vsp + 12'd1;
                                    ip_n = ip + 16'd1;
                                    code_raddr_n = 15'(ops_base + ip + 16'd1);
                                    state_n = S_FETCH_WAIT;
                                end else if (code_rdata[31:24] == 8'd4) begin
                                    // RegExp stub — keep packed /pat/g from the
                                    // const pool so String.replace can read it.
                                    valloc_regex_n = 1'b1;
                                    valloc_regex_pack_n =
                                        vconsts[code_rdata[17:8]][31:0];
                                    vnat_base_n = vsp;
                                    valloc_kind_n = 2'd0;
                                    valloc_i_n = vobj_next;
                                    valloc_retried_n = 1'b0;
                                    state_n = S_V64_ALLOC;
                                end else begin
                                    machine_fault_n = 1'b1; fault_code_n = 8'd5;
                                    running_n = 1'b0; state_n = S_DONE;
                                end
                            end
                            OP_LOAD_VAR: begin
                                if (vsp >= 12'(STACK_DEPTH)) begin
                                    machine_fault_n = 1'b1; fault_code_n = 8'd1;
                                    running_n = 1'b0; state_n = S_DONE;
                                end else if (code_rdata[23:17] != 0) begin
                                    machine_fault_n = 1'b1; fault_code_n = 8'd5;
                                    running_n = 1'b0; state_n = S_DONE;
                                end else if (this_ok &&
                                             code_rdata[16:8] == var_this) begin
                                    vst_wr(vsp, vthis);
                                    vsp_n = vsp + 12'd1;
                                    ip_n = ip + 16'd1;
                                    code_raddr_n =
                                        15'(ops_base + ip + 16'd1);
                                    state_n = S_FETCH_WAIT;
                                end else if (venv[63:48] == 16'h7ff9 &&
                                             venv[47:44] == 4'd9) begin
                                    if (venv[31:0] >= ENV_DEPTH ||
                                        !venv_valid[venv[9:0]] ||
                                        venv_gen[venv[9:0]] !=
                                            venv[43:32]) begin
                                        machine_fault_n = 1'b1;
                                        fault_code_n = 8'd4;
                                        running_n = 1'b0;
                                        state_n = S_DONE;
                                    end else begin
                                        hp_env_n = 1'b1;
                                        hp_cmd_n = HP_GETPROP;
                                        hp_v64_n = 1'b1;
                                        hp_eid_n = venv[9:0];
                                        hp_len_n = {1'b0, venv_len[venv[9:0]]};
                                        hp_slot_n = 5'd0;
                                        hp_key_n = {7'd0, code_rdata[16:8]};
                                        hp_phase_n = 3'd0;
                                        hp_hit_n = 1'b0;
                                        hp_ret_n = S_FETCH_WAIT;
                                        state_n = S_HEAP_WAIT;
                                    end
                                end else begin
                                    vst_wr(vsp, vvar_valid[code_rdata[16:8]]
                                            ? vvars[code_rdata[16:8]]
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
                                    machine_fault_n = 1'b1; fault_code_n = 8'd1;
                                    running_n = 1'b0; state_n = S_DONE;
                                end else if (code_rdata[23:17] != 0) begin
                                    machine_fault_n = 1'b1; fault_code_n = 8'd5;
                                    running_n = 1'b0; state_n = S_DONE;
                                end else if (this_ok &&
                                             code_rdata[16:8] == var_this &&
                                             !(code_rdata[7:0] == OP_LET_VAR &&
                                               code_rdata[24])) begin
                                    if (code_rdata[7:0] == OP_STORE_VAR ||
                                        !vvar_valid[code_rdata[16:8]])
                                        vthis_n = `VST_AT(vsp - 12'd1);
                                    vsp_n = vsp - 12'd1;
                                    ip_n = ip + 16'd1;
                                    code_raddr_n =
                                        15'(ops_base + ip + 16'd1);
                                    state_n = S_FETCH_WAIT;
                                end else if (code_rdata[7:0] == OP_LET_VAR &&
                                             code_rdata[24] && vcsp == 0) begin
                                        machine_fault_n = 1'b1;
                                    fault_code_n = 8'd2;
                                        running_n = 1'b0;
                                        state_n = S_DONE;
                                    end else if (code_rdata[7:0] == OP_LET_VAR &&
                                             code_rdata[24] &&
                                             (venv[63:48] != 16'h7ff9 ||
                                            venv[47:44] != 4'd9 ||
                                            venv[31:0] >= ENV_DEPTH ||
                                              !venv_valid[venv[9:0]] ||
                                              venv_gen[venv[9:0]] !=
                                                  venv[43:32])) begin
                                    // Flat IIFE: LET_VAR local with no ENV
                                    // stores the global (PYTHON / JSB a1 bit6).
                                    vvars_we = 1'b1; vvars_waddr = code_rdata[16:8]; vvars_wdata =
                                        `VST_AT(vsp - 12'd1);
                                    begin vvar_valid_we = 1'b1; vvar_valid_waddr = code_rdata[16:8]; vvar_valid_wdata = 1'b1; end
                                    vsp_n = vsp - 12'd1;
                                    ip_n = ip + 16'd1;
                                    code_raddr_n =
                                        15'(ops_base + ip + 16'd1);
                                    state_n = S_FETCH_WAIT;
                                end else if (venv[63:48] == 16'h7ff9 &&
                                             venv[47:44] == 4'd9) begin
                                    if (venv[31:0] >= ENV_DEPTH ||
                                        !venv_valid[venv[9:0]] ||
                                        venv_gen[venv[9:0]] !=
                                                venv[43:32]) begin
                                            machine_fault_n = 1'b1;
                                        fault_code_n = 8'd4;
                                            running_n = 1'b0;
                                            state_n = S_DONE;
                                        end else begin
                                        hp_env_n = 1'b1;
                                        hp_cmd_n = HP_SETPROP;
                                        hp_v64_n = 1'b1;
                                        hp_eid_n = venv[9:0];
                                        hp_len_n = {1'b0, venv_len[venv[9:0]]};
                                        hp_slot_n = 5'd0;
                                        hp_key_n = {7'd0, code_rdata[16:8]};
                                        hp_wval_n = `VST_AT(vsp - 12'd1);
                                        hp_hit_n = 1'b0;
                                        hp_phase_n = (code_rdata[7:0] ==
                                            OP_LET_VAR && code_rdata[24])
                                            ? 3'd2
                                            : (code_rdata[7:0] == OP_LET_VAR)
                                            ? 3'd1 : 3'd0;
                                        hp_ret_n = S_FETCH_WAIT;
                                        state_n = S_HEAP_WAIT;
                                    end
                                            end else begin
                                            if (code_rdata[7:0] == OP_STORE_VAR ||
                                        !vvar_valid[code_rdata[16:8]]) begin
                                            vvars_we = 1'b1; vvars_waddr = code_rdata[16:8]; vvars_wdata =
                                            `VST_AT(vsp - 12'd1);
                                            begin vvar_valid_we = 1'b1; vvar_valid_waddr = code_rdata[16:8]; vvar_valid_wdata = 1'b1; end
                                        end
                                        vsp_n = vsp - 12'd1;
                                        ip_n = ip + 16'd1;
                                        code_raddr_n =
                                            15'(ops_base + ip + 16'd1);
                                        state_n = S_FETCH_WAIT;
                                end
                            end
                            OP_MAKE_ARR: begin
                                if (code_rdata[23:8] > ARR_CAP) begin
                                    machine_fault_n = 1'b1; fault_code_n = 8'd3;
                                    running_n = 1'b0; state_n = S_DONE;
                                end else if (vsp < code_rdata[19:8] ||
                                             (code_rdata[23:8] == 0 &&
                                              vsp >= 12'(STACK_DEPTH))) begin
                                    machine_fault_n = 1'b1; fault_code_n = 8'd1;
                                    running_n = 1'b0; state_n = S_DONE;
                                end else begin
                                    vnat_dom_n = 3'd0;
                                    // Latch length: S_V64_ALLOC must not re-read
                                    // code_rdata (GC resume is thousands of
                                    // clocks later; combo >>8 is not [23:8]).
                                    valloc_arr_n_n = code_rdata[15:8];
                                    valloc_kind_n = 2'd1;
                                    hp_phase_n = 3'd0;
                                    // PYTHON scans from 0 so holes before the
                                    // bump cursor are visible without a GC.
                                    valloc_i_n = (code_rdata[23:8] > 16'(ARR_SHORT_CAP))
                                        ? 14'(MAX_ARR_SHORT)
                                        : 14'd0;
                                    valloc_retried_n = 1'b0;
                                    state_n = S_V64_ALLOC;
                                end
                            end
                            OP_MAKE_OBJ: begin
                                if (vsp >= 12'(STACK_DEPTH)) begin
                                    machine_fault_n = 1'b1; fault_code_n = 8'd1;
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
                                nid = code_rdata[15:8];
                                argc = code_rdata[31:24];
                                base = vsp - argc;
                                result = V64_UNDEFINED;
                                bad_fn = 1'b0;
                                found_slot = 1'b0;
                                free_slot = 7'd0;
                                ms = 32'sd0;
                                frames = 32'sd1;
                                wanted = -32'sd1;
                                if (vsp < argc) begin
                                    machine_fault_n = 1'b1;
                                    fault_code_n = 8'd1;
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
                                                !vfn_valid[`VST_AT(base)[12:0]] ||
                                                vfn_gen[`VST_AT(base)[12:0]] !=
                                                    `VST_AT(base)[43:32];
                                            if (bad_fn) begin
                                                machine_fault_n = 1'b1;
                                                fault_code_n = 8'd4;
                                                running_n = 1'b0;
                                                state_n = S_DONE;
                                            end else if (vraf_n >= 4'd8) begin
                                                machine_fault_n = 1'b1;
                                                fault_code_n = 8'd3;
                                                running_n = 1'b0;
                                                state_n = S_DONE;
                                            end else begin
                                                vraf_arr_n[vraf_n] = `VST_AT(base);
                                                vraf_n_n = vraf_n + 4'd1;
                                                vst_wr(base, result);
                                                vsp_n = base + 12'd1;
                                                ip_n = ip + 16'd1;
                                                code_raddr_n = 15'(ops_base + ip + 16'd1);
                                                state_n = S_FETCH_WAIT;
                                            end
                                        end
                                        8'd28, 8'd29: begin // timeout / interval
                                            bad_fn = argc == 0 ||
                                                `VST_AT(base)[63:48] != 16'h7ff9 ||
                                                `VST_AT(base)[47:44] != 4'd7 ||
                                                `VST_AT(base)[31:0] >= MAX_OBJ ||
                                                !vfn_valid[`VST_AT(base)[12:0]] ||
                                                vfn_gen[`VST_AT(base)[12:0]] !=
                                                    `VST_AT(base)[43:32];
                                            for (int k = 0; k < 64; k++)
                                                if (!found_slot && !vtimer_valid[k]) begin
                                                    found_slot = 1'b1;
                                                    free_slot = 7'(k);
                                                end
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
                                                running_n = 1'b0;
                                                state_n = S_DONE;
                                            end else if (!found_slot || vtimer_n >= 7'd64) begin
                                                machine_fault_n = 1'b1;
                                                fault_code_n = 8'd3;
                                                running_n = 1'b0;
                                                state_n = S_DONE;
                                            end else begin
                                                vtimer_valid_n[free_slot] = 1'b1;
                                                vtimer_due_n[free_slot] =
                                                    $signed(vframe_no) + frames;
                                                vtimer_id_n[free_slot] = $signed(vtimer_seq);
                                                vtimer_period_n[free_slot] =
                                                    (nid == 8'd29) ? 64'(frames) : -64'sd1;
                                                vtimer_fn_n[free_slot] = `VST_AT(base);
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
                                            for (int k = 0; k < 64; k++)
                                                if (vtimer_valid[k] &&
                                                    vtimer_id[k] == wanted) begin
                                                    vtimer_valid_n[k] = 1'b0;
                                                    vtimer_n_n = vtimer_n - 7'd1;
                                                end
                                            vst_wr(base, result);
                                            vsp_n = base + 12'd1;
                                            ip_n = ip + 16'd1;
                                            code_raddr_n = 15'(ops_base + ip + 16'd1);
                                            state_n = S_FETCH_WAIT;
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
                                            logic [4:0] same_n;
                                            logic dup;
                                            ev = (argc != 0) ? `VST_AT(base) : V64_UNDEFINED;
                                            fn = (argc > 1) ? `VST_AT(base + 1) : V64_UNDEFINED;
                                            same_n = 5'd0;
                                            dup = 1'b0;
                                            for (int k = 0; k < 16; k++)
                                                if (k < vlistener_n) begin
                                                    if (v64_equal(vlistener_ev[k], ev) &&
                                                        v64_equal(vlistener_fn[k], fn))
                                                        dup = 1'b1;
                                                    if (v64_equal(vlistener_ev[k], ev))
                                                        same_n = same_n + 5'd1;
                                                end
                                            if (fn[63:48] != 16'h7ff9 ||
                                                fn[47:44] != 4'd7) begin
                                                machine_fault_n = 1'b1;
                                                fault_code_n = 8'd4;
                                                running_n = 1'b0;
                                                state_n = S_DONE;
                                            end else if (!dup && same_n >= 5'd4) begin
                                                machine_fault_n = 1'b1;
                                                fault_code_n = 8'd3;
                                                running_n = 1'b0;
                                                state_n = S_DONE;
                                            end else if (!dup && vlistener_n >= 5'd16) begin
                                                machine_fault_n = 1'b1;
                                                fault_code_n = 8'd3;
                                                running_n = 1'b0;
                                                state_n = S_DONE;
                                            end else begin
                                                if (!dup) begin
                                                    vlistener_ev_n[vlistener_n] = ev;
                                                    vlistener_fn_n[vlistener_n] = fn;
                                                    vlistener_n_n = vlistener_n + 5'd1;
                                                end
                                                vst_wr(base, result);
                                                vsp_n = base + 12'd1;
                                                ip_n = ip + 16'd1;
                                                code_raddr_n =
                                                    15'(ops_base + ip + 16'd1);
                                                state_n = S_FETCH_WAIT;
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
                                                    name_blen[`VST_AT(base)[9:0]][13:0];
                                                json_rp_n = 14'd0;
                                                js_sp_n = 6'd0;
                                                json_pph_n = 3'd0;
                                                vnat_base_n = base;
                                                if (name_blen[`VST_AT(base)[9:0]] == 16'd0) begin
                                                    vst_wr(base, V64_NULL);
                                                    vsp_n = base + 12'd1;
                                                    ip_n = ip + 16'd1;
                                                    code_raddr_n =
                                                        15'(ops_base + ip + 16'd1);
                                                    state_n = S_FETCH_WAIT;
                                                end else begin
                                                    name_rdaddr_n =
                                                        name_off[`VST_AT(base)[9:0]];
                                                    json_wp_n = 14'd0;
                                                    namcpy_repl_n = 1'b0;
                                                    namcpy_v64_n = 1'b1;
                                                    namcpy_armed_n = 1'b0;
                                                    state_n = S_NAMCPY;
                                                end
                                            end else if (`VST_AT(base)[63:48] == V64_TAG_PREFIX &&
                                                       `VST_AT(base)[47:44] == V64_KIND_OBJECT &&
                                                       `VST_AT(base)[31:0] < MAX_OBJ &&
                                                       vobj_alloc[`VST_AT(base)[12:0]] == 2'd1 &&
                                                       vobj_builtin[`VST_AT(base)[12:0]] == 4'd7) begin
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
                                            vjs_val_n[0] = (argc != 0)
                                                ? `VST_AT(base) : V64_UNDEFINED;
                                            js_i_n[0] = 8'd0;
                                            js_ph_n[0] = 3'd0;
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
                                            v64_mul_task(
                                                frame_number,
                                                64'h4030aaaaaaaaaaab,
                                                result
                                            );
                                            vst_wr(base, result);
                                            vsp_n = base + 12'd1;
                                            ip_n = ip + 16'd1;
                                            code_raddr_n = 15'(ops_base + ip + 16'd1);
                                            state_n = S_FETCH_WAIT;
                                        end
                                        8'd36, 8'd37: begin
                                            // PYTHON removeEventListener —
                                            // drop matching (event, fn).
                                            begin
                                                logic [63:0] ev, fn;
                                                logic [63:0] nev [0:15];
                                                logic [63:0] nfn [0:15];
                                                logic [4:0] w;
                                                ev = (argc != 0)
                                                    ? `VST_AT(base) : V64_UNDEFINED;
                                                fn = (argc > 1)
                                                    ? `VST_AT(base + 1)
                                                    : V64_UNDEFINED;
                                                w = 5'd0;
                                                for (int k = 0; k < 16; k++) begin
                                                    nev[k] = V64_UNDEFINED;
                                                    nfn[k] = V64_UNDEFINED;
                                                end
                                                for (int k = 0; k < 16; k++)
                                                    if (k < vlistener_n &&
                                                        !(v64_equal(
                                                              vlistener_ev[k], ev) &&
                                                          v64_equal(
                                                              vlistener_fn[k], fn)))
                                                    begin
                                                        nev[w] = vlistener_ev[k];
                                                        nfn[w] = vlistener_fn[k];
                                                        w = w + 5'd1;
                                                    end
                                                for (int k = 0; k < 16; k++) begin
                                                    vlistener_ev_n[k] = nev[k];
                                                    vlistener_fn_n[k] = nfn[k];
                                                end
                                                vlistener_n_n = w;
                                                vst_wr(base, result);
                                                vsp_n = base + 12'd1;
                                                ip_n = ip + 16'd1;
                                                code_raddr_n =
                                                    15'(ops_base + ip + 16'd1);
                                                state_n = S_FETCH_WAIT;
                                            end
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
                                        default: begin
                                            machine_fault_n = 1'b1;
                                            fault_code_n = 8'd5;
                                            running_n = 1'b0;
                                            state_n = S_DONE;
                                        end
                                    endcase
                                end
                            end
                            OP_MAKE_FN: begin
                                if (vsp >= 12'(STACK_DEPTH)) begin
                                    machine_fault_n = 1'b1; fault_code_n = 8'd1;
                                    running_n = 1'b0; state_n = S_DONE;
                                end else begin
                                    // Latch entry/flags: S_V64_ALLOC must not
                                    // re-read code_rdata (same class as
                                    // valloc_arr_n for OP_MAKE_ARR).
                                    valloc_fn_entry_n = code_rdata[23:8];
                                    valloc_fn_a1_n = code_rdata[31:24];
                                    valloc_kind_n = 2'd2;
                                    valloc_i_n = vfn_next;
                                    valloc_retried_n = 1'b0;
                                    state_n = S_V64_ALLOC;
                                end
                            end
                            OP_CALL_USER: begin
                                if (vcsp >= CSTK) begin
                                    machine_fault_n = 1'b1; fault_code_n = 8'd2;
                                    running_n = 1'b0; state_n = S_DONE;
                                end else if (vsp < code_rdata[31:24]) begin
                                    machine_fault_n = 1'b1; fault_code_n = 8'd1;
                                    running_n = 1'b0; state_n = S_DONE;
                                end else begin
                                    vcall_value_n = 1'b0;
                                    vcall_entry_n = code_rdata[23:8];
                                    vcall_argc_n = code_rdata[31:24];
                                    vcall_set_this_n = 1'b0;
                                    vcall_ctor_val_n = V64_UNDEFINED;
                                    valloc_kind_n = 2'd3;
                                    valloc_i_n = venv_next;
                                    valloc_retried_n = 1'b0;
                                    state_n = S_V64_ALLOC;
                                end
                            end
                            OP_CALL_VAL: begin
                                logic [15:0] argc;
                                logic [63:0] handle;
                                logic iife_flat;
                                logic [11:0] base_sp;
                                logic [7:0] nparam;
                                argc = code_rdata[23:8];
                                handle = (vsp > argc)
                                    ? `VST_AT(vsp - argc - 12'd1)
                                    : V64_UNDEFINED;
                                iife_flat = (handle[63:48] == 16'h7ff9 &&
                                             handle[47:44] == 4'd7 &&
                                             handle[31:0] < MAX_OBJ &&
                                             vfn_valid[handle[12:0]] &&
                                             vfn_gen[handle[12:0]] ==
                                                handle[43:32] &&
                                             vfn_flags[handle[12:0]][1] &&
                                             (vfn_env[handle[12:0]][63:48] !=
                                                V64_TAG_PREFIX ||
                                              vfn_env[handle[12:0]][47:44] !=
                                                V64_KIND_ENV));
                                if (vcsp >= CSTK) begin
                                    machine_fault_n = 1'b1; fault_code_n = 8'd2;
                                    running_n = 1'b0; state_n = S_DONE;
                                end else if (vsp < argc + 16'd1) begin
                                    machine_fault_n = 1'b1; fault_code_n = 8'd1;
                                    running_n = 1'b0; state_n = S_DONE;
                                end else if (handle[63:48] != 16'h7ff9 ||
                                             handle[47:44] != 4'd7 ||
                                             handle[31:0] >= MAX_OBJ ||
                                             !vfn_valid[handle[12:0]] ||
                                             vfn_gen[handle[12:0]] !=
                                                handle[43:32]) begin
                                    machine_fault_n = 1'b1; fault_code_n = 8'd4;
                                    running_n = 1'b0; state_n = S_DONE;
                                end else if (vfn_entry[handle[12:0]] ==
                                           16'hfffa) begin
                                    // Date.now / performance.now native 35.
                                    logic [63:0] now_result;
                                    logic [11:0] now_base;
                                    now_base = vsp - argc - 12'd1;
                                    v64_mul_task(
                                        v64_int32_number(vframe_no),
                                        64'h4030aaaaaaaaaaab,
                                        now_result
                                    );
                                    vst_wr(now_base, now_result);
                                    vsp_n = now_base + 12'd1;
                                    ip_n = ip + 16'd1;
                                    code_raddr_n =
                                        15'(ops_base + ip + 16'd1);
                                    state_n = S_FETCH_WAIT;
                                end else if (iife_flat) begin
                                    // JSB MAKE_FN a1 bit6: top-level IIFE is
                                    // a flat call (no ENV). Same ProgramImage
                                    // as PYTHON Value64.
                                    base_sp = vsp - argc - 12'd1;
                                    nparam = {2'd0, vfn_nparam[handle[12:0]]};
                                    vframe_return_ip_n[vcsp] = ip + 16'd1;
                                    vframe_base_sp_n[vcsp] = base_sp;
                                    vframe_this_n[vcsp] = vthis;
                                    vframe_env_n[vcsp] = venv;
                                    vframe_fn_n[vcsp] = handle;
                                    vframe_ctor_n[vcsp] = V64_UNDEFINED;
                                    vframe_escaped_n[vcsp] = 1'b0;
                                    vcsp_n = vcsp + 8'd1;
                                    vthis_n = V64_UNDEFINED;
                                    bind_mode_n = 2'd0;
                                    bind_k_n = 8'd0;
                                    bind_n_n = nparam;
                                    bind_argc_n = argc;
                                    bind_base_n = base_sp;
                                    bind_src_n = vsp - argc;
                                    bind_vsp_next_n = base_sp + nparam;
                                    bind_ip_n = vfn_entry[handle[12:0]];
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
                                    state_n = S_V64_ALLOC;
                                end
                            end
                            OP_RET_VAL: begin
                                if (vsp == 0) begin
                                    machine_fault_n = 1'b1; fault_code_n = 8'd1;
                                    running_n = 1'b0; state_n = S_DONE;
                                end else if (vcsp == 0) begin
                                    machine_fault_n = 1'b1; fault_code_n = 8'd2;
                                    running_n = 1'b0; state_n = S_DONE;
                                end else begin
                                    // PYTHON pops result then checks sp==base.
                                    // Keep the top as the return value so one
                                    // extra (ctx.fillText in a method) still
                                    // returns; writeback below uses `VST_AT(vsp-1).
                                    // Leaf CALL_USER (palK/drawPix) must recycle
                                    // the env here — waiting for GC fills
                                    // ENV_DEPTH and burns ~10M clocks/paint.
                                    if (!vframe_escaped[vcsp - 8'd1] &&
                                        venv[63:48] == V64_TAG_PREFIX &&
                                        venv[47:44] == V64_KIND_ENV &&
                                        venv[31:0] < ENV_DEPTH &&
                                        venv_valid[venv[9:0]] &&
                                        venv_gen[venv[9:0]] == venv[43:32] &&
                                        venv != vframe_env[vcsp - 8'd1]) begin
                                        begin venv_valid_we = 1'b1; venv_valid_waddr = venv[9:0]; venv_valid_wdata = 1'b0; end
                                        begin venv_len_we = 1'b1; venv_len_waddr = venv[9:0]; venv_len_wdata = 5'd0; end
                                        venv_gen_we = 1'b1; venv_gen_waddr = venv[9:0]; venv_gen_wdata =
                                            (venv_gen[venv[9:0]] == 12'hfff)
                                            ? 12'd1
                                            : (venv_gen[venv[9:0]] + 12'd1);
                                        if (venv_next > venv[9:0])
                                            venv_next_n = venv[9:0];
                                    end
                                    vthis_n = vframe_this[vcsp - 8'd1];
                                    venv_n = vframe_env[vcsp - 8'd1];
                                    vcsp_n = vcsp - 8'd1;
                                    if (vframe_return_ip[vcsp - 8'd1] ==
                                        16'hffff) begin
                                        vsp_n = vframe_base_sp[vcsp - 8'd1];
                                        state_n = S_V64_FRAME_RAF;
                                    end else if (
                                        vframe_return_ip[vcsp - 8'd1] ==
                                        16'hfffe
                                    ) begin
                                        vsp_n = vframe_base_sp[vcsp - 8'd1];
                                        state_n = S_V64_FRAME_TIMER;
                                    end else if (
                                        vframe_return_ip[vcsp - 8'd1] ==
                                        16'hfffd
                                    ) begin
                                        vsp_n = vframe_base_sp[vcsp - 8'd1];
                                        state_n = S_V64_FRAME_KEY;
                                    end else if (
                                        vframe_return_ip[vcsp - 8'd1] ==
                                        16'hfffc
                                    ) begin
                                        // Array.find: truthy callback → that
                                        // element (vfe_i already advanced).
                                        if (vfe_mode == 2'd1 &&
                                            v64_truthy(`VST_AT(vsp - 12'd1)))
                                        begin
                                            hp_cmd_n = HP_AGETI;
                                            hp_v64_n = 1'b1;
                                            hp_aid_n = vfe_arr[11:0];
                                            hp_aslot_n = 7'(vfe_i - 8'd1);
                                            hp_alen_n = varr_len[vfe_arr[11:0]];
                                            hp_ret_n = S_V64_FE_ELEM;
                                            state_n = S_HEAP_WAIT;
                                    end else begin
                                            // map stores callback result;
                                            // filter keeps the source element.
                                            vsp_n =
                                                vframe_base_sp[vcsp - 8'd1];
                                            if (vfe_mode == 2'd2 &&
                                                vfe_map[63:48] == V64_TAG_PREFIX &&
                                                vfe_map[47:44] == V64_KIND_ARRAY &&
                                                varr_valid[vfe_map[11:0]] &&
                                                (vfe_i - 8'd1) <
                                                    varr_len[vfe_map[11:0]])
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
                                                     varr_valid[vfe_map[11:0]])
                                            begin
                                                hp_cmd_n = HP_AGETI;
                                                hp_v64_n = 1'b1;
                                                hp_aid_n = vfe_arr[11:0];
                                                hp_aslot_n = 7'(vfe_i - 8'd1);
                                                hp_alen_n = varr_len[vfe_arr[11:0]];
                                                hp_ret_n = S_V64_FE_FILTER;
                                                state_n = S_HEAP_WAIT;
                                            end else
                                                state_n = S_V64_FOREACH;
                                        end
                                    end else begin
                                        // PYTHON RET_VAL: constructor frames
                                        // yield the instance, not undefined.
                                        vst_wr(vframe_base_sp[vcsp - 8'd1], (vframe_ctor[vcsp - 8'd1][63:48] ==
                                             V64_TAG_PREFIX &&
                                             vframe_ctor[vcsp - 8'd1][47:44] ==
                                             V64_KIND_OBJECT)
                                            ? vframe_ctor[vcsp - 8'd1]
                                            : `VST_AT(vsp - 12'd1));
                                        vsp_n =
                                            vframe_base_sp[vcsp - 8'd1] + 12'd1;
                                        ip_n = vframe_return_ip[vcsp - 8'd1];
                                        code_raddr_n = 15'(
                                            ops_base +
                                            vframe_return_ip[vcsp - 8'd1]
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
                                        if (vframe_base_sp[vcsp - 8'd1]
                                                >= 12'd1) begin
                                            vst_refill_i_n = 4'd1;
                                            vst_refill_arm_n = 1'b0;
                                            vst_refill_ret_n = S_FETCH_WAIT;
                                            vst_hold_win_n = 1'b1;
                                            vst_win_n[0] = (vframe_ctor[vcsp - 8'd1][63:48] ==
                                                 V64_TAG_PREFIX &&
                                                 vframe_ctor[vcsp - 8'd1][47:44] ==
                                                 V64_KIND_OBJECT)
                                                ? vframe_ctor[vcsp - 8'd1]
                                                : `VST_AT(vsp - 12'd1);
                                            state_n = S_V64_WIN_FILL;
                                        end else
                                        state_n = S_FETCH_WAIT;
                                    end
                                end
                            end
                            OP_ARR_GET: begin
                                if (vsp < 12'd2) begin
                                    machine_fault_n = 1'b1; fault_code_n = 8'd1;
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
                                        end else if (array_index < 0 ||
                                            array_index >=
                                                {17'd0, name_blen[handle[9:0]]}) begin
                                            vst_wr(vsp - 12'd2, V64_UNDEFINED);
                                            vsp_n = vsp - 12'd1;
                                            ip_n = ip + 16'd1;
                                            code_raddr_n =
                                                15'(ops_base + ip + 16'd1);
                                            state_n = S_FETCH_WAIT;
                                        end else begin
                                            name_rdaddr_n =
                                                name_off[handle[9:0]] +
                                                16'(array_index);
                                            vsp_n = vsp - 12'd1;
                                            ip_n = ip + 16'd1;
                                            state_n = S_V64_STRIDX;
                                        end
                                    end else if (handle[63:48] == 16'h7ff9 &&
                                        (handle[47:44] == V64_KIND_OBJECT ||
                                         handle[47:44] == V64_KIND_ELEMENT) &&
                                        handle[31:0] < MAX_OBJ &&
                                        vobj_alloc[handle[12:0]] == 2'd1 &&
                                        vobj_gen[handle[12:0]] == handle[43:32])
                                    begin
                                        // PYTHON: obj[computed] uses interned
                                        // keys (`_events[eventType]`).
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
                                                hp_len_n = vobj_len[handle[12:0]];
                                                hp_slot_n = 5'd0;
                                                hp_phase_n = 3'd1;
                                                hp_proto_n = V64_UNDEFINED;
                                                state_n = S_HEAP_WAIT;
                                            end
                                        end
                                    end else if (handle[63:48] != 16'h7ff9 ||
                                        handle[47:44] != 4'd6 ||
                                        handle[31:0] >= MAX_ARR ||
                                        !varr_valid[handle[11:0]] ||
                                        varr_gen[handle[11:0]] != handle[43:32]) begin
                                        // JS: Number[index] is undefined, not a type fault.
                                        vst_wr(vsp - 12'd2, V64_UNDEFINED);
                                        vsp_n = vsp - 12'd1;
                                        ip_n = ip + 16'd1;
                                        code_raddr_n = 15'(ops_base + ip + 16'd1);
                                        state_n = S_FETCH_WAIT;
                                    end else if (!index_valid ||
                                                 array_index < 0 ||
                                                 array_index >=
                                                    {25'd0, varr_len[handle[11:0]]})
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
                                        hp_alen_n = varr_len[handle[11:0]];
                                        state_n = S_HEAP_WAIT;
                                    end
                                end
                            end
                            OP_ARR_SET: begin
                                if (vsp < 12'd3) begin
                                    machine_fault_n = 1'b1; fault_code_n = 8'd1;
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
                                        handle[31:0] < MAX_OBJ &&
                                        vobj_alloc[handle[12:0]] == 2'd1 &&
                                        vobj_gen[handle[12:0]] == handle[43:32])
                                    begin
                                        // PYTHON: obj[computed]=value interned
                                        // keys (`_events[eventType] = {}`).
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
                                                hp_len_n = vobj_len[handle[12:0]];
                                                hp_slot_n = 5'd0;
                                                hp_phase_n = 3'd0;
                                                state_n = S_HEAP_WAIT;
                                            end
                                        end
                                    end else if (handle[63:48] != 16'h7ff9 ||
                                        handle[47:44] != 4'd6 ||
                                        handle[31:0] >= MAX_ARR ||
                                        !varr_valid[handle[11:0]] ||
                                        varr_gen[handle[11:0]] != handle[43:32]) begin
                                        // PYTHON: primitive[index]= is a no-op.
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
                                    end else if (!varr_long[handle[11:0]] &&
                                                 array_index >= ARR_SHORT_CAP &&
                                                 !vprom_done) begin
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
                                        if (array_index > varr_len[handle[11:0]])
                                        begin
                                            hp_aslot_n = varr_len[handle[11:0]][6:0];
                                            hp_lim_n = array_index[7:0];
                                            hp_wval_n = V64_UNDEFINED;
                                            varr_len_we = 1'b1; varr_len_waddr = handle[11:0]; varr_len_wdata =
                                                array_index[7:0] + 8'd1;
                                            state_n = S_HEAP_FILL;
                                        end else begin
                                            if (array_index >=
                                                    varr_len[handle[11:0]])
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
                                    machine_fault_n = 1'b1; fault_code_n = 8'd1;
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
                                        varr_valid[handle[11:0]] &&
                                        varr_gen[handle[11:0]] == handle[43:32]) begin
                                        if (code_rdata[23:8] == id_length)
                                            result = v64_int32_number(
                                                {24'd0, varr_len[handle[11:0]]}
                                            );
                                        vst_wr(vsp - 12'd1, result);
                                        ip_n = ip + 16'd1;
                                        code_raddr_n =
                                            15'(ops_base + ip + 16'd1);
                                        state_n = S_FETCH_WAIT;
                                    end else if (handle[63:48] == 16'h7ff9 &&
                                                 handle[47:44] == 4'd4 &&
                                                 handle[31:0] < 32'd1024) begin
                                        if (code_rdata[23:8] == id_now) begin
                                            // PYTHON: Date.now / performance.now
                                            // on the interned constructor name.
                                            valloc_now_fn_n = 1'b1;
                                            vnat_base_n = vsp - 12'd1;
                                            valloc_kind_n = 2'd2;
                                            valloc_i_n = vfn_next;
                                            valloc_retried_n = 1'b0;
                                            state_n = S_V64_ALLOC;
                                        end else begin
                                            if (code_rdata[23:8] == id_length)
                                                result = v64_int32_number(
                                                    {16'd0, name_blen[handle[9:0]]}
                                                );
                                            vst_wr(vsp - 12'd1, result);
                                            ip_n = ip + 16'd1;
                                            code_raddr_n =
                                                15'(ops_base + ip + 16'd1);
                                            state_n = S_FETCH_WAIT;
                                        end
                                    end else if (handle[63:48] == 16'h7ff9 &&
                                                 handle[47:44] == 4'd7 &&
                                                 handle[31:0] < MAX_OBJ &&
                                                 vfn_valid[handle[12:0]] &&
                                                 vfn_gen[handle[12:0]] ==
                                                     handle[43:32]) begin
                                        // PYTHON: every function has .prototype
                                        // (Stage.prototype.createItem).
                                        if (code_rdata[23:8] == id_proto) begin
                                            if (vfn_proto[handle[12:0]][63:48] ==
                                                    V64_TAG_PREFIX &&
                                                vfn_proto[handle[12:0]][47:44] ==
                                                    V64_KIND_OBJECT &&
                                                vfn_proto[handle[12:0]][31:0] <
                                                    MAX_OBJ &&
                                                vobj_alloc[vfn_proto[handle[12:0]][12:0]]
                                                    == 2'd1 &&
                                                vobj_gen[vfn_proto[handle[12:0]][12:0]]
                                                    == vfn_proto[handle[12:0]][43:32])
                                            begin
                                                vst_wr(vsp - 12'd1, vfn_proto[handle[12:0]]);
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
                                    end else if (handle[63:48] != 16'h7ff9 ||
                                        handle[47:44] != 4'd5 ||
                                        handle[31:0] >= MAX_OBJ ||
                                        vobj_alloc[handle[12:0]] != 2'd1 ||
                                        vobj_gen[handle[12:0]] != handle[43:32]) begin
                                        // PYTHON: missing/primitive GET_PROP
                                        // is undefined (width/height → 640/480).
                                        if (code_rdata[23:8] == id_width)
                                            result = v64_int32_number(32'd640);
                                        else if (code_rdata[23:8] == id_height)
                                            result = v64_int32_number(32'd480);
                                        vst_wr(vsp - 12'd1, result);
                                        ip_n = ip + 16'd1;
                                        code_raddr_n =
                                            15'(ops_base + ip + 16'd1);
                                        state_n = S_FETCH_WAIT;
                                    end else begin
                                        hp_cmd_n = HP_GETPROP;
                                        hp_v64_n = 1'b1;
                                        hp_env_n = 1'b0;
                                        hp_oid_n = handle[12:0];
                                        hp_key_n = code_rdata[23:8];
                                        hp_len_n = vobj_len[handle[12:0]];
                                        hp_slot_n = 5'd0;
                                        hp_phase_n = 3'd0;
                                        hp_proto_n = vobj_proto[handle[12:0]];
                                        state_n = S_HEAP_WAIT;
                                    end
                                end
                            end
                            OP_SET_PROP: begin
                                if (vsp < 12'd2) begin
                                    machine_fault_n = 1'b1; fault_code_n = 8'd1;
                                    running_n = 1'b0; state_n = S_DONE;
                                end else begin
                                    logic [63:0] handle;
                                    logic found;
                                    handle = `VST_AT(vsp - 12'd2);
                                    found = 1'b0;
                                    if (handle[63:48] == 16'h7ff9 &&
                                        handle[47:44] == 4'd6 &&
                                        handle[31:0] < MAX_ARR &&
                                        varr_valid[handle[11:0]] &&
                                        varr_gen[handle[11:0]] == handle[43:32] &&
                                        code_rdata[23:8] == id_length) begin
                                        logic [31:0] new_len;
                                        new_len = v64_to_uint32(`VST_AT(vsp - 12'd1));
                                        if (new_len > ARR_CAP) begin
                                            machine_fault_n = 1'b1;
                                            fault_code_n = 8'd3;
                                            running_n = 1'b0;
                                            state_n = S_DONE;
                                        end else begin
                                            begin varr_len_we = 1'b1; varr_len_waddr = handle[11:0]; varr_len_wdata = new_len[7:0]; end
                                            vst_wr(vsp - 12'd2, `VST_AT(vsp - 12'd1));
                                            vsp_n = vsp - 12'd1;
                                            ip_n = ip + 16'd1;
                                            code_raddr_n =
                                                15'(ops_base + ip + 16'd1);
                                            if (new_len > varr_len[handle[11:0]])
                                            begin
                                                hp_cmd_n = HP_AFILL;
                                                hp_v64_n = 1'b1;
                                                hp_from_stack_n = 1'b0;
                                                hp_aid_n = handle[11:0];
                                                hp_aslot_n =
                                                    varr_len[handle[11:0]][6:0];
                                                hp_lim_n = new_len[7:0];
                                                hp_wval_n = V64_UNDEFINED;
                                                hp_ret_n = S_FETCH_WAIT;
                                                state_n = S_HEAP_FILL;
                                            end else
                                                state_n = S_FETCH_WAIT;
                                        end
                                    end else if (handle[63:48] != 16'h7ff9 ||
                                        handle[47:44] != 4'd5 ||
                                        handle[31:0] >= MAX_OBJ ||
                                        vobj_alloc[handle[12:0]] != 2'd1 ||
                                        vobj_gen[handle[12:0]] != handle[43:32]) begin
                                        // PYTHON: SET_PROP on a primitive is a
                                        // sloppy-mode no-op (Date.now = fn).
                                        vst_wr(vsp - 12'd2, `VST_AT(vsp - 12'd1));
                                        vsp_n = vsp - 12'd1;
                                        ip_n = ip + 16'd1;
                                        code_raddr_n =
                                            15'(ops_base + ip + 16'd1);
                                        state_n = S_FETCH_WAIT;
                                    end else begin
                                        if (code_rdata[23:8] == id_fillstyle ||
                                            code_rdata[23:8] == id_strokestyle) begin
                                            logic [63:0] style_val;
                                            style_val = `VST_AT(vsp - 12'd1);
                                            if (v64_is_number(style_val))
                                                fill_style_i_n =
                                                    v64_to_uint32(style_val)[7:0];
                                            else if (style_val[63:48] == 16'h7ff9 &&
                                                     style_val[47:44] == 4'd4 &&
                                                     style_val[15:0] < 16'd1024 &&
                                                     fill_lut[style_val[9:0]] != 8'hFF)
                                                fill_style_i_n =
                                                    fill_lut[style_val[9:0]];
                                            else if (style_val[15:0] == id_black ||
                                                     style_val[15:0] == id_hex_000)
                                                fill_style_i_n = 8'd0;
                                            else if (style_val[15:0] == id_white ||
                                                     style_val[15:0] == id_hex_fff)
                                                fill_style_i_n = 8'd1;
                                            else
                                                fill_style_i_n = 8'd1;
                                        end
                                        if (code_rdata[23:8] == id_textalign) begin
                                            // PYTHON ctx.textAlign — fillText
                                            // shifts the pen (center / right).
                                            ctx_align_n =
                                                (`VST_AT(vsp - 12'd1)[15:0] ==
                                                 id_center) ? 2'd1
                                                : (`VST_AT(vsp - 12'd1)[15:0] ==
                                                   id_right) ? 2'd2
                                                : 2'd0;
                                        end
                                        if (code_rdata[23:8] == id_imgsmooth) begin
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
                                        hp_cmd_n = HP_SETPROP;
                                        hp_v64_n = 1'b1;
                                        hp_env_n = 1'b0;
                                        hp_oid_n = handle[12:0];
                                        hp_key_n = code_rdata[23:8];
                                        hp_wval_n = `VST_AT(vsp - 12'd1);
                                        hp_len_n = vobj_len[handle[12:0]];
                                        hp_slot_n = 5'd0;
                                        hp_phase_n = 3'd0;
                                        hp_tag_n = 3'd0;
                                        if (code_rdata[23:8] == id_src &&
                                            vobj_builtin[handle[12:0]] == 4'd2 &&
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
                                        if (code_rdata[23:8] == id_onload &&
                                            `VST_AT(vsp - 12'd1)[63:48] ==
                                                V64_TAG_PREFIX &&
                                            `VST_AT(vsp - 12'd1)[47:44] ==
                                                4'd7)
                                            hp_phase_n = 3'd6;
                                        state_n = S_HEAP_WAIT;
                                    end
                                end
                            end
                            OP_NEW_OBJ: begin
                                if (vsp < code_rdata[31:24]) begin
                                    machine_fault_n = 1'b1; fault_code_n = 8'd1;
                                    running_n = 1'b0; state_n = S_DONE;
                                end else if (code_rdata[31:24] == 8'd0 &&
                                             vsp >= 12'(STACK_DEPTH)) begin
                                    machine_fault_n = 1'b1; fault_code_n = 8'd1;
                                        running_n = 1'b0; state_n = S_DONE;
                                    end else begin
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
                                argc = {4'd0, code_rdata[31:24]};
                                base = vsp - argc - 12'd1;
                                receiver = (vsp > argc)
                                    ? `VST_AT(base)
                                    : V64_UNDEFINED;
                                mip = 16'hFFFF;
                                obj_ok = (receiver[63:48] == V64_TAG_PREFIX &&
                                          receiver[47:44] == V64_KIND_OBJECT &&
                                          receiver[31:0] < MAX_OBJ &&
                                          vobj_alloc[receiver[12:0]] == 2'd1 &&
                                          vobj_gen[receiver[12:0]] ==
                                              receiver[43:32]);
                                arr_ok = (receiver[63:48] == V64_TAG_PREFIX &&
                                          receiver[47:44] == V64_KIND_ARRAY &&
                                          receiver[31:0] < MAX_ARR &&
                                          varr_valid[receiver[11:0]] &&
                                          varr_gen[receiver[11:0]] ==
                                              receiver[43:32]);
                                paint_color = 8'd0;
                                same_n = 5'd0;
                                dup = 1'b0;
                                ev = V64_UNDEFINED;
                                fn = V64_UNDEFINED;
                                if (vcsp >= CSTK) begin
                                    machine_fault_n = 1'b1; fault_code_n = 8'd2;
                                    running_n = 1'b0; state_n = S_DONE;
                                end else if (vsp < argc + 12'd1) begin
                                    machine_fault_n = 1'b1; fault_code_n = 8'd1;
                                    running_n = 1'b0; state_n = S_DONE;
                                end else if (code_rdata[23:8] == id_assign &&
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
                                                  tgt[31:0] < MAX_OBJ &&
                                                  vobj_alloc[tgt[12:0]] == 2'd1 &&
                                                  vobj_gen[tgt[12:0]] ==
                                                      tgt[43:32]);
                                        sv0 = `VST_AT(base + 12'd2);
                                        src0_ok = (argc >= 12'd2 &&
                                                   sv0[63:48] == V64_TAG_PREFIX &&
                                                   (sv0[47:44] == V64_KIND_OBJECT ||
                                                    sv0[47:44] == V64_KIND_ELEMENT) &&
                                                   sv0[31:0] < MAX_OBJ &&
                                                   vobj_alloc[sv0[12:0]] == 2'd1);
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
                                            hp_phase_n = 3'd0;
                                            hp_tn_n = vobj_len[tgt[12:0]];
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
                                           code_rdata[23:8] == id_push) begin
                                    if (varr_len[receiver[11:0]] + argc[7:0] >
                                            ARR_CAP[7:0]) begin
                                        machine_fault_n = 1'b1;
                                        fault_code_n = 8'd3;
                                        running_n = 1'b0; state_n = S_DONE;
                                    end else if (!varr_long[receiver[11:0]] &&
                                        (varr_len[receiver[11:0]] + argc[7:0] >
                                            ARR_SHORT_CAP[7:0]) &&
                                        !vprom_done) begin
                                        hp_aid_n = receiver[11:0];
                                        valloc_i_n = 14'd0;
                                        vprom_copy_n = 1'b0;
                                        vprom_ret_n = S_V64_EXEC;
                                        state_n = S_ARR_PROMOTE;
                                    end else begin
                                        vprom_done_n = 1'b0;
                                        varr_len_we = 1'b1; varr_len_waddr = receiver[11:0]; varr_len_wdata =
                                            varr_len[receiver[11:0]] + argc[7:0];
                                        vst_wr(base, v64_int32_number(
                                            {24'd0, varr_len[receiver[11:0]]} +
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
                                                varr_len[receiver[11:0]][6:0];
                                            hp_lim_n =
                                                varr_len[receiver[11:0]][7:0] +
                                                argc[7:0];
                                            hp_vbase_n = base + 12'd1 -
                                                {4'd0, varr_len[receiver[11:0]]};
                                            hp_ret_n = S_FETCH_WAIT;
                                            state_n = S_HEAP_FILL;
                                        end
                                    end
                                end else if (arr_ok &&
                                           (id_pop != 16'hFFFF &&
                                            code_rdata[23:8] == id_pop)) begin
                                    // PYTHON Array.pop: return last element
                                    // (undefined if empty) and shrink length.
                                    begin
                                        logic [7:0] al;
                                        al = varr_len[receiver[11:0]];
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
                                           (code_rdata[23:8] == id_foreach ||
                                            (id_find != 16'hFFFF &&
                                             code_rdata[23:8] == id_find) ||
                                            code_rdata[23:8] == id_map ||
                                            (id_filter != 16'hFFFF &&
                                             code_rdata[23:8] == id_filter)))
                                begin
                                    if (vfe_sp >= 4'd8) begin
                                        machine_fault_n = 1'b1;
                                        fault_code_n = 8'd3;
                                        running_n = 1'b0; state_n = S_DONE;
                                    end else begin
                                        logic [13:0] free_a;
                                        logic found_a;
                                        logic [1:0] md;
                                        found_a = 1'b0;
                                        free_a = 14'd0;
                                        md = (id_find != 16'hFFFF &&
                                              code_rdata[23:8] == id_find)
                                            ? 2'd1
                                            : (code_rdata[23:8] == id_map)
                                            ? 2'd2
                                            : (id_filter != 16'hFFFF &&
                                               code_rdata[23:8] == id_filter)
                                            ? 2'd3 : 2'd0;
                                        if ((md == 2'd2 || md == 2'd3) &&
                                            !vfree_armed) begin
                                            vfree_armed_n = 1'b1;
                                            vfree_arr_long_n =
                                                varr_long[receiver[11:0]] ||
                                                (varr_len[receiver[11:0]] >
                                                    ARR_SHORT_CAP[7:0]);
                                            valloc_i_n =
                                                (varr_long[receiver[11:0]] ||
                                                 (varr_len[receiver[11:0]] >
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
                                            running_n = 1'b0;
                                            state_n = S_DONE;
                                            end
                                        end else begin
                                            vfree_armed_n = 1'b0;
                                            free_a = valloc_i;
                                            valloc_retried_n = 1'b0;
                                        vfe_arr_s_n[vfe_sp] = vfe_arr;
                                        vfe_fn_s_n[vfe_sp] = vfe_fn;
                                        vfe_i_s_n[vfe_sp] = vfe_i;
                                        vfe_ret_s_n[vfe_sp] = vfe_ret;
                                        vfe_base_s_n[vfe_sp] = vfe_base;
                                        vfe_mode_s_n[vfe_sp] = vfe_mode;
                                        vfe_map_s_n[vfe_sp] = vfe_map;
                                        vfe_sp_n = vfe_sp + 4'd1;
                                        vfe_arr_n = receiver;
                                        vfe_fn_n = (argc != 0)
                                            ? `VST_AT(vsp - 12'd1)
                                            : V64_UNDEFINED;
                                        vfe_i_n = 8'd0;
                                        vfe_ret_n = ip + 16'd1;
                                        vfe_base_n = base;
                                        vfe_mode_n = md;
                                        if (md == 2'd2 || md == 2'd3) begin
                                            begin varr_valid_we = 1'b1; varr_valid_waddr = free_a[11:0]; varr_valid_wdata = 1'b1; end
                                            varr_len_we = 1'b1; varr_len_waddr = free_a[11:0]; varr_len_wdata =
                                                (md == 2'd2)
                                                ? varr_len[receiver[11:0]]
                                                : 8'd0;
                                            varr_long_we = 1'b1; varr_long_waddr = free_a[11:0]; varr_long_wdata =
                                                vfree_arr_long ||
                                                (free_a >= 14'(MAX_ARR_SHORT));
                                            if (vfree_arr_long ||
                                                (free_a >= 14'(MAX_ARR_SHORT)))
                                            begin
                                                varr_lidx_we = 1'b1; varr_lidx_waddr = free_a[11:0]; varr_lidx_wdata =
                                                    free_a[7:0];
                                                vlong_used_n[free_a[7:0]] = 1'b1;
                                            end
                                            varr_next_n = free_a + 14'd1;
                                            vfe_map_n = v64_handle(
                                                4'd6, varr_gen[free_a[11:0]],
                                                {20'd0, free_a[11:0]}
                                            );
                                            vnat_base_n = base;
                                            if (md == 2'd2 &&
                                                varr_len[receiver[11:0]] != 8'd0)
                                            begin
                                                hp_cmd_n = HP_AFILL;
                                                hp_v64_n = 1'b1;
                                                hp_from_stack_n = 1'b0;
                                                hp_aid_n = free_a[11:0];
                                                hp_aslot_n = 7'd0;
                                                hp_lim_n = varr_len[receiver[11:0]];
                                                hp_wval_n = V64_UNDEFINED;
                                                hp_ret_n = S_V64_FOREACH;
                                                state_n = S_HEAP_FILL;
                                            end else
                                                state_n = S_V64_FOREACH;
                                        end else begin
                                            vfe_map_n = V64_UNDEFINED;
                                            vnat_base_n = base;
                                            state_n = S_V64_FOREACH;
                                        end
                                    end
                                    end
                                end else if (code_rdata[23:8] == id_getctx) begin
                                    vnat_dom_n = 3'd3;
                                    vnat_base_n = base;
                                    valloc_kind_n = 2'd0;
                                    valloc_i_n = vobj_next;
                                    valloc_retried_n = 1'b0;
                                    state_n = S_V64_ALLOC;
                                end else if (obj_ok && argc >= 12'd4 &&
                                           (code_rdata[23:8] == id_fillrect ||
                                            code_rdata[23:8] == id_clearrect)) begin
                                    if (code_rdata[23:8] != id_clearrect)
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
                                    vdraw_color_n = (code_rdata[23:8] == id_clearrect)
                                        ? 8'd0 : paint_color;
                                    vdraw_i_n = 19'd0;
                                    vnat_base_n = base;
                                    state_n = S_V64_RECT;
                                end else if (obj_ok && argc >= 12'd4 &&
                                           code_rdata[23:8] == id_getimgdata) begin
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
                                           code_rdata[23:8] == id_putimgdata) begin
                                    begin
                                        logic [63:0] src;
                                        src = `VST_AT(base + 12'd1);
                                        if (src[63:48] == V64_TAG_PREFIX &&
                                            src[47:44] == V64_KIND_OBJECT &&
                                            src[31:0] < MAX_OBJ &&
                                            vobj_cls[src[12:0]] == CLS_IMGD) begin
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
                                           vobj_builtin[receiver[12:0]] == 4'd5 &&
                                           code_rdata[23:8] == id_save) begin
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
                                           vobj_builtin[receiver[12:0]] == 4'd5 &&
                                           code_rdata[23:8] == id_restore) begin
                                    ctx_tx_n = saved_tx; ctx_ty_n = saved_ty;
                                    ctx_sx_n = saved_sx; ctx_sy_n = saved_sy;
                                    vst_wr(base, V64_UNDEFINED);
                                    vsp_n = base + 12'd1;
                                    ip_n = ip + 16'd1;
                                    code_raddr_n =
                                        15'(ops_base + ip + 16'd1);
                                    state_n = S_FETCH_WAIT;
                                end else if (obj_ok && argc >= 12'd2 &&
                                           vobj_builtin[receiver[12:0]] == 4'd5 &&
                                           code_rdata[23:8] == id_translate) begin
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
                                           code_rdata[23:8] == id_settransform) begin
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
                                end else if (obj_ok && argc >= 12'd3 &&
                                           code_rdata[23:8] == id_drawimage) begin
                                    // PYTHON ctx.drawImage — ASET blit when
                                    // Image.src was jmr:spr:N (vobj_cls FFC).
                                    begin
                                        logic [63:0] img;
                                        logic [7:0] si;
                                        logic spr_ok;
                                        img = `VST_AT(base + 1);
                                        si = 8'(vobj_cls[img[12:0]][3:0]);
                                        spr_ok = (img[63:48] == V64_TAG_PREFIX &&
                                                  img[47:44] == V64_KIND_OBJECT &&
                                                  img[31:0] < MAX_OBJ &&
                                                  vobj_cls[img[12:0]][15:4] ==
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
                                                    rw_n = (spr_ww[si[3:0]] > 16'(MW))
                                                        ? 10'(MW)
                                                        : spr_ww[si[3:0]][9:0];
                                                    rh_n = (spr_hh[si[3:0]] > 16'(MH))
                                                        ? 10'(MH)
                                                        : spr_hh[si[3:0]][9:0];
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
                                           code_rdata[23:8] == id_filltext) begin
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
                                    state_n = S_TXT_LD;
                                end else if (obj_ok &&
                                           code_rdata[23:8] == id_measuretext) begin
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
                                            tl = {8'd0, name_len_tbl[txt[9:0]]};
                                        else if (txt[63:48] == V64_TAG_PREFIX &&
                                                 txt[47:44] == V64_KIND_OBJECT &&
                                                 txt[31:0] < MAX_OBJ &&
                                                 vobj_builtin[txt[12:0]] == 4'd7)
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
                                                vobj_alloc[vmetrics[12:0]] == 2'd1)
                                            begin
                                                vst_wr(base, vmetrics);
                                                vsp_n = base + 12'd1;
                                                hp_cmd_n = HP_OSETI;
                                                hp_v64_n = 1'b1;
                                                hp_oid_n = vmetrics[12:0];
                                                hp_slot_n = 5'd0;
                                                hp_qn_n = 3'd1;
                                                hp_qi_n = 3'd0;
                                                hp_qk_n[0] = id_width;
                                                hp_qv_n[0] =
                                                    v64_int32_number({16'd0, tl << 3});
                                                hp_qt_n[0] = 3'd0;
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
                                           code_rdata[23:8] == id_fill) begin
                                    // Array.fill(v) — not ctx.fill(). PYTHON
                                    // writes every slot and returns the array.
                                    begin
                                        logic [7:0] al;
                                        logic [63:0] fv;
                                        al = varr_len[receiver[11:0]];
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
                                           code_rdata[23:8] == id_unshift) begin
                                    begin
                                        logic [7:0] al;
                                        al = varr_len[receiver[11:0]];
                                        if (al < ARR_CAP[7:0] &&
                                            !varr_long[receiver[11:0]] &&
                                            (al + 8'd1 > ARR_SHORT_CAP[7:0]) &&
                                            !vprom_done) begin
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
                                           code_rdata[23:8] == id_splice) begin
                                    logic [7:0] st, cnt, al;
                                    al = varr_len[receiver[11:0]];
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
                                           code_rdata[23:8] == id_join) begin
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
                                           code_rdata[23:8] == id_indexof) begin
                                    begin
                                        logic [7:0] al;
                                        al = varr_len[receiver[11:0]];
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
                                end else if (code_rdata[23:8] == id_indexof &&
                                    ((receiver[63:48] == V64_TAG_PREFIX &&
                                      receiver[47:44] == 4'd4 &&
                                      receiver[31:0] < 32'd1024) ||
                                     (receiver[63:48] == V64_TAG_PREFIX &&
                                      receiver[47:44] == V64_KIND_OBJECT &&
                                      receiver[31:0] < MAX_OBJ &&
                                      vobj_builtin[receiver[12:0]] == 4'd7)))
                                begin
                                    // PYTHON String.indexOf — ToString(needle)
                                    // (`JSON.stringify(data).indexOf(0)`).
                                    begin
                                        logic signed [31:0] found_i;
                                        logic [7:0] needle_b;
                                        logic [15:0] hay_off, hay_len;
                                        logic intern_hay;
                                        found_i = -32'sd1;
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
                                                name_mem[name_off[`VST_AT(base + 12'd1)[9:0]]];
                                        intern_hay = (receiver[47:44] == 4'd4);
                                        ip_n = ip + 16'd1;
                                        code_raddr_n =
                                            15'(ops_base + ip + 16'd1);
                                        hp_vbase_n = base;
                                        hp_key_n = {8'd0, needle_b};
                                        hp_wval_n = {56'd0, needle_b};
                                        if (intern_hay) begin
                                            hay_off = name_off[receiver[9:0]];
                                            hay_len = {8'd0, name_len_tbl[receiver[9:0]]};
                                            for (int k = 0; k < 256; k++)
                                                if (k < hay_len && found_i < 0 &&
                                                    name_mem[hay_off + 16'(k)] ==
                                                        needle_b)
                                                    found_i = k;
                                            vst_wr(base, v64_int32_number(found_i));
                                            vsp_n = base + 12'd1;
                                            state_n = S_FETCH_WAIT;
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
                                end else if (code_rdata[23:8] == id_replace &&
                                           argc >= 12'd2 &&
                                    ((receiver[63:48] == V64_TAG_PREFIX &&
                                      receiver[47:44] == 4'd4 &&
                                      receiver[31:0] < 32'd1024) ||
                                     (receiver[63:48] == V64_TAG_PREFIX &&
                                      receiver[47:44] == V64_KIND_OBJECT &&
                                      receiver[31:0] < MAX_OBJ &&
                                      vobj_builtin[receiver[12:0]] == 4'd7)))
                                begin
                                    // PYTHON String.replace — dynstr or interned
                                    // haystack, packed RegExp or digit pattern.
                                    begin
                                        logic [63:0] pat, replv;
                                        logic intern_hay;
                                        pat = `VST_AT(base + 12'd1);
                                        replv = `VST_AT(base + 12'd2);
                                        intern_hay = (receiver[47:44] == 4'd4);
                                        vnat_base_n = base;
                                        v64_repl_n = 1'b1;
                                        repl_g_n = 1'b0;
                                        repl_nlen_n = 8'd1;
                                        repl_pat1_n = 8'd0;
                                        repl_pat0_n = 8'd0;
                                        repl_did_n = 1'b0;
                                        if (pat[63:48] == V64_TAG_PREFIX &&
                                            pat[47:44] == 4'd4 &&
                                            pat[31:0] < 32'd1024 &&
                                            name_len_tbl[pat[9:0]] == 8'd1)
                                            repl_pat0_n =
                                                name_hash_tbl[pat[9:0]][7:0];
                                        else if (v64_is_number(pat))
                                            repl_pat0_n = 8'h30 +
                                                v64_to_uint32(pat)[7:0];
                                        if (replv[63:48] == V64_TAG_PREFIX &&
                                            replv[47:44] == 4'd4 &&
                                            replv[31:0] < 32'd1024 &&
                                            name_len_tbl[replv[9:0]] == 8'd1)
                                            repl_rch_n =
                                                name_hash_tbl[replv[9:0]][7:0];
                                        else if (v64_is_number(replv))
                                            repl_rch_n = 8'h30 +
                                                v64_to_uint32(replv)[7:0];
                                        else
                                            repl_rch_n = 8'h30;
                                        ip_n = ip + 16'd1;
                                        if (pat[63:48] == V64_TAG_PREFIX &&
                                            pat[47:44] == V64_KIND_OBJECT &&
                                            pat[31:0] < MAX_OBJ &&
                                            vobj_alloc[pat[12:0]] == 2'd1 &&
                                            vobj_builtin[pat[12:0]] == 4'd6) begin
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
                                                    {6'd0, name_len_tbl[receiver[9:0]]};
                                                json_rp_n = 14'd0;
                                                name_rdaddr_n =
                                                    name_off[receiver[9:0]];
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
                                                {6'd0, name_len_tbl[receiver[9:0]]};
                                            json_rp_n = 14'd0;
                                            name_rdaddr_n =
                                                name_off[receiver[9:0]];
                                            json_wp_n = 14'd0;
                                            namcpy_repl_n = 1'b1;
                                            namcpy_v64_n = 1'b0;
                                            namcpy_armed_n = 1'b0;
                                            state_n = S_NAMCPY;
                                        end
                                    end
                                end else if (code_rdata[23:8] == id_beginpath ||
                                           code_rdata[23:8] == id_closepath) begin
                                    if (code_rdata[23:8] == id_beginpath)
                                        pc_n_n = 5'd0;
                                    path_kind_n = 2'd0;
                                    vst_wr(base, V64_UNDEFINED);
                                    vsp_n = base + 12'd1;
                                    ip_n = ip + 16'd1;
                                    code_raddr_n =
                                        15'(ops_base + ip + 16'd1);
                                    state_n = S_FETCH_WAIT;
                                end else if (code_rdata[23:8] == id_arc &&
                                           argc >= 12'd3) begin
                                    if (pc_n < 5'(PATH_MAX)) begin
                                        pc_op_n[pc_n[3:0]] = 2'd3;
                                        pc_a1_n[pc_n[3:0]] =
                                            v64_to_fx(`VST_AT(base + 12'd1));
                                        pc_a2_n[pc_n[3:0]] =
                                            v64_to_fx(`VST_AT(base + 12'd2));
                                        pc_a3_n[pc_n[3:0]] =
                                            v64_to_fx(`VST_AT(base + 12'd3));
                                        pc_a4_n[pc_n[3:0]] = (argc > 12'd3)
                                            ? v64_to_fx(`VST_AT(base + 12'd4))
                                            : 32'sd0;
                                        pc_a5_n[pc_n[3:0]] = (argc > 12'd4)
                                            ? v64_to_fx(`VST_AT(base + 12'd5))
                                            : 32'sd0;
                                        pc_ccw_n[pc_n[3:0]] = (argc > 12'd5)
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
                                end else if ((code_rdata[23:8] == id_moveto ||
                                            code_rdata[23:8] == id_lineto) &&
                                           argc >= 12'd2) begin
                                    if (pc_n < 5'(PATH_MAX)) begin
                                        pc_op_n[pc_n[3:0]] =
                                            (code_rdata[23:8] == id_moveto)
                                            ? 2'd0 : 2'd1;
                                        pc_a1_n[pc_n[3:0]] =
                                            v64_to_fx(`VST_AT(base + 12'd1));
                                        pc_a2_n[pc_n[3:0]] =
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
                                end else if (code_rdata[23:8] == id_fill ||
                                           code_rdata[23:8] == id_stroke) begin
                                    color_n = fill_style_i;
                                    path_stroke_n =
                                        (code_rdata[23:8] == id_stroke);
                                    vst_wr(base, V64_UNDEFINED);
                                    vsp_n = base + 12'd1;
                                    ip_n = ip + 16'd1;
                                    pi_n = 5'd0;
                                    path_active_n = 1'b1;
                                    state_n = S_PWALK;
                                end else if (code_rdata[23:8] == id_ael) begin
                                    ev = (argc != 0) ? `VST_AT(base + 1)
                                        : V64_UNDEFINED;
                                    fn = (argc > 1) ? `VST_AT(base + 2)
                                        : V64_UNDEFINED;
                                    for (int k = 0; k < 16; k++)
                                        if (k < vlistener_n) begin
                                            if (v64_equal(vlistener_ev[k], ev) &&
                                                v64_equal(vlistener_fn[k], fn))
                                                dup = 1'b1;
                                            if (v64_equal(vlistener_ev[k], ev))
                                                same_n = same_n + 5'd1;
                                        end
                                    if (fn[63:48] != 16'h7ff9 ||
                                        fn[47:44] != 4'd7) begin
                                        machine_fault_n = 1'b1;
                                        fault_code_n = 8'd4;
                                        running_n = 1'b0; state_n = S_DONE;
                                    end else if (!dup && same_n >= 5'd4) begin
                                        machine_fault_n = 1'b1;
                                        fault_code_n = 8'd3;
                                        running_n = 1'b0; state_n = S_DONE;
                                    end else if (!dup && vlistener_n >= 5'd16) begin
                                        machine_fault_n = 1'b1;
                                        fault_code_n = 8'd3;
                                        running_n = 1'b0; state_n = S_DONE;
                                    end else begin
                                        if (!dup) begin
                                            vlistener_ev_n[vlistener_n] = ev;
                                            vlistener_fn_n[vlistener_n] = fn;
                                            vlistener_n_n = vlistener_n + 5'd1;
                                        end
                                        vst_wr(base, V64_UNDEFINED);
                                        vsp_n = base + 12'd1;
                                        ip_n = ip + 16'd1;
                                        code_raddr_n =
                                            15'(ops_base + ip + 16'd1);
                                        state_n = S_FETCH_WAIT;
                                    end
                                end else if (code_rdata[23:8] == id_gettime ||
                                           code_rdata[23:8] == id_now) begin
                                    // Date.getTime / .now — frame clock
                                    // (same mul as native 35 / PYTHON).
                                    begin
                                        logic [63:0] ts;
                                        v64_mul_task(
                                            v64_int32_number(vframe_no),
                                            64'h4030aaaaaaaaaaab,
                                            ts
                                        );
                                        vst_wr(base, ts);
                                        vsp_n = base + 12'd1;
                                        ip_n = ip + 16'd1;
                                        code_raddr_n =
                                            15'(ops_base + ip + 16'd1);
                                        state_n = S_FETCH_WAIT;
                                    end
                                end else if (code_rdata[23:8] == id_bind &&
                                    receiver[63:48] == V64_TAG_PREFIX &&
                                    receiver[47:44] == V64_KIND_FUNCTION &&
                                    receiver[31:0] < MAX_OBJ &&
                                    vfn_valid[receiver[12:0]] &&
                                    vfn_gen[receiver[12:0]] ==
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
                                end else if (obj_ok) begin
                                    for (int c = 0; c < MAX_CLS; c++)
                                        if (c < n_cls &&
                                            cls_name[c] ==
                                                vobj_cls[receiver[12:0]])
                                            for (int m = 0; m < MAX_CMETH; m++)
                                                if (m < cls_nmeth[c] &&
                                                    cls_mname[c][m] ==
                                                        code_rdata[23:8])
                                                    mip = cls_mip[c][m];
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
                                        state_n = S_V64_BIND;
                                    end else begin
                                        hp_cmd_n = HP_LOOKFN;
                                        hp_v64_n = 1'b1;
                                        hp_oid_n = receiver[12:0];
                                        hp_key_n = code_rdata[23:8];
                                        hp_len_n = vobj_len[receiver[12:0]];
                                        hp_slot_n = 5'd0;
                                        hp_phase_n = 3'd0;
                                        hp_proto_n = vobj_proto[receiver[12:0]];
                                        hp_hit_n = 1'b0;
                                        hp_ret_n = S_V64_METH;
                                        vnat_base_n = base;
                                        vcall_argc_n = argc;
                                        vcall_this_n = receiver;
                                        state_n = S_HEAP_WAIT;
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
                                    machine_fault_n = 1'b1; fault_code_n = 8'd1;
                                    running_n = 1'b0; state_n = S_DONE;
                                end else if (code_rdata[7:0] == OP_ADD &&
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
                                    state_n = S_CONCAT;
                                end else begin
                                    // PYTHON ToNumber: non-Number → +0
                                    // (`timestamp - previous` on first rAF).
                                    logic [63:0] aa, bb, arithmetic_result;
                                    aa = v64_is_number(`VST_AT(vsp - 12'd2))
                                        ? `VST_AT(vsp - 12'd2) : 64'd0;
                                    bb = v64_is_number(`VST_AT(vsp - 12'd1))
                                        ? `VST_AT(vsp - 12'd1) : 64'd0;
                                    if (code_rdata[7:0] == OP_ADD)
                                        v64_add_task(aa, bb, arithmetic_result);
                                    else if (code_rdata[7:0] == OP_SUB)
                                        v64_add_task(aa,
                                                     {~bb[63], bb[62:0]},
                                                     arithmetic_result);
                                    else
                                        v64_mul_task(aa, bb, arithmetic_result);
                                    vst_wr(vsp - 12'd2, arithmetic_result);
                                    vsp_n = vsp - 12'd1;
                                    ip_n = ip + 16'd1;
                                    code_raddr_n = 15'(ops_base + ip + 16'd1);
                                    state_n = S_FETCH_WAIT;
                                end
                            end
                            OP_DIV: begin
                                if (vsp < 12'd2) begin
                                    machine_fault_n = 1'b1; fault_code_n = 8'd1;
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
                                    machine_fault_n = 1'b1; fault_code_n = 8'd1;
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
                                    machine_fault_n = 1'b1; fault_code_n = 8'd1;
                                    running_n = 1'b0; state_n = S_DONE;
                                end else begin
                                    logic [31:0] left_int, right_int, bit_result;
                                    // ToInt32: BOOL true|false, not a Number-only fault
                                    left_int = v64_to_int32(`VST_AT(vsp - 12'd2));
                                    right_int = v64_to_int32(`VST_AT(vsp - 12'd1));
                                    bit_result = (code_rdata[7:0] == OP_BIT_OR)
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
                                    machine_fault_n = 1'b1; fault_code_n = 8'd1;
                                    running_n = 1'b0; state_n = S_DONE;
                                end else begin
                                    logic [63:0] aa, bb;
                                    // PYTHON ToNumber: non-Number → +0 for LT/GT
                                    // (`this.jumpHeight >= 750` before first jump).
                                    // EQ keeps identity (PYTHON does not ToNumber).
                                    aa = (code_rdata[7:0] != OP_EQ &&
                                          !v64_is_number(`VST_AT(vsp - 12'd2)))
                                        ? 64'd0 : `VST_AT(vsp - 12'd2);
                                    bb = (code_rdata[7:0] != OP_EQ &&
                                          !v64_is_number(`VST_AT(vsp - 12'd1)))
                                        ? 64'd0 : `VST_AT(vsp - 12'd1);
                                    vst_wr(vsp - 12'd2, {16'h7ff9, 4'd3, 12'd0, 31'd0,
                                         (code_rdata[7:0] == OP_EQ)
                                         ? v64_equal(aa, bb)
                                         : (code_rdata[7:0] == OP_LT)
                                         ? v64_less(aa, bb)
                                         : v64_less(bb, aa)});
                                    vsp_n = vsp - 12'd1;
                                    ip_n = ip + 16'd1;
                                    code_raddr_n = 15'(ops_base + ip + 16'd1);
                                    state_n = S_FETCH_WAIT;
                                end
                            end
                            OP_JUMP: begin
                                if (code_rdata[23:8] > n_ops) begin
                                    machine_fault_n = 1'b1; fault_code_n = 8'd5;
                                    running_n = 1'b0; state_n = S_DONE;
                                end else begin
                                    ip_n = code_rdata[23:8];
                                    code_raddr_n = 15'(ops_base + code_rdata[23:8]);
                                    state_n = S_FETCH_WAIT;
                                end
                            end
                            OP_JIF: begin
                                if (vsp == 0) begin
                                    machine_fault_n = 1'b1; fault_code_n = 8'd1;
                                    running_n = 1'b0; state_n = S_DONE;
                                end else if (code_rdata[23:8] > n_ops) begin
                                    machine_fault_n = 1'b1; fault_code_n = 8'd5;
                                    running_n = 1'b0; state_n = S_DONE;
                                end else begin
                                    vsp_n = vsp - 12'd1;
                                    if (!v64_truthy(`VST_AT(vsp - 12'd1))) begin
                                        ip_n = code_rdata[23:8];
                                        code_raddr_n = 15'(ops_base + code_rdata[23:8]);
                                    end else begin
                                        ip_n = ip + 16'd1;
                                        code_raddr_n = 15'(ops_base + ip + 16'd1);
                                    end
                                    state_n = S_FETCH_WAIT;
                                end
                            end
                            OP_POP: begin
                                if (vsp == 0) begin
                                    machine_fault_n = 1'b1; fault_code_n = 8'd1;
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
                                    machine_fault_n = 1'b1; fault_code_n = 8'd1;
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
                                    machine_fault_n = 1'b1; fault_code_n = 8'd1;
                                    running_n = 1'b0; state_n = S_DONE;
                                end else if (code_rdata[7:0] == OP_NEG &&
                                             !v64_is_number(`VST_AT(vsp - 12'd1))) begin
                                    machine_fault_n = 1'b1; fault_code_n = 8'd5;
                                    running_n = 1'b0; state_n = S_DONE;
                                end else begin
                                    if (code_rdata[7:0] == OP_NEG)
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
                            OP_RETURN: begin
                                if (vsp != 0) begin
                                    machine_fault_n = 1'b1; fault_code_n = 8'd1;
                                    running_n = 1'b0;
                                    state_n = S_DONE;
                                end else if (vcsp != 0) begin
                                    machine_fault_n = 1'b1; fault_code_n = 8'd2;
                                    running_n = 1'b0;
                                    state_n = S_DONE;
                                end else begin
                                    vgc_clear_i_n = 14'd0;
                                    vgc_qr_n = 14'd0;
                                    vgc_qw_n = 14'd0;
                                    vgc_halt_after_n = 1'b1;
                                    vgc_wait_after_n =
                                        (vraf_n != 0 || vtimer_n != 0);
                                    state_n = S_V64_GC_CLEAR;
                                end
                            end
                            default: begin
                                machine_fault_n = 1'b1;
                                fault_code_n = 8'd5;
                                running_n = 1'b0;
                                state_n = S_DONE;
                            end
                        endcase
                    end
        end
    end
    `undef VST_AT
    `undef VST_REL
endmodule
