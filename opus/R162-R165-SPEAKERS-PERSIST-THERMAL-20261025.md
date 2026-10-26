# R162–R165: звук в KDE, автозагрузка со звуком/Wi-Fi/Chromium, cpufreq и термозащита, 2026-10-25

Итог: recovery_b = **R165** (61e5638d…), автозагрузка `tb371fc-linux/autoboot-6.12-r165`.
При включении сами поднимаются: KDE, тач, клавиатура, динамики (4×TFA9894, контейнер QS,
выход PipeWire «Динамики планшета» 35 %), Wi-Fi (5 ГГц, Wi-Fi 6), часовой пояс Екатеринбург,
слой программ с Chromium, cpufreq + термозащита. Откат: R164 553fc648 → R163 b72c08f2 → R158 d3464681.

## R162: первый звук и рабочий стол

- Тихий тон 440 Гц −40 dBFS в левом канале услышан пользователем (сторона не определена).
- PipeWire: ACP даёт только pro-audio (8 каналов aux) → свой sink `tb371fc-speakers`
  (hw:0,0, S16LE 2ch 48 кГц, FL/FR) в `pipewire.conf.d/50-tb371fc-speakers.conf`, ACP-устройство
  карты выключено правилом WirePlumber.
- Wi-Fi на ядре R159 модулями из r159-modroot; Chromium 153 через pacman в RAM.
- plasma-pa был установлен; частичное обновление до 6.8.1 откатано к 6.7.4 под Plasma 6.7.4.
- Chromium + YouTube повесил систему (тогда причина не была известна).

## R163: сохранение (автозагрузка)

- Payload: R159 Image 62763187, R161 DTB, initramfs (R159 test + r163-config): загрузчик R129
  монтирует необязательный слой `tb371fc-linux/layers/r163-apps.img` (ext4 820 МБ, только чтение,
  Chromium + зависимости + pacman db, sha 9f7318d8…) между базовым образом и RAM-слоем (1,5 ГБ);
  `r163-install.sh` (часовой пояс, panic_on_oops=0, конфиги PipeWire/WirePlumber, сервисы
  `r163-audio`/`r163-wifi`).
- Слой собран так: Chromium поставлен в RAM на планшете, RAM-слой передан tar-потоком на ПК,
  образ сделан в WSL (`scripts/build-r163-apps-layer.sh`) — упаковка mkfs/cp на самом планшете
  вешала его (перегрев, см. ниже).
- Запись на SD — только из консоли 4.19 (`r163-sd-prepare-419.sh`, слой через scp за 99 с,
  `r163-sd-finish-419.sh` сверяет хеш). Прошивка как раньше (`temporary-vbmeta-recovery-test.ps1
  -Action LaunchFastboot`, Start-Transcript, без перенаправления stderr!).
- Проблема: Wi-Fi при холодном старте — линк PCIe тренируется до того, как pwrctrl включит
  QCA6390; конечная точка перечисляется неготовой («BAR 0 … can't assign; bogus alignment»),
  ath11k падает. Удалять root port нельзя — линк теряется до перезагрузки.

## R164: Wi-Fi, TSENS, попытка cpufreq

- `r163-wifi.sh`: если wlp1s0 нет — удалить только 0000:01:00.0 и `pci rescan`, до 3 попыток.
  После прошивки Wi-Fi поднялся с первой попытки (повтор не понадобился), но защита на месте.
- `QCOM_TSENS` не был собран вовсе → система не знала температуру. Внешний модуль
  `scripts/build-r164-tsens.sh` (175c0ade…), грузится первым в r163-audio.sh: 28 тепловых зон.
- DT 49c42b85: убраны `interconnects` у cpu@0..700 (cpufreq-hw откладывался «Failed to find icc paths»).
- Нагрузочный тест без троттлинга: 77 → **94 °C за 5 с** — причина зависаний под нагрузкой.
- cpufreq не взлетел: «_read_bw: Mismatch between opp-peak-kBps and paths (2 0)» → таблица OPP
  отвергнута → «Domain-N failed to read LUT».

## R165: cpufreq-hw + троттлинг

- DT a7058d8e: у cpu@… убран также `operating-points-v2` → cpufreq-hw берёт EPSS LUT.
- Политики: policy0 300–1804 МГц, policy4 710–2419 МГц, policy7 845–3187 МГц, schedutil;
  cooling devices cpufreq-cpu0/4/7.
- Полная нагрузка 8 ядер 150 с: **89–91 °C стабильно**, частоты ~1,9/2,4 ГГц, система живая
  (diagnostics/r165-thermal-load-100-20261025.log).
- Сбой при первой прошивке R165: добавленный `2>$null` превратил stderr fastboot в исключение,
  контроллер прервался после Sending, fastboot на планшете завис (таймаут USB). Помогло
  переподключение кабеля и Restart bootloader; повторная прошивка обычной командой — OK.

## Остаётся

- Проверить YouTube в Chromium под нагрузкой на R165.
- Пользовательские данные не сохраняются (запись на SD из 6.12 нестабильна).
- Звук: 32-битный формат BE (q6routing 6.12 знает только S16/S24), карта каналов 4 динамиков.
- NetworkManager для выбора сетей в KDE.
