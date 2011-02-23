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
 * Module      : Geometric Transformation
 * Class       : none
 * Language    : CUDA
 * Description : Implementation of CUDA wrappers for remap operations
 *
 * Author     : Manuel Werlberger
 * EMail      : werlberger@icg.tugraz.at
 *
 */

#include <iostream>
#include <iudefs.h>
#include <iucutil.h>
#include <iucore/iutextures.cuh>

#ifndef IUTRANSFORM_REMAP_CU
#define IUTRANSFORM_REMAP_CU

namespace iuprivate {

// local textures
texture<float, 2, cudaReadModeElementType> tex_remap_dx_32f_C1__;
texture<float, 2, cudaReadModeElementType> tex_remap_dy_32f_C1__;

/** Remap input image (tex1) with disparities (tex_remap_dx, tex_remap_dy). */
// linear interpolation
__global__ void cuRemapKernel_32f_C1(float *dst, size_t stride, int width, int height)
{
  const int x = blockIdx.x*blockDim.x + threadIdx.x;
  const int y = blockIdx.y*blockDim.y + threadIdx.y;

  // texutre coordinates
  const float xx = x+0.5f;
  const float yy = y+0.5f;
  // warped texutre coordinates
  const float wx = xx + tex2D(tex_remap_dx_32f_C1__, xx, yy);
  const float wy = yy + tex2D(tex_remap_dy_32f_C1__, xx, yy);

  if (x<width && y<height) // Check if out coordinates lie inside output image
  {
    dst[y*stride+x] = tex2D(tex1_32f_C1__, wx, wy);
  }
}
// cubic interpolation
__global__ void cuRemapCubicKernel_32f_C1(float *dst, size_t stride, int width, int height)
{
  const int x = blockIdx.x*blockDim.x + threadIdx.x;
  const int y = blockIdx.y*blockDim.y + threadIdx.y;

  // texutre coordinates
  const float xx = x+0.5f;
  const float yy = y+0.5f;
  // warped texutre coordinates
  const float wx = xx + tex2D(tex_remap_dx_32f_C1__, xx, yy);
  const float wy = yy + tex2D(tex_remap_dy_32f_C1__, xx, yy);

  if (x<width && y<height) // Check if out coordinates lie inside output image
  {
    dst[y*stride+x] = iu::cubicTex2DSimple(tex1_32f_C1__, wx, wy);
  }
}
// cubic spline interpolation
__global__ void cuRemapCubicSplineKernel_32f_C1(float *dst, size_t stride, int width, int height)
{
  const int x = blockIdx.x*blockDim.x + threadIdx.x;
  const int y = blockIdx.y*blockDim.y + threadIdx.y;

  // texutre coordinates
  const float xx = x+0.5f;
  const float yy = y+0.5f;
  // warped texutre coordinates
  const float wx = xx + tex2D(tex_remap_dx_32f_C1__, xx, yy);
  const float wy = yy + tex2D(tex_remap_dy_32f_C1__, xx, yy);

  if (x<width && y<height) // Check if out coordinates lie inside output image
  {
    dst[y*stride+x] = iu::cubicTex2D(tex1_32f_C1__, wx, wy);
  }
}

//-----------------------------------------------------------------------------
IuStatus cuRemap(iu::ImageGpu_32f_C1* src,
                 iu::ImageGpu_32f_C1* dx_map, iu::ImageGpu_32f_C1* dy_map,
                 iu::ImageGpu_32f_C1* dst, IuInterpolationType interpolation)
{
  tex1_32f_C1__.addressMode[0] = cudaAddressModeClamp;
  tex1_32f_C1__.addressMode[1] = cudaAddressModeClamp;
  tex1_32f_C1__.normalized = false;

  tex_remap_dx_32f_C1__.addressMode[0] = cudaAddressModeClamp;
  tex_remap_dx_32f_C1__.addressMode[1] = cudaAddressModeClamp;
  tex_remap_dx_32f_C1__.normalized = false;
  tex_remap_dx_32f_C1__.filterMode = cudaFilterModePoint;

  tex_remap_dy_32f_C1__.addressMode[0] = cudaAddressModeClamp;
  tex_remap_dy_32f_C1__.addressMode[1] = cudaAddressModeClamp;
  tex_remap_dy_32f_C1__.normalized = false;
  tex_remap_dy_32f_C1__.filterMode = cudaFilterModePoint;


  // bind src image to texture and use as input for reduction
  cudaChannelFormatDesc channel_desc = cudaCreateChannelDesc<float>();
  cudaBindTexture2D(0, &tex1_32f_C1__, src->data(), &channel_desc, src->width(), src->height(), src->pitch());
  cudaBindTexture2D(0, &tex_remap_dx_32f_C1__, dx_map->data(), &channel_desc, dx_map->width(), dx_map->height(), dx_map->pitch());
  cudaBindTexture2D(0, &tex_remap_dy_32f_C1__, dy_map->data(), &channel_desc, dy_map->width(), dy_map->height(), dy_map->pitch());

  // fragmentation
  unsigned int block_size = 16;
  dim3 dimBlock(block_size, block_size);
  dim3 dimGridOut(iu::divUp(dst->width(), dimBlock.x), iu::divUp(dst->height(), dimBlock.y));

  switch(interpolation)
  {
  case IU_INTERPOLATE_NEAREST:
  case IU_INTERPOLATE_CUBIC:
  case IU_INTERPOLATE_CUBIC_SPLINE:
    tex1_32f_C1__.filterMode = cudaFilterModePoint;
    break;
  case IU_INTERPOLATE_LINEAR:
    tex1_32f_C1__.filterMode = cudaFilterModeLinear;
    break;
  }

  switch(interpolation)
  {
  case IU_INTERPOLATE_NEAREST:
  case IU_INTERPOLATE_LINEAR: // fallthrough intended
    cuRemapKernel_32f_C1 <<< dimGridOut, dimBlock >>> (
        dst->data(), dst->stride(), dst->width(), dst->height());
    break;
  case IU_INTERPOLATE_CUBIC:
    cuRemapCubicKernel_32f_C1 <<< dimGridOut, dimBlock >>> (
        dst->data(), dst->stride(), dst->width(), dst->height());
    break;
  case IU_INTERPOLATE_CUBIC_SPLINE:
    cuRemapCubicSplineKernel_32f_C1 <<< dimGridOut, dimBlock >>> (
        dst->data(), dst->stride(), dst->width(), dst->height());
    break;
  }

  cudaUnbindTexture(&tex1_32f_C1__);
  cudaUnbindTexture(&tex_remap_dx_32f_C1__);
  cudaUnbindTexture(&tex_remap_dy_32f_C1__);

  return iu::checkCudaErrorState();
}


} // namespace iuprivate

#endif // IUTRANSFORM_REMAP_CU
