#include "cbase.h"
#include "lux_shader_caps.h"
#include "materialsystem/imaterialsystem.h"
#include "materialsystem/imaterialsystemhardwareconfig.h"
#include "materialsystem/materialsystem_config.h"
#include "tier0/icommandline.h"
#include "../../../materialsystem/lux/sdk2013sp_image.h"

#include "tier0/memdbgon.h"

// SDK2013CE e39cceab4f and e458d3007b, adapted for the verified Win32 SP
// CHardwareConfig layout. The three private caps are consecutive int fields.
void ApplyLuxShaderCaps( IMaterialSystem *pMaterialSystem )
{
	if ( !pMaterialSystem || CommandLine()->CheckParm( "-nolux" ) || CommandLine()->CheckParm( "-textmode" ) )
		return;

	IMaterialSystemHardwareConfig *pHardware = pMaterialSystem->GetHardwareConfig(
		MATERIALSYSTEM_HARDWARECONFIG_INTERFACE_VERSION, NULL );
	if ( !pHardware || !pHardware->SupportsShaderModel_3_0() )
		return;

	const unsigned char *pImage = FindSdk2013SpShaderApi();
	const size_t hardwareObject = 0x170060;
	const size_t hardwareVtable = 0x1054F8;
	const size_t pixelCapsOffset = 0x52C;
	const unsigned char getter[] = { 0x8B, 0x81, 0x2C, 0x05, 0x00, 0x00, 0xC3 };
	if ( !pImage || reinterpret_cast<const unsigned char *>( pHardware ) != pImage + hardwareObject ||
		*reinterpret_cast<const void *const *>( pHardware ) != pImage + hardwareVtable ||
		memcmp( pImage + 0xB3100, getter, sizeof( getter ) ) != 0 )
	{
		if ( pHardware->NumPixelShaderConstants() < 224 )
			Warning( "LUX: shaderapidx9.dll has an unknown SM3 caps layout.\n" );
		return;
	}

	unsigned char *pCaps = reinterpret_cast<unsigned char *>( pHardware ) + pixelCapsOffset;
	const int caps[] = { 254, 16, 16 }; // Float, boolean and integer constants.
	MEMORY_BASIC_INFORMATION page;
	if ( !VirtualQuery( pCaps, &page, sizeof( page ) ) || page.AllocationBase != pImage ||
		page.State != MEM_COMMIT || ( page.Protect != PAGE_READWRITE && page.Protect != PAGE_WRITECOPY ) ||
		page.RegionSize < sizeof( caps ) ||
		static_cast<size_t>( pCaps - static_cast<unsigned char *>( page.BaseAddress ) ) > page.RegionSize - sizeof( caps ) )
	{
		Warning( "LUX: SM3 caps are outside the expected writable shader API data.\n" );
		return;
	}

	int current[3];
	memcpy( current, pCaps, sizeof( current ) );
	if ( current[0] >= 224 && current[1] >= 16 && current[2] >= 16 )
		return;

	MaterialSystem_Config_t config = pMaterialSystem->GetCurrentConfigForVideoCard();
	memcpy( pCaps, caps, sizeof( caps ) );
	config.m_nReserved ^= 1; // Force the material system to refresh the device state.
	pMaterialSystem->OverrideConfig( config, true );
	if ( pHardware->NumPixelShaderConstants() < 224 )
		Warning( "LUX: the video configuration did not retain the SM3 caps.\n" );
}
