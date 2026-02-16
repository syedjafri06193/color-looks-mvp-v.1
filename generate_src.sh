bash generate_src.sh
#!/usr/bin/env bash
set -euo pipefail

ROOT="src"

mkdir -p "$ROOT"

write() {
  local path="$1"
  shift
  mkdir -p "$(dirname "$path")"
  cat > "$path" <<'EOF'
'"$@"'
EOF
}

# -------------------------
# src/CMakeLists.txt
# -------------------------
cat > "$ROOT/CMakeLists.txt" <<'EOF'
add_subdirectory(common)
add_subdirectory(color)
add_subdirectory(presets)
add_subdirectory(engine)
add_subdirectory(gpu)
add_subdirectory(ui)

option(COLORLOOKS_BUILD_OFX "Build OFX plugin (requires OFX headers/SDK)" OFF)
if(COLORLOOKS_BUILD_OFX)
    add_subdirectory(ofx)
endif()
EOF

# =========================================================
# COMMON
# =========================================================
mkdir -p "$ROOT/common/include/colorlooks/common" "$ROOT/common/src"

cat > "$ROOT/common/CMakeLists.txt" <<'EOF'
add_library(colorlooks_common
    src/Hash.cpp
    src/Logging.cpp
    src/Version.cpp
)

target_include_directories(colorlooks_common PUBLIC
    ${CMAKE_CURRENT_SOURCE_DIR}/include
)

target_compile_features(colorlooks_common PUBLIC cxx_std_17)
EOF

cat > "$ROOT/common/include/colorlooks/common/Types.hpp" <<'EOF'
#pragma once
#include <cstdint>

namespace colorlooks
{
    using i8  = std::int8_t;
    using i16 = std::int16_t;
    using i32 = std::int32_t;
    using i64 = std::int64_t;

    using u8  = std::uint8_t;
    using u16 = std::uint16_t;
    using u32 = std::uint32_t;
    using u64 = std::uint64_t;

    using f32 = float;
    using f64 = double;
}
EOF

cat > "$ROOT/common/include/colorlooks/common/Assert.hpp" <<'EOF'
#pragma once
#include <cstdlib>
#include <iostream>

namespace colorlooks
{
    [[noreturn]] inline void AssertFail(const char* expr, const char* file, int line, const char* msg)
    {
        std::cerr << "ASSERT FAILED: (" << expr << ") at " << file << ":" << line;
        if (msg) std::cerr << " | " << msg;
        std::cerr << std::endl;
        std::abort();
    }
}

#define COLORLOOKS_ASSERT(expr) \
    do { if (!(expr)) { ::colorlooks::AssertFail(#expr, __FILE__, __LINE__, nullptr); } } while (0)

#define COLORLOOKS_ASSERT_MSG(expr, msg) \
    do { if (!(expr)) { ::colorlooks::AssertFail(#expr, __FILE__, __LINE__, (msg)); } } while (0)
EOF

cat > "$ROOT/common/include/colorlooks/common/Span.hpp" <<'EOF'
#pragma once
#include <cstddef>
#include <type_traits>

namespace colorlooks
{
    template <typename T>
    class Span
    {
    public:
        using element_type = T;
        using value_type   = std::remove_cv_t<T>;

        Span() : m_ptr(nullptr), m_len(0) {}
        Span(T* ptr, std::size_t len) : m_ptr(ptr), m_len(len) {}

        T* data() const { return m_ptr; }
        std::size_t size() const { return m_len; }
        bool empty() const { return m_len == 0; }

        T& operator[](std::size_t i) const { return m_ptr[i]; }

        T* begin() const { return m_ptr; }
        T* end() const { return m_ptr + m_len; }

    private:
        T* m_ptr;
        std::size_t m_len;
    };
}
EOF

cat > "$ROOT/common/include/colorlooks/common/Math.hpp" <<'EOF'
#pragma once
#include <algorithm>
#include <cmath>

namespace colorlooks
{
    template <typename T>
    inline T Clamp(T v, T lo, T hi)
    {
        return std::min(std::max(v, lo), hi);
    }

    template <typename T>
    inline T Lerp(T a, T b, T t)
    {
        return a + (b - a) * t;
    }

    inline float Smoothstep(float edge0, float edge1, float x)
    {
        float t = Clamp((x - edge0) / (edge1 - edge0), 0.0f, 1.0f);
        return t * t * (3.0f - 2.0f * t);
    }

    inline bool NearlyEqual(float a, float b, float eps = 1e-6f)
    {
        return std::fabs(a - b) <= eps;
    }
}
EOF

cat > "$ROOT/common/include/colorlooks/common/Hash.hpp" <<'EOF'
#pragma once
#include <cstddef>
#include <string_view>
#include "colorlooks/common/Types.hpp"

namespace colorlooks
{
    // 64-bit FNV-1a
    class Hasher64
    {
    public:
        Hasher64();

        void AddBytes(const void* data, std::size_t size);
        void AddU64(u64 v);
        void AddI64(i64 v);
        void AddF32(float v);
        void AddString(std::string_view s);

        u64 Final() const;

    private:
        u64 m_hash;
    };

    u64 HashBytes64(const void* data, std::size_t size);
    u64 HashString64(std::string_view s);
}
EOF

cat > "$ROOT/common/include/colorlooks/common/Logging.hpp" <<'EOF'
#pragma once
#include <string>

namespace colorlooks
{
    enum class LogLevel
    {
        Debug,
        Info,
        Warn,
        Error
    };

    void Log(LogLevel level, const std::string& msg);

    void LogDebug(const std::string& msg);
    void LogInfo(const std::string& msg);
    void LogWarn(const std::string& msg);
    void LogError(const std::string& msg);
}
EOF

cat > "$ROOT/common/include/colorlooks/common/Version.hpp" <<'EOF'
#pragma once
#include <string>

namespace colorlooks
{
    struct Version
    {
        int major = 1;
        int minor = 0;
        int patch = 0;
    };

    Version GetVersion();
    std::string GetVersionString();

    // Naming / IDs (stable, code-safe)
    constexpr const char* kCompanyDisplayName = "client of AXIOMS";
    constexpr const char* kCompanyIdPrefix    = "com.clientofaxioms";
    constexpr const char* kProductName        = "color-looks-mvp-v.1";

    constexpr const char* kPresetSchemaId     = "com.clientofaxioms.colorlooks.lookpreset";
    constexpr const char* kPackSchemaId       = "com.clientofaxioms.colorlooks.lookpack";
    constexpr const char* kOfxPluginId        = "com.clientofaxioms.colorlooks.ofx";
}
EOF

cat > "$ROOT/common/src/Hash.cpp" <<'EOF'
#include "colorlooks/common/Hash.hpp"

namespace colorlooks
{
    static constexpr u64 kFNVOffset = 14695981039346656037ull;
    static constexpr u64 kFNVPrime  = 1099511628211ull;

    Hasher64::Hasher64() : m_hash(kFNVOffset) {}

    void Hasher64::AddBytes(const void* data, std::size_t size)
    {
        const u8* p = static_cast<const u8*>(data);
        for (std::size_t i = 0; i < size; ++i)
        {
            m_hash ^= static_cast<u64>(p[i]);
            m_hash *= kFNVPrime;
        }
    }

    void Hasher64::AddU64(u64 v) { AddBytes(&v, sizeof(v)); }
    void Hasher64::AddI64(i64 v) { AddBytes(&v, sizeof(v)); }
    void Hasher64::AddF32(float v) { AddBytes(&v, sizeof(v)); }

    void Hasher64::AddString(std::string_view s)
    {
        AddBytes(s.data(), s.size());
    }

    u64 Hasher64::Final() const { return m_hash; }

    u64 HashBytes64(const void* data, std::size_t size)
    {
        Hasher64 h;
        h.AddBytes(data, size);
        return h.Final();
    }

    u64 HashString64(std::string_view s)
    {
        Hasher64 h;
        h.AddString(s);
        return h.Final();
    }
}
EOF

cat > "$ROOT/common/src/Logging.cpp" <<'EOF'
#include "colorlooks/common/Logging.hpp"
#include <iostream>

namespace colorlooks
{
    static const char* LevelToString(LogLevel level)
    {
        switch (level)
        {
            case LogLevel::Debug: return "DEBUG";
            case LogLevel::Info:  return "INFO";
            case LogLevel::Warn:  return "WARN";
            case LogLevel::Error: return "ERROR";
            default:              return "INFO";
        }
    }

    void Log(LogLevel level, const std::string& msg)
    {
        std::cerr << "[" << LevelToString(level) << "] " << msg << std::endl;
    }

    void LogDebug(const std::string& msg) { Log(LogLevel::Debug, msg); }
    void LogInfo(const std::string& msg)  { Log(LogLevel::Info, msg); }
    void LogWarn(const std::string& msg)  { Log(LogLevel::Warn, msg); }
    void LogError(const std::string& msg) { Log(LogLevel::Error, msg); }
}
EOF

cat > "$ROOT/common/src/Version.cpp" <<'EOF'
#include "colorlooks/common/Version.hpp"

namespace colorlooks
{
    Version GetVersion()
    {
        return Version{1, 0, 0};
    }

    std::string GetVersionString()
    {
        auto v = GetVersion();
        return std::to_string(v.major) + "." + std::to_string(v.minor) + "." + std::to_string(v.patch);
    }
}
EOF

# =========================================================
# COLOR
# =========================================================
mkdir -p "$ROOT/color/include/colorlooks/color" "$ROOT/color/src"

cat > "$ROOT/color/CMakeLists.txt" <<'EOF'
add_library(colorlooks_color
    src/OCIOManager.cpp
    src/ToneMap.cpp
    src/GamutCompress.cpp
    src/Curves.cpp
    src/Matrix3x3.cpp
)

target_include_directories(colorlooks_color PUBLIC
    ${CMAKE_CURRENT_SOURCE_DIR}/include
)

target_link_libraries(colorlooks_color PUBLIC
    colorlooks_common
    OpenColorIO::OpenColorIO
)

target_compile_features(colorlooks_color PUBLIC cxx_std_17)
EOF

cat > "$ROOT/color/include/colorlooks/color/Matrix3x3.hpp" <<'EOF'
#pragma once
#include "colorlooks/common/Types.hpp"

namespace colorlooks
{
    struct Vec3
    {
        f32 x = 0, y = 0, z = 0;
    };

    struct Matrix3x3
    {
        // Row-major: m[row][col]
        f32 m[3][3] = {
            {1,0,0},
            {0,1,0},
            {0,0,1}
        };

        static Matrix3x3 Identity();

        Vec3 Mul(const Vec3& v) const;
        Matrix3x3 LerpTo(const Matrix3x3& other, f32 t) const;
    };
}
EOF

cat > "$ROOT/color/include/colorlooks/color/ColorSpaces.hpp" <<'EOF'
#pragma once
#include <string>

namespace colorlooks
{
    struct ColorSpaces
    {
        static constexpr const char* kSceneLinear = "scene_linear";
        static constexpr const char* kHostInput   = "host_input";
        static constexpr const char* kHostOutput  = "host_output";
    };

    struct OCIOContextSpec
    {
        // "builtin_or_host", "builtin", "path"
        std::string configMode = "builtin_or_host";
        std::string configPath = "";

        std::string inputSpace   = "host_input";
        std::string workingSpace = "scene_linear";
        std::string outputSpace  = "host_output";
    };
}
EOF

cat > "$ROOT/color/include/colorlooks/color/OCIOManager.hpp" <<'EOF'
#pragma once
#include <OpenColorIO/OpenColorIO.h>
#include <string>
#include "colorlooks/color/ColorSpaces.hpp"

namespace colorlooks
{
    namespace OCIO = OCIO_NAMESPACE;

    class OCIOManager
    {
    public:
        OCIOManager();
        ~OCIOManager();

        void Load(const OCIOContextSpec& spec);
        bool IsLoaded() const;
        std::string GetConfigName() const;

        OCIO::ConstProcessorRcPtr MakeProcessor(const std::string& src, const std::string& dst) const;

    private:
        OCIO::ConstConfigRcPtr m_config;
        OCIOContextSpec m_spec;
    };
}
EOF

cat > "$ROOT/color/include/colorlooks/color/ToneMap.hpp" <<'EOF'
#pragma once
#include "colorlooks/common/Types.hpp"

namespace colorlooks
{
    struct ToneMapParams
    {
        f32 shoulderStrength = 0.6f; // [0..1]
        f32 toeStrength      = 0.2f; // [0..1]
        bool preserveHue     = true;
    };

    void ToneMapFilmicV1(f32& r, f32& g, f32& b, const ToneMapParams& p);
}
EOF

cat > "$ROOT/color/include/colorlooks/color/GamutCompress.hpp" <<'EOF'
#pragma once
#include "colorlooks/common/Types.hpp"

namespace colorlooks
{
    struct GamutCompressParams
    {
        f32 strength = 0.5f; // [0..1]
    };

    void GamutCompressNeutralAxis(f32& r, f32& g, f32& b, const GamutCompressParams& p);
}
EOF

cat > "$ROOT/color/include/colorlooks/color/Curves.hpp" <<'EOF'
#pragma once
#include <vector>
#include "colorlooks/common/Types.hpp"

namespace colorlooks
{
    struct CurvePoint
    {
        f32 x = 0;
        f32 y = 0;
    };

    class Curve1D
    {
    public:
        void SetPoints(std::vector<CurvePoint> pts);
        bool Empty() const { return m_pts.empty(); }
        f32 Eval(f32 x) const;

    private:
        std::vector<CurvePoint> m_pts;
    };

    struct CurvesParams
    {
        Curve1D lumaVsSat; // x:[0..1], y:delta in [-1..+1]
    };

    void ApplyCurvesLumaVsSat(f32& r, f32& g, f32& b, const CurvesParams& c);
}
EOF

cat > "$ROOT/color/src/Matrix3x3.cpp" <<'EOF'
#include "colorlooks/color/Matrix3x3.hpp"
#include "colorlooks/common/Math.hpp"

namespace colorlooks
{
    Matrix3x3 Matrix3x3::Identity()
    {
        return Matrix3x3{};
    }

    Vec3 Matrix3x3::Mul(const Vec3& v) const
    {
        Vec3 out;
        out.x = m[0][0]*v.x + m[0][1]*v.y + m[0][2]*v.z;
        out.y = m[1][0]*v.x + m[1][1]*v.y + m[1][2]*v.z;
        out.z = m[2][0]*v.x + m[2][1]*v.y + m[2][2]*v.z;
        return out;
    }

    Matrix3x3 Matrix3x3::LerpTo(const Matrix3x3& other, f32 t) const
    {
        Matrix3x3 out;
        t = Clamp(t, 0.0f, 1.0f);
        for (int r = 0; r < 3; ++r)
            for (int c = 0; c < 3; ++c)
                out.m[r][c] = Lerp(m[r][c], other.m[r][c], t);
        return out;
    }
}
EOF

cat > "$ROOT/color/src/OCIOManager.cpp" <<'EOF'
#include "colorlooks/color/OCIOManager.hpp"
#include "colorlooks/common/Logging.hpp"
#include <stdexcept>

namespace colorlooks
{
    OCIOManager::OCIOManager() = default;
    OCIOManager::~OCIOManager() = default;

    void OCIOManager::Load(const OCIOContextSpec& spec)
    {
        m_spec = spec;

        try
        {
            if (spec.configMode == "path")
            {
                if (spec.configPath.empty())
                    throw std::runtime_error("OCIO configMode=path but configPath is empty.");

                m_config = OCIO::Config::CreateFromFile(spec.configPath.c_str());
                LogInfo("Loaded OCIO config from path: " + spec.configPath);
            }
            else
            {
                // builtin_or_host: use current config (typically respects $OCIO)
                m_config = OCIO::GetCurrentConfig();
                LogInfo("Loaded OCIO config from current environment/host context.");
            }
        }
        catch (const std::exception& e)
        {
            m_config.reset();
            LogError(std::string("Failed to load OCIO config: ") + e.what());
            throw;
        }
    }

    bool OCIOManager::IsLoaded() const
    {
        return static_cast<bool>(m_config);
    }

    std::string OCIOManager::GetConfigName() const
    {
        if (!m_config) return "UNLOADED";
        const char* name = m_config->getName();
        return name ? std::string(name) : std::string("Unnamed OCIO Config");
    }

    OCIO::ConstProcessorRcPtr OCIOManager::MakeProcessor(const std::string& src, const std::string& dst) const
    {
        if (!m_config)
            throw std::runtime_error("OCIOManager::MakeProcessor called before config loaded.");

        return m_config->getProcessor(src.c_str(), dst.c_str());
    }
}
EOF

cat > "$ROOT/color/src/ToneMap.cpp" <<'EOF'
#include "colorlooks/color/ToneMap.hpp"
#include "colorlooks/common/Math.hpp"
#include <cmath>
#include <algorithm>

namespace colorlooks
{
    static inline float Luma709(float r, float g, float b)
    {
        return 0.2126f*r + 0.7152f*g + 0.0722f*b;
    }

    // Simple filmic-ish curve (MVP): toe lift + shoulder compression.
    static inline float FilmicCurve(float x, float toe, float shoulder)
    {
        x = std::max(0.0f, x);

        float t = Lerp(1.0f, 0.25f, Clamp(toe, 0.0f, 1.0f));
        float y = std::log1p(x * t) / std::log1p(t);

        float s = Lerp(1.0f, 2.0f, Clamp(shoulder, 0.0f, 1.0f));
        y = y / (1.0f + (y * (s - 1.0f)));

        return y;
    }

    void ToneMapFilmicV1(float& r, float& g, float& b, const ToneMapParams& p)
    {
        if (!p.preserveHue)
        {
            r = FilmicCurve(r, p.toeStrength, p.shoulderStrength);
            g = FilmicCurve(g, p.toeStrength, p.shoulderStrength);
            b = FilmicCurve(b, p.toeStrength, p.shoulderStrength);
            return;
        }

        float l0 = Luma709(r, g, b);
        float l1 = FilmicCurve(l0, p.toeStrength, p.shoulderStrength);

        if (l0 > 1e-6f)
        {
            float k = l1 / l0;
            r *= k; g *= k; b *= k;
        }
        else
        {
            r = FilmicCurve(r, p.toeStrength, p.shoulderStrength);
            g = FilmicCurve(g, p.toeStrength, p.shoulderStrength);
            b = FilmicCurve(b, p.toeStrength, p.shoulderStrength);
        }
    }
}
EOF

cat > "$ROOT/color/src/GamutCompress.cpp" <<'EOF'
#include "colorlooks/color/GamutCompress.hpp"
#include "colorlooks/common/Math.hpp"
#include <algorithm>

namespace colorlooks
{
    static inline float Luma709(float r, float g, float b)
    {
        return 0.2126f*r + 0.7152f*g + 0.0722f*b;
    }

    void GamutCompressNeutralAxis(float& r, float& g, float& b, const GamutCompressParams& p)
    {
        float strength = Clamp(p.strength, 0.0f, 1.0f);

        float l = Luma709(r, g, b);

        float minc = std::min({r, g, b});
        float maxc = std::max({r, g, b});

        float neg = (minc < 0.0f) ? (-minc) : 0.0f;
        float hi  = (maxc > 1.0f) ? (maxc - 1.0f) : 0.0f;

        float amount = Clamp((neg + hi) * 0.5f, 0.0f, 1.0f) * strength;

        r = Lerp(r, l, amount);
        g = Lerp(g, l, amount);
        b = Lerp(b, l, amount);

        r = std::max(0.0f, r);
        g = std::max(0.0f, g);
        b = std::max(0.0f, b);
    }
}
EOF

cat > "$ROOT/color/src/Curves.cpp" <<'EOF'
#include "colorlooks/color/Curves.hpp"
#include "colorlooks/common/Math.hpp"
#include <algorithm>

namespace colorlooks
{
    void Curve1D::SetPoints(std::vector<CurvePoint> pts)
    {
        std::sort(pts.begin(), pts.end(),
                  [](const CurvePoint& a, const CurvePoint& b) { return a.x < b.x; });
        m_pts = std::move(pts);
    }

    float Curve1D::Eval(float x) const
    {
        if (m_pts.empty()) return 0.0f;
        if (x <= m_pts.front().x) return m_pts.front().y;
        if (x >= m_pts.back().x)  return m_pts.back().y;

        for (size_t i = 0; i + 1 < m_pts.size(); ++i)
        {
            const auto& a = m_pts[i];
            const auto& b = m_pts[i + 1];
            if (x >= a.x && x <= b.x)
            {
                float t = (x - a.x) / (b.x - a.x);
                return Lerp(a.y, b.y, t);
            }
        }
        return m_pts.back().y;
    }

    static inline float Luma709(float r, float g, float b)
    {
        return 0.2126f*r + 0.7152f*g + 0.0722f*b;
    }

    void ApplyCurvesLumaVsSat(float& r, float& g, float& b, const CurvesParams& c)
    {
        if (c.lumaVsSat.Empty()) return;

        float l = Clamp(Luma709(r, g, b), 0.0f, 1.0f);
        float delta = c.lumaVsSat.Eval(l);
        float satMul = Clamp(1.0f + delta, 0.0f, 4.0f);

        float cr = r - l;
        float cg = g - l;
        float cb = b - l;

        r = std::max(0.0f, l + cr * satMul);
        g = std::max(0.0f, l + cg * satMul);
        b = std::max(0.0f, l + cb * satMul);
    }
}
EOF

# =========================================================
# PRESETS
# =========================================================
mkdir -p "$ROOT/presets/include/colorlooks/presets" "$ROOT/presets/src" "$ROOT/presets/schema"

cat > "$ROOT/presets/CMakeLists.txt" <<'EOF'
add_library(colorlooks_presets
    src/Preset.cpp
    src/PresetIO.cpp
    src/PresetSchema.cpp
    src/PresetVersioning.cpp
)

target_include_directories(colorlooks_presets PUBLIC
    ${CMAKE_CURRENT_SOURCE_DIR}/include
)

target_link_libraries(colorlooks_presets PUBLIC
    colorlooks_common
)

target_compile_features(colorlooks_presets PUBLIC cxx_std_17)
EOF

cat > "$ROOT/presets/include/colorlooks/presets/Preset.hpp" <<'EOF'
#pragma once
#include <array>
#include <string>
#include <vector>

namespace colorlooks
{
    struct PresetDefaults
    {
        float exposureStops  = 0.0f;
        float contrast       = 1.0f;
        float pivot          = 0.18f;
        float saturation     = 1.0f;

        float warmCool       = 0.0f;
        std::array<float,3> shadowTint   {0,0,0}; // signed
        std::array<float,3> highlightTint{0,0,0}; // signed

        float filmStrength   = 1.0f;
        float grainAmount    = 0.0f;
        float halationAmount = 0.0f;
    };

    struct ToneMapSpec
    {
        std::string model = "filmic_v1";
        float shoulderStrength = 0.6f;
        float toeStrength      = 0.2f;
        bool preserveHue       = true;
    };

    struct FilmMatrixSpec
    {
        bool enabled = true;
        float m[3][3] = {
            {1,0,0},
            {0,1,0},
            {0,0,1}
        };
        float strength = 1.0f;
    };

    struct GamutCompressSpec
    {
        bool enabled = true;
        std::string method = "neutral_axis";
        float strength = 0.5f;
    };

    struct GrainSpec
    {
        bool enabled = true;
        std::string model = "procedural_v1";
        float size = 0.45f;
        float colorful = 0.35f;
        float shadowsBoost = 0.2f;
        float highlightsRolloff = 0.7f;
    };

    struct HalationSpec
    {
        bool enabled = false;
        float threshold = 1.2f;
        float radius = 6.0f;
        float strength = 0.0f;
    };

    struct WorkingSpaceSpec
    {
        std::string type = "ocio";
        std::string config = "builtin_or_host"; // builtin_or_host|builtin|path
        std::string configPath;

        std::string input   = "host_input";
        std::string working = "scene_linear";
        std::string output  = "host_output";
    };

    struct PresetPipeline
    {
        WorkingSpaceSpec workingSpace;
        ToneMapSpec toneMap;
        FilmMatrixSpec filmMatrix;
        GamutCompressSpec gamutCompress;
        GrainSpec grain;
        HalationSpec halation;
    };

    struct Preset
    {
        std::string schema;
        int schemaVersion = 1;

        std::string id;
        std::string name;
        std::string description;
        std::string author;
        std::vector<std::string> tags;

        PresetDefaults defaults;
        PresetPipeline pipeline;
    };
}
EOF

cat > "$ROOT/presets/include/colorlooks/presets/PresetIO.hpp" <<'EOF'
#pragma once
#include <string>
#include "colorlooks/presets/Preset.hpp"

namespace colorlooks
{
    // Reads preset JSON from disk.
    // If nlohmann/json is available, it parses; otherwise returns false (MVP stub).
    bool LoadPresetFromFile(const std::string& path, Preset& out, std::string* err = nullptr);

    // Writes preset JSON to disk (requires nlohmann/json to be available).
    bool SavePresetToFile(const std::string& path, const Preset& preset, std::string* err = nullptr);
}
EOF

cat > "$ROOT/presets/include/colorlooks/presets/PresetSchema.hpp" <<'EOF'
#pragma once
#include <string>

namespace colorlooks
{
    // Returns embedded schema ID strings used at runtime (not JSON Schema itself).
    const char* PresetSchemaId();
    const char* PackSchemaId();

    // Minimal check: ensure schema + schema_version are correct.
    bool ValidateSchemaFields(const std::string& schema, int schemaVersion, std::string* err = nullptr);
}
EOF

cat > "$ROOT/presets/include/colorlooks/presets/PresetVersioning.hpp" <<'EOF'
#pragma once
#include "colorlooks/presets/Preset.hpp"

namespace colorlooks
{
    // For future migrations; currently schema_version 1 only.
    bool UpgradePresetInPlace(Preset& preset);
}
EOF

cat > "$ROOT/presets/src/Preset.cpp" <<'EOF'
#include "colorlooks/presets/Preset.hpp"
EOF

cat > "$ROOT/presets/src/PresetSchema.cpp" <<'EOF'
#include "colorlooks/presets/PresetSchema.hpp"
#include "colorlooks/common/Version.hpp"

namespace colorlooks
{
    const char* PresetSchemaId() { return kPresetSchemaId; }
    const char* PackSchemaId()   { return kPackSchemaId; }

    bool ValidateSchemaFields(const std::string& schema, int schemaVersion, std::string* err)
    {
        if (schema != kPresetSchemaId)
        {
            if (err) *err = "Invalid preset schema id: " + schema;
            return false;
        }
        if (schemaVersion != 1)
        {
            if (err) *err = "Unsupported schema_version: " + std::to_string(schemaVersion);
            return false;
        }
        return true;
    }
}
EOF

cat > "$ROOT/presets/src/PresetVersioning.cpp" <<'EOF'
#include "colorlooks/presets/PresetVersioning.hpp"

namespace colorlooks
{
    bool UpgradePresetInPlace(Preset& preset)
    {
        // v1 only for MVP. Add migrations here later.
        (void)preset;
        return true;
    }
}
EOF

cat > "$ROOT/presets/src/PresetIO.cpp" <<'EOF'
#include "colorlooks/presets/PresetIO.hpp"
#include "colorlooks/presets/PresetSchema.hpp"
#include "colorlooks/common/Logging.hpp"

#include <fstream>
#include <sstream>

#if __has_include(<nlohmann/json.hpp>)
  #include <nlohmann/json.hpp>
  #define COLORLOOKS_HAS_JSON 1
#else
  #define COLORLOOKS_HAS_JSON 0
#endif

namespace colorlooks
{
#if COLORLOOKS_HAS_JSON
    using json = nlohmann::json;

    static bool ReadAll(const std::string& path, std::string& out, std::string* err)
    {
        std::ifstream f(path);
        if (!f)
        {
            if (err) *err = "Failed to open: " + path;
            return false;
        }
        std::stringstream ss;
        ss << f.rdbuf();
        out = ss.str();
        return true;
    }

    static void GetVec3(const json& j, const char* key, std::array<float,3>& out)
    {
        if (!j.contains(key)) return;
        auto a = j.at(key);
        if (!a.is_array() || a.size() != 3) return;
        out[0] = a[0].get<float>();
        out[1] = a[1].get<float>();
        out[2] = a[2].get<float>();
    }

    bool LoadPresetFromFile(const std::string& path, Preset& out, std::string* err)
    {
        std::string s;
        if (!ReadAll(path, s, err)) return false;

        json j;
        try { j = json::parse(s); }
        catch (const std::exception& e)
        {
            if (err) *err = std::string("JSON parse error: ") + e.what();
            return false;
        }

        out.schema        = j.value("schema", "");
        out.schemaVersion = j.value("schema_version", 0);

        if (!ValidateSchemaFields(out.schema, out.schemaVersion, err))
            return false;

        out.id          = j.value("id", "");
        out.name        = j.value("name", "");
        out.description = j.value("description", "");
        out.author      = j.value("author", "");

        if (j.contains("tags") && j["tags"].is_array())
        {
            out.tags.clear();
            for (auto& t : j["tags"]) out.tags.push_back(t.get<std::string>());
        }

        if (j.contains("defaults"))
        {
            const auto& d = j["defaults"];
            out.defaults.exposureStops  = d.value("exposure_stops", 0.0f);
            out.defaults.contrast       = d.value("contrast", 1.0f);
            out.defaults.pivot          = d.value("pivot", 0.18f);
            out.defaults.saturation     = d.value("saturation", 1.0f);
            out.defaults.warmCool       = d.value("warm_cool", 0.0f);
            GetVec3(d, "shadow_tint", out.defaults.shadowTint);
            GetVec3(d, "highlight_tint", out.defaults.highlightTint);
            out.defaults.filmStrength   = d.value("film_strength", 1.0f);
            out.defaults.grainAmount    = d.value("grain_amount", 0.0f);
            out.defaults.halationAmount = d.value("halation_amount", 0.0f);
        }

        if (j.contains("pipeline"))
        {
            const auto& p = j["pipeline"];

            if (p.contains("working_space"))
            {
                const auto& ws = p["working_space"];
                out.pipeline.workingSpace.type       = ws.value("type", "ocio");
                out.pipeline.workingSpace.config     = ws.value("config", "builtin_or_host");
                out.pipeline.workingSpace.configPath = ws.value("config_path", "");
                out.pipeline.workingSpace.input      = ws.value("input", "host_input");
                out.pipeline.workingSpace.working    = ws.value("working", "scene_linear");
                out.pipeline.workingSpace.output     = ws.value("output", "host_output");
            }

            if (p.contains("tone_map"))
            {
                const auto& tm = p["tone_map"];
                out.pipeline.toneMap.model            = tm.value("model", "filmic_v1");
                out.pipeline.toneMap.shoulderStrength = tm.value("shoulder_strength", 0.6f);
                out.pipeline.toneMap.toeStrength      = tm.value("toe_strength", 0.2f);
                out.pipeline.toneMap.preserveHue      = tm.value("preserve_hue", true);
            }

            if (p.contains("film_matrix"))
            {
                const auto& fm = p["film_matrix"];
                out.pipeline.filmMatrix.enabled  = fm.value("enabled", true);
                out.pipeline.filmMatrix.strength = fm.value("strength", 1.0f);

                if (fm.contains("matrix_3x3") && fm["matrix_3x3"].is_array() && fm["matrix_3x3"].size() == 3)
                {
                    for (int r=0; r<3; ++r)
                        for (int c=0; c<3; ++c)
                            out.pipeline.filmMatrix.m[r][c] = fm["matrix_3x3"][r][c].get<float>();
                }
            }

            if (p.contains("gamut_compress"))
            {
                const auto& gc = p["gamut_compress"];
                out.pipeline.gamutCompress.enabled  = gc.value("enabled", true);
                out.pipeline.gamutCompress.method   = gc.value("method", "neutral_axis");
                out.pipeline.gamutCompress.strength = gc.value("strength", 0.5f);
            }

            if (p.contains("grain"))
            {
                const auto& gr = p["grain"];
                out.pipeline.grain.enabled          = gr.value("enabled", true);
                out.pipeline.grain.model            = gr.value("model", "procedural_v1");
                out.pipeline.grain.size             = gr.value("size", 0.45f);
                out.pipeline.grain.colorful         = gr.value("colorful", 0.35f);
                out.pipeline.grain.shadowsBoost     = gr.value("shadows_boost", 0.2f);
                out.pipeline.grain.highlightsRolloff= gr.value("highlights_rolloff", 0.7f);
            }

            if (p.contains("halation"))
            {
                const auto& h = p["halation"];
                out.pipeline.halation.enabled   = h.value("enabled", false);
                out.pipeline.halation.threshold = h.value("threshold", 1.2f);
                out.pipeline.halation.radius    = h.value("radius", 6.0f);
                out.pipeline.halation.strength  = h.value("strength", 0.0f);
            }
        }

        LogInfo("Loaded preset: " + out.id + " (" + out.name + ")");
        return true;
    }

    bool SavePresetToFile(const std::string& path, const Preset& preset, std::string* err)
    {
        json j;
        j["schema"] = preset.schema.empty() ? PresetSchemaId() : preset.schema;
        j["schema_version"] = preset.schemaVersion;

        j["id"] = preset.id;
        j["name"] = preset.name;
        j["description"] = preset.description;
        j["author"] = preset.author;
        j["tags"] = preset.tags;

        j["defaults"] = {
            {"exposure_stops", preset.defaults.exposureStops},
            {"contrast", preset.defaults.contrast},
            {"pivot", preset.defaults.pivot},
            {"saturation", preset.defaults.saturation},
            {"warm_cool", preset.defaults.warmCool},
            {"shadow_tint", {preset.defaults.shadowTint[0], preset.defaults.shadowTint[1], preset.defaults.shadowTint[2]}},
            {"highlight_tint", {preset.defaults.highlightTint[0], preset.defaults.highlightTint[1], preset.defaults.highlightTint[2]}},
            {"film_strength", preset.defaults.filmStrength},
            {"grain_amount", preset.defaults.grainAmount},
            {"halation_amount", preset.defaults.halationAmount}
        };

        j["pipeline"]["working_space"] = {
            {"type", preset.pipeline.workingSpace.type},
            {"config", preset.pipeline.workingSpace.config},
            {"config_path", preset.pipeline.workingSpace.configPath},
            {"input", preset.pipeline.workingSpace.input},
            {"working", preset.pipeline.workingSpace.working},
            {"output", preset.pipeline.workingSpace.output}
        };

        j["pipeline"]["tone_map"] = {
            {"model", preset.pipeline.toneMap.model},
            {"shoulder_strength", preset.pipeline.toneMap.shoulderStrength},
            {"toe_strength", preset.pipeline.toneMap.toeStrength},
            {"preserve_hue", preset.pipeline.toneMap.preserveHue}
        };

        j["pipeline"]["film_matrix"] = {
            {"enabled", preset.pipeline.filmMatrix.enabled},
            {"strength", preset.pipeline.filmMatrix.strength},
            {"matrix_3x3", {
                {preset.pipeline.filmMatrix.m[0][0], preset.pipeline.filmMatrix.m[0][1], preset.pipeline.filmMatrix.m[0][2]},
                {preset.pipeline.filmMatrix.m[1][0], preset.pipeline.filmMatrix.m[1][1], preset.pipeline.filmMatrix.m[1][2]},
                {preset.pipeline.filmMatrix.m[2][0], preset.pipeline.filmMatrix.m[2][1], preset.pipeline.filmMatrix.m[2][2]}
            }}
        };

        j["pipeline"]["gamut_compress"] = {
            {"enabled", preset.pipeline.gamutCompress.enabled},
            {"method", preset.pipeline.gamutCompress.method},
            {"strength", preset.pipeline.gamutCompress.strength}
        };

        j["pipeline"]["grain"] = {
            {"enabled", preset.pipeline.grain.enabled},
            {"model", preset.pipeline.grain.model},
            {"size", preset.pipeline.grain.size},
            {"colorful", preset.pipeline.grain.colorful},
            {"shadows_boost", preset.pipeline.grain.shadowsBoost},
            {"highlights_rolloff", preset.pipeline.grain.highlightsRolloff}
        };

        j["pipeline"]["halation"] = {
            {"enabled", preset.pipeline.halation.enabled},
            {"threshold", preset.pipeline.halation.threshold},
            {"radius", preset.pipeline.halation.radius},
            {"strength", preset.pipeline.halation.strength}
        };

        std::ofstream f(path);
        if (!f)
        {
            if (err) *err = "Failed to open for write: " + path;
            return false;
        }
        f << j.dump(2) << "\n";
        return true;
    }

#else
    bool LoadPresetFromFile(const std::string& path, Preset& out, std::string* err)
    {
        (void)path; (void)out;
        if (err) *err = "nlohmann/json not found. Add third_party/nlohmann_json or install it.";
        return false;
    }

    bool SavePresetToFile(const std::string& path, const Preset& preset, std::string* err)
    {
        (void)path; (void)preset;
        if (err) *err = "nlohmann/json not found. Add third_party/nlohmann_json or install it.";
        return false;
    }
#endif
}
EOF

# Provide a copy of the JSON Schema used (optional reference; tooling can load from here)
cat > "$ROOT/presets/schema/lookpreset.schema.json" <<'EOF'
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "https://schemas.clientofaxioms/color-looks/lookpreset.schema.json",
  "title": "ColorLooks Look Preset (client of AXIOMS)",
  "type": "object",
  "additionalProperties": false,
  "required": ["schema", "schema_version", "id", "name", "defaults", "pipeline"],
  "properties": {
    "schema": { "const": "com.clientofaxioms.colorlooks.lookpreset" },
    "schema_version": { "type": "integer", "minimum": 1, "maximum": 1 },
    "id": { "type": "string", "pattern": "^[a-z0-9_\\-]{3,64}$" },
    "name": { "type": "string", "minLength": 1, "maxLength": 128 },
    "description": { "type": "string", "maxLength": 2048 },
    "author": { "type": "string", "maxLength": 128 },
    "tags": {
      "type": "array",
      "items": { "type": "string", "maxLength": 48 },
      "maxItems": 32
    },
    "defaults": { "type": "object" },
    "pipeline": { "type": "object" }
  }
}
EOF

# =========================================================
# ENGINE
# =========================================================
mkdir -p "$ROOT/engine/include/colorlooks/engine" "$ROOT/engine/src"

cat > "$ROOT/engine/CMakeLists.txt" <<'EOF'
add_library(colorlooks_engine
    src/LookEngine.cpp
    src/RenderGraph.cpp
    src/Nodes.cpp
    src/Params.cpp
    src/Cache.cpp
    src/CPUFallback.cpp
)

target_include_directories(colorlooks_engine PUBLIC
    ${CMAKE_CURRENT_SOURCE_DIR}/include
)

target_link_libraries(colorlooks_engine PUBLIC
    colorlooks_common
    colorlooks_color
    colorlooks_presets
)

target_compile_features(colorlooks_engine PUBLIC cxx_std_17)
EOF

cat > "$ROOT/engine/include/colorlooks/engine/Frame.hpp" <<'EOF'
#pragma once
#include <cstddef>
#include "colorlooks/common/Span.hpp"

namespace colorlooks
{
    enum class PixelFormat
    {
        RGBA_F32
    };

    struct FrameView
    {
        PixelFormat fmt = PixelFormat::RGBA_F32;
        int width = 0;
        int height = 0;
        int strideFloats = 0; // floats per row (RGBA = 4*width typically)

        // Interleaved RGBA float pixels: [r,g,b,a, r,g,b,a, ...]
        Span<float> data;
    };
}
EOF

cat > "$ROOT/engine/include/colorlooks/engine/Params.hpp" <<'EOF'
#pragma once
#include <cstdint>
#include "colorlooks/presets/Preset.hpp"

namespace colorlooks
{
    struct RuntimeParams
    {
        PresetDefaults defaults;
        uint32_t frameIndex = 0; // for grain temporal seed
    };
}
EOF

cat > "$ROOT/engine/include/colorlooks/engine/Nodes.hpp" <<'EOF'
#pragma once
#include <string>

namespace colorlooks
{
    enum class NodeId
    {
        InputTransform,
        Exposure,
        Contrast,
        FilmMatrix,
        Saturation,
        ToneMap,
        GamutCompress,
        Grain,
        Halation,
        OutputTransform
    };

    const char* NodeName(NodeId id);
}
EOF

cat > "$ROOT/engine/include/colorlooks/engine/RenderGraph.hpp" <<'EOF'
#pragma once
#include <vector>
#include "colorlooks/engine/Nodes.hpp"

namespace colorlooks
{
    struct RenderGraph
    {
        std::vector<NodeId> nodes;
    };

    RenderGraph BuildDefaultLookGraph();
}
EOF

cat > "$ROOT/engine/include/colorlooks/engine/Cache.hpp" <<'EOF'
#pragma once
#include <cstdint>

namespace colorlooks
{
    // MVP stub: replace with real node caching keyed by hash(preset+params+frame)
    struct Cache
    {
        void Clear() {}
        std::uint64_t lastHash = 0;
    };
}
EOF

cat > "$ROOT/engine/include/colorlooks/engine/CPUFallback.hpp" <<'EOF'
#pragma once
#include "colorlooks/engine/Frame.hpp"
#include "colorlooks/engine/Params.hpp"
#include "colorlooks/presets/Preset.hpp"

namespace colorlooks
{
    // CPU pipeline for correctness/reference. This is how you validate GPU output later.
    bool ApplyLookCPU(const Preset& preset, const RuntimeParams& rp, const FrameView& in, const FrameView& out);
}
EOF

cat > "$ROOT/engine/include/colorlooks/engine/LookEngine.hpp" <<'EOF'
#pragma once
#include "colorlooks/engine/Cache.hpp"
#include "colorlooks/engine/Frame.hpp"
#include "colorlooks/engine/Params.hpp"
#include "colorlooks/engine/RenderGraph.hpp"
#include "colorlooks/presets/Preset.hpp"

namespace colorlooks
{
    class LookEngine
    {
    public:
        LookEngine();

        void SetPreset(const Preset& preset);
        const Preset& GetPreset() const { return m_preset; }

        void SetGraph(const RenderGraph& g) { m_graph = g; }
        const RenderGraph& GetGraph() const { return m_graph; }

        // MVP: CPU only. GPU backend hooks will be added via colorlooks_gpu later.
        bool RenderCPU(const RuntimeParams& rp, const FrameView& in, const FrameView& out);

        void ClearCache() { m_cache.Clear(); }

    private:
        Preset m_preset;
        RenderGraph m_graph;
        Cache m_cache;
    };
}
EOF

cat > "$ROOT/engine/src/Nodes.cpp" <<'EOF'
#include "colorlooks/engine/Nodes.hpp"

namespace colorlooks
{
    const char* NodeName(NodeId id)
    {
        switch (id)
        {
            case NodeId::InputTransform:  return "InputTransform";
            case NodeId::Exposure:        return "Exposure";
            case NodeId::Contrast:        return "Contrast";
            case NodeId::FilmMatrix:      return "FilmMatrix";
            case NodeId::Saturation:      return "Saturation";
            case NodeId::ToneMap:         return "ToneMap";
            case NodeId::GamutCompress:   return "GamutCompress";
            case NodeId::Grain:           return "Grain";
            case NodeId::Halation:        return "Halation";
            case NodeId::OutputTransform: return "OutputTransform";
            default:                      return "Unknown";
        }
    }
}
EOF

cat > "$ROOT/engine/src/RenderGraph.cpp" <<'EOF'
#include "colorlooks/engine/RenderGraph.hpp"

namespace colorlooks
{
    RenderGraph BuildDefaultLookGraph()
    {
        RenderGraph g;
        g.nodes = {
            NodeId::InputTransform,
            NodeId::Exposure,
            NodeId::Contrast,
            NodeId::FilmMatrix,
            NodeId::Saturation,
            NodeId::ToneMap,
            NodeId::GamutCompress,
            NodeId::Grain,
            NodeId::Halation,
            NodeId::OutputTransform
        };
        return g;
    }
}
EOF

cat > "$ROOT/engine/src/Cache.cpp" <<'EOF'
#include "colorlooks/engine/Cache.hpp"
EOF

cat > "$ROOT/engine/src/Params.cpp" <<'EOF'
#include "colorlooks/engine/Params.hpp"
EOF

cat > "$ROOT/engine/src/CPUFallback.cpp" <<'EOF'
#include "colorlooks/engine/CPUFallback.hpp"
#include "colorlooks/common/Math.hpp"
#include "colorlooks/color/ToneMap.hpp"
#include "colorlooks/color/GamutCompress.hpp"
#include "colorlooks/color/Matrix3x3.hpp"

#include <cmath>
#include <algorithm>

namespace colorlooks
{
    static inline float Luma709(float r, float g, float b)
    {
        return 0.2126f*r + 0.7152f*g + 0.0722f*b;
    }

    static inline void ApplySaturation(float& r, float& g, float& b, float sat)
    {
        float l = Luma709(r,g,b);
        float cr = r - l;
        float cg = g - l;
        float cb = b - l;
        r = l + cr * sat;
        g = l + cg * sat;
        b = l + cb * sat;
    }

    static inline void ApplyFilmMatrix(float& r, float& g, float& b, const Preset& preset)
    {
        if (!preset.pipeline.filmMatrix.enabled) return;

        Matrix3x3 M;
        for (int rr=0; rr<3; ++rr)
            for (int cc=0; cc<3; ++cc)
                M.m[rr][cc] = preset.pipeline.filmMatrix.m[rr][cc];

        float t = Clamp(preset.pipeline.filmMatrix.strength, 0.0f, 1.0f) *
                  Clamp(preset.defaults.filmStrength, 0.0f, 1.0f);

        Matrix3x3 I = Matrix3x3::Identity();
        Matrix3x3 L = I.LerpTo(M, t);

        Vec3 v{r,g,b};
        Vec3 o = L.Mul(v);
        r = o.x; g = o.y; b = o.z;
    }

    static inline void ApplyContrastPivotedLog(float& r, float& g, float& b, float contrast, float pivot)
    {
        // MVP: log2-domain pivoted contrast
        auto safeLog2 = [](float x) { return std::log2(std::max(x, 1e-6f)); };
        auto safeExp2 = [](float x) { return std::exp2(x); };

        float pivotLog = safeLog2(std::max(pivot, 1e-6f));

        float lr = (safeLog2(r) - pivotLog) * contrast + pivotLog;
        float lg = (safeLog2(g) - pivotLog) * contrast + pivotLog;
        float lb = (safeLog2(b) - pivotLog) * contrast + pivotLog;

        r = safeExp2(lr);
        g = safeExp2(lg);
        b = safeExp2(lb);
    }

    // Procedural grain (very simple MVP): stable per-pixel hash noise
    static inline float HashNoise(int x, int y, uint32_t frame)
    {
        uint32_t h = 2166136261u;
        h = (h ^ (uint32_t)x) * 16777619u;
        h = (h ^ (uint32_t)y) * 16777619u;
        h = (h ^ frame) * 16777619u;
        // [0..1]
        return (h & 0x00FFFFFFu) / float(0x01000000u);
    }

    static inline void ApplyGrain(float& r, float& g, float& b, int x, int y, const Preset& preset, uint32_t frame)
    {
        if (!preset.pipeline.grain.enabled) return;

        float amt = Clamp(preset.defaults.grainAmount, 0.0f, 1.0f);
        if (amt <= 0.0f) return;

        float n = HashNoise(x,y,frame) - 0.5f;
        // weight by luma (more grain in shadows)
        float l = Clamp(Luma709(r,g,b), 0.0f, 1.0f);
        float shadowBoost = Clamp(preset.pipeline.grain.shadowsBoost, 0.0f, 1.0f);
        float w = Clamp((1.0f - l) + shadowBoost * (1.0f - l), 0.0f, 2.0f);

        float gval = n * amt * 0.08f * w;

        r = std::max(0.0f, r + gval);
        g = std::max(0.0f, g + gval);
        b = std::max(0.0f, b + gval);
    }

    bool ApplyLookCPU(const Preset& preset, const RuntimeParams& rp, const FrameView& in, const FrameView& out)
    {
        if (in.fmt != PixelFormat::RGBA_F32 || out.fmt != PixelFormat::RGBA_F32) return false;
        if (in.width != out.width || in.height != out.height) return false;
        if (in.data.size() < (size_t)in.strideFloats * in.height) return false;
        if (out.data.size() < (size_t)out.strideFloats * out.height) return false;

        ToneMapParams tm;
        tm.shoulderStrength = preset.pipeline.toneMap.shoulderStrength;
        tm.toeStrength      = preset.pipeline.toneMap.toeStrength;
        tm.preserveHue      = preset.pipeline.toneMap.preserveHue;

        GamutCompressParams gc;
        gc.strength = preset.pipeline.gamutCompress.strength;

        float exposureMul = std::exp2(preset.defaults.exposureStops + rp.defaults.exposureStops);

        float contrast   = preset.defaults.contrast   * (rp.defaults.contrast);
        float pivot      = preset.defaults.pivot; // pivot is usually not multiplied
        float saturation = preset.defaults.saturation * (rp.defaults.saturation);

        for (int y=0; y<in.height; ++y)
        {
            const float* src = in.data.data() + y * in.strideFloats;
            float* dst       = out.data.data() + y * out.strideFloats;

            for (int x=0; x<in.width; ++x)
            {
                float r = src[x*4 + 0];
                float g = src[x*4 + 1];
                float b = src[x*4 + 2];
                float a = src[x*4 + 3];

                // Exposure
                r *= exposureMul; g *= exposureMul; b *= exposureMul;

                // Contrast (log pivot)
                ApplyContrastPivotedLog(r,g,b, contrast, pivot);

                // Film matrix
                ApplyFilmMatrix(r,g,b, preset);

                // Saturation
                ApplySaturation(r,g,b, saturation);

                // Tone map
                ToneMapFilmicV1(r,g,b, tm);

                // Gamut compress
                if (preset.pipeline.gamutCompress.enabled)
                    GamutCompressNeutralAxis(r,g,b, gc);

                // Grain
                ApplyGrain(r,g,b, x,y, preset, rp.frameIndex);

                dst[x*4 + 0] = r;
                dst[x*4 + 1] = g;
                dst[x*4 + 2] = b;
                dst[x*4 + 3] = a;
            }
        }
        return true;
    }
}
EOF

cat > "$ROOT/engine/src/LookEngine.cpp" <<'EOF'
#include "colorlooks/engine/LookEngine.hpp"
#include "colorlooks/engine/CPUFallback.hpp"
#include "colorlooks/common/Logging.hpp"

namespace colorlooks
{
    LookEngine::LookEngine()
    {
        m_graph = BuildDefaultLookGraph();
    }

    void LookEngine::SetPreset(const Preset& preset)
    {
        m_preset = preset;
        ClearCache();
        LogInfo("Preset set: " + m_preset.id);
    }

    bool LookEngine::RenderCPU(const RuntimeParams& rp, const FrameView& in, const FrameView& out)
    {
        return ApplyLookCPU(m_preset, rp, in, out);
    }
}
EOF

# =========================================================
# GPU (interfaces + Metal skeleton + shaders)
# =========================================================
mkdir -p "$ROOT/gpu/include/colorlooks/gpu" \
         "$ROOT/gpu/metal/include/colorlooks/gpu/metal" \
         "$ROOT/gpu/metal/src" \
         "$ROOT/gpu/metal/shaders" \
         "$ROOT/gpu/cpu"

cat > "$ROOT/gpu/CMakeLists.txt" <<'EOF'
add_library(colorlooks_gpu INTERFACE)

target_include_directories(colorlooks_gpu INTERFACE
    ${CMAKE_CURRENT_SOURCE_DIR}/include
)

# Metal backend (macOS only)
if(APPLE)
    add_subdirectory(metal)
endif()
EOF

cat > "$ROOT/gpu/include/colorlooks/gpu/GPUBackend.hpp" <<'EOF'
#pragma once
#include <cstdint>

namespace colorlooks
{
    // Future: cross-backend interface (Metal/Vulkan/DirectX).
    class GPUBackend
    {
    public:
        virtual ~GPUBackend() = default;

        // MVP: placeholder
        virtual bool IsAvailable() const = 0;
    };
}
EOF

cat > "$ROOT/gpu/include/colorlooks/gpu/KernelIDs.hpp" <<'EOF'
#pragma once

namespace colorlooks
{
    enum class KernelId
    {
        BasicStage
    };
}
EOF

cat > "$ROOT/gpu/include/colorlooks/gpu/Dispatch.hpp" <<'EOF'
#pragma once
#include <cstdint>

namespace colorlooks
{
    struct DispatchSize
    {
        uint32_t width = 0;
        uint32_t height = 0;
    };
}
EOF

cat > "$ROOT/gpu/metal/CMakeLists.txt" <<'EOF'
add_library(colorlooks_gpu_metal
    src/MetalBackend.mm
    src/MetalPipelineCache.mm
    src/MetalUtils.mm
)

target_include_directories(colorlooks_gpu_metal PUBLIC
    ${CMAKE_CURRENT_SOURCE_DIR}/include
    ${CMAKE_CURRENT_SOURCE_DIR}/../include
)

target_link_libraries(colorlooks_gpu_metal PUBLIC
    Metal::Metal
    colorlooks_common
)

target_compile_features(colorlooks_gpu_metal PUBLIC cxx_std_17)
EOF

cat > "$ROOT/gpu/metal/include/colorlooks/gpu/metal/MetalBackend.hpp" <<'EOF'
#pragma once
#include "colorlooks/gpu/GPUBackend.hpp"

namespace colorlooks
{
    class MetalBackend final : public GPUBackend
    {
    public:
        MetalBackend();
        ~MetalBackend() override;

        bool IsAvailable() const override;

    private:
        void* m_device = nullptr; // id<MTLDevice> stored opaquely in header
    };
}
EOF

cat > "$ROOT/gpu/metal/include/colorlooks/gpu/metal/MetalPipelineCache.hpp" <<'EOF'
#pragma once
#include <string>

namespace colorlooks
{
    // MVP placeholder; real version caches MTLComputePipelineState by function name/constants.
    class MetalPipelineCache
    {
    public:
        MetalPipelineCache() = default;
        ~MetalPipelineCache() = default;

        void Clear() {}
        std::string DebugStats() const { return "MetalPipelineCache(MVP)"; }
    };
}
EOF

cat > "$ROOT/gpu/metal/src/MetalUtils.mm" <<'EOF'
#import <Foundation/Foundation.h>
EOF

cat > "$ROOT/gpu/metal/src/MetalPipelineCache.mm" <<'EOF'
#include "colorlooks/gpu/metal/MetalPipelineCache.hpp"
EOF

cat > "$ROOT/gpu/metal/src/MetalBackend.mm" <<'EOF'
#include "colorlooks/gpu/metal/MetalBackend.hpp"
#include "colorlooks/common/Logging.hpp"

#import <Metal/Metal.h>

namespace colorlooks
{
    MetalBackend::MetalBackend()
    {
        id<MTLDevice> dev = MTLCreateSystemDefaultDevice();
        m_device = (__bridge_retained void*)dev;
        if (dev) LogInfo("Metal device acquired.");
        else LogWarn("No Metal device available.");
    }

    MetalBackend::~MetalBackend()
    {
        if (m_device)
        {
            id<MTLDevice> dev = (__bridge_transfer id<MTLDevice>)m_device;
            (void)dev;
            m_device = nullptr;
        }
    }

    bool MetalBackend::IsAvailable() const
    {
        return m_device != nullptr;
    }
}
EOF

# Shaders (reused from earlier)
cat > "$ROOT/gpu/metal/shaders/Common.metal" <<'EOF'
#include <metal_stdlib>
using namespace metal;

struct ColorLooksParamsCommon
{
    uint  width;
    uint  height;

    float exposureStops;
    float contrast;
    float pivot;
    float saturation;

    float filmStrength;
    float grainAmount;
    uint  frameIndex;
};

inline float luminance(float3 rgb)
{
    return dot(rgb, float3(0.2126, 0.7152, 0.0722));
}

inline float3 safeLog2(float3 x) { return log2(max(x, float3(1e-6))); }
inline float3 safeExp2(float3 x) { return exp2(x); }
EOF

cat > "$ROOT/gpu/metal/shaders/PipelineKernels.metal" <<'EOF'
#include <metal_stdlib>
using namespace metal;

#include "Common.metal"

kernel void ColorLooks_BasicStage(
    texture2d<half, access::read>  inTex  [[texture(0)]],
    texture2d<half, access::write> outTex [[texture(1)]],
    constant ColorLooksParamsCommon& p    [[buffer(0)]],
    uint2 gid                             [[thread_position_in_grid]])
{
    if (gid.x >= p.width || gid.y >= p.height) return;

    half4 inPx = inTex.read(gid);
    float3 rgb = float3(inPx.rgb);
    float  a   = float(inPx.a);

    rgb *= exp2(p.exposureStops);

    float3 logv     = safeLog2(rgb);
    float  pivotLog = log2(max(p.pivot, 1e-6));
    logv = (logv - pivotLog) * p.contrast + pivotLog;
    rgb  = safeExp2(logv);

    float l = luminance(rgb);
    float3 chroma = rgb - l;
    rgb = l + chroma * p.saturation;

    rgb = max(rgb, float3(0.0));

    outTex.write(half4(half3(rgb), half(a)), gid);
}
EOF

# Optional placeholder shader files in the tree (empty now, but created)
touch "$ROOT/gpu/metal/shaders/ColorOps.metal" \
      "$ROOT/gpu/metal/shaders/ToneMap.metal" \
      "$ROOT/gpu/metal/shaders/Grain.metal" \
      "$ROOT/gpu/metal/shaders/GamutCompress.metal"

# =========================================================
# UI (MVP model helpers)
# =========================================================
mkdir -p "$ROOT/ui/include/colorlooks/ui" "$ROOT/ui/src"

cat > "$ROOT/ui/CMakeLists.txt" <<'EOF'
add_library(colorlooks_ui
    src/ParamModel.cpp
    src/LookSelector.cpp
)

target_include_directories(colorlooks_ui PUBLIC
    ${CMAKE_CURRENT_SOURCE_DIR}/include
)

target_link_libraries(colorlooks_ui PUBLIC
    colorlooks_common
    colorlooks_presets
)

target_compile_features(colorlooks_ui PUBLIC cxx_std_17)
EOF

cat > "$ROOT/ui/include/colorlooks/ui/ParamModel.hpp" <<'EOF'
#pragma once
#include "colorlooks/presets/Preset.hpp"

namespace colorlooks
{
    // MVP: simple param model to bind UI controls to runtime defaults
    struct ParamModel
    {
        PresetDefaults user; // user overrides (multipliers or overrides depending on control)

        static ParamModel FromPreset(const Preset& preset)
        {
            ParamModel m;
            m.user = PresetDefaults{};
            // MVP: start neutral (multipliers default to 1 where appropriate)
            m.user.exposureStops = 0.0f;
            m.user.contrast      = 1.0f;
            m.user.saturation    = 1.0f;
            return m;
        }
    };
}
EOF

cat > "$ROOT/ui/include/colorlooks/ui/LookSelector.hpp" <<'EOF'
#pragma once
#include <string>
#include <vector>

namespace colorlooks
{
    struct LookItem
    {
        std::string id;
        std::string name;
        std::string path;
    };

    class LookSelector
    {
    public:
        void Clear() { m_items.clear(); }
        void Add(const LookItem& item) { m_items.push_back(item); }
        const std::vector<LookItem>& Items() const { return m_items; }

    private:
        std::vector<LookItem> m_items;
    };
}
EOF

cat > "$ROOT/ui/src/ParamModel.cpp" <<'EOF'
#include "colorlooks/ui/ParamModel.hpp"
EOF

cat > "$ROOT/ui/src/LookSelector.cpp" <<'EOF'
#include "colorlooks/ui/LookSelector.hpp"
EOF

# =========================================================
# OFX (guarded; only builds if COLORLOOKS_BUILD_OFX=ON and you provide OFX headers)
# =========================================================
mkdir -p "$ROOT/ofx/include/colorlooks/ofx" "$ROOT/ofx/src"

cat > "$ROOT/ofx/CMakeLists.txt" <<'EOF'
add_library(colorlooks_ofx MODULE
    src/OfxMain.cpp
    src/OfxPlugin.cpp
    src/ParamsBinding.cpp
    src/HostUtils.cpp
)

target_include_directories(colorlooks_ofx PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/include
)

target_link_libraries(colorlooks_ofx PRIVATE
    colorlooks_common
    colorlooks_engine
    colorlooks_presets
)

target_compile_features(colorlooks_ofx PRIVATE cxx_std_17)

# You must provide OFX headers include path via:
#   -DOFX_INCLUDE_DIR=/path/to/ofx/include
if(NOT DEFINED OFX_INCLUDE_DIR)
    message(FATAL_ERROR "COLORLOOKS_BUILD_OFX=ON requires -DOFX_INCLUDE_DIR=/path/to/ofx/include")
endif()

target_include_directories(colorlooks_ofx PRIVATE ${OFX_INCLUDE_DIR})
EOF

cat > "$ROOT/ofx/include/colorlooks/ofx/OfxPlugin.hpp" <<'EOF'
#pragma once

namespace colorlooks
{
    // Placeholder for OFX plugin class wiring; real OFX uses global entrypoints.
    struct OfxPluginStub
    {
        int dummy = 0;
    };
}
EOF

cat > "$ROOT/ofx/include/colorlooks/ofx/ParamsBinding.hpp" <<'EOF'
#pragma once
namespace colorlooks
{
    // Placeholder: map OFX params -> RuntimeParams
    struct ParamsBindingStub {};
}
EOF

cat > "$ROOT/ofx/include/colorlooks/ofx/HostUtils.hpp" <<'EOF'
#pragma once
namespace colorlooks
{
    // Placeholder: host capability detection, pixel format queries, etc.
    struct HostUtilsStub {};
}
EOF

cat > "$ROOT/ofx/src/OfxMain.cpp" <<'EOF'
// This file intentionally minimal.
// A real OFX plugin must export OfxGetPlugin and OfxGetNumberOfPlugins.

#include "colorlooks/common/Logging.hpp"

extern "C"
{
    int OfxGetNumberOfPlugins(void)
    {
        colorlooks::LogInfo("OfxGetNumberOfPlugins called (stub).");
        return 0;
    }

    void* OfxGetPlugin(int /*n*/)
    {
        colorlooks::LogInfo("OfxGetPlugin called (stub).");
        return nullptr;
    }
}
EOF

cat > "$ROOT/ofx/src/OfxPlugin.cpp" <<'EOF'
#include "colorlooks/ofx/OfxPlugin.hpp"
EOF

cat > "$ROOT/ofx/src/ParamsBinding.cpp" <<'EOF'
#include "colorlooks/ofx/ParamsBinding.hpp"
EOF

cat > "$ROOT/ofx/src/HostUtils.cpp" <<'EOF'
#include "colorlooks/ofx/HostUtils.hpp"
EOF

echo "✅ Generated full src/ tree for color-looks-mvp-v.1"
echo "   - OFX is guarded. Enable with: -DCOLORLOOKS_BUILD_OFX=ON -DOFX_INCLUDE_DIR=..."
echo "   - Preset JSON parsing auto-enables if <nlohmann/json.hpp> is available."
