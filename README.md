```bash
color-looks-mvp-v.1/
├─ README.md
├─ LICENSE
├─ .gitignore
├─ .editorconfig
├─ .clang-format
├─ CMakeLists.txt
├─ cmake/
│  ├─ Toolchains/
│  ├─ FindOpenColorIO.cmake
│  ├─ FindMetal.cmake
│  └─ CompileShaders.cmake
├─ third_party/
│  ├─ ocio/                         # optional vendored; prefer package manager/submodule
│  ├─ nlohmann_json/                # if used
│  └─ stb/                          # optional utilities
├─ docs/
│  ├─ technical-spec.md
│  ├─ color-management.md
│  ├─ look-pipeline.md
│  ├─ preset-authoring.md
│  ├─ performance.md
│  └─ testing.md
├─ tools/
│  ├─ preset_validator/
│  │  ├─ CMakeLists.txt
│  │  └─ main.cpp
│  ├─ preset_packager/
│  │  ├─ main.py                    # optional: zip/sign packs
│  │  └─ requirements.txt
│  └─ ocio_inspector/
│     └─ main.cpp
├─ assets/
│  ├─ presets/
│  │  ├─ builtin/
│  │  │  ├─ neutral_film.json
│  │  │  ├─ soft_contrast_film.json
│  │  │  └─ ...
│  │  └─ packs/
│  │     └─ starter_pack/
│  │        ├─ pack.json
│  │        └─ looks/
│  │           ├─ neutral_film.json
│  │           └─ soft_contrast_film.json
│  ├─ thumbnails/                   # optional UI thumbnails
│  └─ ocio/
│     └─ config.ocio                # optional bundled OCIO config for override workflows
├─ src/
│  ├─ common/
│  │  ├─ include/
│  │  │  ├─ colorlooks/common/Assert.hpp
│  │  │  ├─ colorlooks/common/Hash.hpp
│  │  │  ├─ colorlooks/common/Logging.hpp
│  │  │  ├─ colorlooks/common/Math.hpp
│  │  │  ├─ colorlooks/common/Span.hpp
│  │  │  ├─ colorlooks/common/Types.hpp
│  │  │  └─ colorlooks/common/Version.hpp
│  │  └─ src/
│  │     ├─ Hash.cpp
│  │     ├─ Logging.cpp
│  │     └─ Version.cpp
│  ├─ color/
│  │  ├─ include/
│  │  │  ├─ colorlooks/color/ColorSpaces.hpp
│  │  │  ├─ colorlooks/color/OCIOManager.hpp
│  │  │  ├─ colorlooks/color/ToneMap.hpp
│  │  │  ├─ colorlooks/color/GamutCompress.hpp
│  │  │  ├─ colorlooks/color/Curves.hpp
│  │  │  └─ colorlooks/color/Matrix3x3.hpp
│  │  └─ src/
│  │     ├─ OCIOManager.cpp
│  │     ├─ ToneMap.cpp
│  │     ├─ GamutCompress.cpp
│  │     ├─ Curves.cpp
│  │     └─ Matrix3x3.cpp
│  ├─ presets/
│  │  ├─ include/
│  │  │  ├─ colorlooks/presets/Preset.hpp
│  │  │  ├─ colorlooks/presets/PresetIO.hpp
│  │  │  ├─ colorlooks/presets/PresetSchema.hpp
│  │  │  └─ colorlooks/presets/PresetVersioning.hpp
│  │  └─ src/
│  │     ├─ Preset.cpp
│  │     ├─ PresetIO.cpp
│  │     ├─ PresetSchema.cpp
│  │     └─ PresetVersioning.cpp
│  ├─ engine/
│  │  ├─ include/
│  │  │  ├─ colorlooks/engine/LookEngine.hpp
│  │  │  ├─ colorlooks/engine/RenderGraph.hpp
│  │  │  ├─ colorlooks/engine/Nodes.hpp
│  │  │  ├─ colorlooks/engine/Params.hpp
│  │  │  ├─ colorlooks/engine/Frame.hpp
│  │  │  ├─ colorlooks/engine/Cache.hpp
│  │  │  └─ colorlooks/engine/CPUFallback.hpp
│  │  └─ src/
│  │     ├─ LookEngine.cpp
│  │     ├─ RenderGraph.cpp
│  │     ├─ Nodes.cpp
│  │     ├─ Params.cpp
│  │     ├─ Cache.cpp
│  │     └─ CPUFallback.cpp
│  ├─ gpu/
│  │  ├─ include/
│  │  │  ├─ colorlooks/gpu/GPUBackend.hpp
│  │  │  ├─ colorlooks/gpu/KernelIDs.hpp
│  │  │  └─ colorlooks/gpu/Dispatch.hpp
│  │  ├─ metal/
│  │  │  ├─ include/
│  │  │  │  ├─ colorlooks/gpu/metal/MetalBackend.hpp
│  │  │  │  └─ colorlooks/gpu/metal/MetalPipelineCache.hpp
│  │  │  ├─ src/
│  │  │  │  ├─ MetalBackend.mm
│  │  │  │  ├─ MetalPipelineCache.mm
│  │  │  │  └─ MetalUtils.mm
│  │  │  └─ shaders/
│  │  │     ├─ Common.metal
│  │  │     ├─ ColorOps.metal
│  │  │     ├─ ToneMap.metal
│  │  │     ├─ Grain.metal
│  │  │     ├─ GamutCompress.metal
│  │  │     └─ PipelineKernels.metal
│  │  └─ cpu/
│  │     └─ (optional) reference kernels
│  ├─ ofx/
│  │  ├─ include/
│  │  │  ├─ colorlooks/ofx/OfxPlugin.hpp
│  │  │  ├─ colorlooks/ofx/ParamsBinding.hpp
│  │  │  └─ colorlooks/ofx/HostUtils.hpp
│  │  └─ src/
│  │     ├─ OfxMain.cpp
│  │     ├─ OfxPlugin.cpp
│  │     ├─ ParamsBinding.cpp
│  │     └─ HostUtils.cpp
│  └─ ui/
│     ├─ include/
│     │  ├─ colorlooks/ui/ParamModel.hpp
│     │  └─ colorlooks/ui/LookSelector.hpp
│     └─ src/
│        ├─ ParamModel.cpp
│        └─ LookSelector.cpp
├─ tests/
│  ├─ CMakeLists.txt
│  ├─ test_ramps.cpp
│  ├─ test_gamut.cpp
│  ├─ test_tonemap.cpp
│  ├─ test_presets.cpp
│  └─ fixtures/
│     ├─ ramps.exr
│     ├─ chart.exr
│     └─ skin.exr
├─ packaging/
│  ├─ ofx/
│  │  ├─ Info.plist
│  │  ├─ manifest.json
│  │  ├─ install_mac.sh
│  │  └─ bundle_layout.md
│  └─ codesign/
│     └─ entitlements.plist
└─ ci/
   ├─ build_macos.yml
   ├─ test.yml
   └─ release.yml
'''
