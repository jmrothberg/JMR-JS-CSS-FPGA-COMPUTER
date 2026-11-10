# hardware_model/

Python models written at the level of the hardware.

| File | What it models | Used by |
|---|---|---|
| `fat32.py` | The FAT32 layout of the card. | Card builder, GUI, tests. |
| `sd_spi.py` | The SD card SPI protocol. | `fat32.py`. |
| `js_vm.py` | The VM's memories and program loading. | Tests that compare against the RTL. |
