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
 * Module      : Filter
 * Class       : none
 * Language    : CUDA
 * Description : Definition of CUDA wrappers for filter functions on Npp images
 *
 * Author     : Manuel Werlberger
 * EMail      : werlberger@icg.tugraz.at
 *
 */

#ifndef IUPRIVATE_FILTER_CUH
#define IUPRIVATE_FILTER_CUH

#include <iucore/coredefs.h>
#include <iucore/memorydefs.h>

namespace iuprivate {

// cuda wrapper: median filter; 32-bit; 1-channel
IuStatus cuFilterMedian3x3(const iu::ImageGpu_32f_C1* src, iu::ImageGpu_32f_C1* dst,
                            const IuRect& roi);

// cuda wrapper: Gaussian filter; 32-bit; 1-channel
IuStatus cuFilterGauss(const iu::ImageGpu_32f_C1* src, iu::ImageGpu_32f_C1* dst,
                        const IuRect& roi, float sigma, int kernel_size);

// cuda wrapper: Rof filter; 32-bit; 1-channel
IuStatus cuFilterRof(const iu::ImageGpu_32f_C1* src, iu::ImageGpu_32f_C1* dst,
                      const IuRect& roi, float lambda, int iterations);

} // namespace iuprivate

#endif // IUPRIVATE_FILTER_CUH
