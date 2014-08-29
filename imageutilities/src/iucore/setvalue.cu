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
 * Class       : none
 * Language    : C
 * Description : Implementation of CUDA functions to set a value to GPU memory
 *
 * Author     : Manuel Werlberger
 * EMail      : werlberger@icg.tugraz.at
 *
 */


#ifndef IUCORE_SETVALUE_CU
#define IUCORE_SETVALUE_CU

#include "coredefs.h"
#include "memorydefs.h"
#include "iucutil.h"

namespace iuprivate {

/* ****************************************************************************
 *  1D
 * ****************************************************************************/

//-----------------------------------------------------------------------------
// kernel: 1D set values; 1D
template<class T>
__global__ void cuSetValueKernel(T value, T* dst, int length)
{
  int x = blockIdx.x * blockDim.x + threadIdx.x;

  if(x<length)
  {
    dst[x] = value;
  }
}

//-----------------------------------------------------------------------------
// wrapper: set values; 1D; 8-bit
/** Sets values of 1D linear gpu memory.
 * \param value The pixel value to be set.
 * \param buffer Pointer to the buffer
 */
void cuSetValue(const unsigned char& value, iu::LinearDeviceMemory_8u_C1* dst)
{
  // fragmentation
  const unsigned int block_width = 512;
  dim3 dimBlock(block_width, 1, 1);
  dim3 dimGrid(iu::divUp(dst->length(), dimBlock.x), 1);

  cuSetValueKernel <<< dimGrid, dimBlock >>> (
      value, dst->data(), dst->length());

  IU_CUDA_CHECK();
}

//-----------------------------------------------------------------------------
// wrapper: set values; 1D; 32-bit
/** Sets values of 1D linear gpu memory.
 * \param value The pixel value to be set.
 * \param buffer Pointer to the buffer
 */
void cuSetValue(const int& value, iu::LinearDeviceMemory_32s_C1* dst)
{
  // fragmentation
  const unsigned int block_width = 512;
  dim3 dimBlock(block_width, 1, 1);

  int numChunks = iu::divUp(iu::divUp(dst->length(), dimBlock.x), 65535);
  if (numChunks > 1)
  {
    for (int i=0; i < numChunks-1; i++)
    {
      unsigned int globalPos = i*65535*dimBlock.x;        // calculate start index of current chunk
      dim3 dimGrid(65535, 1);                             // max grid dimension
    
      cuSetValueKernel <<< dimGrid, dimBlock >>> (         // kernel writes 65535*dimBlock.x elements
	value, dst->data(globalPos), 65535*dimBlock.x);
    }
    // calculate start index of last chunk
    unsigned int lastChunkStart = (numChunks-1)*65535*dimBlock.x;
    
    // determine grid size
    dim3 dimGrid(iu::divUp(dst->length()-lastChunkStart, dimBlock.x), 1);
    cuSetValueKernel <<< dimGrid, dimBlock >>> (       // kernel writes remaining elements
	value, dst->data(lastChunkStart), dst->length()-lastChunkStart);
  }
  else       // memory is smaller than 65535*dimBlock.x elements
  {
    dim3 dimGrid(iu::divUp(dst->length(), dimBlock.x), 1);
    
    cuSetValueKernel <<< dimGrid, dimBlock >>> (
	value, dst->data(), dst->length());
  }
  IU_CUDA_CHECK();
}

//-----------------------------------------------------------------------------
// wrapper: set values; 1D; 32-bit
/** Sets values of 1D linear gpu memory.
 * \param value The pixel value to be set.
 * \param buffer Pointer to the buffer
 */
void cuSetValue(const float& value, iu::LinearDeviceMemory_32f_C1* dst)
{
  // fragmentation
  const unsigned int block_width = 512;
  dim3 dimBlock(block_width, 1, 1);
  
  // FIXXXME: apply this also to the other setValue() functions
  
  // if memory is too long to be set with a single kernel calculate number of required
  // chunks.
  // Max grid dimension according to cuda pragramming guide: 65535
  int numChunks = iu::divUp(iu::divUp(dst->length(), dimBlock.x), 65535);
  if (numChunks > 1)
  {
    for (int i=0; i < numChunks-1; i++)
    {
      unsigned int globalPos = i*65535*dimBlock.x;        // calculate start index of current chunk
      dim3 dimGrid(65535, 1);                             // max grid dimension
    
      cuSetValueKernel <<< dimGrid, dimBlock >>> (         // kernel writes 65535*dimBlock.x elements
	value, dst->data(globalPos), 65535*dimBlock.x);
    }
    // calculate start index of last chunk
    unsigned int lastChunkStart = (numChunks-1)*65535*dimBlock.x;
    
    // determine grid size
    dim3 dimGrid(iu::divUp(dst->length()-lastChunkStart, dimBlock.x), 1);
    cuSetValueKernel <<< dimGrid, dimBlock >>> (       // kernel writes remaining elements
	value, dst->data(lastChunkStart), dst->length()-lastChunkStart);
  }
  else       // memory is smaller than 65535*dimBlock.x elements
  {
    dim3 dimGrid(iu::divUp(dst->length(), dimBlock.x), 1);
    
    cuSetValueKernel <<< dimGrid, dimBlock >>> (
	value, dst->data(), dst->length());
  }

  IU_CUDA_CHECK();
}


/* ****************************************************************************
 *  2D
 * ****************************************************************************/

//-----------------------------------------------------------------------------
// kernel: 2D set values; multi-channel
template<class T>
__global__ void cuSetValueKernel(T value, T* dst, size_t stride,
                                 int xoff, int yoff, int width, int height)
{
  int x = blockIdx.x*blockDim.x + threadIdx.x;
  int y = blockIdx.y*blockDim.y + threadIdx.y;
  const int c = y*stride+x;

  // add xoff for checks after calculating the output pixel location c
  x+=xoff;
  y+=yoff;

  if(x>=0 && y>=0 && x < xoff+width && y < yoff+height)
  {
    dst[c] = value;
  }
}

//-----------------------------------------------------------------------------
// templated wrapper: set value; 2D;
template<typename PixelType, class Allocator, IuPixelType _pixel_type>
void cuSetValueTemplate(const PixelType &value,
                            iu::ImageGpu<PixelType, Allocator, _pixel_type> *dst,
                            const IuRect& roi, bool useMemset = false)
{
  if (useMemset && roi.width == dst->width() && roi.height == dst->height() &&
      roi.x == 0 && roi.y == 0)
  {
    // if value = 0 use memset() which is a lot faster than the kernel call
    cudaMemset2D(dst->data(), dst->pitch(), 0, dst->width()*sizeof(PixelType), dst->height());
    //printf("using fast memset\n");
  }
  else
  {
    // fragmentation
    const unsigned int block_size = 16;
    dim3 dimBlock(block_size, block_size);
    dim3 dimGrid(iu::divUp(roi.width, dimBlock.x),
		iu::divUp(roi.height, dimBlock.y));
  
    cuSetValueKernel <<< dimGrid, dimBlock >>> (
	value, dst->data(roi.x, roi.y), dst->stride(),
	roi.x, roi.y, roi.width, roi.height);
    //printf("using kernel memset\n");
  }
  IU_CUDA_CHECK();
}

//-----------------------------------------------------------------------------
// specialized wrapper: set values (single value); 2D; 8-bit;
void cuSetValue(const unsigned char& value, iu::ImageGpu_8u_C1 *dst, const IuRect &roi)
{ 
  if (value == 0)
    return cuSetValueTemplate(value, dst, roi, true);
  else
    return cuSetValueTemplate(value, dst, roi);
}
void cuSetValue(const uchar2& value, iu::ImageGpu_8u_C2 *dst, const IuRect &roi)
{ 
  if (value.x == 0 && value.y == 0)
    return cuSetValueTemplate(value, dst, roi, true);
  else
    return cuSetValueTemplate(value, dst, roi); 
}
void cuSetValue(const uchar3& value, iu::ImageGpu_8u_C3 *dst, const IuRect &roi)
{ 
  if (value.x == 0 && value.y == 0 && value.z == 0)
    return cuSetValueTemplate(value, dst, roi, true);
  else
    return cuSetValueTemplate(value, dst, roi); 
}
void cuSetValue(const uchar4& value, iu::ImageGpu_8u_C4 *dst, const IuRect &roi)
{ 
  if (value.x == 0 && value.y == 0 && value.z == 0 && value.w == 0)
    return cuSetValueTemplate(value, dst, roi, true);
  else
    return cuSetValueTemplate(value, dst, roi); 
}
// wrapper: set values (single value); 2D; 32-bit;
void cuSetValue(const int& value, iu::ImageGpu_32s_C1 *dst, const IuRect &roi)
{ return cuSetValueTemplate(value, dst, roi); }
// wrapper: set values (single value); 2D; 32-bit;
void cuSetValue(const float& value, iu::ImageGpu_32f_C1 *dst, const IuRect &roi)
{ 
  if (value == 0)
    return cuSetValueTemplate(value, dst, roi, true);
  else
    return cuSetValueTemplate(value, dst, roi); 
}
void cuSetValue(const float2& value, iu::ImageGpu_32f_C2 *dst, const IuRect &roi)
{ 
  if (value.x == 0 && value.y == 0)
    return cuSetValueTemplate(value, dst, roi, true);
  else
    return cuSetValueTemplate(value, dst, roi); 
}
void cuSetValue(const float3& value, iu::ImageGpu_32f_C3 *dst, const IuRect &roi)
{
  if (value.x == 0 && value.y == 0 && value.z == 0)
    return cuSetValueTemplate(value, dst, roi, true);
  else
    return cuSetValueTemplate(value, dst, roi); 
}
void cuSetValue(const float4& value, iu::ImageGpu_32f_C4 *dst, const IuRect &roi)
{ 
  if (value.x == 0 && value.y == 0 && value.z == 0 && value.w == 0)
    return cuSetValueTemplate(value, dst, roi, true);
  else
    return cuSetValueTemplate(value, dst, roi); 
}


/* ****************************************************************************
 *  3D
 * ****************************************************************************/

//-----------------------------------------------------------------------------
// kernel: 3D set values; multi-channel
template<class T>
__global__ void cuSetValueKernel(T value, T* dst, size_t stride, size_t slice_stride,
                                 int xoff, int yoff, int zoff, int roi_width, int roi_height,
                                 int roi_depth, int width, int height, int depth)
{
  int x = blockIdx.x*blockDim.x + threadIdx.x;
  int y = blockIdx.y*blockDim.y + threadIdx.y;

  const int c =  y*stride+x;

  x+=xoff;
  y+=yoff;

  if(x>=0 && y>=0 && x<min(width,xoff+roi_width) && y<min(height,yoff+roi_height))
  {
    for(int z = 0; z<min(depth-zoff, roi_depth); ++z)
      dst[c+z*slice_stride] = value;
  }
}

//-----------------------------------------------------------------------------
// templated wrapper: set values (single value); 3D; ...
template<typename PixelType, class Allocator, IuPixelType _pixel_type>
void cuSetValueTemplate(const PixelType &value,
                            iu::VolumeGpu<PixelType, Allocator, _pixel_type> *dst,
                            const IuCube& roi, bool useMemset = false)
{
  // fragmentation
  const unsigned int block_size = 16;
  dim3 dimBlock(block_size, block_size);
  dim3 dimGrid(iu::divUp(roi.width, dimBlock.x),
               iu::divUp(roi.height, dimBlock.y));

  if (useMemset)
  {
    // dammit cuda, y u need width in bytes and height & depth in elements???
    cudaPitchedPtr pp = make_cudaPitchedPtr(dst->data(),
                                            dst->pitch(), dst->width()*sizeof(PixelType),
                                            dst->height());
    cudaExtent ex = make_cudaExtent(roi.width*sizeof(PixelType), roi.height, roi.depth);
    cudaMemset3D(pp, 0, ex);
  }
  else
  {
    cuSetValueKernel <<< dimGrid, dimBlock >>> (
      value, dst->data(roi.x, roi.y, roi.z), dst->stride(), dst->slice_stride(),
      roi.x, roi.y, roi.z, roi.width, roi.height, roi.depth, dst->width(), dst->height(),
      dst->depth());
  }

  IU_CUDA_CHECK();
}

//-----------------------------------------------------------------------------
// specialized wrapper: set values (single value); 3D; 8-bit;
void cuSetValue(const unsigned char& value, iu::VolumeGpu_8u_C1 *dst, const IuCube &roi)
{ return cuSetValueTemplate(value, dst, roi); }
void cuSetValue(const uchar2& value, iu::VolumeGpu_8u_C2 *dst, const IuCube &roi)
{ return cuSetValueTemplate(value, dst, roi); }
void cuSetValue(const uchar4& value, iu::VolumeGpu_8u_C4 *dst, const IuCube &roi)
{ return cuSetValueTemplate(value, dst, roi); }
// wrapper: set values (single value); 3D; 32-bit;
void cuSetValue(const float& value, iu::VolumeGpu_32f_C1 *dst, const IuCube &roi)
{
  if (value == 0 && roi.x == 0 && roi.y == 0 && roi.z == 0 && roi.width == dst->width() &&
      roi.height == dst->height() && roi.depth == dst->depth())
    return cuSetValueTemplate(value, dst, roi, true);
  else
    return cuSetValueTemplate(value, dst, roi);
}
void cuSetValue(const unsigned int& value, iu::VolumeGpu_32u_C1 *dst, const IuCube &roi)
{
  if (value == 0 && roi.x == 0 && roi.y == 0 && roi.z == 0 && roi.width == dst->width() &&
      roi.height == dst->height() && roi.depth == dst->depth())
    return cuSetValueTemplate(value, dst, roi, true);
  else
    return cuSetValueTemplate(value, dst, roi);
}
void cuSetValue(const uint2& value, iu::VolumeGpu_32u_C2 *dst, const IuCube &roi)
{
  if (value.x == 0 && value.y == 0 &&  roi.x == 0 && roi.y == 0 && roi.z == 0 && roi.width == dst->width() &&
      roi.height == dst->height() && roi.depth == dst->depth())
    return cuSetValueTemplate(value, dst, roi, true);
  else
    return cuSetValueTemplate(value, dst, roi);
}
void cuSetValue(const uint4& value, iu::VolumeGpu_32u_C4 *dst, const IuCube &roi)
{
  if (value.x == 0 && value.y == 0 && value.z == 0 && value.w == 0 && roi.x == 0 && roi.y == 0 && roi.z == 0 && roi.width == dst->width() &&
      roi.height == dst->height() && roi.depth == dst->depth())
    return cuSetValueTemplate(value, dst, roi, true);
  else
    return cuSetValueTemplate(value, dst, roi);
}
void cuSetValue(const int& value, iu::VolumeGpu_32s_C1 *dst, const IuCube &roi)
{
  if (value == 0 && roi.x == 0 && roi.y == 0 && roi.z == 0 && roi.width == dst->width() &&
      roi.height == dst->height() && roi.depth == dst->depth())
    return cuSetValueTemplate(value, dst, roi, true);
  else
    return cuSetValueTemplate(value, dst, roi);
}
void cuSetValue(const int2& value, iu::VolumeGpu_32s_C2 *dst, const IuCube &roi)
{
  if (value.x == 0 && value.y == 0 &&  roi.x == 0 && roi.y == 0 && roi.z == 0 && roi.width == dst->width() &&
      roi.height == dst->height() && roi.depth == dst->depth())
    return cuSetValueTemplate(value, dst, roi, true);
  else
    return cuSetValueTemplate(value, dst, roi);
}
void cuSetValue(const int4& value, iu::VolumeGpu_32s_C4 *dst, const IuCube &roi)
{
  if (value.x == 0 && value.y == 0 && value.z == 0 && value.w == 0 && roi.x == 0 && roi.y == 0 && roi.z == 0 && roi.width == dst->width() &&
      roi.height == dst->height() && roi.depth == dst->depth())
    return cuSetValueTemplate(value, dst, roi, true);
  else
    return cuSetValueTemplate(value, dst, roi);
}
void cuSetValue(const float2& value, iu::VolumeGpu_32f_C2 *dst, const IuCube &roi)
{ return cuSetValueTemplate(value, dst, roi); }
void cuSetValue(const float4& value, iu::VolumeGpu_32f_C4 *dst, const IuCube &roi)
{ return cuSetValueTemplate(value, dst, roi); }
void cuSetValue(const unsigned short& value, iu::VolumeGpu_16u_C1 *dst, const IuCube &roi)
{ return cuSetValueTemplate(value, dst, roi); }



} // namespace iuprivate

#endif // IUCORE_SETVALUE_CU
