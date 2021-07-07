`ifndef TEST_GROUP2_SV
 `define TEST_GROUP2_SV

//this test will be used to test the basic functionality
//of the environment, it will not be used for verifying the DUV
class test_group2 extends test_base;

   //UVM factory registration
   `uvm_component_utils(test_group2)
   
   //the sequences that will be used
   acc_calc_master_group2_seq master_group2_seq;
   acc_calc_slave_group2_seq slave_group2_seq;

   //constructor
   function new(string name = "test_group2", uvm_component parent = null);
      super.new(name, parent);
   endfunction : new

   //build phase, create the sequences
   function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      master_group2_seq = acc_calc_master_group2_seq::type_id::create("master_group2_seq");
      slave_group2_seq = acc_calc_slave_group2_seq::type_id::create("slave_group2_seq");

      master_group2_seq.randomize();
   endfunction : build_phase

   //main phase, raise objections, run the sequences, drop objections
   task main_phase(uvm_phase phase);
      phase.raise_objection(this);
      //two threads
      fork
         begin
            master_group2_seq.start(env.master_agent.seqr);
         end

         begin
            slave_group2_seq.start(env.slave_agent.seqr);
         end
      join
      phase.drop_objection(this);
   endtask : main_phase

endclass : test_group2

`endif
