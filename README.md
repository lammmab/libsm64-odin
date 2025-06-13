# libsm64-odin
A lightweight wrapper for libsm64 in Odin, created by lammmab.
# NOTE: PLEASE EXPECT SOME BUGS, IF SO YOU CAN POP IN SM64.ODIN AND FIDDLE AROUND, OTHERWISE OPEN AN ISSUE AND I'LL GET TO IT
# 🛠️ Building
* Step 1: Clone the repo with submodules:
 ```git clone --recursive https://github.com/lammmab/libsm64-odin```
* Step 2: Go through instructions to build [odin c bindgen], and place the output bindgen.exe in the main directory of libsm64-odin
* Step 3: Setup [libsm64], and get it to output the dll
* Step 4: Convert the dll to a .lib file (follow [these] instructions), and place it in the input folder
* Step 5: Run this in the root folder to output libsm64.odin: 
```bindgen bindgen.sjson```
* Step 6: Place the .dll in the directory with your odin file


# ❌ Don't want to build?
Grab the released, development ready copy from the releases page!

# 👌 How to use
* MUST HAVE A ROM IN THE DIRECTORY WITH YOUR EXECUTABLE, ASWELL AS sm64.dll
* import sm64.odin in your project, must also include output/libsm64.odin.
* VERY IMPORTANT NOTE: YOU **MUST** FREE_ALL(CONTEXT.ALLOCATOR) & FREE_ALL(CONTEXT.TEMP_ALLOCATOR) AT THE END OF EACH FRAME, OR ELSE YOU WILL MEM LEAK!
* Check out [these examples] to see how the project works

[these examples]: https://github.com/lammmab/libsm64-odin/blob/main/example
[these]: https://github.com/lammmab/libsm64-odin/blob/main/DLL.md
[libsm64]: https://github.com/libsm64/libsm64/
[odin c bindgen]: https://github.com/karl-zylinski/odin-c-bindgen/
