# Linux-порт для Lenovo Xiaoxin Pad Pro 12.7 (TB371FC)

## Подтверждённое устройство

- Windows USB/MTP: `Xiaoxin Pad Pro 12.7 (Snapdragon)`
- USB ID: `VID_17EF&PID_7E34`
- Целевая модель: `TB371FC`, Snapdragon 870 / Qualcomm SM8250
- ADB/Fastboot: Android SDK Platform-Tools 37.0.1 установлены
- После успешной проверки Android был выполнен разрешённый тест исправленного
  recovery DTBO. Он снова вернулся в fastboot до Linux USB; автоматический
  откат восстановил stock `recovery_b` и `vbmeta_b`. Сейчас планшет находится
  в штатном recovery с `ADB unauthorized` и снова требует ручного
  `Reboot system now`

Позднее проверенный no-EFI Linux 7.1.8 образ также был отвергнут до Linux USB.
Автоматический откат снова успешно восстановил оба stock-раздела; повторный
запуск этого образа запрещён. Планшет снова находится в stock recovery и ждёт
ручного `Reboot system now`.

После включения USB debugging ADB подтвердил:

- `ro.product.model`: `TB371FC`
- build: `TB371FC_CN_OPEN_USER_Q00028.1_U_ZUI_16.0.474_ST_241129`
- Android 14, kernel `4.19.157-perf+`
- active slot: `_b`
- bootloader: unlocked, `ro.boot.flash.locked=0`, Verified Boot state `orange`
- panel: 2944×1840, 30/60/120/144 Hz
- board: Qualcomm `kona`, SKU `CMIT_ID-LGSIU-2023`, board id `SOVP_Prc`
- partitions include `boot_a/b`, `dtbo_a/b`, `super`, `vm-linux_a/b`

## Найденная база

В теме 4PDA `1086877`, пост `#1644`, найдено подтверждение рабочего desktop-Linux-проекта:

- репозиторий ядра: `tb371fc-desktop/linux-android-msm-lenovo-p12`;
- отдельный репозиторий device tree: `tb371fc-desktop/devicetree`;
- готовый файл `qcom/lenovo-tb371fc.dts` извлечён из оригинального `boot.img`;
- desktop-вариант DTS содержит настройки simple framebuffer и ширины SSPP для экрана 2944×1840;
- в wiki описана сборка ядра с `vendor/tb371fc_defconfig`.

В рабочем каталоге сохранены обе базы: `tb371fc-linux/` и `tb371fc-devicetree/`. В `sm8250-mainline/` оставлена отдельная upstream-база для будущего переноса DTS и драйверов.

Автор проекта прямо отмечает ограничения старого ядра 4.19: пропуски кадров через DRM/Wayland, невозможность запуска GNOME из-за старого DRM Plane API и отсутствие корректной поддержки батареи/зарядки. Поэтому готовый старый образ полезен для эксперимента, но целевая разработка — перенос аппаратных настроек на более новое ядро.

## Следующий безопасный этап

1. Завершить офлайн-проверку исправленного диагностического recovery с
   минимальным совместимым DTBO.
2. Получить отдельное разрешение на новый тест: прошлое разрешение не
   распространяется на новый образ.
3. Временно проверить только `recovery_b` и `vbmeta_b`, с автоматическим
   восстановлением точных EDL-копий при тайм-ауте или возврате в fastboot.
4. После первой загрузки Linux собрать логи, затем по одному проверять экран,
   тач/AP500U, Wi-Fi/BT, USB-C/DP, док, звук и камеры. Установка и dual boot —
   только после повторяемых временных загрузок.

Текущий исправленный образ — диагностический BusyBox/initramfs. Полный Arch
Linux ARM rootfs уже воспроизводимо собран и проверен в QEMU, но ещё не
загружался на TB371FC и не является готовым установочным дистрибутивом.

**Важно:** разблокировка bootloader обычно стирает пользовательские данные. До неё нужен полный бэкап и подтверждение владельца.
