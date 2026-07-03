interface mips_interface;
    // Opcodes for MIPS-lite ISA
    parameter ADD   = 6'b000000; 
    parameter ADDI  = 6'b000001;
    parameter SUB   = 6'b000010;
    parameter SUBI  = 6'b000011;
    parameter MUL   = 6'b000100;
    parameter MULI  = 6'b000101;
    parameter OR    = 6'b000110;
    parameter ORI   = 6'b000111;
    parameter AND   = 6'b001000;
    parameter ANDI  = 6'b001001;
    parameter XOR   = 6'b001010;
    parameter XORI  = 6'b001011;
    parameter LW    = 6'b001100;
    parameter SW    = 6'b001101;
    parameter BZ    = 6'b001110;
    parameter BEQ   = 6'b001111;
    parameter JR    = 6'b010000;
    parameter HALT  = 6'b010001;
endinterface
