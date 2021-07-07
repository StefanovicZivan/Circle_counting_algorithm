`ifndef ACC_CALC_MASTER_AGENT_PKG_SV
 `define ACC_CALC_MASTER_AGENT_PKG_SV

package acc_calc_master_agent_pkg;
   import uvm_pkg::*;
 `include "uvm_macros.svh"

   //include Master Agent components
   //import configurations_pkg::*;

 `include "acc_calc_master_seq_item.sv"
 `include "acc_calc_master_sequencer.sv"
 `include "acc_calc_master_driver.sv"
 `include "acc_calc_master_monitor.sv"
 `include "acc_calc_master_agent.sv"
endpackage : acc_calc_master_agent_pkg

`endif
