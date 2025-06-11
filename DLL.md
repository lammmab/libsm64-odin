# Converting DLL to .lib
* Step 1: Get Visual Studio installed with the Developer Command Prompt for Visual Studio 2022+
* Step 2: Open the Developer Command Prompt, and run: 
```gendef "path-to-libsm64.dll"```
```lib /machine:x64 /def:output-libsm64-dll.def /out:libsm64.lib```
