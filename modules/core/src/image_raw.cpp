#include <imp/core/image_raw.hpp>

#include <iostream>

#include <imp/core/exception.hpp>


namespace imp {

//-----------------------------------------------------------------------------
template<typename PixelStorageType, imp::PixelType pixel_type>
ImageRaw<PixelStorageType, pixel_type>::ImageRaw(std::uint32_t width, std::uint32_t height)
  : Base(width, height)
{
  data_.reset(Memory::alignedAlloc(width, height, &pitch_));
}

//-----------------------------------------------------------------------------
template<typename PixelStorageType, imp::PixelType pixel_type>
ImageRaw<PixelStorageType, pixel_type>::ImageRaw(const imp::Size2u& size)
  : Base(size)
{
  data_.reset(Memory::alignedAlloc(size, &pitch_));
}

//-----------------------------------------------------------------------------
template<typename PixelStorageType, imp::PixelType pixel_type>
ImageRaw<PixelStorageType, pixel_type>::ImageRaw(const ImageRaw& from)
  : Base(from)
{
  data_.reset(Memory::alignedAlloc(this->width(), this->height(), &pitch_));
  if (this->bytes() == from.bytes())
  {
    std::cout << "using std::copy" << std::cout;
    std::copy(from.data_.get(), from.data_.get()+from.stride()*from.height(), data_.get());
  }
  else
  {
    std::cout << "pixel-wise copy" << std::cout;
    for (std::uint32_t y=0; y<this->height(); ++y)
    {
      for (std::uint32_t x=0; x<this->width(); ++x)
      {
        data_.get()[y*this->stride()+x] = from[y][x];
      }
    }
  }
}

//-----------------------------------------------------------------------------
template<typename PixelStorageType, imp::PixelType pixel_type>
ImageRaw<PixelStorageType, pixel_type>::ImageRaw(
    pixel_container_t data, std::uint32_t width, std::uint32_t height,
    size_type pitch, bool use_ext_data_pointer)
  : Base(width, height)
{
  if (data == nullptr)
  {
    throw imp::Exception("input data not valid", __FILE__, __FUNCTION__, __LINE__);
  }

  if(use_ext_data_pointer)
  {
    // This uses the external data pointer as internal data pointer.
    auto dealloc_nop = [](pixel_container_t p) { ; };
    data_ = std::unique_ptr<pixel_storage_t, Deallocator>(
          data, Deallocator(dealloc_nop));
    pitch_ = pitch;
  }
  else
  {
    data_.reset(Memory::alignedAlloc(this->width(), this->height(), &pitch_));
    size_type stride = pitch / sizeof(pixel_storage_t);

    if (this->bytes() == pitch*height)
    {
      std::copy(data, data+stride*height, data_.get());
    }
    else
    {
      for (std::uint32_t y=0; y<height; ++y)
      {
        for (std::uint32_t x=0; x<width; ++x)
        {
          data_.get()[y*this->stride()+x] = data[y*stride + x];
        }
      }
    }
  }
}

//-----------------------------------------------------------------------------
template<typename PixelStorageType, imp::PixelType pixel_type>
PixelStorageType* ImageRaw<PixelStorageType, pixel_type>::data(
    std::uint32_t ox, std::uint32_t oy)
{
  if (ox > this->width() || oy > this->height())
  {
    throw imp::Exception("Request starting offset is outside of the image.", __FILE__, __FUNCTION__, __LINE__);
  }

  return &data_.get()[oy*this->stride() + ox];
}

//-----------------------------------------------------------------------------
template<typename PixelStorageType, imp::PixelType pixel_type>
void ImageRaw<PixelStorageType, pixel_type>::copyTo(Base& dst)
{
  if (this->width() != dst.width() || this->height() != dst.height())
  {
    //! @todo (MWE) if width/height is the same but alignment is different we can copy manually!
    throw imp::Exception("Image size and/or memory alignment is different.", __FILE__, __FUNCTION__, __LINE__);
  }

  if (this->bytes() == dst.bytes())
  {
    std::cout << "using std::copy" << std::endl;
    std::copy(data_.get(), data_.get()+this->stride()*this->height(), dst.data());
  }
  else
  {
    std::cout << "pixel-wise copy" << std::endl;
    for (std::uint32_t y=0; y<this->height(); ++y)
    {
      for (std::uint32_t x=0; x<this->width(); ++x)
      {
        dst[y][x] = data_.get()[y*this->stride() + x];
      }
    }
  }
}

// //-----------------------------------------------------------------------------
// virtual size_type bytes() const override
// {
//   return this->height()*pitch_;
// }

// virtual size_type pitch() const override
// {
//   return pitch_;
// }

// virtual bool isGpuMemory() const override
// {
//   return false;
// }


//=============================================================================
// Explicitely instantiate the desired classes
// (sync with typedefs at the end of the hpp file)
template class ImageRaw<std::uint8_t, imp::PixelType::i8uC1>;
template class ImageRaw<std::uint16_t, imp::PixelType::i8uC1>;
template class ImageRaw<std::int32_t, imp::PixelType::i8uC1>;
template class ImageRaw<float, imp::PixelType::i8uC1>;


} // namespace imp
