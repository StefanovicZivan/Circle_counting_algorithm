module acc_calc_verif_top;

   import uvm_pkg::*; // import the UVM library
`include "uvm_macros.svh" // include the UVM macros

   import acc_calc_test_pkg::*; // include the test package

   //define the aclk and aresetn signals
   logic aclk;
   logic aresetn;

   //DUV interface
   acc_calc_if acc_calc_vif(aclk, aresetn);

   //DUV
   acc_calc_ip_top DUV(
                       .axis_aclk (aclk),
                       .axis_aresetn (aresetn),
                       .m00_axis_tvalid (acc_calc_vif.m00_axis_tvalid),
                       .m00_axis_tready (acc_calc_vif.m00_axis_tready),
                       .m00_axis_tlast (acc_calc_vif.m00_axis_tlast),
                       .m00_axis_tdata (acc_calc_vif.m00_axis_tdata),
                       .s00_axis_tready (acc_calc_vif.s00_axis_tready),
                       .s00_axis_tvalid (acc_calc_vif.s00_axis_tvalid),
                       .s00_axis_tlast (acc_calc_vif.s00_axis_tlast),
                       .s00_axis_tdata (acc_calc_vif.s00_axis_tdata)
                       );
   /*INSTANTIATE HERE*/

   //set the virtual interface in config_db and run test
   initial
     begin
        uvm_config_db#(virtual acc_calc_if)::set(null, "uvm_test_top.env", "acc_calc_if", acc_calc_vif);
        run_test();
     end

   //clock and reset initialization
   initial
     begin
        aclk <= 0;
        aresetn <= 0;
        #20 aresetn <= 1;
     end

   //clock generation
   always #10 aclk = ~aclk;

endmodule : acc_calc_verif_top