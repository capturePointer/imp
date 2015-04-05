#ifndef IMP_CU_STEREOCTFWARPING_HPP
#define IMP_CU_STEREOCTFWARPING_HPP

#include <memory>
#include <vector>

#include <imp/cucore/cu_image_gpu.cuh>
#include <imp/cuimgproc/image_pyramid.hpp>
#include <imp/cucore/cu_matrix.cuh>

#include <imp/cudepth/variational_stereo_parameters.hpp>
//#include <imp/cudepth/solver_stereo_abstract.hpp>


namespace imp {
namespace cu {

// forward declarations
class SolverStereoAbstract;

/**
 * @brief The StereoCtFWarping class
 * @todo (MWE) better handling of fixed vs. moving images when adding (incremental updates)
 * @todo (MWE) better interface for multiple input images with fundamental matrix prior
 */
class StereoCtFWarping
{
public:
  using Parameters = VariationalStereoParameters;

  using Image = imp::cu::ImageGpu32fC1;
  using ImagePtr = std::shared_ptr<Image>;
  using ConstImagePtrRef = const std::shared_ptr<Image>&;

  using VectorImage = imp::cu::ImageGpu32fC2;
  using VectorImagePtr = std::shared_ptr<VectorImage>;
  using ConstVectorImagePtr = const std::shared_ptr<VectorImage>&;

  using ImagePyramid = imp::ImagePyramid32fC1;
  using ImagePyramidPtr = std::shared_ptr<ImagePyramid>;

public:
  StereoCtFWarping() = delete;
  virtual ~StereoCtFWarping();// = default;
//  StereoCtFWarping(const StereoCtFWarping&);
//  StereoCtFWarping(StereoCtFWarping&&);

  StereoCtFWarping(std::shared_ptr<Parameters> params);

  void addImage(ImagePtr image);
  void solve();
  ImagePtr getDisparities(size_type level=0);

  // if we have a guess about the correspondence points and the epipolar geometry
  // given we can set these as a prior
  inline virtual void setFundamentalMatrix(const cu::Matrix3f& F) {F_ = F;}
  inline virtual void setCorrespondenceGuess(ConstVectorImagePtr correspondence_guess)
  {init_correspondence_guess_ = correspondence_guess;}
  inline virtual void setEpiVecs(ConstVectorImagePtr epi_vec) {init_epi_vec_ = epi_vec;}

protected:
  /**
   * @brief ready checks if everything is setup and initialized.
   * @return State if everything is ready to solve the given problem.
   */
  bool ready();

  /**
   * @brief init initializes the solvers for the current setup
   */
  void init();

private:
  std::shared_ptr<Parameters> params_; //!< configuration parameters
  std::vector<ImagePtr> images_; //!< all unprocessed input images
  std::vector<ImagePyramidPtr> image_pyramids_; //!< image pyramids corresponding to the unprocesed input images
  std::vector<std::unique_ptr<SolverStereoAbstract>> levels_;

  cu::Matrix3f F_;
  VectorImagePtr init_correspondence_guess_;
  VectorImagePtr init_epi_vec_;
};

} // namespace cu
} // namespace imp

#endif // IMP_CU_STEREOCTFWARPING_HPP
