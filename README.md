# libsm64-odin
A lightweight wrapper for libsm64 in Odin, created by lammmab.

# 🛠️ Building
* Step 1: Clone the repo with submodules:
 ```git clone --recursive https://github.com/lammmab/libsm64-odin```
* Step 2: Go through instructions to build [odin c bindgen], and place the output bindgen.exe in the main directory of libsm64-odin
* Step 3: Setup [libsm64], and get it to output the dll
* Step 4: Convert the dll to a .lib file (follow [these] instructions), and place it in the input folder
* Step 5: Run this in the root folder to output libsm64.odin:
 ```bindgen bindgen.sjson```

# ❌ Don't want to build?
Grab the released, development ready copy from the releases page!

# 👌 How to use
* MUST HAVE A ROM IN THE DIRECTORY WITH YOUR EXECUTABLE, ASWELL AS sm64.dll
* import sm64.odin in your project, must also include output/libsm64.odin.
* Check out [this example] to see how the project works

[this example]: https://github.com/lammmab/libsm64-odin/tree/main/example/example.odin
[these]: https://github.com/lammmab/libsm64-odin/blob/main/DLL.md
[libsm64]: https://github.com/libsm64/libsm64/tree/2195849aba5051acf97ae5d39d89135cd90b34b8
[odin c bindgen]: https://github.com/karl-zylinski/odin-c-bindgen/blob/46762d53bbadcddbd8c04be52d049b7833d021b5/README.md