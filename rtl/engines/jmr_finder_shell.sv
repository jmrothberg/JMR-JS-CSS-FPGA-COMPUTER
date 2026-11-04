// Small disk-program supervisor. All Finder drawing, sorting, folders, Trash
// and persistence belong to FINDER.JSH. This module only starts/returns apps.
module jmr_finder_shell(
 input logic clk,rst_n,enabled,ready,failed,keyboard_empty,keyboard_full,console_clear,
 input logic vm_busy,storage_busy,disk_busy,actions_busy,fs_busy,
 input logic home_stb,home_on,quit,
 input logic launch,
 input logic [95:0] launch_name,
 input logic [3:0] launch_len,launch_how,
 output logic key_push,output logic [7:0] key_data,
 output logic tool_start,tool_finder,
 output logic busy,loading
);
 typedef enum logic [3:0] {BOOT,IDLE,WAIT_STOP,SEND,WAIT_COMMAND,START_TOOL,WATCH} st_t;
 st_t state;
 logic [95:0] name;
 logic [3:0] n,how;
 logic [4:0] i;
 logic second,home,seen,finder_running,pending;
 logic [6:0] age;
 wire idle_console=ready && keyboard_empty && !console_clear && !storage_busy && !disk_busy && !actions_busy && !fs_busy;
 assign loading=state==BOOT || (tool_finder && (state==START_TOOL || (state==WATCH && !seen)));
 assign busy=(state!=IDLE && state!=WATCH) || loading;
 function automatic logic [7:0] command_char(input logic [4:0] at);
  if(!second)begin
   if(at<6)case(at)0:command_char="L";1:command_char="O";2:command_char="A";3:command_char="D";4:command_char=32;default:command_char=34;endcase
   else if(at<6+{1'b0,n})command_char=name[(at-6)*8+:8];
   else command_char=at==6+{1'b0,n}?34:13;
  end else if(how==1)case(at)0:command_char="E";1:command_char="D";2:command_char="I";3:command_char="T";default:command_char=13;endcase
  else if(how==2)case(at)0:command_char="R";1:command_char="E";2:command_char="A";3:command_char="D";default:command_char=13;endcase
  else case(at)0:command_char="R";1:command_char="U";2:command_char="N";default:command_char=13;endcase
 endfunction
 always_ff @(posedge clk)begin
  if(!rst_n)begin state<=BOOT;name<=0;n<=0;how<=0;i<=0;second<=0;home<=1;seen<=0;finder_running<=0;pending<=0;age<=0;key_push<=0;key_data<=0;tool_start<=0;tool_finder<=1;end
  else begin
   key_push<=0;tool_start<=0;
   case(state)
    BOOT:if(enabled && idle_console && !vm_busy)begin tool_finder<=1;state<=START_TOOL;end
    IDLE:;
    WAIT_STOP:if(!vm_busy && idle_console)begin
     pending<=0;finder_running<=0;seen<=0;age<=0;i<=0;second<=0;
     if(how==4)begin home<=0;state<=IDLE;end
     else if(how==8 || n==0)begin tool_finder<=1;state<=START_TOOL;end
     else begin home<=1;state<=SEND;end
    end
    SEND:if(idle_console && !keyboard_full)begin
     key_push<=1;key_data<=command_char(i);age<=0;
     if(command_char(i)==13)begin i<=0;state<=WAIT_COMMAND;end else i<=i+1'b1;
    end
    WAIT_COMMAND:begin
     if(second && vm_busy)begin seen<=1;state<=WATCH;end
     else if(idle_console)begin
      if(age==100)begin
       age<=0;
       if(failed)begin home<=0;state<=IDLE;end
       else if(!second)begin
        if(how==3)begin tool_finder<=0;state<=START_TOOL;end
        else begin second<=1;i<=0;state<=SEND;end
       end else begin seen<=1;state<=WATCH;end
      end else age<=age+1'b1;
     end else age<=0;
    end
    START_TOOL:if(idle_console && !vm_busy)begin
     tool_start<=1;finder_running<=tool_finder;home<=1;seen<=0;age<=0;state<=WATCH;
    end
    WATCH:begin
     if(vm_busy)seen<=1;
     // A missing/bad system image never starts the VM. Once the loader
     // returns to its prompt, dismiss the splash and expose recovery tools.
     if(!seen && !vm_busy && idle_console)begin
      if(age==100)begin home<=0;state<=IDLE;end
      else age<=age+1'b1;
     end else age<=0;
     if(seen && !vm_busy && idle_console && !pending)begin
      if(home && !finder_running)begin tool_finder<=1;state<=START_TOOL;end
      else begin home<=0;state<=IDLE;end // failed/exited Finder: leave usable Terminal
     end
    end
    default:state<=IDLE;
   endcase
   // Native menu actions own their lifecycle until they explicitly show Home.
   if(home_stb)begin
    if(home_on)begin how<=8;n<=0;pending<=1;state<=WAIT_STOP;end
    else begin home<=0;state<=IDLE;end
   end
   if(quit)begin how<=8;n<=0;pending<=1;state<=WAIT_STOP;end
   if(launch)begin
    name<=launch_name;n<=launch_len;how<=launch_how;pending<=1;state<=WAIT_STOP;
    // Mode 0 uses the on-disk extension, not an application-name list.
    if(launch_how==0 && !((launch_len>=4 && launch_name[(launch_len-4)*8+:32]==32'h4d54482e) ||
       (launch_len>=3 && launch_name[(launch_len-3)*8+:24]==24'h534a2e)))how<=2;
    // Existing system actions create Note and stage Utility's catalog.
    // They own the console until they return Home, avoiding two launchers.
    if(launch_how>=5 && launch_how<=7)begin home<=0;pending<=0;state<=IDLE;end
   end
  end
 end
endmodule
