#ifndef IMP_CU_K_STEREO_CTF_WARPING_LEVEL_PRECOND_HUBER_L1_WEIGHTED_CUH
#define IMP_CU_K_STEREO_CTF_WARPING_LEVEL_PRECOND_HUBER_L1_WEIGHTED_CUH

#include <cuda_runtime_api.h>
#include <imp/core/types.hpp>
#include <imp/cu_core/cu_utils.hpp>
#include <imp/cu_core/cu_k_derivative.cuh>
#include <imp/cuda_toolkit/helper_math.h>


namespace imp {
namespace cu {

//-----------------------------------------------------------------------------
template<typename Pixel>
__global__ void k_preconditionerWeighted(Pixel* xi, size_type stride,
                                         std::uint32_t width, std::uint32_t height,
                                         // std::uint32_t roi_x, std::uint32_t roi_y,
                                         float lambda, Texture2D ix_tex, Texture2D g_tex)
{
  const int x = blockIdx.x*blockDim.x + threadIdx.x;
  const int y = blockIdx.y*blockDim.y + threadIdx.y;

  if (x<width && y<height)
  {
    Pixel ix, g;
    ix_tex.fetch(ix, x, y);
    g_tex.fetch(g, x, y);
    xi[y*stride+x] = 4*g + fabs(lambda * ix);
    //    xi[y*stride+x] = 4*g + sqr(lambda) * sqr(ix);
  }
}

//-----------------------------------------------------------------------------
template<typename Pixel>
__global__ void k_preconditionerWeighted(Pixel* xi, size_type stride,
                                         std::uint32_t width, std::uint32_t height,
                                         // std::uint32_t roi_x, std::uint32_t roi_y,
                                         Texture2D lambda_tex, Texture2D ix_tex,
                                         Texture2D g_tex)
{
  const int x = blockIdx.x*blockDim.x + threadIdx.x;
  const int y = blockIdx.y*blockDim.y + threadIdx.y;

  if (x<width && y<height)
  {
    Pixel ix, g;
    ix_tex.fetch(ix, x, y);
    g_tex.fetch(g, x, y);
    xi[y*stride+x] = 4*g + fabs(lambda_tex.fetch<float>(x,y)*ix);
    //    xi[y*stride+x] = 4*g + sqr(lambda) * sqr(ix);
  }
}

//-----------------------------------------------------------------------------
/**
 * @brief k_primalUpdateWeighted is the weighted Huber-L1-Precondition model's primal update kernel
 * @note PPixel and DPixel denote for the Pixel type/dimension of primal and dual variable
 */
template<typename PPixel>
__global__ void k_primalUpdateWeighted(PPixel* d_u, PPixel* d_u_prev, const size_type stride,
                                       std::uint32_t width, std::uint32_t height,
                                       const float lambda, const float tau,
                                       const float lin_step,
                                       Texture2D u_tex, Texture2D u0_tex,
                                       Texture2D pu_tex, Texture2D q_tex,
                                       Texture2D ix_tex, Texture2D xi_tex,
                                       Texture2D g_tex)
{
  const int x = blockIdx.x*blockDim.x + threadIdx.x;
  const int y = blockIdx.y*blockDim.y + threadIdx.y;

  if (x<width && y<height)
  {
    float u_prev = u_tex.fetch<float>(x, y);
    float q = q_tex.fetch<float>(x, y);
    float ix = ix_tex.fetch<float>(x, y);
    float xi = max(1e-6f, xi_tex.fetch<float>(x, y));

    float div = dpAdWeighted(pu_tex, g_tex, x, y, width, height);

    float u = u_prev - tau/xi * (-div + lambda*ix*q);

    d_u[y*stride+x] = u = k_linearized_update(u, u0_tex, lin_step, x, y);
    d_u_prev[y*stride+x] = 2.f*u - u_prev;
  }
}


//-----------------------------------------------------------------------------
/**
 * @brief k_primalUpdateWeighted is the weighted Huber-L1-Precondition model's primal update kernel
 * @note PPixel and DPixel denote for the Pixel type/dimension of primal and dual variable
 */
template<typename PPixel>
__global__ void k_primalUpdateWeighted(PPixel* d_u, PPixel* d_u_prev, const size_type stride,
                                       std::uint32_t width, std::uint32_t height,
                                       const float tau, const float lin_step,
                                       Texture2D lambda_tex,
                                       Texture2D u_tex, Texture2D u0_tex,
                                       Texture2D pu_tex, Texture2D q_tex,
                                       Texture2D ix_tex, Texture2D xi_tex,
                                       Texture2D g_tex)
{
  const int x = blockIdx.x*blockDim.x + threadIdx.x;
  const int y = blockIdx.y*blockDim.y + threadIdx.y;

  if (x<width && y<height)
  {
    float u_prev = u_tex.fetch<float>(x, y);
    float q = q_tex.fetch<float>(x, y);
    float ix = ix_tex.fetch<float>(x, y);
    float xi = max(1e-6f, xi_tex.fetch<float>(x, y));

    float div = dpAdWeighted(pu_tex, g_tex, x, y, width, height);
    //    float div = dpAd(pu_tex, x, y, width, height);

    float lambda = lambda_tex.fetch<float>(x,y);
    float u = u_prev - tau/xi * (-div + lambda*ix*q);

    u = k_linearized_update(u, u0_tex, lin_step, x, y);
    d_u[y*stride+x] = u;
    d_u_prev[y*stride+x] = 2.f*u - u_prev;
  }
}

//-----------------------------------------------------------------------------
template<typename PPixel, typename DPixel>
__global__ void k_dualUpdateWeighted(DPixel* d_pu, const size_type stride_pu,
                                     PPixel* d_q, const size_type stride_q,
                                     std::uint32_t width, std::uint32_t height,
                                     const float eps_u,
                                     const float sigma, const float eta,
                                     Texture2D lambda_tex,
                                     Texture2D u_prev_tex, Texture2D u0_tex,
                                     Texture2D pu_tex, Texture2D q_tex,
                                     Texture2D ix_tex, Texture2D it_tex,
                                     Texture2D g_tex)
{
  const int x = blockIdx.x*blockDim.x + threadIdx.x;
  const int y = blockIdx.y*blockDim.y + threadIdx.y;
  if (x<width && y<height)
  {
    const float sigma_by_eta = sigma/eta;

    // update pu
    float2 du = dpWeighted(u_prev_tex, g_tex, x, y);
    float2 pu = pu_tex.fetch<float2>(x,y);
    pu  = (pu + sigma_by_eta*du) / (1.f + sigma_by_eta*eps_u);
    pu = pu / max(1.0f, length(pu));
    d_pu[y*stride_pu+x] = {pu.x, pu.y};

    // update q
    float u_prev = u_prev_tex.fetch<float>(x, y);
    float u0 = u0_tex.fetch<float>(x, y);
    float q = q_tex.fetch<float>(x, y);
    float ix = ix_tex.fetch<float>(x, y);
    float it = it_tex.fetch<float>(x, y);
    float lambda = lambda_tex.fetch<float>(x,y);
    const float sigma_q = sigma / max(1e-6f, lambda * fabs(ix));
    q = q + lambda*sigma_q * (it + ix*(u_prev-u0));
    d_q[y*stride_q+x] = max(-1.f, min(1.f, q));
  }
}

//-----------------------------------------------------------------------------
template<typename T>
__global__ void k_primalEnergy(T* ep, const size_type stride,
                               const std::uint32_t width, const std::uint32_t height,
                               const float lambda,
                               Texture2D u_tex, Texture2D g_tex,
                               Texture2D i1_tex, Texture2D i2_tex)
{
  const int x = blockIdx.x*blockDim.x + threadIdx.x;
  const int y = blockIdx.y*blockDim.y + threadIdx.y;
  if (x<width && y<height)
  {
    float2 du = dpWeighted(u_tex, g_tex, x, y);
    float u = u_tex.fetch<float>(x,y);
    float wx = x+u;
    float dat = 0.f;

    float bd = .5f;
    if ((wx > bd) && (x > bd) && (wx < width-bd-1) && (x < width-bd-1) &&
        (y>bd) && (y<height-bd-1))
    {
      dat = i2_tex.fetch<float>(wx,y) - i1_tex.fetch<float>(x,y);
    }

    ep[y*stride+x] = length(du) + lambda * fabs(dat);
  }
}

} // namespace cu
} // namespace imp



#endif // IMP_CU_K_STEREO_CTF_WARPING_LEVEL_PRECOND_HUBER_L1_WEIGHTED_CUH

