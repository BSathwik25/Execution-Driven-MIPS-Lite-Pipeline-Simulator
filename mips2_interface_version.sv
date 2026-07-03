`include "interface.sv"
module mips_lite_core(input bit clk, output bit done);

mips_interface iface();

bit signed  [31:0]gpr_file[32];
bit signed  [7:0]mem_array[4096];
bit signed  [31:0]pc_current; 

int exec_counter;
int cycle_exec_counterer;
int instruction_exec_counter;
int arith_ops;        
int logic_ops;           
int branch_ops;          
int taken_branches;
int mem_exec_counter;         

int modified_regs[32];
int modified_mem[4096];
bit  signed [31:0]Instruction; 
bit  [5:0]opcode;
bit  [4:0]rs_add;
bit  [4:0]rt_add;
bit  [4:0]rd_add;
bit signed  [31:0]Rs;
bit signed  [31:0]Rt;
bit signed  [31:0]Rd;
bit signed  [16:0]imm;
bit signed  [31:0]result;
bit  [31:0]ld_add; 
bit  [31:0]st_add; 
bit signed  [31:0]load_data;
bit  signed [31:0]pc_value;
bit signed [31:0]x_inst; 

int fd; 
int i;
string input_file;

initial begin : file_block
	if ($value$plusargs("INPUT=%s", input_file)) begin
		file_operation();
	end 
	else begin
		input_file = "final_proj_trace.txt"; //default file
		file_operation();
	end
	
end : file_block

task automatic file_operation();
	fd = $fopen (input_file, "r");  
		if(fd ==0)
			disable file_block; 
		i=0;
		while (!($feof(fd))) begin
			$fscanf(fd, "%32h",{mem_array[i], mem_array[i+1], mem_array[i+2], mem_array[i+3]});
			i=i+4;
		end
		$fclose(fd);
endtask


always@(posedge clk)
begin
	if(done==0)
	begin
		stage_fetch();
		stage_decode();
		stage_execute();
		stage_mem_array();
		stage_write_back();
	end
end

function void stage_fetch();
	begin	         
    Instruction = {mem_array[pc_current], mem_array[pc_current+1], mem_array[pc_current+2], mem_array[pc_current+3]};
    pc_current = pc_current + 4;
	end
endfunction
            
function void stage_decode( );

    opcode = Instruction[31:26];                      
    if ((opcode == iface.ADD) || (opcode == iface.SUB) || (opcode == iface.MUL) || (opcode == iface.OR) || (opcode == iface.AND) || (opcode == iface.XOR))
    begin       
        rs_add     = Instruction[25:21];
        rt_add     = Instruction[20:16];
        rd_add     = Instruction[15:11];
        Rs         = $signed(gpr_file[rs_add]);
        Rt         = $signed(gpr_file[rt_add]);
        Rd         = $signed(gpr_file[rd_add]);                               
    end
                         
    else if ((opcode == iface.ADDI) || (opcode ==iface.SUBI) || (opcode == iface.MULI) || (opcode == iface.ORI) || (opcode == iface.ANDI) || ( opcode == iface.XORI) || (opcode == iface.LW) || (opcode == iface.SW))                       
    begin                                     
        imm        = $signed(Instruction[15:0]);
        rs_add     = Instruction[25:21];
        rt_add     = Instruction[20:16];
        Rs         = $signed(gpr_file[rs_add]);
        Rt         = $signed(gpr_file[rt_add]);
    end
                         
    else if ((opcode == iface.BZ))
    begin
        rs_add     = Instruction[25:21];
        x_inst     = $signed(Instruction[15:0]);
        Rs         = $signed(gpr_file[rs_add]);
    end
                         
    else if (opcode == iface.BEQ)                      
    begin
        rs_add     = Instruction[25:21];
        rt_add     = Instruction[20:16];
        x_inst   = $signed(Instruction[15:0]);	                                        	                                  
        Rs       = $signed(gpr_file[rs_add]);
        Rt       = $signed(gpr_file[rt_add]);
    end
                         
    else if (opcode == iface.JR)                         
    begin
        rs_add     = Instruction[25:21];                          
        Rs         = $signed(gpr_file[rs_add]);
    end
    
	else
    begin
        Rd         = 0;
        Rs         = 0;
        Rt         = 0;
        rd_add     = 0;
        rs_add     = 0;
        rt_add     = 0;
	end
	
    modified_regs[rs_add]=1;
    modified_regs[rt_add]=1;
    modified_regs[rd_add]=1;
	
endfunction

function void stage_execute();
    case(opcode)
                        
    iface.ADD    : result = Rs + Rt;
    iface.ADDI   : result = Rs + imm;                           
    iface.SUB    : result = Rs - Rt;                           	     
    iface.SUBI   : result = Rs - imm;                           
    iface.MUL    : result = Rs * Rt;                           
    iface.MULI   : result = Rs * imm;                           
    iface.OR     : result = Rs | Rt;                           
	  iface.ORI    : result = Rs | imm;                           
    iface.AND    : result = Rs & Rt;                           
    iface.ANDI   : result = Rs & imm;                        
    iface.OR    : result = Rs ^ Rt;                           
    iface.ORI   : result = Rs ^ imm;                           
    iface.LW     : begin
				ld_add = Rs + imm;
				mem_exec_counter += 1;
 			end                           
    iface.SW     :begin
                st_add = Rs + imm;
                mem_exec_counter += 1;
                modified_mem[st_add]=1; 
            end
    iface.BZ     :begin
				branch_ops += 1;                     
                if(Rs == 0)begin
					taken_branches += 1;                                  
                    pc_current <= (x_inst * 4 )+  pc_current - 4; 
				end
            end                           
    iface.BEQ  :begin
				branch_ops += 1;                                  
                if( Rs == Rt)begin                                       
                    pc_current <= (x_inst * 4) + pc_current - 4;
					taken_branches += 1;
				end                           
            end                           
    iface.JR 	   :begin
                pc_current <= Rs;
				branch_ops += 1;
				taken_branches += 1;
			end                                                  
    endcase

 endfunction

function void stage_mem_array();         
    case(opcode)                           
		iface.LW: load_data = $signed({mem_array[ld_add],mem_array[ld_add+1], mem_array[ld_add+2], mem_array[ld_add+3]});                          
        iface.SW: {mem_array[st_add],mem_array[st_add+1], mem_array[st_add+2], mem_array[st_add+3]} = $signed(Rt);                           
    endcase
endfunction

function void stage_write_back();
    instruction_exec_counter += 1;                                
    case(opcode)                            
        iface.ADD : begin                           
				gpr_file[rd_add] = result;
                arith_ops += 1;                              
              end                 
        iface.ADDI: begin                           
                gpr_file[rt_add] = result;
                arith_ops += 1;                              
              end                   
        iface.SUB:  begin                           
                gpr_file[rd_add] = result;                           	     
                arith_ops += 1;                              
              end                   
        iface.SUBI: begin                           
                gpr_file[rt_add] = result;                           	      
                arith_ops += 1;                              
              end               
        iface.MUL: begin                           
                gpr_file[rd_add] = result;                           
                arith_ops += 1;                              
           	  end                   
        iface.MULI: begin                           
				gpr_file[rt_add] = result;                           
                arith_ops += 1;                              
              end
        iface.OR:   begin                           
                gpr_file[rd_add] = result; 
                logic_ops += 1;                          	       
              end                                              
        iface.ORI:  begin                           
                gpr_file[rt_add] = result;                           
                logic_ops += 1;                          	       
              end             
        iface.AND:  begin                           
                gpr_file[rd_add] = result;                           	   
                logic_ops += 1;                          	       
			  end                        
        iface.ANDI: begin                                 
                gpr_file[rt_add] = result;
                logic_ops += 1;                          	       
        	  end			  
        iface.XOR:  begin                      
                gpr_file[rd_add] = result;                           
                logic_ops += 1;                          	       
              end               
        iface.XORI: begin                           
                gpr_file[rt_add] =result;                           	   
                logic_ops += 1;                           	       
		      end                   
        iface.LW :  begin                           
                gpr_file[rt_add] = load_data;                           
              end                                        
        iface.HALT: done <= 1;                                                                     
    endcase 
	
 endfunction

always@(posedge clk)
begin
if(done == 0)
  cycle_exec_counterer += 1;
end

endmodule

module non_forwarding_pipeline(input clk, output bit done);

mips_interface iface();

bit signed [31:0] gpr_file[32];
bit signed [7:0]mem_array[4096];
bit signed [31:0]pc_current;

int exec_counter;
int cycle_exec_counterer;
int raw_stalls;
int instruction_exec_counter;
bit taken_branches;
int branch_exec_counter ;
int hit;
int single_stalls;
int double_stalls;
bit temp;

struct{
		bit [31:0]Instruction;
		bit [5:0]opcode;
		bit [4:0]rs_add;
		bit [4:0]rt_add; 
		bit [4:0]rd_add; 
		bit signed[31:0]Rs;
		bit signed[31:0]Rt;
		bit signed[31:0]Rd;
		bit signed[16:0]imm;
		bit signed[31:0]result;
		bit [31:0]ld_add; 
		bit [31:0]st_add;	
		bit signed[31:0]load_data;
		bit signed[31:0]pc_value;
		int signed source_reg1;
		int signed source_reg2;
		int signed dest_reg;
		bit signed [31:0]x_inst;
} instruction_line[5];
  
bit [3:0] instruction_stage[5];

int decode_stall;
bit decode_wait;
bit fetch_wait;
int total_stall;

int fd;
int i;
string input_file;

initial begin : file_block
	if ($value$plusargs("INPUT=%s", input_file)) begin
		file_operation();
	end 
	else begin
		input_file = "final_proj_trace.txt"; //default file
		file_operation();
	end
	
end : file_block

task automatic file_operation();
	fd = $fopen (input_file, "r");  
		if(fd ==0)
			disable file_block; 
		i=0;
		while (!($feof(fd))) begin
			$fscanf(fd, "%32h",{mem_array[i], mem_array[i+1], mem_array[i+2], mem_array[i+3]});
			i=i+4;
		end
		$fclose(fd);
endtask







always@(posedge clk) begin
  if(done == 0)
  begin
	  if(fetch_wait == 0) 
	  begin
		  for(int i=0; i<5; i++)
      begin
            if(instruction_stage[i]==0)
            begin		         
                instruction_stage[i] <=1;
                instruction_line[i].Instruction ={mem_array[pc_current], mem_array[pc_current+1], mem_array[pc_current+2], mem_array[pc_current+3] }  ;
                instruction_line[i].pc_value     = pc_current;
                pc_current = pc_current + 4;
                break;
            end
        end
    end
  end
end


always@(posedge clk)begin
if(done==0)
begin
#0;
	for(int i=0; i<5; i++)
    begin
        if(instruction_stage[i]==4'd1)      
        begin
            stage_decode(i) ;                            
            decode_stall = check_decode_stall(i);
            if(decode_stall == 2)
                double_stalls += 1;
            if(decode_stall == 1)
                single_stalls += 1;
            decode_wait =0; 
            if(decode_stall!=0)
            begin
                raw_stalls += 1;
                repeat(decode_stall)
                begin
                    decode_wait<=1; 
                    fetch_wait <=1;
                    @(posedge clk);
					fetch_wait<=0;
                end
                stage_decode(i) ; 
                decode_wait <= 0;
            end
            instruction_stage[i]<=2;                         
            break;
        end
    end
end
end

task stage_decode(int i);

    instruction_line[i].opcode = instruction_line[i].Instruction[31:26];                      
    if ((instruction_line[i].opcode == iface.ADD) || (instruction_line[i].opcode == iface.SUB) ||   (instruction_line[i].opcode == iface.MUL) || (instruction_line[i].opcode == iface.OR) ||(instruction_line[i].opcode == iface.AND) ||(instruction_line[i].opcode == iface.XOR))                     
    begin       
        instruction_line[i].rs_add      = instruction_line[i].Instruction[25:21];
        instruction_line[i].rt_add      = instruction_line[i].Instruction[20:16];
        instruction_line[i].rd_add      = instruction_line[i].Instruction[15:11];
        instruction_line[i].source_reg1 = instruction_line[i].rs_add;
        instruction_line[i].source_reg2 = instruction_line[i].rt_add;
        instruction_line[i].dest_reg    = instruction_line[i].rd_add;
        instruction_line[i].Rs          = $signed(gpr_file[instruction_line[i].rs_add ]);
        instruction_line[i].Rt          = $signed(gpr_file[instruction_line[i].rt_add]);
        instruction_line[i].Rd          = $signed(gpr_file[instruction_line[i].rd_add]);
    end
                                                        	                          
    else if ((instruction_line[i].opcode == iface.ADDI) ||(instruction_line[i].opcode == iface.SUBI) ||(instruction_line[i].opcode == iface.MULI) ||(instruction_line[i].opcode == iface.ORI) ||(instruction_line[i].opcode == iface.ANDI) ||(instruction_line[i].opcode == iface.XORI) || (instruction_line[i].opcode == iface.LW) || (instruction_line[i].opcode == iface.SW))                     
    begin                                     
        instruction_line[i].imm         = $signed(instruction_line[i].Instruction[15:0]);
        instruction_line[i].rs_add      = instruction_line[i].Instruction[25:21];
        instruction_line[i].rt_add      = instruction_line[i].Instruction[20:16];
        instruction_line[i].source_reg1 = instruction_line[i].rs_add;
        instruction_line[i].dest_reg    = instruction_line[i].rt_add;
        instruction_line[i].source_reg2 = 32'hffff;
        instruction_line[i].Rs          = $signed(gpr_file[instruction_line[i].rs_add]);
        instruction_line[i].Rt          = $signed(gpr_file[instruction_line[i].rt_add]);
    end
                         
    else if ((instruction_line[i].opcode == iface.BZ))                      
    begin
        instruction_line[i].rs_add      = instruction_line[i].Instruction[25:21];
        instruction_line[i].x_inst      = $signed(instruction_line[i].Instruction[15:0]);
        instruction_line[i].Rs          = $signed(gpr_file[instruction_line[i].rs_add]);
        instruction_line[i].source_reg1 = instruction_line[i].rs_add;
        instruction_line[i].dest_reg    = 32'hffff;
        instruction_line[i].source_reg2 = 32'hffff;
    end
                         
    else if ((instruction_line[i].opcode == iface.BEQ))                      
    begin
        instruction_line[i].rs_add      = instruction_line[i].Instruction[25:21];
        instruction_line[i].rt_add      = instruction_line[i].Instruction[20:16];
        instruction_line[i].x_inst      = $signed(instruction_line[i].Instruction[15:0]);	                  
        instruction_line[i].source_reg1 = instruction_line[i].rs_add;
        instruction_line[i].source_reg2 = instruction_line[i].rt_add;
        instruction_line[i].dest_reg    = 32'hffff;           
        instruction_line[i].Rs          = $signed( gpr_file[instruction_line[i].rs_add]);
        instruction_line[i].Rt          = $signed(gpr_file[instruction_line[i].rt_add]);
    end
                         
    else if ((instruction_line[i].opcode == iface.JR))                      
    begin
        instruction_line[i].rs_add     = instruction_line[i].Instruction[25:21];                          
        instruction_line[i].Rs         = $signed(gpr_file[instruction_line[i].rs_add]);
        instruction_line[i].source_reg1 = instruction_line[i].rs_add;
        instruction_line[i].dest_reg    = 32'hffff;
        instruction_line[i].source_reg2  = 32'hffff;
    end
    
	else begin
        instruction_line[i].Rd         = 0;
        instruction_line[i].Rs         = 0;
        instruction_line[i].Rt         = 0;
        instruction_line[i].rd_add     = 0;
        instruction_line[i].rs_add     = 0;
        instruction_line[i].rt_add     = 0;
        instruction_line[i].source_reg1 =  32'hffff;
        instruction_line[i].dest_reg    = 32'hffff;
        instruction_line[i].source_reg2  = 32'hffff;
	end
	
endtask


function int check_decode_stall(int add);
	hit=0;
	for(int i=0; i<5; i++)
    begin
        if(((instruction_line[add].source_reg1== instruction_line[i].dest_reg) || ( instruction_line[add].source_reg2== instruction_line[i].dest_reg)) && (instruction_line[i].dest_reg != 32'hffff ) && instruction_stage[i]==4'd2 && taken_branches == 0 && temp == 0) 
         begin
			   hit=1; 
			   break;
		   end                       
    end
          
	for(int i=0; i<5; i++)  
    begin                                                                                     
		if (((instruction_line[add].source_reg1== instruction_line[i].dest_reg) || ( instruction_line[add].source_reg2== instruction_line[i].dest_reg)) && ( instruction_line[i].dest_reg != 32'hffff )  && instruction_stage[i]==4'd3 && hit !=1 &&  taken_branches == 0 && temp == 0) 
        begin
            hit=2; 
            break;
        end    
    end

    if(hit==0)  return 0;
    else if (hit == 1) return 2;
    else if (hit == 2) return 1 ;

 endfunction


always@(posedge clk)begin
  if(done == 0)
  begin
    for(i=0; i<5; i++)
    begin         
        if(instruction_stage[i]==4'd2)
        begin
            instruction_stage[i] <= 3;               
            if(taken_branches == 0 )
            begin   
            case(instruction_line[i].opcode)
                        
				        iface.ADD    : instruction_line[i].result = instruction_line[i].Rs + instruction_line[i].Rt;
		            iface.ADDI   : instruction_line[i].result = instruction_line[i].Rs + instruction_line[i].imm;                           
				        iface.SUB    : instruction_line[i].result = instruction_line[i].Rs - instruction_line[i].Rt;                           	     
				        iface.SUBI   : instruction_line[i].result = instruction_line[i].Rs - instruction_line[i].imm;                           
				        iface.MUL    : instruction_line[i].result = instruction_line[i].Rs * instruction_line[i].Rt;                           
				        iface.MULI   : instruction_line[i].result = instruction_line[i].Rs * instruction_line[i].imm;                           
				        iface.OR     : instruction_line[i].result = instruction_line[i].Rs | instruction_line[i].Rt;                           
				        iface.ORI    : instruction_line[i].result = instruction_line[i].Rs | instruction_line[i].imm;                           
		            iface.AND    : instruction_line[i].result = instruction_line[i].Rs & instruction_line[i].Rt;                           
				        iface.ANDI   : instruction_line[i].result = instruction_line[i].Rs & instruction_line[i].imm;                        
				        iface.XOR    : instruction_line[i].result = instruction_line[i].Rs ^ instruction_line[i].Rt;                           
				        iface.XORI   : instruction_line[i].result = instruction_line[i].Rs ^ instruction_line[i].imm;
                iface.LW	   : instruction_line[i].ld_add=instruction_line[i].Rs+instruction_line[i].imm;                                      
                iface.SW	   : instruction_line[i].st_add= instruction_line[i].Rs+instruction_line[i].imm;                                      
                iface.BZ     : begin
                                 if(instruction_line[i].Rs==0)  begin    
                                    pc_current <= (instruction_line[i].x_inst*4 )+instruction_line[i].pc_value;
							                      taken_branches <= 1;
							                      temp=1;
					                          branch_exec_counter += 1;
							                    end
                               end           
                iface.BEQ    : begin
                                  if(instruction_line[i].Rs==instruction_line[i].Rt) begin
							                      pc_current <= (instruction_line[i].x_inst*4) +instruction_line[i].pc_value ;
					                          taken_branches <= 1;
					                          temp = 1;
					                          branch_exec_counter += 1;
                                  end
                               end                           
                iface.JR     : begin
                                  pc_current <= instruction_line[i].Rs;
                                  taken_branches <= 1;
							                    temp=1;
					                        branch_exec_counter += 1;
                               end                           
            endcase
            end
        
		    else   
        begin                   
          instruction_line[i].opcode=6'd22; 
          exec_counter += 1;             
          if(exec_counter > 1)
          begin
                exec_counter = 0;
                taken_branches <= 0; 
                temp=0;             
          end
        end
                           
    break;
    end                                       
  end               
 end
end

always@(posedge clk)begin
  if(done==0)
  begin
      for(i=0; i<5; i++)
          begin

            if(instruction_stage[i]==4'd3)

                       begin

                         instruction_stage[i]<=4;

                        case(instruction_line[i].opcode)
                                                                              
                           iface.LW : begin
                           
                             instruction_line[i].load_data= {mem_array[instruction_line[i].ld_add],mem_array[instruction_line[i].ld_add+1], mem_array[instruction_line[i].ld_add+2], mem_array[instruction_line[i].ld_add+3]};
                           
                           	   end
                           
                           iface.SW: begin
                             {mem_array[instruction_line[i].st_add],mem_array[instruction_line[i].st_add+1], mem_array[instruction_line[i].st_add+2], mem_array[instruction_line[i].st_add+3]}=instruction_line[i].Rt;
                           
                           	   end
                        
                           endcase
                           
                           break;
                      
                       end
         end
  end
end

always@(posedge clk)

  begin
if(done==0)
begin
      for(i=0; i<5; i++)

          begin

            if(instruction_stage[i]==4'd4)

                       begin
                         if(instruction_line[i].opcode <= 6'd18)
                         instruction_exec_counter =instruction_exec_counter+1;  
      
                         instruction_stage[i]<=0;
                         
                         case(instruction_line[i].opcode) 
                           
                           iface.ADD :   begin  gpr_file[instruction_line[i].rd_add] = instruction_line[i].result;  end
                                                        
                           iface.ADDI: begin   gpr_file[instruction_line[i].rt_add] = instruction_line[i].result; end
                                                     
                           iface.SUB:     gpr_file[instruction_line[i].rd_add] = instruction_line[i].result;                 
                           
                           iface.SUBI:   gpr_file[instruction_line[i].rt_add] = instruction_line[i].result;
                           	                                
                           iface.MUL:     gpr_file[instruction_line[i].rd_add] = instruction_line[i].result;                                                
                           
                           iface.MULI:   gpr_file[instruction_line[i].rt_add] = instruction_line[i].result;
                                                      
                           iface.OR:      gpr_file[instruction_line[i].rd_add] = instruction_line[i].result;
                           	                            
                           iface.ORI:    gpr_file[instruction_line[i].rt_add] = instruction_line[i].result;
                                                      
                           iface.AND:     gpr_file[instruction_line[i].rd_add] = instruction_line[i].result;
                           	                            
                           iface.ANDI:   gpr_file[instruction_line[i].rt_add] = instruction_line[i].result;
                           	                                
                           iface.XOR:     gpr_file[instruction_line[i].rd_add] = instruction_line[i].result;
                                                      
                           iface.XORI:   gpr_file[instruction_line[i].rt_add] = instruction_line[i].result;
                           	                              
                           iface.LW :   gpr_file[instruction_line[i].rt_add] = instruction_line[i].load_data;
                                                                               
                           iface.HALT:    begin done<=1;  end
                                                     	               
                           endcase
                           
                           break;                       
                       end
         end
  end
end

always@(posedge clk)
begin
if(done==0)
cycle_exec_counterer += 1;

if(decode_wait)
total_stall += 1;

end


endmodule

module forwarding_pipeline(output bit done);

mips_interface iface();

parameter  add_i=6'd0;
parameter  add_imm=6'd1;
parameter  sub_i=6'd2;
parameter  sub_imm=6'd3;
parameter  mul_i=6'd4;
parameter  mul_imm=6'd5;
parameter  or_i=6'd6;
parameter  or_imm=6'd7;
parameter  and_i=6'd8;
parameter  and_imm=6'd9;
parameter  xor_i=6'd10;
parameter  xor_imm=6'd11;
parameter  load_i=6'd12;
parameter  store_i=6'd13;
parameter  bz_i=6'd14;
parameter  beq_i=6'd15;
parameter  jr_i=6'd16;
parameter  halt_i=6'd17;

bit signed [31:0]gpr_file[32];
bit signed [31:0]reg_updated[32];
bit signed [7:0]mem_array[4096];
bit signed [31:0]pc;
int fd;
int exec_counter;
int cycle_exec_counterer;
int raw_stalls;
int instruction_exec_counter;
bit taken_branches;
int branch_exec_counter ;
int hit;

struct             {

  bit [31:0]Ir;
  bit [5:0]opcode;
  bit [4:0]rs_add;
  bit [4:0]rt_add;
  bit [4:0]rd_add;
  bit signed [31:0]Rs;
  bit signed [31:0]Rt;
  bit signed [31:0]Rd;
  bit signed [16:0]imm;
  bit signed [31:0]result;
  bit [31:0]ld_add;
  bit [31:0]st_add;
  bit signed [31:0]load_data;
  bit signed [31:0]pc_value;
  int signed source_reg1;
  int signed source_reg2;
  int signed dest_reg;
  bit signed [31:0]x_inst; } instruction_line[5];
bit [3:0] instrcution_stage[5];
int i=0;
int decode_stall;
bit fetch_wait;
string input_file;



initial begin : file_block
	if ($value$plusargs("INPUT=%s", input_file)) begin
		file_operation();
	end 
	else begin
		input_file = "final_proj_trace.txt"; //default file
		file_operation();
	end
	
end : file_block

task automatic file_operation();
	fd = $fopen (input_file, "r");  
		if(fd ==0)
			disable file_block; 
		i=0;
		while (!($feof(fd))) begin
			$fscanf(fd, "%32h",{mem_array[i], mem_array[i+1], mem_array[i+2], mem_array[i+3]});
			i=i+4;
		end
		$fclose(fd);
endtask





bit clk=0;

always 
begin

#10 clk=~clk;

end

always@(posedge clk)

 begin
if(done==0)
begin
 if(fetch_wait==0) 
   begin
   for(int i=0; i<5; i++)

          begin

            if(instrcution_stage[i]==0 )

                       begin		         
                         instrcution_stage[i] <=1;
                         instruction_line[i].Ir ={mem_array[pc], mem_array[pc+1], mem_array[pc+2], mem_array[pc+3] }  ;
                         instruction_line[i].pc_value     = pc;
                         pc=pc+4;
                         break;
                       end
            end
    end
 end
end

always@(posedge clk)

 begin
if(done==0)
begin
#0;
   for(int i=0; i<5; i++)

          begin
            if(instrcution_stage[i]==4'd1)
           
                       begin
                          stage_decode(i) ;                            
                          decode_stall = check_decode_stall(i);
                          if(decode_stall==1)
                            begin
                          raw_stalls=raw_stalls+1;
                           fetch_wait <=1;
                            @(posedge clk);
                            fetch_wait<=0;
                           stage_decode(i) ; 
                             end
                          instrcution_stage[i]<=2;                         
                       break;
		       end
           end
 end
end
task stage_decode(int i);

     instruction_line[i].opcode = instruction_line[i].Ir[31:26];

                       
                         if ( (instruction_line[i].opcode==add_i) || (instruction_line[i].opcode==sub_i) ||   (instruction_line[i].opcode==mul_i) || (instruction_line[i].opcode==or_i) ||(instruction_line[i].opcode==and_i) ||(instruction_line[i].opcode==xor_i))
                         
                                    begin       
                                      instruction_line[i].rs_add     = instruction_line[i].Ir[25:21];
                                      instruction_line[i].rt_add     = instruction_line[i].Ir[20:16];
                                      instruction_line[i].rd_add     = instruction_line[i].Ir[15:11];
                                      instruction_line[i].source_reg1 = instruction_line[i].Ir[25:21];
                                      instruction_line[i].source_reg2     = instruction_line[i].Ir[20:16];
                                      instruction_line[i].dest_reg     = instruction_line[i].Ir[15:11];
                                      instruction_line[i].Rs         = $signed(gpr_file[instruction_line[i].Ir[25:21]]);
                                      instruction_line[i].Rt         = $signed(gpr_file[instruction_line[i].Ir[20:16]]);
                                      instruction_line[i].Rd         = $signed(gpr_file[instruction_line[i].Ir[15:11]]);
                                    end
                                                        	                          
                         else if ((instruction_line[i].opcode==add_imm) ||(instruction_line[i].opcode==sub_imm) ||(instruction_line[i].opcode==mul_imm) ||(instruction_line[i].opcode==or_imm) ||(instruction_line[i].opcode==and_imm) ||(instruction_line[i].opcode==xor_imm) || (instruction_line[i].opcode==load_i) || (instruction_line[i].opcode==store_i))
                         
                                    begin                                     
                                      instruction_line[i].imm        = $signed(instruction_line[i].Ir[15:0]);
                                      instruction_line[i].rs_add     = instruction_line[i].Ir[25:21];
                                      instruction_line[i].rt_add     = instruction_line[i].Ir[20:16];
                                      instruction_line[i].source_reg1 = instruction_line[i].Ir[25:21];
                                      instruction_line[i].dest_reg     = instruction_line[i].Ir[20:16];
                                      instruction_line[i].source_reg2  = 32'hffff;
                                      instruction_line[i].Rs         = $signed(gpr_file[instruction_line[i].Ir[25:21]]);
                                      instruction_line[i].Rt         = $signed(gpr_file[instruction_line[i].Ir[20:16]]);
                                    end
                         
                         else if ((instruction_line[i].opcode== bz_i))
                          
                                     begin
                                       instruction_line[i].rs_add     = instruction_line[i].Ir[25:21];
                                       instruction_line[i].x_inst     = $signed(instruction_line[i].Ir[15:0]);
                                       instruction_line[i].Rs         = $signed(gpr_file[instruction_line[i].Ir[25:21]]);
                                       instruction_line[i].source_reg1 = instruction_line[i].Ir[25:21];
                                       instruction_line[i].dest_reg    = 32'hffff;
                                       instruction_line[i].source_reg2  = 32'hffff;
                                     end
                         
                         else if ((instruction_line[i].opcode== beq_i))
                          
                                     begin
                                      instruction_line[i].rs_add     = instruction_line[i].Ir[25:21];
                                      instruction_line[i].rt_add     = instruction_line[i].Ir[20:16];
                                      instruction_line[i].x_inst     = $signed(instruction_line[i].Ir[15:0]);	                  
                                      instruction_line[i].source_reg1 = instruction_line[i].Ir[25:21];
                                      instruction_line[i].source_reg2= instruction_line[i].Ir[20:16];
                                      instruction_line[i].dest_reg  = 32'hffff;           
                                      instruction_line[i].Rs         = $signed(gpr_file[instruction_line[i].Ir[25:21]]);
                                      instruction_line[i].Rt         = $signed(gpr_file[instruction_line[i].Ir[20:16]]);
                                    end
                         
                         else if ((instruction_line[i].opcode== jr_i))
                          
                                     begin
                                     instruction_line[i].rs_add     = instruction_line[i].Ir[25:21];                          
                                     instruction_line[i].Rs         = $signed(gpr_file[instruction_line[i].Ir[25:21]]);
                                     instruction_line[i].source_reg1 = instruction_line[i].Ir[25:21];
                                     instruction_line[i].dest_reg    = 32'hffff;
                                     instruction_line[i].source_reg2  = 32'hffff;
                                     end
                           else
                                   begin
                                      instruction_line[i].Rd         = 0;
                                      instruction_line[i].Rs         = 0;
                                      instruction_line[i].Rt         = 0;
                                      instruction_line[i].rd_add     = 0;
                                      instruction_line[i].rs_add     = 0;
                                      instruction_line[i].rt_add     = 0;
                                      instruction_line[i].source_reg1 =  32'hffff;
                                      instruction_line[i].dest_reg    = 32'hffff;
                                      instruction_line[i].source_reg2  = 32'hffff;
				   end
endtask

 function int check_decode_stall(int add);

  for(int i=0; i<5; i++) begin
    if(((instruction_line[add].source_reg1== instruction_line[i].dest_reg) || ( instruction_line[add].source_reg2== instruction_line[i].dest_reg) )    &&  ( instruction_line[i].dest_reg != 32'hffff )  && instrcution_stage[i]==4'd2 && taken_branches==0 &&  instruction_line[i].opcode == 6'd12  ) 

                           begin    hit=1;  break  ;    end                       
    end
          
  if(hit==1) begin hit=0;  return 1; end else  return 0 ;
            
  endfunction

always@(posedge clk)

  begin
if(done==0)
begin
       for(i=0; i<5; i++)

          begin
            
            if(instrcution_stage[i]==4'd2)

                       begin

                          instruction_line[i].Rs=$signed(reg_updated[instruction_line[i].rs_add]);
                          instruction_line[i].Rt=$signed(reg_updated[instruction_line[i].rt_add]);
                          instruction_line[i].Rd=$signed(reg_updated[instruction_line[i].rd_add]);                                                 
                          instrcution_stage[i]<=3;
                           
                     if(taken_branches ==0 )
                       begin   
                         case(instruction_line[i].opcode)
                           
                           add_i :  begin  ADD(instruction_line[i].Rs, instruction_line[i].Rt, instruction_line[i].result ); 
                                           reg_updated[instruction_line[i].rd_add] =  $signed(instruction_line[i].result) ;               end
                           
                           add_imm:  begin  ADDI(instruction_line[i].Rs, instruction_line[i].imm , instruction_line[i].result );
                                           reg_updated[instruction_line[i].rt_add] =  $signed(instruction_line[i].result) ;               end
                           
                           sub_i:    begin  SUB(instruction_line[i].Rs, instruction_line[i].Rt, instruction_line[i].result );
                                           reg_updated[instruction_line[i].rd_add] =  $signed(instruction_line[i].result) ;               end
                                                      
                           sub_imm:   begin SUBI(instruction_line[i].Rs, instruction_line[i].imm , instruction_line[i].result );
                                           reg_updated[instruction_line[i].rt_add] =  $signed(instruction_line[i].result) ;               end
                           	                            
                           mul_i:    begin  MUL(instruction_line[i].Rs, instruction_line[i].Rt, instruction_line[i].result );
                                           reg_updated[instruction_line[i].rd_add] =  $signed(instruction_line[i].result) ;               end
                           
                           mul_imm:   begin  MULI(instruction_line[i].Rs, instruction_line[i].imm , instruction_line[i].result );
                                           reg_updated[instruction_line[i].rt_add] =  $signed(instruction_line[i].result) ;               end
                                                     
                           or_i:    begin   OR(instruction_line[i].Rs, instruction_line[i].Rt, instruction_line[i].result );
                                           reg_updated[instruction_line[i].rd_add] =  $signed(instruction_line[i].result) ;               end
                                   
                           or_imm:    begin  ORI(instruction_line[i].Rs, instruction_line[i].imm , instruction_line[i].result );
                                           reg_updated[instruction_line[i].rt_add] =  $signed(instruction_line[i].result );               end
                                                      
                           and_i:    begin  AND(instruction_line[i].Rs, instruction_line[i].Rt, instruction_line[i].result );
                                           reg_updated[instruction_line[i].rd_add] =  $signed(instruction_line[i].result) ;               end
                           	                           
                           and_imm:   begin  ANDI(instruction_line[i].Rs, instruction_line[i].imm , instruction_line[i].result );
                                           reg_updated[instruction_line[i].rt_add] =  $signed(instruction_line[i].result );               end
                                                      
                           xor_i:    begin  XOR(instruction_line[i].Rs, instruction_line[i].Rt, instruction_line[i].result );
                                           reg_updated[instruction_line[i].rd_add] =  $signed(instruction_line[i].result) ;               end
                                                      
                           xor_imm:   begin  XORI(instruction_line[i].Rs, instruction_line[i].imm , instruction_line[i].result );
                                           reg_updated[instruction_line[i].rt_add] =  $signed(instruction_line[i].result) ;               end
                                                      
                           load_i:   instruction_line[i].ld_add=instruction_line[i].Rs+instruction_line[i].imm;
                                                      
                           store_i:   instruction_line[i].st_add= instruction_line[i].Rs+instruction_line[i].imm;
                                                      
                           bz_i:      begin
                                       if(instruction_line[i].Rs==0)  begin   
                                       pc<= (instruction_line[i].x_inst*4 )+instruction_line[i].pc_value;  taken_branches<=1; branch_exec_counter= branch_exec_counter +1;  end
                           	     end
                           
                           beq_i:    begin
                                       if(instruction_line[i].Rs==instruction_line[i].Rt)
                                      begin  pc<= (instruction_line[i].x_inst*4) +instruction_line[i].pc_value ; taken_branches<=1; branch_exec_counter= branch_exec_counter +1; end
                           	     end
                           
                           jr_i:     begin
                                       pc<=instruction_line[i].Rs;
                                       taken_branches<=1; branch_exec_counter= branch_exec_counter +1;
                           	    end                           
                           endcase
                        end

                      else
           
                         begin
                           
                           instruction_line[i].opcode=6'd22; 
                           exec_counter=exec_counter+1;
                         
                           if(exec_counter>1)
                           begin
                              exec_counter=0;
                              taken_branches<=0;              
                            end
                        end
                           
                           break;
               end                                       
        end               
  end
end

always@(posedge clk)

  begin
if(done==0)
begin
      for(i=0; i<5; i++)
          begin

            if(instrcution_stage[i]==4'd3)

                       begin

                         instrcution_stage[i]<=4;

                        case(instruction_line[i].opcode)
                                                                              
                           load_i : begin
                           
                             instruction_line[i].load_data= {mem_array[instruction_line[i].ld_add],mem_array[instruction_line[i].ld_add+1], mem_array[instruction_line[i].ld_add+2], mem_array[instruction_line[i].ld_add+3]};
                                reg_updated[ instruction_line[i].rt_add] = $signed(instruction_line[i].load_data);
                           	   end
                           
                           store_i: begin
                             {mem_array[instruction_line[i].st_add],mem_array[instruction_line[i].st_add+1], mem_array[instruction_line[i].st_add+2], mem_array[instruction_line[i].st_add+3]}=instruction_line[i].Rt;
                           
                           	   end
                        
                           endcase
                           
                           break;
                      
                       end
         end
  end
end

always@(posedge clk)

  begin
if(done==0)
begin
      for(i=0; i<5; i++)

          begin

            if(instrcution_stage[i]==4'd4)

                       begin
                         if(instruction_line[i].opcode <= 6'd18)
                         instruction_exec_counter =instruction_exec_counter+1;  
      
                         instrcution_stage[i]<=0;
                         
                         case(instruction_line[i].opcode) 
                           
                           add_i :    gpr_file[instruction_line[i].rd_add] = instruction_line[i].result;
                                                        
                           add_imm:   gpr_file[instruction_line[i].rt_add] = instruction_line[i].result;
                                                     
                           sub_i:     gpr_file[instruction_line[i].rd_add] = instruction_line[i].result;                 
                           
                           sub_imm:   gpr_file[instruction_line[i].rt_add] = instruction_line[i].result;
                           	                                
                           mul_i:     gpr_file[instruction_line[i].rd_add] = instruction_line[i].result;                                                
                           
                           mul_imm:   gpr_file[instruction_line[i].rt_add] = instruction_line[i].result;
                                                      
                           or_i:      gpr_file[instruction_line[i].rd_add] = instruction_line[i].result;
                           	                            
                           or_imm:    gpr_file[instruction_line[i].rt_add] = instruction_line[i].result;
                                                      
                           and_i:     gpr_file[instruction_line[i].rd_add] = instruction_line[i].result;
                           	                            
                           and_imm:   gpr_file[instruction_line[i].rt_add] = instruction_line[i].result;
                           	                                
                           xor_i:     gpr_file[instruction_line[i].rd_add] = instruction_line[i].result;
                                                      
                           xor_imm:   gpr_file[instruction_line[i].rt_add] = instruction_line[i].result;
                           	                              
                           load_i :   gpr_file[instruction_line[i].rt_add] = instruction_line[i].load_data;
                                                                               
                           halt_i:    done<=1;
                                                     	               
                           endcase
                           
                           break;                       
                       end
         end
  end

end

always@(posedge clk)
begin  
if(done==0)
 cycle_exec_counterer=cycle_exec_counterer+1; 
 end

function void ADD (input  bit signed [31:0]a , input bit signed [31:0]b , output bit signed [31:0]c ) ;   c=a+b;  endfunction

function void ADDI (input bit signed [31:0]a , input bit signed [15:0]b , output bit signed [31:0]c ) ;  c=a+b;  endfunction

function void SUB (input  bit signed [31:0]a , input bit signed [31:0]b , output bit signed [31:0]c ) ;   c=a-b;  endfunction

function void SUBI (input bit signed [31:0]a , input bit signed [15:0]b , output bit signed [31:0]c ) ;  c=a-b;  endfunction

function void MUL (input  bit signed [31:0]a , input bit signed [31:0]b , output bit signed [31:0]c ) ;  c=a*b;   endfunction

function void MULI(input  bit signed [31:0]a , input bit signed [15:0]b , output bit signed [31:0]c ) ; c=a*b;  endfunction

function void OR (input   bit  [31:0]a , input bit  [31:0]b , output bit  [31:0]c ) ;   c=a|b;  endfunction

function void ORI (input  bit  [31:0]a , input bit  [15:0]b , output bit  [31:0]c ) ;  c=a|b;  endfunction

function void AND (input  bit  [31:0]a , input bit  [31:0]b , output bit  [31:0]c ) ;  c=a&b;  endfunction

function void ANDI (input bit  [31:0]a , input bit  [15:0]b , output bit  [31:0]c ) ; c=a&b;  endfunction

function void XOR (input  bit  [31:0]a , input bit  [31:0]b , output bit  [31:0]c ) ; c=a^b;  endfunction

function void XORI (input bit  [31:0]a , input bit  [15:0]b , output bit  [31:0]c ) ; c=a^b;  endfunction

endmodule
