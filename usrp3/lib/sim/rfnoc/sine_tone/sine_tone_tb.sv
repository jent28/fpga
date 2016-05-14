//
// Copyright 2015 Ettus Research LLC
//
`timescale 1ns/1ps
`define SIM_RUNTIME_US 5
`define NS_PER_TICK 1
`define NUM_TEST_CASES 2
`include "sim_exec_report.vh"
`include "sim_rfnoc_lib.svh"
`include "sim_set_rb_lib.svh"

module sine_tone_tb();
  `TEST_BENCH_INIT("sine_tone_tb",`NUM_TEST_CASES,`NS_PER_TICK);
  localparam CLK_PERIOD = $ceil(1e6/166.67e6);
  localparam TEST_LENGTH = 2000;
  `DEFINE_CLK(clk, CLK_PERIOD, 50); 
  `DEFINE_RESET(rst, 0, 100);

  //Input Output definitions
  //axis_t axis (.clk(clk)); 			
  axis_slave tb_axis (.clk(clk));
  
  //settings_bus_t set_bus (.clk(clk));
  //readback_bus_t rb_bus (.clk(clk));
  settings_bus_master set_bus (.clk(clk));
  
  wire [15:0] o_tdata_I;
  wire [15:0] o_tdata_Q;
  wire o_tlast;
  wire o_tvalid;
  wire o_tready;
  wire [15:0] phase ;
  wire [31:0] cartesian;
  wire [15:0] phase2 ;
  wire [31:0] cartesian2;

  logic [15:0] real_val, cplx_val;
  logic last;
  logic error = 0;   
  real pi = $acos(-1);
  real gain_correction = 0.699;
  real expected_sine, expected_cosine;
  real expected_sine2, expected_cosine2;
  real phase_real, expected_sine_real, expected_cosine_real;
  real phase_real2, expected_sine_real2, expected_cosine_real2;
  integer freq = 1; // (In MHz)
  integer sample_rate = 100; // (In Msps)
  
  assign o_tdata_I = tb_axis.axis.tdata[15:0];
  assign o_tdata_Q = tb_axis.axis.tdata[31:16];
  assign o_tlast = tb_axis.axis.tlast;
  assign o_tvalid = tb_axis.axis.tvalid;
  assign o_tready = tb_axis.axis.tready;
  wire enable;

  //Module Instantiation
  sine_tone #(.WIDTH(32)) sine_tone_inst
      (.clk(clk), .reset(rst), .clear(0), .enable(enable),
       .set_stb(set_bus.settings_bus.set_stb), .set_data(set_bus.settings_bus.set_data), .set_addr(set_bus.settings_bus.set_addr), 
       .o_tdata(tb_axis.axis.tdata), .o_tlast(tb_axis.axis.tlast), .o_tvalid(tb_axis.axis.tvalid), .o_tready(tb_axis.axis.tready));
    
  initial begin
    //tb_axis = new(axis);
    //tb_set_bus = new(set_bus, rb_bus);
  end
  
  assign phase = 16'($floor(((2**13) * ((2.0*freq)/sample_rate)) + 0.5));
  assign phase_real = real'((phase/(2.0**13))* pi);
  assign cartesian = {16'b0,16'($floor((2**13) * (1/1.65)))};

  assign phase2 = 16'($floor(((2**13) * ((2.0*freq)/(0.5*sample_rate)) + 0.5)));
  assign phase_real2 = real'((phase2/(2.0**13))* pi);
  assign cartesian2 = {16'b0,16'($floor((2**13) * (1/1.65)))};
  assign enable = 1;


  task automatic check_wave;
     input real actual;
     input real expected;
     begin
        if (expected > 0) 
           error = (actual > expected) ? (((actual - expected)/expected) > 0.03) : (((expected - actual)/expected) > 0.03) ;
        //`ASSERT_FATAL(error != 1'b1, "Sine wave incorrectly generated");
        `ASSERT_ERROR(error != 1'b1, "Sine wave incorrectly generated");
     end
  endtask
  //setting_reg #(
  //  .my_addr(132), .awidth(8), .width(1)) 
  //set_enable (
  //  .clk(clk), .rst(reset),
  //  .strobe(set_stb), .addr(set_addr), .in(set_data),
  //  .out(enable), .changed());
  
  /********************************************************
  ** Verification
  ********************************************************/
  initial begin : tb_main
    `TEST_CASE_START("Wait for reset");
    //FIXME: Reset set_bus here? 
    set_bus.reset;
    tb_axis.reset;
    while (rst) @(posedge clk);
    `TEST_CASE_DONE(~rst);
    
    
    `TEST_CASE_START("Check sine wave generation");
    //Enable
    //set_bus.write(132,1'b1,0);
    
    //Set the phase value
    set_bus.write(129,phase,0);

    //Set the cartesian value
    set_bus.write(130,cartesian,0);
   
    //Receive data from AXI slave
    for (int i = 0; i < TEST_LENGTH - 1; ++i) begin
      tb_axis.pull_word({real_val,cplx_val},last);
      expected_sine_real = $sin((i-2)*phase_real);
      expected_sine = $floor((gain_correction * ((2.0**13)* expected_sine_real)) + 0.5);
      if (sine_tone_inst.o_tvalid)  check_wave(real_val, expected_sine );
    end
    
    //Enable
    //set_bus.write(132,1'b0,0);
  
    repeat (100) @(posedge clk);
  
    //Enable
    //set_bus.write(132,1'b1,0);
    
    //Set the phase value
    //set_bus.write(129,phase2,0);

    //Set the cartesian value
    //set_bus.write(130,cartesian2,0);
   
    //Receive data from AXI slave
    for (int i = 0; i < TEST_LENGTH - 1; ++i) begin
      tb_axis.pull_word({real_val,cplx_val},last);
      expected_sine_real2 = $sin((i)*phase_real2);
      expected_sine2 = $floor((gain_correction * ((2.0**13)* expected_sine_real2)) + 0.5);
      if (sine_tone_inst.o_tvalid) check_wave(real_val, expected_sine2);
    end
    `TEST_CASE_DONE(1);
    
    //Testcase3: Check functionality of 'clear'
    //Testcase4: Check start and stop 
    //Testcase5: Check a range of frequencies
    

     repeat (10) @(posedge clk);
   end

endmodule
