`include "interface.sv"

module top();

bit done1;
bit done2;
bit done3;
bit clk = 0;
int mode,xyz;


// Interface instantiation
mips_interface iface();

// Updated module instances with interface passed
mips_lite_core dut1(clk, done1);
non_forwarding_pipeline dut2(clk, done2);
forwarding_pipeline dut3(done3); // or (clk, done3, iface) if clk is used



reg [4095:0] mem_data;

integer file_handler;

always #10 clk=~clk;

always@(posedge clk)
begin
    if(done1 && done2 && done3)
        $finish();
end

final
begin
    file_handler = $fopen("Solutions.txt", "w");
    if ($value$plusargs("MODE=%d", mode)) begin
        end
    if( mode==0 || mode==1|| mode==2 || mode==3) begin
    $fwrite(file_handler, "-----Instruction Count according to the Category--------------------\n");
    $fwrite(file_handler, "Program Counter                : %0d\n", dut1.pc_current);
    $fwrite(file_handler, "Total number of instructions   : %0d\n", dut1.instruction_exec_counter);
    $fwrite(file_handler, "Arithmetic instructions        : %0d\n", dut1.arith_ops);
    $fwrite(file_handler, "Logical instructions           : %0d\n", dut1.logic_ops);
    $fwrite(file_handler, "Memory Accessess               : %0d\n", dut1.mem_exec_counter);
    $fwrite(file_handler, "Control Transfer Instructions  : %0d\n", dut1.branch_ops+1); //count starting from 0
	$fwrite(file_handler,"---------------------------------------------------------------------\n");

    $fwrite(file_handler, "\n\n-----------Final Register and Memory State---------------\n");

    foreach(dut1.modified_regs[i])
    begin
        if(dut1.modified_regs[i]==1)
            $fwrite(file_handler, "R[%0d]        : %0d\n", i, dut1.gpr_file[i]);
    end
    $fwrite(file_handler, "\n\n-----------Final Memory State---------------\n");
    foreach(dut1.modified_mem[i])
    begin
        if(dut1.modified_mem[i]==1) begin

            $fwrite(file_handler, "Memory Address: %0d and Contents: %0d\n", i, {dut1.mem_array[i], dut1.mem_array[i+1],dut1.mem_array[i+2],dut1.mem_array[i+3] });
        end
    end
	$fwrite(file_handler,"----------------------------------------------------------------------\n");
 end
 
  if(mode==1 || mode==3) begin
	
    $fwrite(file_handler,"-----------------Timing Simulator:Non-Forwarding ---------------------\n");
    $fwrite(file_handler,"Total number of clock cycles: %0d\n", dut2.cycle_exec_counterer);
    $fwrite(file_handler,"Total Stalls : %0d\n", dut2.total_stall);
	  $fwrite(file_handler,"----------------------------------------------------------------------\n");
  end
    
  if(mode ==2 || mode==3) begin
    $fwrite(file_handler,"-------------------Timing Simulator:Forwarding------------------------\n");
    $fwrite(file_handler,"Total number of clock cycles: %0d\n", dut3.cycle_exec_counterer);
    $fwrite(file_handler,"Total Stalls : %0d\n", dut3.raw_stalls);
	  $fwrite(file_handler,"----------------------------------------------------------------------\n");
  end

	
    $fwrite(file_handler, "Program Halted");

    $fclose(file_handler);
end

endmodule






