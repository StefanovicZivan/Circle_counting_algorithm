`ifndef ACC_CALC_SEQ_PKG_SV
 `define ACC_CALC_SEQ_PKG_SV

package acc_calc_seq_pkg;
   import uvm_pkg::*; //import the UVM library
 `include "uvm_macros.svh" //include the UVM macros


   //import the sequence item and sequencer
   import acc_calc_master_agent_pkg::acc_calc_master_seq_item;
   import acc_calc_master_agent_pkg::acc_calc_master_sequencer;
   import acc_calc_slave_agent_pkg::acc_calc_slave_seq_item;
   import acc_calc_slave_agent_pkg::acc_calc_slave_sequencer;

   //include Sequences
 `include "acc_calc_master_base_seq.sv"
 `include "acc_calc_slave_base_seq.sv"
 `include "acc_calc_slave_test_seq.sv"
 `include "acc_calc_master_test_seq.sv"
 `include "acc_calc_master_group1_seq.sv"
 `include "acc_calc_master_group2_seq.sv"
 `include "acc_calc_slave_group1_seq.sv"
 `include "acc_calc_slave_group2_seq.sv"
endpackage : acc_calc_seq_pkg

`endif
