project(imp_tools_cmd)
cmake_minimum_required(VERSION 2.8.0)

include(${CMAKE_CURRENT_SOURCE_DIR}/../../cmake/imp_ext_finders.cmake)
find_cuda()

find_package(catkin_simple REQUIRED)
catkin_simple()

SET(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -std=c++11 -fPIC -Wall -g")

###
### command line tools
###
# find_package( OpenCV REQUIRED core highgui imgproc)
# include_directories(${OpenCV_INCLUDE_DIRS})

cs_add_executable(cu_rof_denoising_test cu_rof_denoising_test.cpp)
target_link_libraries(cu_rof_denoising_test)

cs_add_executable(image_pyramid_test image_pyramid_test.cpp)
target_link_libraries(image_pyramid_test)

cs_add_executable(image_filter_median3x3_test image_filter_median3x3_test.cpp)
target_link_libraries(image_filter_median3x3_test)

cs_add_executable(image_filter_gauss_test image_filter_gauss_test.cpp)
target_link_libraries(image_filter_gauss_test)

cs_add_executable(natural_edges_test natural_edges_test.cpp)
target_link_libraries(natural_edges_test)

#cs_add_executable(example_executable src/main.cc)
#target_link_libraries(example_executable example_library)

cs_install()
cs_export()