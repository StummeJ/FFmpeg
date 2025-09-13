# FFmpeg Development Instructions

FFmpeg is a comprehensive multimedia processing library and command-line toolset for handling audio, video, subtitles, and related metadata. It consists of multiple libraries (libavcodec, libavformat, libavutil, libavfilter, libavdevice, libswresample, libswscale) and command-line tools (ffmpeg, ffprobe, ffplay).

Always reference these instructions first and fallback to search or bash commands only when you encounter unexpected information that does not match the info here.

## Working Effectively

### Build Dependencies and Setup (Windows x64)
Install required dependencies for Windows x64 development:

**Required Tools:**
- Visual Studio 2019/2022 with C++ development tools
- NASM (Netwide Assembler) - Download from https://www.nasm.us/pub/nasm/releasebuilds/
- YASM (optional, for compatibility) - Download from http://yasm.tortall.net/Download.html
- pkg-config for Windows - Install via vcpkg or MSYS2
- Git for Windows

**NVIDIA CUDA SDK v13 Setup:**
```cmd
# Download and install NVIDIA CUDA Toolkit v13.0 from:
# https://developer.nvidia.com/cuda-13-0-download-archive
# Select Windows -> x86_64 -> Version -> exe (network/local)

# Verify CUDA installation
nvcc --version
nvidia-smi

# Set CUDA environment variables (typically auto-configured by installer)
set CUDA_PATH=C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v13.0
set CUDA_PATH_V13_0=C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v13.0
```

**Windows Build Tools Setup:**
```cmd
# Install vcpkg for dependency management
git clone https://github.com/Microsoft/vcpkg.git
cd vcpkg
.\bootstrap-vcpkg.bat
.\vcpkg.exe integrate install

# Install common FFmpeg dependencies via vcpkg
.\vcpkg.exe install zlib:x64-windows
.\vcpkg.exe install openssl:x64-windows
.\vcpkg.exe install opus:x64-windows
.\vcpkg.exe install x264:x64-windows
.\vcpkg.exe install x265:x64-windows
```

### Configure and Build Process (Windows x64 with CUDA)
Bootstrap, configure, and build the repository using Developer Command Prompt for VS:

```cmd
# Open "Developer Command Prompt for VS 2019/2022" as Administrator
# Navigate to FFmpeg source directory

# Configure with CUDA support and Windows-specific options
./configure ^
  --toolchain=msvc ^
  --arch=x86_64 ^
  --enable-gpl ^
  --enable-version3 ^
  --enable-cuda-nvcc ^
  --enable-cuda-llvm ^
  --enable-cuvid ^
  --enable-nvenc ^
  --enable-nvdec ^
  --enable-libx264 ^
  --enable-libx265 ^
  --enable-libopus ^
  --extra-cflags=-I"%CUDA_PATH%\include" ^
  --extra-ldflags=-L"%CUDA_PATH%\lib\x64" ^
  --extra-libs=cuda.lib ^
  --extra-libs=cudart.lib ^
  --extra-libs=cufft.lib ^
  --extra-libs=curand.lib ^
  --extra-libs=cublas.lib ^
  --prefix=./build/x64
```

**Configure Options Explained:**
- `--toolchain=msvc`: Use Microsoft Visual C++ compiler
- `--arch=x86_64`: Target 64-bit Windows
- `--enable-cuda-nvcc`: Enable CUDA compilation support
- `--enable-nvenc/nvdec`: Enable NVIDIA hardware encoding/decoding
- `--extra-cflags/ldflags`: Include CUDA headers and libraries
- Configure takes ~15-20 seconds on Windows

Build FFmpeg with parallel compilation:
```cmd
# Use maximum CPU cores for parallel build
make -j%NUMBER_OF_PROCESSORS%
```
- **NEVER CANCEL: Build takes 8-12 minutes on Windows. Set timeout to 20+ minutes.**
- Uses parallel compilation to speed up build process
- Produces ffmpeg.exe, ffprobe.exe binaries and all libraries
- Output will be in current directory with .exe extensions

Build examples and tools:
```cmd
make examples       # Takes ~25 seconds on Windows
make alltools      # Takes ~20 seconds on Windows
```

### Testing and Validation (Windows)

Run basic functionality tests:
```cmd
.\ffmpeg.exe -version
.\ffprobe.exe -version
.\ffmpeg.exe -f lavfi -i testsrc=duration=1:size=320x240:rate=1 -f null -
```

**CUDA Hardware Acceleration Test:**
```cmd
# Test NVIDIA hardware encoding (requires NVIDIA GPU)
.\ffmpeg.exe -f lavfi -i testsrc=duration=5:size=1920x1080:rate=30 -c:v h264_nvenc -preset fast -b:v 5M test_nvenc.mp4

# Test NVIDIA hardware decoding
.\ffmpeg.exe -hwaccel cuda -hwaccel_output_format cuda -i test_nvenc.mp4 -c:v h264_nvenc output_decoded.mp4

# List available CUDA devices
.\ffmpeg.exe -f lavfi -i nullsrc -c:v h264_nvenc -gpu list -f null -
```

Run unit tests (no external samples required):
```cmd
make tests/checkasm/checkasm.exe    # Build takes ~35 seconds on Windows
.\tests\checkasm\checkasm.exe --test=audiodsp  # Runs in milliseconds
```

Run basic filter tests:
```cmd
make fate-filter-adelay fate-filter-aecho fate-filter-afade-esin
```
- Individual filter tests take 2-3 seconds each on Windows
- These tests work without external media samples

### Pre-commit Validation (Windows)
Install and run pre-commit hooks using Windows Python:
```cmd
# Install Python 3.9+ from python.org or Microsoft Store
# Create virtual environment for pre-commit
python -m venv %USERPROFILE%\pre-commit-env
%USERPROFILE%\pre-commit-env\Scripts\activate.bat

# Install pre-commit
pip install pre-commit

# Run pre-commit on specific files
pre-commit run -c .forgejo/pre-commit/config.yaml --show-diff-on-failure --color=always --files filename.c
```
- Note: Pre-commit setup may fail due to network timeouts - document failures as known issues
- Some hooks may require additional Windows-specific configuration

## Validation Scenarios (Windows with CUDA)

Always manually validate changes by running complete scenarios:

### Basic Media Processing Test
```cmd
.\ffmpeg.exe -f lavfi -i testsrc=duration=5:size=640x480:rate=30 -f lavfi -i sine=frequency=1000:duration=5 -c:v mpeg4 -c:a mp2 test_output.avi
.\ffprobe.exe test_output.avi
```
- Use built-in codecs (mpeg4, mp2) for basic testing
- External codecs like libx264 require additional dependencies

### CUDA-Accelerated Media Processing Test
```cmd
# GPU-accelerated encoding with NVENC
.\ffmpeg.exe -f lavfi -i testsrc=duration=10:size=1920x1080:rate=60 -c:v h264_nvenc -preset fast -b:v 10M -gpu 0 cuda_test.mp4

# GPU-accelerated transcoding
.\ffmpeg.exe -hwaccel cuda -i input.mp4 -c:v h264_nvenc -preset medium -b:v 5M output_gpu.mp4

# Verify GPU memory usage during processing
nvidia-smi
```

### Library API Test (using examples)
```cmd
.\doc\examples\encode_audio.exe test.mp2
.\doc\examples\encode_video.exe test.h264
# Use 'file' command equivalent or check file properties in Windows Explorer
```

### Tool Functionality Test  
```cmd
echo test content | .\tools\ffhash.exe md5
echo test content | .\tools\ffhash.exe sha256
```
- Note: Some tools may have different behavior on Windows
- Test with PowerShell and Command Prompt for compatibility

## Critical Timing and Timeout Information (Windows x64)

**NEVER CANCEL these operations - they take significant time:**
- `make -j%NUMBER_OF_PROCESSORS%`: 8-12 minutes (set 20+ minute timeout)
- `./configure`: ~15-20 seconds (set 90+ second timeout) 
- `make examples`: ~25 seconds (set 90+ second timeout)
- `make alltools`: ~20 seconds (set 90+ second timeout)
- `make tests/checkasm/checkasm.exe`: ~35 seconds (set 120+ second timeout)

Fast operations (under 10 seconds):
- Individual fate tests: 2-3 seconds each
- Checkasm test execution: milliseconds
- Binary version checks: instant
- CUDA device enumeration: 1-2 seconds

## Repository Structure

### Key Directories
- **libavcodec/**: Codec implementations (encoders/decoders)
- **libavformat/**: Container format support and I/O
- **libavutil/**: Utility functions and data structures  
- **libavfilter/**: Audio/video filtering framework
- **libavdevice/**: Device abstraction layer
- **libswresample/**: Audio resampling 
- **libswscale/**: Video scaling and color conversion
- **fftools/**: Command-line tools (ffmpeg, ffprobe, ffplay)
- **tools/**: Development and utility tools
- **doc/**: Documentation and examples
- **tests/**: Test suite and validation

### Important Files
- **configure**: Build configuration script (shell script, works with MSYS2/Git Bash on Windows)
- **Makefile**: Main build system entry point
- **INSTALL.md**: Installation instructions
- **CONTRIBUTING.md**: Development workflow (note: GitHub PRs not accepted)
- **doc/build_system.txt**: Build system documentation
- **ffbuild/**: Windows-specific build configuration files

## Common Development Tasks (Windows)

### Building Specific Components
```cmd
make libavcodec/libavcodec.a          # Build specific library
make fftools/ffmpeg.exe               # Build specific tool
make doc/examples/scale_video.exe     # Build specific example
```

### Development and Debugging
```cmd
make checkheaders                     # Verify header dependencies
make V=1                             # Verbose build output  
make DBG=1                           # Generate debug assembly files

# Windows-specific debugging with Visual Studio
devenv ffmpeg.sln                    # Open solution in VS (if generated)
```

### CUDA Development Tasks
```cmd
# Test CUDA compilation
nvcc --version
nvidia-smi

# Check CUDA-enabled build
.\ffmpeg.exe -hide_banner -encoders | findstr nvenc
.\ffmpeg.exe -hide_banner -decoders | findstr cuvid

# Profile CUDA performance
.\ffmpeg.exe -f lavfi -i testsrc=duration=10:size=1920x1080:rate=30 -c:v h264_nvenc -gpu 0 -preset fast nul
```

### Cleaning and Rebuilding
```cmd
make clean                           # Clean build artifacts
make distclean                       # Clean everything including config
# Windows-specific cleanup
del /s *.exe *.dll *.lib *.obj 2>nul
```

## CI/CD Information

The project uses Forgejo workflows located in `.forgejo/workflows/`:
- **test.yml**: Runs fate test suite on push/PR (uses external fate-suite)
- **lint.yml**: Runs pre-commit hooks for code quality
- **autolabel.yml**: Automatic PR labeling

CI builds use:
```cmd
REM Equivalent Windows CI configuration
configure.exe --toolchain=msvc --arch=x86_64 --enable-gpl --enable-nonfree --enable-cuda-nvcc --enable-nvenc --enable-memory-poisoning --assert-level=2
make -j%NUMBER_OF_PROCESSORS%
make fate SAMPLES=%CD%\fate-suite -j%NUMBER_OF_PROCESSORS%
```

## Troubleshooting (Windows x64 with CUDA)

### Common Issues and Solutions
- **"nasm not found"**: Download NASM from official site and add to PATH
- **"CUDA not found"**: Verify CUDA_PATH environment variable and nvcc availability
- **"Visual Studio not found"**: Run from "Developer Command Prompt for VS"
- **Build failures**: Check `ffbuild/config.log` for detailed error information
- **Missing dependencies**: Use `./configure --help` to see disable options for missing libs
- **Slow builds**: Ensure using `make -j%NUMBER_OF_PROCESSORS%` for parallel compilation
- **NVENC/NVDEC not available**: Check NVIDIA driver version and GPU compatibility

### CUDA-Specific Issues
- **CUDA out of memory**: Reduce batch size or resolution in test commands
- **NVENC initialization failed**: Check if another application is using NVENC
- **Driver version mismatch**: Update NVIDIA drivers to match CUDA SDK v13
- **Multiple GPU issues**: Use `-gpu N` parameter to specify GPU index

### Network Issues
- Pre-commit hooks may timeout due to PyPI connectivity
- FATE tests require external sample files (not always available)
- vcpkg package downloads may fail due to network restrictions
- Document known failures rather than trying alternative approaches

### Platform-Specific Notes (Windows)
- Build system supports out-of-tree builds: use absolute path to configure
- Some tests require specific hardware (NVIDIA GPU for CUDA tests)
- Cross-compilation supported via configure flags
- Use PowerShell or Command Prompt - avoid mixing shell environments
- File paths use backslashes, but forward slashes work in most contexts
- Windows Defender may slow builds - consider exclusions for build directory

## Development Workflow (Windows x64 with CUDA)

1. **Always build first**: Run full configure && make cycle in Developer Command Prompt
2. **Test basic functionality**: Run version checks and simple processing test using .exe extensions  
3. **Test CUDA functionality**: Verify NVENC/NVDEC support and GPU acceleration
4. **Run relevant tests**: Use checkasm and filter tests for validation
5. **Build examples**: Ensure API compatibility with example programs
6. **Manual validation**: Exercise actual multimedia processing scenarios with CUDA acceleration
7. **Documentation**: Update relevant .texi files if changing user-facing features

**Windows-Specific Workflow Notes:**
- Always use Developer Command Prompt for Visual Studio for builds
- Test both Command Prompt and PowerShell compatibility
- Verify CUDA functionality with nvidia-smi before running GPU tests
- Use Windows-style path separators in documentation but accept forward slashes in practice

Remember: FFmpeg development uses mailing lists, not GitHub PRs. This is for internal development only.
