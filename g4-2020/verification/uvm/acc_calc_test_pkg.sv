`ifndef ACC_CALC_TEST_PKG_SV
 `define ACC_CALC_TEST_PKG_SV

package acc_calc_test_pkg;

   import uvm_pkg::*;           // import the UVM library
 `include "uvm_macros.svh"     // include the UVM macros

   //import sequences, agents, optional configurations
   import acc_calc_master_agent_pkg::*;
   import acc_calc_slave_agent_pkg::*;
   import acc_calc_seq_pkg::*;

   //include tests, scoreboard, environment
 `include "acc_calc_scoreboard.sv"
 `include "acc_calc_env.sv"
 `include "test_base.sv"
 `include "test_simple.sv"
 `include "test_group1.sv"
 `include "test_group2.sv"

endpackage // acc_calc_test_pkg

 `include "acc_calc_if.sv"      // include the interface

`endif
