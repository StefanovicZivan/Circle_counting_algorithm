`ifndef ACC_CALC_IF_SV
 `define ACC_CALC_IF_SV

interface acc_calc_if(input aclk, logic aresetn);
   parameter M00_AXIS_TDATA_WIDTH = 32;
   parameter S00_AXIS_TDATA_WIDTH = 32;

   //acc_calc_ip master interface
   logic [M00_AXIS_TDATA_WIDTH - 1 : 0] m00_axis_tdata;
   logic                                m00_axis_tvalid;
   logic                                m00_axis_tlast;
   logic                                m00_axis_tready;

   //acc_calc_ip slave interface
   logic [S00_AXIS_TDATA_WIDTH - 1 : 0] s00_axis_tdata;
   logic                                s00_axis_tvalid;
   logic                                s00_axis_tlast;
   logic                                s00_axis_tready;

endinterface : acc_calc_if

`endif
