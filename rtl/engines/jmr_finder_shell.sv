// Disk-program supervisor. Finder owns UI policy; the loader accepts typed
// services directly. No command strings, keyboard macros or settling timers.
module jmr_finder_shell(
 input logic clk,rst_n,enabled,ready,failed,accepted,
 input logic vm_busy,storage_busy,disk_busy,fs_busy,present_busy,
 input logic host_hold,host_started,host_started_finder,
 input logic home_stb,home_on,quit,
 input logic launch,
 input logic [95:0] launch_name,
 input logic [3:0] launch_len,launch_how,
 output logic request,
 output logic [95:0] request_name,
 output logic [3:0] request_len,request_how,
 output logic monitor_visible,
 // Finder-first: a program that exits or fails is not a reason to show the
 // text monitor. Tell the loader to drop its error reply and go back to Finder.
 output logic dismiss_failure,
 output logic busy,loading
);
 typedef enum logic [2:0] {BOOT,IDLE,WAIT_STOP,REQUEST,WATCH} st_t;
 st_t state;
 logic seen,finder_running;
 wire available=!host_hold && ready && !vm_busy && !storage_busy && !disk_busy && !fs_busy && !present_busy;
 assign request=state==REQUEST;
 assign loading=state==BOOT || state==WAIT_STOP || state==REQUEST || (state==WATCH && !seen);
 assign busy=loading;
 always_ff @(posedge clk)begin
  if(!rst_n)begin
   state<=BOOT;request_name<=0;request_len<=0;request_how<=8;
   monitor_visible<=0;seen<=0;finder_running<=0;dismiss_failure<=0;
  end else begin
   dismiss_failure<=0;
   case(state)
    BOOT:if(enabled && available)begin request_how<=8;state<=REQUEST;end
    IDLE:;
    WAIT_STOP:if(failed && !host_hold)dismiss_failure<=1; // outgoing program's exit status
    else if(available)begin
     seen<=0;
     if(request_how==4)begin monitor_visible<=1;state<=IDLE;end
     else begin monitor_visible<=0;state<=REQUEST;end
    end
    REQUEST:if(accepted)begin
     finder_running<=request_how==8;seen<=0;state<=WATCH;
    end
    WATCH:begin
     if(vm_busy)seen<=1;
     if(failed && !host_hold)begin
      // Only a failure of Finder itself leaves the read-only recovery display.
      if(finder_running)begin monitor_visible<=1;state<=IDLE;end
      else begin dismiss_failure<=1;request_how<=8;request_len<=0;seen<=0;state<=WAIT_STOP;end
     end
     else if(seen && available)begin
      if(finder_running)begin monitor_visible<=1;state<=IDLE;end
      else begin request_how<=8;request_len<=0;state<=REQUEST;seen<=0;end
     end
    end
    default:state<=IDLE;
   endcase
   if(host_started)begin
    monitor_visible<=0;finder_running<=host_started_finder;seen<=0;state<=WATCH;
   end
   if(home_stb)begin
    if(home_on)begin request_how<=8;request_len<=0;state<=WAIT_STOP;end
    else begin monitor_visible<=1;state<=IDLE;end
   end
   if(quit)begin request_how<=8;request_len<=0;state<=WAIT_STOP;end
   if(launch)begin
    request_name<=launch_name;request_len<=launch_len;request_how<=launch_how;
    state<=WAIT_STOP;
    // Existing sysRun mode/extension contract, normalized once at capture.
    if(launch_how==0 && !((launch_len>=4 && launch_name[(launch_len-4)*8+:32]==32'h4d54482e) ||
       (launch_len>=3 && launch_name[(launch_len-3)*8+:24]==24'h534a2e)))request_how<=2;
    if(launch_how==5)begin request_name<=96'h000000004d54482e45544f4e;request_len<=8;request_how<=0;end
    else if(launch_how==6)begin request_name<=96'h0000000000444d2e504c4548;request_len<=7;request_how<=2;end
    else if(launch_how==7)begin request_name<=96'h004d54482e5954494c495455;request_len<=11;request_how<=0;end
   end
  end
 end
endmodule
