.386
.model flat, stdcall
.code
ASSUME fs:nothing
EXTERNDEF chaindll:PROC
EXTERNDEF chaindll_end:PROC

chaindll:
	call getrel
getrel:
	pop eax
	lea eax, [eax+(chaindll_end-getrel)+8]
	push [eax-8] 			; original EP
	pushad

	add [esp+20h], eax 		; rebase EP
	push eax 				; UNICODE_STRING.Buffer
	push dword ptr [eax-4]  ; UNICODE_STRING.Length / MaxLen

	; LdrpLoadDll args
	mov eax, esp
	push 0

	push esp
	push eax
	push 0
	push 0

	mov eax, [fs:30h]		; eax = (PPEB) __readfsdword(0x30);
	mov eax, [eax+0ch]		; eax = (PPEB_LDR_DATA)peb->Ldr
	lea ebp, [eax+14h]		; ebp = &ldr->InLoadOrderModuleList.Flink
nextdll:					; while {
	mov ebp, [ebp]			; ebp = *ebp
	mov ebx, [ebp+10h]		; ebx = ebp->DllBase

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
	; check for LdrLoadDll\0
	cmp dword ptr [ebx+eax], "LrdL"
	jnz namescan
	cmp dword ptr [ebx+eax+4], "Ddao"
	jnz namescan
	cmp word ptr [ebx+eax+8], "ll"
	jnz namescan
	cmp byte ptr [ebx+eax+10], 0
	jnz namescan

	; resolve and invoke
	mov esi, [ebx+ecx+24h]  ; esi = IMAGE_EXPORT_DIRECTORY.AddressOfNameOrd
	add esi, ebx
	movzx eax, word ptr [esi+edx*2-2] ; eax = IMAGE_EXPORT_DIRECTORY.AddressOfNameOrd[edx]
	add ebx, [ebx+ecx+1ch]  ; ebx = IMAGE_EXPORT_DIRECTORY.AddressOfFuncs
	mov edi, [ebx+eax*4]	; eax = IMAGE_EXPORT_DIRECTORY.AddressOfFuncs[eax]
	add edi, [ebp+10h]		; add module base (destroyed by add ebx above)

	call edi

	add esp, 12
	popad
	ret

chaindll_end:

END
