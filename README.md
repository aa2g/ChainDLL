# ChainDLL

This utility will patch an exe file so that it will load specified DLL file on startup
(prior to executing anything else).

It is similiar to various injectors (CreateRemoteThread/QueueAPC etc), however it burns
the LoadLibrary call into the target exe file and executes it at a well-defined point.

It does not need a debug privilege either.

If the burned in DLL path does not exist, or its DllMain fails for some reason, the original
EXE binary continues silently.

The DLL paths injected are always interpreted relative to the host EXE.
