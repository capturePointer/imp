#ifndef VARIATIONAL_STEREO_PARAMETERS_HPP
#define VARIATIONAL_STEREO_PARAMETERS_HPP

#include <cstdint>
#include <imp/core/types.hpp>
#include <imp/cudepth/stereo_solver_enum.hpp>

namespace imp {
namespace cu {

// the parameter struct
struct VariationalStereoParameters
{
  int verbose=10; //!< verbosity level (the higher, the more the Stereo algorithm talks to us)
  StereoPDSolver solver=StereoPDSolver::HuberL1; //!< selected primal-dual solver / model
  float lambda = 30.0f; //!< tradeoff between regularization and matching term
  float eps_u = 0.05f; //!< tradeoff between L1 and L2 part of the Huber regularization

  // settings for the ctf warping
  struct CTF // we might want to define this externally for all ctf approaches?
  {
    float scale_factor = 0.8f; //!< multiplicative scale factor between coarse-to-fine pyramid levels
    std::uint32_t iters = 100;
    std::uint32_t warps =  10;
    size_type levels = UINT32_MAX;
    size_type coarsest_level = UINT32_MAX;
    size_type finest_level = 0;
    bool apply_median_filter = false;
  };

  CTF ctf;

  friend std::ostream& operator<<(std::ostream& stream,
                                  const VariationalStereoParameters& p);
};


} // namespace cu
} // namespace imp

#endif // VARIATIONAL_STEREO_PARAMETERS_HPP

