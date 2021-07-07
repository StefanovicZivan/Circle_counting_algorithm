//This sequence will be purely used as a test sequence
//to verify that the environment will successfully generate
//a sequence and monitor the answer

//It will not be included in the finished environment

`ifndef ACC_CALC_MASTER_TEST_SEQ_SV
 `define ACC_CALC_MASTER_TEST_SEQ_SV

class acc_calc_master_test_seq extends acc_calc_master_base_seq;

   `uvm_object_utils(acc_calc_master_test_seq)

   function new(string name = "acc_calc_master_test_seq");
      super.new(name);
   endfunction : new

   virtual task body();
      //send radius, then a pixel
      `uvm_do_with(req, {req.s00_axis_tdata == 32'h80000005; req.s00_axis_tlast == 1'b0; req.delay == 0;})
      //`uvm_do_with(req, {req.s00_axis_tdata == 32'h0000280a; req.s00_axis_tlast == 1'b0; req.delay == 0;})
      `uvm_do_with(req, {req.s00_axis_tdata == 32'h00000000; req.s00_axis_tlast == 1'b1; req.delay == 0;})
   endtask : body

endclass // acc_calc_master_test_seq

`endif
