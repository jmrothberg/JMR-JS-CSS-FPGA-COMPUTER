// Hierarchical opcode/native decoder. Same clk as jmr_js_vm.
// Enable when state==S_EXEC or S_NAT. Case text from the parent always_ff.
import jmr_js_vm_pkg::*;
import jmr_value_pkg::*;
module jmr_js_vm_exec32 (
    input  logic clk,
    input  logic enable,
    input  logic signed [31:0] alu_a,
    input  logic signed [31:0] alu_b,
    input  logic alu_fx,
    input  logic [2:0] alu_op,
    input  logic arr_keep_ok,
    input  logic [7:0] arr_len [0:MAX_ARR-1],
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
    input  logic [15:0] char_id [0:255],
    input  logic char_ok [0:255],
    input  logic click_fired,
    input  logic [15:0] click_fn,
    input  logic [18:0] clr_idx,
    input  logic [15:0] cls_ctor [0:MAX_CLS-1],
    input  logic [15:0] cls_mip [0:MAX_CLS-1][0:MAX_CMETH-1],
    input  logic [15:0] cls_mname [0:MAX_CLS-1][0:MAX_CMETH-1],
    input  logic [15:0] cls_name [0:MAX_CLS-1],
    input  logic [4:0] cls_nmeth [0:MAX_CLS-1],
    input  logic [14:0] code_raddr,
    input  logic [31:0] code_rdata,
    input  logic [7:0] color,
    input  logic signed [31:0] consts [0:MAX_CONSTS-1],
    input  logic [6:0] csp,
    input  logic [15:0] cstack_ctorobj [0:CSTK-1],
    input  logic [5:0] cstack_env [0:CSTK-1],
    input  logic [15:0] cstack_fe_arr [0:CSTK-1],
    input  logic [15:0] cstack_fe_fn [0:CSTK-1],
    input  logic [7:0] cstack_fe_i [0:CSTK-1],
    input  logic [15:0] cstack_ip [0:CSTK-1],
    input  logic cstack_isctor [0:CSTK-1],
    input  logic cstack_isfe [0:CSTK-1],
    input  logic [15:0] cstack_map_arr [0:CSTK-1],
    input  logic [15:0] cstack_this [0:CSTK-1],
    input  logic [1:0] ctx_align,
    input  logic [7:0] ctx_font_px,
    input  logic ctx_smooth,
    input  logic signed [31:0] ctx_sx,
    input  logic signed [31:0] ctx_sy,
    input  logic signed [31:0] ctx_tx,
    input  logic signed [31:0] ctx_ty,
    input  logic [15:0] dbg_call_ovf,
    input  logic [15:0] dbg_cb_ip,
    input  logic [15:0] dbg_di_hit,
    input  logic [15:0] dbg_di_miss,
    input  logic [15:0] dbg_div_n,
    input  logic [15:0] dbg_find_hit,
    input  logic [15:0] dbg_heap_ovf,
    input  logic [15:0] dbg_json_ovf,
    input  logic [15:0] dbg_path_ovf,
    input  logic [15:0] dbg_splice_n,
    input  logic [15:0] dbg_stack_ovf,
    input  logic [15:0] dbg_tmr_sched,
    input  logic [15:0] dbg_to_ovf,
    input  logic did_swap,
    input  logic [5:0] div_cnt,
    input  logic div_int_in,
    input  logic div_neg,
    input  logic [31:0] div_rem,
    input  logic [31:0] div_ub,
    input  logic [47:0] div_uq,
    input  logic env_cap [0:ENV_DEPTH-1],
    input  logic [15:0] env_free [0:ENV_DEPTH-1],
    input  logic [5:0] env_free_n,
    input  logic env_is_store,
    input  logic [8:0] env_ld_slot,
    input  logic [15:0] env_oid [0:ENV_DEPTH-1],
    input  logic [5:0] env_sp,
    input  logic [15:0] env_walk,
    input  logic [18:0] fb_dump_addr,
    input  logic fb_dump_sel,
    input  logic fb_swap,
    input  logic [7:0] fill_lut [0:1023],
    input  logic [7:0] fill_style_i,
    input  logic [15:0] fn_proto_ip [0:MAX_FN_PROTO-1],
    input  logic [15:0] fn_proto_oid [0:MAX_FN_PROTO-1],
    input  logic [7:0] fp_left,
    input  logic [7:0] fpx_acc,
    input  logic frame_fire,
    input  logic frame_tick,
    input  logic [11:0] hp_aid,
    input  logic [7:0] hp_alen,
    input  logic [6:0] hp_aslot,
    input  logic [3:0] hp_cmd,
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
    input  logic [4:0] hp_ss,
    input  logic [2:0] hp_tag,
    input  logic [5:0] hp_tn,
    input  logic hp_v64,
    input  logic [11:0] hp_vbase,
    input  logic [63:0] hp_wval,
    input  logic [15:0] id_a,
    input  logic [15:0] id_ael,
    input  logic [15:0] id_arc,
    input  logic [15:0] id_assign,
    input  logic [15:0] id_beginpath,
    input  logic [15:0] id_bind,
    input  logic [15:0] id_black,
    input  logic [15:0] id_center,
    input  logic [15:0] id_clearrect,
    input  logic [15:0] id_click,
    input  logic [15:0] id_closepath,
    input  logic [15:0] id_customev,
    input  logic [15:0] id_cyan,
    input  logic [15:0] id_d,
    input  logic [15:0] id_disp,
    input  logic [15:0] id_domevent,
    input  logic [15:0] id_drawimage,
    input  logic [15:0] id_fill,
    input  logic [15:0] id_fillrect,
    input  logic [15:0] id_fillstyle,
    input  logic [15:0] id_filltext,
    input  logic [15:0] id_filter,
    input  logic [15:0] id_find,
    input  logic [15:0] id_findindex,
    input  logic [15:0] id_font,
    input  logic [15:0] id_foreach,
    input  logic [15:0] id_getctx,
    input  logic [15:0] id_getimgdata,
    input  logic [15:0] id_gettime,
    input  logic [15:0] id_gold,
    input  logic [15:0] id_height,
    input  logic [15:0] id_hex_000,
    input  logic [15:0] id_hex_09f,
    input  logic [15:0] id_hex_2ec,
    input  logic [15:0] id_hex_3f6,
    input  logic [15:0] id_hex_aaa,
    input  logic [15:0] id_hex_f00,
    input  logic [15:0] id_hex_f5a,
    input  logic [15:0] id_hex_f5f5,
    input  logic [15:0] id_hex_fc0,
    input  logic [15:0] id_hex_ffe6,
    input  logic [15:0] id_hex_fff,
    input  logic [15:0] id_imgsmooth,
    input  logic [15:0] id_indexof,
    input  logic [15:0] id_join,
    input  logic [15:0] id_kbevent,
    input  logic [15:0] id_keydown,
    input  logic [15:0] id_keyup,
    input  logic [15:0] id_kspace,
    input  logic [15:0] id_length,
    input  logic [15:0] id_lineto,
    input  logic [15:0] id_map,
    input  logic [15:0] id_measuretext,
    input  logic [15:0] id_mouseev,
    input  logic [15:0] id_moveto,
    input  logic [15:0] id_now,
    input  logic [15:0] id_onload,
    input  logic [15:0] id_proto,
    input  logic [15:0] id_push,
    input  logic [15:0] id_putimgdata,
    input  logic [15:0] id_quadcurve,
    input  logic [15:0] id_red,
    input  logic [15:0] id_rel,
    input  logic [15:0] id_replace,
    input  logic [15:0] id_restore,
    input  logic [15:0] id_right,
    input  logic [15:0] id_rotate,
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
    input  logic [15:0] id_type,
    input  logic [15:0] id_unshift,
    input  logic [15:0] id_white,
    input  logic [15:0] id_width,
    input  logic [15:0] id_yellow,
    input  logic [7:0] idx_needle,
    input  logic [2:0] idx_t,
    input  logic signed [31:0] idx_v,
    input  logic imgd_armed,
    input  logic [9:0] imgd_h,
    input  logic [18:0] imgd_i,
    input  logic [18:0] imgd_n,
    input  logic [10:0] imgd_res,
    input  logic [9:0] imgd_w,
    input  logic [9:0] imgd_x,
    input  logic [9:0] imgd_x0,
    input  logic [9:0] imgd_y,
    input  logic [9:0] imgd_y0,
    input  logic [8:0] intern_var [0:1023],
    input  logic intern_var_ok [0:1023],
    input  logic [15:0] ip,
    input  logic [11:0] jn_arr,
    input  logic [15:0] jn_h,
    input  logic [15:0] jn_i,
    input  logic [10:0] jn_res,
    input  logic [5:0] joy_in,
    input  logic [7:0] js_i [0:JSON_STK-1],
    input  logic [2:0] js_ph [0:JSON_STK-1],
    input  logic [5:0] js_sp,
    input  logic [2:0] js_tag [0:JSON_STK-1],
    input  logic [31:0] js_val [0:JSON_STK-1],
    input  logic [13:0] json_dst,
    input  logic [7:0] json_mem [0:JSON_CAP-1],
    input  logic [2:0] json_pph,
    input  logic [10:0] json_res,
    input  logic [13:0] json_rp,
    input  logic [13:0] json_src,
    input  logic [13:0] json_srclen,
    input  logic [13:0] json_wp,
    input  logic [2:0] kd_n,
    input  logic [15:0] kd_slot [0:3],
    input  logic [15:0] kev_fn,
    input  logic kev_is_down,
    input  logic [1:0] kev_li,
    input  logic [15:0] kev_obj,
    input  logic [15:0] kev_ret_ip,
    input  logic [15:0] keys_a_oid,
    input  logic [15:0] keys_d_oid,
    input  logic [15:0] keys_sp_oid,
    input  logic [2:0] ku_n,
    input  logic [15:0] ku_slot [0:3],
    input  logic [31:0] lfsr,
    input  logic looping,
    input  logic [15:0] metrics_oid,
    input  logic signed [31:0] mul_a,
    input  logic signed [31:0] mul_b,
    input  logic mul_fx_a,
    input  logic mul_fx_b,
    input  logic [15:0] n_arr,
    input  logic [15:0] n_arr_keep,
    input  logic [4:0] n_cls,
    input  logic [6:0] n_fn_proto,
    input  logic [15:0] n_obj,
    input  logic [15:0] n_obj_keep,
    input  logic [15:0] n_ops,
    input  logic [4:0] n_spr,
    input  logic namcpy_armed,
    input  logic namcpy_repl,
    input  logic name_has [0:1023],
    input  logic [15:0] name_hash_tbl [0:1023],
    input  logic [7:0] name_len_tbl [0:1023],
    input  logic [7:0] name_mem [0:NAME_CAP-1],
    input  logic [15:0] name_off [0:1023],
    input  logic [15:0] name_rdaddr,
    input  logic [7:0] name_rdata,
    input  logic names_ok,
    input  logic [7:0] nat_argc,
    input  logic [7:0] nat_id,
    input  logic [15:0] obj_cls [0:MAX_OBJ-1],
    input  logic obj_keep_ok,
    input  logic [5:0] obj_n [0:MAX_OBJ-1],
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
    input  logic present_pend,
    input  logic [15:0] raf_fn [0:7],
    input  logic [3:0] raf_n,
    input  logic [5:0] rel_i,
    input  logic [5:0] rel_lim,
    input  logic [5:0] rel_nn,
    input  logic [6:0] rel_ret,
    input  logic [5:0] rel_saved,
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
    input  logic [2:0] stack_tag [0:STACK_DEPTH-1],
    input  logic start,
    input  logic [6:0] state,
    input  logic signed [31:0] str_pf_ci,
    input  logic [15:0] str_pf_id,
    input  logic str_pf_ok,
    input  logic [10:0] str_res,
    input  logic [15:0] tenv_parent [0:MAX_OBJ-1],
    input  logic [15:0] tfn_entry [0:MAX_OBJ-1],
    input  logic tfn_has_this [0:MAX_OBJ-1],
    input  logic [7:0] tfn_nparam [0:MAX_OBJ-1],
    input  logic [15:0] tfn_parent [0:MAX_OBJ-1],
    input  logic [15:0] tfn_this [0:MAX_OBJ-1],
    input  logic [2:0] tfn_this_tag [0:MAX_OBJ-1],
    input  logic [15:0] this_obj,
    input  logic this_ok,
    input  logic [31:0] time_ms,
    input  logic [11:0] to_delay [0:TIMER_DEPTH-1],
    input  logic [15:0] to_fn [0:TIMER_DEPTH-1],
    input  logic [15:0] to_id [0:TIMER_DEPTH-1],
    input  logic [6:0] to_n,
    input  logic [11:0] to_period [0:TIMER_DEPTH-1],
    input  logic [15:0] to_seq,
    input  logic [6:0] txt_bn,
    input  logic [7:0] txt_buf [0:TXT_MAX-1],
    input  logic [3:0] txt_ph,
    input  logic signed [15:0] txt_px,
    input  logic signed [15:0] txt_py,
    input  logic [15:0] txt_rp,
    input  logic [31:0] txt_val,
    input  logic [2:0] txt_vt,
    input  logic var_init [0:MAX_VARS-1],
    input  logic [2:0] var_tag [0:MAX_VARS-1],
    input  logic [8:0] var_this,
    input  logic signed [31:0] vars [0:MAX_VARS-1],
    input  logic [11:0] vcall_argc,
    input  logic [63:0] vcall_this,
    input  logic [5:0] vobj_len [0:MAX_OBJ-1],
    input  logic [9:0] x,
    input  logic [1:0] xf_dst,
    input  logic signed [31:0] xf_h,
    input  logic signed [31:0] xf_w,
    input  logic signed [31:0] xf_x,
    input  logic signed [31:0] xf_y,
    input  logic [9:0] y,
    output logic signed [31:0] alu_a_n,
    output logic signed [31:0] alu_b_n,
    output logic alu_fx_n,
    output logic [2:0] alu_op_n,
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
    output logic click_fired_n,
    output logic [15:0] click_fn_n,
    output logic [18:0] clr_idx_n,
    output logic [14:0] code_raddr_n,
    output logic [7:0] color_n,
    output logic [6:0] csp_n,
    output logic [1:0] ctx_align_n,
    output logic [7:0] ctx_font_px_n,
    output logic ctx_smooth_n,
    output logic signed [31:0] ctx_sx_n,
    output logic signed [31:0] ctx_sy_n,
    output logic signed [31:0] ctx_tx_n,
    output logic signed [31:0] ctx_ty_n,
    output logic [15:0] dbg_call_ovf_n,
    output logic [15:0] dbg_cb_ip_n,
    output logic [15:0] dbg_di_hit_n,
    output logic [15:0] dbg_di_miss_n,
    output logic [15:0] dbg_div_n_n,
    output logic [15:0] dbg_find_hit_n,
    output logic [15:0] dbg_heap_ovf_n,
    output logic [15:0] dbg_json_ovf_n,
    output logic [15:0] dbg_path_ovf_n,
    output logic [15:0] dbg_splice_n_n,
    output logic [15:0] dbg_stack_ovf_n,
    output logic [15:0] dbg_tmr_sched_n,
    output logic [15:0] dbg_to_ovf_n,
    output logic did_swap_n,
    output logic [5:0] div_cnt_n,
    output logic div_int_in_n,
    output logic div_neg_n,
    output logic [31:0] div_rem_n,
    output logic [31:0] div_ub_n,
    output logic [47:0] div_uq_n,
    output logic [5:0] env_free_n_n,
    output logic env_is_store_n,
    output logic [8:0] env_ld_slot_n,
    output logic [5:0] env_sp_n,
    output logic [15:0] env_walk_n,
    output logic [18:0] fb_dump_addr_n,
    output logic fb_dump_sel_n,
    output logic fb_swap_n,
    output logic [7:0] fill_style_i_n,
    output logic [7:0] fp_left_n,
    output logic [7:0] fpx_acc_n,
    output logic frame_fire_n,
    output logic [11:0] hp_aid_n,
    output logic [7:0] hp_alen_n,
    output logic [6:0] hp_aslot_n,
    output logic [3:0] hp_cmd_n,
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
    output logic [4:0] hp_ss_n,
    output logic [2:0] hp_tag_n,
    output logic [5:0] hp_tn_n,
    output logic hp_v64_n,
    output logic [11:0] hp_vbase_n,
    output logic [63:0] hp_wval_n,
    output logic [7:0] idx_needle_n,
    output logic [2:0] idx_t_n,
    output logic signed [31:0] idx_v_n,
    output logic imgd_armed_n,
    output logic [9:0] imgd_h_n,
    output logic [18:0] imgd_i_n,
    output logic [18:0] imgd_n_n,
    output logic [10:0] imgd_res_n,
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
    output logic [13:0] json_dst_n,
    output logic [2:0] json_pph_n,
    output logic [10:0] json_res_n,
    output logic [13:0] json_rp_n,
    output logic [13:0] json_src_n,
    output logic [13:0] json_srclen_n,
    output logic [13:0] json_wp_n,
    output logic [2:0] kd_n_n,
    output logic [15:0] kev_fn_n,
    output logic kev_is_down_n,
    output logic [1:0] kev_li_n,
    output logic [15:0] kev_obj_n,
    output logic [15:0] kev_ret_ip_n,
    output logic [15:0] keys_a_oid_n,
    output logic [15:0] keys_d_oid_n,
    output logic [15:0] keys_sp_oid_n,
    output logic [2:0] ku_n_n,
    output logic [31:0] lfsr_n,
    output logic looping_n,
    output logic [15:0] metrics_oid_n,
    output logic signed [31:0] mul_a_n,
    output logic signed [31:0] mul_b_n,
    output logic mul_fx_a_n,
    output logic mul_fx_b_n,
    output logic [15:0] n_arr_n,
    output logic [15:0] n_arr_keep_n,
    output logic [6:0] n_fn_proto_n,
    output logic [15:0] n_obj_n,
    output logic [15:0] n_obj_keep_n,
    output logic namcpy_armed_n,
    output logic namcpy_repl_n,
    output logic [15:0] name_rdaddr_n,
    output logic [7:0] nat_argc_n,
    output logic [7:0] nat_id_n,
    output logic path_active_n,
    output logic [1:0] path_kind_n,
    output logic path_stroke_n,
    output logic [4:0] pc_n_n,
    output logic [4:0] pi_n,
    output logic present_pend_n,
    output logic [3:0] raf_n_n,
    output logic [5:0] rel_i_n,
    output logic [5:0] rel_lim_n,
    output logic [5:0] rel_nn_n,
    output logic [6:0] rel_ret_n,
    output logic [5:0] rel_saved_n,
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
    output logic [10:0] sp_n,
    output logic [4:0] sq_i_n,
    output logic [47:0] sq_rad_n,
    output logic [25:0] sq_rem_n,
    output logic [23:0] sq_root_n,
    output logic [6:0] state_n,
    output logic signed [31:0] str_pf_ci_n,
    output logic [15:0] str_pf_id_n,
    output logic str_pf_ok_n,
    output logic [10:0] str_res_n,
    output logic [15:0] this_obj_n,
    output logic [6:0] to_n_n,
    output logic [15:0] to_seq_n,
    output logic [6:0] txt_bn_n,
    output logic [3:0] txt_ph_n,
    output logic signed [15:0] txt_px_n,
    output logic signed [15:0] txt_py_n,
    output logic [15:0] txt_rp_n,
    output logic [31:0] txt_val_n,
    output logic [2:0] txt_vt_n,
    output logic [11:0] vcall_argc_n,
    output logic [63:0] vcall_this_n,
    output logic [9:0] x_n,
    output logic [1:0] xf_dst_n,
    output logic signed [31:0] xf_h_n,
    output logic signed [31:0] xf_w_n,
    output logic signed [31:0] xf_x_n,
    output logic signed [31:0] xf_y_n,
    output logic [9:0] y_n,
    output logic [15:0] cstack_ctorobj_n [0:CSTK-1],
    output logic [5:0] cstack_env_n [0:CSTK-1],
    output logic [15:0] cstack_fe_arr_n [0:CSTK-1],
    output logic [15:0] cstack_fe_fn_n [0:CSTK-1],
    output logic [7:0] cstack_fe_i_n [0:CSTK-1],
    output logic [15:0] cstack_ip_n [0:CSTK-1],
    output logic cstack_isctor_n [0:CSTK-1],
    output logic cstack_isfe_n [0:CSTK-1],
    output logic [15:0] cstack_map_arr_n [0:CSTK-1],
    output logic [15:0] cstack_this_n [0:CSTK-1],
    output logic [15:0] fn_proto_ip_n [0:MAX_FN_PROTO-1],
    output logic [15:0] fn_proto_oid_n [0:MAX_FN_PROTO-1],
    output logic [15:0] hp_qk_n [0:3],
    output logic [2:0] hp_qt_n [0:3],
    output logic [63:0] hp_qv_n [0:3],
    output logic [7:0] js_i_n [0:JSON_STK-1],
    output logic [2:0] js_ph_n [0:JSON_STK-1],
    output logic [2:0] js_tag_n [0:JSON_STK-1],
    output logic [31:0] js_val_n [0:JSON_STK-1],
    output logic [15:0] kd_slot_n [0:3],
    output logic [15:0] ku_slot_n [0:3],
    output logic signed [31:0] pc_a1_n [0:PATH_MAX-1],
    output logic signed [31:0] pc_a2_n [0:PATH_MAX-1],
    output logic signed [31:0] pc_a3_n [0:PATH_MAX-1],
    output logic signed [31:0] pc_a4_n [0:PATH_MAX-1],
    output logic signed [31:0] pc_a5_n [0:PATH_MAX-1],
    output logic pc_ccw_n [0:PATH_MAX-1],
    output logic [1:0] pc_op_n [0:PATH_MAX-1],
    output logic [15:0] raf_fn_n [0:7],
    output logic [11:0] to_delay_n [0:TIMER_DEPTH-1],
    output logic [15:0] to_fn_n [0:TIMER_DEPTH-1],
    output logic [15:0] to_id_n [0:TIMER_DEPTH-1],
    output logic [11:0] to_period_n [0:TIMER_DEPTH-1],
    output logic arr_len_we,
    output logic [11:0] arr_len_waddr,
    output logic [7:0] arr_len_wdata,
    output logic env_cap_we,
    output logic [11:0] env_cap_waddr,
    output logic [31:0] env_cap_wdata,
    output logic env_oid_we,
    output logic [11:0] env_oid_waddr,
    output logic [15:0] env_oid_wdata,
    output logic json_mem_we,
    output logic [12:0] json_mem_waddr,
    output logic [7:0] json_mem_wdata,
    output logic obj_cls_we,
    output logic [11:0] obj_cls_waddr,
    output logic [15:0] obj_cls_wdata,
    output logic obj_n_we,
    output logic [11:0] obj_n_waddr,
    output logic [5:0] obj_n_wdata,
    output logic stack_we,
    output logic [11:0] stack_waddr,
    output logic signed [31:0] stack_wdata,
    output logic stack_tag_we,
    output logic [11:0] stack_tag_waddr,
    output logic [2:0] stack_tag_wdata,
    output logic tenv_parent_we,
    output logic [11:0] tenv_parent_waddr,
    output logic [15:0] tenv_parent_wdata,
    output logic tfn_entry_we,
    output logic [11:0] tfn_entry_waddr,
    output logic [15:0] tfn_entry_wdata,
    output logic tfn_has_this_we,
    output logic [11:0] tfn_has_this_waddr,
    output logic [31:0] tfn_has_this_wdata,
    output logic tfn_nparam_we,
    output logic [11:0] tfn_nparam_waddr,
    output logic [7:0] tfn_nparam_wdata,
    output logic tfn_parent_we,
    output logic [11:0] tfn_parent_waddr,
    output logic [15:0] tfn_parent_wdata,
    output logic tfn_this_we,
    output logic [11:0] tfn_this_waddr,
    output logic [15:0] tfn_this_wdata,
    output logic tfn_this_tag_we,
    output logic [11:0] tfn_this_tag_waddr,
    output logic [2:0] tfn_this_tag_wdata,
    output logic var_init_we,
    output logic [11:0] var_init_waddr,
    output logic [31:0] var_init_wdata,
    output logic var_tag_we,
    output logic [11:0] var_tag_waddr,
    output logic [2:0] var_tag_wdata,
    output logic vars_we,
    output logic [11:0] vars_waddr,
    output logic signed [31:0] vars_wdata,
    output logic vobj_len_we,
    output logic [11:0] vobj_len_waddr,
    output logic [5:0] vobj_len_wdata
);

    // Sequential cell so Vivado keep_hierarchy is not dissolved as combo-only.
    logic hier_keep;
    always_ff @(posedge clk) if (enable) hier_keep <= ~hier_keep;

    logic signed [31:0] a_s;
    logic [52:0] mb;
    `define VST_REL(addr) (((((vsp)>(addr)) && (((vsp)-(addr)-12'd1)<12'd16))) ? 4'((vsp)-(addr)-12'd1) : 4'd0)
    `define VST_AT(addr) vst_peek[`VST_REL(addr)]

    function automatic logic [7:0] sat8(input logic signed [31:0] v);
        if (v < 0) sat8 = 8'd0;
        else if (v > 255) sat8 = 8'd255;
        else sat8 = 8'(v);
    endfunction
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
    function automatic logic signed [31:0] f32_to_fx(input logic [31:0] bits);
        logic [7:0] exp;
        logic [23:0] mant;
        logic signed [31:0] mag;
        exp = bits[30:23];
        mant = {1'b1, bits[22:0]};
        if (exp == 8'd0 || exp < 8'd103)          // |v| < 2^-24 → 0
            mag = 32'sd0;
        else if (exp >= 8'd142)                    // |v| >= 2^15 clamps Q16.16
            mag = 32'sd2147483647;
        else if (exp >= 8'd134)                    // v×2^16 = mant×2^(exp-134)
            mag = $signed({8'd0, mant} << (exp - 8'd134));
        else
            mag = $signed({8'd0, mant} >> (8'd134 - exp));
        f32_to_fx = bits[31] ? -mag : mag;
    endfunction
    // NEW: tag-aware int read — Q16.16 (tag 7) floors to i32, others pass through
    function automatic logic signed [31:0] fxi(
        input logic signed [31:0] v, input logic [2:0] t);
        fxi = (t == 3'd7) ? (v >>> 16) : v;
    endfunction
    // NEW: lift an int operand into Q16.16 when its partner is fx
    function automatic logic signed [31:0] fxlift(
        input logic signed [31:0] v, input logic [2:0] t, input logic pair_fx);
        fxlift = (pair_fx && t != 3'd7) ? (v <<< 16) : v;
    endfunction
    // NEW: stack read floored to int — draw/native args must not see raw Q16.16
    function automatic logic signed [31:0] sti(input logic [10:0] i);
        sti = (stack_tag[i] == 3'd7) ? (stack[i] >>> 16) : stack[i];
    endfunction
    // NEW: stack read AS Q16.16 — scaled draws keep the fraction until the
    // final int() like FM _xf (int lifts <<16, fx passes raw)
    function automatic logic signed [31:0] stfx(input logic [10:0] i);
        stfx = (stack_tag[i] == 3'd7) ? stack[i] : (stack[i] <<< 16);
    endfunction
    function automatic logic [15:0] fn_entry(input logic [15:0] oid);
        fn_entry = tfn_entry[oid[12:0]];
    endfunction
    function automatic logic [7:0] fn_nparam(input logic [15:0] oid);
        fn_nparam = tfn_nparam[oid[12:0]];
    endfunction
    task automatic commit_obj_keep(input logic [2:0] tag, input logic [15:0] oid);
        if (obj_keep_ok && (tag == 3'd1 || tag == 3'd4) && oid >= n_obj_keep)
            n_obj_keep_n = oid + 16'd1;
    endtask
    task automatic commit_deep_keep(input logic [2:0] tag);
        if (tag == 3'd1 || tag == 3'd4 || tag == 3'd2) begin
            if (obj_keep_ok && n_obj > n_obj_keep) n_obj_keep_n = n_obj;
            if (arr_keep_ok && n_arr > n_arr_keep) n_arr_keep_n = n_arr;
        end
    endtask
    task automatic bump_csp();
        if (csp >= 7'(CSTK - 1))
            dbg_call_ovf_n = dbg_call_ovf + 16'd1;
        else
            csp_n = csp + 7'd1;
    endtask
    task automatic boundary_sp(input logic [10:0] next_sp);
        // One callback return value is permitted; anything more is a real
        // stack-balance defect and must remain visible as a machine fault.
        if (sp > 11'd1) dbg_stack_ovf_n = dbg_stack_ovf + 16'd1;
        sp_n = next_sp;
    endtask
    task automatic push_fresh_env(input logic [15:0] parent);
        logic [15:0] oid;
        if (env_sp < TAGGED_ENV_DEPTH[5:0]) begin
            if (env_free_n != 6'd0) begin
                oid = env_free[env_free_n - 6'd1];
                env_free_n_n = env_free_n - 6'd1;
            end else begin
                oid = n_obj;
                if (n_obj >= 16'(MAX_OBJ - 1)) dbg_heap_ovf_n = dbg_heap_ovf + 16'd1;
                n_obj_n = (n_obj >= 16'(MAX_OBJ - 1)) ? n_obj : (n_obj + 16'd1);
            end
            begin obj_cls_we = 1'b1; obj_cls_waddr = oid[12:0]; obj_cls_wdata = CLS_ENV; end
            begin obj_n_we = 1'b1; obj_n_waddr = oid[12:0]; obj_n_wdata = 6'd1; end
            begin tenv_parent_we = 1'b1; tenv_parent_waddr = oid[12:0]; tenv_parent_wdata = parent; end
            begin vobj_len_we = 1'b1; vobj_len_waddr = oid[12:0]; vobj_len_wdata = 6'd1; end
            begin env_oid_we = 1'b1; env_oid_waddr = env_sp; env_oid_wdata = oid; end
            begin env_cap_we = 1'b1; env_cap_waddr = env_sp; env_cap_wdata = 1'b0; end
            env_sp_n = env_sp + 6'd1;
        end
    endtask
    task automatic enter_captured_fn(input logic [15:0] foid);
        logic [12:0] fo;
        logic [15:0] parent;
        fo = foid[12:0];
        parent = (obj_n[fo] > 6'd2) ? tfn_parent[fo] : 16'd0;
        cstack_env_n[csp] = env_sp;
        push_fresh_env(parent);
        // Fn slot3 is the receiver captured by an arrow or a materialized
        // class method. Regular callbacks deliberately enter with no `this`.
        if (obj_n[fo] > 6'd3 && tfn_has_this[fo]) begin
            this_obj_n = tfn_this[fo];
            if (this_ok) begin
                begin vars_we = 1'b1; vars_waddr = var_this; vars_wdata = {16'd0, tfn_this[fo]}; end
                begin var_tag_we = 1'b1; var_tag_waddr = var_this; var_tag_wdata = tfn_this_tag[fo]; end
            end
        end else begin
            this_obj_n = 16'hFFFF;
            if (this_ok) begin
                begin vars_we = 1'b1; vars_waddr = var_this; vars_wdata = 32'd0; end
                begin var_tag_we = 1'b1; var_tag_waddr = var_this; var_tag_wdata = 3'd5; end
            end
        end
    endtask
    task automatic add_key_listener(input logic is_down, input logic [15:0] fn);
        integer i;
        logic dup;
        dup = 1'b0;
        if (is_down) begin
            for (i = 0; i < 4; i++)
                if (i < kd_n && kd_slot[i] == fn) dup = 1'b1;
            if (!dup && kd_n < 3'd4) begin
                kd_slot_n[kd_n] = fn;
                kd_n_n = kd_n + 3'd1;
            end
        end else begin
            for (i = 0; i < 4; i++)
                if (i < ku_n && ku_slot[i] == fn) dup = 1'b1;
            if (!dup && ku_n < 3'd4) begin
                ku_slot_n[ku_n] = fn;
                ku_n_n = ku_n + 3'd1;
            end
        end
    endtask
    task automatic remove_key_listener(input logic is_down, input logic [15:0] fn);
        integer i, j;
        if (is_down) begin
            j = 0;
            for (i = 0; i < 4; i++) begin
                if (i < kd_n && kd_slot[i] != fn) begin
                    kd_slot_n[j] = kd_slot[i];
                    j = j + 1;
                end
            end
            kd_n_n = 3'(j);
            // Synth 8-3380: trip count must be constant (j is runtime).
            for (i = 0; i < 4; i++)
                if (i >= j) kd_slot_n[i] = 16'hFFFF;
        end else begin
            j = 0;
            for (i = 0; i < 4; i++) begin
                if (i < ku_n && ku_slot[i] != fn) begin
                    ku_slot_n[j] = ku_slot[i];
                    j = j + 1;
                end
            end
            ku_n_n = 3'(j);
            for (i = 0; i < 4; i++)
                if (i >= j) ku_slot_n[i] = 16'hFFFF;
        end
    endtask
    task automatic arm_release_env(input logic [5:0] saved, input st_t nxt);
        rel_saved_n = saved;
        rel_lim_n = env_sp;
        rel_i_n = saved;
        rel_nn_n = env_free_n;
        rel_ret_n = nxt;
        state_n = S_REL_ENV;
    endtask
    task automatic json_putc(input logic [7:0] ch);
        if (json_wp < 14'(JSON_CAP)) begin
            begin json_mem_we = 1'b1; json_mem_waddr = json_wp[12:0]; json_mem_wdata = ch; end
            json_wp_n = json_wp + 14'd1;
        end else dbg_json_ovf_n = dbg_json_ovf + 16'd1;
    endtask
    task automatic next_op;
        ip_n = ip + 16'd1;
        code_raddr_n = 15'(ops_base + ip + 16'd1);
        state_n = S_FETCH_WAIT;
    endtask

    always_comb begin
        alu_a_n = alu_a;
        alu_b_n = alu_b;
        alu_fx_n = alu_fx;
        alu_op_n = alu_op;
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
        click_fired_n = click_fired;
        click_fn_n = click_fn;
        clr_idx_n = clr_idx;
        code_raddr_n = code_raddr;
        color_n = color;
        csp_n = csp;
        ctx_align_n = ctx_align;
        ctx_font_px_n = ctx_font_px;
        ctx_smooth_n = ctx_smooth;
        ctx_sx_n = ctx_sx;
        ctx_sy_n = ctx_sy;
        ctx_tx_n = ctx_tx;
        ctx_ty_n = ctx_ty;
        dbg_call_ovf_n = dbg_call_ovf;
        dbg_cb_ip_n = dbg_cb_ip;
        dbg_di_hit_n = dbg_di_hit;
        dbg_di_miss_n = dbg_di_miss;
        dbg_div_n_n = dbg_div_n;
        dbg_find_hit_n = dbg_find_hit;
        dbg_heap_ovf_n = dbg_heap_ovf;
        dbg_json_ovf_n = dbg_json_ovf;
        dbg_path_ovf_n = dbg_path_ovf;
        dbg_splice_n_n = dbg_splice_n;
        dbg_stack_ovf_n = dbg_stack_ovf;
        dbg_tmr_sched_n = dbg_tmr_sched;
        dbg_to_ovf_n = dbg_to_ovf;
        did_swap_n = did_swap;
        div_cnt_n = div_cnt;
        div_int_in_n = div_int_in;
        div_neg_n = div_neg;
        div_rem_n = div_rem;
        div_ub_n = div_ub;
        div_uq_n = div_uq;
        env_free_n_n = env_free_n;
        env_is_store_n = env_is_store;
        env_ld_slot_n = env_ld_slot;
        env_sp_n = env_sp;
        env_walk_n = env_walk;
        fb_dump_addr_n = fb_dump_addr;
        fb_dump_sel_n = fb_dump_sel;
        fb_swap_n = fb_swap;
        fill_style_i_n = fill_style_i;
        fp_left_n = fp_left;
        fpx_acc_n = fpx_acc;
        frame_fire_n = frame_fire;
        hp_aid_n = hp_aid;
        hp_alen_n = hp_alen;
        hp_aslot_n = hp_aslot;
        hp_cmd_n = hp_cmd;
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
        hp_ss_n = hp_ss;
        hp_tag_n = hp_tag;
        hp_tn_n = hp_tn;
        hp_v64_n = hp_v64;
        hp_vbase_n = hp_vbase;
        hp_wval_n = hp_wval;
        idx_needle_n = idx_needle;
        idx_t_n = idx_t;
        idx_v_n = idx_v;
        imgd_armed_n = imgd_armed;
        imgd_h_n = imgd_h;
        imgd_i_n = imgd_i;
        imgd_n_n = imgd_n;
        imgd_res_n = imgd_res;
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
        json_dst_n = json_dst;
        json_pph_n = json_pph;
        json_res_n = json_res;
        json_rp_n = json_rp;
        json_src_n = json_src;
        json_srclen_n = json_srclen;
        json_wp_n = json_wp;
        kd_n_n = kd_n;
        kev_fn_n = kev_fn;
        kev_is_down_n = kev_is_down;
        kev_li_n = kev_li;
        kev_obj_n = kev_obj;
        kev_ret_ip_n = kev_ret_ip;
        keys_a_oid_n = keys_a_oid;
        keys_d_oid_n = keys_d_oid;
        keys_sp_oid_n = keys_sp_oid;
        ku_n_n = ku_n;
        lfsr_n = lfsr;
        looping_n = looping;
        metrics_oid_n = metrics_oid;
        mul_a_n = mul_a;
        mul_b_n = mul_b;
        mul_fx_a_n = mul_fx_a;
        mul_fx_b_n = mul_fx_b;
        n_arr_n = n_arr;
        n_arr_keep_n = n_arr_keep;
        n_fn_proto_n = n_fn_proto;
        n_obj_n = n_obj;
        n_obj_keep_n = n_obj_keep;
        namcpy_armed_n = namcpy_armed;
        namcpy_repl_n = namcpy_repl;
        name_rdaddr_n = name_rdaddr;
        nat_argc_n = nat_argc;
        nat_id_n = nat_id;
        path_active_n = path_active;
        path_kind_n = path_kind;
        path_stroke_n = path_stroke;
        pc_n_n = pc_n;
        pi_n = pi;
        present_pend_n = present_pend;
        raf_n_n = raf_n;
        rel_i_n = rel_i;
        rel_lim_n = rel_lim;
        rel_nn_n = rel_nn;
        rel_ret_n = rel_ret;
        rel_saved_n = rel_saved;
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
        sp_n = sp;
        sq_i_n = sq_i;
        sq_rad_n = sq_rad;
        sq_rem_n = sq_rem;
        sq_root_n = sq_root;
        state_n = state;
        str_pf_ci_n = str_pf_ci;
        str_pf_id_n = str_pf_id;
        str_pf_ok_n = str_pf_ok;
        str_res_n = str_res;
        this_obj_n = this_obj;
        to_n_n = to_n;
        to_seq_n = to_seq;
        txt_bn_n = txt_bn;
        txt_ph_n = txt_ph;
        txt_px_n = txt_px;
        txt_py_n = txt_py;
        txt_rp_n = txt_rp;
        txt_val_n = txt_val;
        txt_vt_n = txt_vt;
        vcall_argc_n = vcall_argc;
        vcall_this_n = vcall_this;
        x_n = x;
        xf_dst_n = xf_dst;
        xf_h_n = xf_h;
        xf_w_n = xf_w;
        xf_x_n = xf_x;
        xf_y_n = xf_y;
        y_n = y;
        cstack_ctorobj_n = cstack_ctorobj;
        cstack_env_n = cstack_env;
        cstack_fe_arr_n = cstack_fe_arr;
        cstack_fe_fn_n = cstack_fe_fn;
        cstack_fe_i_n = cstack_fe_i;
        cstack_ip_n = cstack_ip;
        cstack_isctor_n = cstack_isctor;
        cstack_isfe_n = cstack_isfe;
        cstack_map_arr_n = cstack_map_arr;
        cstack_this_n = cstack_this;
        fn_proto_ip_n = fn_proto_ip;
        fn_proto_oid_n = fn_proto_oid;
        hp_qk_n = hp_qk;
        hp_qt_n = hp_qt;
        hp_qv_n = hp_qv;
        js_i_n = js_i;
        js_ph_n = js_ph;
        js_tag_n = js_tag;
        js_val_n = js_val;
        kd_slot_n = kd_slot;
        ku_slot_n = ku_slot;
        pc_a1_n = pc_a1;
        pc_a2_n = pc_a2;
        pc_a3_n = pc_a3;
        pc_a4_n = pc_a4;
        pc_a5_n = pc_a5;
        pc_ccw_n = pc_ccw;
        pc_op_n = pc_op;
        raf_fn_n = raf_fn;
        to_delay_n = to_delay;
        to_fn_n = to_fn;
        to_id_n = to_id;
        to_period_n = to_period;
        arr_len_we = 1'b0;
        arr_len_waddr = '0;
        arr_len_wdata = '0;
        env_cap_we = 1'b0;
        env_cap_waddr = '0;
        env_cap_wdata = '0;
        env_oid_we = 1'b0;
        env_oid_waddr = '0;
        env_oid_wdata = '0;
        json_mem_we = 1'b0;
        json_mem_waddr = '0;
        json_mem_wdata = '0;
        obj_cls_we = 1'b0;
        obj_cls_waddr = '0;
        obj_cls_wdata = '0;
        obj_n_we = 1'b0;
        obj_n_waddr = '0;
        obj_n_wdata = '0;
        stack_we = 1'b0;
        stack_waddr = '0;
        stack_wdata = '0;
        stack_tag_we = 1'b0;
        stack_tag_waddr = '0;
        stack_tag_wdata = '0;
        tenv_parent_we = 1'b0;
        tenv_parent_waddr = '0;
        tenv_parent_wdata = '0;
        tfn_entry_we = 1'b0;
        tfn_entry_waddr = '0;
        tfn_entry_wdata = '0;
        tfn_has_this_we = 1'b0;
        tfn_has_this_waddr = '0;
        tfn_has_this_wdata = '0;
        tfn_nparam_we = 1'b0;
        tfn_nparam_waddr = '0;
        tfn_nparam_wdata = '0;
        tfn_parent_we = 1'b0;
        tfn_parent_waddr = '0;
        tfn_parent_wdata = '0;
        tfn_this_we = 1'b0;
        tfn_this_waddr = '0;
        tfn_this_wdata = '0;
        tfn_this_tag_we = 1'b0;
        tfn_this_tag_waddr = '0;
        tfn_this_tag_wdata = '0;
        var_init_we = 1'b0;
        var_init_waddr = '0;
        var_init_wdata = '0;
        var_tag_we = 1'b0;
        var_tag_waddr = '0;
        var_tag_wdata = '0;
        vars_we = 1'b0;
        vars_waddr = '0;
        vars_wdata = '0;
        vobj_len_we = 1'b0;
        vobj_len_waddr = '0;
        vobj_len_wdata = '0;
        if (enable) begin
            if (state == S_EXEC) begin
                    if (ip >= n_ops) begin
                        // One implicit present per FRAME, not per pass: mark the
                        // pass end and let S_WAIT_FRAME swap once at frame_tick
                        // after every callback of this frame (rAF + timers +
                        // key listeners) has run — same order the FM presents.
                        present_pend_n = 1'b1;
                        state_n = S_WAIT_FRAME;
                    end else begin
                        // Plain case: unique made Vivado build every opcode
                        // in parallel (~100 GB, no bitstream). Small unique
                        // cases elsewhere stay.
                        case (code_rdata[7:0])
                            OP_LOAD_CONST: begin
                                // a1: 0=i32 1=str intern 2=undef 3=float bits→int
                                if (code_rdata[31:24] == 8'd1) begin
                                    begin stack_we = 1'b1; stack_waddr = sp; stack_wdata = {16'd0, code_rdata[23:8]}; end
                                    begin stack_tag_we = 1'b1; stack_tag_waddr = sp; stack_tag_wdata = 3'd3; end
                                end else if (code_rdata[31:24] == 8'd2) begin
                                    begin stack_we = 1'b1; stack_waddr = sp; stack_wdata = 32'sd0; end
                                    begin stack_tag_we = 1'b1; stack_tag_waddr = sp; stack_tag_wdata = 3'd5; end
                                end else if (code_rdata[31:24] == 8'd3) begin
                                    // NEW: float const → Q16.16 fixed (tag 7) — real
                                    // fractions (0.12 ship scale, PACMAN *.5 speeds)
                                    begin stack_we = 1'b1; stack_waddr = sp; stack_wdata = f32_to_fx(consts[code_rdata[17:8]]); end
                                    begin stack_tag_we = 1'b1; stack_tag_waddr = sp; stack_tag_wdata = 3'd7; end
                                end else if (code_rdata[31:24] == 8'd4) begin
                                    // NEW: RegExp stub — packed pattern+flags in const pool
                                    begin obj_cls_we = 1'b1; obj_cls_waddr = n_obj[12:0]; obj_cls_wdata = CLS_REGEX; end
                                    begin obj_n_we = 1'b1; obj_n_waddr = n_obj[12:0]; obj_n_wdata = 6'd1; end
                                    begin stack_we = 1'b1; stack_waddr = sp; stack_wdata = {16'd0, n_obj}; end
                                    begin stack_tag_we = 1'b1; stack_tag_waddr = sp; stack_tag_wdata = 3'd1; end
                                    if (n_obj >= 16'(MAX_OBJ - 1)) dbg_heap_ovf_n = dbg_heap_ovf + 16'd1;
                                    hp_cmd_n = HP_OSETI;
                                    hp_v64_n = 1'b0;
                                    hp_oid_n = n_obj[12:0];
                                    hp_slot_n = 5'd0;
                                    hp_qn_n = 3'd1;
                                    hp_qi_n = 3'd0;
                                    hp_qk_n[0] = 16'd0;
                                    hp_qv_n[0] = {32'd0, consts[code_rdata[17:8]]};
                                    hp_qt_n[0] = 3'd0;
                                    hp_ret_n = S_FETCH_WAIT;
                                    n_obj_n = (n_obj >= 16'(MAX_OBJ - 1)) ? n_obj : (n_obj + 16'd1);
                                    sp_n = sp + 8'd1;
                                    ip_n = ip + 16'd1;
                                    code_raddr_n = 15'(ops_base + ip + 16'd1);
                                    state_n = S_HEAP_WR;
                                end else begin
                                    begin stack_we = 1'b1; stack_waddr = sp; stack_wdata = consts[code_rdata[17:8]]; end
                                    begin stack_tag_we = 1'b1; stack_tag_waddr = sp; stack_tag_wdata = 3'd0; end
                                end
                                if (code_rdata[31:24] != 8'd4) begin
                                sp_n = sp + 8'd1;
                                next_op();
                                end
                            end
                            OP_LOAD_VAR: begin
                                if (env_sp != 0) begin
                                    env_walk_n = env_oid[env_sp - 6'd1];
                                    env_ld_slot_n = code_rdata[16:8];
                                    env_is_store_n = 1'b0;
                                    hp_slot_n = 5'd1;
                                    hp_phase_n = 3'd0;
                                    ip_n = ip + 16'd1;
                                    state_n = S_ENV_LOAD;
                                end else begin
                                    begin stack_we = 1'b1; stack_waddr = sp; stack_wdata = vars[code_rdata[16:8]]; end
                                    begin stack_tag_we = 1'b1; stack_tag_waddr = sp; stack_tag_wdata = var_tag[code_rdata[16:8]]; end
                                    sp_n = sp + 8'd1;
                                    next_op();
                                end
                            end
                            OP_STORE_VAR: begin
                                if (env_sp != 0) begin
                                    env_walk_n = env_oid[env_sp - 6'd1];
                                    env_ld_slot_n = code_rdata[16:8];
                                    env_is_store_n = 1'b1;
                                    hp_slot_n = 5'd1;
                                    hp_phase_n = 3'd0;
                                    ip_n = ip + 16'd1;
                                    state_n = S_ENV_LOAD;
                                end else begin
                                    begin vars_we = 1'b1; vars_waddr = code_rdata[16:8]; vars_wdata = stack[sp - 8'd1]; end
                                    begin var_tag_we = 1'b1; var_tag_waddr = code_rdata[16:8]; var_tag_wdata = stack_tag[sp - 8'd1]; end
                                    begin var_init_we = 1'b1; var_init_waddr = code_rdata[16:8]; var_init_wdata = 1'b1; end
                                    sp_n = sp - 8'd1;
                                    next_op();
                                end
                            end
                            OP_LET_VAR: begin
                                // NEW: a1 bit0 = call-frame local — upsert into
                                // the LIFO env so nested MAKE_FN can snapshot it.
                                if (code_rdata[24] || !var_init[code_rdata[16:8]]) begin
                                    begin vars_we = 1'b1; vars_waddr = code_rdata[16:8]; vars_wdata = stack[sp - 8'd1]; end
                                    begin var_tag_we = 1'b1; var_tag_waddr = code_rdata[16:8]; var_tag_wdata = stack_tag[sp - 8'd1]; end
                                    begin var_init_we = 1'b1; var_init_waddr = code_rdata[16:8]; var_init_wdata = 1'b1; end
                                end
                                if (code_rdata[24] && env_sp != 0) begin
                                    hp_cmd_n = HP_SETPROP;
                                    hp_v64_n = 1'b0;
                                    hp_oid_n = env_oid[env_sp - 6'd1][12:0];
                                    hp_key_n = {7'd0, code_rdata[16:8]};
                                    hp_wval_n = {32'd0, stack[sp - 8'd1]};
                                    hp_tag_n = stack_tag[sp - 8'd1];
                                    hp_len_n = obj_n[env_oid[env_sp - 6'd1][12:0]];
                                    hp_slot_n = 5'd0;
                                    hp_phase_n = 3'd0;
                                    state_n = S_HEAP_WAIT;
                                end else begin
                                sp_n = sp - 8'd1;
                                next_op();
                                end
                            end
                            OP_ADD: begin
                                if (stack_tag[sp - 8'd2] == 3'd3 ||
                                    stack_tag[sp - 8'd1] == 3'd3) begin
                                    // NEW: string concat — fold both operands into the
                                    // encoder u16 hash, then find-or-alloc an intern id.
                                    // PACMAN event keys: 's'+_index, 's1i'+id
                                    cc_av_n = stack[sp - 8'd2]; cc_at_n = stack_tag[sp - 8'd2];
                                    cc_bv_n = stack[sp - 8'd1]; cc_bt_n = stack_tag[sp - 8'd1];
                                    cc_second_n = 1'b0; cc_st_n = 2'd0;
                                    cc_h_n = 16'd0; cc_len_n = 8'd0; cc_d_n = 4'd0;
                                    // NEW: rebuild the characters too (txt_buf)
                                    cc_bok_n = 1'b1; txt_bn_n = 7'd0;
                                    jn_res_n = 11'(sp - 8'd2);
                                    sp_n = sp - 8'd1;
                                    ip_n = ip + 16'd1;
                                    state_n = S_CONCAT;
                                end else begin
                                    // NEW: mixed Q16.16 — lift the int side when the other is fx
                                    alu_fx_n = (stack_tag[sp - 8'd2] == 3'd7 || stack_tag[sp - 8'd1] == 3'd7);
                                    alu_a_n = fxlift(stack[sp - 8'd2], stack_tag[sp - 8'd2],
                                                    stack_tag[sp - 8'd1] == 3'd7);
                                    alu_b_n = fxlift(stack[sp - 8'd1], stack_tag[sp - 8'd1],
                                                    stack_tag[sp - 8'd2] == 3'd7);
                                    alu_op_n = 3'd0;
                                    sp_n = sp - 8'd1;
                                    state_n = S_ALU;
                                end
                            end
                            OP_SUB: begin
                                alu_fx_n = (stack_tag[sp - 8'd2] == 3'd7 || stack_tag[sp - 8'd1] == 3'd7);
                                alu_a_n = fxlift(stack[sp - 8'd2], stack_tag[sp - 8'd2],
                                                stack_tag[sp - 8'd1] == 3'd7);
                                alu_b_n = fxlift(stack[sp - 8'd1], stack_tag[sp - 8'd1],
                                                stack_tag[sp - 8'd2] == 3'd7);
                                alu_op_n = 3'd1;
                                sp_n = sp - 8'd1;
                                state_n = S_ALU;
                            end
                            OP_MUL: begin
                                // NEW: register operands, multiply next cycle (timing)
                                mul_a_n = stack[sp - 8'd2];
                                mul_b_n = stack[sp - 8'd1];
                                mul_fx_a_n = (stack_tag[sp - 8'd2] == 3'd7);
                                mul_fx_b_n = (stack_tag[sp - 8'd1] == 3'd7);
                                state_n = S_MUL;
                            end
                            OP_DIV: begin
                                // NEW: multi-cycle divide (see S_DIV) — the old
                                // single-cycle '/' blew board timing (WNS −90 ns).
                                // JS-honest: quotient computed in Q16.16 ((N<<16)/D
                                // after lifting both to fx); int/int exact stays int
                                // (indices), inexact becomes fx (DONKEY 640/1510).
                                if (stack[sp - 8'd1] == 0) begin
                                    begin stack_we = 1'b1; stack_waddr = sp - 8'd2; stack_wdata = 32'sd0; end
                                    begin stack_tag_we = 1'b1; stack_tag_waddr = sp - 8'd2; stack_tag_wdata = 3'd0; end
                                    sp_n = sp - 8'd1;
                                    next_op();
                                // NEW: 1-cycle /2 (arithmetic shift). `cell/2` and
                                // `width/2` were 48 restoring steps each; a frame of
                                // those loops paid millions of clocks. Shift is
                                // JS-honest: even/even stays int, odd/2 is fx (5/2).
                                end else if (stack_tag[sp - 8'd1] != 3'd7 &&
                                             (stack[sp - 8'd1] == 32'sd2 ||
                                              stack[sp - 8'd1] == -32'sd2) &&
                                             stack[sp - 8'd2] != 32'sh80000000) begin
                                    if (stack_tag[sp - 8'd2] == 3'd7) begin
                                        stack_we = 1'b1; stack_waddr = sp - 8'd2; stack_wdata = stack[sp - 8'd1][31]
                                            ? -32'(stack[sp - 8'd2] >>> 1)
                                            : 32'(stack[sp - 8'd2] >>> 1);
                                        begin stack_tag_we = 1'b1; stack_tag_waddr = sp - 8'd2; stack_tag_wdata = 3'd7; end
                                    end else if (!stack[sp - 8'd2][0]) begin
                                        stack_we = 1'b1; stack_waddr = sp - 8'd2; stack_wdata = stack[sp - 8'd1][31]
                                            ? -32'(stack[sp - 8'd2] >>> 1)
                                            : 32'(stack[sp - 8'd2] >>> 1);
                                        begin stack_tag_we = 1'b1; stack_tag_waddr = sp - 8'd2; stack_tag_wdata = 3'd0; end
                                    end else begin
                                        stack_we = 1'b1; stack_waddr = sp - 8'd2; stack_wdata = stack[sp - 8'd1][31]
                                            ? -32'(stack[sp - 8'd2] <<< 15)
                                            : 32'(stack[sp - 8'd2] <<< 15);
                                        begin stack_tag_we = 1'b1; stack_tag_waddr = sp - 8'd2; stack_tag_wdata = 3'd7; end
                                    end
                                    sp_n = sp - 8'd1;
                                    next_op();
                                end else begin
                                    logic signed [31:0] na, nb;
                                    na = fxlift(stack[sp - 8'd2], stack_tag[sp - 8'd2], 1'b1);
                                    nb = fxlift(stack[sp - 8'd1], stack_tag[sp - 8'd1], 1'b1);
                                    div_int_in_n = (stack_tag[sp - 8'd2] != 3'd7 &&
                                                   stack_tag[sp - 8'd1] != 3'd7);
                                    div_neg_n = na[31] ^ nb[31];
                                    // 48-bit dividend = |N| << 16 (fx quotient)
                                    div_uq_n = {(na[31] ? 32'(-na) : 32'(na)), 16'd0};
                                    div_ub_n = nb[31] ? 32'(-nb) : 32'(nb);
                                    div_rem_n = '0;
                                    div_cnt_n = '0;
                                    dbg_div_n_n = dbg_div_n + 16'd1;
                                    state_n = S_DIV;
                                end
                            end
                            OP_LT: begin
                                alu_fx_n = 1'b0;  // compares always yield i32 bool
                                alu_a_n = fxlift(stack[sp - 8'd2], stack_tag[sp - 8'd2],
                                                stack_tag[sp - 8'd1] == 3'd7);
                                alu_b_n = fxlift(stack[sp - 8'd1], stack_tag[sp - 8'd1],
                                                stack_tag[sp - 8'd2] == 3'd7);
                                alu_op_n = 3'd2;
                                sp_n = sp - 8'd1;
                                state_n = S_ALU;
                            end
                            OP_GT: begin
                                alu_fx_n = 1'b0;
                                alu_a_n = fxlift(stack[sp - 8'd2], stack_tag[sp - 8'd2],
                                                stack_tag[sp - 8'd1] == 3'd7);
                                alu_b_n = fxlift(stack[sp - 8'd1], stack_tag[sp - 8'd1],
                                                stack_tag[sp - 8'd2] == 3'd7);
                                alu_op_n = 3'd3;
                                sp_n = sp - 8'd1;
                                state_n = S_ALU;
                            end
                            OP_EQ: begin
                                if (stack_tag[sp - 8'd2] == 3'd5 ||
                                    stack_tag[sp - 8'd1] == 3'd5) begin
                                    // NEW: undefined equals only undefined — FM
                                    // (None == 0) is False; value-only compare made
                                    // PACMAN skip its whole frame (update()!=false)
                                    stack_we = 1'b1; stack_waddr = sp - 8'd2; stack_wdata =
                                        (stack_tag[sp - 8'd2] == stack_tag[sp - 8'd1])
                                        ? 32'sd1 : 32'sd0;
                                    begin stack_tag_we = 1'b1; stack_tag_waddr = sp - 8'd2; stack_tag_wdata = 3'd0; end
                                    sp_n = sp - 8'd1;
                                    next_op();
                                end else if (stack_tag[sp - 8'd2] == 3'd3 &&
                                           stack_tag[sp - 8'd1] == 3'd3) begin
                                    // Intern strings: same id, or same hash+len
                                    // (e.key === " " when KEYEVT intern aliases).
                                    begin
                                        logic [9:0] ia, ib;
                                        ia = stack[sp - 8'd2][9:0];
                                        ib = stack[sp - 8'd1][9:0];
                                        stack_we = 1'b1; stack_waddr = sp - 8'd2; stack_wdata =
                                            (stack[sp - 8'd2][15:0] == stack[sp - 8'd1][15:0] ||
                                             (name_hash_tbl[ia] == name_hash_tbl[ib] &&
                                              name_len_tbl[ia] == name_len_tbl[ib] &&
                                              name_len_tbl[ia] != 8'd0))
                                            ? 32'sd1 : 32'sd0;
                                        begin stack_tag_we = 1'b1; stack_tag_waddr = sp - 8'd2; stack_tag_wdata = 3'd0; end
                                        sp_n = sp - 8'd1;
                                        next_op();
                                    end
                                end else begin
                                    alu_fx_n = 1'b0;
                                    alu_a_n = fxlift(stack[sp - 8'd2], stack_tag[sp - 8'd2],
                                                    stack_tag[sp - 8'd1] == 3'd7);
                                    alu_b_n = fxlift(stack[sp - 8'd1], stack_tag[sp - 8'd1],
                                                    stack_tag[sp - 8'd2] == 3'd7);
                                    alu_op_n = 3'd4;
                                    sp_n = sp - 8'd1;
                                    state_n = S_ALU;
                                end
                            end
                            OP_JUMP: begin
                                ip_n = code_rdata[23:8];
                                code_raddr_n = 15'(ops_base + code_rdata[23:8]);
                                state_n = S_FETCH_WAIT;
                            end
                            OP_JIF: begin
                                // JS falsy: undef, int 0, or fx 0.0 — objects/strings/fns at oid 0 are still truthy
                                a_s = (stack_tag[sp - 8'd1] == 3'd5 ||
                                       ((stack_tag[sp - 8'd1] == 3'd0 || stack_tag[sp - 8'd1] == 3'd7)
                                        && stack[sp - 8'd1] == 0))
                                      ? 32'sd0 : 32'sd1;
                                sp_n = sp - 8'd1;
                                if (a_s == 0) begin
                                    ip_n = code_rdata[23:8];
                                    code_raddr_n = 15'(ops_base + code_rdata[23:8]);
                                end else begin
                                    ip_n = ip + 16'd1;
                                    code_raddr_n = 15'(ops_base + ip + 16'd1);
                                end
                                state_n = S_FETCH_WAIT;
                            end
                            OP_CALL: begin
                                nat_id_n = code_rdata[15:8];
                                nat_argc_n = code_rdata[31:24];
                                ip_n = ip + 16'd1;
                                state_n = S_NAT;
                            end
                            OP_RETURN: begin
                                if (looping) begin
                                    fb_swap_n = 1'b1;
                                    state_n = S_WAIT_FRAME;
                                end
                                else begin running_n = 1'b0; state_n = S_DONE; end
                            end
                            // POP saturates at empty: draw natives push no
                            // return but the compiler still emits POP after
                            // statement calls (FM pushes undefined) — the
                            // unguarded pop wrapped sp to 2047 in PACMAN boot
                            OP_POP: begin if (sp != 0) sp_n = sp - 8'd1; next_op(); end
                            OP_DUP: begin
                                begin stack_we = 1'b1; stack_waddr = sp; stack_wdata = stack[sp - 8'd1]; end
                                begin stack_tag_we = 1'b1; stack_tag_waddr = sp; stack_tag_wdata = stack_tag[sp - 8'd1]; end
                                sp_n = sp + 8'd1;
                                next_op();
                            end
                            OP_NEG: begin
                                alu_fx_n = (stack_tag[sp - 8'd1] == 3'd7);  // -fx stays fx
                                alu_a_n = stack[sp - 8'd1];
                                alu_op_n = 3'd5;
                                state_n = S_ALU;
                            end
                            OP_NOT: begin
                                // JS !x — objects/strings/fns truthy even when the packed oid is 0
                                alu_fx_n = 1'b0;
                                alu_a_n = (stack_tag[sp - 8'd1] == 3'd5 ||
                                          ((stack_tag[sp - 8'd1] == 3'd0 || stack_tag[sp - 8'd1] == 3'd7)
                                           && stack[sp - 8'd1] == 0))
                                         ? 32'sd0 : 32'sd1;
                                alu_op_n = 3'd6;
                                state_n = S_ALU;
                            end
                            OP_MOD: begin
                                // NEW: a % b on floored ints (fx operands coerce) — 0 if b==0
                                begin
                                    logic signed [31:0] ma, mb;
                                    ma = fxi(stack[sp - 8'd2], stack_tag[sp - 8'd2]);
                                    mb = fxi(stack[sp - 8'd1], stack_tag[sp - 8'd1]);
                                    if (mb == 0)
                                        begin stack_we = 1'b1; stack_waddr = sp - 8'd2; stack_wdata = 32'sd0; end
                                    else
                                        begin stack_we = 1'b1; stack_waddr = sp - 8'd2; stack_wdata = ma - (ma / mb) * mb; end
                                    begin stack_tag_we = 1'b1; stack_tag_waddr = sp - 8'd2; stack_tag_wdata = 3'd0; end
                                    sp_n = sp - 8'd1;
                                    next_op();
                                end
                            end
                            OP_BIT_OR: begin
                                // NEW: `v|0` is the JS float→int idiom — floor fx first
                                stack_we = 1'b1; stack_waddr = sp - 8'd2; stack_wdata = fxi(stack[sp - 8'd2], stack_tag[sp - 8'd2])
                                                  | fxi(stack[sp - 8'd1], stack_tag[sp - 8'd1]);
                                begin stack_tag_we = 1'b1; stack_tag_waddr = sp - 8'd2; stack_tag_wdata = 3'd0; end
                                sp_n = sp - 8'd1;
                                next_op();
                            end
                            OP_BIT_AND: begin
                                stack_we = 1'b1; stack_waddr = sp - 8'd2; stack_wdata = fxi(stack[sp - 8'd2], stack_tag[sp - 8'd2])
                                                  & fxi(stack[sp - 8'd1], stack_tag[sp - 8'd1]);
                                begin stack_tag_we = 1'b1; stack_tag_waddr = sp - 8'd2; stack_tag_wdata = 3'd0; end
                                sp_n = sp - 8'd1;
                                next_op();
                            end
                            OP_MAKE_ARR: begin
                                begin arr_len_we = 1'b1; arr_len_waddr = n_arr[11:0]; arr_len_wdata = code_rdata[15:8]; end
                                if (n_arr >= 16'(MAX_ARR - 1)) dbg_heap_ovf_n = dbg_heap_ovf + 16'd1;
                                n_arr_n = (n_arr >= 16'(MAX_ARR - 1)) ? n_arr : (n_arr + 16'd1);
                                ip_n = ip + 16'd1;
                                code_raddr_n = 15'(ops_base + ip + 16'd1);
                                if (code_rdata[15:8] == 8'd0) begin
                                    begin stack_we = 1'b1; stack_waddr = sp; stack_wdata = {16'd0, n_arr}; end
                                    begin stack_tag_we = 1'b1; stack_tag_waddr = sp; stack_tag_wdata = 3'd2; end
                                    sp_n = sp + 8'd1;
                                    state_n = S_FETCH_WAIT;
                                end else begin
                                    // Do not clobber e0 with the handle until
                                    // S_HEAP_FILL has copied the old stack words.
                                    hp_cmd_n = HP_AFILL;
                                    hp_v64_n = 1'b0;
                                    hp_from_stack_n = 1'b1;
                                    hp_make_arr_n = 1'b1;
                                    hp_rval_n = {48'd0, n_arr};
                                    hp_aid_n = n_arr[11:0];
                                    hp_aslot_n = 7'd0;
                                    hp_lim_n = code_rdata[15:8];
                                    hp_vbase_n = {4'd0, sp} - {4'd0, code_rdata[15:8]};
                                    hp_ret_n = S_FETCH_WAIT;
                                sp_n = sp - code_rdata[15:8] + 8'd1;
                                    state_n = S_HEAP_FILL;
                                end
                            end
                            OP_ARR_GET: begin
                                // stack [arr, idx] — fx index floors (a[i*0.5] etc.)
                                if (stack_tag[sp - 8'd2] == 3'd2) begin
                                    begin
                                        logic signed [31:0] aidx32;
                                        logic [11:0] aid;
                                        aid = stack[sp - 8'd2][11:0];
                                        aidx32 = fxi(stack[sp - 8'd1], stack_tag[sp - 8'd1]);
                                        if (aidx32 < 0 || aidx32 >= 32'(arr_len[aid])) begin
                                            begin stack_we = 1'b1; stack_waddr = sp - 8'd2; stack_wdata = 32'sd0; end
                                            begin stack_tag_we = 1'b1; stack_tag_waddr = sp - 8'd2; stack_tag_wdata = 3'd5; end
                                            sp_n = sp - 8'd1;
                                            next_op();
                                        end else begin
                                            hp_cmd_n = HP_ARRGET;
                                            hp_v64_n = 1'b0;
                                            hp_aid_n = aid;
                                            hp_aslot_n = 7'(aidx32);
                                            hp_alen_n = arr_len[aid];
                                            state_n = S_HEAP_WAIT;
                                        end
                                    end
                                end else if (stack_tag[sp - 8'd2] == 3'd1 &&
                                             stack_tag[sp - 8'd1] == 3'd3) begin
                                    hp_cmd_n = HP_GETIDX;
                                    hp_v64_n = 1'b0;
                                    hp_oid_n = stack[sp - 8'd2][12:0];
                                    hp_key_n = stack[sp - 8'd1][15:0];
                                    hp_len_n = obj_n[stack[sp - 8'd2][12:0]];
                                    hp_slot_n = 5'd0;
                                    hp_phase_n = 3'd1;
                                    hp_proto_n = V64_UNDEFINED;
                                    state_n = S_HEAP_WAIT;
                                // NEW: "str"[i] — one char. name_mem is BRAM, so the
                                // byte lands next cycle in S_STRIDX. This is what
                                // string-row sprites need (row[col] === "1").
                                end else if (stack_tag[sp - 8'd2] == 3'd3 && names_ok &&
                                             (stack_tag[sp - 8'd1] == 3'd0 ||
                                              stack_tag[sp - 8'd1] == 3'd7)) begin
                                    begin
                                        logic signed [31:0] ci;
                                        ci = fxi(stack[sp - 8'd1], stack_tag[sp - 8'd1]);
                                        if (ci >= 0 && ci < 32'(name_len_tbl[stack[sp - 8'd2][9:0]])) begin
                                            if (str_pf_ok && str_pf_id == stack[sp - 8'd2][15:0] &&
                                                str_pf_ci == ci &&
                                                name_rdaddr == name_off[stack[sp - 8'd2][9:0]] + 16'(ci)) begin
                                                // NEW: sequential hit — name_rdata is this char
                                                if (char_ok[name_rdata]) begin
                                                    begin stack_we = 1'b1; stack_waddr = sp - 8'd2; stack_wdata = {16'd0, char_id[name_rdata]}; end
                                                    begin stack_tag_we = 1'b1; stack_tag_waddr = sp - 8'd2; stack_tag_wdata = 3'd3; end
                                                end else begin
                                                    begin stack_we = 1'b1; stack_waddr = sp - 8'd2; stack_wdata = 32'sd0; end
                                                    begin stack_tag_we = 1'b1; stack_tag_waddr = sp - 8'd2; stack_tag_wdata = 3'd5; end
                                                end
                                                sp_n = sp - 8'd1;
                                                name_rdaddr_n = name_off[stack[sp - 8'd2][9:0]] + 16'(ci) + 16'd1;
                                                str_pf_id_n = stack[sp - 8'd2][15:0];
                                                str_pf_ci_n = ci + 32'sd1;
                                                str_pf_ok_n = 1'b1;
                                                next_op();
                                            end else begin
                                                name_rdaddr_n = name_off[stack[sp - 8'd2][9:0]] + 16'(ci);
                                                str_res_n = 11'(sp - 8'd2);
                                                str_pf_id_n = stack[sp - 8'd2][15:0];
                                                str_pf_ci_n = ci;
                                                str_pf_ok_n = 1'b0;
                                                sp_n = sp - 8'd1;
                                                ip_n = ip + 16'd1;
                                                state_n = S_STRIDX;
                                            end
                                        end else begin
                                            // out of range is undefined, same as PYTHON
                                            begin stack_we = 1'b1; stack_waddr = sp - 8'd2; stack_wdata = 32'sd0; end
                                            begin stack_tag_we = 1'b1; stack_tag_waddr = sp - 8'd2; stack_tag_wdata = 3'd5; end
                                            sp_n = sp - 8'd1;
                                            next_op();
                                        end
                                    end
                                end else begin
                                    begin stack_we = 1'b1; stack_waddr = sp - 8'd2; stack_wdata = 32'sd0; end
                                    begin stack_tag_we = 1'b1; stack_tag_waddr = sp - 8'd2; stack_tag_wdata = 3'd5; end
                                    sp_n = sp - 8'd1;
                                    next_op();
                                end
                            end
                            OP_ARR_SET: begin
                                // [arr, idx, val] — fx index floors first (LHS needs a plain var)
                                begin
                                    logic signed [31:0] aidx32;
                                    logic [11:0] aid;
                                    aidx32 = fxi(stack[sp - 8'd2], stack_tag[sp - 8'd2]);
                                    aid = stack[sp - 8'd3][11:0];
                                    if (stack_tag[sp - 8'd3] == 3'd2 &&
                                        aidx32 >= 0 && aidx32 < ARR_CAP) begin
                                        if (aidx32 >= 32'(arr_len[aid]))
                                            begin arr_len_we = 1'b1; arr_len_waddr = aid; arr_len_wdata = 8'(aidx32 + 32'sd1); end
                                        hp_cmd_n = HP_ARRSET;
                                        hp_v64_n = 1'b0;
                                        hp_from_stack_n = 1'b0;
                                        hp_aid_n = aid;
                                        hp_aslot_n = 7'(aidx32);
                                        hp_wval_n = {32'd0, stack[sp - 8'd1]};
                                        hp_tag_n = stack_tag[sp - 8'd1];
                                        state_n = S_HEAP_AWR;
                                    end else if (stack_tag[sp - 8'd3] == 3'd1 &&
                                                 stack_tag[sp - 8'd2] == 3'd3) begin
                                        hp_cmd_n = HP_SETIDX;
                                        hp_v64_n = 1'b0;
                                        hp_oid_n = stack[sp - 8'd3][12:0];
                                        hp_key_n = stack[sp - 8'd2][15:0];
                                        hp_wval_n = {32'd0, stack[sp - 8'd1]};
                                        hp_tag_n = stack_tag[sp - 8'd1];
                                        hp_len_n = obj_n[stack[sp - 8'd3][12:0]];
                                        hp_slot_n = 5'd0;
                                        hp_phase_n = 3'd0;
                                        state_n = S_HEAP_WAIT;
                                    end else begin
                                begin stack_we = 1'b1; stack_waddr = sp - 8'd3; stack_wdata = stack[sp - 8'd1]; end
                                begin stack_tag_we = 1'b1; stack_tag_waddr = sp - 8'd3; stack_tag_wdata = stack_tag[sp - 8'd1]; end
                                sp_n = sp - 8'd2;
                                next_op();
                                    end
                                end
                            end
                            OP_MAKE_OBJ: begin
                                begin obj_n_we = 1'b1; obj_n_waddr = n_obj[12:0]; obj_n_wdata = 0; end
                                begin obj_cls_we = 1'b1; obj_cls_waddr = n_obj[12:0]; obj_cls_wdata = 0; end
                                begin stack_we = 1'b1; stack_waddr = sp; stack_wdata = {16'd0, n_obj}; end
                                begin stack_tag_we = 1'b1; stack_tag_waddr = sp; stack_tag_wdata = 3'd1; end
                                n_obj_n = (n_obj >= 16'(MAX_OBJ - 1)) ? n_obj : (n_obj + 16'd1);
                                sp_n = sp + 8'd1;
                                next_op();
                            end
                            OP_GET_PROP: begin
                                if (stack_tag[sp - 8'd1] == 3'd2 &&
                                    (code_rdata[23:8] == id_length || code_rdata[23:8] == 16'd66)) begin
                                    begin stack_we = 1'b1; stack_waddr = sp - 8'd1; stack_wdata = {24'd0, arr_len[stack[sp - 8'd1][11:0]]}; end
                                    begin stack_tag_we = 1'b1; stack_tag_waddr = sp - 8'd1; stack_tag_wdata = 3'd0; end
                                // NEW: "str".length — the interned length table
                                // already had this; only arrays were answered, so
                                // `col < row.length` was col < undefined and every
                                // character loop body was skipped.
                                end else if (stack_tag[sp - 8'd1] == 3'd3 &&
                                    (code_rdata[23:8] == id_length || code_rdata[23:8] == 16'd66)) begin
                                    begin stack_we = 1'b1; stack_waddr = sp - 8'd1; stack_wdata = {24'd0, name_len_tbl[stack[sp - 8'd1][9:0]]}; end
                                    begin stack_tag_we = 1'b1; stack_tag_waddr = sp - 8'd1; stack_tag_wdata = 3'd0; end
                                // NEW: dynamic string (replace / JSON result) length
                                end else if (stack_tag[sp - 8'd1] == 3'd1 &&
                                    obj_cls[stack[sp - 8'd1][12:0]] == CLS_DYNSTR &&
                                    (code_rdata[23:8] == id_length || code_rdata[23:8] == 16'd66)) begin
                                    hp_cmd_n = HP_OGETI;
                                    hp_v64_n = 1'b0;
                                    hp_oid_n = stack[sp - 8'd1][12:0];
                                    hp_slot_n = 5'd1;
                                    hp_qn_n = 3'd1;
                                    hp_qi_n = 3'd0;
                                    hp_nat_n = 4'd6;
                                    hp_ret_n = S_V64_OGETI_NAT;
                                    state_n = S_HEAP_WAIT;
                                end else if (stack_tag[sp - 8'd1] == 3'd1) begin
                                    hp_cmd_n = HP_GETPROP;
                                    hp_v64_n = 1'b0;
                                    hp_oid_n = stack[sp - 8'd1][12:0];
                                    hp_key_n = code_rdata[23:8];
                                    hp_len_n = obj_n[stack[sp - 8'd1][12:0]];
                                    hp_slot_n = 5'd0;
                                    hp_phase_n = 3'd0;
                                    hp_proto_n = V64_UNDEFINED;
                                    hp_tag_n = 3'd0;
                                    state_n = S_HEAP_WAIT;
                                end else begin
                                if (stack_tag[sp - 8'd1] == 3'd4 &&
                                            code_rdata[23:8] == id_proto) begin
                                    // Fn.prototype — stable heap object per MAKE_FN entry
                                    begin
                                        logic [15:0] poid;
                                        logic hit;
                                        hit = 1'b0;
                                        poid = 16'd0;
                                        for (int i = 0; i < MAX_FN_PROTO; i++) begin
                                            if (i < n_fn_proto && fn_proto_ip[i] == stack[sp - 8'd1][15:0]) begin
                                                hit = 1'b1;
                                                poid = fn_proto_oid[i];
                                            end
                                        end
                                        if (!hit && n_fn_proto < MAX_FN_PROTO[6:0]) begin
                                            poid = n_obj;
                                            begin obj_n_we = 1'b1; obj_n_waddr = n_obj[12:0]; obj_n_wdata = 0; end
                                            begin obj_cls_we = 1'b1; obj_cls_waddr = n_obj[12:0]; obj_cls_wdata = 0; end
                                            fn_proto_ip_n[n_fn_proto] = stack[sp - 8'd1][15:0];
                                            fn_proto_oid_n[n_fn_proto] = n_obj;
                                            n_fn_proto_n = n_fn_proto + 7'd1;
                                            n_obj_n = (n_obj >= 16'(MAX_OBJ - 1)) ? n_obj : (n_obj + 16'd1);
                                        end
                                        begin stack_we = 1'b1; stack_waddr = sp - 8'd1; stack_wdata = {16'd0, poid}; end
                                        begin stack_tag_we = 1'b1; stack_tag_waddr = sp - 8'd1; stack_tag_wdata = 3'd1; end
                                    end
                                end else if (stack_tag[sp - 8'd1] == 3'd6 && code_rdata[23:8] == id_click) begin
                                    begin stack_we = 1'b1; stack_waddr = sp - 8'd1; stack_wdata = 32'sd1; end
                                    begin stack_tag_we = 1'b1; stack_tag_waddr = sp - 8'd1; stack_tag_wdata = 3'd4; end  // truthy click handle
                                end else if (stack_tag[sp - 8'd1] == 3'd6 &&
                                            (code_rdata[23:8] == id_width || code_rdata[23:8] == id_height)) begin
                                    // canvas.width / canvas.height (INVADERS GAME_WIDTH path is literals; keep DOM sized)
                                    begin stack_we = 1'b1; stack_waddr = sp - 8'd1; stack_wdata = (code_rdata[23:8] == id_width) ? 32'sd640 : 32'sd480; end
                                    begin stack_tag_we = 1'b1; stack_tag_waddr = sp - 8'd1; stack_tag_wdata = 3'd0; end
                                end else if (stack_tag[sp - 8'd1] == 3'd6) begin
                                    // DOM .style → same elem so .style.display is a no-op SET
                                    begin stack_tag_we = 1'b1; stack_tag_waddr = sp - 8'd1; stack_tag_wdata = 3'd6; end
                                end else begin
                                    begin stack_we = 1'b1; stack_waddr = sp - 8'd1; stack_wdata = 32'sd0; end
                                    begin stack_tag_we = 1'b1; stack_tag_waddr = sp - 8'd1; stack_tag_wdata = 3'd5; end
                                end
                                next_op();
                                end
                            end
                            OP_SET_PROP: begin
                                // [obj, val]  a0=name
                                if (stack_tag[sp - 8'd2] == 3'd1) begin
                                    begin
                                        logic [12:0] oi;
                                        oi = stack[sp - 8'd2][12:0];
                                        // last .a/.d/.space object wins — INVADERS keys table
                                        if (stack_tag[sp - 8'd1] == 3'd1) begin
                                            if (code_rdata[23:8] == id_a || code_rdata[23:8] == 16'd98)
                                                keys_a_oid_n = stack[sp - 8'd1][15:0];
                                            if (code_rdata[23:8] == id_d || code_rdata[23:8] == 16'd199)
                                                keys_d_oid_n = stack[sp - 8'd1][15:0];
                                            if (code_rdata[23:8] == id_kspace || code_rdata[23:8] == 16'd204)
                                                keys_sp_oid_n = stack[sp - 8'd1][15:0];
                                        end
                                        if (code_rdata[23:8] == id_src && stack_tag[sp - 8'd1] == 3'd3) begin
                                            for (int k = 0; k < MAX_SPR; k++)
                                                if (stack[sp - 8'd1][15:0] == spr_nid[k[3:0]])
                                                    begin obj_cls_we = 1'b1; obj_cls_waddr = oi; obj_cls_wdata = 16'hFFC0 | k[15:0]; end
                                        end
                                    end
                                    // Image.onload = fn — invoke now so player.image exists before animate
                                    if (code_rdata[23:8] == id_onload && stack_tag[sp - 8'd1] == 3'd4) begin
                                        cstack_ip_n[csp] = ip + 16'd1;
                                        cstack_this_n[csp] = this_obj;
                                        cstack_isctor_n[csp] = 1'b0;
                                        cstack_isfe_n[csp] = 1'b0;
                                        enter_captured_fn(stack[sp - 8'd1][15:0]);
                                        bump_csp();
                                        ip_n = fn_entry(stack[sp - 8'd1][15:0]);
                                        code_raddr_n = 15'(ops_base + fn_entry(stack[sp - 8'd1][15:0]));
                                        begin stack_we = 1'b1; stack_waddr = sp - 8'd2; stack_wdata = stack[sp - 8'd1]; end
                                        begin stack_tag_we = 1'b1; stack_tag_waddr = sp - 8'd2; stack_tag_wdata = stack_tag[sp - 8'd1]; end
                                        sp_n = sp - 8'd1;
                                        state_n = S_FETCH_WAIT;
                                    end else begin
                                        hp_cmd_n = HP_SETPROP;
                                        hp_v64_n = 1'b0;
                                        hp_oid_n = stack[sp - 8'd2][12:0];
                                        hp_key_n = code_rdata[23:8];
                                        hp_wval_n = {32'd0, stack[sp - 8'd1]};
                                        hp_tag_n = stack_tag[sp - 8'd1];
                                        hp_len_n = obj_n[stack[sp - 8'd2][12:0]];
                                        hp_slot_n = 5'd0;
                                        hp_phase_n = 3'd0;
                                        state_n = S_HEAP_WAIT;
                                    end
                                end else if (stack_tag[sp - 8'd2] == 3'd2 &&
                                           (code_rdata[23:8] == id_length || code_rdata[23:8] == 16'd66)) begin
                                    begin arr_len_we = 1'b1; arr_len_waddr = stack[sp - 8'd2][11:0]; arr_len_wdata = stack[sp - 8'd1][7:0]; end
                                    begin stack_we = 1'b1; stack_waddr = sp - 8'd2; stack_wdata = stack[sp - 8'd1]; end
                                    begin stack_tag_we = 1'b1; stack_tag_waddr = sp - 8'd2; stack_tag_wdata = stack_tag[sp - 8'd1]; end
                                    sp_n = sp - 8'd1;
                                    next_op();
                                end else if (stack_tag[sp - 8'd2] == 3'd6 &&
                                             code_rdata[23:8] == id_textalign) begin
                                    // NEW: ctx.textAlign — FM fill_text shifts the
                                    // pen by half / all of the text width
                                    ctx_align_n = (stack[sp - 8'd1][15:0] == id_center) ? 2'd1
                                               : (stack[sp - 8'd1][15:0] == id_right)  ? 2'd2
                                               : 2'd0;
                                    begin stack_we = 1'b1; stack_waddr = sp - 8'd2; stack_wdata = stack[sp - 8'd1]; end
                                    begin stack_tag_we = 1'b1; stack_tag_waddr = sp - 8'd2; stack_tag_wdata = stack_tag[sp - 8'd1]; end
                                    sp_n = sp - 8'd1;
                                    next_op();
                                end else if (stack_tag[sp - 8'd2] == 3'd6 &&
                                             code_rdata[23:8] == id_font) begin
                                    // NEW: ctx.font = "bold 24px Foo" — walk the
                                    // bytes for the first NNpx run, exactly what
                                    // FM machine._font_scale's regex takes.
                                    begin stack_we = 1'b1; stack_waddr = sp - 8'd2; stack_wdata = stack[sp - 8'd1]; end
                                    begin stack_tag_we = 1'b1; stack_tag_waddr = sp - 8'd2; stack_tag_wdata = stack_tag[sp - 8'd1]; end
                                    sp_n = sp - 8'd1;
                                    if (stack_tag[sp - 8'd1] == 3'd3 && names_ok &&
                                        name_has[stack[sp - 8'd1][9:0]]) begin
                                        txt_rp_n = name_off[stack[sp - 8'd1][9:0]];
                                        name_rdaddr_n = name_off[stack[sp - 8'd1][9:0]];
                                        fp_left_n = name_len_tbl[stack[sp - 8'd1][9:0]];
                                        fpx_acc_n = 8'd0;
                                        ctx_font_px_n = 8'd8;  // no "px" found → FM default
                                        ip_n = ip + 16'd1;
                                        state_n = S_FONTPX;
                                    end else begin
                                        ctx_font_px_n = 8'd8;
                                        next_op();
                                    end
                                end else if (stack_tag[sp - 8'd2] == 3'd6 &&
                                             code_rdata[23:8] == id_imgsmooth) begin
                                    // ctx.imageSmoothingEnabled = false → nearest
                                    // (indexed 8-bpp blit has no bilinear either way)
                                    ctx_smooth_n = (stack_tag[sp - 8'd1] == 3'd5)
                                                ? stack[sp - 8'd1][0]
                                                : (stack[sp - 8'd1] != 32'sd0);
                                    begin stack_we = 1'b1; stack_waddr = sp - 8'd2; stack_wdata = stack[sp - 8'd1]; end
                                    begin stack_tag_we = 1'b1; stack_tag_waddr = sp - 8'd2; stack_tag_wdata = stack_tag[sp - 8'd1]; end
                                    sp_n = sp - 8'd1;
                                    next_op();
                                end else if (stack_tag[sp - 8'd2] == 3'd6 &&
                                           (code_rdata[23:8] == id_fillstyle ||
                                            code_rdata[23:8] == id_strokestyle)) begin
                                    // ctx.fillStyle / strokeStyle — FSTY LUT first
                                    // (compiler-resolved 256-palette index, exact FM
                                    // parity); legacy 8-color chain only as fallback
                                    if (stack_tag[sp - 8'd1] == 3'd3 &&
                                        stack[sp - 8'd1][15:0] < 16'd1024 &&
                                        fill_lut[stack[sp - 8'd1][9:0]] != 8'hFF)
                                        fill_style_i_n = fill_lut[stack[sp - 8'd1][9:0]];
                                    else if (stack_tag[sp - 8'd1] == 3'd0 ||
                                             stack_tag[sp - 8'd1] == 3'd7)
                                        // numeric fillStyle — direct palette index
                                        fill_style_i_n = 8'(fxi(stack[sp - 8'd1],
                                                               stack_tag[sp - 8'd1]));
                                    else if (stack[sp - 8'd1][15:0] == id_black || stack[sp - 8'd1][15:0] == id_hex_000)
                                        fill_style_i_n = 8'd0;
                                    else if (stack[sp - 8'd1][15:0] == id_white || stack[sp - 8'd1][15:0] == id_hex_fff
                                          || stack[sp - 8'd1][15:0] == id_hex_aaa
                                          || stack[sp - 8'd1][15:0] == id_hex_f5f5)
                                        fill_style_i_n = 8'd1;
                                    else if (stack[sp - 8'd1][15:0] == id_red || stack[sp - 8'd1][15:0] == id_hex_f00)
                                        fill_style_i_n = 8'd2;
                                    else if (stack[sp - 8'd1][15:0] == id_hex_3f6 || stack[sp - 8'd1][15:0] == id_hex_2ec)
                                        fill_style_i_n = 8'd3;
                                    else if (stack[sp - 8'd1][15:0] == id_cyan || stack[sp - 8'd1][15:0] == id_hex_09f)
                                        fill_style_i_n = 8'd4;
                                    else if (stack[sp - 8'd1][15:0] == id_yellow || stack[sp - 8'd1][15:0] == id_gold
                                          || stack[sp - 8'd1][15:0] == id_hex_fc0
                                          || stack[sp - 8'd1][15:0] == id_hex_ffe6)
                                        fill_style_i_n = 8'd5;
                                    else if (stack[sp - 8'd1][15:0] == id_hex_f5a)
                                        fill_style_i_n = 8'd7;
                                    else fill_style_i_n = 8'd1;
                                    begin stack_we = 1'b1; stack_waddr = sp - 8'd2; stack_wdata = stack[sp - 8'd1]; end
                                    begin stack_tag_we = 1'b1; stack_tag_waddr = sp - 8'd2; stack_tag_wdata = stack_tag[sp - 8'd1]; end
                                    sp_n = sp - 8'd1;
                                    next_op();
                                end else begin
                                    begin stack_we = 1'b1; stack_waddr = sp - 8'd2; stack_wdata = stack[sp - 8'd1]; end
                                    begin stack_tag_we = 1'b1; stack_tag_waddr = sp - 8'd2; stack_tag_wdata = stack_tag[sp - 8'd1]; end
                                    sp_n = sp - 8'd1;
                                    next_op();
                                end
                            end
                            OP_MAKE_FN: begin
                                // NEW: heap Fn {entry, nparam, live env oid,
                                // bound this}. a1 bit7 is the ProgramImage's
                                // arrow flag; arrows capture the current receiver.
                                begin
                                    logic [12:0] fo;
                                    logic [15:0] eoid;
                                    logic bind_this;
                                    fo = n_obj[12:0];
                                    eoid = (env_sp != 0) ? env_oid[env_sp - 6'd1] : 16'd0;
                                    bind_this = code_rdata[31] && this_obj != 16'hFFFF;
                                    begin obj_cls_we = 1'b1; obj_cls_waddr = fo; obj_cls_wdata = CLS_FN; end
                                    begin tfn_entry_we = 1'b1; tfn_entry_waddr = fo; tfn_entry_wdata = code_rdata[23:8]; end
                                    begin tfn_nparam_we = 1'b1; tfn_nparam_waddr = fo; tfn_nparam_wdata = {2'd0, code_rdata[29:24]}; end
                                    begin tfn_parent_we = 1'b1; tfn_parent_waddr = fo; tfn_parent_wdata = eoid; end
                                    begin tfn_this_we = 1'b1; tfn_this_waddr = fo; tfn_this_wdata = this_obj; end
                                    begin tfn_this_tag_we = 1'b1; tfn_this_tag_waddr = fo; tfn_this_tag_wdata = 3'd1; end
                                    begin tfn_has_this_we = 1'b1; tfn_has_this_waddr = fo; tfn_has_this_wdata = bind_this; end
                                    obj_n_we = 1'b1; obj_n_waddr = fo; obj_n_wdata = bind_this ? 6'd4 :
                                                 ((eoid != 16'd0) ? 6'd3 : 6'd2);
                                    hp_cmd_n = HP_OSETI;
                                    hp_v64_n = 1'b0;
                                    hp_oid_n = fo;
                                    hp_slot_n = 5'd0;
                                    hp_qn_n = bind_this ? 3'd4 :
                                             ((eoid != 16'd0) ? 3'd3 : 3'd2);
                                    hp_qi_n = 3'd0;
                                    hp_qk_n[0] = 16'd0;
                                    hp_qv_n[0] = {48'd0, code_rdata[23:8]};
                                    hp_qt_n[0] = 3'd0;
                                    hp_qk_n[1] = 16'd1;
                                    hp_qv_n[1] = {56'd0, 2'd0, code_rdata[29:24]};
                                    hp_qt_n[1] = 3'd0;
                                    hp_qk_n[2] = 16'd2;
                                    hp_qv_n[2] = {48'd0, eoid};
                                    hp_qt_n[2] = 3'd0;
                                    hp_qk_n[3] = 16'd3;
                                    hp_qv_n[3] = {48'd0, this_obj};
                                    hp_qt_n[3] = 3'd1;
                                    hp_ret_n = S_FETCH_WAIT;
                                    if (env_sp != 6'd0)
                                        begin env_cap_we = 1'b1; env_cap_waddr = env_sp - 6'd1; env_cap_wdata = 1'b1; end
                                    begin stack_we = 1'b1; stack_waddr = sp; stack_wdata = {16'd0, n_obj}; end
                                    begin stack_tag_we = 1'b1; stack_tag_waddr = sp; stack_tag_wdata = 3'd4; end
                                    if (n_obj >= 16'(MAX_OBJ - 1)) dbg_heap_ovf_n = dbg_heap_ovf + 16'd1;
                                    n_obj_n = (n_obj >= 16'(MAX_OBJ - 1)) ? n_obj : (n_obj + 16'd1);
                                    sp_n = sp + 8'd1;
                                    ip_n = ip + 16'd1;
                                    code_raddr_n = 15'(ops_base + ip + 16'd1);
                                    state_n = S_HEAP_WR;
                                end
                            end
                            OP_CALL_USER: begin
                                cstack_ip_n[csp] = ip + 16'd1;
                                cstack_this_n[csp] = this_obj;
                                cstack_isctor_n[csp] = 1'b0;
                                cstack_isfe_n[csp] = 1'b0;
                                cstack_env_n[csp] = env_sp;
                                push_fresh_env(16'd0);
                                bump_csp();
                                ip_n = code_rdata[23:8];
                                code_raddr_n = 15'(ops_base + code_rdata[23:8]);
                                state_n = S_FETCH_WAIT;
                            end
                            OP_CALL_VAL: begin
                                // argc in a0; stack [fn, args...] — pop fn, leave args (PYTHON call_fn)
                                if (stack_tag[sp - 8'(code_rdata[15:8]) - 8'd1] == 3'd4) begin
                                    begin
                                        logic [7:0] ac;
                                        logic [15:0] foid;
                                        logic [12:0] fo;
                                        logic [5:0]  capn;
                                        ac = code_rdata[15:8];
                                        foid = stack[sp - ac - 8'd1][15:0];
                                        fo = foid[12:0];
                                        for (int k = 0; k < 8; k++) begin
                                            if (k < ac) begin
                                                begin stack_we = 1'b1; stack_waddr = sp - ac - 8'd1 + k[7:0]; stack_wdata = stack[sp - ac + k[7:0]]; end
                                                begin stack_tag_we = 1'b1; stack_tag_waddr = sp - ac - 8'd1 + k[7:0]; stack_tag_wdata = stack_tag[sp - ac + k[7:0]]; end
                                            end
                                        end
                                        sp_n = sp - 8'd1;
                                        cstack_ip_n[csp] = ip + 16'd1;
                                        cstack_this_n[csp] = this_obj;
                                        cstack_isctor_n[csp] = 1'b0;
                                        cstack_isfe_n[csp] = 1'b0;
                                        enter_captured_fn(foid);
                                        bump_csp();
                                        ip_n = tfn_entry[fo];
                                        code_raddr_n = 15'(ops_base + tfn_entry[fo]);
                                        state_n = S_FETCH_WAIT;
                                    end
                                end else begin
                                    sp_n = sp - 8'(code_rdata[15:8]) - 8'd1;
                                    begin stack_we = 1'b1; stack_waddr = sp - 8'(code_rdata[15:8]) - 8'd1; stack_wdata = 32'sd0; end
                                    begin stack_tag_we = 1'b1; stack_tag_waddr = sp - 8'(code_rdata[15:8]) - 8'd1; stack_tag_wdata = 3'd5; end
                                    sp_n = sp - 8'(code_rdata[15:8]);
                                    next_op();
                                end
                            end
                            OP_RET_VAL: begin
                                if (csp == 0) begin
                                    fb_swap_n = 1'b1;
                                    state_n = S_WAIT_FRAME;
                                end else if (cstack_ip[csp - 7'd1] == 16'hFFFE) begin
                                    // NEW: return from forEach/map/find callback → next element
                                    begin
                                        logic [15:0] md;
                                        logic truthy;
                                        md = cstack_map_arr[csp - 7'd2];
                                        truthy = (sp != 0) && (stack_tag[sp - 8'd1] != 3'd5) &&
                                                 !((stack_tag[sp - 8'd1] == 3'd0 ||
                                                    stack_tag[sp - 8'd1] == 3'd7) &&
                                                   stack[sp - 8'd1] == 32'sd0);
                                        if (md == 16'hFFFE && truthy) begin
                                            // find hit — AGETI then S_V64_FE_ELEM tagged
                                            dbg_find_hit_n = dbg_find_hit + 16'd1;
                                            hp_cmd_n = HP_AGETI;
                                            hp_v64_n = 1'b0;
                                            hp_aid_n = cstack_fe_arr[csp - 7'd2][11:0];
                                            hp_aslot_n = cstack_fe_i[csp - 7'd2][6:0];
                                            hp_alen_n = arr_len[cstack_fe_arr[csp - 7'd2][11:0]];
                                            hp_ret_n = S_V64_FE_ELEM;
                                            state_n = S_HEAP_WAIT;
                                        end else if (md == 16'hFFFD && truthy) begin
                                            // findIndex hit — return current index
                                            begin stack_we = 1'b1; stack_waddr = sp - 8'd1; stack_wdata = {24'd0, cstack_fe_i[csp - 7'd2]}; end
                                            begin stack_tag_we = 1'b1; stack_tag_waddr = sp - 8'd1; stack_tag_wdata = 3'd0; end
                                            arm_release_env(cstack_env[csp - 7'd1], S_FETCH_WAIT);
                                            ip_n = cstack_ip[csp - 7'd2];
                                            this_obj_n = cstack_this[csp - 7'd2];
                                            if (this_ok) begin
                                                vars_we = 1'b1; vars_waddr = var_this; vars_wdata = (cstack_this[csp - 7'd2] == 16'hFFFF)
                                                                  ? 32'd0
                                                                  : {16'd0, cstack_this[csp - 7'd2]};
                                                var_tag_we = 1'b1; var_tag_waddr = var_this; var_tag_wdata = (cstack_this[csp - 7'd2] == 16'hFFFF)
                                                                     ? 3'd5 : 3'd1;
                                            end
                                            csp_n = csp - 7'd2;
                                            code_raddr_n = 15'(ops_base + cstack_ip[csp - 7'd2]);
                                        end else begin
                                            if (cstack_isctor[csp - 7'd2] &&
                                                md != 16'hFFFF && md != 16'hFFFE && md != 16'hFFFD &&
                                                truthy) begin
                                                // filter: keep source element
                                                begin
                                                    logic [7:0] fl;
                                                    fl = arr_len[md[11:0]];
                                                    if (fl < ARR_CAP[7:0]) begin
                                                        begin arr_len_we = 1'b1; arr_len_waddr = md[11:0]; arr_len_wdata = fl + 8'd1; end
                                                    end
                                                end
                                            end else if (md != 16'hFFFF && md != 16'hFFFE &&
                                                       md != 16'hFFFD && !cstack_isctor[csp - 7'd2] &&
                                                       sp != 0) begin
                                            end
                                            arm_release_env(cstack_env[csp - 7'd1], S_FOREACH);
                                            csp_n = csp - 7'd1;
                                            if (sp != 0) sp_n = sp - 8'd1;
                                            cstack_fe_i_n[csp - 7'd2] = cstack_fe_i[csp - 7'd2] + 8'd1;
                                        end
                                    end
                                end else if (cstack_ip[csp - 7'd1] == 16'hFFFD) begin
                                    // NEW: return from key listener → next table slot (same event)
                                    csp_n = csp - 7'd1;
                                    kev_li_n = kev_li + 2'd1;
                                    begin
                                        logic [2:0] nn;
                                        logic [15:0] nxt;
                                        st_t rel_nxt;
                                        nn = kev_is_down ? kd_n : ku_n;
                                        nxt = kev_is_down
                                            ? kd_slot[kev_li + 2'd1] : ku_slot[kev_li + 2'd1];
                                        if ({1'b0, kev_li} + 3'd1 < nn && nxt != 16'hFFFF) begin
                                            kev_fn_n = nxt;
                                            begin stack_we = 1'b1; stack_waddr = 0; stack_wdata = {16'd0, kev_obj}; end
                                            begin stack_tag_we = 1'b1; stack_tag_waddr = 0; stack_tag_wdata = 3'd1; end
                                            boundary_sp(11'd1);
                                            cstack_ip_n[csp - 7'd1] = 16'hFFFD;
                                            cstack_isctor_n[csp - 7'd1] = 1'b0;
                                            cstack_isfe_n[csp - 7'd1] = 1'b0;
                                            rel_nxt = S_KEYEV;
                                        end else if (kev_ret_ip == n_ops) begin
                                            // Hardware KEYEVT owns the input
                                            // phase; continue into this same
                                            // frame's rAF phase after listeners.
                                            frame_fire_n = 1'b1;
                                            rel_nxt = S_WAIT_FRAME;
                                        end else begin
                                            ip_n = kev_ret_ip;
                                            code_raddr_n = 15'(ops_base + kev_ret_ip);
                                            rel_nxt = S_FETCH_WAIT;
                                        end
                                        arm_release_env(cstack_env[csp - 7'd1], rel_nxt);
                                    end
                                end else begin
                                    // NEW: a callback frame returns to the frame
                                    // boundary sentinel (cstack_ip == n_ops). Latch
                                    // the RET site so a loop that stops re-arming
                                    // itself can be found (PACMAN start() fn dies
                                    // mid-frame and raf drops to 0 with no trace).
                                    if (cstack_ip[csp - 7'd1] == n_ops) dbg_cb_ip_n = ip;
                                    arm_release_env(cstack_env[csp - 7'd1], S_FETCH_WAIT);
                                    csp_n = csp - 7'd1;
                                    this_obj_n = cstack_this[csp - 7'd1];
                                    if (this_ok) begin
                                        vars_we = 1'b1; vars_waddr = var_this; vars_wdata = (cstack_this[csp - 7'd1] == 16'hFFFF)
                                                          ? 32'd0
                                                          : {16'd0, cstack_this[csp - 7'd1]};
                                        var_tag_we = 1'b1; var_tag_waddr = var_this; var_tag_wdata = (cstack_this[csp - 7'd1] == 16'hFFFF)
                                                             ? 3'd5 : 3'd1;
                                    end
                                    if (cstack_isctor[csp - 7'd1]) begin
                                        begin stack_we = 1'b1; stack_waddr = sp - 8'd1; stack_wdata = {16'd0, cstack_ctorobj[csp - 7'd1]}; end
                                        begin stack_tag_we = 1'b1; stack_tag_waddr = sp - 8'd1; stack_tag_wdata = 3'd1; end
                                    end
                                    ip_n = cstack_ip[csp - 7'd1];
                                    code_raddr_n = 15'(ops_base + cstack_ip[csp - 7'd1]);
                                end
                            end
                            OP_NEW_OBJ: begin
                                begin obj_n_we = 1'b1; obj_n_waddr = n_obj[12:0]; obj_n_wdata = 0; end
                                begin obj_cls_we = 1'b1; obj_cls_waddr = n_obj[12:0]; obj_cls_wdata = code_rdata[23:8]; end
                                begin
                                    logic [15:0] ctor_ip;
                                    logic [8:0] vslot;
                                    ctor_ip = 16'hFFFF;
                                    for (int c = 0; c < MAX_CLS; c++) begin
                                        if (c < n_cls && cls_name[c] == code_rdata[23:8])
                                            ctor_ip = cls_ctor[c];
                                    end
                                    // PACMAN `var Item = function` — class table ctor is FFFF
                                    if (ctor_ip == 16'hFFFF && intern_var_ok[code_rdata[17:8]]) begin
                                        vslot = intern_var[code_rdata[17:8]];
                                        if (var_tag[vslot] == 3'd4) begin
                                            ctor_ip = fn_entry(vars[vslot][15:0]);
                                            // proto table is keyed by Fn obj idx (MAKE_FN heap)
                                            for (int i = 0; i < MAX_FN_PROTO; i++) begin
                                                if (i < n_fn_proto && fn_proto_ip[i] == vars[vslot][15:0]) begin
            // flatten: heap write via S_HEAP_* only
            // flatten: heap write via S_HEAP_* only
            // flatten: heap write via S_HEAP_* only
                                                    begin obj_n_we = 1'b1; obj_n_waddr = n_obj[12:0]; obj_n_wdata = 6'd1; end
                                                end
                                            end
                                        end
                                    end
                                    // copy Fn.prototype onto new object
                                    for (int i = 0; i < MAX_FN_PROTO; i++) begin
                                        if (i < n_fn_proto && fn_proto_ip[i] == ctor_ip) begin
            // flatten: heap write via S_HEAP_* only
            // flatten: heap write via S_HEAP_* only
            // flatten: heap write via S_HEAP_* only
                                            begin obj_n_we = 1'b1; obj_n_waddr = n_obj[12:0]; obj_n_wdata = 6'd1; end
                                        end
                                    end
                                    if (ctor_ip != 16'hFFFF) begin
                                        cstack_ip_n[csp] = ip + 16'd1;
                                        cstack_this_n[csp] = this_obj;
                                        cstack_isctor_n[csp] = 1'b1;
                                        cstack_isfe_n[csp] = 1'b0;
                                        cstack_env_n[csp] = env_sp;
                                        cstack_ctorobj_n[csp] = n_obj;
                                        // env object at n_obj+1 (instance is n_obj)
                                        begin obj_cls_we = 1'b1; obj_cls_waddr = n_obj[12:0] + 13'd1; obj_cls_wdata = CLS_ENV; end
                                        begin obj_n_we = 1'b1; obj_n_waddr = n_obj[12:0] + 13'd1; obj_n_wdata = 6'd1; end
            // flatten: heap write via S_HEAP_* only
            // flatten: heap write via S_HEAP_* only
            // flatten: heap write via S_HEAP_* only
                                        if (env_sp < TAGGED_ENV_DEPTH[5:0]) begin
                                            begin env_oid_we = 1'b1; env_oid_waddr = env_sp; env_oid_wdata = n_obj + 16'd1; end
                                            begin env_cap_we = 1'b1; env_cap_waddr = env_sp; env_cap_wdata = 1'b0; end
                                            env_sp_n = env_sp + 6'd1;
                                        end
                                        bump_csp();
                                        this_obj_n = n_obj;
                                        if (this_ok) begin
                                            begin vars_we = 1'b1; vars_waddr = var_this; vars_wdata = n_obj; end
                                            begin var_tag_we = 1'b1; var_tag_waddr = var_this; var_tag_wdata = 3'd1; end
                                        end
                                        if (n_obj >= 16'(MAX_OBJ - 2)) dbg_heap_ovf_n = dbg_heap_ovf + 16'd1;
                                        n_obj_n = (n_obj >= 16'(MAX_OBJ - 2)) ? n_obj : (n_obj + 16'd2);
                                        ip_n = ctor_ip;
                                        code_raddr_n = 15'(ops_base + ctor_ip);
                                        state_n = S_FETCH_WAIT;
                                    end else begin
                                        // NEW: pop argc (was leaked). DOM event ctors
                                        // copy (type, options) like PYTHON bytecode.py.
                                        begin
                                            logic [7:0]  nac;
                                            logic [12:0] dst, src;
                                            logic [5:0]  nn;
                                            logic        is_dom;
                                            nac = code_rdata[31:24];
                                            dst = n_obj[12:0];
                                            begin obj_cls_we = 1'b1; obj_cls_waddr = dst; obj_cls_wdata = code_rdata[23:8]; end
                                            is_dom = (code_rdata[23:8] == id_kbevent)
                                                  || (code_rdata[23:8] == id_domevent)
                                                  || (code_rdata[23:8] == id_customev)
                                                  || (code_rdata[23:8] == id_mouseev);
                                            nn = 6'd0;
                                            if (is_dom && nac >= 8'd1 &&
                                                stack_tag[sp - nac] == 3'd3 &&
                                                id_type != 16'hFFFF) begin
            // flatten: heap write via S_HEAP_* only
            // flatten: heap write via S_HEAP_* only
            // flatten: heap write via S_HEAP_* only
                                                nn = 6'd1;
                                            end
                                            if (is_dom && nac >= 8'd2 &&
                                                stack_tag[sp - nac + 8'd1] == 3'd1) begin
                                                src = stack[sp - nac + 8'd1][12:0];
                                            end
                                            begin obj_n_we = 1'b1; obj_n_waddr = dst; obj_n_wdata = nn; end
                                            begin stack_we = 1'b1; stack_waddr = sp - nac; stack_wdata = {16'd0, n_obj}; end
                                            begin stack_tag_we = 1'b1; stack_tag_waddr = sp - nac; stack_tag_wdata = 3'd1; end
                                            n_obj_n = (n_obj >= 16'(MAX_OBJ - 1)) ? n_obj : (n_obj + 16'd1);
                                            sp_n = (nac == 8'd0) ? (sp + 8'd1) : (sp - nac + 8'd1);
                                            next_op();
                                        end
                                    end
                                end
                            end
                            OP_CALL_METH: begin
                                // [obj, args...] a0=meth intern a1=argc
                                if (stack_tag[sp - 8'(code_rdata[31:24]) - 8'd1] == 3'd2 &&
                                    code_rdata[23:8] == id_push) begin
                                    begin
                                        logic [11:0] ai;
                                        logic [7:0] al;
                                        ai = stack[sp - 8'(code_rdata[31:24]) - 8'd1][11:0];
                                        al = arr_len[ai];
                                        if (al < ARR_CAP[7:0]) begin
                                            begin arr_len_we = 1'b1; arr_len_waddr = ai; arr_len_wdata = al + 8'd1; end
                                            // NEW: keep only if dest array is
                                            // old-space (global arr.push). Finder
                                            // new_list.push(to) is nursery — rewind.
                                            // Deep: grids.push(new Grid()) must also
                                            // keep the fields the ctor built after it.
                                            if (arr_keep_ok && {4'd0, ai} < n_arr_keep)
                                                commit_deep_keep(stack_tag[sp - 8'd1]);
                                            hp_cmd_n = HP_ASETI;
                                            hp_v64_n = 1'b0;
                                            hp_from_stack_n = 1'b0;
                                            hp_aid_n = ai;
                                            hp_aslot_n = al[6:0];
                                            hp_wval_n = {32'd0, stack[sp - 8'd1]};
                                            hp_tag_n = stack_tag[sp - 8'd1];
                                            hp_ret_n = S_FETCH_WAIT;
                                            state_n = S_HEAP_AWR;
                                        end
                                        begin stack_we = 1'b1; stack_waddr = sp - 8'(code_rdata[31:24]) - 8'd1; stack_wdata = {24'd0, al + 8'd1}; end
                                        begin stack_tag_we = 1'b1; stack_tag_waddr = sp - 8'(code_rdata[31:24]) - 8'd1; stack_tag_wdata = 3'd0; end
                                        sp_n = sp - 8'(code_rdata[31:24]);
                                        ip_n = ip + 16'd1;
                                        code_raddr_n = 15'(ops_base + ip + 16'd1);
                                        if (al >= ARR_CAP[7:0])
                                            state_n = S_FETCH_WAIT;
                                    end
                                end else if (stack_tag[sp - 8'(code_rdata[31:24]) - 8'd1] == 3'd2 &&
                                           code_rdata[23:8] == id_fill) begin
                                    // arr.fill(v) — not ctx.fill()
                                    begin
                                        logic [11:0] ai;
                                        logic [7:0] al;
                                        ai = stack[sp - 8'(code_rdata[31:24]) - 8'd1][11:0];
                                        al = arr_len[ai];
                                        stack_we = 1'b1; stack_waddr = sp - 8'(code_rdata[31:24]) - 8'd1; stack_wdata =
                                            stack[sp - 8'(code_rdata[31:24]) - 8'd1];
                                        begin stack_tag_we = 1'b1; stack_tag_waddr = sp - 8'(code_rdata[31:24]) - 8'd1; stack_tag_wdata = 3'd2; end
                                        sp_n = sp - 8'(code_rdata[31:24]);
                                        ip_n = ip + 16'd1;
                                        code_raddr_n = 15'(ops_base + ip + 16'd1);
                                        if (al != 8'd0) begin
                                            hp_cmd_n = HP_AFILL;
                                            hp_v64_n = 1'b0;
                                            hp_from_stack_n = 1'b0;
                                            hp_aid_n = ai;
                                            hp_aslot_n = 7'd0;
                                            hp_lim_n = al;
                                            hp_wval_n = (code_rdata[31:24] >= 8'd1)
                                                ? {32'd0, stack[sp - 8'd1]} : 64'd0;
                                            hp_tag_n = (code_rdata[31:24] >= 8'd1)
                                                ? stack_tag[sp - 8'd1] : 3'd0;
                                            hp_ret_n = S_FETCH_WAIT;
                                            state_n = S_HEAP_FILL;
                                        end else
                                            state_n = S_FETCH_WAIT;
                                    end
                                end else if (stack_tag[sp - 8'(code_rdata[31:24]) - 8'd1] == 3'd2 &&
                                           (code_rdata[23:8] == id_foreach ||
                                            code_rdata[23:8] == 16'd112 ||
                                            code_rdata[23:8] == id_map ||
                                            code_rdata[23:8] == id_find ||
                                            (id_findindex != 16'hFFFF &&
                                             code_rdata[23:8] == id_findindex) ||
                                            (id_filter != 16'hFFFF &&
                                             code_rdata[23:8] == id_filter))) begin
                                    // arr.forEach/map/find/findIndex/filter
                                    cstack_ip_n[csp] = ip + 16'd1;
                                    cstack_this_n[csp] = this_obj;
                                    cstack_isctor_n[csp] = (id_filter != 16'hFFFF &&
                                                           code_rdata[23:8] == id_filter);
                                    cstack_isfe_n[csp] = 1'b1;
                                    cstack_fe_arr_n[csp] = stack[sp - 8'(code_rdata[31:24]) - 8'd1][15:0];
                                    cstack_fe_fn_n[csp] = stack[sp - 8'd1][15:0];
                                    cstack_ctorobj_n[csp] = {8'd0, fn_nparam(stack[sp - 8'd1][15:0])};
                                    cstack_fe_i_n[csp] = 8'd0;
                                    if (code_rdata[23:8] == id_map) begin
                                        arr_len_we = 1'b1; arr_len_waddr = n_arr[11:0]; arr_len_wdata =
                                            arr_len[stack[sp - 8'(code_rdata[31:24]) - 8'd1][11:0]];
                                        cstack_map_arr_n[csp] = n_arr;
                                        // NEW: map() output is nursery; SET_PROP
                                        // commits if stored. Do not freeze temps.
                                        if (n_arr >= 16'(MAX_ARR - 1)) dbg_heap_ovf_n = dbg_heap_ovf + 16'd1;
                                        n_arr_n = (n_arr >= 16'(MAX_ARR - 1)) ? n_arr : (n_arr + 16'd1);
                                    end else if (code_rdata[23:8] == id_filter) begin
                                        begin arr_len_we = 1'b1; arr_len_waddr = n_arr[11:0]; arr_len_wdata = 8'd0; end
                                        cstack_map_arr_n[csp] = n_arr;
                                        if (n_arr >= 16'(MAX_ARR - 1)) dbg_heap_ovf_n = dbg_heap_ovf + 16'd1;
                                        n_arr_n = (n_arr >= 16'(MAX_ARR - 1)) ? n_arr : (n_arr + 16'd1);
                                    end else if (id_find != 16'hFFFF &&
                                                code_rdata[23:8] == id_find)
                                        cstack_map_arr_n[csp] = 16'hFFFE;  // find sentinel
                                    else if (id_findindex != 16'hFFFF &&
                                             code_rdata[23:8] == id_findindex)
                                        cstack_map_arr_n[csp] = 16'hFFFD;  // findIndex sentinel
                                    else
                                        cstack_map_arr_n[csp] = 16'hFFFF;
                                    cstack_env_n[csp] = env_sp;
                                    bump_csp();
                                    sp_n = sp - 8'(code_rdata[31:24]) - 8'd1;
                                    state_n = S_FOREACH;
                                end else if (stack_tag[sp - 8'(code_rdata[31:24]) - 8'd1] == 3'd2 &&
                                           code_rdata[23:8] == id_unshift) begin
                                    // arr.unshift(v) — insert at 0
                                    begin
                                        logic [11:0] ai;
                                        logic [7:0] al;
                                        ai = stack[sp - 8'(code_rdata[31:24]) - 8'd1][11:0];
                                        al = arr_len[ai];
                                        if (al < ARR_CAP[7:0]) begin
                                            begin arr_len_we = 1'b1; arr_len_waddr = ai; arr_len_wdata = al + 8'd1; end
                                            if (arr_keep_ok && {4'd0, ai} < n_arr_keep)
                                                commit_deep_keep(stack_tag[sp - 8'd1]);
                                        begin stack_we = 1'b1; stack_waddr = sp - 8'(code_rdata[31:24]) - 8'd1; stack_wdata = {24'd0, al + 8'd1}; end
                                            begin stack_tag_we = 1'b1; stack_tag_waddr = sp - 8'(code_rdata[31:24]) - 8'd1; stack_tag_wdata = 3'd0; end
                                            sp_n = sp - 8'(code_rdata[31:24]);
                                            ip_n = ip + 16'd1;
                                            code_raddr_n = 15'(ops_base + ip + 16'd1);
                                            if (al == 8'd0) begin
                                                hp_cmd_n = HP_ASETI;
                                                hp_v64_n = 1'b0;
                                                hp_from_stack_n = 1'b0;
                                                hp_aid_n = ai;
                                                hp_aslot_n = 7'd0;
                                                hp_wval_n = (code_rdata[31:24] >= 8'd1)
                                                    ? {32'd0, stack[sp - 8'd1]} : 64'd0;
                                                hp_tag_n = (code_rdata[31:24] >= 8'd1)
                                                    ? stack_tag[sp - 8'd1] : 3'd5;
                                                hp_ret_n = S_FETCH_WAIT;
                                                state_n = S_HEAP_AWR;
                                            end else begin
                                                hp_cmd_n = HP_UNSHIFT;
                                                hp_v64_n = 1'b0;
                                                hp_from_stack_n = 1'b0;
                                                hp_aid_n = ai;
                                                hp_aslot_n = al[6:0] - 7'd1;
                                                hp_alen_n = al;
                                                hp_rval_n = (code_rdata[31:24] >= 8'd1)
                                                    ? {32'd0, stack[sp - 8'd1]} : 64'd0;
                                                hp_tag_n = (code_rdata[31:24] >= 8'd1)
                                                    ? stack_tag[sp - 8'd1] : 3'd5;
                                                hp_phase_n = 3'd0;
                                                hp_ret_n = S_FETCH_WAIT;
                                                state_n = S_HEAP_WAIT;
                                            end
                                        end else begin
                                            begin stack_we = 1'b1; stack_waddr = sp - 8'(code_rdata[31:24]) - 8'd1; stack_wdata = {24'd0, al}; end
                                        begin stack_tag_we = 1'b1; stack_tag_waddr = sp - 8'(code_rdata[31:24]) - 8'd1; stack_tag_wdata = 3'd0; end
                                        sp_n = sp - 8'(code_rdata[31:24]);
                                        next_op();
                                        end
                                    end
                                end else if (stack_tag[sp - 8'(code_rdata[31:24]) - 8'd1] == 3'd2 &&
                                           code_rdata[23:8] == id_splice) begin
                                    // splice(start, n) — shift-delete (INVADERS cull)
                                    begin
                                        logic [11:0] ai;
                                        logic [7:0] st, cnt;
                                        dbg_splice_n_n = dbg_splice_n + 16'd1;
                                        ai = stack[sp - 8'(code_rdata[31:24]) - 8'd1][11:0];
                                        st = (code_rdata[31:24] >= 8'd1) ? stack[sp - 8'(code_rdata[31:24])][7:0] : 8'd0;
                                        cnt = (code_rdata[31:24] >= 8'd2) ? stack[sp - 8'd1][7:0] : 8'd1;
                                        if (st < arr_len[ai]) begin
                                            if (arr_len[ai] > cnt) begin arr_len_we = 1'b1; arr_len_waddr = ai; arr_len_wdata = arr_len[ai] - cnt; end
                                            else begin arr_len_we = 1'b1; arr_len_waddr = ai; arr_len_wdata = 8'd0; end
                                            begin stack_we = 1'b1; stack_waddr = sp - 8'(code_rdata[31:24]) - 8'd1; stack_wdata = 32'sd0; end
                                            begin stack_tag_we = 1'b1; stack_tag_waddr = sp - 8'(code_rdata[31:24]) - 8'd1; stack_tag_wdata = 3'd2; end
                                            sp_n = sp - 8'(code_rdata[31:24]);
                                            ip_n = ip + 16'd1;
                                            code_raddr_n = 15'(ops_base + ip + 16'd1);
                                            hp_cmd_n = HP_SPLICE;
                                            hp_v64_n = 1'b0;
                                            hp_from_stack_n = 1'b0;
                                            hp_aid_n = ai;
                                            hp_aslot_n = st[6:0] + cnt[6:0];
                                            hp_alen_n = arr_len[ai];
                                            hp_lim_n = {1'b0, cnt};
                                            hp_ret_n = S_FETCH_WAIT;
                                            state_n = S_HEAP_WAIT;
                                        end else begin
                                        begin stack_we = 1'b1; stack_waddr = sp - 8'(code_rdata[31:24]) - 8'd1; stack_wdata = 32'sd0; end
                                        begin stack_tag_we = 1'b1; stack_tag_waddr = sp - 8'(code_rdata[31:24]) - 8'd1; stack_tag_wdata = 3'd2; end
                                        sp_n = sp - 8'(code_rdata[31:24]);
                                        next_op();
                                        end
                                    end
                                end else if (stack_tag[sp - 8'(code_rdata[31:24]) - 8'd1] == 3'd2 &&
                                           code_rdata[23:8] == id_join) begin
                                    // NEW: arr.join('') — hash the digit chars with the
                                    // encoder's u16 hash, then reverse-map to an interned
                                    // name so string EQ (intern-id compare) just works.
                                    // PACMAN maze wall-shape switch: neighbors.join('')=='1100'
                                    jn_arr_n = stack[sp - 8'(code_rdata[31:24]) - 8'd1][11:0];
                                    jn_i_n = 16'd0; jn_h_n = 16'd0;
                                    jn_res_n = 11'(sp - 8'(code_rdata[31:24]) - 8'd1);
                                    sp_n = sp - 8'(code_rdata[31:24]);
                                    ip_n = ip + 16'd1;
                                    state_n = S_JOIN;
                                end else if (stack_tag[sp - 8'(code_rdata[31:24]) - 8'd1] == 3'd2 &&
                                           code_rdata[23:8] == id_indexof &&
                                           code_rdata[31:24] >= 8'd1) begin
                                    // NEW: arr.indexOf(v) — linear scan, -1 when absent (FM twin)
                                    jn_arr_n = stack[sp - 8'(code_rdata[31:24]) - 8'd1][11:0];
                                    jn_i_n = 16'd0;
                                    idx_v_n = $signed(stack[sp - 8'(code_rdata[31:24])]);
                                    idx_t_n = stack_tag[sp - 8'(code_rdata[31:24])];
                                    jn_res_n = 11'(sp - 8'(code_rdata[31:24]) - 8'd1);
                                    sp_n = sp - 8'(code_rdata[31:24]);
                                    ip_n = ip + 16'd1;
                                    state_n = S_IDXOF;
                                end else if (code_rdata[23:8] == id_replace &&
                                           code_rdata[31:24] >= 8'd2 &&
                                           (stack_tag[sp - 8'(code_rdata[31:24]) - 8'd1] == 3'd3 ||
                                            (stack_tag[sp - 8'(code_rdata[31:24]) - 8'd1] == 3'd1 &&
                                             obj_cls[stack[sp - 8'(code_rdata[31:24]) - 8'd1][12:0]] == CLS_DYNSTR))) begin
                                    // String.replace — dynstr or interned 1-char; pattern
                                    // is packed RegExp or interned/int. Any HTML.
                                    begin
                                        logic [7:0] ac;
                                        logic [15:0] recv, p0;
                                        logic [2:0]  rt, pt;
                                        logic [31:0] preg;
                                        ac = code_rdata[31:24];
                                        recv = stack[sp - ac - 8'd1][15:0];
                                        rt = stack_tag[sp - ac - 8'd1];
                                        p0 = stack[sp - ac][15:0];
                                        pt = stack_tag[sp - ac];
                                        json_res_n = 11'(sp - ac - 8'd1);
                                        sp_n = sp - ac;
                                        ip_n = ip + 16'd1;
                                        repl_g_n = 1'b0; repl_nlen_n = 8'd1; repl_pat1_n = 8'd0;
                                        repl_pat0_n = 8'd0;
                                        if (pt == 3'd1 && obj_cls[p0[12:0]] == CLS_REGEX) begin
                                            hp_cmd_n = HP_OGETI;
                                            hp_v64_n = 1'b0;
                                            hp_oid_n = p0[12:0];
                                            hp_slot_n = 5'd0;
                                            hp_qn_n = 3'd1;
                                            hp_qi_n = 3'd0;
                                            hp_nat_n = 4'd10;
                                            hp_si_n = recv[12:0];
                                            hp_phase_n = (rt == 3'd1) ? 3'd1 : 3'd0;
                                            hp_ret_n = S_V64_OGETI_NAT;
                                            state_n = S_HEAP_WAIT;
                                        end else if (pt == 3'd3 && name_len_tbl[p0[9:0]] == 8'd1)
                                            repl_pat0_n = name_hash_tbl[p0[9:0]][7:0];
                                        else if (pt == 3'd0)
                                            repl_pat0_n = 8'(fxi(stack[sp - ac], pt) + 32'sd48);
                                        // replacement: int → digit, intern 1-char, else '0'
                                        if (stack_tag[sp - 8'd1] == 3'd3 &&
                                            name_len_tbl[stack[sp - 8'd1][9:0]] == 8'd1)
                                            repl_rch_n = name_hash_tbl[stack[sp - 8'd1][9:0]][7:0];
                                        else if (stack_tag[sp - 8'd1] == 3'd0)
                                            repl_rch_n = 8'(fxi(stack[sp - 8'd1], 3'd0) + 32'sd48);
                                        else
                                            repl_rch_n = 8'h30;
                                        if (!(pt == 3'd1 && obj_cls[p0[12:0]] == CLS_REGEX) &&
                                            rt == 3'd1) begin
                                            hp_cmd_n = HP_OGETI;
                                            hp_v64_n = 1'b0;
                                            hp_oid_n = recv[12:0];
                                            hp_slot_n = 5'd0;
                                            hp_qn_n = 3'd2;
                                            hp_qi_n = 3'd0;
                                            hp_nat_n = 4'd7;
                                            hp_lim_n = 8'd1;
                                            hp_ret_n = S_V64_OGETI_NAT;
                                            state_n = S_HEAP_WAIT;
                                        end else if (name_len_tbl[recv[9:0]] == 8'd1 &&
                                                     !name_has[recv[9:0]]) begin
                                            // interned 1-char without NAMB: hash == byte
                                            begin json_mem_we = 1'b1; json_mem_waddr = 0; json_mem_wdata = name_hash_tbl[recv[9:0]][7:0]; end
                                            json_src_n = 14'd0;
                                            json_srclen_n = 14'd1;
                                            json_rp_n = 14'd0;
                                            json_dst_n = 14'd1;
                                            json_wp_n = 14'd1;
                                            state_n = S_REPL;
                                        end else begin
                                            // interned longer: copy name_mem → json_mem
                                            json_src_n = 14'd0;
                                            json_srclen_n = {6'd0, name_len_tbl[recv[9:0]]};
                                            json_rp_n = 14'd0;
                                            name_rdaddr_n = name_off[recv[9:0]];
                                            json_wp_n = 14'd0;
                                            namcpy_repl_n = 1'b1;
                                            namcpy_armed_n = 1'b0;
                                            state_n = S_NAMCPY;
                                        end
                                        repl_did_n = 1'b0;
                                    end
                                end else if (code_rdata[23:8] == id_indexof &&
                                           code_rdata[31:24] >= 8'd1 &&
                                           stack_tag[sp - 8'(code_rdata[31:24]) - 8'd1] == 3'd1 &&
                                           obj_cls[stack[sp - 8'(code_rdata[31:24]) - 8'd1][12:0]] == CLS_DYNSTR) begin
                                    // dynstr.indexOf(v) — JS coerces number 0 → "0"
                                    begin
                                        logic [7:0] ac;
                                        logic [15:0] recv;
                                        ac = code_rdata[31:24];
                                        recv = stack[sp - ac - 8'd1][15:0];
                                        json_res_n = 11'(sp - ac - 8'd1);
                                        if (stack_tag[sp - ac] == 3'd3 &&
                                            name_len_tbl[stack[sp - ac][9:0]] == 8'd1)
                                            idx_needle_n = name_hash_tbl[stack[sp - ac][9:0]][7:0];
                                        else
                                            idx_needle_n = 8'(fxi(stack[sp - ac], stack_tag[sp - ac]) + 32'sd48);
                                        sp_n = sp - ac;
                                        ip_n = ip + 16'd1;
                                        hp_cmd_n = HP_OGETI;
                                        hp_v64_n = 1'b0;
                                        hp_oid_n = recv[12:0];
                                        hp_slot_n = 5'd0;
                                        hp_qn_n = 3'd2;
                                        hp_qi_n = 3'd0;
                                        hp_nat_n = 4'd7;
                                        hp_lim_n = 8'd2;
                                        hp_ret_n = S_V64_OGETI_NAT;
                                        state_n = S_HEAP_WAIT;
                                    end
                                end else if (code_rdata[23:8] == id_ael) begin
                                    // el.addEventListener(type, fn) — table, not last-wins
                                    if (stack[sp - 8'd2][15:0] == id_keydown)
                                        add_key_listener(1'b1, stack[sp - 8'd1][15:0]);
                                    if (stack[sp - 8'd2][15:0] == id_keyup)
                                        add_key_listener(1'b0, stack[sp - 8'd1][15:0]);
                                    if (stack[sp - 8'd2][15:0] == id_click && click_fn == 16'hFFFF)
                                        click_fn_n = stack[sp - 8'd1][15:0];
                                    begin stack_we = 1'b1; stack_waddr = sp - 8'(code_rdata[31:24]) - 8'd1; stack_wdata = 32'sd0; end
                                    begin stack_tag_we = 1'b1; stack_tag_waddr = sp - 8'(code_rdata[31:24]) - 8'd1; stack_tag_wdata = 3'd5; end
                                    sp_n = sp - 8'(code_rdata[31:24]);
                                    next_op();
                                end else if (code_rdata[23:8] == id_rel) begin
                                    // el.removeEventListener(type, fn)
                                    if (stack[sp - 8'd2][15:0] == id_keydown)
                                        remove_key_listener(1'b1, stack[sp - 8'd1][15:0]);
                                    if (stack[sp - 8'd2][15:0] == id_keyup)
                                        remove_key_listener(1'b0, stack[sp - 8'd1][15:0]);
                                    begin stack_we = 1'b1; stack_waddr = sp - 8'(code_rdata[31:24]) - 8'd1; stack_wdata = 32'sd0; end
                                    begin stack_tag_we = 1'b1; stack_tag_waddr = sp - 8'(code_rdata[31:24]) - 8'd1; stack_tag_wdata = 3'd5; end
                                    sp_n = sp - 8'(code_rdata[31:24]);
                                    next_op();
                                end else if (code_rdata[23:8] == id_disp) begin
                                    // el.dispatchEvent(ev) — fire listeners now (PYTHON parity)
                                    if (code_rdata[31:24] >= 8'd1 &&
                                        stack_tag[sp - 8'd1] == 3'd1 &&
                                        kd_n != 3'd0 && kd_slot[0] != 16'hFFFF) begin
                                        logic [15:0] oid;
                                        oid = stack[sp - 8'd1][15:0];
                                        kev_obj_n = oid;
                                        kev_fn_n = kd_slot[0];
                                        kev_li_n = 2'd0;
                                        kev_is_down_n = 1'b1;
                                        kev_ret_ip_n = ip + 16'd1;
                                        begin stack_we = 1'b1; stack_waddr = 0; stack_wdata = {16'd0, oid}; end
                                        begin stack_tag_we = 1'b1; stack_tag_waddr = 0; stack_tag_wdata = 3'd1; end
                                        boundary_sp(11'd1);
                                        cstack_ip_n[csp] = 16'hFFFD;
                                        cstack_this_n[csp] = this_obj;
                                        cstack_isctor_n[csp] = 1'b0;
                                        cstack_isfe_n[csp] = 1'b0;
                                        state_n = S_KEYEV;
                                    end else begin
                                        begin stack_we = 1'b1; stack_waddr = sp - 8'(code_rdata[31:24]) - 8'd1; stack_wdata = 32'sd1; end
                                        begin stack_tag_we = 1'b1; stack_tag_waddr = sp - 8'(code_rdata[31:24]) - 8'd1; stack_tag_wdata = 3'd0; end
                                        sp_n = sp - 8'(code_rdata[31:24]);
                                        next_op();
                                    end
                                end else if (stack_tag[sp - 8'(code_rdata[31:24]) - 8'd1] == 3'd6 &&
                                           code_rdata[23:8] == id_getctx) begin
                                    begin stack_we = 1'b1; stack_waddr = sp - 8'(code_rdata[31:24]) - 8'd1; stack_wdata = 32'd1; end  // canvas2d elem
                                    begin stack_tag_we = 1'b1; stack_tag_waddr = sp - 8'(code_rdata[31:24]) - 8'd1; stack_tag_wdata = 3'd6; end
                                    sp_n = sp - 8'(code_rdata[31:24]);
                                    next_op();
                                end else if (stack_tag[sp - 8'(code_rdata[31:24]) - 8'd1] == 3'd6 &&
                                           code_rdata[23:8] == id_click) begin
                                    if (click_fn != 16'hFFFF) begin
                                        click_fired_n = 1'b1;
                                        cstack_ip_n[csp] = ip + 16'd1;
                                        cstack_this_n[csp] = this_obj;
                                        cstack_isctor_n[csp] = 1'b0;
                                        cstack_isfe_n[csp] = 1'b0;
                                        enter_captured_fn(click_fn);
                                        bump_csp();
                                        ip_n = fn_entry(click_fn);
                                        code_raddr_n = 15'(ops_base + fn_entry(click_fn));
                                        sp_n = sp - 8'(code_rdata[31:24]) - 8'd1;
                                        state_n = S_FETCH_WAIT;
                                    end else begin
                                        sp_n = sp - 8'(code_rdata[31:24]);
                                        next_op();
                                    end
                                end else if (code_rdata[23:8] == id_now ||
                                           code_rdata[23:8] == id_gettime) begin
                                    // Date.now() / date.getTime() — pure READ of the frame
                                    // clock (advances once per frame in S_WAIT_FRAME, FM twin)
                                    begin
                                        begin stack_we = 1'b1; stack_waddr = sp - 8'(code_rdata[31:24]) - 8'd1; stack_wdata = time_ms; end
                                        begin stack_tag_we = 1'b1; stack_tag_waddr = sp - 8'(code_rdata[31:24]) - 8'd1; stack_tag_wdata = 3'd0; end
                                        sp_n = sp - 8'(code_rdata[31:24]);
                                        next_op();
                                    end
                                end else if (stack_tag[sp - 8'(code_rdata[31:24]) - 8'd1] == 3'd1 &&
                                            obj_cls[stack[sp - 8'(code_rdata[31:24]) - 8'd1][12:0]] == 16'hFFFD &&
                                            code_rdata[31:24] == 8'd0) begin
                                    // (new Date()).getTime() even if intern id_gettime missed
                                    // — pure READ of the frame clock (FM twin)
                                    begin
                                        begin stack_we = 1'b1; stack_waddr = sp - 8'd1; stack_wdata = time_ms; end
                                        begin stack_tag_we = 1'b1; stack_tag_waddr = sp - 8'd1; stack_tag_wdata = 3'd0; end
                                        next_op();
                                    end
                                end else if (code_rdata[23:8] == id_bind &&
                                           stack_tag[sp - 8'(code_rdata[31:24]) - 8'd1] == 3'd4) begin
                                    // fn.bind(this) — leave the fn (PYTHON copies bound_this)
                                    // NEW: FUNCTION receivers only (FM cls_name=="Fn") —
                                    // swallowing stage.bind('keydown',cb) killed PACMAN keys
                                    sp_n = sp - 8'(code_rdata[31:24]);
                                    next_op();
                                end else if (code_rdata[23:8] == id_assign) begin
                                    // Object.assign — sequential HP_ASSIGN (no 32×32 mux)
                                    begin
                                        logic [7:0] aca;
                                        aca = code_rdata[31:24];
                                        begin stack_we = 1'b1; stack_waddr = sp - aca - 8'd1; stack_wdata = stack[sp - aca]; end
                                        begin stack_tag_we = 1'b1; stack_tag_waddr = sp - aca - 8'd1; stack_tag_wdata = stack_tag[sp - aca]; end
                                        if (stack_tag[sp - aca] == 3'd1 && aca >= 8'd2 &&
                                            stack_tag[sp - aca + 8'd1] == 3'd1) begin
                                            hp_cmd_n = HP_ASSIGN;
                                            hp_v64_n = 1'b0;
                                            hp_oid_n = stack[sp - aca][12:0];
                                            hp_si_n = stack[sp - aca + 8'd1][12:0];
                                            hp_ss_n = 5'd0;
                                            hp_phase_n = 3'd0;
                                            hp_tn_n = obj_n[stack[sp - aca][12:0]];
                                            hp_qi_n = 3'd0;
                                            hp_qn_n = aca[2:0] - 3'd1;
                                            hp_vbase_n = {1'b0, sp} - {4'd0, aca} + 12'd1;
                                            hp_ret_n = S_FETCH_WAIT;
                                            sp_n = sp - aca;
                                            ip_n = ip + 16'd1;
                                            code_raddr_n = 15'(ops_base + ip + 16'd1);
                                            state_n = S_HEAP_WAIT;
                                        end else begin
                                        sp_n = sp - aca;
                                        next_op();
                                        end
                                    end
                                end else if (code_rdata[23:8] == id_save) begin
                                    saved_tx_n = ctx_tx; saved_ty_n = ctx_ty;
                                    saved_sx_n = ctx_sx; saved_sy_n = ctx_sy;  // NEW: FM saves scale too
                                    sp_n = sp - 8'(code_rdata[31:24]);
                                    next_op();
                                end else if (code_rdata[23:8] == id_restore) begin
                                    ctx_tx_n = saved_tx; ctx_ty_n = saved_ty;
                                    ctx_sx_n = saved_sx; ctx_sy_n = saved_sy;  // NEW
                                    sp_n = sp - 8'(code_rdata[31:24]);
                                    next_op();
                                end else if (code_rdata[23:8] == id_translate) begin
                                    ctx_tx_n = ctx_tx + sti(sp - 9'd2);
                                    ctx_ty_n = ctx_ty + sti(sp - 9'd1);
                                    sp_n = sp - 8'(code_rdata[31:24]);
                                    next_op();
                                end else if (code_rdata[23:8] == id_settransform &&
                                           code_rdata[31:24] >= 8'd6) begin
                                    // NEW: setTransform(a,b,c,d,e,f) — FM spec
                                    // (bytecode.py): _sx=a or 1, _sy=d or 1,
                                    // _tx=e, _ty=f. Shear b,c ignored like FM.
                                    ctx_sx_n = (stfx(sp - 9'd6) == 32'sd0) ? FX_ONE : stfx(sp - 9'd6);
                                    ctx_sy_n = (stfx(sp - 9'd3) == 32'sd0) ? FX_ONE : stfx(sp - 9'd3);
                                    ctx_tx_n = sti(sp - 9'd2);
                                    ctx_ty_n = sti(sp - 9'd1);
                                    sp_n = sp - 8'(code_rdata[31:24]);
                                    next_op();
                                end else if (code_rdata[23:8] == id_rotate) begin
                                    sp_n = sp - 8'(code_rdata[31:24]);
                                    next_op();
                                end else if (code_rdata[23:8] == id_beginpath ||
                                           code_rdata[23:8] == id_closepath) begin
                                    // NEW: beginPath resets the command buffer;
                                    // closePath is a no-op like FM _raster_path "Z"
                                    if (code_rdata[23:8] == id_beginpath) pc_n_n = 5'd0;
                                    path_kind_n = 2'd0;
                                    sp_n = sp - 8'(code_rdata[31:24]);
                                    next_op();
                                end else if (code_rdata[23:8] == id_arc && code_rdata[31:24] >= 8'd3) begin
                                    // NEW: record raw fx args (FM records argv; _xf at raster)
                                    if (pc_n < 5'(PATH_MAX)) begin
                                        pc_op_n[pc_n[3:0]] = 2'd3;
                                        pc_a1_n[pc_n[3:0]] = stfx(sp - 9'(code_rdata[31:24]));
                                        pc_a2_n[pc_n[3:0]] = stfx(sp - 9'(code_rdata[31:24]) + 9'd1);
                                        pc_a3_n[pc_n[3:0]] = stfx(sp - 9'(code_rdata[31:24]) + 9'd2);
                                        pc_a4_n[pc_n[3:0]] = (code_rdata[31:24] > 8'd3)
                                            ? stfx(sp - 9'(code_rdata[31:24]) + 9'd3) : 32'sd0;
                                        pc_a5_n[pc_n[3:0]] = (code_rdata[31:24] > 8'd4)
                                            ? stfx(sp - 9'(code_rdata[31:24]) + 9'd4) : 32'sd0;
                                        pc_ccw_n[pc_n[3:0]] = (code_rdata[31:24] > 8'd5)
                                            && (stack[sp - 9'd1] != 32'd0);
                                        pc_n_n = pc_n + 5'd1;
                                    end else dbg_path_ovf_n = dbg_path_ovf + 16'd1;
                                    sp_n = sp - 8'(code_rdata[31:24]);
                                    next_op();
                                end else if ((code_rdata[23:8] == id_moveto ||
                                            code_rdata[23:8] == id_lineto) &&
                                           code_rdata[31:24] >= 8'd2) begin
                                    if (pc_n < 5'(PATH_MAX)) begin
                                        pc_op_n[pc_n[3:0]] = (code_rdata[23:8] == id_moveto) ? 2'd0 : 2'd1;
                                        pc_a1_n[pc_n[3:0]] = stfx(sp - 9'(code_rdata[31:24]));
                                        pc_a2_n[pc_n[3:0]] = stfx(sp - 9'(code_rdata[31:24]) + 9'd1);
                                        pc_n_n = pc_n + 5'd1;
                                    end else dbg_path_ovf_n = dbg_path_ovf + 16'd1;
                                    sp_n = sp - 8'(code_rdata[31:24]);
                                    next_op();
                                end else if (code_rdata[23:8] == id_quadcurve &&
                                           code_rdata[31:24] >= 8'd4) begin
                                    // NEW: quadraticCurveTo(cx,cy,x,y)
                                    if (pc_n < 5'(PATH_MAX)) begin
                                        pc_op_n[pc_n[3:0]] = 2'd2;
                                        pc_a1_n[pc_n[3:0]] = stfx(sp - 9'd4);
                                        pc_a2_n[pc_n[3:0]] = stfx(sp - 9'd3);
                                        pc_a3_n[pc_n[3:0]] = stfx(sp - 9'd2);
                                        pc_a4_n[pc_n[3:0]] = stfx(sp - 9'd1);
                                        pc_n_n = pc_n + 5'd1;
                                    end else dbg_path_ovf_n = dbg_path_ovf + 16'd1;
                                    sp_n = sp - 8'(code_rdata[31:24]);
                                    next_op();
                                end else if (code_rdata[23:8] == id_fill ||
                                           code_rdata[23:8] == id_stroke) begin
                                    // NEW: walk the whole command buffer (FM
                                    // _raster_path). Path survives fill() —
                                    // only beginPath clears it, like FM.
                                    color_n = fill_style_i;
                                    path_stroke_n = (code_rdata[23:8] == id_stroke);
                                    sp_n = sp - 8'(code_rdata[31:24]);
                                    ip_n = ip + 16'd1;
                                    pi_n = 5'd0;
                                    path_active_n = 1'b1;
                                    state_n = S_PWALK;
                                end else if (code_rdata[23:8] == id_filltext) begin
                                    // NEW: real glyphs. args are (text, x, y[, maxW])
                                    // counted from the first one, so a 4-arg call
                                    // still finds x/y. The text value is latched
                                    // here because sp moves this cycle.
                                    begin
                                        logic [10:0] a0;
                                        a0 = sp - 11'(code_rdata[31:24]); // text slot
                                        color_n = fill_style_i;
                                        txt_val_n = stack[a0];
                                        txt_vt_n = stack_tag[a0];
                                        txt_ph_n = 4'd0;
                                        sp_n = sp - 8'(code_rdata[31:24]) - 8'd1;
                                        ip_n = ip + 16'd1;
                                        if (ctx_sx != FX_ONE || ctx_sy != FX_ONE) begin
                                            // scaled ctx (DONKEY world→glass): the pen
                                            // goes through the shared _xf multiplier
                                            xf_x_n = stfx(a0 + 11'd1);
                                            xf_y_n = stfx(a0 + 11'd2);
                                            xf_w_n = 32'sd0; xf_h_n = 32'sd0;
                                            xf_dst_n = 2'd2;
                                            state_n = S_XF_MUL;
                                        end else begin
                                            txt_px_n = 16'(sti(a0 + 11'd1) + ctx_tx);
                                            txt_py_n = 16'(sti(a0 + 11'd2) + ctx_ty);
                                            state_n = S_TXT_LD;
                                        end
                                    end
                                end else if (code_rdata[23:8] == id_measuretext) begin
                                    // NEW: {width} so games can right-align text.
                                    // Same geometry FM _nat_measure_text reports:
                                    // len x 8 x scale (scale folds ctx_sx below).
                                    //
                                    // ONE reserved metrics object, allocated on
                                    // first use and kept for good. A fresh object
                                    // per call is what a browser does, but here any
                                    // store into old space raises the keep
                                    // watermark to the bump pointer
                                    // (commit_deep_keep), so one new object per
                                    // frame walked that watermark up until the
                                    // array ring wrapped and recycled the oldest
                                    // live data — PACMAN's maze rows read back 0
                                    // and half the walls stopped being drawn.
                                    begin
                                        logic [7:0] ac;
                                        logic [15:0] tl;
                                        logic [15:0] px_;
                                        logic [15:0] moid;
                                        ac = code_rdata[31:24];
                                        tl = 16'd0;
                                        if (stack_tag[sp - ac] == 3'd3)
                                            tl = {8'd0, name_len_tbl[stack[sp - ac][9:0]]};
                                        else if (stack_tag[sp - ac] == 3'd1 &&
                                                 obj_cls[stack[sp - ac][12:0]] == CLS_DYNSTR) begin
                                            hp_cmd_n = HP_OGETI;
                                            hp_v64_n = 1'b0;
                                            hp_oid_n = stack[sp - ac][12:0];
                                            hp_slot_n = 5'd1;
                                            hp_qn_n = 3'd1;
                                            hp_qi_n = 3'd0;
                                            hp_nat_n = 4'd11;
                                            hp_vbase_n = {1'b0, sp} - {4'd0, ac};
                                            hp_ret_n = S_V64_OGETI_NAT;
                                            state_n = S_HEAP_WAIT;
                                        end else begin
                                        // px per char = font px (x ctx scale) rounded
                                        // to the 8-px glyph grid, same as fill_text
                                        px_ = 16'((48'(ctx_font_px) * 48'(ctx_sx)
                                                  + 48'sd262144) >>> 19);
                                        if (px_ == 16'd0) px_ = 16'd1;
                                        moid = (metrics_oid == 16'hFFFF) ? n_obj : metrics_oid;
                                        begin obj_cls_we = 1'b1; obj_cls_waddr = moid[12:0]; obj_cls_wdata = 16'd0; end  // plain object
                                        begin obj_n_we = 1'b1; obj_n_waddr = moid[12:0]; obj_n_wdata = 6'd1; end
            // flatten: heap write via S_HEAP_* only
            // flatten: heap write via S_HEAP_* only
            // flatten: heap write via S_HEAP_* only
                                        if (metrics_oid == 16'hFFFF) begin
                                            if (n_obj >= 16'(MAX_OBJ - 1))
                                                dbg_heap_ovf_n = dbg_heap_ovf + 16'd1;
                                            else begin
                                                metrics_oid_n = n_obj;
                                                n_obj_n = n_obj + 16'd1;
                                                // VM-owned: a rewind must never
                                                // recycle the slot metrics_oid names
                                                if ((n_obj + 16'd1) > n_obj_keep)
                                                    n_obj_keep_n = n_obj + 16'd1;
                                            end
                                        end
                                        begin stack_we = 1'b1; stack_waddr = sp - ac - 8'd1; stack_wdata = {16'd0, moid}; end
                                        begin stack_tag_we = 1'b1; stack_tag_waddr = sp - ac - 8'd1; stack_tag_wdata = 3'd1; end
                                        sp_n = sp - ac;
                                        next_op();
                                        end
                                    end
                                end else if (code_rdata[23:8] == id_drawimage) begin
                                    // real sprite blit when Image.src was jmr:spr:N
                                    begin
                                        logic [15:0] ioid;
                                        logic [7:0] ac, si;
                                        ac = code_rdata[31:24];
                                        // args: img at sp-ac, then dx,dy[,dw,dh] or 9-arg sheet
                                        ioid = stack[sp - ac][15:0];
                                        si = 8'(obj_cls[ioid[12:0]][3:0]); // NEW: 4-bit idx (16 sprites)
                                        if (obj_cls[ioid[12:0]][15:4] == 12'hFFC && {1'b0, si} < {4'd0, n_spr}) begin
                                            dbg_di_hit_n = dbg_di_hit + 16'd1;
                                            blit_si_n = si;
                                            if (ac >= 8'd9) begin
                                                // NEW: 16-bit source window (full-res ASET sheets)
                                                blit_sx_n = clip_src(sti(sp - 9'd8));
                                                blit_sy_n = clip_src(sti(sp - 9'd7));
                                                blit_sw_n = clip_src(sti(sp - 9'd6));
                                                blit_sh_n = clip_src(sti(sp - 9'd5));
                                            end else begin
                                                blit_sx_n = 16'd0; blit_sy_n = 16'd0;
                                                blit_sw_n = spr_ww[si[3:0]]; blit_sh_n = spr_hh[si[3:0]];
                                            end
                                            if (ctx_sx != FX_ONE || ctx_sy != FX_ONE) begin
                                                // NEW: scaled dest — FM _xf on dx,dy,dw,dh
                                                // (DONKEY setTransform world→glass)
                                                if (ac >= 8'd5) begin
                                                    xf_x_n = stfx(sp - 9'd4); xf_y_n = stfx(sp - 9'd3);
                                                    xf_w_n = stfx(sp - 9'd2); xf_h_n = stfx(sp - 9'd1);
                                                end else begin
                                                    xf_x_n = stfx(sp - 9'd2); xf_y_n = stfx(sp - 9'd1);
                                                    xf_w_n = 32'(spr_ww[si[3:0]]) <<< 16;
                                                    xf_h_n = 32'(spr_hh[si[3:0]]) <<< 16;
                                                end
                                                xf_dst_n = 2'd1;
                                                sp_n = sp - ac - 8'd1;
                                                ip_n = ip + 16'd1;
                                                state_n = S_XF_MUL;
                                            end else begin
                                                if (ac >= 8'd5) begin
                                                    rx_n = clip_u(sti(sp - 9'd4) + ctx_tx, MW);
                                                    ry_n = clip_u(sti(sp - 9'd3) + ctx_ty, MH);
                                                    rw_n = clip_sz(sti(sp - 9'd2), clip_u(sti(sp - 9'd4) + ctx_tx, MW), MW);
                                                    rh_n = clip_sz(sti(sp - 9'd1), clip_u(sti(sp - 9'd3) + ctx_ty, MH), MH);
                                                end else begin
                                                    rx_n = clip_u(sti(sp - 9'd2) + ctx_tx, MW);
                                                    ry_n = clip_u(sti(sp - 9'd1) + ctx_ty, MH);
                                                    // dest = natural size, clipped to the glass
                                                    rw_n = (spr_ww[si[3:0]] > 16'(MW)) ? 10'(MW) : spr_ww[si[3:0]][9:0];
                                                    rh_n = (spr_hh[si[3:0]] > 16'(MH)) ? 10'(MH) : spr_hh[si[3:0]][9:0];
                                                end
                                                x_n = 10'd0; y_n = 10'd0;
                                                sp_n = sp - ac - 8'd1;
                                                ip_n = ip + 16'd1;
                                                state_n = S_BLIT;
                                            end
                                        end else begin
                                            // no sprite — skip (do not paint a giant magenta box)
                                            dbg_di_miss_n = dbg_di_miss + 16'd1;
                                            sp_n = sp - ac - 8'd1;
                                            next_op();
                                        end
                                    end
                                end else if (code_rdata[23:8] == id_getimgdata) begin
                                    // ctx.getImageData(x,y,w,h) — copy back buffer (FM twin)
                                    begin
                                        logic signed [31:0] gx, gy, gw, gh;
                                        logic [9:0] x0, y0, ww, hh;
                                        logic [7:0] acg;
                                        acg = code_rdata[31:24];
                                        gx = (acg >= 8'd1) ? sti(sp - acg) : 32'sd0;
                                        gy = (acg >= 8'd2) ? sti(sp - acg + 8'd1) : 32'sd0;
                                        gw = (acg >= 8'd3) ? sti(sp - acg + 8'd2) : 32'sd0;
                                        gh = (acg >= 8'd4) ? sti(sp - acg + 8'd3) : 32'sd0;
                                        x0 = clip_u(gx, MW);
                                        y0 = clip_u(gy, MH);
                                        ww = clip_sz(gw, x0, MW);
                                        hh = clip_sz(gh, y0, MH);
                                        imgd_x0_n = x0; imgd_y0_n = y0;
                                        imgd_w_n = ww; imgd_h_n = hh;
                                        imgd_x_n = x0; imgd_y_n = y0;
                                        imgd_i_n = 19'd0;
                                        // 32-bit product: 10-bit ww*hh of 640×480
                                        // wrapped to 0 and skipped the copy (or a
                                        // 19-bit self-mul truncated the count).
                                        imgd_n_n = (32'(ww) * 32'(hh) > 32'(FB_PIXELS))
                                            ? 19'(FB_PIXELS) : 19'(32'(ww) * 32'(hh));
                                        imgd_armed_n = 1'b0;
                                        imgd_res_n = 11'(sp - acg - 8'd1);
                                        sp_n = sp - acg - 8'd1;
                                        ip_n = ip + 16'd1;
                                        fb_dump_sel_n = 1'b1;
                                        fb_dump_addr_n = 19'(y0) * 19'(MW) + 19'(x0);
                                        state_n = S_IMGD_GET;
                                    end
                                end else if (code_rdata[23:8] == id_putimgdata) begin
                                    // ctx.putImageData(img, dx, dy) — blit snapshot to back
                                    begin
                                        logic [7:0] acp;
                                        logic [15:0] src;
                                        acp = code_rdata[31:24];
                                        src = (acp >= 8'd1) ? stack[sp - acp][15:0] : 16'd0;
                                        if (acp >= 8'd1 && stack_tag[sp - acp] == 3'd1 &&
                                            obj_cls[src[12:0]] == CLS_IMGD) begin
                                            imgd_x0_n = (acp >= 8'd2) ? clip_u(sti(sp - acp + 8'd1), MW) : 10'd0;
                                            imgd_y0_n = (acp >= 8'd3) ? clip_u(sti(sp - acp + 8'd2), MH) : 10'd0;
                                            imgd_x_n = 10'd0; imgd_y_n = 10'd0;
                                            imgd_i_n = 19'd0;
                                            sp_n = sp - acp - 8'd1;
                                            ip_n = ip + 16'd1;
                                            hp_cmd_n = HP_OGETI;
                                            hp_v64_n = 1'b0;
                                            hp_oid_n = src[12:0];
                                            hp_slot_n = 5'd0;
                                            hp_qn_n = 3'd2;
                                            hp_qi_n = 3'd0;
                                            hp_nat_n = 4'd8;
                                            hp_ret_n = S_V64_OGETI_NAT;
                                            state_n = S_HEAP_WAIT;
                                        end else begin
                                            sp_n = sp - acp;
                                            next_op();
                                        end
                                    end
                                end else if (code_rdata[23:8] == id_fillrect ||
                                           code_rdata[23:8] == id_clearrect) begin
                                    // ctx.fillRect / clearRect(x,y,w,h) — intern ids only
                                    // (argc-4 fallback retired: it swallowed getImageData)
                                    color_n = (code_rdata[23:8] == id_clearrect) ? 8'd0 : fill_style_i;
                                    if (ctx_sx != FX_ONE || ctx_sy != FX_ONE) begin
                                        // NEW: scaled rect — FM _xf (DONKEY girders)
                                        xf_x_n = stfx(sp - 9'd4); xf_y_n = stfx(sp - 9'd3);
                                        xf_w_n = stfx(sp - 9'd2); xf_h_n = stfx(sp - 9'd1);
                                        xf_dst_n = 2'd0;
                                        sp_n = sp - 8'(code_rdata[31:24]) - 8'd1;
                                        ip_n = ip + 16'd1;
                                        state_n = S_XF_MUL;
                                    end else begin
                                        begin
                                            logic [9:0] tw, th, tx, ty;
                                            tx = clip_u(sti(sp - 9'd4) + ctx_tx, MW);
                                            ty = clip_u(sti(sp - 9'd3) + ctx_ty, MH);
                                            tw = clip_sz(sti(sp - 9'd2), tx, MW);
                                            th = clip_sz(sti(sp - 9'd1), ty, MH);
                                            rx_n = tx; ry_n = ty; rw_n = tw; rh_n = th;
                                            x_n = tx; y_n = ty;
                                        end
                                        sp_n = sp - 8'(code_rdata[31:24]) - 8'd1;
                                        ip_n = ip + 16'd1;  // else S_RECT re-fetches this fillRect forever
                                        state_n = S_RECT;
                                    end
                                end else begin
                                    // class method lookup — pop receiver, leave args
                                    begin
                                        logic [15:0] mip, oid;
                                        logic [2:0] ot;
                                        logic [7:0] ac;
                                        mip = 16'hFFFF;
                                        ac = code_rdata[31:24];
                                        ot = stack_tag[sp - ac - 8'd1];
                                        oid = stack[sp - ac - 8'd1][15:0];
                                        if (ot == 3'd1) begin
                                            for (int c = 0; c < MAX_CLS; c++) begin
                                                if (c < n_cls && cls_name[c] == obj_cls[oid[12:0]]) begin
                                                    for (int m = 0; m < MAX_CMETH; m++) begin
                                                        if (m < cls_nmeth[c] && cls_mname[c][m] == code_rdata[23:8])
                                                            mip = cls_mip[c][m];
                                                    end
                                                end
                                            end
                                        end
                                        if (mip != 16'hFFFF) begin
                                            for (int k = 0; k < 8; k++) begin
                                                if (k < ac) begin
                                                    begin stack_we = 1'b1; stack_waddr = sp - ac - 8'd1 + k[7:0]; stack_wdata = stack[sp - ac + k[7:0]]; end
                                                    begin stack_tag_we = 1'b1; stack_tag_waddr = sp - ac - 8'd1 + k[7:0]; stack_tag_wdata = stack_tag[sp - ac + k[7:0]]; end
                                                end
                                            end
                                            sp_n = sp - 8'd1;
                                            cstack_ip_n[csp] = ip + 16'd1;
                                            cstack_this_n[csp] = this_obj;
                                            cstack_isctor_n[csp] = 1'b0;
                                            cstack_isfe_n[csp] = 1'b0;
                                            cstack_env_n[csp] = env_sp;
                                            bump_csp();
                                            this_obj_n = oid;
                                            if (this_ok) begin
                                                begin vars_we = 1'b1; vars_waddr = var_this; vars_wdata = oid; end
                                                begin var_tag_we = 1'b1; var_tag_waddr = var_this; var_tag_wdata = 3'd1; end
                                            end
                                            ip_n = mip;
                                            code_raddr_n = 15'(ops_base + mip);
                                            state_n = S_FETCH_WAIT;
                                        end else begin
                                            // instance-property Fn — sequential LOOKFN
                                                if (ot == 3'd1) begin
                                                hp_cmd_n = HP_LOOKFN;
                                                hp_v64_n = 1'b0;
                                                hp_oid_n = oid[12:0];
                                                hp_key_n = code_rdata[23:8];
                                                hp_len_n = obj_n[oid[12:0]];
                                                hp_slot_n = 5'd0;
                                                hp_phase_n = 3'd0;
                                                hp_hit_n = 1'b0;
                                                hp_proto_n = 64'hFFFF;
                                                hp_ret_n = S_V64_METH;
                                                vcall_argc_n = {4'd0, ac};
                                                vcall_this_n = {48'd0, oid};
                                                state_n = S_HEAP_WAIT;
                                                end else begin
                                                    begin stack_we = 1'b1; stack_waddr = sp - ac - 8'd1; stack_wdata = 32'sd0; end
                                                    begin stack_tag_we = 1'b1; stack_tag_waddr = sp - ac - 8'd1; stack_tag_wdata = 3'd5; end
                                                    sp_n = sp - ac;
                                                    next_op();
                                            end
                                        end
                                    end
                                end
                            end
                            default: next_op();
                        endcase
                    end
            end else begin
                    // Plain case: unique nat_id was the same Vivado hang as
                    // the opcode switch (every native in parallel).
                    case (nat_id)
                        8'd0: begin
                            sp_n = sp - nat_argc[7:0];
                            code_raddr_n = 15'(ops_base + ip);
                            state_n = S_FETCH_WAIT;
                        end
                        8'd1: begin
                            if (nat_argc >= 8'd1) begin
                                color_n = sat8(stack[sp - 8'd1]);
                                sp_n = sp - 8'd1;
                            end else color_n = 8'd0;
                            clr_idx_n = '0;
                            state_n = S_CLEAR;
                        end
                        8'd2: begin
                            // fillRect(x,y,w,h,color) — native 640×480, clipped
                            color_n = sat8(stack[sp - 8'd1]);
                            rx_n = clip_u(sti(sp - 9'd5), MW);
                            ry_n = clip_u(sti(sp - 9'd4), MH);
                            rw_n = clip_sz(sti(sp - 9'd3), clip_u(sti(sp - 9'd5), MW), MW);
                            rh_n = clip_sz(sti(sp - 9'd2), clip_u(sti(sp - 9'd4), MH), MH);
                            x_n = clip_u(sti(sp - 9'd5), MW);
                            y_n = clip_u(sti(sp - 9'd4), MH);
                            sp_n = sp - 8'd5;
                            state_n = S_RECT;
                        end
                        8'd3: begin
                            fb_swap_n = 1'b1;
                            did_swap_n = 1'b1;  // explicit present — skip pass-end auto-swap
                            code_raddr_n = 15'(ops_base + ip);
                            state_n = S_FETCH_WAIT;
                        end
                        8'd4: begin
                            // NEW: keyLeft = JOY_LEFT bit2 (was [0]=UP — gun ignored arrows)
                            begin stack_we = 1'b1; stack_waddr = sp; stack_wdata = joy_in[2] ? 32'sd1 : 32'sd0; end
                            sp_n = sp + 8'd1;
                            code_raddr_n = 15'(ops_base + ip);
                            state_n = S_FETCH_WAIT;
                        end
                        8'd5: begin
                            // NEW: keyRight = JOY_RIGHT bit3 (was [1]=DOWN)
                            begin stack_we = 1'b1; stack_waddr = sp; stack_wdata = joy_in[3] ? 32'sd1 : 32'sd0; end
                            sp_n = sp + 8'd1;
                            code_raddr_n = 15'(ops_base + ip);
                            state_n = S_FETCH_WAIT;
                        end
                        8'd6: begin
                            // keyFire = JOY_FIRE1 bit4 (unchanged; matches PYTHON)
                            begin stack_we = 1'b1; stack_waddr = sp; stack_wdata = joy_in[4] ? 32'sd1 : 32'sd0; end
                            sp_n = sp + 8'd1;
                            code_raddr_n = 15'(ops_base + ip);
                            state_n = S_FETCH_WAIT;
                        end
                        8'd7: begin
                            looping_n = 1'b1;
                            // Present only if the pass did not already swap —
                            // swapBuffers()+startLoop() double-swap left front
                            // permanently on the undrawn bank (INVADERS.JS blank)
                            if (!did_swap) fb_swap_n = 1'b1;
                            did_swap_n = 1'b0;
                            state_n = S_WAIT_FRAME;
                        end
                        8'd8: begin
                            // NEW: keyUp = JOY_UP bit0 (DONKEY climb)
                            begin stack_we = 1'b1; stack_waddr = sp; stack_wdata = joy_in[0] ? 32'sd1 : 32'sd0; end
                            sp_n = sp + 8'd1;
                            code_raddr_n = 15'(ops_base + ip);
                            state_n = S_FETCH_WAIT;
                        end
                        8'd9: begin
                            // NEW: keyDown = JOY_DOWN bit1
                            begin stack_we = 1'b1; stack_waddr = sp; stack_wdata = joy_in[1] ? 32'sd1 : 32'sd0; end
                            begin stack_tag_we = 1'b1; stack_tag_waddr = sp; stack_tag_wdata = 3'd0; end
                            sp_n = sp + 8'd1;
                            code_raddr_n = 15'(ops_base + ip);
                            state_n = S_FETCH_WAIT;
                        end
                        // NEW: Math / DOM / rAF (HTML .JSH)
                        8'd10: begin // Math.floor — fx floors to int (arith >>16)
                            begin stack_we = 1'b1; stack_waddr = sp - 8'd1; stack_wdata = fxi(stack[sp - 8'd1], stack_tag[sp - 8'd1]); end
                            begin stack_tag_we = 1'b1; stack_tag_waddr = sp - 8'd1; stack_tag_wdata = 3'd0; end
                            code_raddr_n = 15'(ops_base + ip);
                            state_n = S_FETCH_WAIT;
                        end
                        8'd11: begin // Math.abs — keeps fx tag (abs(0.5)=0.5)
                            stack_we = 1'b1; stack_waddr = sp - 8'd1; stack_wdata = stack[sp - 8'd1][31] ?
                                -stack[sp - 8'd1] : stack[sp - 8'd1];
                            code_raddr_n = 15'(ops_base + ip);
                            state_n = S_FETCH_WAIT;
                        end
                        8'd12: begin // min — fx-aware compare, keep the winner's tag
                            if (fxlift(stack[sp - 8'd2], stack_tag[sp - 8'd2], stack_tag[sp - 8'd1] == 3'd7)
                              < fxlift(stack[sp - 8'd1], stack_tag[sp - 8'd1], stack_tag[sp - 8'd2] == 3'd7)) begin
                                begin stack_we = 1'b1; stack_waddr = sp - 8'd2; stack_wdata = stack[sp - 8'd2]; end
                                begin stack_tag_we = 1'b1; stack_tag_waddr = sp - 8'd2; stack_tag_wdata = stack_tag[sp - 8'd2]; end
                            end else begin
                                begin stack_we = 1'b1; stack_waddr = sp - 8'd2; stack_wdata = stack[sp - 8'd1]; end
                                begin stack_tag_we = 1'b1; stack_tag_waddr = sp - 8'd2; stack_tag_wdata = stack_tag[sp - 8'd1]; end
                            end
                            sp_n = sp - 8'd1;
                            code_raddr_n = 15'(ops_base + ip);
                            state_n = S_FETCH_WAIT;
                        end
                        8'd13: begin // max
                            if (fxlift(stack[sp - 8'd2], stack_tag[sp - 8'd2], stack_tag[sp - 8'd1] == 3'd7)
                              > fxlift(stack[sp - 8'd1], stack_tag[sp - 8'd1], stack_tag[sp - 8'd2] == 3'd7)) begin
                                begin stack_we = 1'b1; stack_waddr = sp - 8'd2; stack_wdata = stack[sp - 8'd2]; end
                                begin stack_tag_we = 1'b1; stack_tag_waddr = sp - 8'd2; stack_tag_wdata = stack_tag[sp - 8'd2]; end
                            end else begin
                                begin stack_we = 1'b1; stack_waddr = sp - 8'd2; stack_wdata = stack[sp - 8'd1]; end
                                begin stack_tag_we = 1'b1; stack_tag_waddr = sp - 8'd2; stack_tag_wdata = stack_tag[sp - 8'd1]; end
                            end
                            sp_n = sp - 8'd1;
                            code_raddr_n = 15'(ops_base + ip);
                            state_n = S_FETCH_WAIT;
                        end
                        8'd15: begin // NEW: Math.sqrt — bit-serial, Q16.16 in/out
                            begin
                                logic signed [31:0] v;
                                v = (stack_tag[sp - 8'd1] == 3'd7)
                                    ? $signed(stack[sp - 8'd1])
                                    : ($signed(stack[sp - 8'd1]) <<< 16);
                                if (v < 0) v = 32'sd0; // FM NaN → draw-safe 0
                                sq_rad_n = {v, 16'd0};  // sqrt(v * 2^16) = Q16.16 root
                                sq_rem_n = 26'd0;
                                sq_root_n = 24'd0;
                                sq_i_n = 5'd23;
                                state_n = S_SQRT;
                            end
                        end
                        8'd14: begin // NEW: Math.random → Q16.16 fraction 0..1
                            // xorshift32 (was 1-bit LFSR shift: consecutive values
                            // ~2× apart → INVADERS stars spawned on a diagonal lattice)
                            begin
                                logic [31:0] x1, x2, x3;
                                x1 = lfsr ^ (lfsr << 13);
                                x2 = x1 ^ (x1 >> 17);
                                x3 = x2 ^ (x2 << 5);
                                lfsr_n = x3;
                                begin stack_we = 1'b1; stack_waddr = sp; stack_wdata = {16'd0, x3[31:16]}; end
                            end
                            begin stack_tag_we = 1'b1; stack_tag_waddr = sp; stack_tag_wdata = 3'd7; end
                            sp_n = sp + 8'd1;
                            code_raddr_n = 15'(ops_base + ip);
                            state_n = S_FETCH_WAIT;
                        end
                        8'd16, 8'd17, 8'd18: begin // getElementById / query / create → elem stub
                            sp_n = sp - nat_argc[7:0];
                            begin stack_we = 1'b1; stack_waddr = sp - nat_argc[7:0]; stack_wdata = 32'sd0; end
                            begin stack_tag_we = 1'b1; stack_tag_waddr = sp - nat_argc[7:0]; stack_tag_wdata = 3'd6; end
                            sp_n = sp - nat_argc[7:0] + 8'd1;
                            code_raddr_n = 15'(ops_base + ip);
                            state_n = S_FETCH_WAIT;
                        end
                        8'd19, 8'd20: begin // addEventListener
                            if (stack[sp - 8'd2][15:0] == id_keydown)
                                add_key_listener(1'b1, stack[sp - 8'd1][15:0]);
                            if (stack[sp - 8'd2][15:0] == id_keyup)
                                add_key_listener(1'b0, stack[sp - 8'd1][15:0]);
                            if (stack[sp - 8'd2][15:0] == id_click && click_fn == 16'hFFFF)
                                click_fn_n = stack[sp - 8'd1][15:0];
                            sp_n = sp - nat_argc[7:0];
                            begin stack_we = 1'b1; stack_waddr = sp - nat_argc[7:0]; stack_wdata = 32'sd0; end
                            begin stack_tag_we = 1'b1; stack_tag_waddr = sp - nat_argc[7:0]; stack_tag_wdata = 3'd5; end
                            sp_n = sp - nat_argc[7:0] + 8'd1;
                            code_raddr_n = 15'(ops_base + ip);
                            state_n = S_FETCH_WAIT;
                        end
                        8'd25: begin // Date() stub — getTime via obj_cls magic (intern-miss safe)
                            begin obj_n_we = 1'b1; obj_n_waddr = n_obj[12:0]; obj_n_wdata = 0; end
                            begin obj_cls_we = 1'b1; obj_cls_waddr = n_obj[12:0]; obj_cls_wdata = 16'hFFFD; end
                            begin stack_we = 1'b1; stack_waddr = sp; stack_wdata = {16'd0, n_obj}; end
                            begin stack_tag_we = 1'b1; stack_tag_waddr = sp; stack_tag_wdata = 3'd1; end
                            n_obj_n = (n_obj >= 16'(MAX_OBJ - 1)) ? n_obj : (n_obj + 16'd1);
                            sp_n = sp + 8'd1;
                            code_raddr_n = 15'(ops_base + ip);
                            state_n = S_FETCH_WAIT;
                        end
                        8'd26: begin // Image() — stub size so onload scale is nonzero
                            begin obj_n_we = 1'b1; obj_n_waddr = n_obj[12:0]; obj_n_wdata = 5'd2; end
                            begin obj_cls_we = 1'b1; obj_cls_waddr = n_obj[12:0]; obj_cls_wdata = 16'hFFC0; end
            // flatten: heap write via S_HEAP_* only
            // flatten: heap write via S_HEAP_* only
            // flatten: heap write via S_HEAP_* only
            // flatten: heap write via S_HEAP_* only
            // flatten: heap write via S_HEAP_* only
            // flatten: heap write via S_HEAP_* only
                            begin stack_we = 1'b1; stack_waddr = sp; stack_wdata = {16'd0, n_obj}; end
                            begin stack_tag_we = 1'b1; stack_tag_waddr = sp; stack_tag_wdata = 3'd1; end
                            n_obj_n = (n_obj >= 16'(MAX_OBJ - 1)) ? n_obj : (n_obj + 16'd1);
                            sp_n = sp + 8'd1;
                            code_raddr_n = 15'(ops_base + ip);
                            state_n = S_FETCH_WAIT;
                        end
                        8'd27: begin // requestAnimationFrame — keep Fn obj idx
                            if (raf_n < 4'd8 && nat_argc >= 8'd1) begin
                                raf_fn_n[raf_n] = stack[sp - nat_argc[7:0]][15:0];
                                raf_n_n = raf_n + 4'd1;
                                // NEW: rAF fn must survive the frame nursery
                                // rewind or PACMAN start() loop dies (raf=0)
                                commit_obj_keep(stack_tag[sp - nat_argc[7:0]],
                                                stack[sp - nat_argc[7:0]][15:0]);
                            end
                            sp_n = sp - nat_argc[7:0];
                            begin stack_we = 1'b1; stack_waddr = sp - nat_argc[7:0]; stack_wdata = 32'sd1; end
                            begin stack_tag_we = 1'b1; stack_tag_waddr = sp - nat_argc[7:0]; stack_tag_wdata = 3'd0; end
                            sp_n = sp - nat_argc[7:0] + 8'd1;
                            code_raddr_n = 15'(ops_base + ip);
                            state_n = S_FETCH_WAIT;
                        end
                        8'd28, 8'd29: begin // setTimeout / setInterval — frame delay queue
                            if (to_n < TIMER_DEPTH[6:0] && nat_argc >= 8'd1) begin
                                logic signed [31:0] ms;
                                logic [11:0] fr;
                                ms = (nat_argc >= 8'd2)
                                    ? fxi(stack[sp - nat_argc[7:0] + 8'd1],
                                          stack_tag[sp - nat_argc[7:0] + 8'd1])
                                    : 32'sd0;
                                if (ms < 0) ms = 32'sd0;
                                fr = (ms < 32'sd17) ? 12'd1 : 12'(ms / 32'sd17);
                                to_fn_n[to_n] = stack[sp - nat_argc[7:0]][15:0];
                                to_delay_n[to_n] = fr;
                                to_period_n[to_n] = (nat_id == 8'd29) ? fr : 12'd0;
                                to_id_n[to_n] = to_seq;
                                to_n_n = to_n + 7'd1;
                                to_seq_n = to_seq + 16'd1;
                                dbg_tmr_sched_n = dbg_tmr_sched + 16'd1;
                                commit_obj_keep(stack_tag[sp - nat_argc[7:0]],
                                                stack[sp - nat_argc[7:0]][15:0]);
                            end else if (nat_argc >= 8'd1)
                                dbg_to_ovf_n = dbg_to_ovf + 16'd1;
                            sp_n = sp - nat_argc[7:0];
                            begin stack_we = 1'b1; stack_waddr = sp - nat_argc[7:0]; stack_wdata = {16'd0, to_seq}; end
                            begin stack_tag_we = 1'b1; stack_tag_waddr = sp - nat_argc[7:0]; stack_tag_wdata = 3'd0; end
                            sp_n = sp - nat_argc[7:0] + 8'd1;
                            code_raddr_n = 15'(ops_base + ip);
                            state_n = S_FETCH_WAIT;
                        end
                        8'd30, 8'd31: begin // clearTimeout / clearInterval
                            if (nat_argc >= 8'd1) begin
                                logic [15:0] want;
                                integer i, j;
                                want = stack[sp - nat_argc[7:0]][15:0];
                                j = 0;
                                for (i = 0; i < TIMER_DEPTH; i++) begin
                                    if (i < to_n && to_id[i] != want) begin
                                        to_fn_n[j] = to_fn[i];
                                        to_delay_n[j] = to_delay[i];
                                        to_period_n[j] = to_period[i];
                                        to_id_n[j] = to_id[i];
                                        j = j + 1;
                                    end
                                end
                                to_n_n = 7'(j);
                            end
                            sp_n = (nat_argc == 0) ? sp : (sp - nat_argc[7:0]);
                            begin stack_we = 1'b1; stack_waddr = sp - ((nat_argc == 0) ? 8'd0 : nat_argc[7:0]); stack_wdata = 32'sd0; end
                            begin stack_tag_we = 1'b1; stack_tag_waddr = sp - ((nat_argc == 0) ? 8'd0 : nat_argc[7:0]); stack_tag_wdata = 3'd5; end
                            sp_n = (nat_argc == 0) ? (sp + 8'd1) : (sp - nat_argc[7:0] + 8'd1);
                            code_raddr_n = 15'(ops_base + ip);
                            state_n = S_FETCH_WAIT;
                        end
                        8'd36, 8'd37: begin // removeEventListener
                            if (nat_argc >= 8'd2) begin
                                if (stack[sp - nat_argc[7:0]][15:0] == id_keydown)
                                    remove_key_listener(1'b1, stack[sp - nat_argc[7:0] + 8'd1][15:0]);
                                if (stack[sp - nat_argc[7:0]][15:0] == id_keyup)
                                    remove_key_listener(1'b0, stack[sp - nat_argc[7:0] + 8'd1][15:0]);
                            end
                            sp_n = (nat_argc == 0) ? sp : (sp - nat_argc[7:0]);
                            begin stack_we = 1'b1; stack_waddr = sp - ((nat_argc == 0) ? 8'd0 : nat_argc[7:0]); stack_wdata = 32'sd0; end
                            begin stack_tag_we = 1'b1; stack_tag_waddr = sp - ((nat_argc == 0) ? 8'd0 : nat_argc[7:0]); stack_tag_wdata = 3'd5; end
                            sp_n = (nat_argc == 0) ? (sp + 8'd1) : (sp - nat_argc[7:0] + 8'd1);
                            code_raddr_n = 15'(ops_base + ip);
                            state_n = S_FETCH_WAIT;
                        end
                        8'd38, 8'd39: begin // dispatchEvent — fire listeners now (PYTHON parity)
                            if (nat_argc >= 8'd1 && stack_tag[sp - nat_argc[7:0]] == 3'd1
                                && kd_n != 3'd0 && kd_slot[0] != 16'hFFFF) begin
                                logic [15:0] oid;
                                oid = stack[sp - nat_argc[7:0]][15:0];
                                kev_obj_n = oid;
                                kev_fn_n = kd_slot[0];
                                kev_li_n = 2'd0;
                                kev_is_down_n = 1'b1;
                                kev_ret_ip_n = ip;  // OP_CALL already did ip+1
                                begin stack_we = 1'b1; stack_waddr = 0; stack_wdata = {16'd0, oid}; end
                                begin stack_tag_we = 1'b1; stack_tag_waddr = 0; stack_tag_wdata = 3'd1; end
                                boundary_sp(11'd1);
                                cstack_ip_n[csp] = 16'hFFFD;
                                cstack_this_n[csp] = this_obj;
                                cstack_isctor_n[csp] = 1'b0;
                                cstack_isfe_n[csp] = 1'b0;
                                state_n = S_KEYEV;
                            end else begin
                                sp_n = (nat_argc == 0) ? sp : (sp - nat_argc[7:0]);
                                begin stack_we = 1'b1; stack_waddr = sp - ((nat_argc == 0) ? 8'd0 : nat_argc[7:0]); stack_wdata = 32'sd1; end
                                begin stack_tag_we = 1'b1; stack_tag_waddr = sp - ((nat_argc == 0) ? 8'd0 : nat_argc[7:0]); stack_tag_wdata = 3'd0; end
                                sp_n = (nat_argc == 0) ? (sp + 8'd1) : (sp - nat_argc[7:0] + 8'd1);
                                code_raddr_n = 15'(ops_base + ip);
                                state_n = S_FETCH_WAIT;
                            end
                        end
                        8'd23: begin // JSON.parse
                            json_res_n = 11'(sp - nat_argc[7:0]);
                            if (nat_argc >= 8'd1 &&
                                stack_tag[sp - nat_argc[7:0]] == 3'd1 &&
                                obj_cls[stack[sp - nat_argc[7:0]][12:0]] == CLS_DYNSTR) begin
                                js_sp_n = 6'd0;
                                js_ph_n[0] = 3'd0;
                                json_pph_n = 3'd0;
                                hp_cmd_n = HP_OGETI;
                                hp_v64_n = 1'b0;
                                hp_oid_n = stack[sp - nat_argc[7:0]][12:0];
                                hp_slot_n = 5'd0;
                                hp_qn_n = 3'd2;
                                hp_qi_n = 3'd0;
                                hp_nat_n = 4'd7;
                                hp_lim_n = 8'd0;
                                hp_ret_n = S_V64_OGETI_NAT;
                                sp_n = sp - nat_argc[7:0];
                                state_n = S_HEAP_WAIT;
                            end else if (nat_argc >= 8'd1 &&
                                         stack_tag[sp - nat_argc[7:0]] == 3'd3) begin
                                // interned literal — copy name_mem into json_mem then parse
                                json_src_n = 14'd0;
                                json_srclen_n = {6'd0, name_len_tbl[stack[sp - nat_argc[7:0]][9:0]]};
                                json_rp_n = 14'd0;
                                js_sp_n = 6'd0;
                                js_ph_n[0] = 3'd0;
                                json_pph_n = 3'd0;
                                sp_n = sp - nat_argc[7:0];
                                if (name_len_tbl[stack[sp - nat_argc[7:0]][9:0]] == 8'd0) begin
                                    begin stack_we = 1'b1; stack_waddr = 11'(sp - nat_argc[7:0]); stack_wdata = 32'sd0; end
                                    begin stack_tag_we = 1'b1; stack_tag_waddr = 11'(sp - nat_argc[7:0]); stack_tag_wdata = 3'd5; end
                                    sp_n = 11'(sp - nat_argc[7:0]) + 11'd1;
                                    code_raddr_n = 15'(ops_base + ip);
                                    state_n = S_FETCH_WAIT;
                                end else if (name_len_tbl[stack[sp - nat_argc[7:0]][9:0]] == 8'd1 &&
                                             !name_has[stack[sp - nat_argc[7:0]][9:0]]) begin
                                    begin json_mem_we = 1'b1; json_mem_waddr = 0; json_mem_wdata = name_hash_tbl[stack[sp - nat_argc[7:0]][9:0]][7:0]; end
                                    state_n = S_JSON_PARSE;
                                end else begin
                                    name_rdaddr_n = name_off[stack[sp - nat_argc[7:0]][9:0]];
                                    json_wp_n = 14'd0;
                                    namcpy_repl_n = 1'b0;
                                    namcpy_armed_n = 1'b0;
                                    state_n = S_NAMCPY;
                                end
                            end else begin
                                begin stack_we = 1'b1; stack_waddr = sp - nat_argc[7:0]; stack_wdata = 32'sd0; end
                                begin stack_tag_we = 1'b1; stack_tag_waddr = sp - nat_argc[7:0]; stack_tag_wdata = 3'd5; end
                                sp_n = (nat_argc == 0) ? (sp + 8'd1) : (sp - nat_argc[7:0] + 8'd1);
                                code_raddr_n = 15'(ops_base + ip);
                                state_n = S_FETCH_WAIT;
                            end
                        end
                        8'd24: begin // JSON.stringify
                            json_res_n = 11'(sp - nat_argc[7:0]);
                            json_wp_n = 14'd0;
                            js_sp_n = 6'd1;
                            js_tag_n[0] = (nat_argc >= 8'd1) ? stack_tag[sp - nat_argc[7:0]] : 3'd5;
                            js_val_n[0] = (nat_argc >= 8'd1) ? stack[sp - nat_argc[7:0]] : 32'sd0;
                            js_i_n[0] = 8'd0;
                            js_ph_n[0] = 3'd0;
                            sp_n = (nat_argc == 0) ? sp : (sp - nat_argc[7:0]);
                            state_n = S_JSON;
                        end
                        8'd34: begin // Array(n) — length n, holes undefined
                            begin
                                logic [7:0] aln;
                                aln = (nat_argc >= 8'd1) ?
                                    ((fxi(stack[sp - nat_argc[7:0]], stack_tag[sp - nat_argc[7:0]]) > ARR_CAP)
                                        ? ARR_CAP[7:0]
                                        : (fxi(stack[sp - nat_argc[7:0]], stack_tag[sp - nat_argc[7:0]]) < 0)
                                            ? 8'd0
                                            : 8'(fxi(stack[sp - nat_argc[7:0]], stack_tag[sp - nat_argc[7:0]])))
                                    : 8'd0;
                                begin arr_len_we = 1'b1; arr_len_waddr = n_arr[11:0]; arr_len_wdata = aln; end
                                sp_n = (nat_argc == 0) ? sp : (sp - nat_argc[7:0]);
                                begin stack_we = 1'b1; stack_waddr = sp - nat_argc[7:0]; stack_wdata = {16'd0, n_arr}; end
                                begin stack_tag_we = 1'b1; stack_tag_waddr = sp - nat_argc[7:0]; stack_tag_wdata = 3'd2; end
                                // NEW: Array(n) is nursery (finder steps).
                                if (n_arr >= 16'(MAX_ARR - 1)) dbg_heap_ovf_n = dbg_heap_ovf + 16'd1;
                                n_arr_n = (n_arr >= 16'(MAX_ARR - 1)) ? n_arr : (n_arr + 16'd1);
                                sp_n = (nat_argc == 0) ? (sp + 8'd1) : (sp - nat_argc[7:0] + 8'd1);
                                code_raddr_n = 15'(ops_base + ip);
                                state_n = S_FETCH_WAIT;
                            end
                        end
                        8'd40: begin // typeof — JS tag string (PACMAN map hole checks)
                            begin
                                logic [2:0] tt;
                                logic [15:0] tn;
                                tt = (nat_argc >= 8'd1) ? stack_tag[sp - nat_argc[7:0]] : 3'd5;
                                tn = 16'hFFFF;
                                if (tt == 3'd5) tn = id_str_undef;
                                else if (tt == 3'd3) tn = (id_str_string != 16'hFFFF)
                                    ? id_str_string : id_str_undef;
                                else if (tt == 3'd4) tn = (id_str_function != 16'hFFFF)
                                    ? id_str_function : id_str_undef;
                                else if (tt == 3'd1 || tt == 3'd2) tn = (id_str_object != 16'hFFFF)
                                    ? id_str_object : id_str_undef;
                                else tn = (id_str_number != 16'hFFFF)
                                    ? id_str_number : 16'hFFFE;
                                sp_n = (nat_argc == 0) ? sp : (sp - nat_argc[7:0]);
                                if (tn == 16'hFFFE) begin
                                    // "number" was never interned — still != 'undefined'
                                    begin stack_we = 1'b1; stack_waddr = sp - ((nat_argc == 0) ? 8'd0 : nat_argc[7:0]); stack_wdata = 32'sd1; end
                                    begin stack_tag_we = 1'b1; stack_tag_waddr = sp - ((nat_argc == 0) ? 8'd0 : nat_argc[7:0]); stack_tag_wdata = 3'd0; end
                                end else if (tn != 16'hFFFF) begin
                                    begin stack_we = 1'b1; stack_waddr = sp - ((nat_argc == 0) ? 8'd0 : nat_argc[7:0]); stack_wdata = {16'd0, tn}; end
                                    begin stack_tag_we = 1'b1; stack_tag_waddr = sp - ((nat_argc == 0) ? 8'd0 : nat_argc[7:0]); stack_tag_wdata = 3'd3; end
                                end else begin
                                    begin stack_we = 1'b1; stack_waddr = sp - ((nat_argc == 0) ? 8'd0 : nat_argc[7:0]); stack_wdata = 32'sd0; end
                                    begin stack_tag_we = 1'b1; stack_tag_waddr = sp - ((nat_argc == 0) ? 8'd0 : nat_argc[7:0]); stack_tag_wdata = 3'd5; end
                                end
                                sp_n = (nat_argc == 0) ? (sp + 8'd1) : (sp - nat_argc[7:0] + 8'd1);
                                code_raddr_n = 15'(ops_base + ip);
                                state_n = S_FETCH_WAIT;
                            end
                        end
                        default: begin
                            sp_n = (nat_argc == 0) ? sp : (sp - nat_argc[7:0]);
                            begin stack_we = 1'b1; stack_waddr = sp; stack_wdata = 32'sd0; end
                            begin stack_tag_we = 1'b1; stack_tag_waddr = sp; stack_tag_wdata = 3'd5; end
                            sp_n = (nat_argc == 0) ? (sp + 8'd1) : (sp - nat_argc[7:0] + 8'd1);
                            code_raddr_n = 15'(ops_base + ip);
                            state_n = S_FETCH_WAIT;
                        end
                    endcase
            end
        end
    end
    `undef VST_AT
    `undef VST_REL
endmodule
