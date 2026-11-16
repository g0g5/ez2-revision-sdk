#include "../BaseVSShader.h"

// Names exported by Revision's previous Mapbase shader DLL.
DEFINE_FALLBACK_SHADER( SDK_Core_DX90, LUX_Core )
DEFINE_FALLBACK_SHADER( SDK_DecalModulate_dx9, LUX_DecalModulate )
DEFINE_FALLBACK_SHADER( SDK_EyeRefract_dx9, LUX_EyeRefract )
DEFINE_FALLBACK_SHADER( SDK_Eyes_dx9, LUX_Eyes )
DEFINE_FALLBACK_SHADER( SDK_Screenspace_General_dx9, LUX_Screenspace_General )

// The old SDK_Eyeball was a stub that always fell back to Wireframe.
DEFINE_FALLBACK_SHADER( SDK_Eyeball, Wireframe )

// Offer the compatibility shaders under their stock names as well. Whether
// these override the stock implementation is decided by the engine loader.
DEFINE_FALLBACK_SHADER( DepthWrite, SDK_DepthWrite )
DEFINE_FALLBACK_SHADER( EyeGlint, SDK_EyeGlint )
DEFINE_FALLBACK_SHADER( EyeGlint_dx9, SDK_EyeGlint_dx9 )
DEFINE_FALLBACK_SHADER( MonitorScreen, SDK_MonitorScreen )
DEFINE_FALLBACK_SHADER( MonitorScreen_DX9, SDK_MonitorScreen_DX9 )
DEFINE_FALLBACK_SHADER( WindowImposter, SDK_WindowImposter )
DEFINE_FALLBACK_SHADER( WindowImposter_DX90, SDK_WindowImposter_DX90 )
DEFINE_FALLBACK_SHADER( WorldTwoTextureBlend, SDK_WorldTwoTextureBlend )
