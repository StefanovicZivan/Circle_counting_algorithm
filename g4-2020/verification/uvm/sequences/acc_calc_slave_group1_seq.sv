`ifndef ACC_CALC_SLAVE_GROUP1_SEQ_SV
 `define ACC_CALC_SLAVE_GROUP1_SEQ_SV

//in group1, we just want to test the basic protocol
//and values, so we will always read DUV master transactions
//with zero delay

class acc_calc_slave_group1_seq extends acc_calc_slave_base_seq;

   `uvm_object_utils(acc_calc_slave_group1_seq)

   function new(string name = "acc_calc_slave_group1_seq");
      super.new(name);
   endfunction : new

   virtual task body();
      forever begin
         `uvm_do_with(req, {req.delay == 0;})

         //end condition, if the delay is set by the driver
         //to > 10, then the sequences are finished
         if(req.delay > 10)
           break;
      end
   endtask : body

endclass // acc_calc_slave_group1_seq

`endif
