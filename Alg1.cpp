#include <opencv2/highgui.hpp>
#include "opencv2/imgproc.hpp"
#include "opencv2/imgcodecs.hpp"
#include <iostream>
#include <string>
#include <math.h>
#include <stdint.h>

using namespace std;
using namespace cv; 

int main( int argc, char** argv ) {
  
  Mat image, imgBlur, edge;
  int r_min, r_max, max_el, prev_max_el;
  int length, width, r;
  int y, x, a, b;
  Mat acc, right_acc;
  int num_circles, flag, ym, xm;
  
  image = imread("kockica12.PNG" , 0);
  if(! image.data ) {
    cout <<  "Could not open or find the image" << endl ;
    return -1;
  }
  medianBlur(image, imgBlur, 5);
  Canny(imgBlur, edge, 100, 200);
 
  width = edge.cols;
  length = edge.rows;
  printf("length= %d\n", length);
  printf("width= %d\n", width);

  r_min = 5;
  r_max = 9;

  max_el = 0;
  prev_max_el = 0;
  for(r = r_min; r <= r_max; r++){
    acc = Mat::zeros(length,width,CV_32F);  
    for(y = 0; y < length; y++){
      for(x = 0; x < width; x++){
        if(edge.at<int>(y, x) != 0){
	  for(int theta = 0; theta <= 360; theta++){
	    a = (x - r * cos(theta * M_PI / 180));
            b = (y - r * sin(theta * M_PI / 180));
	    if(a < width && a >= 0 && b < length && b >= 0 ){
	      acc.at<int>(b, a) += 1;
	    }
	  }
	}
      }
    } 
    cout<<"Finished one accumulator matrix"<<endl;
    
    for(y = 0; y < length; y++){
      for(x = 0; x < width; x++){
  	if(max_el < acc.at<int>(y, x)){
	  max_el = acc.at<int>(y, x);
	}
      }
    }	

    if(prev_max_el < max_el){
      right_acc = acc;
    }
    cout<<"max_el= "<<max_el<<endl;
    prev_max_el = max_el;
  }

  cout<<"-----------------------------------------------------------"<<endl;  
  
  num_circles = 0;
  flag = 1;
  prev_max_el = 0;
  while(flag){
    num_circles += 1;
    max_el = 0;
    for(y = 0; y < length; y++){
      for(x = 0; x < width; x++){
	if(max_el < right_acc.at<int>(y, x)){
	  max_el = right_acc.at<int>(y, x);
	    ym = y;
	    xm = x;	
	}
      }
    }
    cout<<"max_el= "<<max_el<<endl;

    for(y = ym - 5; y <= ym + 5; y++){
      for(x = xm  - 5; x <= xm + 5; x++){
	if(x < width && x >= 0 && y < length && y >= 0 ){
	  right_acc.at<int>(y, x) = 0;
	}
      }
    }
    
    if(prev_max_el * 0.65 > max_el){
      flag = 0;
      num_circles -= 1; 
    }
    prev_max_el = max_el;
  }

  cout<<"num_circles= "<<num_circles<<endl;

  imshow("Canny_edge", edge);
  waitKey(0);
  destroyAllWindows();
  
  return 0;
}
