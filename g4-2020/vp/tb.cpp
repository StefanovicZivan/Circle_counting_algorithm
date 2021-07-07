#include "tb.hpp"
#include "vp_addr.hpp"
#include <tlm_utils/tlm_quantumkeeper.h>
#include <iostream>
#include <opencv2/highgui.hpp>
#include <opencv2/imgproc.hpp>
#include <opencv2/core.hpp>
#include <string>

using namespace cv; 
using namespace std;
using namespace sc_core;
using namespace tlm;
//using namespace sc_dt;

SC_HAS_PROCESS(tb);

#define RS_MASK         (0x1 << 0)
#define RESET_MASK      (0x1 << 2)
#define IOC_IRQ_EN_MASK (0x1 << 12)
#define HALTED_MASK     (0x1 << 0)
#define IDLE_MASK       (0x1 << 1)
#define IOC_IRQ_MASK    (0x1 << 12)
#define LENGTH_MASK     (0x3FFFFFF)

#define RAD_PIX_MASK   0x80000000

bool ip_calculation_finished = false;


tb::tb(sc_module_name name) : sc_module(name), mm2s_irq_in("mm2s_port"), s2mm_irq_in("s2mm_port") {

  SC_THREAD(test);

  SC_METHOD(mm2s_irq_method);
  dont_initialize();
  sensitive << mm2s_irq_in.pos();

  SC_METHOD(s2mm_irq_method);
  dont_initialize();
  sensitive << s2mm_irq_in.pos();

  SC_REPORT_INFO("TB", "TB constructed");
}

void tb::test() {
  SC_REPORT_INFO("TB", "TEST STARTED");
  sc_time delay(0, SC_NS);
  sc_time zero(0, SC_NS);
  tlm_utils::tlm_quantumkeeper qk;
  qk.reset();

  sc_dt::sc_uint<32> radius; //variable for the size of the radius(in pixels, is entered via the terminal)
  Mat image, edge, imgBlur;  
  int length, width, x, y;
  int count = 0; //counting number of white pix after processing image with cany algorithm
  //variables needed for counting circles 
  int num_circles = 0;
  int flag = 1;
  int prev_max_el = 0;
  int max_el;
  int ym, xm;
  vector<sc_dt::sc_uint<32>> arr_white_pix(1); //array for containing position of white pixels
  
  // open the image 
  image = imread(image_path, 1);
    
  medianBlur(image, imgBlur, 5); //blur the image to smooth out edges that create noise

  Canny(imgBlur, edge, 150, 380); //Canny edge detection

  //extracting the size of the image
  width = edge.cols;
  length = edge.rows;
  printf("length= %d\n", length);
  printf("width= %d\n", width);

  //Read the radius from the command line
  radius = stoi(rad);

  //counting number of white pix after processing image with cany algorithm and places their positions in array 
  for(y = 0; y < length; y++){
    for(x = 0; x < width; x++){
      if(edge.at<uchar>(y, x) != 0){
        arr_white_pix[count] = 0;
        arr_white_pix[count] = x; //lower 10 bits : x value of the pixel
        arr_white_pix[count] |= y << 10; //next 10 bits : y value of the pixel  
        count++;
        arr_white_pix.resize(1 + count);
      }
    }
  }     

  //the first data we transfer is the radius
  pl_t pl;
  sc_dt::sc_uint<32> mem_wdata = 0; 
  mem_wdata |= RAD_PIX_MASK;
  mem_wdata |= radius;  
  sc_dt::uint64 waddr = 0; //write it to the first location in RAM

  pl.set_command(TLM_WRITE_COMMAND);
  pl.set_data_ptr((unsigned char*) &mem_wdata);
  pl.set_address(waddr);
  pl.set_data_length(1);

  cpu_mem_isoc -> b_transport(pl, delay);
  qk.set_and_sync(delay);
  delay = zero;

  //now we transfer data of position pixels
  for(int i = 0;i < count;i++){
    mem_wdata = 0;  
    //set data  
    mem_wdata = arr_white_pix[i];
    //set the address
    waddr = i + 1;
    pl.set_address(waddr);

    cpu_mem_isoc -> b_transport(pl, delay);
    qk.set_and_sync(delay);
    delay = zero;
  }

  //NOW WE SET THE REGISTERS OF THE DMA
  //FIRST THE MM2S CHANNEL
  sc_dt::sc_uint<32> mm2s_dmacr_val;
  pl.set_command(TLM_WRITE_COMMAND);
  pl.set_data_ptr((unsigned char*) &mm2s_dmacr_val);
  pl.set_address(VP_ADDR_AXI + MM2S_DMACR_OFFSET);
  //SET THE RUN/STOP BIT TO 1
  mm2s_dmacr_val |= RS_MASK;
  //SET THE IOC IRQ EN BIT TO 1
  mm2s_dmacr_val |= IOC_IRQ_EN_MASK;

  cpu_bus_isoc -> b_transport(pl, delay);
  qk.set_and_sync(delay);

  delay = zero;

  //SET THE SOURCE ADDRESS REGISTER
  pl.set_command(TLM_WRITE_COMMAND);
  sc_dt::sc_uint<32> source_address = 0; //the first location in the RAM where the data is written
  pl.set_address(VP_ADDR_AXI + MM2S_SA_OFFSET);
  pl.set_data_ptr((unsigned char*) &source_address);

  cpu_bus_isoc -> b_transport(pl, delay);
  qk.set_and_sync(delay);
  delay = zero;

  //NOW WE DO THE SAME FOR THE S2MM CHANNEL
  sc_dt::sc_uint<32> s2mm_dmacr_val = 0x00010002;
  s2mm_dmacr_val |= RS_MASK;
  s2mm_dmacr_val |= IOC_IRQ_EN_MASK;
  pl.set_address(VP_ADDR_AXI + S2MM_DMACR_OFFSET);
  pl.set_data_ptr((unsigned char*) &s2mm_dmacr_val);

  cpu_bus_isoc -> b_transport(pl, delay);
  qk.set_and_sync(delay);
  delay = zero;

  //SET THE DESTINATION ADDRESS REGISTER
  sc_dt::sc_uint<32> destination_address = count + 1; //the first free location in RAM, after acomodation position of pixels
  pl.set_data_ptr((unsigned char*) &destination_address);
  pl.set_address(VP_ADDR_AXI + S2MM_DA_OFFSET);

  cpu_bus_isoc -> b_transport(pl, delay);
  qk.set_and_sync(delay);
  delay = zero;

  //THE LAST STEP : SET BOTH LENGTH REGISTERS
  sc_dt::sc_uint<32> mm2s_length_val = (count + 1) * 4; //number of white pixels positions + one for radius, each 4 bytes
  pl.set_data_ptr((unsigned char*) &mm2s_length_val);
  pl.set_address(VP_ADDR_AXI + MM2S_LENGTH_OFFSET);

  cpu_bus_isoc -> b_transport(pl, delay);
  qk.set_and_sync(delay);
  delay = zero;

  sc_dt::sc_uint<32> s2mm_length_val = count * 360 * 4; //360 dots around the pixel, each 4 bytes
  pl.set_data_ptr((unsigned char*) &s2mm_length_val);
  pl.set_address(VP_ADDR_AXI + S2MM_LENGTH_OFFSET);

  cpu_bus_isoc -> b_transport(pl, delay);
  qk.set_and_sync(delay);
  delay = zero;

  // READ MEMORY AND CREATED ACCUMULATION MATRIX  
  sc_dt::sc_uint<64> raddr = 0;
  sc_dt::sc_uint<32> mem_rdata = 0;
  raddr = count + 1;
  sc_time clk_period(10, SC_NS);

  pl.set_command(TLM_READ_COMMAND);
  pl.set_data_ptr((unsigned char*) &mem_rdata); 

  Mat acc = Mat::zeros(length, width, CV_16UC1); //initialization matrix of accumulation
  bool out_of_bounds = false; //indicates whether the calculated position is in image bounds

  //wait until the IP finished calculating every pixel
  while(!ip_calculation_finished)
    qk.set_and_sync(clk_period);

  for(int i = 0;i < count * 360;i++){   
    pl.set_address(raddr + i);
    pl.set_data_length(1);

    cpu_mem_isoc -> b_transport(pl, delay);
    qk.set_and_sync(delay);
    delay = clk_period;

    x = mem_rdata & 0x000003FF;
    y = (mem_rdata & 0x000FFC00) >> 10;

    //checks the VALID_PIX mask for underflow, and checks whether the result is in image bounds
    if((mem_rdata & 0x80000000) || (x >= width) || (y >= length))
      out_of_bounds = true;

    if(!out_of_bounds)
      acc.at<short int>(y, x) += 1;

    out_of_bounds = false;
  }

  // NOW WE FIND NUMBER OF CIRCLES
  while(flag){
    num_circles += 1;
    max_el = 0;
    //seeks the maximum element
    for(y = 0; y < length; y++){
      for(x = 0; x < width; x++){
        if(max_el < acc.at<short int>(y, x)){
          max_el = acc.at<short int>(y, x);
          ym = y;
          xm = x; 
        }
      }
    }
    cout<<"max_el= "<<max_el<<endl;
    //deletes the maximum element and 7x7 pixels around it
    for(y = ym - 3; y <= ym + 3; y++){
      for(x = xm  - 3; x <= xm + 3; x++){
        if((x < width && x >= 0) && (y < length && y >= 0)){
          acc.at<short int>(y, x) = 0;
          // cooloring center of circles
          if(prev_max_el * 0.60 < max_el){
            Vec3b color = image.at<Vec3b>(y, x);
            color[0] = 0;
            color[1] = 255;
            color[2] = 0;
            image.at<Vec3b>(y, x) = color;
          }
        }
      }
    }
    //threshold based on when deciding whether the maximum is the center of the circle
    if(prev_max_el * 0.60 > max_el){
      flag = 0;
      num_circles -= 1; 
    }
    if(num_circles > 7){
      flag = 0;
      cout << "Something is wrong, invalid radius size" << endl;
    }
    prev_max_el = max_el;
  }

  cout<<"Num_circles= "<<num_circles<<endl;

  imshow("Marked centers of detected circles", image); // displays the image
  waitKey(0);
  destroyAllWindows(); 
}

//DEASERTED IOC_IRQ BIT AFTER FINISHING MM2S PROCESS
void tb::mm2s_irq_method() {
  sc_time delay(0, SC_NS);

  pl_t pl;
  sc_dt::sc_uint<32> mm2s_dmasr_val = IOC_IRQ_MASK;
  sc_dt::uint64 addr = VP_ADDR_AXI + MM2S_DMASR_OFFSET;

  pl.set_command(TLM_WRITE_COMMAND);
  pl.set_data_ptr((unsigned char*) &mm2s_dmasr_val);
  pl.set_data_length(1);
  pl.set_address(addr);

  cpu_bus_isoc -> b_transport(pl, delay);
}

//DEASERTED IOC_IRQ BIT AFTER FINISHING S2MM PROCESS
void tb::s2mm_irq_method() {
  sc_time delay(0, SC_NS);

  pl_t pl;
  sc_dt::sc_uint<32> s2mm_dmasr_val = IOC_IRQ_MASK;
  sc_dt::uint64 addr = VP_ADDR_AXI + S2MM_DMASR_OFFSET;

  pl.set_command(TLM_WRITE_COMMAND);
  pl.set_data_ptr((unsigned char*) &s2mm_dmasr_val);
  pl.set_data_length(1);
  pl.set_address(addr);

  cpu_bus_isoc -> b_transport(pl, delay);

  ip_calculation_finished = true;
}
