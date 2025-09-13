# FFmpeg Development Instructions

FFmpeg is a comprehensive multimedia processing library and command-line toolset for handling audio, video, subtitles, and related metadata. It consists of multiple libraries (libavcodec, libavformat, libavutil, libavfilter, libavdevice, libswresample, libswscale) and command-line tools (ffmpeg, ffprobe, ffplay).

Always reference these instructions first and fallback to search or bash commands only when you encounter unexpected information that does not match the info here.

## Working Effectively

### Build Dependencies and Setup
Install required dependencies before building:
```bash
sudo apt-get update && sudo apt-get install -y nasm yasm pkg-config build-essential
```

### Configure and Build Process
Bootstrap, configure, and build the repository:
```bash
./configure --enable-gpl --enable-version3
```
- Configure takes ~11 seconds
- Use `--enable-gpl --enable-version3` for development builds to enable maximum codec support
- Check `./configure --help` for all available options

Build FFmpeg with full parallelization:
```bash
make -j$(nproc)
```
- **NEVER CANCEL: Build takes 6-8 minutes. Set timeout to 15+ minutes.**
- Uses parallel compilation to speed up build process
- Produces ffmpeg, ffprobe binaries and all libraries

Build examples and tools:
```bash
make examples       # Takes ~18 seconds
make alltools      # Takes ~15 seconds
```

### Testing and Validation

Run basic functionality tests:
```bash
./ffmpeg -version
./ffprobe -version
./ffmpeg -f lavfi -i testsrc=duration=1:size=320x240:rate=1 -f null -
```

Run unit tests (no external samples required):
```bash
make tests/checkasm/checkasm    # Build takes ~29 seconds
./tests/checkasm/checkasm --test=audiodsp  # Runs in milliseconds
```

Run basic filter tests:
```bash
make fate-filter-adelay fate-filter-aecho fate-filter-afade-esin
```
- Individual filter tests take 1-2 seconds each
- These tests work without external media samples

### Pre-commit Validation
Install and run pre-commit hooks (may have network connectivity issues):
```bash
python3 -m venv ~/pre-commit
~/pre-commit/bin/pip install pre-commit
~/pre-commit/bin/pre-commit run -c .forgejo/pre-commit/config.yaml --show-diff-on-failure --color=always --files <filename>
```
- Note: Pre-commit setup may fail due to network timeouts - document failures as known issues

## Validation Scenarios

Always manually validate changes by running complete scenarios:

### Basic Media Processing Test
```bash
./ffmpeg -f lavfi -i testsrc=duration=5:size=640x480:rate=30 -f lavfi -i sine=frequency=1000:duration=5 -c:v mpeg4 -c:a mp2 /tmp/test_output.avi
./ffprobe /tmp/test_output.avi
```
- Use built-in codecs (mpeg4, mp2) for basic testing
- External codecs like libx264 require additional dependencies

### Library API Test (using examples)
```bash
./doc/examples/encode_audio /tmp/test.mp2
./doc/examples/encode_video /tmp/test.h264
file /tmp/test.mp2 /tmp/test.h264
```

### Tool Functionality Test  
```bash
echo "test content" | ./tools/ffhash md5
echo "test content" | ./tools/ffhash sha256
```
- Note: ./tools/ffeval may hang on some expressions - test with simple operations

## Critical Timing and Timeout Information

**NEVER CANCEL these operations - they take significant time:**
- `make -j$(nproc)`: 6-8 minutes (set 15+ minute timeout)
- `./configure`: ~11 seconds (set 60+ second timeout) 
- `make examples`: ~18 seconds (set 60+ second timeout)
- `make alltools`: ~15 seconds (set 60+ second timeout)
- `make tests/checkasm/checkasm`: ~29 seconds (set 90+ second timeout)

Fast operations (under 10 seconds):
- Individual fate tests: 1-2 seconds each
- Checkasm test execution: milliseconds
- Binary version checks: instant

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
- **configure**: Build configuration script (shell script)
- **Makefile**: Main build system entry point
- **INSTALL.md**: Installation instructions
- **CONTRIBUTING.md**: Development workflow (note: GitHub PRs not accepted)
- **doc/build_system.txt**: Build system documentation

## Common Development Tasks

### Building Specific Components
```bash
make libavcodec/libavcodec.a          # Build specific library
make fftools/ffmpeg                   # Build specific tool
make doc/examples/scale_video         # Build specific example
```

### Development and Debugging
```bash
make checkheaders                     # Verify header dependencies
make V=1                             # Verbose build output  
make DBG=1                           # Generate debug assembly files
```

### Cleaning and Rebuilding
```bash
make clean                           # Clean build artifacts
make distclean                       # Clean everything including config
```

## CI/CD Information

The project uses Forgejo workflows located in `.forgejo/workflows/`:
- **test.yml**: Runs fate test suite on push/PR (uses external fate-suite)
- **lint.yml**: Runs pre-commit hooks for code quality
- **autolabel.yml**: Automatic PR labeling

CI builds use:
```bash
./configure --enable-gpl --enable-nonfree --enable-memory-poisoning --assert-level=2
make -j$(nproc)
make fate SAMPLES=$PWD/fate-suite -j$(nproc)
```

## Troubleshooting

### Common Issues and Solutions
- **"nasm not found"**: Install with `sudo apt-get install nasm yasm`
- **Build failures**: Check `ffbuild/config.log` for detailed error information
- **Missing dependencies**: Use `./configure --help` to see disable options for missing libs
- **Slow builds**: Ensure using `make -j$(nproc)` for parallel compilation

### Network Issues
- Pre-commit hooks may timeout due to PyPI connectivity
- FATE tests require external sample files (not always available)
- Document known failures rather than trying alternative approaches

### Platform-Specific Notes
- Build system supports out-of-tree builds: use absolute path to configure
- Some tests require specific hardware (GPU acceleration, etc.)
- Cross-compilation supported via configure flags

## Development Workflow

1. **Always build first**: Run full configure && make cycle
2. **Test basic functionality**: Run version checks and simple processing test  
3. **Run relevant tests**: Use checkasm and filter tests for validation
4. **Build examples**: Ensure API compatibility with example programs
5. **Manual validation**: Exercise actual multimedia processing scenarios
6. **Documentation**: Update relevant .texi files if changing user-facing features

Remember: FFmpeg development uses mailing lists, not GitHub PRs. This is for internal development only.