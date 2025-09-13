# FFmpeg Windows x64 CUDA 13 Build Workflow

This document describes how to use the automated GitHub Actions workflow to build a fully-featured FFmpeg executable for Windows x64 with CUDA 13 acceleration.

## Quick Start

1. Go to the **Actions** tab in this repository
2. Select **"build-ffmpeg-windows-cuda13-full"** workflow
3. Click **"Run workflow"** 
4. Configure options (defaults are recommended for most users)
5. Click **"Run workflow"** to start the build
6. Wait ~30-45 minutes for completion
7. Download the artifact from the workflow run

## Features Included

### Video Codecs & Acceleration
- **NVIDIA GPU Acceleration**: NVENC/NVDEC for H.264, H.265, AV1
- **CPU Video Codecs**: x264, x265, AV1 (libaom, SVT-AV1, dav1d), VP8/VP9
- **Modern Formats**: WebP, JPEG XL, OpenJPEG
- **Quality Enhancement**: VMAF metrics, Vulkan filters, libplacebo upscaling

### Audio Codecs
- **Lossless**: FLAC, ALAC
- **Lossy**: Opus, Vorbis, MP3 (LAME), AAC
- **High Quality**: FDK-AAC (optional, requires nonfree)
- **Audio DSP**: SoXR resampling, bs2b binaural processing

### Subtitle & Text
- **Advanced Rendering**: libass with FreeType, HarfBuzz, Fribidi
- **Full Unicode Support**: Complex text shaping, bidirectional text

### Network & IO
- **Streaming**: SRT, RIST protocols  
- **Remote Access**: SSH, ZMQ messaging
- **Disc Formats**: Blu-ray support
- **Module Formats**: ModPlug, OpenMPT
- **Security**: GnuTLS encryption
- **Metadata**: libxml2 processing

### Platform Integration
- **Frame Servers**: AviSynth+ support
- **GPU Computing**: CUDA kernels, Vulkan compute
- **Windows Optimization**: Native threading, ASLR/DEP security

## Workflow Options

### Core Settings
- **FFmpeg Version**: Choose release tag (e.g., "n8.0") or "master" for latest
- **GPL License**: Enable GPL-licensed components (recommended: ON)
- **Version 3**: Enable LGPLv3/GPLv3 components (recommended: ON)  
- **Nonfree**: Enable proprietary components like FDK-AAC (default: OFF)

### CUDA Optimization
- **CUDA Stack**: Enable all NVIDIA GPU features (recommended: ON)
- **CUDA Compiler**: Use NVIDIA's nvcc vs Clang (recommended: ON for better optimization)
- **PTX Compression**: Compress CUDA kernels (recommended: ON for smaller binaries)

### Build Options
- **Debug Symbols**: Include debugging info (makes files larger, default: OFF)
- **Build Validation**: Test built executable before packaging (recommended: ON)

### Individual Features
All major codecs and libraries can be individually toggled. Defaults enable a comprehensive set suitable for most use cases.

## System Requirements

### Build Environment
- GitHub Actions provides: Windows Server 2022, CUDA 13.0, MSYS2 toolchain

### Runtime Requirements (for built executable)
- **OS**: Windows 11 recommended (Windows 10 version 1903+ supported)
- **GPU**: NVIDIA GeForce GTX 10-series or newer for CUDA features
- **Driver**: NVIDIA driver 527.41 or newer (for CUDA 12.0+ API support)
- **RAM**: 4GB+ recommended for 4K video processing

## Usage Examples

The built FFmpeg is completely self-contained - just run it from any location.

### Basic Transcoding
```bash
# Simple format conversion
ffmpeg -i input.mkv output.mp4

# High quality H.265 encode
ffmpeg -i input.mp4 -c:v libx265 -crf 20 -c:a libopus output.mkv
```

### GPU-Accelerated Encoding
```bash
# NVENC H.264 (very fast)
ffmpeg -i input.mp4 -c:v h264_nvenc -preset p4 -rc vbr -cq 23 output.mp4

# NVENC H.265 with GPU scaling
ffmpeg -i input.mp4 -vf "scale_cuda=1920:1080" -c:v hevc_nvenc -preset p4 output.mp4

# AV1 encoding (CPU)
ffmpeg -i input.mp4 -c:v libsvtav1 -crf 30 output.mkv
```

### Advanced Processing
```bash
# HDR tone mapping with libplacebo
ffmpeg -i hdr_input.mkv -vf "libplacebo=tonemapping=hable" -c:v libx265 sdr_output.mp4

# Audio enhancement with bs2b
ffmpeg -i input.mp4 -af "bs2b" -c:v copy enhanced_audio.mp4

# Live streaming with SRT
ffmpeg -i input.mp4 -c copy -f mpegts "srt://server:port"
```

## Troubleshooting

### Common Issues
1. **CUDA errors**: Ensure NVIDIA driver is up to date
2. **Missing DLLs**: All dependencies should be bundled - try running from extracted directory
3. **Slow encoding**: Check if GPU acceleration is working: `ffmpeg -encoders | findstr nvenc`

### Validation
The workflow includes built-in validation that tests:
- Basic FFmpeg functionality
- CUDA encoder availability  
- Common codec support
- Library linkage

### Getting Help
- Check FFmpeg documentation: https://ffmpeg.org/documentation.html
- Verify hardware support: `ffmpeg -hwaccels` and `ffmpeg -encoders`
- For CUDA issues: `nvidia-smi` to check GPU status

## Development

### Customizing the Build
1. Fork this repository
2. Modify `.github/workflows/build-ffmpeg-windows-cuda.yml`
3. Test changes in your fork
4. Submit pull request if beneficial to others

### Adding New Libraries
1. Check if available in MSYS2: https://packages.msys2.org/
2. Add to package installation list
3. Add workflow input parameter
4. Add configure flag logic
5. Test build compatibility

## License & Redistribution

**Important**: The built binaries inherit the licenses of all included components:
- **GPL Build** (default): Can only be distributed under GPLv3+
- **LGPL Build** (--disable-gpl): More permissive licensing 
- **Nonfree Build** (--enable-nonfree): Cannot be redistributed

See the `licenses/` directory in the built package for full license information.

Built binaries include components under various licenses. Ensure compliance with all applicable licenses before redistribution.