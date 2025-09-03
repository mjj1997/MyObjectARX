include(cmake/SystemLink.cmake)
include(cmake/LibFuzzer.cmake)
include(CMakeDependentOption)
include(CheckCXXCompilerFlag)


include(CheckCXXSourceCompiles)


macro(MyObjectARX_supports_sanitizers)
  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND NOT WIN32)

    message(STATUS "Sanity checking UndefinedBehaviorSanitizer, it should be supported on this platform")
    set(TEST_PROGRAM "int main() { return 0; }")

    # Check if UndefinedBehaviorSanitizer works at link time
    set(CMAKE_REQUIRED_FLAGS "-fsanitize=undefined")
    set(CMAKE_REQUIRED_LINK_OPTIONS "-fsanitize=undefined")
    check_cxx_source_compiles("${TEST_PROGRAM}" HAS_UBSAN_LINK_SUPPORT)

    if(HAS_UBSAN_LINK_SUPPORT)
      message(STATUS "UndefinedBehaviorSanitizer is supported at both compile and link time.")
      set(SUPPORTS_UBSAN ON)
    else()
      message(WARNING "UndefinedBehaviorSanitizer is NOT supported at link time.")
      set(SUPPORTS_UBSAN OFF)
    endif()
  else()
    set(SUPPORTS_UBSAN OFF)
  endif()

  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND WIN32)
    set(SUPPORTS_ASAN OFF)
  else()
    if (NOT WIN32)
      message(STATUS "Sanity checking AddressSanitizer, it should be supported on this platform")
      set(TEST_PROGRAM "int main() { return 0; }")

      # Check if AddressSanitizer works at link time
      set(CMAKE_REQUIRED_FLAGS "-fsanitize=address")
      set(CMAKE_REQUIRED_LINK_OPTIONS "-fsanitize=address")
      check_cxx_source_compiles("${TEST_PROGRAM}" HAS_ASAN_LINK_SUPPORT)

      if(HAS_ASAN_LINK_SUPPORT)
        message(STATUS "AddressSanitizer is supported at both compile and link time.")
        set(SUPPORTS_ASAN ON)
      else()
        message(WARNING "AddressSanitizer is NOT supported at link time.")
        set(SUPPORTS_ASAN OFF)
      endif()
    else()
      set(SUPPORTS_ASAN ON)
    endif()
  endif()
endmacro()

macro(MyObjectARX_setup_options)
  option(MyObjectARX_ENABLE_HARDENING "Enable hardening" ON)
  option(MyObjectARX_ENABLE_COVERAGE "Enable coverage reporting" OFF)
  cmake_dependent_option(
    MyObjectARX_ENABLE_GLOBAL_HARDENING
    "Attempt to push hardening options to built dependencies"
    ON
    MyObjectARX_ENABLE_HARDENING
    OFF)

  MyObjectARX_supports_sanitizers()

  if(NOT PROJECT_IS_TOP_LEVEL OR MyObjectARX_PACKAGING_MAINTAINER_MODE)
    option(MyObjectARX_ENABLE_IPO "Enable IPO/LTO" OFF)
    option(MyObjectARX_WARNINGS_AS_ERRORS "Treat Warnings As Errors" OFF)
    option(MyObjectARX_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(MyObjectARX_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" OFF)
    option(MyObjectARX_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(MyObjectARX_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" OFF)
    option(MyObjectARX_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(MyObjectARX_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(MyObjectARX_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(MyObjectARX_ENABLE_CLANG_TIDY "Enable clang-tidy" OFF)
    option(MyObjectARX_ENABLE_CPPCHECK "Enable cpp-check analysis" OFF)
    option(MyObjectARX_ENABLE_PCH "Enable precompiled headers" OFF)
    option(MyObjectARX_ENABLE_CACHE "Enable ccache" OFF)
  else()
    option(MyObjectARX_ENABLE_IPO "Enable IPO/LTO" ON)
    option(MyObjectARX_WARNINGS_AS_ERRORS "Treat Warnings As Errors" ON)
    option(MyObjectARX_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(MyObjectARX_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" ${SUPPORTS_ASAN})
    option(MyObjectARX_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(MyObjectARX_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" ${SUPPORTS_UBSAN})
    option(MyObjectARX_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(MyObjectARX_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(MyObjectARX_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(MyObjectARX_ENABLE_CLANG_TIDY "Enable clang-tidy" ON)
    option(MyObjectARX_ENABLE_CPPCHECK "Enable cpp-check analysis" ON)
    option(MyObjectARX_ENABLE_PCH "Enable precompiled headers" OFF)
    option(MyObjectARX_ENABLE_CACHE "Enable ccache" ON)
  endif()

  if(NOT PROJECT_IS_TOP_LEVEL)
    mark_as_advanced(
      MyObjectARX_ENABLE_IPO
      MyObjectARX_WARNINGS_AS_ERRORS
      MyObjectARX_ENABLE_USER_LINKER
      MyObjectARX_ENABLE_SANITIZER_ADDRESS
      MyObjectARX_ENABLE_SANITIZER_LEAK
      MyObjectARX_ENABLE_SANITIZER_UNDEFINED
      MyObjectARX_ENABLE_SANITIZER_THREAD
      MyObjectARX_ENABLE_SANITIZER_MEMORY
      MyObjectARX_ENABLE_UNITY_BUILD
      MyObjectARX_ENABLE_CLANG_TIDY
      MyObjectARX_ENABLE_CPPCHECK
      MyObjectARX_ENABLE_COVERAGE
      MyObjectARX_ENABLE_PCH
      MyObjectARX_ENABLE_CACHE)
  endif()

  MyObjectARX_check_libfuzzer_support(LIBFUZZER_SUPPORTED)
  if(LIBFUZZER_SUPPORTED AND (MyObjectARX_ENABLE_SANITIZER_ADDRESS OR MyObjectARX_ENABLE_SANITIZER_THREAD OR MyObjectARX_ENABLE_SANITIZER_UNDEFINED))
    set(DEFAULT_FUZZER ON)
  else()
    set(DEFAULT_FUZZER OFF)
  endif()

  option(MyObjectARX_BUILD_FUZZ_TESTS "Enable fuzz testing executable" ${DEFAULT_FUZZER})

endmacro()

macro(MyObjectARX_global_options)
  if(MyObjectARX_ENABLE_IPO)
    include(cmake/InterproceduralOptimization.cmake)
    MyObjectARX_enable_ipo()
  endif()

  MyObjectARX_supports_sanitizers()

  if(MyObjectARX_ENABLE_HARDENING AND MyObjectARX_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR MyObjectARX_ENABLE_SANITIZER_UNDEFINED
       OR MyObjectARX_ENABLE_SANITIZER_ADDRESS
       OR MyObjectARX_ENABLE_SANITIZER_THREAD
       OR MyObjectARX_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    message("${MyObjectARX_ENABLE_HARDENING} ${ENABLE_UBSAN_MINIMAL_RUNTIME} ${MyObjectARX_ENABLE_SANITIZER_UNDEFINED}")
    MyObjectARX_enable_hardening(MyObjectARX_options ON ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()
endmacro()

macro(MyObjectARX_local_options)
  if(PROJECT_IS_TOP_LEVEL)
    include(cmake/StandardProjectSettings.cmake)
  endif()

  add_library(MyObjectARX_warnings INTERFACE)
  add_library(MyObjectARX_options INTERFACE)

  include(cmake/CompilerWarnings.cmake)
  MyObjectARX_set_project_warnings(
    MyObjectARX_warnings
    ${MyObjectARX_WARNINGS_AS_ERRORS}
    ""
    ""
    ""
    "")

  if(MyObjectARX_ENABLE_USER_LINKER)
    include(cmake/Linker.cmake)
    MyObjectARX_configure_linker(MyObjectARX_options)
  endif()

  include(cmake/Sanitizers.cmake)
  MyObjectARX_enable_sanitizers(
    MyObjectARX_options
    ${MyObjectARX_ENABLE_SANITIZER_ADDRESS}
    ${MyObjectARX_ENABLE_SANITIZER_LEAK}
    ${MyObjectARX_ENABLE_SANITIZER_UNDEFINED}
    ${MyObjectARX_ENABLE_SANITIZER_THREAD}
    ${MyObjectARX_ENABLE_SANITIZER_MEMORY})

  set_target_properties(MyObjectARX_options PROPERTIES UNITY_BUILD ${MyObjectARX_ENABLE_UNITY_BUILD})

  if(MyObjectARX_ENABLE_PCH)
    target_precompile_headers(
      MyObjectARX_options
      INTERFACE
      <vector>
      <string>
      <utility>)
  endif()

  if(MyObjectARX_ENABLE_CACHE)
    include(cmake/Cache.cmake)
    MyObjectARX_enable_cache()
  endif()

  include(cmake/StaticAnalyzers.cmake)
  if(MyObjectARX_ENABLE_CLANG_TIDY)
    MyObjectARX_enable_clang_tidy(MyObjectARX_options ${MyObjectARX_WARNINGS_AS_ERRORS})
  endif()

  if(MyObjectARX_ENABLE_CPPCHECK)
    MyObjectARX_enable_cppcheck(${MyObjectARX_WARNINGS_AS_ERRORS} "" # override cppcheck options
    )
  endif()

  if(MyObjectARX_ENABLE_COVERAGE)
    include(cmake/Tests.cmake)
    MyObjectARX_enable_coverage(MyObjectARX_options)
  endif()

  if(MyObjectARX_WARNINGS_AS_ERRORS)
    check_cxx_compiler_flag("-Wl,--fatal-warnings" LINKER_FATAL_WARNINGS)
    if(LINKER_FATAL_WARNINGS)
      # This is not working consistently, so disabling for now
      # target_link_options(MyObjectARX_options INTERFACE -Wl,--fatal-warnings)
    endif()
  endif()

  if(MyObjectARX_ENABLE_HARDENING AND NOT MyObjectARX_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR MyObjectARX_ENABLE_SANITIZER_UNDEFINED
       OR MyObjectARX_ENABLE_SANITIZER_ADDRESS
       OR MyObjectARX_ENABLE_SANITIZER_THREAD
       OR MyObjectARX_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    MyObjectARX_enable_hardening(MyObjectARX_options OFF ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()

endmacro()
