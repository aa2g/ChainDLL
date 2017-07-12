#include "stdafx.h"

extern "C" {
	extern char chaindll_begin;
	extern char chaindll_ep;
	extern char chaindll_eprel;
	extern char chaindll_path;
	extern char chaindll_name;
	extern char chaindll_entry;
	extern char chaindll_end;
}

int main(int argc, char **argv)
{
	uint8_t *buf;
	IMAGE_DOS_HEADER *mz;
	IMAGE_NT_HEADERS32 *pe;
	IMAGE_SECTION_HEADER *sh;

	if (argc != 3) {
		printf("usage: %s file.exe some.dll\ndll can be a relative path, too\n", argv[0]);
		return 1;
	}
	FILE *f = fopen(argv[1], "rb+");
	char *dll = argv[2];
	fseek(f, 0, SEEK_END);
	size_t fsize = ftell(f);
	fseek(f, 0, SEEK_SET);
	buf = (uint8_t*)malloc(fsize + 16384);
	size_t got = fread(buf, 1, fsize, f);

	mz = (IMAGE_DOS_HEADER*)buf;
	pe = (IMAGE_NT_HEADERS32*)(buf + mz->e_lfanew);
	sh = IMAGE_FIRST_SECTION(pe);
	IMAGE_SECTION_HEADER *lsh = &sh[pe->FileHeader.NumberOfSections - 1];
	if (strcmp((char*)lsh->Name, ".ezdiy")) {
		DWORD pptr = lsh->PointerToRawData;
		DWORD psz = lsh->SizeOfRawData;
		DWORD naddr = lsh->VirtualAddress + psz;
		DWORD padding = ((4096 - (naddr & 4095)) & 4095);
		lsh++;
		pe->FileHeader.NumberOfSections++;
		memset(lsh, 0, sizeof(*lsh) * 2);
		strcpy((char*)lsh->Name, ".ezdiy");
		lsh->PointerToRawData = pptr + psz + padding;
		lsh->VirtualAddress = naddr + padding;
		lsh->Characteristics = IMAGE_SCN_MEM_READ | IMAGE_SCN_MEM_EXECUTE | IMAGE_SCN_CNT_CODE;
		lsh->Misc.VirtualSize = 4096;
		lsh->SizeOfRawData = 4096;
		printf("created loader section for %s\n", argv[2]);
	}
	else {
		printf("modified existing loader section for %s\n", argv[2]);
	}
	
	uint8_t *p = buf + lsh->PointerToRawData;
#define OFF(n) ((&chaindll_##n - &chaindll_begin))
#define P(n) (p + OFF(n))

	memcpy(p, &chaindll_begin, OFF(end));
	if (pe->OptionalHeader.AddressOfEntryPoint != lsh->VirtualAddress + OFF(entry)) {
		*((DWORD*)P(ep)) = pe->OptionalHeader.AddressOfEntryPoint - lsh->VirtualAddress - OFF(eprel);
		pe->OptionalHeader.AddressOfEntryPoint = lsh->VirtualAddress + OFF(entry);
	}
	char *path = argv[2];
	char *name;
	name = strrchr(path, '\\');
	if (!name) {
		name = path;
		path = ".";
	}
	else {
		*name++ = 0;
	}
	strcpy((char*)P(path), path);
	strcpy((char*)P(name), name);
	fsize = lsh->PointerToRawData + lsh->SizeOfRawData;
	pe->OptionalHeader.SizeOfImage = lsh->VirtualAddress + lsh->Misc.VirtualSize;
	fseek(f, 0, SEEK_SET);
	fwrite(buf, 1, fsize, f);
	fclose(f);

    return 0;
}

