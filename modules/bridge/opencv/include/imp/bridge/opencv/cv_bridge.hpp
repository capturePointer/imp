#ifndef IMP_OPENCV_BRIDGE_HPP
#define IMP_OPENCV_BRIDGE_HPP

#include <memory>

#include <opencv2/highgui/highgui.hpp>
#include <opencv2/imgproc/imgproc.hpp>
#include <imp/core/image_cv.hpp>

namespace imp {

//------------------------------------------------------------------------------
template<typename Pixel, imp::PixelType pixel_type>
void cvBridgeLoad(ImageCvPtr<Pixel,pixel_type>& out,
                  const std::string& filename, imp::PixelOrder pixel_order)
{
  cv::Mat mat;
  if (pixel_order == PixelOrder::gray)
  {
    mat = cv::imread(filename, CV_LOAD_IMAGE_GRAYSCALE);
  }
  else
  {
    // everything else needs color information :)
    mat = cv::imread(filename, CV_LOAD_IMAGE_COLOR);
  }

  switch(pixel_type)
  {
  case imp::PixelType::i8uC1:
    if (pixel_order == PixelOrder::gray)
    {
      out = std::make_shared<ImageCv<Pixel,pixel_type>>(mat);
    }
    else
    {
      out = std::make_shared<ImageCv<Pixel,pixel_type>>(mat.cols, mat.rows);
      cv::cvtColor(mat, out->cvMat(), CV_BGR2GRAY);
    }
  break;
  case imp::PixelType::i32fC1:
    out = std::make_shared<ImageCv<Pixel,pixel_type>>(mat.cols, mat.rows);
    if (mat.channels() > 1)
    {
      cv::cvtColor(mat, mat, CV_BGR2GRAY);
    }
    mat.convertTo(out->cvMat(), CV_32F, 1./255.);
  break;
  default:
    throw imp::Exception("Conversion for reading given pixel_type not supported yet.", __FILE__, __FUNCTION__, __LINE__);
  }
}

//------------------------------------------------------------------------------
template<typename Pixel, imp::PixelType pixel_type>
void cvBridgeSave(const std::string& filename, const ImageCv<Pixel,pixel_type>& img, bool normalize=false)
{
  if (normalize)
  {
    // TODO
  }
  cv::imwrite(filename, img.cvMat());
}

//------------------------------------------------------------------------------
template<typename Pixel, imp::PixelType pixel_type>
void cvBridgeShow(const std::string& winname, const ImageCv<Pixel,pixel_type>& img,
                   bool normalize=false)
{
  if (normalize)
  {
    int mat_type = (img.nChannels() > 1) ? CV_8UC3 : CV_8UC1;
    cv::Mat norm_mat(img.height(), img.width(), mat_type);
    cv::normalize(img.cvMat(), norm_mat, 0, 255, CV_MINMAX, CV_8U);
    cv::imshow(winname, norm_mat);
  }
  else
  {
    cv::imshow(winname, img.cvMat());
  }
}


//------------------------------------------------------------------------------
//enum class OcvBridgeLoadAs
//{
//  raw,
//  cuda,
//  cvmat
//};
//
//template<typename Pixel, imp::PixelType pixel_type>
//std::shared_ptr<> ocv_bridge_imread(const std::string& filename, OcvBridgeLoadAs load_as=OcvBridgeLoadAs::raw)
//{
//  switch (load_as)
//  {
//  case OcvBridgeLoadAs::cvmat:
//    break;
//  case OcvBridgeLoadAs::cuda:
//    break;
//  case OcvBridgeLoadAs::raw:
//  default:
//    break;

//  }
//}


} // namespace imp

#endif // IMP_OPENCV_BRIDGE_HPP
