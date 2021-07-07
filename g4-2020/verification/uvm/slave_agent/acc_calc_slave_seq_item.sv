`ifndef ACC_CALC_SLAVE_SEQ_ITEM_SV
 `define ACC_CALC_SLAVE_SEQ_ITEM_SV

//Parameters of the AXI Stream Master Bus Interface of acc_calc_ip
parameter M00_AXIS_TDATA_WIDTH = 32;

//this class represents the transactions that the
//AXI DMA will recieve on its AXI Stream slave interface
//which corresponds to the Master interface of acc_calc_ip
class acc_calc_slave_seq_item extends uvm_sequence_item;

   //acc_calc_ip master interface
   bit [M00_AXIS_TDATA_WIDTH - 1 : 0] m00_axis_tdata;
   bit                                m00_axis_tlast;

   //measured delay
   rand int unsigned                       delay;

   constraint c_delay {delay < 10;}

   //UVM factory registration
   `uvm_object_utils_begin(acc_calc_slave_seq_item)
      `uvm_field_int(m00_axis_tdata, UVM_DEFAULT)
      `uvm_field_int(m00_axis_tlast, UVM_DEFAULT)

      `uvm_field_int(delay, UVM_DEFAULT)
   `uvm_object_utils_end

   //constructor
   function new(string name = "acc_calc_slave_seq_item");
      super.new(name);
   endfunction : new

endclass : acc_calc_slave_seq_item

`endif
