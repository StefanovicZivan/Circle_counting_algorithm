`ifndef ACC_CALC_MASTER_SEQ_ITEM_SV
 `define ACC_CALC_MASTER_SEQ_ITEM_SV

//paramaters of the AXI Stream Slave Bus Interface of acc_calc_ip
parameter S00_AXIS_TDATA_WIDTH = 32;

//this class represents the transactions that the
//AXI DMA will generate on its AXI Stream master interface
//which corresponds to the Slave interface of acc_calc_ip
class acc_calc_master_seq_item extends uvm_sequence_item;

   //acc_calc_ip slave interface
   rand bit [S00_AXIS_TDATA_WIDTH - 1 : 0] s00_axis_tdata;
   rand bit s00_axis_tlast;

   //randomized transaction delay
   rand int unsigned delay;

   //constraints
   constraint c_delay {delay < 10;}

   //max input image size 800x800
   constraint c_size {
      s00_axis_tdata[9 : 0] < 801;
      s00_axis_tdata[19 : 10] < 801;
   }

   //UVM factory registration
   `uvm_object_utils_begin(acc_calc_master_seq_item)
      `uvm_field_int(s00_axis_tdata, UVM_DEFAULT)
      `uvm_field_int(s00_axis_tlast, UVM_DEFAULT)

      `uvm_field_int(delay, UVM_DEFAULT)
   `uvm_object_utils_end

   //constructor
   function new(string name = "acc_calc_master_seq_item");
      super.new(name);
   endfunction : new

endclass : acc_calc_master_seq_item

`endif
