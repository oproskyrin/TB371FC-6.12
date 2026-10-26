# Firmware preparation

The TB371FC port needs proprietary Qualcomm, Novatek and NXP payloads. They are
not redistributable in this repository. Extract them locally from Lenovo's
official `TB371_ZUI_16.0.474_Tool.7z` package and keep the generated `firmware/`
directory untracked.

Expected inputs to `scripts/package-stock-firmware.sh` are:

- the `image/` directory extracted from `NON-HLOS.bin`;
- the actual firmware directory from the vendor image (`super_6.img` in the
  16.0.474 package), containing `a650_*`, `novatek_*` and `tfa98xx_*` files;
- the `image/` directory extracted from `bluetooth.img`.

Example:

```sh
./scripts/package-stock-firmware.sh \
  ~/tb371fc-firmware-source/non-hlos/image \
  ~/tb371fc-firmware-source/vendor/firmware/firmware \
  ~/tb371fc-firmware-source/bluetooth/image \
  ./firmware
```

The script packages:

- ADSP, CDSP and SLPI metadata/segments under a TB371FC-specific path;
- Adreno 650 SQE, GMU and zap firmware;
- QCA6390 WLAN runtime, M3 and regulatory database;
- both QCA6390 Bluetooth ROM 1.0 and 2.0 patch/NVM pairs;
- the known Novatek touch and TFA9894 container files for later driver work.

## TFA9894 speaker containers

Keep both stock containers until the fitted speaker variant has been identified:

- `tfa98xx_YC.cnt`: SHA-256
  `8e7d4a1c4d9587382150cd949e202100d64e17447719a6b6efdb7611ffb952f5`;
- `tfa98xx_QS.cnt`: SHA-256
  `a3f641609cbb617ea2c3169e5a9edc6c04f89a342e99fd96dacc44f216cdfa81`.

The stock module selects YC when its speaker-ID input is low and QS when it is
high. Do not rename one variant over the other or load either container until
the tablet's ID is read. See [AUDIO_PORT.md](AUDIO_PORT.md).

## QCA6390 board data

Do not rename a random stock `bdwlan.eXX` file to `board-2.bin`. The ath11k board
database associates hardware identifiers with the correct board payload. Until
the tablet's exact ath11k board identifier is captured from a native boot log,
use the QCA6390 hw2.0 `board-2.bin` supplied by the current `linux-firmware`
package. We will narrow or generate the device-specific database after the
first diagnostic boot.

## Source package

- Lenovo package: `TB371_ZUI_16.0.474_Tool.7z`
- Android build: `TB371FC_CN_OPEN_USER_Q00028.1_U_ZUI_16.0.474_ST_241129`
- Package link recorded in the 4PDA TB371FC firmware topic and served by
  Lenovo's `zsk-cdn.lenovows.com` infrastructure.
