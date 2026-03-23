`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////////////
//      DDR4Interface
//
//      Description:
//          SystemVerilog interface modeling DDR4 command/address, data,
//              and sideband signals.
//
//      Purpose:
//          - Provides a unified connection point between:
//              * Memory Controller (MC)
//              * DDR PHY / Memory Model
//          - Separates CA, DQ, and sideband signals using modports.
//
//  NOTE:
//      This DDR4 interface definition was inspired by publicly available DDR4 
//      interface examples in github. (https://github.com/ananthbhat94/DDR4MemoryController/blob/master/DDR4Interface.sv)
//      The structure and signal grouping have been adapted and simplified
//          to fit this project's controller and memory model architecture.
//
//      Author  : Seongwon Jo
//      Created : 2026.02
//////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////
//      DDR4Interface
//
//      설명(Description):
//          DDR4의 명령/주소(Command/Address), 데이터(Data),
//          그리고 사이드밴드(sideband) 신호를 모델링한
//          SystemVerilog 인터페이스.
//
//      목적(Purpose):
//          - 다음 구성 요소들 사이의
//            통합된(unified) 연결 지점을 제공함:
//              * 메모리 컨트롤러(Memory Controller, MC)
//              * DDR PHY / 메모리 모델
//          - modport를 사용하여
//            CA(Command/Address), DQ(Data), 사이드밴드 신호를
//            논리적으로 분리함.
//
//  참고(NOTE):
//      본 DDR4 인터페이스 정의는
//      GitHub에 공개된 DDR4 인터페이스 예제들을 참고하여 작성되었음.
//      (https://github.com/ananthbhat94/DDR4MemoryController/blob/master/DDR4Interface.sv)
//
//      인터페이스의 전체 구조와 신호 그룹 구성은
//      본 프로젝트의 메모리 컨트롤러 및 메모리 모델 아키텍처에
//      맞도록 수정 및 단순화되었음.
//
//      작성자  : Seongwon Jo
//      작성일  : 2026.02
//////////////////////////////////////////////////////////////////////////////////////////

interface DDR4Interface #(
	parameter int COMMAND_WIDTH = 18,
	parameter int MEM_DATAWIDTH = 64,
	parameter int BURST_LENGTH  = 8,
	parameter int BGWIDTH       = 2,
	parameter int BKWIDTH       = 2,
	parameter int RWIDTH        = 15,
	parameter int RKWIDTH       = 2,
	parameter int CWIDTH        = 10,
	parameter int NUMRANK       = 4
) (
	input logic clk, rst
);

    // Definitions and LocalParameters
    // RAS, CAS, ACT, WE, CS -> command OPCode
    // Row bits -> 15, Col bits -> 10, bg,bk -> 2 bits 
    // Pin signal requires: RAS, CAS, WE ,CS, ACT 
    `define RAS pin_A[16]	//RAS Command Input
    `define CAS pin_A[15] 	//CAS Command Input
    `define WE	pin_A[14]	//WE Command Input
    `define BC	pin_A[12] 	//Burst Chop
    `define AP 	pin_A[10]  	// Auto Precharge 
    `define HIGH '1
    localparam LOW = '0;

    /**************Define Interface Signals*********************/
    //Address Inputs
    logic [COMMAND_WIDTH-1:0] pin_A; 

    //Control Signals
    logic act_n; //Activate Command Input
    logic [BGWIDTH-1:0] bg; //Bank Address Inputs
    logic [BKWIDTH-1:0] b; //Bank Group Address Inputs

    logic cke; //Clock Enable
    logic [NUMRANK-1:0] cs_n; //Chip Select
    logic [MEM_DATAWIDTH/BURST_LENGTH - 1 : 0] dm_n,udm_n,ldm_n; //Input Data Mask
    logic odt; //On Die Termination
    logic par; //Parity
    logic reset_n; //Asynchronous Reset
    logic ten; //Connectivity Test Mode
    logic alert_n; //Alert output



    //////////////////////////////////////////////////////////////////////
    //////////////////// OPCODE FOR DDR4 Memory //////////////////////////
    //////////////// CKE     ACT     RAS      CAS      WE     CS   ///////
    // ACTIVATE       1       0       X        X       X       0        //
    // PRECHARGE      1       1       0       1        0       0        //
    // READ           1       1       1       0        0       0        //
    // WRITE          1       1       1       0        1       0        //
    // REFRESH        1       1       0       0        0       0        //
    // NO-OPERATION   1       1       1       1        1       0        //
    //////////////////////////////////////////////////////////////////////

    //Data Signals
    wire [MEM_DATAWIDTH-1:0] pin_dq; //Bidirectional Data Bus
    wire dbi_n, udbi_n, ldbi_n; //Data Bus Inversion
    wire dqs_t,dqs_c,   //Data Strobe pins
        dqsu_t,dqsu_c,
        dqsl_t,dqsl_u;
    wire tdqs_t,tdws_c; //Termination Data Strobe. 

    assign reset_n = ~rst;

    //Modport Definitions
    modport Memory_SidePort(
        input reset_n, 
        inout dbi_n, udbi_n, ldbi_n,
        output alert_n, tdqs_t, tdws_c
    );
    
    modport Memory_CA(
        input cke, cs_n, par, pin_A, act_n, bg, b
    );

    modport Memory_DQ(
        inout pin_dq, dqs_t, dqs_c, 
        input dm_n, udm_n, ldm_n, odt
    );
    // ten is in internal signal

    modport MC_Sideport(
        output reset_n,
        inout dbi_n, udbi_n,ldbi_n,
        input alert_n, tdqs_t, tdws_c
    );

    modport MC_CA(
        output cke, cs_n, par, pin_A, act_n, bg, b
    );

    modport MC_DQ(
        inout pin_dq, dqs_t, dqs_c,
        output dm_n, udm_n, ldm_n, odt
    );

endinterface
