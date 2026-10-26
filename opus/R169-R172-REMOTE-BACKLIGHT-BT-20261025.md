# R169–R172: удалённая прошивка, подсветка, Bluetooth, Wi-Fi холодный старт (2026-10-25)

## R169 — удалённое управление без кнопок
- Хелпер автозагрузки (recovery_b) при подключённом ПК (USB-гаджет сконфигурирован) ждёт 60 с;
  файл `/run/tb371fc-autoboot-hold` отменяет автозагрузку. ПК-скрипты:
  `tb371fc-reboot-to-console.ps1` (6.12 → консоль 4.19, удержание), `tb371fc-flash-release.ps1`
  (полный цикл: загрузка payload → microSD с проверкой → bootloader → recovery_b/vbmeta_b → SSH).
- Контроллер fastboot запускается в отдельном процессе: перенаправление stderr в вызывающем
  PowerShell дважды «заклинило» fastboot (R165, R170).
- Payload R169: перезапуск timesyncd после NM, Chromium `--disable-quic`, поиск Яндекс (policy).

## R170 — подсветка панели
- Два KTZ8866 по адресу 0x11 на I2C5 (gpio12/13) и I2C11 (gpio60/61). DTB a99cb124.
- Модуль `tb371fc-ktz8866` (+ внешний `backlight.ko`): берёт уровень и маску светодиодов от
  загрузчика (259, BL_EN 0x4f), пишет оба чипа. `/sys/class/backlight` работает.
- Ползунок KDE пока только программно затемняет: simpledrm-коннектор «Unknown». Визуальная
  проверка пользователем — в ожидании.

## R171 — Bluetooth (QCA6390 по UART6)
- DTB d341922a: gpio16–19 открыты, у serial@998000 удалены interconnects, алиасы serial0/serial1
  (без них «Invalid line -19»). Модули btqca/hci_uart, прошивка htbtfw20.tlv/htnv20.bin.
- У контроллера нет своего адреса («missing public-address»): задаётся стабильный адрес из
  серийного номера SoC (`btmgmt public-addr`).
- bluedevil 6.7.4 собран из исходников (пакеты Arch требуют Qt 6.12) — слой `r171-apps.img`
  (7e26fa2b), загрузчик монтирует несколько слоёв (r163-apps, r171-apps).
- Проблемы после прошивки: (1) Wi-Fi: холодный старт — PCIe-линк тренируется до включения
  чипа, BAR не назначен; запасной цикл «remove endpoint + rescan» отключал питание чипа
  (pwrctrl) — гибли и Wi-Fi, и BT; (2) загрузка прошивки BT одновременно с Wi-Fi: таймаут -110.

## R172 — исправления
- `pci=realloc` в cmdline (хелпер и boot-now): мост перераспределяет окно, BAR назначается,
  Wi-Fi поднимается при холодном старте (проверено вручную на R171r).
- Цикл remove/rescan удалён из `r163-wifi.sh`.
- `r171-bt.sh`: старт после Wi-Fi, до 3 попыток загрузки прошивки (по счётчику «QCA setup on
  UART is completed»), адрес, bluetoothd, имя «Lenovo TB371FC». Вживую: готов за 11 с,
  поиск нашёл 8 устройств.
- Хеши: initramfs 197e6687, payload c0ecbfac, recovery f1b15988 (AUDIT_RESULT=PASS), откат R171 c1fdcdf3.

## Известное
- Предупреждение `spurious spmi irq received for apid=77` (irq 130) — не фатально, не исследовано.
- Запись на microSD из 6.12 — нужна поддержка моста BayHub BH201.

## R172 на железе и R173
- R172 прошит удалённо (RELEASE_OK). Wi-Fi при холодном старте поднялся сам (`pci=realloc`).
- Bluetooth: прошивка под нагрузкой загрузки иногда падает (-110), а установка адреса вызывает
  повторную загрузку прошивки, которая тоже может упасть; вдобавок устройство может появиться
  как hci1, а адрес «из серийника» менялся каждую загрузку (soc0 нет, machine-id новый).
- R173 `r171-bt.sh`: старт после Wi-Fi + plasmashell + 15 с; весь цикл (модуль → прошивка →
  адрес → «Primary controller») повторяется до 5 раз; индекс hciN определяется; адрес из
  серийного номера microSD (стабилен). 5 прогонов подряд — успех.
- R173 рабочий стол: перед стартом KDE (ExecStartPre в r149-plasma.service) — locale ru_RU.UTF-8,
  KDE на русском, раскладки us/ru (Alt+Shift), масштаб 125 %.
- Хеши R173: initramfs 7051537e, payload e3320d8e, recovery c1be9671 (PASS), откат R172 f1b15988.
