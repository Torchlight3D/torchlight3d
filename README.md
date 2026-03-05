# Torchlight3d

## Motivation

Sensor calibration is a critical task in numerous fields such as robotics, computer vision, and augmented reality. Despite its apparent simplicity, achieving high-quality calibration is complex and often requires solutions tailored to specific hardware configurations. This complexity arises from the need to precisely align sensor data in multi-sensor systems, ensuring accurate data fusion and reliable performance.

The process of sensor calibration shares many similarities with 3D reconstruction and Simultaneous Localization and Mapping (SLAM). These tasks often utilize common mathematical models, optimization techniques, and algorithms. By leveraging these shared modules, we can create a more efficient and cohesive calibration library.

Existing libraries like Kalibr and OpenCV have made significant strides in sensor calibration. However, they fall short in terms of customizability and portability. These tools often provide robust solutions for standard configurations but lack the flexibility required for unique or evolving hardware setups. This limitation can be a significant barrier for researchers and developers working with non-standard or cutting-edge sensor arrays.

Moreover, there has been a surge of state-of-the-art research in sensor calibration, often open-sourced or otherwise accessible. While these contributions are invaluable, they are frequently developed by students and researchers whose primary focus is on academic exploration rather than production-level implementation. As a result, these projects may not be well-organized or thoroughly tested to meet the rigorous standards of real-world applications.

Our motivation for developing this new calibration library is to address these gaps. We aim to create a tool that not only achieves high accuracy but also offers extensive customization options and portability. By integrating modular components that can be easily adapted and extended, we hope to support a wide range of hardware configurations and use cases. Furthermore, we intend to consolidate and refine cutting-edge research contributions, ensuring they are organized, tested, and ready for practical deployment.


## Goals

+ Modern

+ Modular

+ Well-tested

+ Cross-platform

## Build

A complete 3rd-party libraries list can be found [here](DEPENDENCIES.md).

Most of the dependencies are the same on both Windows and Linux, not tested on macOS.

### Windows

Prereqs:
- Visual Studio 2022 (v18) with MSVC
- CMake 3.24+ and Ninja (installed with VS)
- vcpkg (set `VCPKG_ROOT` to your vcpkg root)

Build, install, and test from a Developer PowerShell for VS 2022:

```powershell
$env:VCPKG_ROOT = "C:\Program Files\Microsoft Visual Studio\18\Community\VC\vcpkg"
cmake --preset windows-release
cmake --build --preset windows-release --parallel
cmake --build --preset windows-release --target install
ctest --preset windows-release
```

Notes:
- The install output goes to `install/` at the repo root (see CMake preset).
- A small number of tests are data-dependent and will be skipped if the test data is not present.

### Using the library (CMake)

Point CMake to the install prefix and link the components you need:

```cmake
# Example: adjust the install prefix to your local path
list(APPEND CMAKE_PREFIX_PATH "E:/path/to/torchlight3d/install")

find_package(Torchlight CONFIG REQUIRED COMPONENTS Core Math Motion Vision)
target_link_libraries(my_app PRIVATE tl::Core tl::Math tl::Motion tl::Vision)
```

Headers are installed under module include directories like `tCore/`, `tMath/`, etc.
For example:

```cpp
#include <tCore/Bimap>
```

## RoadMap

### Algorithms

+ [x] Merge camera's Calibrate-from-Reconstruction
+ [ ] Add photometric camera calibration
+ [ ] Add more geometric camera models
+ [x] Use CRTP on Camera class
+ [x] Add more fiducial markers, e.g. Stag, CCTag
+ [ ] Clean up fiducial marker libraries, add unit tests
+ [ ] Complete MultiChessboardDetector
+ [ ] Add Handeye calibration
+ [ ] Better IMU calibration, make use of B-spline
+ [ ] Complete MTF
+ [ ] Complete structured light
+ [ ] Bring in deep learning, start with feature detection

### Software

+ [x] Move application and Qt related stuffs out of `modules`
+ [x] Better CMake, library export and package
+ [ ] Documentations
+ [ ] Add Python binding (pybind11)
+ [ ] Add 3D visualization module (Complete the old Qt-based one, or start over with imgui?)
+ [ ] Open sourced project desciption, setting, and license stuffs
+ [ ] CI/CD
