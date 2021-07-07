`ifndef TEST_SIMPLE_SV
 `define TEST_SIMPLE_SV

//this test will be used to test the basic functionality
//of the environment, it will not be used for verifying the DUV
class test_simple extends test_base;

   //UVM factory registration
   `uvm_component_utils(test_simple)
   
   //the sequences that will be used
   acc_calc_master_test_seq master_test_seq;
   acc_calc_slave_test_seq slave_test_seq;

   real cos_val_array[360];
   real sin_val_array[360];

   bit [31 : 0] expected_val_array[360];

   const real M_PI =  3.14159265358979323846; /* pi value as defined in math.h*/

   //constructor
   function new(string name = "test_simple", uvm_component parent = null);
      super.new(name, parent);
   endfunction : new

   //build phase, create the sequences
   function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      master_test_seq = acc_calc_master_test_seq::type_id::create("master_test_seq");
      slave_test_seq = acc_calc_slave_test_seq::type_id::create("slave_test_seq");
   endfunction : build_phase

   //main phase, raise objections, run the sequences, drop objections
   task main_phase(uvm_phase phase);
      real r2;
      int unsigned radius = 5;
      int unsigned y_pos = 0;
      int unsigned x_pos;
      phase.raise_objection(this);
      init_cos_sin_array(cos_val_array, sin_val_array);
      ref_model_func(32'h00000000, 5);

      $cast(x_pos, 10'b0000000000);

      $display("sin(180) = %0f", sin_val_array[180]);

      r2 = radius * sin_val_array[180];
      $display("r2 = %0f", r2);

      if(y_pos < r2)
        $display("ITS LESS!");

      $display("x_pos = %0d", x_pos);

      //two threads, since the slave sequence has a forever loop
      //the simulation would never end, so we make a fork - join_any
      //construction, and wait for the master sequence to finish
      fork
         begin
            master_test_seq.start(env.master_agent.seqr);
            $display("MASTER SEQ FORK FINISHED @%0t\n", $time());
         end

         begin
            slave_test_seq.start(env.slave_agent.seqr);
            $display("SLAVE SEQ FORK FINISHED @%0t\n", $time());
         end
      join

      //this delay is necessary, because the test doesn't have drain time set
      //#80000ns;
      phase.drop_objection(this);
   endtask : main_phase

   extern function void init_cos_sin_array(ref real cos_val_array[360], ref real sin_val_array[360]);
   extern function void ref_model_func(input bit [31 : 0] input_data, input int unsigned radius);

endclass : test_simple

//function used to initialize the sine and cosine arrays in fixed point representation
function void test_simple::init_cos_sin_array(ref real cos_val_array[360], ref real sin_val_array[360]);
   real theta_rad;
   real cos_value_float, sin_value_float;
   int  cos_value_bin, sin_value_bin;
   real cos_value_fix, sin_value_fix;
   //iterate through 0 - 360 degrees with 1 degree step
   for(int theta = 0; theta < 360; theta++) begin
      //same steps as in the SystemC model
      theta_rad = theta * M_PI / 180;

      //1. calculate cos(theta) and sin(theta) - degrees must be converted to radians
      cos_value_float = $cos(theta_rad); // non quantized
      sin_value_float = $sin(theta_rad); // non quantized

      //now we must convert the floating point to fixed point
      //the DUV uses 6 bits for the fractal part, and 4 for the integer part
      //we multiply by 2^6, round it, and the resulting integer, converted to binary
      //is the fixed point representation, with the point at the correct position

      if(cos_value_float > 0)
        cos_value_bin = $floor(cos_value_float * 64);
      else
        cos_value_bin = $ceil(cos_value_float * 64);

      if(sin_value_float > 0)
        sin_value_bin = $floor(sin_value_float * 64);
      else
        sin_value_bin = $ceil(sin_value_float * 64);

      //now we have a value that can be represented in fixed point
      //the implicit rounding gives us a fixed point value
      //now we just shift the rounded value by the scale, i.e. 2^(-6)
      cos_value_fix = cos_value_bin * 0.015625;
      sin_value_fix = sin_value_bin * 0.015625;

      cos_val_array[theta] = cos_value_fix;
      sin_val_array[theta] = sin_value_fix;

      if(theta == 300)
        `uvm_info("TEST", $sformatf("cos(300) = %0f", cos_value_fix), UVM_LOW)
   end // for (int theta = 0; theta < 360; theta++)

   //added due to quantization issues
   cos_val_array[120] = -0.5;
   sin_val_array[330] = -0.484375;

endfunction : init_cos_sin_array

//referent model implementation
function void test_simple::ref_model_func(input bit [31 : 0] input_data, input int unsigned radius);
   int unsigned x_pos, y_pos;   // x and y positions of the recieved white pixel
   int unsigned a_pos, b_pos;   // circle values around the (x,y) center
   bit [9 : 0]  a_pos_bin, b_pos_bin;
   real r1, r2;                 // r1 = rad * cos; r2 = rad * sin
   real r1_r, r2_r;
   bit [31 : 0] expected_value;

   $cast(x_pos, input_data[9 : 0]); // bits 9 : 0 contain the x position
   $cast(y_pos, input_data[19 : 10]); // next 10 bits contain the y position

   //same steps as the SystemC model
   for(int theta = 0; theta < 360; theta++) begin
      //step 1 - calculate radius * cos and radius * sin
      //we multiplied a fixed point value with an integer represented with 10 bits
      //the result will be : 14 bits for integer part, 6 bits for fractal
      r1 = radius * cos_val_array[theta];
      r2 = radius * sin_val_array[theta];

      //calculate x_pos - r1 to check if the result is < 0
      //same for y_pos

      r1_r = radius * $cos(theta * M_PI / 180);
      r2_r = radius * $sin(theta * M_PI / 180);

      //step 2 - check if the result of x_pos - r1 and y_pos - r2 will be negative
      if((x_pos < r1_r) || (y_pos < r2_r)) begin
        expected_value[31] = 1'b1; // set the INVALID_PIX_MASK
      end
      else begin
         //step 3 - calculate x - r1 and y - r2 and round the value to the closest integer
         $cast(a_pos, x_pos - r1); // implicit rounding will be done here
         $cast(b_pos, y_pos - r2);

         //step 4 - convert to binary, and pack the data
         $cast(a_pos_bin, a_pos);
         $cast(b_pos_bin, b_pos);

         expected_value[9 : 0] = a_pos_bin;
         expected_value[19 : 10] = b_pos_bin;
      end // else: !if((x_pos < r1) || (y_pos < r2))

      //store the data
      expected_val_array[theta] = expected_value;
   end
endfunction : ref_model_func


`endif
