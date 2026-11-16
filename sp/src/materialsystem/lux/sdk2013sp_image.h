#ifndef LUX_SDK2013SP_IMAGE_H
#define LUX_SDK2013SP_IMAGE_H

#include "winlite.h"

// Windows retail binaries from Source SDK Base 2013 Singleplayer. Check the
// specific code or data layout at the point where it is used as well.
inline unsigned char *FindSdk2013SpImage( const char *pName, DWORD timestamp, DWORD imageSize )
{
	unsigned char *pImage = reinterpret_cast<unsigned char *>( GetModuleHandleA( pName ) );
	if ( !pImage )
		return NULL;

	const IMAGE_DOS_HEADER *pDos = reinterpret_cast<const IMAGE_DOS_HEADER *>( pImage );
	const DWORD headerOffset = static_cast<DWORD>( pDos->e_lfanew );
	if ( pDos->e_magic != IMAGE_DOS_SIGNATURE || headerOffset < sizeof( IMAGE_DOS_HEADER ) ||
		headerOffset > imageSize - sizeof( IMAGE_NT_HEADERS32 ) )
		return NULL;

	const IMAGE_NT_HEADERS32 *pNt = reinterpret_cast<const IMAGE_NT_HEADERS32 *>( pImage + headerOffset );
	if ( pNt->Signature != IMAGE_NT_SIGNATURE || pNt->FileHeader.Machine != IMAGE_FILE_MACHINE_I386 ||
		pNt->OptionalHeader.Magic != IMAGE_NT_OPTIONAL_HDR32_MAGIC ||
		pNt->FileHeader.TimeDateStamp != timestamp || pNt->OptionalHeader.SizeOfImage != imageSize )
		return NULL;

	return pImage;
}

inline unsigned char *FindSdk2013SpShaderApi()
{
	return FindSdk2013SpImage( "shaderapidx9.dll", 0x5429D743, 0x1A9000 );
}

#endif
