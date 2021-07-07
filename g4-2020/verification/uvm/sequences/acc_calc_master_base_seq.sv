`ifndef ACC_CALC_MASTER_BASE_SEQ_SV
 `define ACC_CALC_MASTER_BASE_SEQ_SV

class acc_calc_master_base_seq extends uvm_sequence#(acc_calc_master_seq_item);

   //UVM factory registration
   `uvm_object_utils(acc_calc_master_base_seq)
   //declare the sequencer for the sequences
   `uvm_declare_p_sequencer(acc_calc_master_sequencer)

   //constructor
   function new(string name = "acc_calc_master_base_seq");
      super.new(name);
   endfunction : new

   //raise objections in pre_body, set drain time
   virtual task pre_body();
      uvm_phase phase = get_starting_phase();
      //check if the sequence is set as the default one
      if(phase != null)
        phase.raise_objection(this, {"Running phase '", get_full_name(), "'"});
        
      //set drain time
      uvm_test_done.set_drain_time(this, 500ns);
   endtask : pre_body

   //drop objections in post_body
   virtual task post_body();
      uvm_phase phase = get_starting_phase();
      //check if the sequence is set as the default one
      if(phase != null)
        phase.drop_objection(this, {"Completed sequence '", get_full_name(), "'"});
   endtask : post_body

endclass : acc_calc_master_base_seq

`endif
