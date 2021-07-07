`ifndef ACC_CALC_MASTER_GROUP1_SEQ_SV
 `define ACC_CALC_MASTER_GROUP1_SEQ_SV

//this sequence will generate a simple transaction
//first the radius will be sent, then the pixel
//this will test the basic protocol, and check
//the values, etc.

class acc_calc_master_group1_seq extends acc_calc_master_base_seq;

   //UVM factory registration
   `uvm_object_utils(acc_calc_master_group1_seq)

   //constructor
   function new(string name = "acc_calc_master_group1_seq");
      super.new(name);
   endfunction : new

   virtual task body();
      //send radius, then a pixel
      `uvm_do_with(req, {req.s00_axis_tdata == 32'h80000005; req.s00_axis_tlast == 1'b0;})
      `uvm_do_with(req, {req.s00_axis_tdata == 32'h0000280a; req.s00_axis_tlast == 1'b1;})
   endtask : body


endclass : acc_calc_master_group1_seq

`endif
