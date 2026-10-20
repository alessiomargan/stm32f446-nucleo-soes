# stm32f446-nucleo-soes

Firmware for the NUCLEO-F446RE board, based on an STM32F446RE and a LAN9252
EtherCAT controller. The project uses CMake as the common build system for
Visual Studio Code, STM32CubeIDE, and command-line builds.

## Project structure

```text
.
├── CMakeLists.txt                 # Main build configuration
├── CMakePresets.json              # Debug, Release, RelWithDebInfo, MinSizeRel
├── Makefile                       # Build, flash, and deploy shortcuts
├── cmake/
│   ├── gcc-arm-none-eabi.cmake     # GNU Arm toolchain
│   ├── soes.cmake                  # SOES, uc_test, and build metadata integration
│   └── stm32cubemx/CMakeLists.txt  # Board and HAL source configuration
├── Core/
│   ├── Inc/                       # Board headers
│   ├── Src/                       # Initialization and interrupt handlers
│   └── Startup/                   # STM32F446 startup assembly
├── Drivers/                       # STM32 HAL and CMSIS
├── external/
│   ├── soes/                      # EtherCAT stack submodule
│   └── uc_test/                   # Application, CAN code, and shared helpers
│       └── scripts/               # Linux CAN setup and RTR test scripts
├── .vscode/                       # VS Code build and debug configuration
├── .project / .cproject           # STM32CubeIDE project metadata
├── stm32f446-nucleo-soes.ioc    # CubeMX board configuration
├── stm32f446-nucleo-soes.launch # STM32CubeIDE debug launch
├── STM32F446RETX_FLASH.ld          # Partitioned flash linker script
├── STM32F446RETX_RAM.ld            # RAM linker script
└── build/<preset>/                # Generated firmware and build metadata
```

## Memory layout

The active `STM32F446RETX_FLASH.ld` linker script defines these regions:

| Region | Start address | Size | Purpose |
| --- | --- | --- | --- |
| `RAM` | `0x20000000` | 128 KiB | Data, heap, and stack |
| `FLASH_BLD` | `0x08000000` | 48 KiB | Bootloader |
| `FLASH_PAR` | `0x0800C000` | 16 KiB | Persistent parameters (`.params`) |
| `FLASH_CAL` | `0x08010000` | 64 KiB | Calibration (`.calib`) |
| `FLASH_APP` | `0x08020000` | 128 KiB | Application vectors and code |
| `FLASH_NXT` | `0x08040000` | 256 KiB | Reserved next-image region |

The STM32F446RE has 512 KiB of flash, covered by the flash regions above. The `.params` and `.calib`
sections are `NOLOAD`, so their contents are not included in the firmware image.
The application binary must be programmed at `0x08020000`.

## Clone the repository

The application is based on `stm32f407-clickerV2-soes`, with the NUCLEO-F446RE
hardware configuration from `bl-stm32f446`.

Clone the repository and its pinned SOES and uc_test submodules:

```sh
git clone --recurse-submodules https://github.com/alessiomargan/stm32f446-nucleo-soes.git
cd stm32f446-nucleo-soes
```

For an existing checkout without initialized submodules:

```sh
git submodule update --init --recursive
```

## Prerequisites

The common build requires:

- Git
- CMake 3.22 or newer
- Ninja
- GNU Arm Embedded toolchain (`arm-none-eabi-gcc`)

Optional programming and debugging tools include:

- An ST-LINK probe
- STM32CubeProgrammer
- OpenOCD or `stlink-tools`

Verify the basic tools with:

```sh
cmake --version
ninja --version
arm-none-eabi-gcc --version
```

## Command-line build

Configure and build the Debug preset:

```sh
cmake --preset Debug
cmake --build --preset Debug
```

Perform a clean rebuild with:

```sh
cmake --build --preset Debug --clean-first
```

Other available presets are `Release`, `RelWithDebInfo`, and `MinSizeRel`.
For example:

```sh
cmake --preset Release
cmake --build --preset Release
```

Debug artifacts are written to:

```text
build/Debug/stm32f446-nucleo-soes.elf
build/Debug/stm32f446-nucleo-soes.hex
build/Debug/stm32f446-nucleo-soes.bin
```

The application is linked to run from address `0x08020000`.

## Makefile shortcuts

The repository includes a convenience `Makefile` around the Debug CMake preset.
Running `make` configures the project and performs a clean Debug build:

```sh
make
```

The available targets are:

```sh
make configure       # Configure the Debug CMake preset
make build           # Configure and perform a clean Debug build
make bin             # Build and verify that stm32f446-nucleo-soes.bin was generated
make size            # Build and print the ELF section sizes
make flash           # Build and program the BIN at 0x08020000 with st-flash
make flash-openocd   # Build and program the ELF with OpenOCD
make deploy          # Build and copy the BIN to the local EtherCAT master
make deploy_ssh      # Build and copy the BIN to the Raspberry Pi over SSH
make clean           # Remove the complete build directory
```

`make deploy` copies the binary locally to:

```text
~/.ecat_master/firmware/st_lan9252.bin
```

Override the local directory with:

```sh
make deploy ECAT_FIRMWARE_DIR=/path/to/firmware
```

`make deploy_ssh` copies the binary to the Raspberry Pi:

```text
embedded@rpi4:/home/embedded/.ecat_master/firmware/st_lan9252.bin
```

The remote directory must be writable by `embedded`. The target creates it if
needed, copies the binary using SCP, and prints the remote file's SHA-256
checksum. SSH authentication must be configured; sudo is not required.
Override the SSH host or remote directory with:

```sh
make deploy_ssh DEPLOY_HOST=embedded@rpi4 \
    REMOTE_FIRMWARE_DIR=/home/embedded/.ecat_master/firmware
```

Both targets build the Debug binary before copying it. They do not initiate
a FoE transfer or flash the microcontroller.

## Visual Studio Code setup

1. Open the repository root in Visual Studio Code.
2. Install **STM32CubeIDE for Visual Studio Code** by STMicroelectronics. A
   dedicated VS Code profile can be used to keep the STM32 extensions isolated
   from unrelated workspaces.
3. Allow the extension and CMake integration to discover the project.
4. Select the `Debug` configure preset and the `Debug` build preset when
   prompted.
5. Run **CMake: Configure**, followed by **CMake: Build** from the Command
   Palette.

The default `Ctrl+Shift+B` task also builds the selected CMake directory. The
clean and rebuild tasks are available through **Tasks: Run Task**.

For ST-LINK debugging, first configure the project so that
`${command:cmake.launchTargetPath}` resolves to `build/Debug/stm32f446-nucleo-soes.elf`.
Then start the **Debug Microcontroller - ST-Link** launch configuration. If
required by the local installation, update `.vscode/launch.json` with the MCU,
SVD, ST-LINK server, and toolchain paths.

## STM32CubeIDE setup

STM32CubeIDE 1.13 or newer supports CMake projects. This repository already
contains the Eclipse project metadata and can be imported as follows:

1. Open STM32CubeIDE and select a workspace outside this repository.
2. Select **File > Import > General > Existing Projects into Workspace**.
3. Choose the cloned `stm32f446-nucleo-soes` directory as the root directory.
4. Do not select **Copy projects into workspace**.
5. Finish the import and select the `stm32f446-nucleo-soes` project.
6. Select **Project > Build Configurations > Set Active > Debug**.
7. Open **Project Properties > C/C++ Build > CMake Settings** and verify:
   - Source directory: the repository root (`.`)
   - Build directory: `build/Debug`
   - Generator: `Ninja`
   - CMake build type: `Debug`
   - Preset: `Debug`
   - Toolchain file: `cmake/gcc-arm-none-eabi.cmake`
8. Run **CMake > Configure** from the project context menu.
9. Select **Project > Build Project**.

To force a complete rebuild, select **Project > Clean**, run
**CMake > Configure**, and then build the project again.

The checked-in `stm32f446-nucleo-soes` debug launch configuration must load:

```text
build/Debug/stm32f446-nucleo-soes.elf
```

Verify this under **Run > Debug Configurations > STM32 C/C++ Application**
before programming the target.

## Using both IDEs

VS Code and the STM32CubeIDE Debug configuration intentionally share the same
CMake preset, toolchain file, build directory, and resulting firmware:

```text
build/Debug/stm32f446-nucleo-soes.bin
```

Do not use the legacy `Debug/stm32f446-nucleo-soes.elf` or `Debug/stm32f446-nucleo-soes.bin` files.
They were produced by the previous STM32CubeIDE managed-make configuration.

The generated firmware contains build time, host, user, Git revision, and dirty
working-tree information. Consequently, two clean builds performed at different
times are not expected to be byte-for-byte identical, even when their build
configuration is otherwise the same.

## Flashing

When using `st-flash`, program the binary at the application address:

```sh
st-flash write build/Debug/stm32f446-nucleo-soes.bin 0x08020000
```

Alternatively, program `build/Debug/stm32f446-nucleo-soes.elf` through STM32CubeIDE,
STM32CubeProgrammer, or the configured VS Code debug launch.

## Updating submodules

The parent repository records exact submodule commits. To fetch the configured
tracking branches and review new revisions:

```sh
git submodule update --remote --recursive
git status
```

After testing an update, commit the changed submodule pointers in this parent
repository. Changes made inside a submodule must first be committed and pushed
from that submodule repository.

## Troubleshooting

- If CMake cannot find the compiler, ensure the directory containing
  `arm-none-eabi-gcc` is present in `PATH` before starting the IDE.
- If sources under `external/` are missing, run
  `git submodule update --init --recursive`.
- If CMake configuration is stale, remove the applicable `build/<preset>`
  directory and configure it again.
- Use only `cmake/gcc-arm-none-eabi.cmake` for this project. Do not configure a
  second toolchain file for the same build directory.

## Board and related bootloader

This application targets the NUCLEO-F446RE with an
STM32F446RE, using SPI3 for LAN9252 EtherCAT, TIM7, USART2, and CAN1.
The corresponding bootloader is
[bl-stm32f446](../bl-stm32f446).

Board configuration is stored in `stm32f446-nucleo-soes.ioc`.
The `external/uc_test/scripts/can_rtr_test.sh` helper sends CAN RTR requests from Linux using
`can-utils`; run it with `--help` for usage.

## Nucleo hardware configuration

The 8 MHz HSE oscillator configuration, 180 MHz SYSCLK, 45 MHz APB1, and
existing peripheral settings are preserved from `bl-stm32f446`.

| Function | Pins / configuration |
| --- | --- |
| LAN9252 SPI3 | PC10 SCK, PC11 MISO, PC12 MOSI; 22.5 MHz |
| LAN9252 chip select / interrupt | PD2 / PC8 (rising edge) |
| Serial console | USART2 PA2 TX, PA3 RX; 115200 baud, 8N1 |
| Green LED | PA5 |
| Blue pushbutton | PC13 (falling edge) |
| Debug outputs | PC2 / PC3 |
| CAN1 | PA11 RX / PA12 TX, AF9; normal mode, 250000 bit/s |

CAN1 uses APB1 = 45 MHz, prescaler 12, SJW 1 TQ, BS1 12 TQ, BS2 2 TQ:
`45000000 / (12 * (1 + 12 + 2)) = 250000 bit/s`, sample point 86.7%.
PA11/PA12 are used for CAN1 and cannot also serve USB FS on this configuration.
Connect them through an external CAN transceiver to a terminated CAN bus.
Pin alternate functions are documented in the
[STM32F446 datasheet](https://www.st.com/resource/en/datasheet/stm32f446re.pdf).

The CAN application retains the reference RTR responses on IDs 0x100-0x105.
The application sets VTOR to its vector table before HAL initialization, so
interrupt routing also works when a debugger enters the application directly.
The blue-button parameter-save interrupt is enabled on EXTI15_10.

The checked-in `Core/` sources and CMake source list match the `.ioc`; review
CubeMX-generated changes before accepting them, especially the partitioned
application linker script and the separate `cmake/soes.cmake` integration.
Build validation does not establish operation on the physical board.

## Raspberry Pi CAN helpers

On a Linux host with SocketCAN, configure `can0` and request the simulated ADC
readings using the executable scripts:

```sh
./external/uc_test/scripts/setup_can0.sh
./external/uc_test/scripts/can_rtr_test.sh can0 test
```

`setup_can0.sh` requests sudo privileges, sets the bitrate to 250000 bit/s,
and brings the existing interface up. The RTR test requires `can-utils`.

The CAN helpers are maintained in `external/uc_test/scripts/` and shared across
firmware projects; see its `README.md` for load testing and monitoring commands.
The `uc_test` tracking branch is `stm32f4xx`; the parent repository pins its exact
commit. Update the scripts in that submodule rather than making local copies.
