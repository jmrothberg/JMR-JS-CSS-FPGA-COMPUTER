// Hierarchical opcode/native decoder. Same clk as jmr_js_vm.
// Enable when state==S_EXEC or S_NAT. Case text from the parent always_ff.
import jmr_js_vm_pkg::*;
import jmr_value_pkg::*;
module jmr_js_vm_exec32 (
    input  logic clk,
    input  logic rst_n,
    input  logic enable,
    output logic leave_hold,
    input  logic hs_m_ip,
    input  logic hs_m_code,
    input  logic hs_m_state,
    input  logic hs_m_hp_cmd,
    input  logic hs_m_hp_v64,
    input  logic hs_m_hp_oid,
    input  logic hs_m_hp_aid,
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
    input  logic hs_m_hp_nat,
    input  logic hs_m_hp_tag,
    input  logic hs_m_hp_qk,
    input  logic hs_m_hp_qv,
    input  logic hs_m_hp_qt,
    output logic signed [31:0] alu_a_q,
    output logic signed [31:0] alu_b_q,
    output logic alu_fx_q,
    output logic [2:0] alu_op_q,
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
    output logic click_fired_q,
    output logic [15:0] click_fn_q,
    output logic [18:0] clr_idx_q,
    output logic [14:0] code_raddr_q,
    output logic [7:0] color_q,
    output logic [6:0] csp_q,
    output logic [1:0] ctx_align_q,
    output logic [7:0] ctx_font_px_q,
    output logic ctx_smooth_q,
    output logic signed [31:0] ctx_sx_q,
    output logic signed [31:0] ctx_sy_q,
    output logic signed [31:0] ctx_tx_q,
    output logic signed [31:0] ctx_ty_q,
    output logic [15:0] dbg_call_ovf_q,
    output logic [15:0] dbg_cb_ip_q,
    output logic [15:0] dbg_di_hit_q,
    output logic [15:0] dbg_di_miss_q,
    output logic [15:0] dbg_div_n_q,
    output logic [15:0] dbg_find_hit_q,
    output logic [15:0] dbg_heap_ovf_q,
    output logic [15:0] dbg_json_ovf_q,
    output logic [15:0] dbg_path_ovf_q,
    output logic [15:0] dbg_splice_n_q,
    output logic [15:0] dbg_stack_ovf_q,
    output logic [15:0] dbg_tmr_sched_q,
    output logic [15:0] dbg_to_ovf_q,
    output logic did_swap_q,
    output logic [5:0] div_cnt_q,
    output logic div_int_in_q,
    output logic div_neg_q,
    output logic [31:0] div_rem_q,
    output logic [31:0] div_ub_q,
    output logic [47:0] div_uq_q,
    output logic [5:0] env_free_n_q,
    output logic env_is_store_q,
    output logic [8:0] env_ld_slot_q,
    output logic [5:0] env_sp_q,
    output logic [15:0] env_walk_q,
    output logic [18:0] fb_dump_addr_q,
    output logic fb_dump_sel_q,
    output logic fb_swap_q,
    output logic [7:0] fill_style_i_q,
    output logic [7:0] fp_left_q,
    output logic [7:0] fpx_acc_q,
    output logic frame_fire_q,
    output logic [11:0] hp_aid_q,
    output logic [7:0] hp_alen_q,
    output logic [6:0] hp_aslot_q,
    output logic [3:0] hp_cmd_q,
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
    output logic [4:0] hp_ss_q,
    output logic [2:0] hp_tag_q,
    output logic [5:0] hp_tn_q,
    output logic hp_v64_q,
    output logic [11:0] hp_vbase_q,
    output logic [63:0] hp_wval_q,
    output logic [7:0] idx_needle_q,
    output logic [2:0] idx_t_q,
    output logic signed [31:0] idx_v_q,
    output logic imgd_armed_q,
    output logic [9:0] imgd_h_q,
    output logic [18:0] imgd_i_q,
    output logic [18:0] imgd_n_q,
    output logic [10:0] imgd_res_q,
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
    output logic [13:0] json_dst_q,
    output logic [2:0] json_pph_q,
    output logic [10:0] json_res_q,
    output logic [13:0] json_rp_q,
    output logic [13:0] json_src_q,
    output logic [13:0] json_srclen_q,
    output logic [13:0] json_wp_q,
    output logic [2:0] kd_n_q,
    output logic [15:0] kev_fn_q,
    output logic kev_is_down_q,
    output logic [1:0] kev_li_q,
    output logic [15:0] kev_obj_q,
    output logic [15:0] kev_ret_ip_q,
    output logic [15:0] keys_a_oid_q,
    output logic [15:0] keys_d_oid_q,
    output logic [15:0] keys_sp_oid_q,
    output logic [2:0] ku_n_q,
    output logic [31:0] lfsr_q,
    output logic looping_q,
    output logic [15:0] metrics_oid_q,
    output logic signed [31:0] mul_a_q,
    output logic signed [31:0] mul_b_q,
    output logic mul_fx_a_q,
    output logic mul_fx_b_q,
    output logic [15:0] n_arr_q,
    output logic [15:0] n_arr_keep_q,
    output logic [6:0] n_fn_proto_q,
    output logic [15:0] n_obj_q,
    output logic [15:0] n_obj_keep_q,
    output logic namcpy_armed_q,
    output logic namcpy_repl_q,
    output logic [15:0] name_rdaddr_q,
    output logic [7:0] nat_argc_q,
    output logic [7:0] nat_id_q,
    output logic path_active_q,
    output logic [1:0] path_kind_q,
    output logic path_stroke_q,
    output logic [4:0] pc_n_q,
    output logic [4:0] pi_q,
    output logic present_pend_q,
    output logic [3:0] raf_n_q,
    output logic [5:0] rel_i_q,
    output logic [5:0] rel_lim_q,
    output logic [5:0] rel_nn_q,
    output logic [6:0] rel_ret_q,
    output logic [5:0] rel_saved_q,
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
    output logic [10:0] sp_q,
    output logic [4:0] sq_i_q,
    output logic [47:0] sq_rad_q,
    output logic [25:0] sq_rem_q,
    output logic [23:0] sq_root_q,
    output logic [6:0] state_q,
    output logic signed [31:0] str_pf_ci_q,
    output logic [15:0] str_pf_id_q,
    output logic str_pf_ok_q,
    output logic [10:0] str_res_q,
    output logic [15:0] this_obj_q,
    output logic [6:0] to_n_q,
    output logic [15:0] to_seq_q,
    output logic [6:0] txt_bn_q,
    output logic [3:0] txt_ph_q,
    output logic signed [15:0] txt_px_q,
    output logic signed [15:0] txt_py_q,
    output logic [15:0] txt_rp_q,
    output logic [31:0] txt_val_q,
    output logic [2:0] txt_vt_q,
    output logic [11:0] vcall_argc_q,
    output logic [63:0] vcall_this_q,
    output logic [9:0] x_q,
    output logic [1:0] xf_dst_q,
    output logic signed [31:0] xf_h_q,
    output logic signed [31:0] xf_w_q,
    output logic signed [31:0] xf_x_q,
    output logic signed [31:0] xf_y_q,
    output logic [9:0] y_q,
    output logic p_clr_busy_q,
    input  logic signed [31:0] p_alu_a,
    input  logic signed [31:0] p_alu_b,
    input  logic p_alu_fx,
    input  logic [2:0] p_alu_op,
    input  logic arr_keep_ok,
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
    input  logic p_click_fired,
    input  logic [15:0] p_click_fn,
    input  logic [18:0] p_clr_idx,
    input  logic [14:0] p_code_raddr,
    input  logic [31:0] code_rdata,
    input  logic [7:0] p_color,
    input  logic [6:0] p_csp,
    input  logic [1:0] p_ctx_align,
    input  logic [7:0] p_ctx_font_px,
    input  logic p_ctx_smooth,
    input  logic signed [31:0] p_ctx_sx,
    input  logic signed [31:0] p_ctx_sy,
    input  logic signed [31:0] p_ctx_tx,
    input  logic signed [31:0] p_ctx_ty,
    input  logic [15:0] p_dbg_call_ovf,
    input  logic [15:0] p_dbg_cb_ip,
    input  logic [15:0] p_dbg_di_hit,
    input  logic [15:0] p_dbg_di_miss,
    input  logic [15:0] p_dbg_div_n,
    input  logic [15:0] p_dbg_find_hit,
    input  logic [15:0] p_dbg_heap_ovf,
    input  logic [15:0] p_dbg_json_ovf,
    input  logic [15:0] p_dbg_path_ovf,
    input  logic [15:0] p_dbg_splice_n,
    input  logic [15:0] p_dbg_stack_ovf,
    input  logic [15:0] p_dbg_tmr_sched,
    input  logic [15:0] p_dbg_to_ovf,
    input  logic p_did_swap,
    input  logic [5:0] p_div_cnt,
    input  logic p_div_int_in,
    input  logic p_div_neg,
    input  logic [31:0] p_div_rem,
    input  logic [31:0] p_div_ub,
    input  logic [47:0] p_div_uq,
    input  logic [15:0] env_free_rdata,
    input  logic [5:0] p_env_free_n,
    input  logic p_env_is_store,
    input  logic [8:0] p_env_ld_slot,
    input  logic [5:0] p_env_sp,
    input  logic [15:0] p_env_walk,
    input  logic [18:0] p_fb_dump_addr,
    input  logic p_fb_dump_sel,
    input  logic p_fb_swap,
    input  logic [7:0] p_fill_style_i,
    input  logic [7:0] p_fp_left,
    input  logic [7:0] p_fpx_acc,
    input  logic p_frame_fire,
    input  logic frame_tick,
    input  logic [11:0] p_hp_aid,
    input  logic [7:0] p_hp_alen,
    input  logic [6:0] p_hp_aslot,
    input  logic [3:0] p_hp_cmd,
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
    input  logic [4:0] p_hp_ss,
    input  logic [2:0] p_hp_tag,
    input  logic [5:0] p_hp_tn,
    input  logic p_hp_v64,
    input  logic [11:0] p_hp_vbase,
    input  logic [63:0] p_hp_wval,
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
    input  logic [7:0] p_idx_needle,
    input  logic [2:0] p_idx_t,
    input  logic signed [31:0] p_idx_v,
    input  logic p_imgd_armed,
    input  logic [9:0] p_imgd_h,
    input  logic [18:0] p_imgd_i,
    input  logic [18:0] p_imgd_n,
    input  logic [10:0] p_imgd_res,
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
    input  logic [13:0] p_json_dst,
    input  logic [2:0] p_json_pph,
    input  logic [10:0] p_json_res,
    input  logic [13:0] p_json_rp,
    input  logic [13:0] p_json_src,
    input  logic [13:0] p_json_srclen,
    input  logic [13:0] p_json_wp,
    input  logic [2:0] p_kd_n,
    input  logic [15:0] p_kev_fn,
    input  logic p_kev_is_down,
    input  logic [1:0] p_kev_li,
    input  logic [15:0] p_kev_obj,
    input  logic [15:0] p_kev_ret_ip,
    input  logic [15:0] p_keys_a_oid,
    input  logic [15:0] p_keys_d_oid,
    input  logic [15:0] p_keys_sp_oid,
    input  logic [2:0] p_ku_n,
    input  logic [31:0] p_lfsr,
    input  logic p_looping,
    input  logic [15:0] p_metrics_oid,
    input  logic signed [31:0] p_mul_a,
    input  logic signed [31:0] p_mul_b,
    input  logic p_mul_fx_a,
    input  logic p_mul_fx_b,
    input  logic [15:0] p_n_arr,
    input  logic [15:0] p_n_arr_keep,
    input  logic [4:0] n_cls,
    input  logic [6:0] p_n_fn_proto,
    input  logic [15:0] p_n_obj,
    input  logic [15:0] p_n_obj_keep,
    input  logic [15:0] n_ops,
    input  logic [4:0] n_spr,
    input  logic p_namcpy_armed,
    input  logic p_namcpy_repl,
    input  logic name_has_tos,
    input  logic name_has_nos,
    input  logic [15:0] name_hash_tos,
    input  logic [15:0] name_hash_nos,
    input  logic [7:0] name_len_tos,
    input  logic [7:0] name_len_nos,
    input  logic [15:0] name_off_tos,
    input  logic [15:0] name_off_nos,
    input  logic [7:0] fill_lut_rdata,
    input  logic [7:0] arr_len_tos_rdata,
    input  logic [7:0] arr_len_nos_rdata,
    input  logic signed [31:0] vars_rdata,
    input  logic signed [31:0] consts_rdata,
    output logic [9:0] consts_raddr_q,
    input  logic var_init_rdata,
    input  logic [2:0] var_tag_rdata,
    input  logic [15:0] p_name_rdaddr,
    input  logic [7:0] name_rdata,
    input  logic names_ok,
    input  logic [7:0] p_nat_argc,
    input  logic [7:0] p_nat_id,
    input  logic [15:0] obj_cls_rdata,
    output logic [9:0] obj_cls_raddr_q,
    input  logic obj_keep_ok,
    input  logic [5:0] obj_n_rdata,
    output logic [9:0] obj_n_raddr_q,
    input  logic [15:0] ops_base,
    input  logic p_path_active,
    input  logic [1:0] p_path_kind,
    input  logic p_path_stroke,
    input  logic [4:0] p_pc_n,
    input  logic [4:0] p_pi,
    input  logic p_present_pend,
    input  logic [3:0] p_raf_n,
    input  logic [5:0] p_rel_i,
    input  logic [5:0] p_rel_lim,
    input  logic [5:0] p_rel_nn,
    input  logic [6:0] p_rel_ret,
    input  logic [5:0] p_rel_saved,
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
    input  logic [10:0] p_sp,
    input  logic [255:0] spr_hh_pack,
    input  logic [255:0] spr_nid_pack,
    input  logic [255:0] spr_ww_pack,
    input  logic [4:0] p_sq_i,
    input  logic [47:0] p_sq_rad,
    input  logic [25:0] p_sq_rem,
    input  logic [23:0] p_sq_root,
    output logic [10:0] stack_raddr_q,
    output logic [10:0] stack_raddr2_q,
    output logic [9:0] intern_tos_q,
    output logic [9:0] intern_nos_q,
    output logic [11:0] aid_tos_q,
    output logic [11:0] aid_nos_q,
    output logic [8:0] vars_raddr_q,
    // Parent intern_var / env_oid / char_id / fn_proto / cstack: raddr + rdata next clock.
    output logic [9:0] intern_var_raddr_q,
    input  logic [8:0] intern_var_rdata,
    input  logic intern_var_ok_rdata,
    output logic [8:0] env_oid_raddr_q,
    input  logic [15:0] env_oid_rdata,
    output logic [7:0] char_id_raddr_q,
    input  logic [15:0] char_id_rdata,
    input  logic char_ok_rdata,
    // Parent timer SRAM: raddr + rdata next clock; we_q like intern_var.
    output logic [5:0] to_raddr_q,
    input  logic [11:0] to_delay_rdata,
    input  logic [15:0] to_fn_rdata,
    input  logic [15:0] to_id_rdata,
    input  logic [11:0] to_period_rdata,
    output logic to_we_q,
    output logic [5:0] to_waddr_q,
    output logic [11:0] to_delay_wdata_q,
    output logic [11:0] to_period_wdata_q,
    output logic [15:0] to_fn_wdata_q,
    output logic [15:0] to_id_wdata_q,
    output logic [6:0] fn_proto_raddr_q,
    input  logic [15:0] fn_proto_ip_rdata,
    input  logic [15:0] fn_proto_oid_rdata,
    output logic fn_proto_we_q,
    output logic [6:0] fn_proto_waddr_q,
    output logic [15:0] fn_proto_ip_wdata_q,
    output logic [15:0] fn_proto_oid_wdata_q,
    output logic cstack_we_q,
    output logic [6:0] cstack_waddr_q,
    output logic [15:0] cstack_ctorobj_wdata_q,
    output logic [5:0] cstack_env_wdata_q,
    output logic [15:0] cstack_fe_arr_wdata_q,
    output logic [15:0] cstack_fe_fn_wdata_q,
    output logic [7:0] cstack_fe_i_wdata_q,
    output logic [15:0] cstack_ip_wdata_q,
    output logic cstack_isctor_wdata_q,
    output logic cstack_isfe_wdata_q,
    output logic [15:0] cstack_map_arr_wdata_q,
    output logic [15:0] cstack_this_wdata_q,
    input  logic [15:0] cs1_ip_rdata,
    input  logic [15:0] cs1_this_rdata,
    input  logic cs1_isctor_rdata,
    input  logic cs1_isfe_rdata,
    input  logic [15:0] cs1_ctorobj_rdata,
    input  logic [15:0] cs1_fe_arr_rdata,
    input  logic [15:0] cs1_fe_fn_rdata,
    input  logic [7:0] cs1_fe_i_rdata,
    input  logic [15:0] cs1_map_arr_rdata,
    input  logic [5:0] cs1_env_rdata,
    input  logic [15:0] cs2_ip_rdata,
    input  logic [15:0] cs2_this_rdata,
    input  logic cs2_isctor_rdata,
    input  logic cs2_isfe_rdata,
    input  logic [15:0] cs2_ctorobj_rdata,
    input  logic [15:0] cs2_fe_arr_rdata,
    input  logic [15:0] cs2_fe_fn_rdata,
    input  logic [7:0] cs2_fe_i_rdata,
    input  logic [15:0] cs2_map_arr_rdata,
    input  logic [5:0] cs2_env_rdata,
    input  logic signed [31:0] stack_rdata,
    input  logic signed [31:0] stack_rdata2,
    input  logic start,
    input  logic [6:0] p_state,
    input  logic signed [31:0] p_str_pf_ci,
    input  logic [15:0] p_str_pf_id,
    input  logic p_str_pf_ok,
    input  logic [10:0] p_str_res,
    input  logic [15:0] tfn_entry_rdata,
    input  logic tfn_has_this_rdata,
    input  logic [7:0] tfn_nparam_rdata,
    input  logic [15:0] tfn_parent_rdata,
    input  logic [15:0] tfn_this_rdata,
    input  logic [2:0] tfn_this_tag_rdata,
    output logic [12:0] tfn_raddr_q,
    input  logic [15:0] p_this_obj,
    input  logic this_ok,
    input  logic [31:0] time_ms,
    input  logic [6:0] p_to_n,
    input  logic [15:0] p_to_seq,
    input  logic [6:0] p_txt_bn,
    input  logic [3:0] p_txt_ph,
    input  logic signed [15:0] p_txt_px,
    input  logic signed [15:0] p_txt_py,
    input  logic [15:0] p_txt_rp,
    input  logic [31:0] p_txt_val,
    input  logic [2:0] p_txt_vt,
    input  logic [8:0] var_this,
    input  logic [11:0] p_vcall_argc,
    input  logic [63:0] p_vcall_this,
    input  logic [9:0] p_x,
    input  logic [1:0] p_xf_dst,
    input  logic signed [31:0] p_xf_h,
    input  logic signed [31:0] p_xf_w,
    input  logic signed [31:0] p_xf_x,
    input  logic signed [31:0] p_xf_y,
    input  logic [9:0] p_y,
    output logic arr_len_we_q,
    output logic [11:0] arr_len_waddr_q,
    output logic [7:0] arr_len_wdata_q,
    output logic env_cap_we_q,
    output logic [11:0] env_cap_waddr_q,
    output logic [31:0] env_cap_wdata_q,
    output logic env_oid_we_q,
    output logic [11:0] env_oid_waddr_q,
    output logic [15:0] env_oid_wdata_q,
    output logic json_mem_we_q,
    output logic [12:0] json_mem_waddr_q,
    output logic [7:0] json_mem_wdata_q,
    output logic obj_cls_we_q,
    output logic [11:0] obj_cls_waddr_q,
    output logic [15:0] obj_cls_wdata_q,
    output logic obj_n_we_q,
    output logic [11:0] obj_n_waddr_q,
    output logic [5:0] obj_n_wdata_q,
    output logic stack_we_q,
    output logic [11:0] stack_waddr_q,
    output logic signed [31:0] stack_wdata_q,
    output logic stack_tag_we_q,
    output logic [11:0] stack_tag_waddr_q,
    output logic [2:0] stack_tag_wdata_q,
    output logic tenv_parent_we_q,
    output logic [11:0] tenv_parent_waddr_q,
    output logic [15:0] tenv_parent_wdata_q,
    output logic tfn_entry_we_q,
    output logic [11:0] tfn_entry_waddr_q,
    output logic [15:0] tfn_entry_wdata_q,
    output logic tfn_has_this_we_q,
    output logic [11:0] tfn_has_this_waddr_q,
    output logic [31:0] tfn_has_this_wdata_q,
    output logic tfn_nparam_we_q,
    output logic [11:0] tfn_nparam_waddr_q,
    output logic [7:0] tfn_nparam_wdata_q,
    output logic tfn_parent_we_q,
    output logic [11:0] tfn_parent_waddr_q,
    output logic [15:0] tfn_parent_wdata_q,
    output logic tfn_this_we_q,
    output logic [11:0] tfn_this_waddr_q,
    output logic [15:0] tfn_this_wdata_q,
    output logic tfn_this_tag_we_q,
    output logic [11:0] tfn_this_tag_waddr_q,
    output logic [2:0] tfn_this_tag_wdata_q,
    output logic var_init_we_q,
    output logic [11:0] var_init_waddr_q,
    output logic [31:0] var_init_wdata_q,
    output logic var_tag_we_q,
    output logic [11:0] var_tag_waddr_q,
    output logic [2:0] var_tag_wdata_q,
    output logic vars_we_q,
    output logic [11:0] vars_waddr_q,
    output logic signed [31:0] vars_wdata_q,
    output logic vobj_len_we_q,
    output logic [11:0] vobj_len_waddr_q,
    output logic [5:0] vobj_len_wdata_q,
    input  logic p_clr,
    input  logic p_we,
    input  logic [5:0] p_sel,
    input  logic [15:0] p_addr,
    input  logic [15:0] p_addr2,
    input  logic [63:0] p_data
);

    // Combo D-pins are local. Parent sees *_q only (never-fake-fpga-sim).
    // SRAM we/waddr/wdata are local; parent sees *_q (opcode comb assigns no ports).
    logic arr_len_we;
    logic [11:0] arr_len_waddr;
    logic [7:0] arr_len_wdata;
    logic env_cap_we;
    logic [11:0] env_cap_waddr;
    logic [31:0] env_cap_wdata;
    logic env_oid_we;
    logic [11:0] env_oid_waddr;
    logic [15:0] env_oid_wdata;
    logic json_mem_we;
    logic [12:0] json_mem_waddr;
    logic [7:0] json_mem_wdata;
    logic obj_cls_we;
    logic [11:0] obj_cls_waddr;
    logic [15:0] obj_cls_wdata;
    logic obj_n_we;
    logic [11:0] obj_n_waddr;
    logic [5:0] obj_n_wdata;
    logic stack_we;
    logic [11:0] stack_waddr;
    logic signed [31:0] stack_wdata;
    logic stack_tag_we;
    logic [11:0] stack_tag_waddr;
    logic [2:0] stack_tag_wdata;
    logic tenv_parent_we;
    logic [11:0] tenv_parent_waddr;
    logic [15:0] tenv_parent_wdata;
    logic tfn_entry_we;
    logic [11:0] tfn_entry_waddr;
    logic [15:0] tfn_entry_wdata;
    logic tfn_has_this_we;
    logic [11:0] tfn_has_this_waddr;
    logic [31:0] tfn_has_this_wdata;
    logic tfn_nparam_we;
    logic [11:0] tfn_nparam_waddr;
    logic [7:0] tfn_nparam_wdata;
    logic tfn_parent_we;
    logic [11:0] tfn_parent_waddr;
    logic [15:0] tfn_parent_wdata;
    logic tfn_this_we;
    logic [11:0] tfn_this_waddr;
    logic [15:0] tfn_this_wdata;
    logic tfn_this_tag_we;
    logic [11:0] tfn_this_tag_waddr;
    logic [2:0] tfn_this_tag_wdata;
    logic var_init_we;
    logic [11:0] var_init_waddr;
    logic [31:0] var_init_wdata;
    logic var_tag_we;
    logic [11:0] var_tag_waddr;
    logic [2:0] var_tag_wdata;
    logic vars_we;
    logic [11:0] vars_waddr;
    logic signed [31:0] vars_wdata;
    logic vobj_len_we;
    logic [11:0] vobj_len_waddr;
    logic [5:0] vobj_len_wdata;
    logic signed [31:0] alu_a_n;
    logic signed [31:0] alu_b_n;
    logic alu_fx_n;
    logic [2:0] alu_op_n;
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
    logic click_fired_n;
    logic [15:0] click_fn_n;
    logic [18:0] clr_idx_n;
    logic [14:0] code_raddr_n;
    logic [7:0] color_n;
    logic [6:0] csp_n;
    logic [1:0] ctx_align_n;
    logic [7:0] ctx_font_px_n;
    logic ctx_smooth_n;
    logic signed [31:0] ctx_sx_n;
    logic signed [31:0] ctx_sy_n;
    logic signed [31:0] ctx_tx_n;
    logic signed [31:0] ctx_ty_n;
    logic [15:0] dbg_call_ovf_n;
    logic [15:0] dbg_cb_ip_n;
    logic [15:0] dbg_di_hit_n;
    logic [15:0] dbg_di_miss_n;
    logic [15:0] dbg_div_n_n;
    logic [15:0] dbg_find_hit_n;
    logic [15:0] dbg_heap_ovf_n;
    logic [15:0] dbg_json_ovf_n;
    logic [15:0] dbg_path_ovf_n;
    logic [15:0] dbg_splice_n_n;
    logic [15:0] dbg_stack_ovf_n;
    logic [15:0] dbg_tmr_sched_n;
    logic [15:0] dbg_to_ovf_n;
    logic did_swap_n;
    logic [5:0] div_cnt_n;
    logic div_int_in_n;
    logic div_neg_n;
    logic [31:0] div_rem_n;
    logic [31:0] div_ub_n;
    logic [47:0] div_uq_n;
    logic [5:0] env_free_n_n;
    logic env_is_store_n;
    logic [8:0] env_ld_slot_n;
    logic [5:0] env_sp_n;
    logic [15:0] env_walk_n;
    logic [18:0] fb_dump_addr_n;
    logic fb_dump_sel_n;
    logic fb_swap_n;
    logic [7:0] fill_style_i_n;
    logic [7:0] fp_left_n;
    logic [7:0] fpx_acc_n;
    logic frame_fire_n;
    logic [11:0] hp_aid_n;
    logic [7:0] hp_alen_n;
    logic [6:0] hp_aslot_n;
    logic [3:0] hp_cmd_n;
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
    logic [4:0] hp_ss_n;
    logic [2:0] hp_tag_n;
    logic [5:0] hp_tn_n;
    logic hp_v64_n;
    logic [11:0] hp_vbase_n;
    logic [63:0] hp_wval_n;
    logic [7:0] idx_needle_n;
    logic [2:0] idx_t_n;
    logic signed [31:0] idx_v_n;
    logic imgd_armed_n;
    logic [9:0] imgd_h_n;
    logic [18:0] imgd_i_n;
    logic [18:0] imgd_n_n;
    logic [10:0] imgd_res_n;
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
    logic [13:0] json_dst_n;
    logic [2:0] json_pph_n;
    logic [10:0] json_res_n;
    logic [13:0] json_rp_n;
    logic [13:0] json_src_n;
    logic [13:0] json_srclen_n;
    logic [13:0] json_wp_n;
    logic [2:0] kd_n_n;
    logic [15:0] kev_fn_n;
    logic kev_is_down_n;
    logic [1:0] kev_li_n;
    logic [15:0] kev_obj_n;
    logic [15:0] kev_ret_ip_n;
    logic [15:0] keys_a_oid_n;
    logic [15:0] keys_d_oid_n;
    logic [15:0] keys_sp_oid_n;
    logic [2:0] ku_n_n;
    logic [31:0] lfsr_n;
    logic looping_n;
    logic [15:0] metrics_oid_n;
    logic signed [31:0] mul_a_n;
    logic signed [31:0] mul_b_n;
    logic mul_fx_a_n;
    logic mul_fx_b_n;
    logic [15:0] n_arr_n;
    logic [15:0] n_arr_keep_n;
    logic [6:0] n_fn_proto_n;
    logic [15:0] n_obj_n;
    logic [15:0] n_obj_keep_n;
    logic namcpy_armed_n;
    logic namcpy_repl_n;
    logic [15:0] name_rdaddr_n;
    logic [7:0] nat_argc_n;
    logic [7:0] nat_id_n;
    logic path_active_n;
    logic [1:0] path_kind_n;
    logic path_stroke_n;
    logic [4:0] pc_n_n;
    logic [4:0] pi_n;
    logic present_pend_n;
    logic [3:0] raf_n_n;
    logic [5:0] rel_i_n;
    logic [5:0] rel_lim_n;
    logic [5:0] rel_nn_n;
    logic [6:0] rel_ret_n;
    logic [5:0] rel_saved_n;
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
    logic [10:0] sp_n;
    logic [4:0] sq_i_n;
    logic [47:0] sq_rad_n;
    logic [25:0] sq_rem_n;
    logic [23:0] sq_root_n;
    logic [6:0] state_n;
    logic signed [31:0] str_pf_ci_n;
    logic [15:0] str_pf_id_n;
    logic str_pf_ok_n;
    logic [10:0] str_res_n;
    logic [15:0] this_obj_n;
    logic [6:0] to_n_n;
    logic [15:0] to_seq_n;
    logic [6:0] txt_bn_n;
    logic [3:0] txt_ph_n;
    logic signed [15:0] txt_px_n;
    logic signed [15:0] txt_py_n;
    logic [15:0] txt_rp_n;
    logic [31:0] txt_val_n;
    logic [2:0] txt_vt_n;
    logic [11:0] vcall_argc_n;
    logic [63:0] vcall_this_n;
    logic [9:0] x_n;
    logic [1:0] xf_dst_n;
    logic signed [31:0] xf_h_n;
    logic signed [31:0] xf_w_n;
    logic signed [31:0] xf_x_n;
    logic signed [31:0] xf_y_n;
    logic [9:0] y_n;

    // Scalar we only (no whole-array combo *_n = *_q). FFs clock here.
    logic fn_proto_we;
    logic [6:0] fn_proto_waddr;
    logic [15:0] fn_proto_ip_wdata, fn_proto_oid_wdata;
    logic hp_q_we, hp_q_repl;
    logic [1:0] hp_q_waddr;
    logic [15:0] hp_qk_wdata;
    logic [2:0] hp_qt_wdata;
    logic [63:0] hp_qv_wdata;
    logic [15:0] hp_qk_nev [0:3];
    logic [2:0] hp_qt_nev [0:3];
    logic [63:0] hp_qv_nev [0:3];
    logic js_we;
    logic [4:0] js_waddr;
    logic [7:0] js_i_wdata;
    logic [2:0] js_ph_wdata, js_tag_wdata;
    logic [31:0] js_val_wdata;
    logic kd_repl, ku_repl;
    logic [15:0] kd_nev [0:3], ku_nev [0:3];
    logic pc_we;
    logic [3:0] pc_waddr;
    logic signed [31:0] pc_a1_wdata, pc_a2_wdata, pc_a3_wdata, pc_a4_wdata, pc_a5_wdata;
    logic pc_ccw_wdata;
    logic [1:0] pc_op_wdata;
    logic raf_we;
    logic [2:0] raf_waddr;
    logic [15:0] raf_fn_wdata;
    logic to_we;
    logic [5:0] to_waddr;
    logic [11:0] to_delay_wdata, to_period_wdata;
    logic [15:0] to_fn_wdata, to_id_wdata;
    logic cstack_we;
    logic [6:0] cstack_waddr;
    logic [15:0] cstack_ctorobj_wdata;
    logic [5:0] cstack_env_wdata;
    logic [15:0] cstack_fe_arr_wdata, cstack_fe_fn_wdata;
    logic [7:0] cstack_fe_i_wdata;
    logic [15:0] cstack_ip_wdata;
    logic cstack_isctor_wdata, cstack_isfe_wdata;
    logic [15:0] cstack_map_arr_wdata, cstack_this_wdata;

    // LARGE memories: parent SRAM (stack/name/arr_len/vars/fill_lut/char_id). Locals stay.
    logic [15:0] cls_ctor [0:MAX_CLS-1];
    logic [15:0] cls_mip [0:MAX_CLS-1][0:MAX_CMETH-1];
    logic [15:0] cls_mname [0:MAX_CLS-1][0:MAX_CMETH-1];
    logic [15:0] cls_name [0:MAX_CLS-1];
    logic [4:0] cls_nmeth [0:MAX_CLS-1];
    // json_mem / vobj_len live in parent (we_q). TOS window FFs (16).
    // Combo reads these, never parent stack SRAM.
    logic signed [31:0] e32_sv [0:15];
    logic [2:0] e32_st [0:15];
    logic [2:0] stack_tag_tos, stack_tag_nos;
    logic [9:0] intern_tos, intern_nos;
    logic [11:0] aid_tos, aid_nos;
    assign intern_tos = e32_sv[0][9:0];
    assign intern_nos = e32_sv[1][9:0];
    assign aid_tos = e32_sv[0][11:0];
    assign aid_nos = e32_sv[1][11:0];
    // Opcode a0/a1 as wires so TOS macros never see code_rdata[n:m] (nested ]).
    logic [7:0] e32_a0, e32_a1;
    assign e32_a0 = code_rdata[15:8];
    assign e32_a1 = code_rdata[31:24];
    logic [11:0] clr_i;
    logic clr_busy;
    logic opnd_q, opnd_n;
    localparam int E32_CLR_LIM = MAX_ARR;

    // Combo raddr/TOS/busy stay local; parent sees *_q next clock.
    logic p_clr_busy;
    assign p_clr_busy = clr_busy | p_clr;

    // Working regs clock here. Parent sees *_q / leave_hold, not combo *_n.
    logic signed [31:0] alu_a;
    assign alu_a_q = alu_a;
    logic signed [31:0] alu_b;
    assign alu_b_q = alu_b;
    logic alu_fx;
    assign alu_fx_q = alu_fx;
    logic [2:0] alu_op;
    assign alu_op_q = alu_op;
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
    logic click_fired;
    assign click_fired_q = click_fired;
    logic [15:0] click_fn;
    assign click_fn_q = click_fn;
    logic [18:0] clr_idx;
    assign clr_idx_q = clr_idx;
    logic [14:0] code_raddr;
    assign code_raddr_q = code_raddr;
    logic [7:0] color;
    assign color_q = color;
    logic [6:0] csp;
    assign csp_q = csp;
    logic [1:0] ctx_align;
    assign ctx_align_q = ctx_align;
    logic [7:0] ctx_font_px;
    assign ctx_font_px_q = ctx_font_px;
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
    logic [15:0] dbg_call_ovf;
    assign dbg_call_ovf_q = dbg_call_ovf;
    logic [15:0] dbg_cb_ip;
    assign dbg_cb_ip_q = dbg_cb_ip;
    logic [15:0] dbg_di_hit;
    assign dbg_di_hit_q = dbg_di_hit;
    logic [15:0] dbg_di_miss;
    assign dbg_di_miss_q = dbg_di_miss;
    logic [15:0] dbg_div_n;
    assign dbg_div_n_q = dbg_div_n;
    logic [15:0] dbg_find_hit;
    assign dbg_find_hit_q = dbg_find_hit;
    logic [15:0] dbg_heap_ovf;
    assign dbg_heap_ovf_q = dbg_heap_ovf;
    logic [15:0] dbg_json_ovf;
    assign dbg_json_ovf_q = dbg_json_ovf;
    logic [15:0] dbg_path_ovf;
    assign dbg_path_ovf_q = dbg_path_ovf;
    logic [15:0] dbg_splice_n;
    assign dbg_splice_n_q = dbg_splice_n;
    logic [15:0] dbg_stack_ovf;
    assign dbg_stack_ovf_q = dbg_stack_ovf;
    logic [15:0] dbg_tmr_sched;
    assign dbg_tmr_sched_q = dbg_tmr_sched;
    logic [15:0] dbg_to_ovf;
    assign dbg_to_ovf_q = dbg_to_ovf;
    logic did_swap;
    assign did_swap_q = did_swap;
    logic [5:0] div_cnt;
    assign div_cnt_q = div_cnt;
    logic div_int_in;
    assign div_int_in_q = div_int_in;
    logic div_neg;
    assign div_neg_q = div_neg;
    logic [31:0] div_rem;
    assign div_rem_q = div_rem;
    logic [31:0] div_ub;
    assign div_ub_q = div_ub;
    logic [47:0] div_uq;
    assign div_uq_q = div_uq;
    logic [5:0] env_free_n;
    assign env_free_n_q = env_free_n;
    logic env_is_store;
    assign env_is_store_q = env_is_store;
    logic [8:0] env_ld_slot;
    assign env_ld_slot_q = env_ld_slot;
    logic [5:0] env_sp;
    assign env_sp_q = env_sp;
    logic [15:0] env_walk;
    assign env_walk_q = env_walk;
    logic [18:0] fb_dump_addr;
    assign fb_dump_addr_q = fb_dump_addr;
    logic fb_dump_sel;
    assign fb_dump_sel_q = fb_dump_sel;
    logic fb_swap;
    assign fb_swap_q = fb_swap;
    logic [7:0] fill_style_i;
    assign fill_style_i_q = fill_style_i;
    // fn_proto_* live in parent. Scan one index/clock; combo reads *_rdata.
    logic fp_scan, fp_scan_n, fp_armed, fp_armed_n, fp_hit, fp_hit_n;
    logic [6:0] fp_i, fp_i_n;
    logic [1:0] fp_kind, fp_kind_n;
    logic [15:0] fp_key, fp_key_n, fp_poid, fp_poid_n, newobj_ctor, newobj_ctor_n;
    logic newobj_rdy, newobj_rdy_n, newobj_emit, newobj_emit_n;
    // Class method lookup: one (c,m) per clock. Opcode comb must not index cls_*.
    logic cm_scan, cm_scan_n, cm_armed, cm_armed_n, cm_done, cm_done_n;
    logic [3:0] cm_c, cm_c_n, cm_m, cm_m_n;
    logic [15:0] cm_mip, cm_mip_n, cm_key, cm_key_n, cm_cls, cm_cls_n;
    logic to_clr_go, to_clr_busy, to_clr_fin, to_clr_armed;
    logic [15:0] to_clr_want, to_clr_want_n;
    logic [6:0] to_clr_i, to_clr_w;
    logic [7:0] fp_left;
    assign fp_left_q = fp_left;
    logic [7:0] fpx_acc;
    assign fpx_acc_q = fpx_acc;
    logic frame_fire;
    assign frame_fire_q = frame_fire;
    logic [11:0] hp_aid;
    assign hp_aid_q = hp_aid;
    logic [7:0] hp_alen;
    assign hp_alen_q = hp_alen;
    logic [6:0] hp_aslot;
    assign hp_aslot_q = hp_aslot;
    logic [3:0] hp_cmd;
    assign hp_cmd_q = hp_cmd;
    logic hp_from_stack;
    assign hp_from_stack_q = hp_from_stack;
    logic hp_hit;
    assign hp_hit_q = hp_hit;
    logic [15:0] hp_key;
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
    logic [7:0] idx_needle;
    assign idx_needle_q = idx_needle;
    logic [2:0] idx_t;
    assign idx_t_q = idx_t;
    logic signed [31:0] idx_v;
    assign idx_v_q = idx_v;
    logic imgd_armed;
    assign imgd_armed_q = imgd_armed;
    logic [9:0] imgd_h;
    assign imgd_h_q = imgd_h;
    logic [18:0] imgd_i;
    assign imgd_i_q = imgd_i;
    logic [18:0] imgd_n;
    assign imgd_n_q = imgd_n;
    logic [10:0] imgd_res;
    assign imgd_res_q = imgd_res;
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
    logic [15:0] ip;
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
    logic [2:0] js_tag [0:JSON_STK-1];
    logic [31:0] js_val [0:JSON_STK-1];
    logic [13:0] json_dst;
    assign json_dst_q = json_dst;
    logic [2:0] json_pph;
    assign json_pph_q = json_pph;
    logic [10:0] json_res;
    assign json_res_q = json_res;
    logic [13:0] json_rp;
    assign json_rp_q = json_rp;
    logic [13:0] json_src;
    assign json_src_q = json_src;
    logic [13:0] json_srclen;
    assign json_srclen_q = json_srclen;
    logic [13:0] json_wp;
    assign json_wp_q = json_wp;
    logic [2:0] kd_n;
    assign kd_n_q = kd_n;
    logic [15:0] kd_slot [0:3];
    logic [15:0] kev_fn;
    assign kev_fn_q = kev_fn;
    logic kev_is_down;
    assign kev_is_down_q = kev_is_down;
    logic [1:0] kev_li;
    assign kev_li_q = kev_li;
    logic [15:0] kev_obj;
    assign kev_obj_q = kev_obj;
    logic [15:0] kev_ret_ip;
    assign kev_ret_ip_q = kev_ret_ip;
    logic [15:0] keys_a_oid;
    assign keys_a_oid_q = keys_a_oid;
    logic [15:0] keys_d_oid;
    assign keys_d_oid_q = keys_d_oid;
    logic [15:0] keys_sp_oid;
    assign keys_sp_oid_q = keys_sp_oid;
    logic [2:0] ku_n;
    assign ku_n_q = ku_n;
    logic [15:0] ku_slot [0:3];
    logic [31:0] lfsr;
    assign lfsr_q = lfsr;
    logic looping;
    assign looping_q = looping;
    logic [15:0] metrics_oid;
    assign metrics_oid_q = metrics_oid;
    logic signed [31:0] mul_a;
    assign mul_a_q = mul_a;
    logic signed [31:0] mul_b;
    assign mul_b_q = mul_b;
    logic mul_fx_a;
    assign mul_fx_a_q = mul_fx_a;
    logic mul_fx_b;
    assign mul_fx_b_q = mul_fx_b;
    logic [15:0] n_arr;
    assign n_arr_q = n_arr;
    logic [15:0] n_arr_keep;
    assign n_arr_keep_q = n_arr_keep;
    logic [6:0] n_fn_proto;
    assign n_fn_proto_q = n_fn_proto;
    logic [15:0] n_obj;
    assign n_obj_q = n_obj;
    logic [15:0] n_obj_keep;
    assign n_obj_keep_q = n_obj_keep;
    logic namcpy_armed;
    assign namcpy_armed_q = namcpy_armed;
    logic namcpy_repl;
    assign namcpy_repl_q = namcpy_repl;
    logic [15:0] name_rdaddr;
    assign name_rdaddr_q = name_rdaddr;
    logic [7:0] nat_argc;
    assign nat_argc_q = nat_argc;
    logic [7:0] nat_id;
    assign nat_id_q = nat_id;
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
    logic present_pend;
    assign present_pend_q = present_pend;
    logic [15:0] raf_fn [0:7];
    logic [3:0] raf_n;
    assign raf_n_q = raf_n;
    logic [5:0] rel_i;
    assign rel_i_q = rel_i;
    logic [5:0] rel_lim;
    assign rel_lim_q = rel_lim;
    logic [5:0] rel_nn;
    assign rel_nn_q = rel_nn;
    logic [6:0] rel_ret;
    assign rel_ret_q = rel_ret;
    logic [5:0] rel_saved;
    assign rel_saved_q = rel_saved;
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
    logic [10:0] sp;
    assign sp_q = sp;
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
    logic signed [31:0] str_pf_ci;
    assign str_pf_ci_q = str_pf_ci;
    logic [15:0] str_pf_id;
    assign str_pf_id_q = str_pf_id;
    logic str_pf_ok;
    assign str_pf_ok_q = str_pf_ok;
    logic [10:0] str_res;
    assign str_res_q = str_res;
    logic [15:0] this_obj;
    assign this_obj_q = this_obj;
    logic [6:0] to_n;
    assign to_n_q = to_n;
    logic [15:0] to_seq;
    assign to_seq_q = to_seq;
    logic [6:0] txt_bn;
    assign txt_bn_q = txt_bn;
    logic [3:0] txt_ph;
    assign txt_ph_q = txt_ph;
    logic signed [15:0] txt_px;
    assign txt_px_q = txt_px;
    logic signed [15:0] txt_py;
    assign txt_py_q = txt_py;
    logic [15:0] txt_rp;
    assign txt_rp_q = txt_rp;
    logic [31:0] txt_val;
    assign txt_val_q = txt_val;
    logic [2:0] txt_vt;
    assign txt_vt_q = txt_vt;
    logic [11:0] vcall_argc;
    assign vcall_argc_q = vcall_argc;
    logic [63:0] vcall_this;
    assign vcall_this_q = vcall_this;
    logic [9:0] x;
    assign x_q = x;
    logic [1:0] xf_dst;
    assign xf_dst_q = xf_dst;
    logic signed [31:0] xf_h;
    assign xf_h_q = xf_h;
    logic signed [31:0] xf_w;
    assign xf_w_q = xf_w;
    logic signed [31:0] xf_x;
    assign xf_x_q = xf_x;
    logic signed [31:0] xf_y;
    assign xf_y_q = xf_y;
    logic [9:0] y;
    assign y_q = y;
    // Two registered call-frame FFs (csp-1, csp-2). Parent SRAM holds the rest.
    logic [15:0] cs1_ip, cs2_ip, cs1_this, cs2_this;
    logic cs1_isctor, cs2_isctor, cs1_isfe, cs2_isfe;
    logic [15:0] cs1_ctorobj, cs2_ctorobj, cs1_fe_arr, cs2_fe_arr;
    logic [15:0] cs1_fe_fn, cs2_fe_fn, cs1_map_arr, cs2_map_arr;
    logic [7:0] cs1_fe_i, cs2_fe_i;
    logic [5:0] cs1_env, cs2_env;
    logic [9:0] consts_raddr;
    logic [10:0] stack_raddr, stack_raddr2;
    logic [9:0] obj_cls_raddr, obj_n_raddr;
    logic [12:0] tfn_raddr;
    logic [9:0] intern_var_raddr;
    logic [8:0] vars_raddr;
    logic [8:0] env_oid_raddr;
    logic [7:0] char_id_raddr;
    logic [5:0] to_raddr;
    logic [6:0] fn_proto_raddr;
    assign consts_raddr = code_rdata[17:8];
    // SRAM raddr outside opcode always_comb; clocked *_q is the parent port.
    assign stack_raddr = (sp >= 11'd1) ? (sp - 11'd1) : 11'd0;
    assign stack_raddr2 = (sp >= 11'd2) ? (sp - 11'd2) : 11'd0;
    // drawImage: Image is arg0 (window[argc-1]), not TOS (dy). TOS class
    // is a Number — FFC miss, dihit=0 (ASET 1x pixel 0). sv[argc-1]
    // avoids E32_AT (macro is below).
    assign obj_cls_raddr =
        ((code_rdata[7:0] == OP_CALL_METH) &&
         (code_rdata[23:8] == id_drawimage) &&
         (code_rdata[31:24] != 8'd0) &&
         (code_rdata[31:24] <= 8'd16) &&
         (sp >= {3'd0, code_rdata[31:24]}))
        ? e32_sv[4'(code_rdata[31:24] - 8'd1)][9:0]
        : ((sp >= 11'd1) ? e32_sv[0][9:0] : 10'd0);
    assign obj_n_raddr = (sp >= 11'd1) ? e32_sv[0][9:0] : 10'd0;
    assign tfn_raddr = (sp >= 11'd1) ? e32_sv[0][12:0] : 13'd0;
    assign intern_var_raddr = code_rdata[17:8];
    assign vars_raddr = (code_rdata[7:0] == OP_NEW_OBJ && intern_var_ok_rdata)
        ? intern_var_rdata : code_rdata[16:8];
    assign env_oid_raddr = (env_sp != 6'd0) ? {3'd0, (env_sp - 6'd1)} : 9'd0;
    assign char_id_raddr = name_rdata;
    assign to_raddr = to_clr_busy ? to_clr_i[5:0] : 6'd0;
    assign fn_proto_raddr = fp_scan ? fp_i : 7'd0;
    logic [15:0] spr_hh [0:MAX_SPR-1];
    logic [15:0] spr_nid [0:MAX_SPR-1];
    logic [15:0] spr_ww [0:MAX_SPR-1];


    // Parent clr/poke + exec we into local copies. No opcode rewrite.
    // p_clr walks one index per clock (SRAM has no parallel clear).
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            clr_busy <= 1'b0;
            clr_i <= 12'd0;
            opnd_q <= 1'b0;
            p_clr_busy_q <= 1'b0;
        end else if (p_clr) begin
            clr_busy <= 1'b1;
            clr_i <= 12'd0;
        end else if (clr_busy) begin
            // char_id / intern_var / env_oid / cstack live in parent.
            if (clr_i + 12'd1 >= 12'(E32_CLR_LIM))
                clr_busy <= 1'b0;
            else
                clr_i <= clr_i + 12'd1;
        end
        if (enable)
            opnd_q <= opnd_n;
        else
            opnd_q <= 1'b0;
        // Parent SRAM raddr/TOS/busy: clocked ports (never-fake-fpga-sim).
        p_clr_busy_q <= p_clr_busy;
        intern_tos_q <= intern_tos;
        intern_nos_q <= intern_nos;
        aid_tos_q <= aid_tos;
        aid_nos_q <= aid_nos;
        consts_raddr_q <= consts_raddr;
        stack_raddr_q <= stack_raddr;
        stack_raddr2_q <= stack_raddr2;
        obj_cls_raddr_q <= obj_cls_raddr;
        obj_n_raddr_q <= obj_n_raddr;
        tfn_raddr_q <= tfn_raddr;
        intern_var_raddr_q <= intern_var_raddr;
        vars_raddr_q <= vars_raddr;
        env_oid_raddr_q <= env_oid_raddr;
        char_id_raddr_q <= char_id_raddr;
        to_raddr_q <= to_raddr;
        fn_proto_raddr_q <= fn_proto_raddr;
    end

    // Sequential cell so Vivado keep_hierarchy is not dissolved as combo-only.
    logic hier_keep;
    always_ff @(posedge clk) if (enable) hier_keep <= ~hier_keep;

    // EXEC working FFs. Combo *_n is the D pin. Parent must not mux *_n.
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            leave_hold <= 1'b0;
            fp_scan <= 1'b0;
            cm_scan <= 1'b0;
            cm_armed <= 1'b0;
            cm_done <= 1'b0;
            cm_mip <= 16'hFFFF;
            to_clr_busy <= 1'b0;
            to_clr_fin <= 1'b0;
            to_clr_armed <= 1'b0;
        end else if (enable) begin
            if (!leave_hold) begin
                alu_a <= alu_a_n;
                alu_b <= alu_b_n;
                alu_fx <= alu_fx_n;
                alu_op <= alu_op_n;
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
                click_fired <= click_fired_n;
                click_fn <= click_fn_n;
                clr_idx <= clr_idx_n;
                code_raddr <= code_raddr_n;
                color <= color_n;
                csp <= csp_n;
                ctx_align <= ctx_align_n;
                ctx_font_px <= ctx_font_px_n;
                ctx_smooth <= ctx_smooth_n;
                ctx_sx <= ctx_sx_n;
                ctx_sy <= ctx_sy_n;
                ctx_tx <= ctx_tx_n;
                ctx_ty <= ctx_ty_n;
                dbg_call_ovf <= dbg_call_ovf_n;
                dbg_cb_ip <= dbg_cb_ip_n;
                dbg_di_hit <= dbg_di_hit_n;
                dbg_di_miss <= dbg_di_miss_n;
                dbg_div_n <= dbg_div_n_n;
                dbg_find_hit <= dbg_find_hit_n;
                dbg_heap_ovf <= dbg_heap_ovf_n;
                dbg_json_ovf <= dbg_json_ovf_n;
                dbg_path_ovf <= dbg_path_ovf_n;
                dbg_splice_n <= dbg_splice_n_n;
                dbg_stack_ovf <= dbg_stack_ovf_n;
                dbg_tmr_sched <= dbg_tmr_sched_n;
                dbg_to_ovf <= dbg_to_ovf_n;
                did_swap <= did_swap_n;
                div_cnt <= div_cnt_n;
                div_int_in <= div_int_in_n;
                div_neg <= div_neg_n;
                div_rem <= div_rem_n;
                div_ub <= div_ub_n;
                div_uq <= div_uq_n;
                env_free_n <= env_free_n_n;
                env_is_store <= env_is_store_n;
                env_ld_slot <= env_ld_slot_n;
                env_sp <= env_sp_n;
                env_walk <= env_walk_n;
                fb_dump_addr <= fb_dump_addr_n;
                fb_dump_sel <= fb_dump_sel_n;
                fb_swap <= fb_swap_n;
                fill_style_i <= fill_style_i_n;
                fp_scan <= fp_scan_n;
                fp_armed <= fp_armed_n;
                fp_hit <= fp_hit_n;
                fp_i <= fp_i_n;
                fp_kind <= fp_kind_n;
                fp_key <= fp_key_n;
                fp_poid <= fp_poid_n;
                cm_scan <= cm_scan_n;
                cm_armed <= cm_armed_n;
                cm_done <= cm_done_n;
                cm_c <= cm_c_n;
                cm_m <= cm_m_n;
                cm_key <= cm_key_n;
                cm_cls <= cm_cls_n;
                cm_mip <= cm_mip_n;
                newobj_ctor <= newobj_ctor_n;
                if (cm_scan && cm_armed &&
                    ({1'b0, cm_c} < n_cls) &&
                    cls_name[cm_c] == cm_cls) begin
                    // cm_key FFFF = NEW_OBJ ctor scan (one class/clock).
                    if (cm_key == 16'hFFFF)
                        newobj_ctor <= cls_ctor[cm_c];
                    else if (({1'b0, cm_m} < cls_nmeth[cm_c]) &&
                             cls_mname[cm_c][cm_m] == cm_key)
                        cm_mip <= cls_mip[cm_c][cm_m];
                end
                newobj_rdy <= newobj_rdy_n;
                newobj_emit <= newobj_emit_n;
                fp_left <= fp_left_n;
                fpx_acc <= fpx_acc_n;
                frame_fire <= frame_fire_n;
                hp_aid <= hp_aid_n;
                hp_alen <= hp_alen_n;
                hp_aslot <= hp_aslot_n;
                hp_cmd <= hp_cmd_n;
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
                if (hp_q_repl) begin
                    hp_qk <= hp_qk_nev;
                    hp_qt <= hp_qt_nev;
                    hp_qv <= hp_qv_nev;
                end else if (hp_q_we) begin
                    hp_qk[hp_q_waddr] <= hp_qk_wdata;
                    hp_qt[hp_q_waddr] <= hp_qt_wdata;
                    hp_qv[hp_q_waddr] <= hp_qv_wdata;
                end
                hp_qn <= hp_qn_n;
                hp_ret <= hp_ret_n;
                hp_rval <= hp_rval_n;
                hp_si <= hp_si_n;
                hp_slot <= hp_slot_n;
                hp_ss <= hp_ss_n;
                hp_tag <= hp_tag_n;
                hp_tn <= hp_tn_n;
                hp_v64 <= hp_v64_n;
                hp_vbase <= hp_vbase_n;
                hp_wval <= hp_wval_n;
                idx_needle <= idx_needle_n;
                idx_t <= idx_t_n;
                idx_v <= idx_v_n;
                imgd_armed <= imgd_armed_n;
                imgd_h <= imgd_h_n;
                imgd_i <= imgd_i_n;
                imgd_n <= imgd_n_n;
                imgd_res <= imgd_res_n;
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
                    js_tag[js_waddr] <= js_tag_wdata;
                    js_val[js_waddr] <= js_val_wdata;
                end
                js_sp <= js_sp_n;
                json_dst <= json_dst_n;
                json_pph <= json_pph_n;
                json_res <= json_res_n;
                json_rp <= json_rp_n;
                json_src <= json_src_n;
                json_srclen <= json_srclen_n;
                json_wp <= json_wp_n;
                kd_n <= kd_n_n;
                if (kd_repl) kd_slot <= kd_nev;
                kev_fn <= kev_fn_n;
                kev_is_down <= kev_is_down_n;
                kev_li <= kev_li_n;
                kev_obj <= kev_obj_n;
                kev_ret_ip <= kev_ret_ip_n;
                keys_a_oid <= keys_a_oid_n;
                keys_d_oid <= keys_d_oid_n;
                keys_sp_oid <= keys_sp_oid_n;
                ku_n <= ku_n_n;
                if (ku_repl) ku_slot <= ku_nev;
                lfsr <= lfsr_n;
                looping <= looping_n;
                metrics_oid <= metrics_oid_n;
                mul_a <= mul_a_n;
                mul_b <= mul_b_n;
                mul_fx_a <= mul_fx_a_n;
                mul_fx_b <= mul_fx_b_n;
                n_arr <= n_arr_n;
                n_arr_keep <= n_arr_keep_n;
                n_fn_proto <= n_fn_proto_n;
                n_obj <= n_obj_n;
                n_obj_keep <= n_obj_keep_n;
                namcpy_armed <= namcpy_armed_n;
                namcpy_repl <= namcpy_repl_n;
                name_rdaddr <= name_rdaddr_n;
                nat_argc <= nat_argc_n;
                nat_id <= nat_id_n;
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
                present_pend <= present_pend_n;
                if (raf_we) raf_fn[raf_waddr] <= raf_fn_wdata;
                raf_n <= raf_n_n;
                rel_i <= rel_i_n;
                rel_lim <= rel_lim_n;
                rel_nn <= rel_nn_n;
                rel_ret <= rel_ret_n;
                rel_saved <= rel_saved_n;
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
                sp <= sp_n;
                sq_i <= sq_i_n;
                sq_rad <= sq_rad_n;
                sq_rem <= sq_rem_n;
                sq_root <= sq_root_n;
                state <= state_n;
                str_pf_ci <= str_pf_ci_n;
                str_pf_id <= str_pf_id_n;
                str_pf_ok <= str_pf_ok_n;
                str_res <= str_res_n;
                this_obj <= this_obj_n;
                if (to_clr_go && !to_clr_busy) begin
                    to_clr_busy <= 1'b1;
                    to_clr_fin <= 1'b0;
                    to_clr_i <= 7'd0;
                    to_clr_w <= 7'd0;
                    to_clr_armed <= 1'b0;
                    to_clr_want <= to_clr_want_n;
                end else if (to_clr_busy) begin
                    // Parent to_* rdata next clock. Extra SRAM-wait clocks OK.
                    if (to_clr_i >= to_n) begin
                        to_n <= to_clr_w;
                        to_clr_busy <= 1'b0;
                        to_clr_fin <= 1'b1;
                        to_clr_armed <= 1'b0;
                    end else if (!to_clr_armed) begin
                        to_clr_armed <= 1'b1;
                    end else begin
                        if (to_id_rdata != to_clr_want)
                            to_clr_w <= to_clr_w + 7'd1;
                        to_clr_i <= to_clr_i + 7'd1;
                        to_clr_armed <= 1'b0;
                    end
                end
                if (!to_clr_busy && !(to_clr_go && !to_clr_busy))
                    to_n <= to_n_n;
                to_seq <= to_seq_n;
                txt_bn <= txt_bn_n;
                txt_ph <= txt_ph_n;
                txt_px <= txt_px_n;
                txt_py <= txt_py_n;
                txt_rp <= txt_rp_n;
                txt_val <= txt_val_n;
                txt_vt <= txt_vt_n;
                vcall_argc <= vcall_argc_n;
                vcall_this <= vcall_this_n;
                x <= x_n;
                xf_dst <= xf_dst_n;
                xf_h <= xf_h_n;
                xf_w <= xf_w_n;
                xf_x <= xf_x_n;
                xf_y <= xf_y_n;
                y <= y_n;
                if (cstack_we && (csp_n < csp) && csp >= 7'd2 &&
                    cstack_waddr == (csp - 7'd2)) begin
                    // RET forEach: pop FFFE, m1 becomes forEach with fe_i+1.
                    cs1_ip <= cs2_ip; cs1_this <= cs2_this;
                    cs1_isctor <= cs2_isctor; cs1_isfe <= cs2_isfe;
                    cs1_ctorobj <= cs2_ctorobj; cs1_fe_arr <= cs2_fe_arr;
                    cs1_fe_fn <= cs2_fe_fn; cs1_fe_i <= cstack_fe_i_wdata;
                    cs1_map_arr <= cs2_map_arr; cs1_env <= cs2_env;
                end else if (cstack_we) begin
                    if (cstack_waddr == csp) begin
                        cs2_ip <= cs1_ip; cs2_this <= cs1_this;
                        cs2_isctor <= cs1_isctor; cs2_isfe <= cs1_isfe;
                        cs2_ctorobj <= cs1_ctorobj; cs2_fe_arr <= cs1_fe_arr;
                        cs2_fe_fn <= cs1_fe_fn; cs2_fe_i <= cs1_fe_i;
                        cs2_map_arr <= cs1_map_arr; cs2_env <= cs1_env;
                        cs1_ip <= cstack_ip_wdata; cs1_this <= cstack_this_wdata;
                        cs1_isctor <= cstack_isctor_wdata; cs1_isfe <= cstack_isfe_wdata;
                        cs1_ctorobj <= cstack_ctorobj_wdata; cs1_fe_arr <= cstack_fe_arr_wdata;
                        cs1_fe_fn <= cstack_fe_fn_wdata; cs1_fe_i <= cstack_fe_i_wdata;
                        cs1_map_arr <= cstack_map_arr_wdata; cs1_env <= cstack_env_wdata;
                    end else if (csp >= 7'd1 && cstack_waddr == (csp - 7'd1)) begin
                        cs1_ip <= cstack_ip_wdata; cs1_this <= cstack_this_wdata;
                        cs1_isctor <= cstack_isctor_wdata; cs1_isfe <= cstack_isfe_wdata;
                        cs1_ctorobj <= cstack_ctorobj_wdata; cs1_fe_arr <= cstack_fe_arr_wdata;
                        cs1_fe_fn <= cstack_fe_fn_wdata; cs1_fe_i <= cstack_fe_i_wdata;
                        cs1_map_arr <= cstack_map_arr_wdata; cs1_env <= cstack_env_wdata;
                    end else if (csp >= 7'd2 && cstack_waddr == (csp - 7'd2)) begin
                        cs2_fe_i <= cstack_fe_i_wdata;
                    end
                end else if (csp_n < csp && csp >= 7'd1) begin
                    cs1_ip <= cs2_ip; cs1_this <= cs2_this;
                    cs1_isctor <= cs2_isctor; cs1_isfe <= cs2_isfe;
                    cs1_ctorobj <= cs2_ctorobj; cs1_fe_arr <= cs2_fe_arr;
                    cs1_fe_fn <= cs2_fe_fn; cs1_fe_i <= cs2_fe_i;
                    cs1_map_arr <= cs2_map_arr; cs1_env <= cs2_env;
                end
                // TOS window follows stack_we / sp_n (parent SRAM is 1W; no 16-port).
                begin
                    integer sh, wi, d;
                    if (sp_n > sp) begin
                        e32_sv[15] <= e32_sv[14]; e32_st[15] <= e32_st[14];
                        e32_sv[14] <= e32_sv[13]; e32_st[14] <= e32_st[13];
                        e32_sv[13] <= e32_sv[12]; e32_st[13] <= e32_st[12];
                        e32_sv[12] <= e32_sv[11]; e32_st[12] <= e32_st[11];
                        e32_sv[11] <= e32_sv[10]; e32_st[11] <= e32_st[10];
                        e32_sv[10] <= e32_sv[9];  e32_st[10] <= e32_st[9];
                        e32_sv[9]  <= e32_sv[8];  e32_st[9]  <= e32_st[8];
                        e32_sv[8]  <= e32_sv[7];  e32_st[8]  <= e32_st[7];
                        e32_sv[7]  <= e32_sv[6];  e32_st[7]  <= e32_st[6];
                        e32_sv[6]  <= e32_sv[5];  e32_st[6]  <= e32_st[5];
                        e32_sv[5]  <= e32_sv[4];  e32_st[5]  <= e32_st[4];
                        e32_sv[4]  <= e32_sv[3];  e32_st[4]  <= e32_st[3];
                        e32_sv[3]  <= e32_sv[2];  e32_st[3]  <= e32_st[2];
                        e32_sv[2]  <= e32_sv[1];  e32_st[2]  <= e32_st[1];
                        e32_sv[1]  <= e32_sv[0];  e32_st[1]  <= e32_st[0];
                        e32_sv[0]  <= stack_wdata;
                        e32_st[0]  <= stack_tag_we ? stack_tag_wdata : 3'd0;
                    end else if (sp_n < sp) begin
                        sh = integer'(sp) - integer'(sp_n);
                        if (stack_we && stack_waddr == (sp_n - 11'd1))
                            e32_sv[0] <= stack_wdata;
                        else if (sh < 16)
                            e32_sv[0] <= e32_sv[sh[3:0]];
                        if (stack_tag_we && stack_tag_waddr == (sp_n - 11'd1))
                            e32_st[0] <= stack_tag_wdata;
                        else if (sh < 16)
                            e32_st[0] <= e32_st[sh[3:0]];
                        for (wi = 1; wi < 16; wi++)
                            if (wi + sh < 16) begin
                                e32_sv[wi] <= e32_sv[wi[3:0] + sh[3:0]];
                                e32_st[wi] <= e32_st[wi[3:0] + sh[3:0]];
                            end
                    end else begin
                        if (stack_we) begin
                            d = integer'(sp) - 1 - integer'(stack_waddr);
                            if (d >= 0 && d < 16)
                                e32_sv[d[3:0]] <= stack_wdata;
                        end
                        if (stack_tag_we) begin
                            d = integer'(sp) - 1 - integer'(stack_tag_waddr);
                            if (d >= 0 && d < 16)
                                e32_st[d[3:0]] <= stack_tag_wdata;
                        end
                    end
                end
                // Registered SRAM we: parent applies *_q on the leave_hold EXEC beat.
                arr_len_we_q <= arr_len_we;
                arr_len_waddr_q <= arr_len_waddr;
                arr_len_wdata_q <= arr_len_wdata;
                env_cap_we_q <= env_cap_we;
                env_cap_waddr_q <= env_cap_waddr;
                env_cap_wdata_q <= env_cap_wdata;
                env_oid_we_q <= env_oid_we;
                env_oid_waddr_q <= env_oid_waddr;
                env_oid_wdata_q <= env_oid_wdata;
                json_mem_we_q <= json_mem_we;
                json_mem_waddr_q <= json_mem_waddr;
                json_mem_wdata_q <= json_mem_wdata;
                obj_cls_we_q <= obj_cls_we;
                obj_cls_waddr_q <= obj_cls_waddr;
                obj_cls_wdata_q <= obj_cls_wdata;
                obj_n_we_q <= obj_n_we;
                obj_n_waddr_q <= obj_n_waddr;
                obj_n_wdata_q <= obj_n_wdata;
                stack_we_q <= stack_we;
                stack_waddr_q <= stack_waddr;
                stack_wdata_q <= stack_wdata;
                stack_tag_we_q <= stack_tag_we;
                stack_tag_waddr_q <= stack_tag_waddr;
                stack_tag_wdata_q <= stack_tag_wdata;
                tenv_parent_we_q <= tenv_parent_we;
                tenv_parent_waddr_q <= tenv_parent_waddr;
                tenv_parent_wdata_q <= tenv_parent_wdata;
                tfn_entry_we_q <= tfn_entry_we;
                tfn_entry_waddr_q <= tfn_entry_waddr;
                tfn_entry_wdata_q <= tfn_entry_wdata;
                tfn_has_this_we_q <= tfn_has_this_we;
                tfn_has_this_waddr_q <= tfn_has_this_waddr;
                tfn_has_this_wdata_q <= tfn_has_this_wdata;
                tfn_nparam_we_q <= tfn_nparam_we;
                tfn_nparam_waddr_q <= tfn_nparam_waddr;
                tfn_nparam_wdata_q <= tfn_nparam_wdata;
                tfn_parent_we_q <= tfn_parent_we;
                tfn_parent_waddr_q <= tfn_parent_waddr;
                tfn_parent_wdata_q <= tfn_parent_wdata;
                tfn_this_we_q <= tfn_this_we;
                tfn_this_waddr_q <= tfn_this_waddr;
                tfn_this_wdata_q <= tfn_this_wdata;
                tfn_this_tag_we_q <= tfn_this_tag_we;
                tfn_this_tag_waddr_q <= tfn_this_tag_waddr;
                tfn_this_tag_wdata_q <= tfn_this_tag_wdata;
                var_init_we_q <= var_init_we;
                var_init_waddr_q <= var_init_waddr;
                var_init_wdata_q <= var_init_wdata;
                var_tag_we_q <= var_tag_we;
                var_tag_waddr_q <= var_tag_waddr;
                var_tag_wdata_q <= var_tag_wdata;
                vars_we_q <= vars_we;
                vars_waddr_q <= vars_waddr;
                vars_wdata_q <= vars_wdata;
                vobj_len_we_q <= vobj_len_we;
                vobj_len_waddr_q <= vobj_len_waddr;
                vobj_len_wdata_q <= vobj_len_wdata;
                fn_proto_we_q <= fn_proto_we;
                fn_proto_waddr_q <= fn_proto_waddr;
                fn_proto_ip_wdata_q <= fn_proto_ip_wdata;
                fn_proto_oid_wdata_q <= fn_proto_oid_wdata;
                cstack_we_q <= cstack_we;
                cstack_waddr_q <= cstack_waddr;
                cstack_ctorobj_wdata_q <= cstack_ctorobj_wdata;
                cstack_env_wdata_q <= cstack_env_wdata;
                cstack_fe_arr_wdata_q <= cstack_fe_arr_wdata;
                cstack_fe_fn_wdata_q <= cstack_fe_fn_wdata;
                cstack_fe_i_wdata_q <= cstack_fe_i_wdata;
                cstack_ip_wdata_q <= cstack_ip_wdata;
                cstack_isctor_wdata_q <= cstack_isctor_wdata;
                cstack_isfe_wdata_q <= cstack_isfe_wdata;
                cstack_map_arr_wdata_q <= cstack_map_arr_wdata;
                cstack_this_wdata_q <= cstack_this_wdata;
                to_we_q <= to_we;
                to_waddr_q <= to_waddr;
                to_delay_wdata_q <= to_delay_wdata;
                to_period_wdata_q <= to_period_wdata;
                to_fn_wdata_q <= to_fn_wdata;
                to_id_wdata_q <= to_id_wdata;
                if (to_clr_fin && !to_clr_go && !to_clr_busy)
                    to_clr_fin <= 1'b0;
                leave_hold <= ((state_n != S_EXEC) && (state_n != S_NAT));
            end else
                leave_hold <= 1'b0;
        end else begin
            leave_hold <= 1'b0;
                arr_len_we_q <= 1'b0;
                env_cap_we_q <= 1'b0;
                env_oid_we_q <= 1'b0;
                json_mem_we_q <= 1'b0;
                obj_cls_we_q <= 1'b0;
                obj_n_we_q <= 1'b0;
                stack_we_q <= 1'b0;
                stack_tag_we_q <= 1'b0;
                tenv_parent_we_q <= 1'b0;
                tfn_entry_we_q <= 1'b0;
                tfn_has_this_we_q <= 1'b0;
                tfn_nparam_we_q <= 1'b0;
                tfn_parent_we_q <= 1'b0;
                tfn_this_we_q <= 1'b0;
                tfn_this_tag_we_q <= 1'b0;
                var_init_we_q <= 1'b0;
                var_tag_we_q <= 1'b0;
                vars_we_q <= 1'b0;
                vobj_len_we_q <= 1'b0;
                fn_proto_we_q <= 1'b0;
                cstack_we_q <= 1'b0;
                to_we_q <= 1'b0;
                // Overlay call-frame FFs from parent SRAM (csp-1 / csp-2).
                csp <= p_csp;
                cs1_ip <= cs1_ip_rdata; cs1_this <= cs1_this_rdata;
                cs1_isctor <= cs1_isctor_rdata; cs1_isfe <= cs1_isfe_rdata;
                cs1_ctorobj <= cs1_ctorobj_rdata; cs1_fe_arr <= cs1_fe_arr_rdata;
                cs1_fe_fn <= cs1_fe_fn_rdata; cs1_fe_i <= cs1_fe_i_rdata;
                cs1_map_arr <= cs1_map_arr_rdata; cs1_env <= cs1_env_rdata;
                cs2_ip <= cs2_ip_rdata; cs2_this <= cs2_this_rdata;
                cs2_isctor <= cs2_isctor_rdata; cs2_isfe <= cs2_isfe_rdata;
                cs2_ctorobj <= cs2_ctorobj_rdata; cs2_fe_arr <= cs2_fe_arr_rdata;
                cs2_fe_fn <= cs2_fe_fn_rdata; cs2_fe_i <= cs2_fe_i_rdata;
                cs2_map_arr <= cs2_map_arr_rdata; cs2_env <= cs2_env_rdata;
                to_n <= p_to_n;
                to_seq <= p_to_seq;
                if (hs_m_ip) ip <= p_ip;
                if (hs_m_code) code_raddr <= p_code_raddr;
                if (hs_m_state) state <= p_state;
                if (hs_m_hp_cmd) hp_cmd <= p_hp_cmd;
                if (hs_m_hp_v64) hp_v64 <= p_hp_v64;
                if (hs_m_hp_oid) hp_oid <= p_hp_oid;
                if (hs_m_hp_aid) hp_aid <= p_hp_aid;
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
        end
    end

    logic signed [31:0] a_s;
    logic [52:0] mb;
    // TOS window macros (16 FFs). Not function automatic (Synth 8-660).
    `define E32_REL(addr) (((((sp)>(addr)) && (((sp)-(addr)-11'd1)<11'd16))) ? 4'((sp)-(addr)-11'd1) : 4'd0)
    `define E32_AT(addr) e32_sv[`E32_REL(addr)]
    `define E32_TAG(addr) e32_st[`E32_REL(addr)]
    `define E32_STI(addr) ((`E32_TAG(addr)==3'd7) ? (`E32_AT(addr)>>>16) : `E32_AT(addr))
    `define E32_STFX(addr) ((`E32_TAG(addr)==3'd7) ? `E32_AT(addr) : (`E32_AT(addr)<<<16))
    `define E32_STAG(addr) `E32_TAG(addr)
    genvar gi_spr;
    generate
        for (gi_spr = 0; gi_spr < MAX_SPR; gi_spr++) begin : g_spr
            assign spr_hh[gi_spr] = spr_hh_pack[16*gi_spr +: 16];
            assign spr_nid[gi_spr] = spr_nid_pack[16*gi_spr +: 16];
            assign spr_ww[gi_spr] = spr_ww_pack[16*gi_spr +: 16];
        end
    endgenerate

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
    // sti/stfx/stag are E32_STI / E32_STFX / E32_STAG (TOS window FFs).
    function automatic logic [15:0] fn_entry(input logic [15:0] oid);
        fn_entry = tfn_entry_rdata;
    endfunction
    function automatic logic [7:0] fn_nparam(input logic [15:0] oid);
        fn_nparam = tfn_nparam_rdata;
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
                oid = env_free_rdata;
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
        parent = (obj_n_rdata > 6'd2) ? tfn_parent_rdata : 16'd0;
        cstack_we = 1'b1; cstack_waddr = csp; cstack_env_wdata = env_sp;
        push_fresh_env(parent);
        // Fn slot3 is the receiver captured by an arrow or a materialized
        // class method. Regular callbacks deliberately enter with no `this`.
        if (obj_n_rdata > 6'd3 && tfn_has_this_rdata) begin
            this_obj_n = tfn_this_rdata;
            if (this_ok) begin
                begin vars_we = 1'b1; vars_waddr = var_this; vars_wdata = {16'd0, tfn_this_rdata}; end
                begin var_tag_we = 1'b1; var_tag_waddr = var_this; var_tag_wdata = tfn_this_tag_rdata; end
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
                kd_repl = 1'b1;
                for (i = 0; i < 4; i++) kd_nev[i] = kd_slot[i];
                kd_nev[kd_n] = fn;
                kd_n_n = kd_n + 3'd1;
            end
        end else begin
            for (i = 0; i < 4; i++)
                if (i < ku_n && ku_slot[i] == fn) dup = 1'b1;
            if (!dup && ku_n < 3'd4) begin
                ku_repl = 1'b1;
                for (i = 0; i < 4; i++) ku_nev[i] = ku_slot[i];
                ku_nev[ku_n] = fn;
                ku_n_n = ku_n + 3'd1;
            end
        end
    endtask
    task automatic remove_key_listener(input logic is_down, input logic [15:0] fn);
        integer i, j;
        if (is_down) begin
            j = 0;
            kd_repl = 1'b1;
            for (i = 0; i < 4; i++) kd_nev[i] = 16'hFFFF;
            for (i = 0; i < 4; i++) begin
                if (i < kd_n && kd_slot[i] != fn) begin
                    kd_nev[j] = kd_slot[i];
                    j = j + 1;
                end
            end
            kd_n_n = 3'(j);
        end else begin
            j = 0;
            ku_repl = 1'b1;
            for (i = 0; i < 4; i++) ku_nev[i] = 16'hFFFF;
            for (i = 0; i < 4; i++) begin
                if (i < ku_n && ku_slot[i] != fn) begin
                    ku_nev[j] = ku_slot[i];
                    j = j + 1;
                end
            end
            ku_n_n = 3'(j);
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
        state_n = p_state;
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
        stack_tag_tos = e32_st[0];
        stack_tag_nos = e32_st[1];
        fn_proto_we = 1'b0;
        fn_proto_waddr = '0;
        fn_proto_ip_wdata = '0;
        fn_proto_oid_wdata = '0;
        hp_q_we = 1'b0;
        hp_q_repl = 1'b0;
        hp_q_waddr = 2'd0;
        hp_qk_wdata = '0;
        hp_qt_wdata = '0;
        hp_qv_wdata = '0;
        js_we = 1'b0;
        js_waddr = '0;
        js_i_wdata = '0;
        js_ph_wdata = '0;
        js_tag_wdata = '0;
        js_val_wdata = '0;
        kd_repl = 1'b0;
        ku_repl = 1'b0;
        pc_we = 1'b0;
        pc_waddr = '0;
        pc_a1_wdata = '0;
        pc_a2_wdata = '0;
        pc_a3_wdata = '0;
        pc_a4_wdata = '0;
        pc_a5_wdata = '0;
        pc_ccw_wdata = 1'b0;
        pc_op_wdata = '0;
        raf_we = 1'b0;
        raf_waddr = '0;
        raf_fn_wdata = '0;
        to_we = 1'b0;
        to_waddr = '0;
        to_delay_wdata = '0;
        to_period_wdata = '0;
        to_fn_wdata = '0;
        to_id_wdata = '0;
        cstack_we = 1'b0;
        cstack_waddr = '0;
        cstack_ctorobj_wdata = '0;
        cstack_env_wdata = '0;
        cstack_fe_arr_wdata = '0;
        cstack_fe_fn_wdata = '0;
        cstack_fe_i_wdata = '0;
        cstack_ip_wdata = '0;
        cstack_isctor_wdata = 1'b0;
        cstack_isfe_wdata = 1'b0;
        cstack_map_arr_wdata = '0;
        cstack_this_wdata = '0;
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
        opnd_n = 1'b0;
        fp_scan_n = 1'b0;
        fp_armed_n = 1'b0;
        fp_hit_n = fp_hit;
        fp_i_n = fp_i;
        fp_kind_n = fp_kind;
        fp_key_n = fp_key;
        fp_poid_n = fp_poid;
        newobj_ctor_n = newobj_ctor;
        newobj_rdy_n = 1'b0;
        newobj_emit_n = 1'b0;
        cm_scan_n = 1'b0;
        cm_armed_n = 1'b0;
        cm_done_n = cm_done;
        cm_c_n = cm_c;
        cm_m_n = cm_m;
        cm_mip_n = cm_mip;
        cm_key_n = cm_key;
        cm_cls_n = cm_cls;
        to_clr_go = 1'b0;
        to_clr_want_n = to_clr_want;
        if (enable && !leave_hold) begin
            if (to_clr_busy) begin
                state_n = S_NAT;
                // Compact keep: copy parent rdata to write port (no 64-wide copy).
                if (to_clr_armed && to_clr_i < to_n &&
                    to_id_rdata != to_clr_want) begin
                    to_we = 1'b1;
                    to_waddr = to_clr_w[5:0];
                    to_fn_wdata = to_fn_rdata;
                    to_delay_wdata = to_delay_rdata;
                    to_period_wdata = to_period_rdata;
                    to_id_wdata = to_id_rdata;
                end
            end else if (to_clr_fin) begin
                code_raddr_n = 15'(ops_base + ip);
                state_n = S_FETCH_WAIT;
            end else if (fp_scan) begin
                // One fn_proto index per clock. Combo never indexes fn_proto_ip[].
                fp_scan_n = 1'b1;
                fp_kind_n = fp_kind;
                fp_key_n = fp_key;
                newobj_ctor_n = newobj_ctor;
                state_n = S_EXEC;
                if (!fp_armed) begin
                    fp_armed_n = 1'b1;
                    fp_i_n = 7'd0;
                    fp_hit_n = 1'b0;
                    fp_poid_n = 16'd0;
                end else begin
                    logic hit_now;
                    logic [15:0] poid_now;
                    hit_now = fp_hit;
                    poid_now = fp_poid;
                    if (fp_i < n_fn_proto && fn_proto_ip_rdata == fp_key) begin
                        hit_now = 1'b1;
                        poid_now = fn_proto_oid_rdata;
                        fp_hit_n = 1'b1;
                        fp_poid_n = fn_proto_oid_rdata;
                    end
                    if ((fp_i + 7'd1 >= n_fn_proto) || (fp_i + 7'd1 >= MAX_FN_PROTO[6:0])) begin
                        fp_scan_n = 1'b0;
                        fp_armed_n = 1'b0;
                        if (fp_kind == 2'd1) begin
                            if (!hit_now && n_fn_proto < MAX_FN_PROTO[6:0]) begin
                                poid_now = n_obj;
                                begin obj_n_we = 1'b1; obj_n_waddr = n_obj[12:0]; obj_n_wdata = 0; end
                                begin obj_cls_we = 1'b1; obj_cls_waddr = n_obj[12:0]; obj_cls_wdata = 0; end
                                fn_proto_we = 1'b1; fn_proto_waddr = n_fn_proto; fn_proto_ip_wdata = fp_key;
                                fn_proto_we = 1'b1; fn_proto_waddr = n_fn_proto; fn_proto_oid_wdata = n_obj;
                                n_fn_proto_n = n_fn_proto + 7'd1;
                                n_obj_n = (n_obj >= 16'(MAX_OBJ - 1)) ? n_obj : (n_obj + 16'd1);
                            end
                            begin stack_we = 1'b1; stack_waddr = sp - 8'd1; stack_wdata = {16'd0, poid_now}; end
                            begin stack_tag_we = 1'b1; stack_tag_waddr = sp - 8'd1; stack_tag_wdata = 3'd1; end
                            next_op();
                        end else if (fp_kind == 2'd2) begin
                            if (hit_now) begin
                                obj_n_we = 1'b1; obj_n_waddr = n_obj[12:0]; obj_n_wdata = 6'd1;
                            end
                            fp_scan_n = 1'b1;
                            fp_kind_n = 2'd3;
                            fp_key_n = newobj_ctor;
                            fp_i_n = 7'd0;
                            fp_armed_n = 1'b0;
                            fp_hit_n = 1'b0;
                            fp_poid_n = 16'd0;
                            state_n = S_EXEC;
                        end else begin
                            if (hit_now) begin
                                obj_n_we = 1'b1; obj_n_waddr = n_obj[12:0]; obj_n_wdata = 6'd1;
                            end
                            newobj_emit_n = 1'b1;
                            state_n = S_EXEC;
                        end
                    end else
                        fp_i_n = fp_i + 7'd1;
                end
            end else if (cm_scan) begin
                // One (class,method) per clock. cls_mip read is always_ff.
                cm_scan_n = 1'b1;
                cm_key_n = cm_key;
                cm_cls_n = cm_cls;
                cm_mip_n = cm_mip;
                cm_done_n = 1'b0;
                state_n = S_EXEC;
                if (!cm_armed) begin
                    cm_armed_n = 1'b1;
                    cm_c_n = 4'd0;
                    cm_m_n = 4'd0;
                end else if (cm_key == 16'hFFFF) begin
                    // NEW_OBJ ctor: one class per clock (not a (c,m) CAM).
                    if (({1'b0, cm_c} + 5'd1 >= n_cls) ||
                        (cm_c == 4'(MAX_CLS - 1))) begin
                        cm_scan_n = 1'b0;
                        cm_armed_n = 1'b0;
                        cm_done_n = 1'b1;
                    end else begin
                        cm_armed_n = 1'b1;
                        cm_c_n = cm_c + 4'd1;
                    end
                end else if (cm_m == 4'(MAX_CMETH - 1)) begin
                    cm_m_n = 4'd0;
                    if (({1'b0, cm_c} + 5'd1 >= n_cls) ||
                        (cm_c == 4'(MAX_CLS - 1))) begin
                        cm_scan_n = 1'b0;
                        cm_armed_n = 1'b0;
                        cm_done_n = 1'b1;
                    end else begin
                        // Keep armed: default cm_armed_n=0 restarted c=0
                        // forever when n_cls>=2 (title hang at CALL_METH).
                        cm_armed_n = 1'b1;
                        cm_c_n = cm_c + 4'd1;
                    end
                end else begin
                    cm_armed_n = 1'b1;
                    cm_c_n = cm_c;
                    cm_m_n = cm_m + 4'd1;
                end
            // S_NAT is exec-internal: leave_hold stays 0 so parent EXEC
            // keeps enable (SRAM we). Default state_n=p_state would drop
            // NAT and skip fillRect/rAF (FRAME 64M, raf=0, ip=n_ops).
            end else if (p_state == S_EXEC && state != S_NAT && !opnd_q) begin
                opnd_n = 1'b1;
                state_n = S_EXEC;
            end else if (p_state == S_EXEC && state != S_NAT) begin
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
                                    begin stack_we = 1'b1; stack_waddr = sp; stack_wdata = f32_to_fx(consts_rdata); end
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
                                    hp_q_we = 1'b1;
                                    hp_q_waddr = 2'd0;
                                    hp_qk_wdata = 16'd0;
                                    hp_qv_wdata = {32'd0, consts_rdata};
                                    hp_qt_wdata = 3'd0;
                                    hp_ret_n = S_FETCH_WAIT;
                                    n_obj_n = (n_obj >= 16'(MAX_OBJ - 1)) ? n_obj : (n_obj + 16'd1);
                                    sp_n = sp + 8'd1;
                                    ip_n = ip + 16'd1;
                                    code_raddr_n = 15'(ops_base + ip + 16'd1);
                                    state_n = S_HEAP_WR;
                                end else begin
                                    begin stack_we = 1'b1; stack_waddr = sp; stack_wdata = consts_rdata; end
                                    begin stack_tag_we = 1'b1; stack_tag_waddr = sp; stack_tag_wdata = 3'd0; end
                                end
                                if (code_rdata[31:24] != 8'd4) begin
                                sp_n = sp + 8'd1;
                                next_op();
                                end
                            end
                            OP_LOAD_VAR: begin
                                if (env_sp != 0) begin
                                    env_walk_n = env_oid_rdata;
                                    env_ld_slot_n = code_rdata[16:8];
                                    env_is_store_n = 1'b0;
                                    hp_slot_n = 5'd1;
                                    hp_phase_n = 3'd0;
                                    ip_n = ip + 16'd1;
                                    state_n = S_ENV_LOAD;
                                end else begin
                                    begin stack_we = 1'b1; stack_waddr = sp; stack_wdata = vars_rdata; end
                                    begin stack_tag_we = 1'b1; stack_tag_waddr = sp; stack_tag_wdata = var_tag_rdata; end
                                    sp_n = sp + 8'd1;
                                    next_op();
                                end
                            end
                            OP_STORE_VAR: begin
                                if (env_sp != 0) begin
                                    env_walk_n = env_oid_rdata;
                                    env_ld_slot_n = code_rdata[16:8];
                                    env_is_store_n = 1'b1;
                                    hp_slot_n = 5'd1;
                                    hp_phase_n = 3'd0;
                                    ip_n = ip + 16'd1;
                                    state_n = S_ENV_LOAD;
                                end else begin
                                    begin vars_we = 1'b1; vars_waddr = code_rdata[16:8]; vars_wdata = `E32_AT(sp - 8'd1); end
                                    begin var_tag_we = 1'b1; var_tag_waddr = code_rdata[16:8]; var_tag_wdata = stack_tag_tos; end
                                    begin var_init_we = 1'b1; var_init_waddr = code_rdata[16:8]; var_init_wdata = 1'b1; end
                                    sp_n = sp - 8'd1;
                                    next_op();
                                end
                            end
                            OP_LET_VAR: begin
                                // NEW: a1 bit0 = call-frame local — upsert into
                                // the LIFO env so nested MAKE_FN can snapshot it.
                                if (code_rdata[24] || !var_init_rdata) begin
                                    begin vars_we = 1'b1; vars_waddr = code_rdata[16:8]; vars_wdata = `E32_AT(sp - 8'd1); end
                                    begin var_tag_we = 1'b1; var_tag_waddr = code_rdata[16:8]; var_tag_wdata = stack_tag_tos; end
                                    begin var_init_we = 1'b1; var_init_waddr = code_rdata[16:8]; var_init_wdata = 1'b1; end
                                end
                                if (code_rdata[24] && env_sp != 0) begin
                                    hp_cmd_n = HP_SETPROP;
                                    hp_v64_n = 1'b0;
                                    hp_oid_n = env_oid_rdata[12:0];
                                    hp_key_n = {7'd0, code_rdata[16:8]};
                                    hp_wval_n = {32'd0, `E32_AT(sp - 8'd1)};
                                    hp_tag_n = stack_tag_tos;
                                    hp_len_n = obj_n_rdata;
                                    hp_slot_n = 5'd0;
                                    hp_phase_n = 3'd0;
                                    state_n = S_HEAP_WAIT;
                                end else begin
                                sp_n = sp - 8'd1;
                                next_op();
                                end
                            end
                            OP_ADD: begin
                                if (stack_tag_nos == 3'd3 ||
                                    stack_tag_tos == 3'd3) begin
                                    // NEW: string concat — fold both operands into the
                                    // encoder u16 hash, then find-or-alloc an intern id.
                                    // PACMAN event keys: 's'+_index, 's1i'+id
                                    cc_av_n = `E32_AT(sp - 8'd2); cc_at_n = stack_tag_nos;
                                    cc_bv_n = `E32_AT(sp - 8'd1); cc_bt_n = stack_tag_tos;
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
                                    alu_fx_n = (stack_tag_nos == 3'd7 || stack_tag_tos == 3'd7);
                                    alu_a_n = fxlift(`E32_AT(sp - 8'd2), stack_tag_nos,
                                                    stack_tag_tos == 3'd7);
                                    alu_b_n = fxlift(`E32_AT(sp - 8'd1), stack_tag_tos,
                                                    stack_tag_nos == 3'd7);
                                    alu_op_n = 3'd0;
                                    sp_n = sp - 8'd1;
                                    state_n = S_ALU;
                                end
                            end
                            OP_SUB: begin
                                alu_fx_n = (stack_tag_nos == 3'd7 || stack_tag_tos == 3'd7);
                                alu_a_n = fxlift(`E32_AT(sp - 8'd2), stack_tag_nos,
                                                stack_tag_tos == 3'd7);
                                alu_b_n = fxlift(`E32_AT(sp - 8'd1), stack_tag_tos,
                                                stack_tag_nos == 3'd7);
                                alu_op_n = 3'd1;
                                sp_n = sp - 8'd1;
                                state_n = S_ALU;
                            end
                            OP_MUL: begin
                                // NEW: register operands, multiply next cycle (timing)
                                mul_a_n = `E32_AT(sp - 8'd2);
                                mul_b_n = `E32_AT(sp - 8'd1);
                                mul_fx_a_n = (stack_tag_nos == 3'd7);
                                mul_fx_b_n = (stack_tag_tos == 3'd7);
                                state_n = S_MUL;
                            end
                            OP_DIV: begin
                                // NEW: multi-cycle divide (see S_DIV) — the old
                                // single-cycle '/' blew board timing (WNS −90 ns).
                                // JS-honest: quotient computed in Q16.16 ((N<<16)/D
                                // after lifting both to fx); int/int exact stays int
                                // (indices), inexact becomes fx (DONKEY 640/1510).
                                if (`E32_AT(sp - 8'd1) == 0) begin
                                    begin stack_we = 1'b1; stack_waddr = sp - 8'd2; stack_wdata = 32'sd0; end
                                    begin stack_tag_we = 1'b1; stack_tag_waddr = sp - 8'd2; stack_tag_wdata = 3'd0; end
                                    sp_n = sp - 8'd1;
                                    next_op();
                                // NEW: 1-cycle /2 (arithmetic shift). `cell/2` and
                                // `width/2` were 48 restoring steps each; a frame of
                                // those loops paid millions of clocks. Shift is
                                // JS-honest: even/even stays int, odd/2 is fx (5/2).
                                end else if (stack_tag_tos != 3'd7 &&
                                             (`E32_AT(sp - 8'd1) == 32'sd2 ||
                                              `E32_AT(sp - 8'd1) == -32'sd2) &&
                                             `E32_AT(sp - 8'd2) != 32'sh80000000) begin
                                    if (stack_tag_nos == 3'd7) begin
                                        stack_we = 1'b1; stack_waddr = sp - 8'd2; stack_wdata = `E32_AT(sp - 8'd1)[31]
                                            ? -32'(`E32_AT(sp - 8'd2) >>> 1)
                                            : 32'(`E32_AT(sp - 8'd2) >>> 1);
                                        begin stack_tag_we = 1'b1; stack_tag_waddr = sp - 8'd2; stack_tag_wdata = 3'd7; end
                                    end else if (!`E32_AT(sp - 8'd2)[0]) begin
                                        stack_we = 1'b1; stack_waddr = sp - 8'd2; stack_wdata = `E32_AT(sp - 8'd1)[31]
                                            ? -32'(`E32_AT(sp - 8'd2) >>> 1)
                                            : 32'(`E32_AT(sp - 8'd2) >>> 1);
                                        begin stack_tag_we = 1'b1; stack_tag_waddr = sp - 8'd2; stack_tag_wdata = 3'd0; end
                                    end else begin
                                        stack_we = 1'b1; stack_waddr = sp - 8'd2; stack_wdata = `E32_AT(sp - 8'd1)[31]
                                            ? -32'(`E32_AT(sp - 8'd2) <<< 15)
                                            : 32'(`E32_AT(sp - 8'd2) <<< 15);
                                        begin stack_tag_we = 1'b1; stack_tag_waddr = sp - 8'd2; stack_tag_wdata = 3'd7; end
                                    end
                                    sp_n = sp - 8'd1;
                                    next_op();
                                end else begin
                                    logic signed [31:0] na, nb;
                                    na = fxlift(`E32_AT(sp - 8'd2), stack_tag_nos, 1'b1);
                                    nb = fxlift(`E32_AT(sp - 8'd1), stack_tag_tos, 1'b1);
                                    div_int_in_n = (stack_tag_nos != 3'd7 &&
                                                   stack_tag_tos != 3'd7);
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
                                alu_a_n = fxlift(`E32_AT(sp - 8'd2), stack_tag_nos,
                                                stack_tag_tos == 3'd7);
                                alu_b_n = fxlift(`E32_AT(sp - 8'd1), stack_tag_tos,
                                                stack_tag_nos == 3'd7);
                                alu_op_n = 3'd2;
                                sp_n = sp - 8'd1;
                                state_n = S_ALU;
                            end
                            OP_GT: begin
                                alu_fx_n = 1'b0;
                                alu_a_n = fxlift(`E32_AT(sp - 8'd2), stack_tag_nos,
                                                stack_tag_tos == 3'd7);
                                alu_b_n = fxlift(`E32_AT(sp - 8'd1), stack_tag_tos,
                                                stack_tag_nos == 3'd7);
                                alu_op_n = 3'd3;
                                sp_n = sp - 8'd1;
                                state_n = S_ALU;
                            end
                            OP_EQ: begin
                                if (stack_tag_nos == 3'd5 ||
                                    stack_tag_tos == 3'd5) begin
                                    // NEW: undefined equals only undefined — FM
                                    // (None == 0) is False; value-only compare made
                                    // PACMAN skip its whole frame (update()!=false)
                                    stack_we = 1'b1; stack_waddr = sp - 8'd2; stack_wdata =
                                        (stack_tag_nos == stack_tag_tos)
                                        ? 32'sd1 : 32'sd0;
                                    begin stack_tag_we = 1'b1; stack_tag_waddr = sp - 8'd2; stack_tag_wdata = 3'd0; end
                                    sp_n = sp - 8'd1;
                                    next_op();
                                end else if (stack_tag_nos == 3'd3 &&
                                           stack_tag_tos == 3'd3) begin
                                    // Intern strings: same id, or same hash+len
                                    // (e.key === " " when KEYEVT intern aliases).
                                    begin
                                        logic [9:0] ia, ib;
                                        ia = `E32_AT(sp - 8'd2)[9:0];
                                        ib = `E32_AT(sp - 8'd1)[9:0];
                                        stack_we = 1'b1; stack_waddr = sp - 8'd2; stack_wdata =
                                            (`E32_AT(sp - 8'd2)[15:0] == `E32_AT(sp - 8'd1)[15:0] ||
                                             (name_hash_nos == name_hash_tos &&
                                              name_len_nos == name_len_tos &&
                                              name_len_nos != 8'd0))
                                            ? 32'sd1 : 32'sd0;
                                        begin stack_tag_we = 1'b1; stack_tag_waddr = sp - 8'd2; stack_tag_wdata = 3'd0; end
                                        sp_n = sp - 8'd1;
                                        next_op();
                                    end
                                end else begin
                                    alu_fx_n = 1'b0;
                                    alu_a_n = fxlift(`E32_AT(sp - 8'd2), stack_tag_nos,
                                                    stack_tag_tos == 3'd7);
                                    alu_b_n = fxlift(`E32_AT(sp - 8'd1), stack_tag_tos,
                                                    stack_tag_nos == 3'd7);
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
                                a_s = (stack_tag_tos == 3'd5 ||
                                       ((stack_tag_tos == 3'd0 || stack_tag_tos == 3'd7)
                                        && `E32_AT(sp - 8'd1) == 0))
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
                                begin stack_we = 1'b1; stack_waddr = sp; stack_wdata = `E32_AT(sp - 8'd1); end
                                begin stack_tag_we = 1'b1; stack_tag_waddr = sp; stack_tag_wdata = stack_tag_tos; end
                                sp_n = sp + 8'd1;
                                next_op();
                            end
                            OP_NEG: begin
                                alu_fx_n = (stack_tag_tos == 3'd7);  // -fx stays fx
                                alu_a_n = `E32_AT(sp - 8'd1);
                                alu_op_n = 3'd5;
                                state_n = S_ALU;
                            end
                            OP_NOT: begin
                                // JS !x — objects/strings/fns truthy even when the packed oid is 0
                                alu_fx_n = 1'b0;
                                alu_a_n = (stack_tag_tos == 3'd5 ||
                                          ((stack_tag_tos == 3'd0 || stack_tag_tos == 3'd7)
                                           && `E32_AT(sp - 8'd1) == 0))
                                         ? 32'sd0 : 32'sd1;
                                alu_op_n = 3'd6;
                                state_n = S_ALU;
                            end
                            OP_MOD: begin
                                // NEW: a % b on floored ints (fx operands coerce) — 0 if b==0
                                begin
                                    logic signed [31:0] ma, mb;
                                    ma = fxi(`E32_AT(sp - 8'd2), stack_tag_nos);
                                    mb = fxi(`E32_AT(sp - 8'd1), stack_tag_tos);
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
                                stack_we = 1'b1; stack_waddr = sp - 8'd2; stack_wdata = fxi(`E32_AT(sp - 8'd2), stack_tag_nos)
                                                  | fxi(`E32_AT(sp - 8'd1), stack_tag_tos);
                                begin stack_tag_we = 1'b1; stack_tag_waddr = sp - 8'd2; stack_tag_wdata = 3'd0; end
                                sp_n = sp - 8'd1;
                                next_op();
                            end
                            OP_BIT_AND: begin
                                stack_we = 1'b1; stack_waddr = sp - 8'd2; stack_wdata = fxi(`E32_AT(sp - 8'd2), stack_tag_nos)
                                                  & fxi(`E32_AT(sp - 8'd1), stack_tag_tos);
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
                                if (stack_tag_nos == 3'd2) begin
                                    begin
                                        logic signed [31:0] aidx32;
                                        logic [11:0] aid;
                                        aid = `E32_AT(sp - 8'd2)[11:0];
                                        aidx32 = fxi(`E32_AT(sp - 8'd1), stack_tag_tos);
                                        if (aidx32 < 0 || aidx32 >= 32'(arr_len_nos_rdata)) begin
                                            begin stack_we = 1'b1; stack_waddr = sp - 8'd2; stack_wdata = 32'sd0; end
                                            begin stack_tag_we = 1'b1; stack_tag_waddr = sp - 8'd2; stack_tag_wdata = 3'd5; end
                                            sp_n = sp - 8'd1;
                                            next_op();
                                        end else begin
                                            hp_cmd_n = HP_ARRGET;
                                            hp_v64_n = 1'b0;
                                            hp_aid_n = aid;
                                            hp_aslot_n = 7'(aidx32);
                                            hp_alen_n = arr_len_nos_rdata;
                                            state_n = S_HEAP_WAIT;
                                        end
                                    end
                                end else if (stack_tag_nos == 3'd1 &&
                                             stack_tag_tos == 3'd3) begin
                                    hp_cmd_n = HP_GETIDX;
                                    hp_v64_n = 1'b0;
                                    hp_oid_n = `E32_AT(sp - 8'd2)[12:0];
                                    hp_key_n = `E32_AT(sp - 8'd1)[15:0];
                                    hp_len_n = obj_n_rdata;
                                    hp_slot_n = 5'd0;
                                    hp_phase_n = 3'd1;
                                    hp_proto_n = V64_UNDEFINED;
                                    state_n = S_HEAP_WAIT;
                                // NEW: "str"[i] — one char. name_mem is BRAM, so the
                                // byte lands next cycle in S_STRIDX. This is what
                                // string-row sprites need (row[col] === "1").
                                end else if (stack_tag_nos == 3'd3 && names_ok &&
                                             (stack_tag_tos == 3'd0 ||
                                              stack_tag_tos == 3'd7)) begin
                                    begin
                                        logic signed [31:0] ci;
                                        ci = fxi(`E32_AT(sp - 8'd1), stack_tag_tos);
                                        if (ci >= 0 && ci < 32'(name_len_nos)) begin
                                            if (str_pf_ok && str_pf_id == `E32_AT(sp - 8'd2)[15:0] &&
                                                str_pf_ci == ci &&
                                                name_rdaddr == name_off_nos + 16'(ci)) begin
                                                // Sequential hit: char_id_rdata is name_rdata from the opnd wait.
                                                if (char_ok_rdata) begin
                                                    begin stack_we = 1'b1; stack_waddr = sp - 8'd2; stack_wdata = {16'd0, char_id_rdata}; end
                                                    begin stack_tag_we = 1'b1; stack_tag_waddr = sp - 8'd2; stack_tag_wdata = 3'd3; end
                                                end else begin
                                                    begin stack_we = 1'b1; stack_waddr = sp - 8'd2; stack_wdata = 32'sd0; end
                                                    begin stack_tag_we = 1'b1; stack_tag_waddr = sp - 8'd2; stack_tag_wdata = 3'd5; end
                                                end
                                                sp_n = sp - 8'd1;
                                                name_rdaddr_n = name_off_nos + 16'(ci) + 16'd1;
                                                str_pf_id_n = `E32_AT(sp - 8'd2)[15:0];
                                                str_pf_ci_n = ci + 32'sd1;
                                                str_pf_ok_n = 1'b1;
                                                next_op();
                                            end else begin
                                                name_rdaddr_n = name_off_nos + 16'(ci);
                                                str_res_n = 11'(sp - 8'd2);
                                                str_pf_id_n = `E32_AT(sp - 8'd2)[15:0];
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
                                    aidx32 = fxi(`E32_AT(sp - 8'd2), stack_tag_nos);
                                    aid = `E32_AT(sp - 8'd3)[11:0];
                                    if (`E32_STAG(sp - 8'd3) == 3'd2 &&
                                        aidx32 >= 0 && aidx32 < ARR_CAP) begin
                                        if (aidx32 >= 32'(arr_len_nos_rdata))
                                            begin arr_len_we = 1'b1; arr_len_waddr = aid; arr_len_wdata = 8'(aidx32 + 32'sd1); end
                                        hp_cmd_n = HP_ARRSET;
                                        hp_v64_n = 1'b0;
                                        hp_from_stack_n = 1'b0;
                                        hp_aid_n = aid;
                                        hp_aslot_n = 7'(aidx32);
                                        hp_wval_n = {32'd0, `E32_AT(sp - 8'd1)};
                                        hp_tag_n = stack_tag_tos;
                                        state_n = S_HEAP_AWR;
                                    end else if (`E32_STAG(sp - 8'd3) == 3'd1 &&
                                                 stack_tag_nos == 3'd3) begin
                                        hp_cmd_n = HP_SETIDX;
                                        hp_v64_n = 1'b0;
                                        hp_oid_n = `E32_AT(sp - 8'd3)[12:0];
                                        hp_key_n = `E32_AT(sp - 8'd2)[15:0];
                                        hp_wval_n = {32'd0, `E32_AT(sp - 8'd1)};
                                        hp_tag_n = stack_tag_tos;
                                        hp_len_n = obj_n_rdata;
                                        hp_slot_n = 5'd0;
                                        hp_phase_n = 3'd0;
                                        state_n = S_HEAP_WAIT;
                                    end else begin
                                begin stack_we = 1'b1; stack_waddr = sp - 8'd3; stack_wdata = `E32_AT(sp - 8'd1); end
                                begin stack_tag_we = 1'b1; stack_tag_waddr = sp - 8'd3; stack_tag_wdata = stack_tag_tos; end
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
                                if (stack_tag_tos == 3'd2 &&
                                    (code_rdata[23:8] == id_length || code_rdata[23:8] == 16'd66)) begin
                                    begin stack_we = 1'b1; stack_waddr = sp - 8'd1; stack_wdata = {24'd0, arr_len_tos_rdata}; end
                                    begin stack_tag_we = 1'b1; stack_tag_waddr = sp - 8'd1; stack_tag_wdata = 3'd0; end
                                // NEW: "str".length — the interned length table
                                // already had this; only arrays were answered, so
                                // `col < row.length` was col < undefined and every
                                // character loop body was skipped.
                                end else if (stack_tag_tos == 3'd3 &&
                                    (code_rdata[23:8] == id_length || code_rdata[23:8] == 16'd66)) begin
                                    begin stack_we = 1'b1; stack_waddr = sp - 8'd1; stack_wdata = {24'd0, name_len_tos}; end
                                    begin stack_tag_we = 1'b1; stack_tag_waddr = sp - 8'd1; stack_tag_wdata = 3'd0; end
                                // NEW: dynamic string (replace / JSON result) length
                                end else if (stack_tag_tos == 3'd1 &&
                                    obj_cls_rdata == CLS_DYNSTR &&
                                    (code_rdata[23:8] == id_length || code_rdata[23:8] == 16'd66)) begin
                                    hp_cmd_n = HP_OGETI;
                                    hp_v64_n = 1'b0;
                                    hp_oid_n = `E32_AT(sp - 8'd1)[12:0];
                                    hp_slot_n = 5'd1;
                                    hp_qn_n = 3'd1;
                                    hp_qi_n = 3'd0;
                                    hp_nat_n = 4'd6;
                                    hp_ret_n = S_V64_OGETI_NAT;
                                    state_n = S_HEAP_WAIT;
                                end else if (stack_tag_tos == 3'd1) begin
                                    hp_cmd_n = HP_GETPROP;
                                    hp_v64_n = 1'b0;
                                    hp_oid_n = `E32_AT(sp - 8'd1)[12:0];
                                    hp_key_n = code_rdata[23:8];
                                    hp_len_n = obj_n_rdata;
                                    hp_slot_n = 5'd0;
                                    hp_phase_n = 3'd0;
                                    hp_proto_n = V64_UNDEFINED;
                                    hp_tag_n = 3'd0;
                                    state_n = S_HEAP_WAIT;
                                end else begin
                                if (stack_tag_tos == 3'd4 &&
                                            code_rdata[23:8] == id_proto) begin
                                    // Fn.prototype — scan parent fn_proto_* one index/clock.
                                    fp_scan_n = 1'b1;
                                    fp_armed_n = 1'b0;
                                    fp_hit_n = 1'b0;
                                    fp_i_n = 7'd0;
                                    fp_kind_n = 2'd1;
                                    fp_key_n = `E32_AT(sp - 8'd1)[15:0];
                                    fp_poid_n = 16'd0;
                                    state_n = S_EXEC;
                                end else if (stack_tag_tos == 3'd6 && code_rdata[23:8] == id_click) begin
                                    begin stack_we = 1'b1; stack_waddr = sp - 8'd1; stack_wdata = 32'sd1; end
                                    begin stack_tag_we = 1'b1; stack_tag_waddr = sp - 8'd1; stack_tag_wdata = 3'd4; end  // truthy click handle
                                end else if (stack_tag_tos == 3'd6 &&
                                            (code_rdata[23:8] == id_width || code_rdata[23:8] == id_height)) begin
                                    // canvas.width / canvas.height (INVADERS GAME_WIDTH path is literals; keep DOM sized)
                                    begin stack_we = 1'b1; stack_waddr = sp - 8'd1; stack_wdata = (code_rdata[23:8] == id_width) ? 32'sd640 : 32'sd480; end
                                    begin stack_tag_we = 1'b1; stack_tag_waddr = sp - 8'd1; stack_tag_wdata = 3'd0; end
                                end else if (stack_tag_tos == 3'd6) begin
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
                                if (stack_tag_nos == 3'd1) begin
                                    begin
                                        logic [12:0] oi;
                                        oi = `E32_AT(sp - 8'd2)[12:0];
                                        // last .a/.d/.space object wins — INVADERS keys table
                                        if (stack_tag_tos == 3'd1) begin
                                            if (code_rdata[23:8] == id_a || code_rdata[23:8] == 16'd98)
                                                keys_a_oid_n = `E32_AT(sp - 8'd1)[15:0];
                                            if (code_rdata[23:8] == id_d || code_rdata[23:8] == 16'd199)
                                                keys_d_oid_n = `E32_AT(sp - 8'd1)[15:0];
                                            if (code_rdata[23:8] == id_kspace || code_rdata[23:8] == 16'd204)
                                                keys_sp_oid_n = `E32_AT(sp - 8'd1)[15:0];
                                        end
                                        if (code_rdata[23:8] == id_src && stack_tag_tos == 3'd3) begin
                                            for (int k = 0; k < MAX_SPR; k++)
                                                if (`E32_AT(sp - 8'd1)[15:0] == spr_nid[k[3:0]])
                                                    begin obj_cls_we = 1'b1; obj_cls_waddr = oi; obj_cls_wdata = 16'hFFC0 | k[15:0]; end
                                        end
                                    end
                                    // Image.onload = fn — invoke now so player.image exists before animate
                                    if (code_rdata[23:8] == id_onload && stack_tag_tos == 3'd4) begin
                                        cstack_we = 1'b1; cstack_waddr = csp; cstack_ip_wdata = ip + 16'd1;
                                        cstack_we = 1'b1; cstack_waddr = csp; cstack_this_wdata = this_obj;
                                        cstack_we = 1'b1; cstack_waddr = csp; cstack_isctor_wdata = 1'b0;
                                        cstack_we = 1'b1; cstack_waddr = csp; cstack_isfe_wdata = 1'b0;
                                        enter_captured_fn(`E32_AT(sp - 8'd1)[15:0]);
                                        bump_csp();
                                        ip_n = fn_entry(`E32_AT(sp - 8'd1)[15:0]);
                                        code_raddr_n = 15'(ops_base + fn_entry(`E32_AT(sp - 8'd1)[15:0]));
                                        begin stack_we = 1'b1; stack_waddr = sp - 8'd2; stack_wdata = `E32_AT(sp - 8'd1); end
                                        begin stack_tag_we = 1'b1; stack_tag_waddr = sp - 8'd2; stack_tag_wdata = stack_tag_tos; end
                                        sp_n = sp - 8'd1;
                                        state_n = S_FETCH_WAIT;
                                    end else begin
                                        hp_cmd_n = HP_SETPROP;
                                        hp_v64_n = 1'b0;
                                        hp_oid_n = `E32_AT(sp - 8'd2)[12:0];
                                        hp_key_n = code_rdata[23:8];
                                        hp_wval_n = {32'd0, `E32_AT(sp - 8'd1)};
                                        hp_tag_n = stack_tag_tos;
                                        hp_len_n = obj_n_rdata;
                                        hp_slot_n = 5'd0;
                                        hp_phase_n = 3'd0;
                                        state_n = S_HEAP_WAIT;
                                    end
                                end else if (stack_tag_nos == 3'd2 &&
                                           (code_rdata[23:8] == id_length || code_rdata[23:8] == 16'd66)) begin
                                    begin arr_len_we = 1'b1; arr_len_waddr = `E32_AT(sp - 8'd2)[11:0]; arr_len_wdata = `E32_AT(sp - 8'd1)[7:0]; end
                                    begin stack_we = 1'b1; stack_waddr = sp - 8'd2; stack_wdata = `E32_AT(sp - 8'd1); end
                                    begin stack_tag_we = 1'b1; stack_tag_waddr = sp - 8'd2; stack_tag_wdata = stack_tag_tos; end
                                    sp_n = sp - 8'd1;
                                    next_op();
                                end else if (stack_tag_nos == 3'd6 &&
                                             code_rdata[23:8] == id_textalign) begin
                                    // NEW: ctx.textAlign — FM fill_text shifts the
                                    // pen by half / all of the text width
                                    ctx_align_n = (`E32_AT(sp - 8'd1)[15:0] == id_center) ? 2'd1
                                               : (`E32_AT(sp - 8'd1)[15:0] == id_right)  ? 2'd2
                                               : 2'd0;
                                    begin stack_we = 1'b1; stack_waddr = sp - 8'd2; stack_wdata = `E32_AT(sp - 8'd1); end
                                    begin stack_tag_we = 1'b1; stack_tag_waddr = sp - 8'd2; stack_tag_wdata = stack_tag_tos; end
                                    sp_n = sp - 8'd1;
                                    next_op();
                                end else if (stack_tag_nos == 3'd6 &&
                                             code_rdata[23:8] == id_font) begin
                                    // NEW: ctx.font = "bold 24px Foo" — walk the
                                    // bytes for the first NNpx run, exactly what
                                    // FM machine._font_scale's regex takes.
                                    begin stack_we = 1'b1; stack_waddr = sp - 8'd2; stack_wdata = `E32_AT(sp - 8'd1); end
                                    begin stack_tag_we = 1'b1; stack_tag_waddr = sp - 8'd2; stack_tag_wdata = stack_tag_tos; end
                                    sp_n = sp - 8'd1;
                                    if (stack_tag_tos == 3'd3 && names_ok &&
                                        name_has_tos) begin
                                        txt_rp_n = name_off_tos;
                                        name_rdaddr_n = name_off_tos;
                                        fp_left_n = name_len_tos;
                                        fpx_acc_n = 8'd0;
                                        ctx_font_px_n = 8'd8;  // no "px" found → FM default
                                        ip_n = ip + 16'd1;
                                        state_n = S_FONTPX;
                                    end else begin
                                        ctx_font_px_n = 8'd8;
                                        next_op();
                                    end
                                end else if (stack_tag_nos == 3'd6 &&
                                             code_rdata[23:8] == id_imgsmooth) begin
                                    // ctx.imageSmoothingEnabled = false → nearest
                                    // (indexed 8-bpp blit has no bilinear either way)
                                    ctx_smooth_n = (stack_tag_tos == 3'd5)
                                                ? `E32_AT(sp - 8'd1)[0]
                                                : (`E32_AT(sp - 8'd1) != 32'sd0);
                                    begin stack_we = 1'b1; stack_waddr = sp - 8'd2; stack_wdata = `E32_AT(sp - 8'd1); end
                                    begin stack_tag_we = 1'b1; stack_tag_waddr = sp - 8'd2; stack_tag_wdata = stack_tag_tos; end
                                    sp_n = sp - 8'd1;
                                    next_op();
                                end else if (stack_tag_nos == 3'd6 &&
                                           (code_rdata[23:8] == id_fillstyle ||
                                            code_rdata[23:8] == id_strokestyle)) begin
                                    // ctx.fillStyle / strokeStyle — FSTY LUT first
                                    // (compiler-resolved 256-palette index, exact FM
                                    // parity); legacy 8-color chain only as fallback
                                    if (stack_tag_tos == 3'd3 &&
                                        `E32_AT(sp - 8'd1)[15:0] < 16'd1024 &&
                                        fill_lut_rdata != 8'hFF)
                                        fill_style_i_n = fill_lut_rdata;
                                    else if (stack_tag_tos == 3'd0 ||
                                             stack_tag_tos == 3'd7)
                                        // numeric fillStyle — direct palette index
                                        fill_style_i_n = 8'(fxi(`E32_AT(sp - 8'd1),
                                                               stack_tag_tos));
                                    else if (`E32_AT(sp - 8'd1)[15:0] == id_black || `E32_AT(sp - 8'd1)[15:0] == id_hex_000)
                                        fill_style_i_n = 8'd0;
                                    else if (`E32_AT(sp - 8'd1)[15:0] == id_white || `E32_AT(sp - 8'd1)[15:0] == id_hex_fff
                                          || `E32_AT(sp - 8'd1)[15:0] == id_hex_aaa
                                          || `E32_AT(sp - 8'd1)[15:0] == id_hex_f5f5)
                                        fill_style_i_n = 8'd1;
                                    else if (`E32_AT(sp - 8'd1)[15:0] == id_red || `E32_AT(sp - 8'd1)[15:0] == id_hex_f00)
                                        fill_style_i_n = 8'd2;
                                    else if (`E32_AT(sp - 8'd1)[15:0] == id_hex_3f6 || `E32_AT(sp - 8'd1)[15:0] == id_hex_2ec)
                                        fill_style_i_n = 8'd3;
                                    else if (`E32_AT(sp - 8'd1)[15:0] == id_cyan || `E32_AT(sp - 8'd1)[15:0] == id_hex_09f)
                                        fill_style_i_n = 8'd4;
                                    else if (`E32_AT(sp - 8'd1)[15:0] == id_yellow || `E32_AT(sp - 8'd1)[15:0] == id_gold
                                          || `E32_AT(sp - 8'd1)[15:0] == id_hex_fc0
                                          || `E32_AT(sp - 8'd1)[15:0] == id_hex_ffe6)
                                        fill_style_i_n = 8'd5;
                                    else if (`E32_AT(sp - 8'd1)[15:0] == id_hex_f5a)
                                        fill_style_i_n = 8'd7;
                                    else fill_style_i_n = 8'd1;
                                    begin stack_we = 1'b1; stack_waddr = sp - 8'd2; stack_wdata = `E32_AT(sp - 8'd1); end
                                    begin stack_tag_we = 1'b1; stack_tag_waddr = sp - 8'd2; stack_tag_wdata = stack_tag_tos; end
                                    sp_n = sp - 8'd1;
                                    next_op();
                                end else begin
                                    begin stack_we = 1'b1; stack_waddr = sp - 8'd2; stack_wdata = `E32_AT(sp - 8'd1); end
                                    begin stack_tag_we = 1'b1; stack_tag_waddr = sp - 8'd2; stack_tag_wdata = stack_tag_tos; end
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
                                    eoid = (env_sp != 0) ? env_oid_rdata : 16'd0;
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
                                    hp_q_repl = 1'b1;
                                    hp_qk_nev[0] = 16'd0;
                                    hp_qv_nev[0] = {48'd0, code_rdata[23:8]};
                                    hp_qt_nev[0] = 3'd0;
                                    hp_qk_nev[1] = 16'd1;
                                    hp_qv_nev[1] = {56'd0, 2'd0, code_rdata[29:24]};
                                    hp_qt_nev[1] = 3'd0;
                                    hp_qk_nev[2] = 16'd2;
                                    hp_qv_nev[2] = {48'd0, eoid};
                                    hp_qt_nev[2] = 3'd0;
                                    hp_qk_nev[3] = 16'd3;
                                    hp_qv_nev[3] = {48'd0, this_obj};
                                    hp_qt_nev[3] = 3'd1;
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
                                cstack_we = 1'b1; cstack_waddr = csp; cstack_ip_wdata = ip + 16'd1;
                                cstack_we = 1'b1; cstack_waddr = csp; cstack_this_wdata = this_obj;
                                cstack_we = 1'b1; cstack_waddr = csp; cstack_isctor_wdata = 1'b0;
                                cstack_we = 1'b1; cstack_waddr = csp; cstack_isfe_wdata = 1'b0;
                                cstack_we = 1'b1; cstack_waddr = csp; cstack_env_wdata = env_sp;
                                push_fresh_env(16'd0);
                                bump_csp();
                                ip_n = code_rdata[23:8];
                                code_raddr_n = 15'(ops_base + code_rdata[23:8]);
                                state_n = S_FETCH_WAIT;
                            end
                            OP_CALL_VAL: begin
                                // argc in a0; stack [fn, args...] — pop fn, leave args (PYTHON call_fn)
                                if (`E32_STAG(sp - 8'(code_rdata[15:8]) - 8'd1) == 3'd4) begin
                                    begin
                                        logic [7:0] ac;
                                        logic [15:0] foid;
                                        logic [12:0] fo;
                                        logic [5:0]  capn;
                                        ac = code_rdata[15:8];
                                        foid = `E32_AT(sp - ac - 8'd1)[15:0];
                                        fo = foid[12:0];
                                        for (int k = 0; k < 8; k++) begin
                                            if (k < ac) begin
                                                begin stack_we = 1'b1; stack_waddr = sp - ac - 8'd1 + k[7:0]; stack_wdata = `E32_AT(sp - ac + 8'(k)); end
                                                begin stack_tag_we = 1'b1; stack_tag_waddr = sp - ac - 8'd1 + k[7:0]; stack_tag_wdata = `E32_STAG(sp - ac + 8'(k)); end
                                            end
                                        end
                                        sp_n = sp - 8'd1;
                                        cstack_we = 1'b1; cstack_waddr = csp; cstack_ip_wdata = ip + 16'd1;
                                        cstack_we = 1'b1; cstack_waddr = csp; cstack_this_wdata = this_obj;
                                        cstack_we = 1'b1; cstack_waddr = csp; cstack_isctor_wdata = 1'b0;
                                        cstack_we = 1'b1; cstack_waddr = csp; cstack_isfe_wdata = 1'b0;
                                        enter_captured_fn(foid);
                                        bump_csp();
                                        ip_n = tfn_entry_rdata;
                                        code_raddr_n = 15'(ops_base + tfn_entry_rdata);
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
                                end else if (cs1_ip == 16'hFFFE) begin
                                    // NEW: return from forEach/map/find callback → next element
                                    begin
                                        logic [15:0] md;
                                        logic truthy;
                                        md = cs2_map_arr;
                                        truthy = (sp != 0) && (stack_tag_tos != 3'd5) &&
                                                 !((stack_tag_tos == 3'd0 ||
                                                    stack_tag_tos == 3'd7) &&
                                                   `E32_AT(sp - 8'd1) == 32'sd0);
                                        if (md == 16'hFFFE && truthy) begin
                                            // find hit — AGETI then S_V64_FE_ELEM tagged
                                            dbg_find_hit_n = dbg_find_hit + 16'd1;
                                            hp_cmd_n = HP_AGETI;
                                            hp_v64_n = 1'b0;
                                            hp_aid_n = cs2_fe_arr[11:0];
                                            hp_aslot_n = cs2_fe_i[6:0];
                                            hp_alen_n = arr_len_nos_rdata;
                                            hp_ret_n = S_V64_FE_ELEM;
                                            state_n = S_HEAP_WAIT;
                                        end else if (md == 16'hFFFD && truthy) begin
                                            // findIndex hit — return current index
                                            begin stack_we = 1'b1; stack_waddr = sp - 8'd1; stack_wdata = {24'd0, cs2_fe_i}; end
                                            begin stack_tag_we = 1'b1; stack_tag_waddr = sp - 8'd1; stack_tag_wdata = 3'd0; end
                                            arm_release_env(cs1_env, S_FETCH_WAIT);
                                            ip_n = cs2_ip;
                                            this_obj_n = cs2_this;
                                            if (this_ok) begin
                                                vars_we = 1'b1; vars_waddr = var_this; vars_wdata = (cs2_this == 16'hFFFF)
                                                                  ? 32'd0
                                                                  : {16'd0, cs2_this};
                                                var_tag_we = 1'b1; var_tag_waddr = var_this; var_tag_wdata = (cs2_this == 16'hFFFF)
                                                                     ? 3'd5 : 3'd1;
                                            end
                                            csp_n = csp - 7'd2;
                                            code_raddr_n = 15'(ops_base + cs2_ip);
                                        end else begin
                                            if (cs2_isctor &&
                                                md != 16'hFFFF && md != 16'hFFFE && md != 16'hFFFD &&
                                                truthy) begin
                                                // filter: keep source element
                                                begin
                                                    logic [7:0] fl;
                                                    fl = arr_len_nos_rdata;
                                                    if (fl < ARR_CAP[7:0]) begin
                                                        begin arr_len_we = 1'b1; arr_len_waddr = md[11:0]; arr_len_wdata = fl + 8'd1; end
                                                    end
                                                end
                                            end else if (md != 16'hFFFF && md != 16'hFFFE &&
                                                       md != 16'hFFFD && !cs2_isctor &&
                                                       sp != 0) begin
                                            end
                                            arm_release_env(cs1_env, S_FOREACH);
                                            csp_n = csp - 7'd1;
                                            if (sp != 0) sp_n = sp - 8'd1;
                                            cstack_we = 1'b1; cstack_waddr = csp - 7'd2; cstack_fe_i_wdata = cs2_fe_i + 8'd1;
                                        end
                                    end
                                end else if (cs1_ip == 16'hFFFD) begin
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
                                            cstack_we = 1'b1; cstack_waddr = csp - 7'd1; cstack_ip_wdata = 16'hFFFD;
                                            cstack_we = 1'b1; cstack_waddr = csp - 7'd1; cstack_isctor_wdata = 1'b0;
                                            cstack_we = 1'b1; cstack_waddr = csp - 7'd1; cstack_isfe_wdata = 1'b0;
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
                                        arm_release_env(cs1_env, rel_nxt);
                                    end
                                end else begin
                                    // NEW: a callback frame returns to the frame
                                    // boundary sentinel (cstack_ip == n_ops). Latch
                                    // the RET site so a loop that stops re-arming
                                    // itself can be found (PACMAN start() fn dies
                                    // mid-frame and raf drops to 0 with no trace).
                                    if (cs1_ip == n_ops) dbg_cb_ip_n = ip;
                                    arm_release_env(cs1_env, S_FETCH_WAIT);
                                    csp_n = csp - 7'd1;
                                    this_obj_n = cs1_this;
                                    if (this_ok) begin
                                        vars_we = 1'b1; vars_waddr = var_this; vars_wdata = (cs1_this == 16'hFFFF)
                                                          ? 32'd0
                                                          : {16'd0, cs1_this};
                                        var_tag_we = 1'b1; var_tag_waddr = var_this; var_tag_wdata = (cs1_this == 16'hFFFF)
                                                             ? 3'd5 : 3'd1;
                                    end
                                    if (cs1_isctor) begin
                                        begin stack_we = 1'b1; stack_waddr = sp - 8'd1; stack_wdata = {16'd0, cs1_ctorobj}; end
                                        begin stack_tag_we = 1'b1; stack_tag_waddr = sp - 8'd1; stack_tag_wdata = 3'd1; end
                                    end
                                    ip_n = cs1_ip;
                                    code_raddr_n = 15'(ops_base + cs1_ip);
                                end
                            end
                            OP_NEW_OBJ: begin
                                if (!newobj_rdy && !newobj_emit) begin
                                    newobj_rdy_n = 1'b1;
                                    state_n = S_EXEC;
                                end else begin
                                if (!newobj_emit && !cm_done) begin
                                begin obj_n_we = 1'b1; obj_n_waddr = n_obj[12:0]; obj_n_wdata = 0; end
                                begin obj_cls_we = 1'b1; obj_cls_waddr = n_obj[12:0]; obj_cls_wdata = code_rdata[23:8]; end
                                cm_scan_n = 1'b1;
                                cm_armed_n = 1'b0;
                                cm_done_n = 1'b0;
                                cm_c_n = 4'd0;
                                cm_m_n = 4'd0;
                                cm_mip_n = 16'hFFFF;
                                cm_key_n = 16'hFFFF;
                                cm_cls_n = code_rdata[23:8];
                                newobj_ctor_n = 16'hFFFF;
                                state_n = S_EXEC;
                                end else begin
                                begin
                                    logic [15:0] ctor_ip;
                                    logic [8:0] vslot;
                                    ctor_ip = newobj_ctor;
                                    if (!newobj_emit) begin
                                    cm_done_n = 1'b0;
                                    // PACMAN `var Item = function` — class table ctor is FFFF
                                    if (ctor_ip == 16'hFFFF && intern_var_ok_rdata) begin
                                        vslot = intern_var_rdata;
                                        if (var_tag_rdata == 3'd4) begin
                                            ctor_ip = fn_entry(vars_rdata[15:0]);
                                        end
                                    end
                                    newobj_ctor_n = ctor_ip;
                                    if (n_fn_proto != 7'd0) begin
                                        fp_scan_n = 1'b1;
                                        fp_armed_n = 1'b0;
                                        fp_hit_n = 1'b0;
                                        fp_i_n = 7'd0;
                                        fp_kind_n = (ctor_ip != 16'hFFFF && intern_var_ok_rdata && var_tag_rdata == 3'd4)
                                            ? 2'd2 : 2'd3;
                                        fp_key_n = (fp_kind_n == 2'd2) ? vars_rdata[15:0] : ctor_ip;
                                        fp_poid_n = 16'd0;
                                        state_n = S_EXEC;
                                    end
                                    end
                                    if (fp_scan_n) begin
                                        state_n = S_EXEC;
                                    end else if (ctor_ip != 16'hFFFF) begin
                                        cstack_we = 1'b1; cstack_waddr = csp; cstack_ip_wdata = ip + 16'd1;
                                        cstack_we = 1'b1; cstack_waddr = csp; cstack_this_wdata = this_obj;
                                        cstack_we = 1'b1; cstack_waddr = csp; cstack_isctor_wdata = 1'b1;
                                        cstack_we = 1'b1; cstack_waddr = csp; cstack_isfe_wdata = 1'b0;
                                        cstack_we = 1'b1; cstack_waddr = csp; cstack_env_wdata = env_sp;
                                        cstack_we = 1'b1; cstack_waddr = csp; cstack_ctorobj_wdata = n_obj;
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
                                                `E32_STAG(sp - nac) == 3'd3 &&
                                                id_type != 16'hFFFF) begin
            // flatten: heap write via S_HEAP_* only
            // flatten: heap write via S_HEAP_* only
            // flatten: heap write via S_HEAP_* only
                                                nn = 6'd1;
                                            end
                                            if (is_dom && nac >= 8'd2 &&
                                                `E32_STAG(sp - nac + 8'd1) == 3'd1) begin
                                                src = `E32_AT(sp - nac + 8'd1)[12:0];
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
                                end
                            end
                            OP_CALL_METH: begin
                                // [obj, args...] a0=meth intern a1=argc
                                if (`E32_STAG(sp - 8'(code_rdata[31:24]) - 8'd1) == 3'd2 &&
                                    code_rdata[23:8] == id_push) begin
                                    begin
                                        logic [11:0] ai;
                                        logic [7:0] al;
                                        ai = `E32_AT(sp - 8'(code_rdata[31:24]) - 8'd1)[11:0];
                                        al = arr_len_nos_rdata;
                                        if (al < ARR_CAP[7:0]) begin
                                            begin arr_len_we = 1'b1; arr_len_waddr = ai; arr_len_wdata = al + 8'd1; end
                                            // NEW: keep only if dest array is
                                            // old-space (global arr.push). Finder
                                            // new_list.push(to) is nursery — rewind.
                                            // Deep: grids.push(new Grid()) must also
                                            // keep the fields the ctor built after it.
                                            if (arr_keep_ok && {4'd0, ai} < n_arr_keep)
                                                commit_deep_keep(stack_tag_tos);
                                            hp_cmd_n = HP_ASETI;
                                            hp_v64_n = 1'b0;
                                            hp_from_stack_n = 1'b0;
                                            hp_aid_n = ai;
                                            hp_aslot_n = al[6:0];
                                            hp_wval_n = {32'd0, `E32_AT(sp - 8'd1)};
                                            hp_tag_n = stack_tag_tos;
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
                                end else if (`E32_STAG(sp - 8'(code_rdata[31:24]) - 8'd1) == 3'd2 &&
                                           code_rdata[23:8] == id_fill) begin
                                    // arr.fill(v) — not ctx.fill()
                                    begin
                                        logic [11:0] ai;
                                        logic [7:0] al;
                                        ai = `E32_AT(sp - 8'(code_rdata[31:24]) - 8'd1)[11:0];
                                        al = arr_len_nos_rdata;
                                        stack_we = 1'b1; stack_waddr = sp - 8'(code_rdata[31:24]) - 8'd1; stack_wdata =
                                            `E32_AT(sp - 8'(code_rdata[31:24]) - 8'd1);
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
                                                ? {32'd0, `E32_AT(sp - 8'd1)} : 64'd0;
                                            hp_tag_n = (code_rdata[31:24] >= 8'd1)
                                                ? stack_tag_tos : 3'd0;
                                            hp_ret_n = S_FETCH_WAIT;
                                            state_n = S_HEAP_FILL;
                                        end else
                                            state_n = S_FETCH_WAIT;
                                    end
                                end else if (`E32_STAG(sp - 8'(code_rdata[31:24]) - 8'd1) == 3'd2 &&
                                           (code_rdata[23:8] == id_foreach ||
                                            code_rdata[23:8] == 16'd112 ||
                                            code_rdata[23:8] == id_map ||
                                            code_rdata[23:8] == id_find ||
                                            (id_findindex != 16'hFFFF &&
                                             code_rdata[23:8] == id_findindex) ||
                                            (id_filter != 16'hFFFF &&
                                             code_rdata[23:8] == id_filter))) begin
                                    // arr.forEach/map/find/findIndex/filter
                                    cstack_we = 1'b1; cstack_waddr = csp; cstack_ip_wdata = ip + 16'd1;
                                    cstack_we = 1'b1; cstack_waddr = csp; cstack_this_wdata = this_obj;
                                    cstack_we = 1'b1; cstack_waddr = csp; cstack_isctor_wdata = (id_filter != 16'hFFFF &&
                                                           code_rdata[23:8] == id_filter);
                                    cstack_we = 1'b1; cstack_waddr = csp; cstack_isfe_wdata = 1'b1;
                                    cstack_we = 1'b1; cstack_waddr = csp; cstack_fe_arr_wdata = `E32_AT(sp - 8'(code_rdata[31:24]) - 8'd1)[15:0];
                                    cstack_we = 1'b1; cstack_waddr = csp; cstack_fe_fn_wdata = `E32_AT(sp - 8'd1)[15:0];
                                    cstack_we = 1'b1; cstack_waddr = csp; cstack_ctorobj_wdata = {8'd0, fn_nparam(`E32_AT(sp - 8'd1)[15:0])};
                                    cstack_we = 1'b1; cstack_waddr = csp; cstack_fe_i_wdata = 8'd0;
                                    if (code_rdata[23:8] == id_map) begin
                                        arr_len_we = 1'b1; arr_len_waddr = n_arr[11:0]; arr_len_wdata =
                                            arr_len_nos_rdata;
                                        cstack_we = 1'b1; cstack_waddr = csp; cstack_map_arr_wdata = n_arr;
                                        // NEW: map() output is nursery; SET_PROP
                                        // commits if stored. Do not freeze temps.
                                        if (n_arr >= 16'(MAX_ARR - 1)) dbg_heap_ovf_n = dbg_heap_ovf + 16'd1;
                                        n_arr_n = (n_arr >= 16'(MAX_ARR - 1)) ? n_arr : (n_arr + 16'd1);
                                    end else if (code_rdata[23:8] == id_filter) begin
                                        begin arr_len_we = 1'b1; arr_len_waddr = n_arr[11:0]; arr_len_wdata = 8'd0; end
                                        cstack_we = 1'b1; cstack_waddr = csp; cstack_map_arr_wdata = n_arr;
                                        if (n_arr >= 16'(MAX_ARR - 1)) dbg_heap_ovf_n = dbg_heap_ovf + 16'd1;
                                        n_arr_n = (n_arr >= 16'(MAX_ARR - 1)) ? n_arr : (n_arr + 16'd1);
                                    end else if (id_find != 16'hFFFF &&
                                                code_rdata[23:8] == id_find) begin
                                        cstack_we = 1'b1; cstack_waddr = csp; cstack_map_arr_wdata = 16'hFFFE;  // find sentinel
                                    end else if (id_findindex != 16'hFFFF &&
                                             code_rdata[23:8] == id_findindex) begin
                                        cstack_we = 1'b1; cstack_waddr = csp; cstack_map_arr_wdata = 16'hFFFD;  // findIndex sentinel
                                    end else begin
                                        cstack_we = 1'b1; cstack_waddr = csp; cstack_map_arr_wdata = 16'hFFFF;
                                    end
                                    cstack_we = 1'b1; cstack_waddr = csp; cstack_env_wdata = env_sp;
                                    bump_csp();
                                    sp_n = sp - 8'(code_rdata[31:24]) - 8'd1;
                                    state_n = S_FOREACH;
                                end else if (`E32_STAG(sp - 8'(code_rdata[31:24]) - 8'd1) == 3'd2 &&
                                           code_rdata[23:8] == id_unshift) begin
                                    // arr.unshift(v) — insert at 0
                                    begin
                                        logic [11:0] ai;
                                        logic [7:0] al;
                                        ai = `E32_AT(sp - 8'(code_rdata[31:24]) - 8'd1)[11:0];
                                        al = arr_len_nos_rdata;
                                        if (al < ARR_CAP[7:0]) begin
                                            begin arr_len_we = 1'b1; arr_len_waddr = ai; arr_len_wdata = al + 8'd1; end
                                            if (arr_keep_ok && {4'd0, ai} < n_arr_keep)
                                                commit_deep_keep(stack_tag_tos);
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
                                                    ? {32'd0, `E32_AT(sp - 8'd1)} : 64'd0;
                                                hp_tag_n = (code_rdata[31:24] >= 8'd1)
                                                    ? stack_tag_tos : 3'd5;
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
                                                    ? {32'd0, `E32_AT(sp - 8'd1)} : 64'd0;
                                                hp_tag_n = (code_rdata[31:24] >= 8'd1)
                                                    ? stack_tag_tos : 3'd5;
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
                                end else if (`E32_STAG(sp - 8'(code_rdata[31:24]) - 8'd1) == 3'd2 &&
                                           code_rdata[23:8] == id_splice) begin
                                    // splice(start, n) — shift-delete (INVADERS cull)
                                    begin
                                        logic [11:0] ai;
                                        logic [7:0] st, cnt;
                                        dbg_splice_n_n = dbg_splice_n + 16'd1;
                                        ai = `E32_AT(sp - 8'(code_rdata[31:24]) - 8'd1)[11:0];
                                        st = (code_rdata[31:24] >= 8'd1) ? `E32_AT(sp - 8'(code_rdata[31:24]))[7:0] : 8'd0;
                                        cnt = (code_rdata[31:24] >= 8'd2) ? `E32_AT(sp - 8'd1)[7:0] : 8'd1;
                                        if (st < arr_len_nos_rdata) begin
                                            if (arr_len_nos_rdata > cnt) begin arr_len_we = 1'b1; arr_len_waddr = ai; arr_len_wdata = arr_len_nos_rdata - cnt; end
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
                                            hp_alen_n = arr_len_nos_rdata;
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
                                end else if (`E32_STAG(sp - 8'(code_rdata[31:24]) - 8'd1) == 3'd2 &&
                                           code_rdata[23:8] == id_join) begin
                                    // NEW: arr.join('') — hash the digit chars with the
                                    // encoder's u16 hash, then reverse-map to an interned
                                    // name so string EQ (intern-id compare) just works.
                                    // PACMAN maze wall-shape switch: neighbors.join('')=='1100'
                                    jn_arr_n = `E32_AT(sp - 8'(code_rdata[31:24]) - 8'd1)[11:0];
                                    jn_i_n = 16'd0; jn_h_n = 16'd0;
                                    jn_res_n = 11'(sp - 8'(code_rdata[31:24]) - 8'd1);
                                    sp_n = sp - 8'(code_rdata[31:24]);
                                    ip_n = ip + 16'd1;
                                    state_n = S_JOIN;
                                end else if (`E32_STAG(sp - 8'(code_rdata[31:24]) - 8'd1) == 3'd2 &&
                                           code_rdata[23:8] == id_indexof &&
                                           code_rdata[31:24] >= 8'd1) begin
                                    // NEW: arr.indexOf(v) — linear scan, -1 when absent (FM twin)
                                    jn_arr_n = `E32_AT(sp - 8'(code_rdata[31:24]) - 8'd1)[11:0];
                                    jn_i_n = 16'd0;
                                    idx_v_n = $signed(`E32_AT(sp - 8'(code_rdata[31:24])));
                                    idx_t_n = `E32_STAG(sp - 8'(code_rdata[31:24]));
                                    jn_res_n = 11'(sp - 8'(code_rdata[31:24]) - 8'd1);
                                    sp_n = sp - 8'(code_rdata[31:24]);
                                    ip_n = ip + 16'd1;
                                    state_n = S_IDXOF;
                                end else if (code_rdata[23:8] == id_replace &&
                                           code_rdata[31:24] >= 8'd2 &&
                                           (`E32_STAG(sp - 8'(code_rdata[31:24]) - 8'd1) == 3'd3 ||
                                            (`E32_STAG(sp - 8'(code_rdata[31:24]) - 8'd1) == 3'd1 &&
                                             obj_cls_rdata == CLS_DYNSTR))) begin
                                    // String.replace — dynstr or interned 1-char; pattern
                                    // is packed RegExp or interned/int. Any HTML.
                                    begin
                                        logic [7:0] ac;
                                        logic [15:0] recv, p0;
                                        logic [2:0]  rt, pt;
                                        logic [31:0] preg;
                                        ac = code_rdata[31:24];
                                        recv = `E32_AT(sp - ac - 8'd1)[15:0];
                                        rt = `E32_STAG(sp - ac - 8'd1);
                                        p0 = `E32_AT(sp - ac)[15:0];
                                        pt = `E32_STAG(sp - ac);
                                        json_res_n = 11'(sp - ac - 8'd1);
                                        sp_n = sp - ac;
                                        ip_n = ip + 16'd1;
                                        repl_g_n = 1'b0; repl_nlen_n = 8'd1; repl_pat1_n = 8'd0;
                                        repl_pat0_n = 8'd0;
                                        if (pt == 3'd1 && obj_cls_rdata == CLS_REGEX) begin
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
                                        end else if (pt == 3'd3 && name_len_nos == 8'd1)
                                            repl_pat0_n = name_hash_nos[7:0];
                                        else if (pt == 3'd0)
                                            repl_pat0_n = 8'(fxi(`E32_AT(sp - ac), pt) + 32'sd48);
                                        // replacement: int → digit, intern 1-char, else '0'
                                        if (stack_tag_tos == 3'd3 &&
                                            name_len_tos == 8'd1)
                                            repl_rch_n = name_hash_tos[7:0];
                                        else if (stack_tag_tos == 3'd0)
                                            repl_rch_n = 8'(fxi(`E32_AT(sp - 8'd1), 3'd0) + 32'sd48);
                                        else
                                            repl_rch_n = 8'h30;
                                        if (!(pt == 3'd1 && obj_cls_rdata == CLS_REGEX) &&
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
                                        end else if (name_len_tos == 8'd1 &&
                                                     !name_has_tos) begin
                                            // interned 1-char without NAMB: hash == byte
                                            begin json_mem_we = 1'b1; json_mem_waddr = 0; json_mem_wdata = name_hash_tos[7:0]; end
                                            json_src_n = 14'd0;
                                            json_srclen_n = 14'd1;
                                            json_rp_n = 14'd0;
                                            json_dst_n = 14'd1;
                                            json_wp_n = 14'd1;
                                            state_n = S_REPL;
                                        end else begin
                                            // interned longer: copy name_mem → json_mem
                                            json_src_n = 14'd0;
                                            json_srclen_n = {6'd0, name_len_tos};
                                            json_rp_n = 14'd0;
                                            name_rdaddr_n = name_off_tos;
                                            json_wp_n = 14'd0;
                                            namcpy_repl_n = 1'b1;
                                            namcpy_armed_n = 1'b0;
                                            state_n = S_NAMCPY;
                                        end
                                        repl_did_n = 1'b0;
                                    end
                                end else if (code_rdata[23:8] == id_indexof &&
                                           code_rdata[31:24] >= 8'd1 &&
                                           `E32_STAG(sp - 8'(code_rdata[31:24]) - 8'd1) == 3'd1 &&
                                           obj_cls_rdata == CLS_DYNSTR) begin
                                    // dynstr.indexOf(v) — JS coerces number 0 → "0"
                                    begin
                                        logic [7:0] ac;
                                        logic [15:0] recv;
                                        ac = code_rdata[31:24];
                                        recv = `E32_AT(sp - ac - 8'd1)[15:0];
                                        json_res_n = 11'(sp - ac - 8'd1);
                                        if (`E32_STAG(sp - ac) == 3'd3 &&
                                            name_len_tos == 8'd1)
                                            idx_needle_n = name_hash_tos[7:0];
                                        else
                                            idx_needle_n = 8'(fxi(`E32_AT(sp - ac), `E32_STAG(sp - ac)) + 32'sd48);
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
                                    if (`E32_AT(sp - 8'd2)[15:0] == id_keydown)
                                        add_key_listener(1'b1, `E32_AT(sp - 8'd1)[15:0]);
                                    if (`E32_AT(sp - 8'd2)[15:0] == id_keyup)
                                        add_key_listener(1'b0, `E32_AT(sp - 8'd1)[15:0]);
                                    if (`E32_AT(sp - 8'd2)[15:0] == id_click && click_fn == 16'hFFFF)
                                        click_fn_n = `E32_AT(sp - 8'd1)[15:0];
                                    begin stack_we = 1'b1; stack_waddr = sp - 8'(code_rdata[31:24]) - 8'd1; stack_wdata = 32'sd0; end
                                    begin stack_tag_we = 1'b1; stack_tag_waddr = sp - 8'(code_rdata[31:24]) - 8'd1; stack_tag_wdata = 3'd5; end
                                    sp_n = sp - 8'(code_rdata[31:24]);
                                    next_op();
                                end else if (code_rdata[23:8] == id_rel) begin
                                    // el.removeEventListener(type, fn)
                                    if (`E32_AT(sp - 8'd2)[15:0] == id_keydown)
                                        remove_key_listener(1'b1, `E32_AT(sp - 8'd1)[15:0]);
                                    if (`E32_AT(sp - 8'd2)[15:0] == id_keyup)
                                        remove_key_listener(1'b0, `E32_AT(sp - 8'd1)[15:0]);
                                    begin stack_we = 1'b1; stack_waddr = sp - 8'(code_rdata[31:24]) - 8'd1; stack_wdata = 32'sd0; end
                                    begin stack_tag_we = 1'b1; stack_tag_waddr = sp - 8'(code_rdata[31:24]) - 8'd1; stack_tag_wdata = 3'd5; end
                                    sp_n = sp - 8'(code_rdata[31:24]);
                                    next_op();
                                end else if (code_rdata[23:8] == id_disp) begin
                                    // el.dispatchEvent(ev) — fire listeners now (PYTHON parity)
                                    if (code_rdata[31:24] >= 8'd1 &&
                                        stack_tag_tos == 3'd1 &&
                                        kd_n != 3'd0 && kd_slot[0] != 16'hFFFF) begin
                                        logic [15:0] oid;
                                        oid = `E32_AT(sp - 8'd1)[15:0];
                                        kev_obj_n = oid;
                                        kev_fn_n = kd_slot[0];
                                        kev_li_n = 2'd0;
                                        kev_is_down_n = 1'b1;
                                        kev_ret_ip_n = ip + 16'd1;
                                        begin stack_we = 1'b1; stack_waddr = 0; stack_wdata = {16'd0, oid}; end
                                        begin stack_tag_we = 1'b1; stack_tag_waddr = 0; stack_tag_wdata = 3'd1; end
                                        boundary_sp(11'd1);
                                        cstack_we = 1'b1; cstack_waddr = csp; cstack_ip_wdata = 16'hFFFD;
                                        cstack_we = 1'b1; cstack_waddr = csp; cstack_this_wdata = this_obj;
                                        cstack_we = 1'b1; cstack_waddr = csp; cstack_isctor_wdata = 1'b0;
                                        cstack_we = 1'b1; cstack_waddr = csp; cstack_isfe_wdata = 1'b0;
                                        state_n = S_KEYEV;
                                    end else begin
                                        begin stack_we = 1'b1; stack_waddr = sp - 8'(code_rdata[31:24]) - 8'd1; stack_wdata = 32'sd1; end
                                        begin stack_tag_we = 1'b1; stack_tag_waddr = sp - 8'(code_rdata[31:24]) - 8'd1; stack_tag_wdata = 3'd0; end
                                        sp_n = sp - 8'(code_rdata[31:24]);
                                        next_op();
                                    end
                                end else if (`E32_STAG(sp - 8'(code_rdata[31:24]) - 8'd1) == 3'd6 &&
                                           code_rdata[23:8] == id_getctx) begin
                                    begin stack_we = 1'b1; stack_waddr = sp - 8'(code_rdata[31:24]) - 8'd1; stack_wdata = 32'd1; end  // canvas2d elem
                                    begin stack_tag_we = 1'b1; stack_tag_waddr = sp - 8'(code_rdata[31:24]) - 8'd1; stack_tag_wdata = 3'd6; end
                                    sp_n = sp - 8'(code_rdata[31:24]);
                                    next_op();
                                end else if (`E32_STAG(sp - 8'(code_rdata[31:24]) - 8'd1) == 3'd6 &&
                                           code_rdata[23:8] == id_click) begin
                                    if (click_fn != 16'hFFFF) begin
                                        click_fired_n = 1'b1;
                                        cstack_we = 1'b1; cstack_waddr = csp; cstack_ip_wdata = ip + 16'd1;
                                        cstack_we = 1'b1; cstack_waddr = csp; cstack_this_wdata = this_obj;
                                        cstack_we = 1'b1; cstack_waddr = csp; cstack_isctor_wdata = 1'b0;
                                        cstack_we = 1'b1; cstack_waddr = csp; cstack_isfe_wdata = 1'b0;
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
                                end else if (`E32_STAG(sp - 8'(code_rdata[31:24]) - 8'd1) == 3'd1 &&
                                            obj_cls_rdata == 16'hFFFD &&
                                            code_rdata[31:24] == 8'd0) begin
                                    // (new Date()).getTime() even if intern id_gettime missed
                                    // — pure READ of the frame clock (FM twin)
                                    begin
                                        begin stack_we = 1'b1; stack_waddr = sp - 8'd1; stack_wdata = time_ms; end
                                        begin stack_tag_we = 1'b1; stack_tag_waddr = sp - 8'd1; stack_tag_wdata = 3'd0; end
                                        next_op();
                                    end
                                end else if (code_rdata[23:8] == id_bind &&
                                           `E32_STAG(sp - 8'(code_rdata[31:24]) - 8'd1) == 3'd4) begin
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
                                        begin stack_we = 1'b1; stack_waddr = sp - aca - 8'd1; stack_wdata = `E32_AT(sp - aca); end
                                        begin stack_tag_we = 1'b1; stack_tag_waddr = sp - aca - 8'd1; stack_tag_wdata = `E32_STAG(sp - aca); end
                                        if (`E32_STAG(sp - aca) == 3'd1 && aca >= 8'd2 &&
                                            `E32_STAG(sp - aca + 8'd1) == 3'd1) begin
                                            hp_cmd_n = HP_ASSIGN;
                                            hp_v64_n = 1'b0;
                                            hp_oid_n = `E32_AT(sp - aca)[12:0];
                                            hp_si_n = `E32_AT(sp - aca + 8'd1)[12:0];
                                            hp_ss_n = 5'd0;
                                            hp_phase_n = 3'd0;
                                            hp_tn_n = obj_n_rdata;
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
                                    ctx_tx_n = ctx_tx + `E32_STI(sp - 9'd2);
                                    ctx_ty_n = ctx_ty + `E32_STI(sp - 9'd1);
                                    sp_n = sp - 8'(code_rdata[31:24]);
                                    next_op();
                                end else if (code_rdata[23:8] == id_settransform &&
                                           code_rdata[31:24] >= 8'd6) begin
                                    // NEW: setTransform(a,b,c,d,e,f) — FM spec
                                    // (bytecode.py): _sx=a or 1, _sy=d or 1,
                                    // _tx=e, _ty=f. Shear b,c ignored like FM.
                                    ctx_sx_n = (`E32_STFX(sp - 9'd6) == 32'sd0) ? FX_ONE : `E32_STFX(sp - 9'd6);
                                    ctx_sy_n = (`E32_STFX(sp - 9'd3) == 32'sd0) ? FX_ONE : `E32_STFX(sp - 9'd3);
                                    ctx_tx_n = `E32_STI(sp - 9'd2);
                                    ctx_ty_n = `E32_STI(sp - 9'd1);
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
                                        pc_we = 1'b1;
                                        pc_waddr = pc_n[3:0];
                                        pc_op_wdata = 2'd3;
                                        pc_a1_wdata = `E32_STFX(sp - 9'(code_rdata[31:24]));
                                        pc_a2_wdata = `E32_STFX(sp - 9'(code_rdata[31:24]) + 9'd1);
                                        pc_a3_wdata = `E32_STFX(sp - 9'(code_rdata[31:24]) + 9'd2);
                                        pc_a4_wdata = (code_rdata[31:24] > 8'd3)
                                            ? `E32_STFX(sp - 9'(code_rdata[31:24]) + 9'd3) : 32'sd0;
                                        pc_a5_wdata = (code_rdata[31:24] > 8'd4)
                                            ? `E32_STFX(sp - 9'(code_rdata[31:24]) + 9'd4) : 32'sd0;
                                        pc_ccw_wdata = (code_rdata[31:24] > 8'd5)
                                            && (`E32_AT(sp - 9'd1) != 32'd0);
                                        pc_n_n = pc_n + 5'd1;
                                    end else dbg_path_ovf_n = dbg_path_ovf + 16'd1;
                                    sp_n = sp - 8'(code_rdata[31:24]);
                                    next_op();
                                end else if ((code_rdata[23:8] == id_moveto ||
                                            code_rdata[23:8] == id_lineto) &&
                                           code_rdata[31:24] >= 8'd2) begin
                                    if (pc_n < 5'(PATH_MAX)) begin
                                        pc_we = 1'b1;
                                        pc_waddr = pc_n[3:0];
                                        pc_op_wdata = (code_rdata[23:8] == id_moveto) ? 2'd0 : 2'd1;
                                        pc_a1_wdata = `E32_STFX(sp - 9'(code_rdata[31:24]));
                                        pc_a2_wdata = `E32_STFX(sp - 9'(code_rdata[31:24]) + 9'd1);
                                        pc_n_n = pc_n + 5'd1;
                                    end else dbg_path_ovf_n = dbg_path_ovf + 16'd1;
                                    sp_n = sp - 8'(code_rdata[31:24]);
                                    next_op();
                                end else if (code_rdata[23:8] == id_quadcurve &&
                                           code_rdata[31:24] >= 8'd4) begin
                                    // NEW: quadraticCurveTo(cx,cy,x,y)
                                    if (pc_n < 5'(PATH_MAX)) begin
                                        pc_we = 1'b1;
                                        pc_waddr = pc_n[3:0];
                                        pc_op_wdata = 2'd2;
                                        pc_a1_wdata = `E32_STFX(sp - 9'd4);
                                        pc_a2_wdata = `E32_STFX(sp - 9'd3);
                                        pc_a3_wdata = `E32_STFX(sp - 9'd2);
                                        pc_a4_wdata = `E32_STFX(sp - 9'd1);
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
                                        txt_val_n = `E32_AT(a0);
                                        txt_vt_n = `E32_STAG(a0);
                                        txt_ph_n = 4'd0;
                                        sp_n = sp - 8'(code_rdata[31:24]) - 8'd1;
                                        ip_n = ip + 16'd1;
                                        if (ctx_sx != FX_ONE || ctx_sy != FX_ONE) begin
                                            // scaled ctx (DONKEY world→glass): the pen
                                            // goes through the shared _xf multiplier
                                            xf_x_n = `E32_STFX(a0 + 11'd1);
                                            xf_y_n = `E32_STFX(a0 + 11'd2);
                                            xf_w_n = 32'sd0; xf_h_n = 32'sd0;
                                            xf_dst_n = 2'd2;
                                            state_n = S_XF_MUL;
                                        end else begin
                                            txt_px_n = 16'(`E32_STI(a0 + 11'd1) + ctx_tx);
                                            txt_py_n = 16'(`E32_STI(a0 + 11'd2) + ctx_ty);
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
                                        if (`E32_STAG(sp - ac) == 3'd3)
                                            tl = {8'd0, name_len_tos};
                                        else if (`E32_STAG(sp - ac) == 3'd1 &&
                                                 obj_cls_rdata == CLS_DYNSTR) begin
                                            hp_cmd_n = HP_OGETI;
                                            hp_v64_n = 1'b0;
                                            hp_oid_n = `E32_AT(sp - ac)[12:0];
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
                                        ioid = `E32_AT(sp - ac)[15:0];
                                        si = 8'(obj_cls_rdata[3:0]); // NEW: 4-bit idx (16 sprites)
                                        if (obj_cls_rdata[15:4] == 12'hFFC && {1'b0, si} < {4'd0, n_spr}) begin
                                            dbg_di_hit_n = dbg_di_hit + 16'd1;
                                            blit_si_n = si;
                                            if (ac >= 8'd9) begin
                                                // NEW: 16-bit source window (full-res ASET sheets)
                                                blit_sx_n = clip_src(`E32_STI(sp - 9'd8));
                                                blit_sy_n = clip_src(`E32_STI(sp - 9'd7));
                                                blit_sw_n = clip_src(`E32_STI(sp - 9'd6));
                                                blit_sh_n = clip_src(`E32_STI(sp - 9'd5));
                                            end else begin
                                                blit_sx_n = 16'd0; blit_sy_n = 16'd0;
                                                blit_sw_n = spr_ww[si[3:0]]; blit_sh_n = spr_hh[si[3:0]];
                                            end
                                            if (ctx_sx != FX_ONE || ctx_sy != FX_ONE) begin
                                                // NEW: scaled dest — FM _xf on dx,dy,dw,dh
                                                // (DONKEY setTransform world→glass)
                                                if (ac >= 8'd5) begin
                                                    xf_x_n = `E32_STFX(sp - 9'd4); xf_y_n = `E32_STFX(sp - 9'd3);
                                                    xf_w_n = `E32_STFX(sp - 9'd2); xf_h_n = `E32_STFX(sp - 9'd1);
                                                end else begin
                                                    xf_x_n = `E32_STFX(sp - 9'd2); xf_y_n = `E32_STFX(sp - 9'd1);
                                                    xf_w_n = 32'(spr_ww[si[3:0]]) <<< 16;
                                                    xf_h_n = 32'(spr_hh[si[3:0]]) <<< 16;
                                                end
                                                xf_dst_n = 2'd1;
                                                sp_n = sp - ac - 8'd1;
                                                ip_n = ip + 16'd1;
                                                state_n = S_XF_MUL;
                                            end else begin
                                                if (ac >= 8'd5) begin
                                                    rx_n = clip_u(`E32_STI(sp - 9'd4) + ctx_tx, MW);
                                                    ry_n = clip_u(`E32_STI(sp - 9'd3) + ctx_ty, MH);
                                                    rw_n = clip_sz(`E32_STI(sp - 9'd2), clip_u(`E32_STI(sp - 9'd4) + ctx_tx, MW), MW);
                                                    rh_n = clip_sz(`E32_STI(sp - 9'd1), clip_u(`E32_STI(sp - 9'd3) + ctx_ty, MH), MH);
                                                end else begin
                                                    rx_n = clip_u(`E32_STI(sp - 9'd2) + ctx_tx, MW);
                                                    ry_n = clip_u(`E32_STI(sp - 9'd1) + ctx_ty, MH);
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
                                        gx = (acg >= 8'd1) ? `E32_STI(sp - acg) : 32'sd0;
                                        gy = (acg >= 8'd2) ? `E32_STI(sp - acg + 8'd1) : 32'sd0;
                                        gw = (acg >= 8'd3) ? `E32_STI(sp - acg + 8'd2) : 32'sd0;
                                        gh = (acg >= 8'd4) ? `E32_STI(sp - acg + 8'd3) : 32'sd0;
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
                                        src = (acp >= 8'd1) ? `E32_AT(sp - acp)[15:0] : 16'd0;
                                        if (acp >= 8'd1 && `E32_STAG(sp - acp) == 3'd1 &&
                                            obj_cls_rdata == CLS_IMGD) begin
                                            imgd_x0_n = (acp >= 8'd2) ? clip_u(`E32_STI(sp - acp + 8'd1), MW) : 10'd0;
                                            imgd_y0_n = (acp >= 8'd3) ? clip_u(`E32_STI(sp - acp + 8'd2), MH) : 10'd0;
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
                                        xf_x_n = `E32_STFX(sp - 9'd4); xf_y_n = `E32_STFX(sp - 9'd3);
                                        xf_w_n = `E32_STFX(sp - 9'd2); xf_h_n = `E32_STFX(sp - 9'd1);
                                        xf_dst_n = 2'd0;
                                        sp_n = sp - 8'(code_rdata[31:24]) - 8'd1;
                                        ip_n = ip + 16'd1;
                                        state_n = S_XF_MUL;
                                    end else begin
                                        begin
                                            logic [9:0] tw, th, tx, ty;
                                            tx = clip_u(`E32_STI(sp - 9'd4) + ctx_tx, MW);
                                            ty = clip_u(`E32_STI(sp - 9'd3) + ctx_ty, MH);
                                            tw = clip_sz(`E32_STI(sp - 9'd2), tx, MW);
                                            th = clip_sz(`E32_STI(sp - 9'd1), ty, MH);
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
                                        ac = code_rdata[31:24];
                                        ot = `E32_STAG(sp - ac - 8'd1);
                                        oid = `E32_AT(sp - ac - 8'd1)[15:0];
                                        if (ot == 3'd1 && !cm_done) begin
                                            cm_scan_n = 1'b1;
                                            cm_armed_n = 1'b0;
                                            cm_done_n = 1'b0;
                                            cm_c_n = 4'd0;
                                            cm_m_n = 4'd0;
                                            cm_mip_n = 16'hFFFF;
                                            cm_key_n = code_rdata[23:8];
                                            cm_cls_n = obj_cls_rdata;
                                            state_n = S_EXEC;
                                        end else begin
                                        mip = cm_done ? cm_mip : 16'hFFFF;
                                        cm_done_n = 1'b0;
                                        if (mip != 16'hFFFF) begin
                                            for (int k = 0; k < 8; k++) begin
                                                if (k < ac) begin
                                                    begin stack_we = 1'b1; stack_waddr = sp - ac - 8'd1 + k[7:0]; stack_wdata = `E32_AT(sp - ac + 8'(k)); end
                                                    begin stack_tag_we = 1'b1; stack_tag_waddr = sp - ac - 8'd1 + k[7:0]; stack_tag_wdata = `E32_STAG(sp - ac + 8'(k)); end
                                                end
                                            end
                                            sp_n = sp - 8'd1;
                                            cstack_we = 1'b1; cstack_waddr = csp; cstack_ip_wdata = ip + 16'd1;
                                            cstack_we = 1'b1; cstack_waddr = csp; cstack_this_wdata = this_obj;
                                            cstack_we = 1'b1; cstack_waddr = csp; cstack_isctor_wdata = 1'b0;
                                            cstack_we = 1'b1; cstack_waddr = csp; cstack_isfe_wdata = 1'b0;
                                            cstack_we = 1'b1; cstack_waddr = csp; cstack_env_wdata = env_sp;
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
                                                hp_len_n = obj_n_rdata;
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
                                color_n = sat8(`E32_AT(sp - 8'd1));
                                sp_n = sp - 8'd1;
                            end else color_n = 8'd0;
                            clr_idx_n = '0;
                            state_n = S_CLEAR;
                        end
                        8'd2: begin
                            // fillRect(x,y,w,h,color) — native 640×480, clipped
                            color_n = sat8(`E32_AT(sp - 8'd1));
                            rx_n = clip_u(`E32_STI(sp - 9'd5), MW);
                            ry_n = clip_u(`E32_STI(sp - 9'd4), MH);
                            rw_n = clip_sz(`E32_STI(sp - 9'd3), clip_u(`E32_STI(sp - 9'd5), MW), MW);
                            rh_n = clip_sz(`E32_STI(sp - 9'd2), clip_u(`E32_STI(sp - 9'd4), MH), MH);
                            x_n = clip_u(`E32_STI(sp - 9'd5), MW);
                            y_n = clip_u(`E32_STI(sp - 9'd4), MH);
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
                            begin stack_we = 1'b1; stack_waddr = sp - 8'd1; stack_wdata = fxi(`E32_AT(sp - 8'd1), stack_tag_tos); end
                            begin stack_tag_we = 1'b1; stack_tag_waddr = sp - 8'd1; stack_tag_wdata = 3'd0; end
                            code_raddr_n = 15'(ops_base + ip);
                            state_n = S_FETCH_WAIT;
                        end
                        8'd11: begin // Math.abs — keeps fx tag (abs(0.5)=0.5)
                            stack_we = 1'b1; stack_waddr = sp - 8'd1; stack_wdata = `E32_AT(sp - 8'd1)[31] ?
                                -`E32_AT(sp - 8'd1) : `E32_AT(sp - 8'd1);
                            code_raddr_n = 15'(ops_base + ip);
                            state_n = S_FETCH_WAIT;
                        end
                        8'd12: begin // min — fx-aware compare, keep the winner's tag
                            if (fxlift(`E32_AT(sp - 8'd2), stack_tag_nos, stack_tag_tos == 3'd7)
                              < fxlift(`E32_AT(sp - 8'd1), stack_tag_tos, stack_tag_nos == 3'd7)) begin
                                begin stack_we = 1'b1; stack_waddr = sp - 8'd2; stack_wdata = `E32_AT(sp - 8'd2); end
                                begin stack_tag_we = 1'b1; stack_tag_waddr = sp - 8'd2; stack_tag_wdata = stack_tag_nos; end
                            end else begin
                                begin stack_we = 1'b1; stack_waddr = sp - 8'd2; stack_wdata = `E32_AT(sp - 8'd1); end
                                begin stack_tag_we = 1'b1; stack_tag_waddr = sp - 8'd2; stack_tag_wdata = stack_tag_tos; end
                            end
                            sp_n = sp - 8'd1;
                            code_raddr_n = 15'(ops_base + ip);
                            state_n = S_FETCH_WAIT;
                        end
                        8'd13: begin // max
                            if (fxlift(`E32_AT(sp - 8'd2), stack_tag_nos, stack_tag_tos == 3'd7)
                              > fxlift(`E32_AT(sp - 8'd1), stack_tag_tos, stack_tag_nos == 3'd7)) begin
                                begin stack_we = 1'b1; stack_waddr = sp - 8'd2; stack_wdata = `E32_AT(sp - 8'd2); end
                                begin stack_tag_we = 1'b1; stack_tag_waddr = sp - 8'd2; stack_tag_wdata = stack_tag_nos; end
                            end else begin
                                begin stack_we = 1'b1; stack_waddr = sp - 8'd2; stack_wdata = `E32_AT(sp - 8'd1); end
                                begin stack_tag_we = 1'b1; stack_tag_waddr = sp - 8'd2; stack_tag_wdata = stack_tag_tos; end
                            end
                            sp_n = sp - 8'd1;
                            code_raddr_n = 15'(ops_base + ip);
                            state_n = S_FETCH_WAIT;
                        end
                        8'd15: begin // NEW: Math.sqrt — bit-serial, Q16.16 in/out
                            begin
                                logic signed [31:0] v;
                                v = (stack_tag_tos == 3'd7)
                                    ? $signed(`E32_AT(sp - 8'd1))
                                    : ($signed(`E32_AT(sp - 8'd1)) <<< 16);
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
                            if (`E32_AT(sp - 8'd2)[15:0] == id_keydown)
                                add_key_listener(1'b1, `E32_AT(sp - 8'd1)[15:0]);
                            if (`E32_AT(sp - 8'd2)[15:0] == id_keyup)
                                add_key_listener(1'b0, `E32_AT(sp - 8'd1)[15:0]);
                            if (`E32_AT(sp - 8'd2)[15:0] == id_click && click_fn == 16'hFFFF)
                                click_fn_n = `E32_AT(sp - 8'd1)[15:0];
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
                                raf_we = 1'b1; raf_waddr = raf_n; raf_fn_wdata = `E32_AT(sp - nat_argc)[15:0];
                                raf_n_n = raf_n + 4'd1;
                                // NEW: rAF fn must survive the frame nursery
                                // rewind or PACMAN start() loop dies (raf=0)
                                commit_obj_keep(`E32_STAG(sp - nat_argc),
                                                `E32_AT(sp - nat_argc)[15:0]);
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
                                    ? fxi(`E32_AT(sp - nat_argc + 8'd1),
                                          `E32_STAG(sp - nat_argc + 8'd1))
                                    : 32'sd0;
                                if (ms < 0) ms = 32'sd0;
                                fr = (ms < 32'sd17) ? 12'd1 : 12'(ms / 32'sd17);
                                to_we = 1'b1; to_waddr = to_n[5:0]; to_fn_wdata = `E32_AT(sp - nat_argc)[15:0];
                                to_we = 1'b1; to_waddr = to_n[5:0]; to_delay_wdata = fr;
                                to_we = 1'b1; to_waddr = to_n[5:0]; to_period_wdata = (nat_id == 8'd29) ? fr : 12'd0;
                                to_we = 1'b1; to_waddr = to_n[5:0]; to_id_wdata = to_seq;
                                to_n_n = to_n + 7'd1;
                                to_seq_n = to_seq + 16'd1;
                                dbg_tmr_sched_n = dbg_tmr_sched + 16'd1;
                                commit_obj_keep(`E32_STAG(sp - nat_argc),
                                                `E32_AT(sp - nat_argc)[15:0]);
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
                                to_clr_go = 1'b1;
                                to_clr_want_n = `E32_AT(sp - nat_argc)[15:0];
                                state_n = S_NAT;
                            end else begin
                                code_raddr_n = 15'(ops_base + ip);
                                state_n = S_FETCH_WAIT;
                            end
                            begin stack_we = 1'b1; stack_waddr = sp - ((nat_argc == 0) ? 8'd0 : nat_argc[7:0]); stack_wdata = 32'sd0; end
                            begin stack_tag_we = 1'b1; stack_tag_waddr = sp - ((nat_argc == 0) ? 8'd0 : nat_argc[7:0]); stack_tag_wdata = 3'd5; end
                            sp_n = (nat_argc == 0) ? (sp + 8'd1) : (sp - nat_argc[7:0] + 8'd1);
                        end
                        8'd36, 8'd37: begin // removeEventListener
                            if (nat_argc >= 8'd2) begin
                                if (`E32_AT(sp - nat_argc)[15:0] == id_keydown)
                                    remove_key_listener(1'b1, `E32_AT(sp - nat_argc + 8'd1)[15:0]);
                                if (`E32_AT(sp - nat_argc)[15:0] == id_keyup)
                                    remove_key_listener(1'b0, `E32_AT(sp - nat_argc + 8'd1)[15:0]);
                            end
                            sp_n = (nat_argc == 0) ? sp : (sp - nat_argc[7:0]);
                            begin stack_we = 1'b1; stack_waddr = sp - ((nat_argc == 0) ? 8'd0 : nat_argc[7:0]); stack_wdata = 32'sd0; end
                            begin stack_tag_we = 1'b1; stack_tag_waddr = sp - ((nat_argc == 0) ? 8'd0 : nat_argc[7:0]); stack_tag_wdata = 3'd5; end
                            sp_n = (nat_argc == 0) ? (sp + 8'd1) : (sp - nat_argc[7:0] + 8'd1);
                            code_raddr_n = 15'(ops_base + ip);
                            state_n = S_FETCH_WAIT;
                        end
                        8'd38, 8'd39: begin // dispatchEvent — fire listeners now (PYTHON parity)
                            if (nat_argc >= 8'd1 && `E32_STAG(sp - nat_argc) == 3'd1
                                && kd_n != 3'd0 && kd_slot[0] != 16'hFFFF) begin
                                logic [15:0] oid;
                                oid = `E32_AT(sp - nat_argc)[15:0];
                                kev_obj_n = oid;
                                kev_fn_n = kd_slot[0];
                                kev_li_n = 2'd0;
                                kev_is_down_n = 1'b1;
                                kev_ret_ip_n = ip;  // OP_CALL already did ip+1
                                begin stack_we = 1'b1; stack_waddr = 0; stack_wdata = {16'd0, oid}; end
                                begin stack_tag_we = 1'b1; stack_tag_waddr = 0; stack_tag_wdata = 3'd1; end
                                boundary_sp(11'd1);
                                cstack_we = 1'b1; cstack_waddr = csp; cstack_ip_wdata = 16'hFFFD;
                                cstack_we = 1'b1; cstack_waddr = csp; cstack_this_wdata = this_obj;
                                cstack_we = 1'b1; cstack_waddr = csp; cstack_isctor_wdata = 1'b0;
                                cstack_we = 1'b1; cstack_waddr = csp; cstack_isfe_wdata = 1'b0;
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
                                `E32_STAG(sp - nat_argc) == 3'd1 &&
                                obj_cls_rdata == CLS_DYNSTR) begin
                                js_sp_n = 6'd0;
                                js_we = 1'b1; js_waddr = 5'd0; js_ph_wdata = 3'd0;
                                json_pph_n = 3'd0;
                                hp_cmd_n = HP_OGETI;
                                hp_v64_n = 1'b0;
                                hp_oid_n = `E32_AT(sp - nat_argc)[12:0];
                                hp_slot_n = 5'd0;
                                hp_qn_n = 3'd2;
                                hp_qi_n = 3'd0;
                                hp_nat_n = 4'd7;
                                hp_lim_n = 8'd0;
                                hp_ret_n = S_V64_OGETI_NAT;
                                sp_n = sp - nat_argc[7:0];
                                state_n = S_HEAP_WAIT;
                            end else if (nat_argc >= 8'd1 &&
                                         `E32_STAG(sp - nat_argc) == 3'd3) begin
                                // interned literal — copy name_mem into json_mem then parse
                                json_src_n = 14'd0;
                                json_srclen_n = {6'd0, name_len_tos};
                                json_rp_n = 14'd0;
                                js_sp_n = 6'd0;
                                js_we = 1'b1; js_waddr = 5'd0; js_ph_wdata = 3'd0;
                                json_pph_n = 3'd0;
                                sp_n = sp - nat_argc[7:0];
                                if (name_len_tos == 8'd0) begin
                                    begin stack_we = 1'b1; stack_waddr = 11'(sp - nat_argc[7:0]); stack_wdata = 32'sd0; end
                                    begin stack_tag_we = 1'b1; stack_tag_waddr = 11'(sp - nat_argc[7:0]); stack_tag_wdata = 3'd5; end
                                    sp_n = 11'(sp - nat_argc[7:0]) + 11'd1;
                                    code_raddr_n = 15'(ops_base + ip);
                                    state_n = S_FETCH_WAIT;
                                end else if (name_len_tos == 8'd1 &&
                                             !name_has_tos) begin
                                    begin json_mem_we = 1'b1; json_mem_waddr = 0; json_mem_wdata = name_hash_tos[7:0]; end
                                    state_n = S_JSON_PARSE;
                                end else begin
                                    name_rdaddr_n = name_off_tos;
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
                            js_we = 1'b1; js_waddr = 5'd0; js_tag_wdata = (nat_argc >= 8'd1) ? `E32_STAG(sp - nat_argc) : 3'd5;
                            js_we = 1'b1; js_waddr = 5'd0; js_val_wdata = (nat_argc >= 8'd1) ? `E32_AT(sp - nat_argc) : 32'sd0;
                            js_we = 1'b1; js_waddr = 5'd0; js_i_wdata = 8'd0;
                            js_we = 1'b1; js_waddr = 5'd0; js_ph_wdata = 3'd0;
                            sp_n = (nat_argc == 0) ? sp : (sp - nat_argc[7:0]);
                            state_n = S_JSON;
                        end
                        8'd34: begin // Array(n) — length n, holes undefined
                            begin
                                logic [7:0] aln;
                                aln = (nat_argc >= 8'd1) ?
                                    ((fxi(`E32_AT(sp - nat_argc), `E32_STAG(sp - nat_argc)) > ARR_CAP)
                                        ? ARR_CAP[7:0]
                                        : (fxi(`E32_AT(sp - nat_argc), `E32_STAG(sp - nat_argc)) < 0)
                                            ? 8'd0
                                            : 8'(fxi(`E32_AT(sp - nat_argc), `E32_STAG(sp - nat_argc))))
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
                                tt = (nat_argc >= 8'd1) ? `E32_STAG(sp - nat_argc) : 3'd5;
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
    `undef E32_STAG
    `undef E32_STFX
    `undef E32_STI
    `undef E32_TAG
    `undef E32_AT
    `undef E32_REL
endmodule
