.386
.model flat, stdcall
.code
ASSUME fs:nothing
EXTERNDEF chaindll_begin:PROC
EXTERNDEF chaindll_ep:PROC
EXTERNDEF chaindll_eprel:PROC
EXTERNDEF chaindll_entry:PROC
EXTERNDEF chaindll_path:PROC
EXTERNDEF chaindll_name:PROC
EXTERNDEF chaindll_end:PROC

chaindll_begin:
skip2:
	call	edi
	call	skip3
	db		"LoadLibraryA", 0
skip3:
	call	getapi
	call	skip4
chaindll_name:
chaindll_eprel:
	db	256 dup(0)
skip4:
	db		0b8h
chaindll_ep:
	dd		0

	add		eax, [esp]
	push	eax
	jmp		edi

;;;;;;;;;;;

getapi:
	push	ebp
	mov eax, [fs:30h]		; eax = (PPEB) __readfsdword(0x30);
	mov eax, [eax+0ch]		; eax = (PPEB_LDR_DATA)peb->Ldr
	lea ebp, [eax+14h]		; ebp = &ldr->InLoadOrderModuleList.Flink
nextdll:					; while {
	mov ebp, [ebp]			; ebp = *ebp
	mov ebx, [ebp+10h]		; ebx = ebp->DllBase
	cmp dword ptr [ebp+28h], 0
	jz nextdll

	mov eax, [ebx+3ch]		; eax = IMAGE_DOS_HEADER.e_lfanew
	mov ecx, [ebx+eax+78h]  ; edx = IMAGE_DATA_DIRECTORY[0].VirtualAddress
	jecxz nextdll

	xor edx, edx
	mov esi, [ebx+ecx+20h]  ; esi = IMAGE_EXPORT_DIRECTORY.AddressOfNames
	add esi, ebx
namescan:
	inc edx					; edx is the name index
	cmp edx,  [ebx+ecx+18h] ; if i == IMAGE_EXPORT_DIRECTORY.NumberOfNames
	ja nextdll				;  continue
	lodsd					; load name

	pushad
	lea esi, [ebx+eax]
	mov edi, [esp+28h]
	mov ecx, dword ptr [edi-4]
	repz cmpsb
	popad

	jne namescan

	; resolve
	mov esi, [ebx+ecx+24h]  ; esi = IMAGE_EXPORT_DIRECTORY.AddressOfNameOrd
	add esi, ebx
	movzx eax, word ptr [esi+edx*2-2] ; eax = IMAGE_EXPORT_DIRECTORY.AddressOfNameOrd[edx]
	push ebx
	add ebx, [ebx+ecx+1ch]  ; ebx = IMAGE_EXPORT_DIRECTORY.AddressOfFuncs
	mov edi, [ebx+eax*4]	; eax = IMAGE_EXPORT_DIRECTORY.AddressOfFuncs[eax]
	pop ebx

	; check for forwards
	mov eax, [ebx+3ch]		; eax = IMAGE_DOS_HEADER.e_lfanew
	mov edx, [ebx+eax+78h]
	cmp edi, edx
	jl good
	add edx, [ebx+eax+78h+4]
	cmp edi, edx
	jl nextdll
good:

	; good
	add		edi, ebx			; add module base
	pop		ebp
	ret		4

;;;;;;;;;;;;;;;;;;

chaindll_entry:
	cld
	call	skip1
	db		"SetDllDirectoryA", 0
skip1:
	call	getapi
	call	skip2
chaindll_path:
chaindll_end:


END
