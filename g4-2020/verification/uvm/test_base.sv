`ifndef TEST_BASE_SV
 `define TEST_BASE_SV

class test_base extends uvm_test;

   //instantiate the environment
   acc_calc_env env;

   //UVM factory registration
   `uvm_component_utils(test_base)

   //constructor
   function new(string name = "test_base", uvm_component parent = null);
      super.new(name, parent);
   endfunction : new

   //build phase, create the environment
   function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      env = acc_calc_env::type_id::create("env", this);
   endfunction : build_phase

   //end of elaboration phase, print the topology of the environment
   function void end_of_elaboration_phase(uvm_phase phase);
      super.end_of_elaboration_phase(phase);
      uvm_top.print_topology();
   endfunction : end_of_elaboration_phase

endclass : test_base

`endif
