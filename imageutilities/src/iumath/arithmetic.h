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
 * Module      : Math
 * Class       : none
 * Language    : C++
 * Description : Definition of arithmetic functions
 *
 * Author     : Manuel Werlberger
 * EMail      : werlberger@icg.tugraz.at
 *
 */

#ifndef IUMATH_ARITHMETIC_H
#define IUMATH_ARITHMETIC_H

#include <iucore/coredefs.h>
#include <iucore/memorydefs.h>

namespace iuprivate {

/** Adding an image with an additional weighting factor to another.
 * \param src1 Source image 1.
 * \param src2 Source image 2.
 * \param weight Weighting of image 2 before its added to image 1.
 * \param dst Result image dst=weight1*src1 + weight1*src2.
 * \param roi Region of interest in the source and destination image
 */
// [device] weighted add; Not-in-place; 32-bit;
void addWeighted(const iu::ImageGpu_32f_C1* src1, const float& weight1,
                 const iu::ImageGpu_32f_C1* src2, const float& weight2,
                 iu::ImageGpu_32f_C1* dst, const IuRect& roi);

/** Not-in-place multiplication of every pixel with a constant factor.
 * \param src Source image.
 * \param factor Multiplication factor applied to each pixel.
 * \param dst Destination image.
 * \param roi Region of interest in the source and destination image
 */
// [gpu] multiplication with factor; Not-in-place; 8-bit;
void mulC(const iu::ImageGpu_8u_C1* src, const unsigned char& factor, iu::ImageGpu_8u_C1* dst, const IuRect& roi);
void mulC(const iu::ImageGpu_8u_C4* src, const uchar4& factor, iu::ImageGpu_8u_C4* dst, const IuRect& roi);

// [gpu] multiplication with factor; Not-in-place; 32-bit;
void mulC(const iu::ImageGpu_32f_C1* src, const float& factor, iu::ImageGpu_32f_C1* dst, const IuRect& roi);
void mulC(const iu::ImageGpu_32f_C2* src, const float2& factor, iu::ImageGpu_32f_C2* dst, const IuRect& roi);
void mulC(const iu::ImageGpu_32f_C4* src, const float4& factor, iu::ImageGpu_32f_C4* dst, const IuRect& roi);

/** In-place multiplication of every pixel with a constant factor.
 * \param factor Multiplication factor applied to each pixel.
 * \param srcdst Source and destination
 * \param roi Region of interest in the source/destination image
 *
 * \note supported gpu: 8u_C1, 8u_C4, 32f_C1, 32f_C4,
 */
// multiplication with factor; host; 8-bit




} // namespace iuprivate

#endif // IUMATH_ARITHMETIC_H
