#
# Copyright 2017 National Renewable Energy Laboratory
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

# -----------------------------------------------------------
# -- OpenFAST Unit Testing
# -----------------------------------------------------------

cmake_minimum_required(VERSION 2.8.12)
project(OpenFAST_UnitTest Fortran)

# include(CTest)

# Set the python executable configuration option and default
if(NOT EXISTS ${PYTHON_EXECUTABLE})
  find_program(PYTHON_EXECUTABLE NAMES python3 python py)
  if(NOT EXISTS ${PYTHON_EXECUTABLE})
    message(FATAL_ERROR "CMake cannot find a Python interpreter in your path. Python is required to run OpenFAST tests." )
  endif()
endif()

### pfunit
# set(PFUNIT_INSTALL ${PROJECT_BINARY_DIR}/pfunit)

include(ExternalProject)
set(ExternalProjectCMakeArgs
  -DCMAKE_INSTALL_PREFIX=${PFUNIT_INSTALL}
  -DCMAKE_Fortran_COMPILER=${CMAKE_Fortran_COMPILER}
  -DSKIP_ESMF=ON                                                                                                                                                                                               
  -DSKIP_FHAMCREST=ON
  -DSKIP_MPI=ON
  -DSKIP_OPENMP=ON
  -DSKIP_ROBUST=ON
)

ExternalProject_Add(funit
  SOURCE_DIR ${PROJECT_SOURCE_DIR}/pfunit
  BINARY_DIR ${PROJECT_BINARY_DIR}/pfunit-build
  STAMP_DIR ${PROJECT_BINARY_DIR}/pfunit-stamp
  TMP_DIR ${PROJECT_BINARY_DIR}/pfunit-tmp
  INSTALL_DIR ${PFUNIT_INSTALL}
  CMAKE_ARGS ${ExternalProjectCMakeArgs}
)

# set(PFUNIT_DIR ${PROJECT_BINARY_DIR}/pfunit-build)
set(CMAKE_PREFIX_PATH "${CMAKE_PREFIX_PATH} ${PFUNIT_INSTALL}")
set(PFUNIT "${PFUNIT_INSTALL}/PFUNIT-4.1/cmake/PFUNITConfig.cmake")
# find_package(PFUNIT REQUIRED)

# set(pfunit_directory ${PFUNIT_INSTALL}/PFUNIT-4.1)
# set(source_modulesdirectory ${PROJECT_SOURCE_DIR}/../modules)
# set(build_testdirectory ${PROJECT_BINARY_DIR}/tests)

# include_directories(
#   ${PROJECT_SOURCE_DIR}
#   ${build_testdirectory}
#   ${pfunit_directory}/include
# )

# set_source_files_properties(${pfunit_directory}/include/driver.F90 PROPERTIES GENERATED 1)
# set_source_files_properties(driver.F90 PROPERTIES COMPILE_DEFINITIONS _TEST_SUITES="testSuites.inc")
# if(APPLE OR UNIX OR CYGWIN OR MINGW)
#   # set(pfunit_lib "/lib/libpfunit.a")
#   set(funit_lib "/lib/libfunit.a")
# else() # Windows
#   # set(pfunit_lib "/lib/pfunit.lib")
#   set(funit_lib "/lib/funit.lib")
# endif()

### Add the unit tests here
add_subdirectory("beamdyn")
# add_subdirectory("nwtc-library")
# add_subdirectory("aerodyn")
# add_subdirectory("inflowwind")

add_custom_target(
  unit_tests
  DEPENDS beamdyn_utest nwtc_library_utest fvw_utest inflowwind_utest
)
