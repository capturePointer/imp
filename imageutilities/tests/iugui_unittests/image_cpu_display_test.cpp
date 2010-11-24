
#include <iostream>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <QApplication>

#include <GL/glew.h>
#include <cuda_runtime.h>
#include <iu/iucore.h>
#include <iu/iuio.h>
#include <iu/iugui.h>

int main(int argc, char **argv)
{
  if(argc < 2)
  {
    std::cout << "usage: gl_display_test image_filename1 inmage_filename2" << std::endl;
    exit(EXIT_FAILURE);
  }
  printf("start gl test\n");

  QApplication app(argc, argv);

  // First load the image, so we know what the size of the image (imageW and imageH)
  printf("Allocating host and CUDA memory and loading image file...\n");
  std::string in_file = argv[1];
  std::string in_file2 = argv[2];
  std::cout << "reading " << in_file << std::endl;

  iu::ImageCpu_8u_C1* image_8u_C1 = iu::imread_8u_C1(in_file);
  iu::ImageCpu_32f_C1* image_32f_C1 = iu::imread_32f_C1(in_file);
  iu::ImageCpu_8u_C4* image_8u_C4 = iu::imread_8u_C4(in_file);
  iu::ImageCpu_32f_C4* image_32f_C4 = iu::imread_32f_C4(in_file);
  iu::imshow(image_8u_C1, "input image");

  double time = iu::getTime();
  iu::QImageCpuDisplay im_display_8u_C1(image_8u_C1, "cpu image 8u C1");
  im_display_8u_C1.show();
  std::cout << "display create/show/close takes " << (iu::getTime()-time) << "ms" << std::endl;

  time = iu::getTime();
  iu::QImageCpuDisplay im_display_8u_C4(image_8u_C4, "cpu image 8u C4");
  im_display_8u_C4.show();
  std::cout << "display create/show/close takes " << (iu::getTime()-time) << "ms" << std::endl;

  time = iu::getTime();
  iu::QImageCpuDisplay im_display_32f_C1(image_32f_C1, "cpu image 32f C1");
  im_display_32f_C1.show();
  std::cout << "display create/show/close takes " << (iu::getTime()-time) << "ms" << std::endl;

  time = iu::getTime();
  iu::QImageCpuDisplay im_display_32f_C4(image_32f_C4, "cpu image 32f C4");
  im_display_32f_C4.show();
  std::cout << "display create/show/close takes " << (iu::getTime()-time) << "ms" << std::endl;

  // update test
  std::cout << "reading " << in_file2 << std::endl;
  iu::ImageCpu_8u_C1* image2_8u_C1 = iu::imread_8u_C1(in_file2);
  im_display_8u_C1.updateImage(image2_8u_C1);


  app.exec();

  delete(image_8u_C1);
  delete(image_8u_C4);
  delete(image_32f_C1);
  delete(image_32f_C4);

  cudaThreadExit();
  return(EXIT_SUCCESS);
}
