/*
 * Copyright (c) ICG. All rights reserved.
 *
 * Institute for Computer Graphics and Vision
 * Graz University of Technology / Austria
 *
 *
 * This software is distributed WITHOUT ANY WARRANTY; without even
 * the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
 * PURPOSE.  See the above copyright notices for more information.
 *
 *
 * Project     : ImageUtilities
 * Module      : Core
 * Class       : ImagePyramid
 * Language    : C++
 * Description : Implementation of multiresolution imagepyramid
 *
 * Author     : Manuel Werlberger
 * EMail      : werlberger@icg.tugraz.at
 *
 */

#include <math.h>
#include <vector>
#include "coredefs.h"
#include "memorydefs.h"
#include "iutransform/reduce.h"
#include "copy.h"
#include "imagepyramid.h"


// switch pyramid creation scheme
// 1 - use preallocated device memory for temporary variables in downsampling procedure (gauss filter...)
// 0 - allocate temporary variables on the fly as needed
// preallocated memory is quite a bit faster (3ms vs 11.8ms for 640x480, scalefactor 0.85, GTX680),
// on the downside memory is kept until the end of the pyramid lifecycle.
// On the fly memory is freed immediately.
// Uses roughly 2 times pyramid size of memory
#define FAST_REDUCE 1

namespace iu {

//---------------------------------------------------------------------------
ImagePyramid::ImagePyramid() :
  images_(0), temp_images_(0), temp_filter_images_(0), pixel_type_(IU_UNKNOWN_PIXEL_TYPE),
  scale_factors_(0), num_levels_(0), max_num_levels_(0), scale_factor_(0.0f), size_bound_(0),
  adaptive_scale_(false)
{
}

//---------------------------------------------------------------------------
ImagePyramid::ImagePyramid(unsigned int& max_num_levels, const IuSize& size, const float& scale_factor,
                           unsigned int size_bound) :
  images_(0), pixel_type_(IU_UNKNOWN_PIXEL_TYPE), scale_factors_(0), num_levels_(0),
  max_num_levels_(0), scale_factor_(0.0f), size_bound_(0), adaptive_scale_(false)
{
  max_num_levels = this->init(max_num_levels, size, scale_factor, size_bound);
}

//---------------------------------------------------------------------------
ImagePyramid::ImagePyramid(unsigned int num_levels, const float* scale_factors) :
  images_(0), pixel_type_(IU_UNKNOWN_PIXEL_TYPE), scale_factors_(0), num_levels_(0),
  max_num_levels_(0), scale_factor_(0.0f), size_bound_(0), adaptive_scale_(true)
{
  this->init(num_levels, scale_factors);
}

//---------------------------------------------------------------------------
ImagePyramid::~ImagePyramid()
{
  this->reset();
}

//---------------------------------------------------------------------------
unsigned int ImagePyramid::init(unsigned int max_num_levels, const IuSize& size,
                                const float& scale_factor, unsigned int size_bound)
{
  if ((scale_factor <= 0) || (scale_factor >=1))
  {
    throw IuException("scale_factor out of range; must be in interval ]0,1[.", __FILE__, __FUNCTION__, __LINE__);
  }

  if (images_ != 0)
    this->reset();

  adaptive_scale_ = false;
  max_num_levels_ = IUMAX(1u, max_num_levels);
  num_levels_ = max_num_levels_;
  size_bound_ = IUMAX(1u, size_bound);

  unsigned int shorter_side = IUMIN(size.width, size.height);

  // calculate the maximum number of levels
  float ratio = static_cast<float>(shorter_side)/static_cast<float>(size_bound_);
  // +1 because the original size is level 0
  unsigned int possible_num_levels = static_cast<int>(
        -logf(ratio)/logf(scale_factor)) + 1;
  if(num_levels_ > possible_num_levels)
    num_levels_ = possible_num_levels;

  // init rate for each level
  scale_factors_ = new float[num_levels_];
  for (unsigned int i=0; i<num_levels_; i++)
  {
    scale_factors_[i] = pow(scale_factor, static_cast<float>(i));
  }

  return num_levels_;
}

unsigned int ImagePyramid::init(unsigned int num_levels, const float* scale_factors)
{

  if (num_levels < 1) 
	  throw IuException("num_levels out of range (<1)", __FILE__, __FUNCTION__, __LINE__ );

  for( unsigned int i = 0; i < num_levels; ++i )
  {
    if ((scale_factors[i] <= 0) || (scale_factors[i] >1))
    {
      printf("Error: Pyramid::Init() level %d\n", i);
      throw IuException("scale_factor out of range; must be in interval ]0,1[.", __FILE__, __FUNCTION__, __LINE__);
    }
  }

  if (images_ != 0)
    this->reset();

  adaptive_scale_ = true;
  max_num_levels_ = num_levels;
  num_levels_ = max_num_levels_;
  scale_factors_ = new float[num_levels_];

  memcpy( scale_factors_, scale_factors, sizeof(float)*num_levels);
  return num_levels;
}


//---------------------------------------------------------------------------
/** Resets the image pyramid. Deletes all the data.
   */
void ImagePyramid::reset()
{
  if(images_ != 0)
  {
    // delete all arrays and hold elements!
    for (unsigned int i=0; i<num_levels_; i++)
    {
      delete(images_[i]);
#if FAST_REDUCE
      delete(temp_images_[i]);
      delete(temp_filter_images_[i]);
      temp_images_[i] = 0;
      temp_filter_images_[i] = 0;
#endif
      images_[i] = 0;
    }
  }

  delete[] images_;
#if FAST_REDUCE
  delete[] temp_images_;
  temp_images_ = 0;
  delete[] temp_filter_images_;
  temp_filter_images_ = 0;
#endif
  images_ = 0;

  pixel_type_ = IU_UNKNOWN_PIXEL_TYPE;
  delete[] scale_factors_;
  scale_factors_ = 0;
  num_levels_ = 0;
}

//---------------------------------------------------------------------------
unsigned int ImagePyramid::setImage(iu::Image* image,
                                    IuInterpolationType interp_type, cudaStream_t stream)
{
  if (image == 0)
  {
    throw IuException("Input image is NULL.", __FILE__, __FUNCTION__, __LINE__);
  }
  if (!image->onDevice())
  {
    throw IuException("Currently only device images supported.", __FILE__, __FUNCTION__, __LINE__);
  }

  if ((images_ != 0) && (
        (images_[0]->size() != image->size()) ||
        (images_[0]->pixelType() != image->pixelType()) ))
  {
    this->reset();
    this->init(max_num_levels_, image->size(), scale_factor_, size_bound_);
  }

  pixel_type_ = image->pixelType();
  switch (pixel_type_)
  {
  case IU_32F_C1:
  {
    if (!images_)
      this->alloc(image->size(), IU_32F_C1);

    // *** needed so that always the same mem is used (if already existent)
    iu::ImageGpu_32f_C1*** cur_images = reinterpret_cast<iu::ImageGpu_32f_C1***>(&images_);
#if FAST_REDUCE
    iu::ImageGpu_32f_C1*** temp_cimages = reinterpret_cast<iu::ImageGpu_32f_C1***>(&temp_images_);
    iu::ImageGpu_32f_C1*** temp_filter_cimages = reinterpret_cast<iu::ImageGpu_32f_C1***>(&temp_filter_images_);
#endif
    iuprivate::copy(reinterpret_cast<iu::ImageGpu_32f_C1*>(image), (*cur_images)[0]);
    for (unsigned int i=1; i<num_levels_; i++)
    {
#if FAST_REDUCE
      iuprivate::reduce((*cur_images)[i-1], (*cur_images)[i], (*temp_cimages)[i-1],
          (*temp_filter_cimages)[i-1], stream, interp_type, 1, 0);
#else
      iuprivate::reduce((*cur_images)[i-1], (*cur_images)[i], interp_type, 1, 0);
#endif
    }
    break;
  }
  default:
    throw IuException("Unsupported pixel type. currently supported: 32f_C1", __FILE__, __FUNCTION__, __LINE__);
  }

  return num_levels_;
}


void ImagePyramid::alloc(const IuSize &sz, const IuPixelType &type)
{
  switch(type)
  {
  case IU_32F_C1:
  {
    iu::ImageGpu_32f_C1*** cur_images = reinterpret_cast<iu::ImageGpu_32f_C1***>(&images_);
#if FAST_REDUCE
    iu::ImageGpu_32f_C1*** temp_cimages = reinterpret_cast<iu::ImageGpu_32f_C1***>(&temp_images_);
    iu::ImageGpu_32f_C1*** temp_filter_cimages = reinterpret_cast<iu::ImageGpu_32f_C1***>(&temp_filter_images_);
    (*temp_cimages) = new iu::ImageGpu_32f_C1*[num_levels_];
    (*temp_filter_cimages) = new iu::ImageGpu_32f_C1*[num_levels_];
#endif
    (*cur_images) = new iu::ImageGpu_32f_C1*[num_levels_];
    for (unsigned int i=0; i<num_levels_; i++)
    {
      (*cur_images)[i] = new iu::ImageGpu_32f_C1( sz * scale_factors_[i] );
#if FAST_REDUCE
      (*temp_cimages)[i] = new iu::ImageGpu_32f_C1( sz * scale_factors_[i] );
      (*temp_filter_cimages)[i] = new iu::ImageGpu_32f_C1( sz * scale_factors_[i] );
#endif
    }
    break;
  }

  default:
    throw IuException("Unsupported pixel type. currently supported: 32f_C1", __FILE__, __FUNCTION__, __LINE__);
  }


}

} // namespace iu

