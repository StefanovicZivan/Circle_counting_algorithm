#include <systemc>
#include "tb.hpp"
#include "vp.hpp"

#include <opencv2/highgui.hpp>
#include <opencv2/imgproc.hpp>
#include <opencv2/core.hpp>
#include <iostream>
#include <string>

using namespace std;
using namespace cv; 

using namespace sc_core;

int sc_main(int argc, char* argv[]) {
	
	Mat im;
	vp v("vp");
  SC_REPORT_INFO("MAIN", "VP CONSTRUCTED");
 	tb t("tb");
  SC_REPORT_INFO("MAIN", "TB CONSTRUCTED");
  SC_REPORT_INFO("MAIN", "Clock frequency : 100MHz");
	t.cpu_bus_isoc.bind(v.cpu_bus_tsoc);
	t.cpu_mem_isoc.bind(v.cpu_mem_tsoc);

	t.mm2s_irq_in.bind(v.mm2s_irq_vp_pexp);
	t.s2mm_irq_in(v.s2mm_irq_vp_pexp);

	if(argc == 3){
	  t.image_path = argv[1];
	  t.rad = argv[2];
	}
	else{
	  cout << "Please enter a valid path to an image and correct size of radius for circle detection in pixels" << endl;
	  cout << "Example : ./main_prog ../data/filename.png 29" << endl;
	  return -1;
	}
	if(!(im = imread(argv[1], 1)).data){
	  cout << "Invalid file name, please enter a valid path to an image" << endl;
      cout << "Example : ./main_prog ../data/filename.png 29" << endl;
	  return -1;
	}
	
  sc_start(40, SC_MS);

  return 0;
}
