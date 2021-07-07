`ifndef ACC_CALC_SLAVE_GROUP2_SEQ_SV
 `define ACC_CALC_SLAVE_GROUP2_SEQ_SV

//for group2, we want to see how the DUV responds
//to reads with various delays

//verification plan - check 2.5 - reads with various delays

class acc_calc_slave_group2_seq extends acc_calc_slave_base_seq;

   `uvm_object_utils(acc_calc_slave_group2_seq)

   function new(string name = "acc_calc_slave_group2_seq");
      super.new(name);
   endfunction : new

   virtual task body();
      forever begin
         `uvm_do(req)

         //end condition, if the delay is set by the driver
         //to > 10, then the sequences are finished
         if(req.delay > 10)
           break;
      end
   endtask : body

endclass // acc_calc_slave_group2_seq

`endif
