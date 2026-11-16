//========= Copyright Valve Corporation, All rights reserved. ============//
//
// Purpose: 
//
// $Header: $
// $NoKeywords: $
//=============================================================================//

#ifdef REVISION_LUX
#include "lux_compat.h"
#else
#include "BaseVSShader.h"
#endif

#ifndef REVISION_LUX
#include "SDK_depthwrite_ps20.inc"
#endif
#include "SDK_depthwrite_ps20b.inc"
#include "SDK_depthwrite_vs20.inc"

#if !defined( _X360 )
#include "SDK_depthwrite_ps30.inc"
#include "SDK_depthwrite_vs30.inc"
#endif

BEGIN_VS_SHADER_FLAGS( SDK_DepthWrite, "Help for Depth Write", SHADER_NOT_EDITABLE )

	BEGIN_SHADER_PARAMS
		SHADER_PARAM( ALPHATESTREFERENCE, SHADER_PARAM_TYPE_FLOAT, "", "Alpha reference value" )
		SHADER_PARAM( COLOR_DEPTH, SHADER_PARAM_TYPE_BOOL, "0", "Write depth as color")
		
		// vertexlitgeneric tree sway animation control
		SHADER_PARAM( TREESWAY, SHADER_PARAM_TYPE_INTEGER, "0", "" )
		SHADER_PARAM( TREESWAYHEIGHT, SHADER_PARAM_TYPE_FLOAT, "1000", "" )
		SHADER_PARAM( TREESWAYSTARTHEIGHT, SHADER_PARAM_TYPE_FLOAT, "0.2", "" )
		SHADER_PARAM( TREESWAYRADIUS, SHADER_PARAM_TYPE_FLOAT, "300", "" )
		SHADER_PARAM( TREESWAYSTARTRADIUS, SHADER_PARAM_TYPE_FLOAT, "0.1", "" )
		SHADER_PARAM( TREESWAYSPEED, SHADER_PARAM_TYPE_FLOAT, "1", "" )
		SHADER_PARAM( TREESWAYSPEEDHIGHWINDMULTIPLIER, SHADER_PARAM_TYPE_FLOAT, "2", "" )
		SHADER_PARAM( TREESWAYSTRENGTH, SHADER_PARAM_TYPE_FLOAT, "10", "" )
		SHADER_PARAM( TREESWAYSCRUMBLESPEED, SHADER_PARAM_TYPE_FLOAT, "0.1", "" )
		SHADER_PARAM( TREESWAYSCRUMBLESTRENGTH, SHADER_PARAM_TYPE_FLOAT, "0.1", "" )
		SHADER_PARAM( TREESWAYSCRUMBLEFREQUENCY, SHADER_PARAM_TYPE_FLOAT, "0.1", "" )
		SHADER_PARAM( TREESWAYFALLOFFEXP, SHADER_PARAM_TYPE_FLOAT, "1.5", "" )
		SHADER_PARAM( TREESWAYSCRUMBLEFALLOFFEXP, SHADER_PARAM_TYPE_FLOAT, "1.0", "" )
		SHADER_PARAM( TREESWAYSPEEDLERPSTART, SHADER_PARAM_TYPE_FLOAT, "3", "" )
		SHADER_PARAM( TREESWAYSPEEDLERPEND, SHADER_PARAM_TYPE_FLOAT, "6", "" )
		SHADER_PARAM( TREESWAYSTATIC, SHADER_PARAM_TYPE_BOOL, "0", "" )
		SHADER_PARAM( TREESWAYSTATICVALUES, SHADER_PARAM_TYPE_VEC2, "[0.5 0.5]", "" )
	END_SHADER_PARAMS

	SHADER_INIT_PARAMS()
	{
		SET_FLAGS2( MATERIAL_VAR2_SUPPORTS_HW_SKINNING );
	}

	SHADER_FALLBACK
	{
		if ( g_pHardwareConfig->GetDXSupportLevel() < 90 )
		{
			return "Wireframe";
		}
		return 0;
	}

	SHADER_INIT
	{
	}

	SHADER_DRAW
	{
		bool bAlphaClip = IS_FLAG_SET( MATERIAL_VAR_ALPHATEST );
		int nColorDepth = params[COLOR_DEPTH]->GetIntValue();
		int nTreeSwayMode = clamp( params[TREESWAY]->GetIntValue(), 0, 2 );

		SHADOW_STATE
		{
			// Set stream format (note that this shader supports compression)
			unsigned int flags = VERTEX_POSITION | VERTEX_FORMAT_COMPRESSED;
			int nTexCoordCount = 1;
			int userDataSize = 0;
			pShaderShadow->VertexShaderVertexFormat( flags, nTexCoordCount, NULL, userDataSize );

			if ( nColorDepth == 0 )
			{
				// Bias primitives when rendering into shadow map so we get slope-scaled depth bias
				// rather than having to apply a constant bias in the filtering shader later
				pShaderShadow->EnablePolyOffset( SHADER_POLYOFFSET_SHADOW_BIAS );
			}

			// Turn off writes to color buffer since we always sample shadows from the DEPTH texture later
			// This gives us double-speed fill when rendering INTO the shadow map
			pShaderShadow->EnableColorWrites( ( nColorDepth == 1 ) );
			pShaderShadow->EnableAlphaWrites( false );

			// Don't backface cull unless alpha clipping, since this can cause artifacts when the
			// geometry is clipped by the flashlight near plane
			// If a material was already marked nocull, don't cull it
			pShaderShadow->EnableCulling( IS_FLAG_SET(MATERIAL_VAR_ALPHATEST) && !IS_FLAG_SET(MATERIAL_VAR_NOCULL) );

#ifndef _X360
			if ( !g_pHardwareConfig->HasFastVertexTextures() )
#endif
			{
				DECLARE_STATIC_VERTEX_SHADER( sdk_depthwrite_vs20 );
				SET_STATIC_VERTEX_SHADER_COMBO( ONLY_PROJECT_POSITION, !bAlphaClip && IsX360() && !nColorDepth ); //360 needs to know if it *shouldn't* output texture coordinates to avoid shader patches
				SET_STATIC_VERTEX_SHADER_COMBO( COLOR_DEPTH, nColorDepth );
				SET_STATIC_VERTEX_SHADER_COMBO( TREESWAY, nTreeSwayMode );
				SET_STATIC_VERTEX_SHADER( sdk_depthwrite_vs20 );
				
				if ( bAlphaClip || g_pHardwareConfig->PlatformRequiresNonNullPixelShaders() || nColorDepth )
				{
					if( bAlphaClip )
					{
						pShaderShadow->EnableTexture( SHADER_SAMPLER0, true );
						pShaderShadow->EnableSRGBRead( SHADER_SAMPLER0, true );
					}

#ifndef REVISION_LUX
					if( g_pHardwareConfig->SupportsPixelShaders_2_b() )
#endif
					{
						DECLARE_STATIC_PIXEL_SHADER( sdk_depthwrite_ps20b );
						SET_STATIC_PIXEL_SHADER_COMBO( COLOR_DEPTH, nColorDepth );
						SET_STATIC_PIXEL_SHADER( sdk_depthwrite_ps20b );
					}
#ifndef REVISION_LUX
					else
					{
						DECLARE_STATIC_PIXEL_SHADER( sdk_depthwrite_ps20 );
						SET_STATIC_PIXEL_SHADER_COMBO( COLOR_DEPTH, nColorDepth );
						SET_STATIC_PIXEL_SHADER( sdk_depthwrite_ps20 );
					}
#endif
				}
			}
#ifndef _X360
			else
			{
				SET_FLAGS2( MATERIAL_VAR2_USES_VERTEXID );

				DECLARE_STATIC_VERTEX_SHADER( sdk_depthwrite_vs30 );
				SET_STATIC_VERTEX_SHADER_COMBO( ONLY_PROJECT_POSITION, 0 ); //360 only combo, and this is a PC path
				SET_STATIC_VERTEX_SHADER_COMBO( COLOR_DEPTH, nColorDepth );
				SET_STATIC_VERTEX_SHADER_COMBO( TREESWAY, nTreeSwayMode );
				SET_STATIC_VERTEX_SHADER( sdk_depthwrite_vs30 );

				pShaderShadow->EnableTexture( SHADER_SAMPLER0, true );
				pShaderShadow->EnableSRGBRead( SHADER_SAMPLER0, true );

				DECLARE_STATIC_PIXEL_SHADER( sdk_depthwrite_ps30 );
				SET_STATIC_PIXEL_SHADER_COMBO( COLOR_DEPTH, nColorDepth );
				SET_STATIC_PIXEL_SHADER( sdk_depthwrite_ps30 );
			}
#endif
		}
		DYNAMIC_STATE
		{

#ifndef _X360
			if ( !g_pHardwareConfig->HasFastVertexTextures() )
#endif
			{
				sdk_depthwrite_vs20_Dynamic_Index vshIndex;
				vshIndex.SetSKINNING( pShaderAPI->GetCurrentNumBones() > 0 );
				vshIndex.SetCOMPRESSED_VERTS( (int)vertexCompression );
				pShaderAPI->SetVertexShaderIndex( vshIndex.GetIndex() );

				if ( bAlphaClip )
				{
					BindTexture( SHADER_SAMPLER0, BASETEXTURE, FRAME );

					float vAlphaThreshold[4] = {0.7f, 0.7f, 0.7f, 0.7f};
					if ( ALPHATESTREFERENCE != -1 && ( params[ALPHATESTREFERENCE]->GetFloatValue() > 0.0f ) )
					{
						vAlphaThreshold[0] = vAlphaThreshold[1] = vAlphaThreshold[2] = vAlphaThreshold[3] = params[ALPHATESTREFERENCE]->GetFloatValue();
					}

					pShaderAPI->SetPixelShaderConstant( 0, vAlphaThreshold, 1 );
				}

#ifndef REVISION_LUX
				if( g_pHardwareConfig->SupportsPixelShaders_2_b() )
#endif
				{
					DECLARE_DYNAMIC_PIXEL_SHADER( sdk_depthwrite_ps20b );
					SET_DYNAMIC_PIXEL_SHADER_COMBO( ALPHACLIP, bAlphaClip );
					SET_DYNAMIC_PIXEL_SHADER( sdk_depthwrite_ps20b );
				}
#ifndef REVISION_LUX
				else
				{
					DECLARE_DYNAMIC_PIXEL_SHADER( sdk_depthwrite_ps20 );
					SET_DYNAMIC_PIXEL_SHADER_COMBO( ALPHACLIP, bAlphaClip );
					SET_DYNAMIC_PIXEL_SHADER( sdk_depthwrite_ps20 );
				}
#endif
			}
#ifndef _X360
			else // 3.0 shader case (PC only)
			{
				SetHWMorphVertexShaderState( VERTEX_SHADER_SHADER_SPECIFIC_CONST_6, VERTEX_SHADER_SHADER_SPECIFIC_CONST_7, SHADER_VERTEXTEXTURE_SAMPLER0 );

				sdk_depthwrite_vs30_Dynamic_Index vshIndex;
				vshIndex.SetSKINNING( pShaderAPI->GetCurrentNumBones() > 0 );
				vshIndex.SetMORPHING( pShaderAPI->IsHWMorphingEnabled() );
				vshIndex.SetCOMPRESSED_VERTS( (int)vertexCompression );
				pShaderAPI->SetVertexShaderIndex( vshIndex.GetIndex() );

				if ( bAlphaClip )
				{
					BindTexture( SHADER_SAMPLER0, BASETEXTURE, FRAME );

					float vAlphaThreshold[4] = {0.7f, 0.7f, 0.7f, 0.7f};
					if ( ALPHATESTREFERENCE != -1 && ( params[ALPHATESTREFERENCE]->GetFloatValue() > 0.0f ) )
					{
						vAlphaThreshold[0] = vAlphaThreshold[1] = vAlphaThreshold[2] = vAlphaThreshold[3] = params[ALPHATESTREFERENCE]->GetFloatValue();
					}

					pShaderAPI->SetPixelShaderConstant( 0, vAlphaThreshold, 1 );
				}

				DECLARE_DYNAMIC_PIXEL_SHADER( sdk_depthwrite_ps30 );
				SET_DYNAMIC_PIXEL_SHADER_COMBO( ALPHACLIP, bAlphaClip );
				SET_DYNAMIC_PIXEL_SHADER( sdk_depthwrite_ps30 );
			}
#endif

			if ( nTreeSwayMode != 0 )
			{
				float flParams[4];

				flParams[0] = pShaderAPI->CurrentTime();
				if (params[TREESWAYSTATIC]->GetIntValue() == 0)
				{
					const Vector& windDir = pShaderAPI->GetVectorRenderingParameter( VECTOR_RENDERPARM_WIND_DIRECTION );
					flParams[1] = windDir.x;
					flParams[2] = windDir.y;
				}
				else
				{
					// Use a static value instead of the env_wind value.
					params[TREESWAYSTATICVALUES]->GetVecValue( flParams + 1, 2 );
				}
				flParams[3] = 0.0f;
				pShaderAPI->SetVertexShaderConstant( VERTEX_SHADER_SHADER_SPECIFIC_CONST_2, flParams );

				flParams[0] = params[TREESWAYSCRUMBLEFALLOFFEXP]->GetFloatValue();
				flParams[1] = params[TREESWAYFALLOFFEXP]->GetFloatValue();
				flParams[2] = params[TREESWAYSCRUMBLESPEED]->GetFloatValue();
				flParams[3] = params[TREESWAYSPEEDHIGHWINDMULTIPLIER]->GetFloatValue();
				pShaderAPI->SetVertexShaderConstant( VERTEX_SHADER_SHADER_SPECIFIC_CONST_3, flParams );

				flParams[0] = params[TREESWAYHEIGHT]->GetFloatValue();
				flParams[1] = params[TREESWAYSTARTHEIGHT]->GetFloatValue();
				flParams[2] = params[TREESWAYRADIUS]->GetFloatValue();
				flParams[3] = params[TREESWAYSTARTRADIUS]->GetFloatValue();
				pShaderAPI->SetVertexShaderConstant( VERTEX_SHADER_SHADER_SPECIFIC_CONST_4, flParams );

				flParams[0] = params[TREESWAYSPEED]->GetFloatValue();
				flParams[1] = params[TREESWAYSTRENGTH]->GetFloatValue();
				flParams[2] = params[TREESWAYSCRUMBLEFREQUENCY]->GetFloatValue();
				flParams[3] = params[TREESWAYSCRUMBLESTRENGTH]->GetFloatValue();
				pShaderAPI->SetVertexShaderConstant( VERTEX_SHADER_SHADER_SPECIFIC_CONST_5, flParams );

				flParams[0] = params[TREESWAYSPEEDLERPSTART]->GetFloatValue();
				flParams[1] = params[TREESWAYSPEEDLERPEND]->GetFloatValue();
				flParams[2] = 0.0f;
				flParams[3] = 0.0f;
				pShaderAPI->SetVertexShaderConstant( VERTEX_SHADER_SHADER_SPECIFIC_CONST_9, flParams );
			}

			Vector4D vParms;

			// set up arbitrary far planes, as the real ones are too far ( 30,000 )
//			pShaderAPI->SetPSNearAndFarZ( 1 );
			vParms.x = 7.0f;		// arbitrary near
			vParms.y = 4000.0f;		// arbitrary far 
			vParms.z = 0.0f;
			vParms.w = 0.0f;
			pShaderAPI->SetPixelShaderConstant( 1, vParms.Base(), 1 );

		}	// DYNAMIC_STATE

		Draw( );
	}
END_SHADER
