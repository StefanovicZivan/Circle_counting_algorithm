`ifndef ACC_CALC_MASTER_SEQUENCER_SV
 `define ACC_CALC_MASTER_SEQUENCER_SV

class acc_calc_master_sequencer extends uvm_sequencer#(acc_calc_master_seq_item);

   //factory registration
   `uvm_component_utils(acc_calc_master_sequencer)

   //constructor
   function new(string name = "acc_calc_master_sequencer", uvm_component parent = null);
      super.new(name, parent);
   endfunction : new

endclass : acc_calc_master_sequencer

`endif
