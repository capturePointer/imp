macro(imp_debug)
  string(REPLACE ";" " " __msg "${ARGN}")
  message(STATUS "${__msg}")
endmacro()

macro(imp_warn)
  string(REPLACE ";" " " __msg "${ARGN}")
  message(WARNING "${__msg}")
endmacro()

macro(imp_fatal)
  string(REPLACE ";" " " __msg "${ARGN}")
  message(FATAL_ERROR "${__msg}")
endmacro()

macro(imp_include)
   #imp_debug("[MACRO] imp_include( ${ARGN} )")
   include_directories(${ARGN})
   if (IMP_WITH_CUDA AND CUDA_FOUND)
      cuda_include_directories(${ARGN})
   endif()
endmacro()

##! @todo (MWE) extend with default setup stuff that we want to re-use in every package
macro(imp_setup)
   set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -Wall -Werror -fPIC")

   if(${CMAKE_SYSTEM_NAME} MATCHES "Linux")
      message(STATUS "set imp compile flags for Linux system")
      set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} --std=c++11 ")
   elseif(${CMAKE_SYSTEM_NAME} MATCHES "Darwin")
      message(STATUS "set imp compile flags for Darwin system")
      set(CMAKE_CXX_FLAGS "-std=c++11 -stdlib=libc++")
   elseif(${CMAKE_SYSTEM_NAME} MATCHES "Windows")
      message(STATUS "set imp compile flags for Windows system")
      message(AUTHOR_WARNING "TODO ... compile flags for Windows")
   else()
      message(SEND_ERROR "Unknown/unsupported(?) system")
   endif()

   if (CMAKE_BUILD_TYPE STREQUAL "Debug")
      set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -g")
   endif()
endmacro()
