`ifndef ACC_CALC_SLAVE_AGENT_PKG
 `define ACC_CALC_SLAVE_AGENT_PKG

package acc_calc_slave_agent_pkg;
   import uvm_pkg::*;
 `include "uvm_macros.svh"

   //include Slave Agent components
   //import configurations_pkg::*;   

 `include "acc_calc_slave_seq_item.sv"
 `include "acc_calc_slave_sequencer.sv"
 `include "acc_calc_slave_driver.sv"
 `include "acc_calc_slave_monitor.sv"
 `include "acc_calc_slave_agent.sv"
endpackage : acc_calc_slave_agent_pkg

`endif
