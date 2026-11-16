#ifndef REVISION_LUX_COMPAT_H
#define REVISION_LUX_COMPAT_H

#include "../lux/stdshaders/BaseVSShader.h"

// Map the legacy spelling to LUX's base-parameter layout.
const ShaderMaterialVars_t BASETEXTURE = BaseTexture;
const ShaderMaterialVars_t BASETEXTURETRANSFORM = BaseTextureTransform;
const ShaderMaterialVars_t FRAME = Frame;
const ShaderMaterialVars_t FLASHLIGHTTEXTURE = FlashlightTexture;

#endif
