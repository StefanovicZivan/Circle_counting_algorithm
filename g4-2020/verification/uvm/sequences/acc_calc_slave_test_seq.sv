//This sequence will be purely used as a test sequence
//to verify that the environment will successfully generate
//a sequence and monitor the answer

//It will not be included in the finished environment

`ifndef ACC_CALC_SLAVE_TEST_SEQ_SV
 `define ACC_CALC_SLAVE_TEST_SEQ_SV

class acc_calc_slave_test_seq extends acc_calc_slave_base_seq;

   `uvm_object_utils(acc_calc_slave_test_seq)

   function new(string name = "acc_calc_slave_test_seq");
      super.new(name);
   endfunction : new

   virtual task body();
      //always respond
      forever begin
         //`uvm_do_with(req, {req.delay == 0;})
         `uvm_do(req)

         //end condition, if the delay is set by the driver
         //to > 10, then the sequences are finished
         if(req.delay > 10)
           break;
      end
   endtask : body

endclass // acc_calc_slave_test_seq

`endif
