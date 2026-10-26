# Linux 6.12 kexec-hang investigation — progress summary (2026-08-28/29)

## R174–R175: запись на microSD, карта переразмечена, постоянный корень, 2026-10-25

Запись из 6.12 починена (площадки SDHC2 в 1.8 В). Карта: exFAT 20 ГиБ (консоль 4.19, загрузка)
+ ext4 99 ГиБ (корень Linux с записью). R175 загружается с раздела 2, всё сохраняется.
См. R174-R175-SD-WRITE-PARTITIONS-20261025.md.

## R169–R172: удалённая прошивка, подсветка, Bluetooth, pci=realloc, 2026-10-25

Прошивка релизов полностью с ПК без кнопок (60-секундное окно при подключённом ПК).
R170: драйвер подсветки (два KTZ8866). R171: Bluetooth QCA6390 по UART6 + bluedevil (слой).
R172: `pci=realloc` чинит холодный старт Wi-Fi, убран вредный PCIe-rescan, BT стартует после
Wi-Fi с повторами. См. R169-R172-REMOTE-BACKLIGHT-BT-20261025.md.

## R166–R168: зависания = недоступная RAM 0x1d0000000 после kexec; R167 прошит, 2026-10-25

Зависания под нагрузкой на память: 6.12 получал от 4.19 участок RAM (буферы 4.19 у 0x1d0000000),
доступ к которому вешает ядро процессора. Найден сканированием только на чтение, зарезервирован
в DT (64 МиБ): memtester 4G проходит. R167: + NetworkManager (выбор сетей в KDE), троттлинг 75 °C,
без блокировки экрана. Запись на SD не работает — нужна поддержка моста BayHub BH201.
См. R166-R168-RAM-HOLE-NM-SD-20261025.md.

## R162–R165: автозагрузка со звуком, Wi-Fi, Chromium; cpufreq и термозащита, 2026-10-25

recovery_b = R165. При включении: KDE, тач, клавиатура, динамики (выход «Динамики планшета»),
Wi-Fi, часовой пояс, Chromium из слоя на SD, cpufreq-hw + TSENS. Зависания под нагрузкой были
перегревом (94 °C за 5 с без троттлинга); теперь 89–91 °C стабильно под полной нагрузкой.
Пользовательские данные пока не сохраняются. См. R162-R165-SPEAKERS-PERSIST-THERMAL-20261025.md.

## R160b: звуковая карта и путь до TDM работают (звук, этап 2), 2026-10-25

Сбои R160 = oops в qcom_snd_sdw_startup на кодеке без ops + PANIC_ON_OOPS. Исправлено в
машинном драйвере; MM1 → PRIMARY_TDM_RX_0 проигрывает тишину без ошибок. Усилители выключены.
См. R160-SOUND-CARD-20261025.md.

## R159: ADSP запущен, аудио-сервисы APR есть (звук, этап 1), 2026-10-25

Новое ядро r159-audio (remoteproc/PAS модулями) + внешние модули clk-rpmh (часы xo для DSP)
и qcom_pd_mapper (домен avs/audio). ADSP/CDSP/SLPI running, q6core/q6afe/q6asm/q6adm на aprbus.
Только ручной kexec, recovery_b по-прежнему R158; динамики не включались. См. R159-ADSP-20261025.md.

## R158: зависания = автосон KDE; сон запрещён, 2026-10-24

Зависание ловилось через ~15 мин простоя без сообщений ядра; с замаскированными sleep-целями
система прожила 27 мин. R158 = R157 + маскирование сна при загрузке, прошит. Wi-Fi, вероятно,
был ни при чём. См. R158-NO-SLEEP-20261024.md.

## R154–R157: SD-запись в 6.12 нестабильна; стабильная автозагрузка R157, 2026-10-24

Постоянный слой не сделан: создание 16 ГБ файла на SD из 6.12 вешало систему при любой
конфигурации (опрос/non-removable/DMA/HPM-питание). Зацепка — BHT-редрайвер в vendor 4.19.
R153 с автозапуском Wi-Fi зависал сам; установлен R157 (без Wi-Fi), стабилен в тесте.
См. R154-R157-SD-WRITE-AND-STABLE-AUTOBOOT-20261024.md.

## R152–R153: Wi-Fi и клавиатура в автозагрузке, 2026-10-24

Payload R153 = ядро R140 + DT (тач, Wi-Fi, клавиатура I2C-HID 17ef:6175) + initramfs с
автостартом тача, KDE и Wi-Fi (SSH по Wi-Fi). recovery_b = R153. Пользователь подтвердил
клавиатуру и тачпад, в том числе после переподключения. См. R152-R153-WIFI-KEYBOARD-AUTOBOOT-20261024.md.

## R151: Wi-Fi работает, 2026-10-24

QCA6390 поднят через PCIe0 (pwrseq + pci-pwrctrl + ath11k), модули собраны под ядро R140,
DT по образцу RB5. Подключение к сети пользователя: 5 ГГц Wi-Fi 6, DHCP, интернет, SSH по Wi-Fi.
Всё в RAM, автозапуска пока нет. См. R151-WIFI-20261024.md.

## R150: включение → рабочий стол без ПК, 2026-10-24

recovery_b = R150 (R121 + автозагрузка с SD, payload R149b с жёстко заданными хешами,
отмена кнопкой/касанием за 7 с). Payload на SD в новой папке autoboot-6.12, хеши
проверены. Планшет сам дошёл до 6.12 + тач + KDE. Холодный старт ещё не проверен.
См. R150-AUTOBOOT-20261024.md.

## R148: тачскрин работает в KDE, 2026-10-24

Драйвер nt36523 (патч проекта 0002 для 7.1) собран модулем под ядро R140 без
правок. DT: spi@880000 + touchscreen включены, interconnects у SPI убраны, открыты
только GPIO 40-43/56/68/82. Прошивка Tianma загружается за 0,19 с. Калибровка
libinput "0 1 0 -1 0 1"; пользователь подтвердил точные касания. См. R148-TOUCH-20261024.md.

## R147: 8 CPU на рабочем столе R140, 2026-10-24

Тот же payload R140; из cmdline убраны maxcpus=1 nr_cpus=1 (nr_cpus=8 сверху не
работает). Все 8 ядер online, KDE запущен, ошибок нет. cpufreq пока отложен.
См. R147-SMP-20261024.md.

## R141–R145: первая нативная картинка на 6.12 (DPU/DSI/DSC), 2026-10-24

GPU отключён (R141) — зависание осталось, значит не Adreno. printk_delay показал
NULL dereference: 6.12 при DSC ставил num_intf=1 → один CTL на два DSI (патч 0010).
Затем DPU INTF ширина 490 vs DSI 491 → FIFO-ошибки (патч 0011, округление вверх).
R144: DSI-ошибок 0, левая половина панели показывает правильную тестовую таблицу
modetest через нативный DSI0+DSC0; правая (DSI1) — мусор; есть SMMU over-fetch.
R145 (каждому CTL свой DSC) хуже — отклонён. Лучший нативный: R144.
См. R141-R145-NATIVE-DSC-20261024.md и фото diagnostics/r144-*.jpg, r145-*.jpg.

## R140: MMCX удерживается simplefb — видимая консоль и KDE на 6.12, 2026-10-24

Причина чёрного экрана с R131 найдена: rpmhpd_sync_state() голосует 0 за
домены без потребителей; при fw_devlink=off это происходит сразу после probe,
MMCX гаснет, и вывод загрузочной картинки останавливается. R140 = точный R131 + у
framebuffer@9c000000 power-domains=MMCX, required-opps=NOM. Boot
e35b9f45-368b-4aec-aa25-42af3613c1cf: mmcx on 256, state_synced=1.
Пользователь подтвердил видимую консоль (фото) и видимый рабочий стол KDE
(QPainter на simpledrm, tty7). Без GPU, 1 CPU, без тача. См.
R140-MMCX-SIMPLEFB-20261024.md, checkpoint r140-arch612-mmcx-kde-software-20261024.

## R139 и передача Claude, 2026-10-24

R139 загрузил Arch/SSH. Panel probe stages0..5 прошли; после drm_panel_add
и primary DSI attach вторичный attach запустил DPU/MSM/Adreno. Последнее
сообщение host-stream: a650 SQE firmware0x093 слишком старая, требуется0x095.
Дальше SSH потерян, пользователь видит чёрный экран. Связь с firmware ошибкой
ещё не доказана как причинная. См. R139-PANEL-GATES-20261024.md.

После физического возврата в4.19 программный helper return-to-bootloader
успешно перевёл устройство вfastboot <serial>, пользователь подтвердил экран.
По запросу восстановлен замороженный r130 (Arch login + USB SSH, без
native display): boot3e5afc5f-6ee7-4412-a9b8-8a008c73dc7c, systemd running,
getty@tty1 active, SD/loop RO. Пользователь подтвердил «вижу логин».
Создан CLAUDE_HANDOFF.md с командами, путями, результатами,
планом и правилами Git. Изменения не committed/pushed.

## R138: питание/обе PHY/DSI прошли; потеря SSH на panel module, 2026-10-24

Bootbfea0a4c-9f14-4e4a-ba52-55a5fd25cf2e, ядроR137(намеренно тот жеImage),
liveDT3upstreamokay. Arch/SSH работали, initialfailed0. Power/clock/ICC0,
обаPHY+DSI probe0 и driver links подтверждены: vdds-517 исправлен. Backlight0,
brightness128. Фото/ответ пользователя до этапов: экран чёрный.
Перед загрузкойpanelмодуля журналы скачаны наПК. Приinsmodpanel послеSHA-check
SSH перестал отвечать; повторныеSSH/pingtimeouts, NCM/COM4 видны Windows.
Причина/точнаяграница не установлены: defaultpinctrl, reset69, attach и modeset
ещё не разделены. Панель/видимаяграфика НЕ подтверждены. Нужны фото/trace,
при отсутствиисвязи физическийrestart. Пользовательразрешил software reboot,
но сейчас команду отправить нельзя; возврат4.19 программно не проверен.
См.R138-POWER-CLOSURE-20261024.md, diagnostics/r138-before-panel-20261024.tar.gz.

## R137 boot + две KTZ подтверждены; R138 исправляет входное питание, 2026-10-24

R137 загрузился: bootf8239fae-e368-4b9d-af8a-963ae3a730ec, SSH/Arch живы,
failed units0. Power/DISPCC/ICC stages0, I2C обеprobe0, KTZ primary5-0011 и
secondary11-0011 probe0, backlight class появился. Экран чёрный, native panel
модуль НЕ запускали: обе PHY отложены на vdds. Причина — мой слишком узкий
R137 whitelist питания исключил входныеSMPS6a/SMPS8c/SMPS5a трёх LDO.
Рекурсивная проверка supply closure теперь ловит эту ошибку. Подготовлен
НЕ ЗАПУЩЕННЫЙ R138: ровно3 DT status changes, тот же Image/initrd; closure QA
и DT roundtrip проходят. Нужна начальная4.19консоль. См. R137/R138 reports.

## R137 native-gated собран, офлайн проверен, НЕ ЗАПУЩЕН, 2026-10-24

Из рабочего4.19 source/sysfs выявлена ошибка старой PHY-гипотезы: реальный PHY
v4.1, а не v4.0. Новый board profile сохраняет v4.1 TX и V56-source analog values,
clock-lane CFG0=0x20; отдельно перенесён linewidth1880 под6.12 multirect, не7.1.
Добавлен отсутствовавший REGULATOR_QCOM_RPMH=m, одиннадцать matching modules.
Подготовлен native DT: DSI/PHY armed, точные I2C994000/a8c000 и GPIO whitelist,
только3 display LDO разрешены, остальные power constraints не применяются.
После boot автоматически только SSH+RPMh clock; питание/дисплей по отдельным
командам. Это НЕ успешная физическая графика: пока только офлайн-кандидат.
На планшете всё ещё R135/R136 с SSH и чёрным экраном. Нужна начальная4.19
консоль для RAM kexec. См. R137-NATIVE-GATED-20261024.md.

## R135 boot и R136 direct-simplefb: SSH жив, экран всё ещё чёрный, 2026-10-24

R135 загрузился с тремя модулями USB+RPMh; DISPCC/ICC/MDSS не загружены,
но пользователь видит чёрный экран. Boot1d4ea8c5-929e-4186-9c05-6144302b15f7,
failed units0. Значит поздние дисплейные зависимости не обязательны для blackout.
Повторно изучен рабочий4.19 V56: проверен его прямой framebuffer-путь на6.12.
R136 exact external simplefb модуль успешно привязался вместо simpledrm,
fbcon2944x1840/stride11776 работает программно, SSH и boot ID сохранены;
физически экран снова чёрный. Одной замены simpledrm недостаточно.
Сейчас live simplefb, не DRM; GUI не запускать. Следующий участок — native
DSI/PHY/DSC и питание на основе проверенных stock/V56 данных, с GPIO gates.
См. R135-RPMH-CLOCK-20261024.md и R136-SIMPLEFB-CONTROL-20261024.md.

## R135: исправлен отсутствующий RPMh clock provider, 2026-10-24

В R134 CONFIG_QCOM_CLK_RPMH выключен: DISPCC PLL были orphan/rate0.
Собран точный внешний clk-rpmh.ko, live insmod=0, provider bound;
bi_tcxo19.2MHz, PLL0=1.38GHz, PLL1=600MHz. Boot ID/SSH сохранены, failed units0.
Пользователь подтвердил: экран остаётся чёрным. Тактирование исправлено,
но видимый вывод не восстановлен. Подготовлен НЕ ЗАПУЩЕННЫЙ r135-clock-gated:
тот же Image/DT, RPMh сначала, остальные display modules только отдельными
командами с контрольным фото. Требуется начальная4.19 консоль для теста.
См. R135-RPMH-CLOCK-20261024.md; Android/SD не записывались.

## R134: контрольный boot подтверждён, физический экран чёрный, 2026-10-24

RAM kexec и SSH подтвердили новое ядро6.12.30-tb371fc-r134-panel+, boot ID
ae48fe3d-6286-4e32-824c-18ce271c0bdf; Arch/systemd, USB/SSH, display-deps active,
failed units=0. RPMh/DISPCC/MDSS/DPU bound;7 модулей одной ABI загружены.
DSI отключены, panel/KTZ модули НЕ загружены; только simpledrm, backlight пуст.
Пользователь видит ЧЁРНЫЙ экран с подсветкой; GUI не запускали. Момент потери
изображения не установлен: нельзя объявлять MDSS причиной без сравнения.
SD/loop RO, верхний слой RAM. IRQ Err3636844 стабилен за5с, startup storm остаётся.
Журналы сохранены локально; native display ещё не работает. См. R134-PANEL612-CONTROL-20261024.md.

## R134: офлайн-подготовка перед контрольным запуском

Перенесён проверенный panel-драйвер на6.12 (API allocation и dual helpers),
закрыт пробел prepare_prev_first в общем panel bridge, backlight class включён.
Собраны Image и9 модулей одной версии; фактический C проверен по88 stock-командам
и reset, ARM systemd QA пройден. Пакет r134-control-payload.tar.gz использует
ТОЧНЫЙ R131 DT: DSI/панель и дополнительные GPIO пока отключены; драйверы
панели/KTZ есть в RAM, но не загружаются. Это контроль нового ядра, не готовый
native-display release. PHY/DPU quirks и GPIO ещё требуют отдельных тестов.
Этот этап завершён контрольным запуском выше. См. R134-PANEL612-CONTROL-20261024.md.

## R133: ICC, MDSS и DPU привязались без перезагрузки, 2026-10-24

На текущем R131 с R132 DISPCC загружены четыре точных внешних ICC-модуля.
Все 11 qnoc-провайдеров и BCM voter зарегистрированы. Повторный bind MDSS=0,
ae01000 DPU probe=0. USB/SSH и boot ID сохранены. Панель пока НЕ показывает GUI:
DSI/панель отключены в DT, backlight отсутствует, BOE-заготовка не равна
проверенным Tianma-данным. Архивные команды/reset/timing/128B DSC PPS проверены;
перенос panel-патча на6.12 требует адаптации. Остались PLL warning и ошибка DP
(его PHY отключён), PMIC, cpufreq, два power-management failed units от GUI-теста.
См. R133-ICC-MDSS-20261024.md. Новые модули пока только в RAM, не в boot image.

## Дисплейный аудит R132, 2026-10-24

На текущем R131 KDE/QPainter успешно отрисовал desktop в GEM-буфере (PNG сохранён),
но пользователь подтверждает ЧЁРНЫЙ физический экран. Видимый KDE НЕ подтверждён.
GUI остановлен, DRM вернулся к fbcon; SSH работает, boot ID прежний.
GUI вызвал failed upower/power-profiles-daemon из-за отсутствующих user namespaces;
ошибки не скрывались. Отдельно собран точный внешний dispcc-sm8250.ko:
insmod=0, af00000.clock-controller bound, USB сохранён. MDSS при ручном bind=-517.
INTERCONNECT_QCOM и BACKLIGHT_CLASS_DEVICE выключены; следующий шаг — ICC,
затем безопасная проверка native panel/backlight. Модуль не включён в initramfs.
См. R132-DISPLAY-AUDIT-20261024.md. R130/R131 frozen checkpoints не изменены.

## R131 успешно проверен 2026-10-24: RPMh заработал

Тест из первого этапа выполнен, хеши проверены. SSH подтвердил новый boot ID
418a77c4-0c50-4fe8-bc10-01de00e63295 и отсутствие power-domains у RSC в live DT.
rpmh привязался к 18200000.rsc, probe=0; появились RPMh genpd cx/mx/mmcx/gfx/ebi.
Arch/USB/SSH active, failed units=0, SD RO/RAM overlay сохранены. У ядра и
загрузочных надписей осталась версия R130 — это DTB-only эксперимент.
Дисплей msm-mdss всё ещё -110; card0 — simple framebuffer, не MSM GPU.
PMIC boot IRQ остаётся, Err=3981196 не менялся за контрольные 5с.
Сохранён checkpoint r131-arch612-rpmh-usb-20261024. См. R131-RPMH-DOMAIN-20261024.md.

## Аудит перед R131: R130 жив после >8 часов

Тот же boot ID R130, SSH доступен, failed units=0, IRQ Err за 5с не растёт.
Command DB исправно читается. Найдена отсутствующая зависимость CPU genpd у
RPMh при выключенном CONFIG_ARM_PSCI_CPUIDLE. R131 меняет только это свойство
DTB, Image/initramfs точные R130. Diff/roundtrip/hashes проверены, на планшете
ещё НЕ запускался. R130 оставлен работающим. См. R131-RPMH-DOMAIN-20261024.md.

## R130, 2026-10-24: Arch 6.12 + USB + SSH подтверждены

Фото и прямой SSH подтвердили ядро 6.12.30-tb371fc-r130-usb2-late+,
PID1 systemd, active multi-user.target и ноль failed units. USB2 high-speed,
NCM Windows 172.31.77.1 ↔ планшет 172.31.77.2:2222; ACM COM4.
Несколько SSH-сеансов по ключу и выгрузка журналов успешны; uptime >5 минут.
Сохранён путь R129 с RO SD/RAM overlay. PMIC/SPMI IRQ, RPMh/display и
зарезервированные GPIO ещё не исправлены; повторяемость запуска не проверена.
Сохранена точка D:/TB371FC-builds/checkpoints/r130-arch612-usb-ssh-20261024.
R129 не изменён. См. R130-USB2-LATE-20261024.md.

## Подтверждённый результат 2026-10-24: R129 загрузил Arch на 6.12

Фото image-24-10-26-12-46.jpeg подтверждает Arch Linux ARM tty1 login,
ядро 6.12.30-tb371fc-r118-pinctrl+, PID1=systemd, multi-user.target=active,
корень OverlayFS rw и отсутствие failed systemd units на момент проверки
(около 108 секунд uptime). Это полноценный запуск Arch userspace.
Карта/образ ext4 только для чтения, верхний writable-слой в RAM; изменения
исчезают при перезагрузке. Разрешён только GPIO75. USB/SSH и графика ещё
отключены, предупреждения PMIC/SPMI IRQ сохраняются, длительная стабильность
и повторяемость загрузки пока не проверены. Рабочая контрольная точка сохранена:
D:/TB371FC-builds/checkpoints/r129-arch612-headless-20261024.
См. R129-OVERLAY-ARCH-20261024.md. Исторические промежуточные результаты ниже.

## Актуализация 2026-10-23: r121 и восстановление microSD

См. [R121-DEPLOY-20261023.md](R121-DEPLOY-20261023.md).
ADB авторизован; карта после форматирования exFAT UUID 5772-E7F6.
Arch v2 12 GiB проверен sha256/e2fsck -fn; восстановлен на карту, хеш подтверждён на планшете.
r121 прошёл аудит упаковки: сохранён payload r120, первый panic=0 и
постоянный журнал перед kexec. Первый этап Arch/4.19 успешно загружен.
Переход r121 снова дал reset (новый boot_id), несмотря на panic=0 обоих ядер.
Журналы на карте сохранились. Выполнен контроль с exact r70 Image в RAM
при неизменных DTB/initramfs: фото image-23-10-26-06-41.jpeg подтвердило
достижение initramfs shell (~ #), сообщения до 50 секунд. MMC probe=-517,
USB явно отключён. Это успешный контроль входа в initramfs, но не запуск
полноценного Arch на 6.12. r70 не содержит PINCTRL_MSM; причина reset r118
ещё не установлена. Контроль r122 завершён: чистая пересборка с точной
конфигурацией r68/r70 достигла initramfs shell; фото image-23-10-26-11-00.jpeg.
Image SHA256 fd093c04fb21aa74d7b73df772044b22992cabac5e15c8bd8f3740d341dfb75c.
DTB/initramfs/cmdline сохранены. Раскладка сдвинулась на 64 KiB, но запускается.
Это не доказывает безопасность любой раскладки; ближайший отдельный фактор —
добавление SM8250 pinctrl. MMC всё ещё -517, USB отключён, Arch 6.12 не поднят.
Надпись R118/built-in pinctrl на экране статическая из прежнего initramfs,
не подтверждение включения pinctrl в r122.
Пока диагностический кандидат, не релиз.

Подготовлен R123 (не новая сборка): точный Image r118 с единственным
дополнительным параметром initcall_blacklist=sm8250_pinctrl_init.
Поддержка проверена по исходникам, KALLSYMS и System.map. Выполнен аппаратный
handoff до calling kexec -e; хеши Image/DTB/initramfs подтверждены. Результат
второго этапа подтверждён фото image-23-10-26-11-10 (1).jpeg: точный r118
с blacklist достиг ~ #, пропуск initcall явно показан. MMC=-517, USB отключён.
Подготовлен R124: исходный r118 без blacklist, единственное изменение DTB —
отключение узла TLMM. Аудит diff/roundtrip прошёл, аппаратный handoff выполнен
до calling kexec -e, все хеши проверены. Фото image-23-10-26-11-30 (1).jpeg
подтверждает ~ # и sm8250_pinctrl_init returned 0. TLMM отключён, MMC=-517.
Подготовлен R125: включён TLMM, отключён только GPIO75 sd-redriver-hog.
Аудит DTB прошёл; аппаратный handoff R125 выполнен до calling kexec -e,
хеши Image/DTB/initramfs подтверждены. R125 снова дал reset: пользователь
увидел начальную консоль, SSH подтвердил новый boot ID 53184df6-1877-409b-8563-2b97b0f068c1.
GPIO75 hog не является достаточным объяснением reset. R126 собрана с
контрольными точками и управляемым возвратом -EPROBE_DEFER внутри TLMM.
Аудиты прошли; аппаратный stop=4 подтверждён фото image-23-10-26-11-55.jpeg:
контрольные точки 1–4, отображение west/south/north и итоговый ~ #.
Выполнен handoff того же Image с stop=6, перед gpiochip_add_data; хеши
проверены, журнал r121-r126-stop6-control-20261024.log сохранён. Результат
Фото image-24-10-26-12-03.jpeg подтвердило checkpoint=5, checkpoint=6,
msm_gpio_init ret=-517 (намеренный stop) и ~ #. Подготовлен R127: точный
Image r118 и DTB r125 с единственным изменением gpio-reserved-ranges=<0 181>.
Это исключает опрос всех GPIO и блокирует их потребителей. Handoff R127
выполнен до calling kexec -e, хеши всех компонентов подтверждены; результат
Фото image-24-10-26-12-16.jpeg подтвердило SDXC 119 GiB, mmcblk0 и mmcblk0p1
под 6.12! Доступ нестабилен: -110, ошибка WRITE, отключение и повторное
обнаружение карты. Arch не запущен. Подготовлен R128: разрешён только GPIO75,
включён redriver-hog, автоматический RW handoff заменён чтением и RO-монтированием.
Аппаратный handoff R128 выполнен до calling kexec -e, все хеши подтверждены;
Фото image-24-10-26-12-28.jpeg подтвердило 8 совпавших чтений, RO exFAT,
RO ext4 и маркер Arch. Повторные чтения буферизованы: возможен page cache.
Подготовлен R129: O_DIRECT-проверки и запуск Arch/systemd через RAM OverlayFS,
карта и lower root только для чтения. Локальный overlay/COW тест, ARM systemd
и проверка units прошли. Аппаратный handoff R129 выполнен до calling kexec -e,
все хеши подтверждены. Фото image-24-10-26-12-46.jpeg подтвердило systemd PID1,
multi-user.target active, OverlayFS root rw и 0 failed units. Подробности выше.
См. R127-GPIO-MASK-20261024.md, R128-GPIO75-READONLY-20261024.md,
R129-OVERLAY-ARCH-20261024.md;
см. R126-TLMM-TRACE-20261023.md;
см. R123-PINCTRL-CONTROL-20261023.md.

## Актуализация 2026-10-01: r120

См. [R120-REVIEW-20261001.md](R120-REVIEW-20261001.md).
Исправлены ошибочные выводы о microSD под 6.12 и причине обрыва SSH.
Найдена точная причина отказа сборки r102: устаревшая проверка SSH runtime.
r120 собран из проверенного r118 с runtime r101, журналом handoff и
panic=0/initcall_debug. AUDIT_RESULT=PASS, ValidateOnly=PASS.
Аппаратный результат пока не установлен.

Дополнение r120: запись обоих разделов OKAY; SSH получил все handoff
маркеры до calling kexec -e. Повторный SSH подтвердил новый boot_id и
возврат в 4.19, kexec_loaded=0. PMIC: PS_HOLD. Это reset, а не просто
замерший framebuffer. Инициатор reset пока неизвестен; см. отчёт r120.

## Goal

Boot Linux 6.12 on the TB371FC via `kexec` from the proven V56.6 (Linux
4.19) baseline, to escape 4.19's graphics problems. The 6.12 kernel itself
builds and boots cleanly on a *cold* ABL boot (no V56.6 involved at all,
proven by r48) — the entire investigation below is about why the *same*
Image hangs specifically when reached via `kexec` from a live V56.6.

## How we got here

1. **r39–r46**: single-shot PSCI `SYSTEM_RESET` checkpoints walked forward
   through `head.S` → `start_kernel()` → `setup_arch()` → device-tree
   scanning. Each site fired (tablet auto-reset back to V56.6), proving the
   entire assembly boot path, kernel relocation, EL2/VHE transition, and
   this board's 6.12 device tree parsing are all clean under kexec.
2. **r47–r48**: narrowed the fault to inside `paging_init()`/`map_mem()`
   (`arch/arm64/mm/mmu.c`). **r48 cold-boot pivot**: the *identical* Image,
   booted directly by a tiny ABL-resident shim with no V56.6/kexec
   involved at all, sailed straight through the same checkpoint. This
   proved the hang is a kexec-transition artifact, not a defect in the
   6.12 port's memory layout — something about the *live handoff* from a
   running V56.6 is the problem, not the new kernel's own code.
3. **r49**: candidate fix — `flush_tlb_all()` before `map_mem()` (stale-TLB
   hypothesis). Hung. Refuted.
4. **r50**: candidate fix — reserve 19 stock PIL/firmware regions as
   `no-map` in the DTS (live-firmware-memory-conflict hypothesis). Hung.
   Refuted *at the time*, but this test was run at the wrong checkpoint
   (after the whole loop, before the fault had been localized to inside
   it) and, unknown until much later, was applied to a DTS that already
   silently carried a leftover in-place edit — see the r57 correction.
5. **r51–r54**: bisected *inside* `paging_init()`/`map_mem()` itself with
   checkpoints at progressively finer granularity — proved the fault is
   inside the `for_each_mem_range()` loop that maps each physical memory
   region, specifically on the *very first* region the loop iterates.
6. **The owner asked to stop blind bisection** ("нужно... найти другой
   подход прежде чем собирать версии в слепую") and use a smarter
   technique. **r55**: added a physical-scratch diagnostic write, intended
   to be read back via `devmem` after the hang — but V56.6's 4.19 kernel
   has `CONFIG_STRICT_DEVMEM`, which silently blocks `/dev/mem` reads of
   ordinary RAM. Dead end for readback, but the write mechanism (reusing
   the project's own pre-existing, previously-Kconfig-less
   `TB371FC_LATE_FB_MARKER` framebuffer-write infrastructure) still worked.
7. **r56**: pivoted the *readout* channel from `/dev/mem` to the
   framebuffer itself (already proven reachable post-MMU) — encoded the
   region's start address as an RGB colour. First read: **pure red →
   `0xb0000000`**, a region the project's own DTB had mislabeled
   `boot_log_region`.
8. **r57–r58**: reserved `0xb0000000` as `no-map` in the DTS and
   confirmed, with an unmistakable boolean colour indicator, that it is no
   longer hit. (Along the way, discovered the r50 DTS edit had been
   applied in place to the *shared* kernel source tree that every later
   revision copied from — a bookkeeping trap, now understood and worked
   around.)
9. **r59–r60**: the hang persisted at a *different* region. Colour and
   then an 8-bar hex-nibble graph both proved too imprecise/foreshortened
   to read reliably from an oblique phone photo of a 16-row-tall band.
10. **The owner asked to research the actual cause** rather than keep
    guessing addresses. Web research surfaced the real upstream pattern:
    kernel patches like *"remoteproc: xlnx: add shutdown callback"* — a
    kexec transition only calls `device_shutdown()` on drivers that
    actually implement a `.shutdown` hook; remote-processor/firmware
    owners that don't will stay live across the jump. This directly
    parallels a comment already in this project's own code: *"Lenovo's
    downstream watchdog_v2 driver has no shutdown callback."*
11. **Live investigation on the booted V56.6 rescue shell** (no new build
    needed) confirmed it directly: `/sys/bus/msm_subsys/devices/` showed
    every PIL subsystem (`adsp`/`cdsp`/`venus`/`spss`/`cvpss`/`slpi`/
    `a650_zap`/`npu`/`ipa_fws`/`ipa_uc`) as `OFFLINING` — **except
    `subsys9` (`name=wlan`), which was `ONLINE`**. Its platform device,
    `b0000000.qcom,cnss-qca6390`, sits at physical `0xb0000000` — the
    *exact* address r56 had decoded. **`boot_log_region` was never a boot
    log; it's QCA6390 WLAN's own reserved memory**, still live because
    `cnss2` never gets a clean shutdown before `kexec -e`.
12. Confirmed live: `echo -n 'b0000000.qcom,cnss-qca6390' >
    /sys/bus/platform/drivers/cnss2/unbind` cleanly tears WLAN down
    (regulators dropped, `subsys9` disappears) with **no effect on the
    USB-ACM control channel**.
13. **r61**: added the WLAN unbind to `execute-linux-6.12-r38` (the shared
    pre-kexec script, right before the existing watchdog-disable step) —
    the project's first genuine *root-cause fix* attempt, not just a
    diagnostic. **Hung anyway, with the same signature as r60.** WLAN was
    a real, confirmed, correctly-fixed problem — but not the *only* one.
14. **r62**: replaced the unreadable bar graph with a "spotlight" —
    20 equal segments (18 known PIL candidates + `boot_log_region`/WLAN +
    one "unknown" catch-all), only the matching segment lit solid white.
    Unambiguous to read: a single white block in a single position.
    **Result: the white block landed in the last ("unknown") segment.**
    The current hang is on a region outside the entire stock PIL/firmware
    candidate list this investigation has been working from.

## Where this leaves us

- The WLAN/`cnss2` fix is real and confirmed working; it stays in
  `execute-linux-6.12-r38` going forward.
- Two independent, well-evidenced live-firmware-memory-conflict cases have
  now been found and fixed (`boot_log_region`/WLAN via DTS `no-map`, WLAN
  subsystem via driver unbind) without fully clearing the hang. This
  pattern — fix one, the next appears — suggests the underlying mechanism
  is general (something about how `map_mem()` handles *any* physical
  region a live peripheral/firmware still owns during a kexec transition)
  rather than a single specific address to chase down one at a time.
- The current unknown region is *not* one of: `xbl_aop`, `cmd_db`,
  `xbl_uefi_log`, `smem`, `removed_region`, `pil_camera`, `pil_wlan_fw`,
  `pil_ipa_fw`, `pil_ipa_gsi`, `pil_gpu`, `pil_npu`, `pil_video`,
  `pil_cvp`, `pil_cdsp`, `pil_slpi`, `pil_adsp`, `pil_spss`,
  `cdsp_secure_heap`, or `boot_log_region`/WLAN (`0xb0000000`) — every
  address on the stock-DTB candidate list this session built from has now
  been ruled out.

## Предыдущий список кандидатов (частично закрыт 2026-08-29)

Этот список сохранён как история рассуждений. Пункты 1–3 уже закрыты live-
диагностикой ниже; пункт 4 привёл к текущей гипотезе повреждения ранних
page-table страниц продолжающимся DMA.

1. **Identify the actual unknown address precisely.** r60's 8-bar
   hex-nibble graph is the right level of detail (unlike the 20-way
   spotlight, which only says "not one of the known ones") but the first
   attempt was unreadable from an oblique photo. Retry it with a
   perpendicular, well-lit, close-up photo (the same framing that made
   r56's colour and r62's spotlight readable) rather than changing the
   encoding again.
2. **Enumerate `/proc/iomem` on the booted V56.6 shell** to get the
   *complete*, authoritative physical memory map (not just the 18 stock
   PIL regions this session's candidate list was built from) and
   cross-reference candidate addresses directly, without needing a
   hardware photo cycle at all.
3. **Check for `/proc/kcore` on V56.6** as a possible way around the
   `STRICT_DEVMEM` block on `/dev/mem` — the kernel's own linear map is
   normally exposed through `kcore` independent of that restriction, which
   could let the r55-style physical-scratch diagnostic (index + start/end
   address, already implemented and still present in the kernel tree) be
   read back as an exact number instead of decoded from a photo.
4. **Consider whether the general fix is structural rather than
   per-region**: e.g. auditing whether *all* `msm_subsys` entries are
   truly fully torn down (not just WLAN) before kexec, since PIL
   subsystems reporting `OFFLINING` rather than `OFFLINE` may not be fully
   quiesced either, or whether there's a broader "release/quiesce every
   live peripheral" step (mirroring `device_shutdown()`'s intent) that
   would be more robust than chasing individual regions one at a time.

## Продолжение 2026-08-29: r63 и переход к page-table гипотезе

15. **r63** подготовлен и полностью offline-аудирован. Он повторно использует
    Image r60 с восьмиполосным адресным индикатором, DTB r57 и обязательный
    `cnss2` unbind. Live `/proc/iomem` устранил неоднозначность фотографии:
    первый диапазон — точно `0x80600000-0x806fffff : System RAM`. Recovery
    SHA-256: `f2034d513dceba80ff1d0405db0ce8177d483e139d29423c3ff180413d3d6f09`;
    `scripts/audit-r63-transport-r2.sh` завершился `AUDIT_RESULT=PASS`.
16. Планшет подключён по USB ACM `COM9` через serial-SSH. Подтверждены runtime
    `4.19.157-perf-v56.6+`, `kexec_loaded=0`, отсутствие `/proc/kcore`, почти
    7.4 GiB доступной памяти и `non-coherent table walk` у Apps/GPU SMMU.
17. `/proc/kpageflags` показал `0x80` (`KPF_SLAB`) на всех 256 страницах
    первого диапазона `0x80600000-0x806fffff`; mapcount каждой страницы равен
    нулю. Это меняет направление: сам `__map_memblock()` не читает содержимое
    отображаемой RAM, но внутри него `early_pgtable_alloc()` создаёт новые
    таблицы поверх памяти, где непосредственно до kexec жили slab/DMA-объекты
    4.19. При уже доказанном неполном device shutdown вероятно повреждение
    page-table страниц продолжающимся DMA.
18. Собран и offline-аудирован **r64**: ранние постоянные page tables берутся из отдельного
    1 MiB пула внутри BSS/Image входящего 6.12; после успешного
    `paging_init()` включён PSCI reset checkpoint. Это один изолированный
    тест структурной гипотезы, а не очередное исключение адреса. Полное
    описание и правила интерпретации: [LINUX612_KEXEC.md](LINUX612_KEXEC.md).
    Recovery имеет размер 104857600 байт, SHA-256
    `45d69af926a67582f5f5447c5b063cfeabf07660261efef04003763c5acbe224`;
    `scripts/audit-r64-transport-r2.sh` завершился `AUDIT_RESULT=PASS`.

План аппаратного теста r64 (выполнен): временный recovery_b/vbmeta_b цикл с
проверенным откатом. Автоматический PSCI reset должен был означать прохождение
`paging_init()`; фактический результат зафиксирован ниже.

## Аппаратный результат r64 — 2026-08-29

19. Guarded launch записал только `recovery_b` и `vbmeta_b`; fastboot
    подтвердил `<serial>`, product `spinel`, slot B, unlocked bootloader и
    ожидаемые размеры разделов. V56.6 first stage проверил payload и успешно
    выполнил `kexec -l`; перед execute было `kexec_loaded=1`.
20. После `kexec -e` SSH оборвался, а планшет самостоятельно вернулся в V56.6.
    Uptime изменился примерно с 1287 секунд на 126.92 секунды,
    `kexec_loaded` снова стал `0`, state — `not-loaded`. Это доказывает, что
    r64 дошёл до PSCI checkpoint **после `paging_init()`**. Прежний hang в
    первом `__map_memblock()` устранён dedicated page-table pool.
21. После сбора результата контроллер восстановил allowlisted V56.5 r2
    recovery и test vbmeta. Проверены runtime `4.19.157-perf-v56.5+`, uptime
    54.57 секунды и `kexec_loaded=0`.

Следующее действие: r65 сохраняет 1 MiB pool без изменений и переносит
checkpoint после `setup_arch()`. Это проверяет остаток `setup_arch` с
автоматическим возвратом и без нового слепого поиска адресов.

## Аппаратный результат r65 — 2026-08-29

22. r65 собран и полностью offline-аудирован (`AUDIT_RESULT=PASS`, recovery
    SHA-256 `070b7bc94eaf7a5b0acd73dc787fb722eb9af8c715506f7ff89f3ff3275d3aae`).
    Guarded controller записал только `recovery_b` и `vbmeta_b`; first stage
    проверил payload, `kexec_loaded=1`, CPU `0-7` online.
23. Execute дошёл до Linux 6.12, но PSCI checkpoint после `setup_arch()` не
    сработал. Последняя полоса — точный marker stage 26 (`0xff40ff40`) сразу
    после `cpu_uninstall_idmap()`. Stage 27 после `xen_early_init()` и
    `efi_init()` не появился.
24. Этот запуск остановился раньше успешной границы r64 и указывает на
    недетерминированный либо чувствительный к layout сбой. Следующий
    изолированный тест должен оставить r64 pool и поставить единственный
    checkpoint сразу после `xen_early_init()`.

## Подготовка и прошивка r66 — 2026-08-29

25. r66 сохраняет r64 page-table pool и весь r65 transport без изменений;
    единственный PSCI checkpoint установлен сразу после `xen_early_init()` и
    перед `efi_init()`. Recovery SHA-256
    `7f30fe67edbf633945dccf78df02f680b6a5925d11951fb1f677dd1d5852acb2`,
    полный offline-аудит завершён `AUDIT_RESULT=PASS`.
26. Guarded controller подтвердил fastboot serial `<serial>`, `spinel`, slot
    B и unlocked, затем успешно записал только `recovery_b` и `vbmeta_b`.
    Первый V56.6 loader загрузился; serial-SSH подтвердил точные хеши r66
    payload/DTB/initramfs, CPU `0-7` online и `kexec_loaded=0`.
27. После закрытия проверочного SSH BusyBox/USB-ACM gate оставил COM9 OUT
    заблокированным (`SerialTimeoutException: Write timeout`). Это известная
    ошибка транспорта, а не результат ядра: `kexec -l` и `kexec -e` ещё не
    выполнялись. Нужен физический возврат в bootloader и повторный запуск уже
    прошитого r66 recovery; откат пользовательской системы на V56.5 не делать.
28. После физического fastboot уже прошитый r66 recovery запущен повторно без
    записи разделов. В одном чистом SSH-сеансе payload загружен и проверен:
    `kexec_loaded=1`, CPU `0-7` online. Explicit execute дал немедленный
    `Connection reset`; USB исчез и COM9 автоматически появился снова.
29. После автоматического возврата подтверждены `up 0 min`, `not-loaded` и
    `kexec_loaded=0`. **Checkpoint r66 сработал:** `xen_early_init()` в 6.12
    доказанно возвращается. Следующий изолированный r67 переносит единственную
    точку сразу после `efi_init()`.

## Аппаратный результат r67 — 2026-08-29

30. r67 сохранил r64 page-table pool, r57 DTB, проверенный Arch initramfs и
    весь V56.6 handoff; единственное изменение ядра — checkpoint сразу после
    `efi_init()`. Recovery SHA-256
    `4214533e6977208ad6d5745c5bdcc6c693fd598574e40459d749e9be4b928e42`;
    offline-аудит завершён `AUDIT_RESULT=PASS`.
31. Guarded controller записал только `recovery_b` и `vbmeta_b`. В одном
    serial-SSH-сеансе r67 payload проверен и загружен: Image SHA-256
    `42b59fe6e69d733187bb1f25901ed80d689799f31caa915a5f8b2815ebc5a06a`,
    `kexec_loaded=1`, CPU `0-7` online.
32. Explicit execute дал `Connection reset`; USB ACM исчез и автоматически
    появился снова как COM9. Новый сеанс подтвердил `up 0 min`,
    `not-loaded`, `kexec_loaded=0`, CPU `0-7` online. **Checkpoint r67
    сработал:** `efi_init()` в Linux 6.12 доказанно возвращается.
33. Следующий изолированный r68 сохраняет все компоненты r67 и переносит
    единственную точку сразу после `arm64_memblock_init()`, до
    `paging_init()`. Откат пользовательской системы на V56.5/KDE 4.19 не
    выполнять.

## Аппаратный результат r68 — 2026-08-29 (продолжено Claude после паузы Codex)

34. Codex прошил r68 (только `recovery_b`+`vbmeta_b`) и загрузил payload
    (`kexec_loaded=1`, Image SHA-256
    `09c1b144772bcc37644bf62774549bf4bd8eb01b22a6aba265d641227845a8ec`), затем
    временно приостановил работу по просьбе владельца, чтобы избежать
    одновременного доступа двух агентов к одному serial-порту/устройству.
    Claude продолжил уже загруженный тест тем же протоколом.
35. `execute-linux-6.12-r38` дал немедленный `Connection reset by peer`;
    следующая проверка подтвердила `up 0 min`, `not-loaded`,
    `kexec_loaded=0`. **Checkpoint r68 сработал:** выполнение чисто проходит
    через `arm64_memblock_init()`. Вместе с r64 (чекпоинт сразу после
    `paging_init()` уже подтверждён рабочим с dedicated page-table pool) это
    закрывает промежуток непосредственно перед и сразу после `paging_init()` —
    сама `paging_init()`/`map_mem()`, источник исходного зависания, теперь
    проходит чисто по обе стороны.
36. Следующий шаг (не начат): убрать диагностический PSCI-чекпоинт вовсе и
    проверить, доходит ли Linux 6.12 до итогового состояния (полный запуск
    /Arch окружения) при живом kexec с dedicated page-table pool + WLAN
    unbind, либо продолжить сужать оставшиеся более поздние этапы
    (`bootmem_init()`, `kasan_init()` и далее), если полный запуск ещё не
    удаётся. Ожидает решения владельца.

## r69 — полный тест загрузки без чекпоинта: возможный признак недетерминизма

37. Владелец выбрал вариант 1: убрать диагностический чекпоинт полностью и
    проверить полную загрузку. Собран **r69** на основе дерева r68 (тот же
    dedicated page-table pool, WLAN unbind, r57 DTB) — единственное
    изменение: удалён PSCI-чекпоинт после `arm64_memblock_init()`, поздние
    framebuffer-маркеры (stage 21-27) оставлены как есть. Recovery SHA-256
    `15f65c8b338876abad5d34f995c0cbc0a152f050c85d44a8a48724f1b2491e3c`,
    offline-аудит `AUDIT_RESULT=PASS`.
38. Прошито (`recovery_b`+`vbmeta_b`), payload проверен и загружен
    (`kexec_loaded=1`). `execute` не дал быстрого разрыва — тишина на serial-
    гейте (типичный паттерн зависания, но ожидаемый и при успешной полной
    загрузке, так как initramfs-гейт перестаёт отвечать в обоих случаях).
39. Повторное подключение подтвердило genuine hang (нет ответа на gate,
    после устранения зависшего orphaned-процесса Windows). Фото экрана:
    розовая полоса сверху, консоль V56.6, **узкая синяя полоса с шумом**,
    зелёная полоса снизу. По цветовой кодировке поздних framebuffer-маркеров
    (`0xff0080ff` = азур/синий = stage 27, сразу после `xen_early_init()`/
    `efi_init()`) это означает остановку **раньше** уже подтверждённой
    r68-границы (`arm64_memblock_init()` дошёл и вернулся в r68 на том же
    коде).
40. **Возможное объяснение: недетерминизм.** Такой же паттерн (остановка
    раньше подтверждённой ранее границы на идентичном коде) уже наблюдался
    у r65 относительно r64. Это согласуется с гипотезой гонки по времени с
    ещё не до конца остановленными PIL-подсистемами (`adsp`/`cdsp`/`venus`/
    `spss`/`cvpss`/`slpi`/`a650_zap`/`npu`/`ipa_fws`/`ipa_uc` показывали
    `OFFLINING`, а не `OFFLINE`, когда проверялось для WLAN) — а не с
    единственным фиксированным адресом. Требует физической перезагрузки для
    восстановления, откат на V56.5 не выполнять.

Следующий шаг (не начат, ожидает владельца): (а) повторить r69 как есть,
чтобы проверить воспроизводимость/недетерминизм напрямую, или (б) проверить
и, если нужно, довести до `OFFLINE` остальные PIL-подсистемы перед kexec, не
только WLAN.

## Чистый повтор r68 после остановки параллельного r69

41. Владелец остановил параллельный эксперимент и выбрал вариант Codex r68.
    r68 recovery повторно записан после проверки SHA-256
    `c92c84c5cd67c80a72c3e43d1fff67e57933f59fbdcc468427b063839ba428c6`.
    Loader подтвердил именно r68 Image SHA-256
    `09c1b144772bcc37644bf62774549bf4bd8eb01b22a6aba265d641227845a8ec`,
    `kexec_loaded=1`, CPU `0-7` online.
42. Execute снова дал немедленный reset. После автоматического появления COM9
    подтверждены `up 0 min`, `not-loaded`, `kexec_loaded=0`. Это второй
    независимый PASS checkpoint после `arm64_memblock_init()`.
43. r69 менял kernel layout посредством пересборки, поэтому следующий
    full-boot тест должен сохранить проверенный layout r68: в готовом r68
    Image заменить только единственный checkpoint `smc #0` на равноразмерный
    четырёхбайтный AArch64 `nop`. Все остальные байты должны совпадать.

## r70 — сохранение полного layout r68

44. В готовом r68 Image однозначно найдена checkpoint-инструкция по offset
    `0x019c5238`. r70 создан без компиляции и релинковки: изменены ровно четыре
    байта `smc #0` (`03 00 00 d4`) на равноразмерный `nop`
    (`1f 20 03 d5`). Полный префикс и суффикс проверены `cmp`; размер Image
    остался 29466632 байта. r70 Image SHA-256
    `9644d29f837f0d52f7b25dcc19a4ea6b495833782810f2e6a933d74dacfd662f`.
45. Recovery SHA-256
    `b87db3cb7efac5c68476618964a03191ca63b0387d216b5a5d26f1cc907459fb`
    прошёл `AUDIT_RESULT=PASS`, записан только в `recovery_b` вместе с test
    `vbmeta_b`. Loader подтвердил точный r70 Image, `kexec_loaded=1`, CPU
    `0-7` online.
46. После execute ожидаемого reset нет, но полноценная 6.12/Arch-система не
    появилась: старый COM9 остаётся перечисленным без нового gate-сеанса,
    fastboot отсутствует, WLAN SSH не поднялся. Нужна фотография текущего
    framebuffer marker для точной поздней границы. Это доказывает, что одного
    сохранения layout недостаточно; оставшийся сбой позднее r68 checkpoint или
    зависит от продолжающегося DMA/тайминга.
47. Получены два фото r70. Исправлена прежняя ошибка чтения маркера: широкая
    зелёная полоса — сохранённый 256-строчный фон stage 21; после настройки
    fixmap все следующие маркеры перерисовывают только верхние 16 строк.
    Узкая сине-фиолетовая линия соответствует `0xff8000ff`, stage 30, сразу
    после возврата из `paging_init()`. Следовательно, этот запуск r70 чисто
    прошёл `paging_init()` и завис позднее в `setup_arch()`.
48. Собран r71 без компиляции/релинковки, прямо из r70. В Image изменены три
    инструкции (12 отличающихся байтов): нормальный путь пропускает старый
    checkpoint trampoline, `smc #0` восстановлен, а вызов `psci_dt_init()`
    заменён переходом в trampoline после возврата из `unflatten_device_tree()`,
    `bootmem_init()`, `request_standard_resources()` и
    `early_ioremap_reset()`. Размер Image неизменен 29466632 байта, SHA-256
    `3b243f8d55d2b801ed865adbe5b30dd803f0a5cd09ddc598a4bd41a04abd0f02`.
49. r71 recovery SHA-256
    `85b62c335c74248a4ebd57326e47569c48b5ce87e1331b1538a960f1e1bca7b9`
    прошёл полный offline audit `AUDIT_RESULT=PASS` и добавлен в строгий
    allowlist guarded controller. Ожидаемый PASS на железе — автоматический
    reset; отсутствие reset при узкой stage-30 полосе локализует сбой внутри
    четырёх вызовов до `psci_dt_init()`.
50. r71 прошит и запущен. First stage подтвердил точный Image SHA-256,
    `kexec_loaded=1`, CPU `0-7`. Автоматического reset не произошло; старый
    COM9 остался перечисленным, но открыть его нельзя (Windows error 31), что
    соответствует прежнему genuine kexec-hang. Следовательно, зависание после
    stage 30 находится внутри `unflatten_device_tree()`, `bootmem_init()`,
    `request_standard_resources()` или `early_ioremap_reset()`.
51. Подготовлен r72 без релинковки: checkpoint перенесён в середину этого
    участка, после `unflatten_device_tree()` и `bootmem_init()`, перед
    `request_standard_resources()`. Image SHA-256
    `11ef7ffb0a4335c8b742ab75a2b6f96da5e5695f0ef1f8ab2ea88c2124d38bff`,
    recovery SHA-256
    `fe75c85c166e0361d0902b6c7f0464556eea15a9b11c52c45155ceb0a6899f14`,
    `AUDIT_RESULT=PASS`, strict allowlist обновлён.
52. r72 прошит и запущен; точный payload подтверждён, `kexec_loaded=1`, CPU
    `0-7`. За 50+ секунд checkpoint не дал reset. Значит выполнение зависает
    либо в `unflatten_device_tree()`, либо в следующем `bootmem_init()`; два
    последующих вызова из r71-интервала исключены.
53. Собран r73 без релинковки с checkpoint ровно между этими вызовами — после
    `unflatten_device_tree()`, перед `bootmem_init()`. Image SHA-256
    `f20b414abaa1f60d1ab61e56e6d2d3d56f568b529ba150db8d6fe10d167cd93c`,
    recovery SHA-256
    `c23d34cdb7d5736067391441b25d088ebed6694e00d2d6ad6760b3b004dc037e`,
    полный audit `PASS`, strict allowlist обновлён.
54. r73 прошит и запущен с точным payload (`kexec_loaded=1`, CPU `0-7`). За
    55+ секунд reset не произошёл. Это однозначно доказывает зависание внутри
    `unflatten_device_tree()`; следующий `bootmem_init()` не начинался.
55. Собран r74 без релинковки. Внутри `unflatten_device_tree()` checkpoint
    поставлен сразу после первого вызова `fdt_scan_reserved_mem_reg_nodes()`.
    Image SHA-256
    `dd41ccccb13526e40e0bd1bef1278786808c3635a865b84974a3d99cbe0019b0`,
    recovery SHA-256
    `8eaa8681df615d4e37764a6f83f7cdc5d8a26ac6b29396c23a3c2cca38ef2f24`,
    полный audit `PASS`, strict allowlist обновлён.
56. r74 прошит и запущен с точным payload. Execute дал быстрый
    `Connection reset`; COM9 переобнаружился, свежий сеанс подтвердил `up 0
    min`, `kexec_loaded=0`, `not-loaded`. Значит
    `fdt_scan_reserved_mem_reg_nodes()` возвращается чисто.
57. Собран r75 без релинковки с checkpoint сразу после
    `__unflatten_device_tree()`, перед `of_alias_scan()`. Image SHA-256
    `3fb4fa1dba75fedca13083824bb57d018424928b86999cf62ed267334c0def2e`,
    recovery SHA-256
    `1034659931abef733e479dc693f065dbacde33e79881fcba4790464d34d9df6a`,
    полный audit `PASS`, strict allowlist обновлён.
58. r75 прошит и запущен с точным payload (`kexec_loaded=1`, CPU `0-7`). За
    55+ секунд reset не произошёл. Следовательно, зависание находится внутри
    core `__unflatten_device_tree()`; следующий `of_alias_scan()` не
    начинался.
59. Собран r76 без компиляции и релинковки. Caller-checkpoint r75 восстановлен,
    а checkpoint поставлен сразу после первого sizing-only вызова
    `unflatten_dt_nodes(blob, NULL, ...)`. Изменены ровно восемь байтов,
    размер Image сохранён. Image SHA-256
    `0886498b6cc80ed999e4777a2ec84ccfdb816a0a9f91d799c129bc364f964885`,
    recovery SHA-256
    `719c9c389bca6275d0e66b8b73f3c9586d4163a4064a950da89701e6c3cd434e`,
    полный offline audit `AUDIT_RESULT=PASS`, strict allowlist обновлён.
60. r76 прошит и запущен с точным payload (`kexec_loaded=1`, CPU `0-7`). SSH
    разорван reset примерно через 7.8 секунды; COM9 переобнаружился, свежий
    recovery-сеанс подтвердил uptime около минуты, `kexec_loaded=0` и
    `not-loaded`. Первый sizing-only `unflatten_dt_nodes()` возвращается.
61. Собран r77 без компиляции/релинковки с checkpoint сразу после allocator
    callback в `__unflatten_device_tree()`. Изменены ровно восемь байтов,
    размер Image сохранён. Image SHA-256
    `139543061a8b40ccec49a9ed77561b048cb261cbe786f38131621b6b7fd18c6a`,
    recovery SHA-256
    `df750b64cb1408569e263630f30f814251393b7556540a12ff579acafb3d6d2a`,
    полный offline audit `AUDIT_RESULT=PASS`, strict allowlist обновлён.
62. r77 прошит и запущен с точным payload (`kexec_loaded=1`, CPU `0-7`). За
    55+ секунд reset не произошёл; при отсутствии bridge-процессов COM9
    стабильно возвращал Windows error 31. Allocator callback
    `early_init_dt_alloc_memory_arch()` не возвращается.
63. Собран r78 без компиляции/релинковки с checkpoint внутри
    `memblock_alloc_try_nid()`, сразу после `memblock_alloc_internal()` и до
    его последующего zero-fill. Изменены ровно восемь байтов, размер Image
    сохранён. Image SHA-256
    `c33199d70f18a56c114e9fe6e813b68b887b0fadf836392b871646253eb82b7f`,
    recovery SHA-256
    `27a139ae3cdc0dec3b5db12ecf95efb127df5dcbe11eab5bc57d0e139207baed`,
    полный offline audit `AUDIT_RESULT=PASS`, strict allowlist обновлён.
64. r78 прошит и запущен с точным payload (`kexec_loaded=1`, CPU `0-7`). COM9
    переобнаружился; после готовности gate свежий recovery-сеанс подтвердил
    uptime около минуты, `kexec_loaded=0`, `not-loaded`. Следовательно,
    `memblock_alloc_internal()` возвращается успешно.
65. Собран r79 без компиляции/релинковки с checkpoint сразу после zero-fill в
    `memblock_alloc_try_nid()`. Изменены ровно восемь байтов, размер Image
    сохранён. Image SHA-256
    `498f6636980955726af8f637caf5cf5b7bcf09011b40f166daaddab1438c7942`,
    recovery SHA-256
    `904b8036c774d2cd1539019bf59c6201860b03b74cd94635890cf43b9d876979`,
    полный offline audit `AUDIT_RESULT=PASS`, strict allowlist обновлён.
66. r79 прошит и запущен с точным payload (`kexec_loaded=1`, CPU `0-7`). COM9
    переобнаружился, свежий recovery-сеанс подтвердил uptime 0 минут,
    `kexec_loaded=0`, `not-loaded`. Zero-fill возвращается; выделенный адрес
    доступен для записи.
67. Собран r80 без компиляции/релинковки с checkpoint сразу после полного
    возврата `memblock_alloc_try_nid()` в
    `early_init_dt_alloc_memory_arch()`. Изменены ровно восемь байтов, размер
    Image сохранён. Image SHA-256
    `aef75194e5138758dfcb00b05c60b6c0f4e866f42f53579f7d7aa16769729211`,
    recovery SHA-256
    `d97cb7e93a34e4d44eaae91dd945e7861e71db8e74a4e88752ec0f3f2fd17a2d`,
    полный offline audit `AUDIT_RESULT=PASS`, strict allowlist обновлён.
68. r80 прошит и запущен с точным payload (`kexec_loaded=1`, CPU `0-7`). COM9
    переобнаружился, свежий recovery-сеанс подтвердил uptime 0 минут,
    `kexec_loaded=0`, `not-loaded`. Полный `memblock_alloc_try_nid()`
    возвращается в `early_init_dt_alloc_memory_arch()`.
69. Собран r81 без компиляции/релинковки: финальный `ret` успешного пути
    `early_init_dt_alloc_memory_arch()`, после `ldp`/`autiasp`, заменён на
    checkpoint. Изменены ровно восемь байтов, размер Image сохранён. Image
    SHA-256
    `5caba6e943ffabc4ee82df047959b1e41f9ad7103d78d3f52227a3e2c2acd2a2`,
    recovery SHA-256
    `9214499d38ef463d8e0d58cf30550863a7799835b3a105a16f48be31863fec74`,
    полный offline audit `AUDIT_RESULT=PASS`, strict allowlist обновлён.
70. r81 прошит и запущен с точным payload (`kexec_loaded=1`, CPU `0-7`). За
    55+ секунд reset не произошёл; COM9 без bridge-процессов возвращал Windows
    error 31. Сбой расположен в stack-restore/`autiasp` epilogue
    `early_init_dt_alloc_memory_arch()` до финального `ret`.
71. Собран r82 без компиляции/релинковки: `autiasp` после обеих stack-load
    инструкций и перед `ret` заменён на checkpoint. Изменены ровно восемь
    байтов, размер Image сохранён. Image SHA-256
    `425cce7b542320065e5c8622629aa02853003ea8100b5ff7e6b6bbce40aff2c1`,
    recovery SHA-256
    `99979c175a3f58be10081b2c68f9190f2c1cad3d6b9c109252f990fc2141d8dc`,
    полный offline audit `AUDIT_RESULT=PASS`, strict allowlist обновлён.
72. Повторный аудит disassembly выявил ошибку интерпретации r78-r80: r80
    заменял исходный `cbz x0` безусловным reset и не различал NULL/success;
    r79 также имел общий checkpoint для обеих ветвей. PAC-гипотеза снята.
73. r83 сохранил исходный `cbz x0, panic` и поставил reset на первую
    success-only инструкцию. На железе точный r83 payload был загружен
    (`kexec_loaded=1`, CPU `0-7`), но за 55+ секунд reset не случился. Значит
    `memblock_alloc()` действительно возвращает NULL.
74. Извлечён и декомпилирован точный embedded r57 `board.dtb`. Обнаружено
    `/memory@80000000/reg = <0 0x80000000 0 0>`: статический DTB сообщает
    нулевой объём RAM. ABL исправляет placeholder при cold boot, но не
    участвует в kexec handoff.
75. Собран r84 без пересборки ядра: точный r83 checkpoint Image плюс DTB, где
    изменён только memory `reg` на 19 page-aligned System RAM диапазонов из
    V56.6/kexec-tools (76 cells, суммарно `0x1cacf9000` байт). DTB SHA-256
    `c954a4d36e5bf25c2884bc83293222fd866697556c2fa2fc9f67dbcd85fbfcae`.
    Recovery SHA-256
    `22d957cd297b8779fd8b91a87e794a75c5c705b206078eaf02d55f68cab972f5`;
    независимая распаковка, AVB/header/component/hash audit — PASS. Следующий
    шаг: аппаратный r84 reset-checkpoint, затем full-boot r85 с тем же DTB.
76. r84 прошит и запущен. В recovery подтверждены точные SHA r83 Image и r84
    DTB, `kexec_loaded=1`, CPU `0-7`. За 50+ секунд success-checkpoint не дал
    reset. Результат двусмыслен: исправленный DT впервые добавляет реальную RAM
    и тем самым до allocator checkpoint возвращает большую работу
    `paging_init()/map_mem()`, которой при zero-RAM DTB не было.
77. Запланирован r86-контроль: hardware-proven r64 Image с checkpoint сразу
    после `paging_init()` + неизменный r84 real-RAM DTB. PASS/reset докажет,
    что map_mem завершился и r84 дошёл до allocator; no-reset локализует новый
    ранний сбой обратно в отображение реальных RAM ranges.
78. r86 прошит, payload/DTB SHA подтверждены, `kexec_loaded=1`, CPU `0-7`.
    За 50+ секунд post-`paging_init()` reset не произошёл. Следовательно,
    zero-RAM DTB действительно скрывал прежний `paging_init()/map_mem()` сбой:
    проблема возникает при построении linear map реальной памяти, ещё до
    позднего DT allocator.
79. Собран r87: тот же точный r64 checkpoint Image, но DT сообщает только одну
    реальную банку `0x90500000-0x9bffffff` (187 MiB), содержащую kernel,
    initrd, DTB и purgatory и заканчивающуюся перед cont_splash. DTB SHA
    `cc4f6720a84958038295558cbfa80df6c4fec6ee445cfdfa4afd44717f11a186`,
    recovery SHA
    `42606d199a8892d79b42a64934cef3e0fbdf04961a26d8c3594cbacbe285fbd0`,
    полный offline audit PASS. Это отделит проблему самой payload-банки от
    другого диапазона или суммарной 19-bank карты r84/r86.
80. r87 аппаратно дал PASS: execute разорвал SSH через `Connection reset`
    примерно за 8 секунд; свежий COM9 recovery показал `uptime 0 min`,
    `kexec_loaded=0`, `not-loaded`. Значит payload-банк
    `0x90500000-0x9bffffff` отображается, и `paging_init()` возвращается.
81. Проверен ускоренный RAM-only цикл без перепрошивки: новый DTB передаётся
    по SCP в r87 recovery, в RAM-копии load helper заменяется только pinned
    SHA, после чего обычный load/execute сохраняет все остальные условия.
82. r88 (PASS-банк + верхние диапазоны 12-18) загрузился, но за 55+ секунд не
    дал post-`paging_init()` reset. Проблема подтверждённо в верхней группе.
    Подготовлены r91/r92: три малых диапазона 12-14 отдельно от четырёх
    крупных 512 MiB диапазонов 15-18. Их SHA соответственно
    `77d65d4505a21864a47b04f6aeddbb77821c3deaee2c5a1f1f26cffad6e4250e`
    и `8d7a832129b6276d9273c40feb1b57b70ed50d4dec0e054d08454022654db403`.
83. r91 (PASS-банк + три малых верхних диапазона 12-14) аппаратно дал PASS.
    Точный DTB SHA был подтверждён до load, `kexec_loaded=1`; execute разорвал
    SSH через `Connection reset` ровно примерно за 8 секунд. После возврата
    свежий r87 recovery показал uptime около 50 секунд, `kexec_loaded=0` и
    `not-loaded`, а исходный r87 DTB восстановился из initramfs. Следовательно,
    диапазоны 12-14 безопасны; причина r88 находится в четырёх больших
    512 MiB диапазонах 15-18 (или проявляется при их совокупном отображении).
    Следующий RAM-only тест — r92, затем бисекция 15-18 пополам при FAIL.
84. r92 (PASS-банк + четыре больших 512 MiB диапазона 15-18) загружен с
    подтверждённым DTB SHA
    `8d7a832129b6276d9273c40feb1b57b70ed50d4dec0e054d08454022654db403`.
    Load и execute выполнены одним SSH-сеансом; строка
    `r92-loaded-executing` получена до handoff. За 60+ секунд reset не
    произошёл. Это подтверждённый FAIL внутри `paging_init()/map_mem()`.
85. Собраны и проверены DTB следующей бисекции: r93 содержит PASS-банк и
    диапазоны 15-16 (`0x200000000-0x23fffffff`), SHA
    `fa78e1674870ed01127bd7358ac5858f7eed633fdf716dcdbca6558f0d7e2d30`;
    r94 содержит PASS-банк и диапазоны 17-18
    (`0x240000000-0x27fffffff`), SHA
    `f686f1bd3debb74fd630edb24e5d71d3367749520664d7fbe8b5dbe6730db1b8`.
    `fdtget` и SHA256SUMS audit — PASS. Следующий аппаратный тест — r93.
86. Повторная проверка точной конфигурации и исходника Linux 6.12 сняла
    необходимость продолжать географическую бисекцию. r64 использует 4 KiB
    страницы, 48-bit VA, `CONFIG_RODATA_FULL_DEFAULT_ENABLED=y` и только 256
    страниц (1 MiB) во встроенном раннем пуле таблиц. В ARM64
    `rodata_full` включает `NO_BLOCK_MAPPINGS | NO_CONT_MAPPINGS`, поэтому
    linear map строится PTE-страницами: одна страница таблицы покрывает лишь
    2 MiB RAM.
87. Результаты r91/r92 теперь объясняются количественно. Для четырёх больших
    диапазонов r92 (2 GiB) требуется минимум 1024 PTE-страницы, что
    детерминированно превышает пул в 256 страниц. Для полной r84-карты
    `0x1cacf9000` байт требуется минимум 3679 PTE-страниц плюс верхние уровни;
    дефицит — не менее 3423 страниц. Это исчерпание пула, а не неисправная
    физическая банка RAM.
88. Собран r95: точный r64 post-`paging_init()` checkpoint Image, точный r84
    19-range DTB и единственное изменение runtime-политики — `rodata=on`.
    Оно сохраняет защиту read-only секций ядра, но разрешает ARM64 block
    mappings linear map. Recovery SHA-256
    `c61bc155c64a29f3d97fb8f51482a03f18b609cf14f02e34a1b85872abcfca45`;
    boot/AVB/components/helper/76-cell DT audit — `AUDIT_RESULT=PASS`.
89. r95 записан только в `recovery_b` и test `vbmeta_b`; recovery поднялся на
    COM9. Точный payload загружен, helper сообщил `kexec_loaded=1`. Первый
    SSH-сеанс завершился до execute из-за локальной PowerShell-подстановки;
    ядро ещё не исполнялось. После освобождения 300-секундного serial-SSH
    тайм-аута нужно вызвать только `execute-linux-6.12-r38` и проверить reset.
90. Собран следующий r96: точный layout-preserving full-boot r70 Image
    (checkpoint заменён одним `nop`) + полный r84 DTB + `rodata=on`. Recovery
    SHA-256
    `2d47a53f1b43c3fb2ba7ade23e3ce0a295383e08c7e4cdb5fae520ea503173b7`;
    строгий boot/AVB/component/helper/DT audit — `AUDIT_RESULT=PASS`. Образ
    добавлен в hash allowlist, но должен запускаться только после аппаратного
    PASS r95; аппаратная запись r96 пока не выполнялась.
91. После успешного load r95 первый SSH-сеанс оставил `ttyGS0` в зависшем
    binary stream: COM9 перечисляется, но endpoint не принимает даже один
    байт (`SerialTimeoutException`) и не выдаёт gate marker. Host-side PnP
    restart недоступен без прав администратора. Это состояние первого ядра до
    execute, не результат 6.12. Для продолжения нужна одна физическая
    перезагрузка обратно в bootloader, после чего r95 следует снова запустить
    одной атомарной SSH-командой load+execute.
92. После физического возврата в bootloader r95 повторно прошит и выполнен
    одной атомарной SSH-командой. Подтверждены точные payload/DTB SHA,
    `kexec_loaded=1` и маркер `R95_EXECUTING_FULL_RAM_RODATA_ON`. Соединение
    оборвалось через 8,5 секунды по ожидаемому PSCI checkpoint.
93. После автоматического reset COM9 снова поднялся. Свежий recovery-сеанс
    показал uptime `42.91 s`, `kexec_loaded=0`, loader `not-loaded` и исходные
    r95 Image/DTB SHA. Это аппаратно подтверждённый PASS: полная 19-range
    карта (`0x1cacf9000`, 7.1689 GiB) завершает `paging_init()` с embedded
    pool при `rodata=on`. Первопричина r86/r92 и рабочее исправление доказаны.
94. Следующий аппаратный шаг — r96 full boot: тот же подтверждённый DTB,
    `rodata=on` и pool, но post-`paging_init()` checkpoint заменён одним
    `nop`. Для guarded flash нужен ещё один физический возврат в fastboot.
95. r96 прошит и запущен атомарно. Loader подтвердил точные Image/DTB,
    `kexec_loaded=1`; после execute старый USB исчез. Новый USB gadget за 100+
    секунд не появился, но экран впервые показал непрерывную живую консоль
    Linux 6.12 вместо раннего marker-hang.
96. Фото `IMG_1947.jpeg` зафиксировало работающий kernel/workqueue примерно на
    219-221 секунде. Циклически повторяются `ufshcd-qcom 1d84000.ufshc`,
    `Unable to find vdd-hba-supply regulator`, `OPP parse failed -517` и
    повторное добавление в IOMMU group 9. Это `EPROBE_DEFER`-storm UFS/OPP,
    а не прежний сбой MMU/setup_arch. Linux 6.12 впервые дошёл до реального
    platform-driver probe; достижение отмечено как новый bring-up milestone.
97. r97 post-early-ioremap checkpoint собран и прошёл offline audit, но после
    живого r96 он больше не является рациональным следующим тестом и не был
    прошит. Следующий r98 сохраняет full-boot r96 и отключает только UFS host
    и PHY, как безопасный stage-0, чтобы убрать deferred-probe storm и выйти в
    initramfs/USB без доступа к внутреннему Android-хранилищу.
98. Собран r98 headless full boot. DTB SHA-256
    `ae49070f0e18925de03eb1933a995d7603c9dabb590ef98a097858cb9127c9a7`;
    normalized DT diff содержит ровно две замены `status = "okay"` на
    `"disabled"` для UFS host/PHY, а 76 memory cells сохранены. Recovery
    SHA-256
    `2b9304b34501dc6c3f1217daa62a56f37a34521c2a36f971fd4363b2c4dc96c2`;
    полный boot/AVB/component/helper audit — `AUDIT_RESULT=PASS`, strict
    allowlist обновлён.
99. r98 аппаратно запущен. Отключение UFS host/PHY полностью убрало прежний
    `ufshcd-qcom`/OPP `-EPROBE_DEFER` storm. Ядро продолжило инициализацию и
    выявило следующий независимый цикл: `dwc3 a600000.usb: Adding to iommu
    group 8` примерно каждые 64 мс. Это подтвердило, что исправление r98
    работает и что новый блокер находится в USB1/SMMU, а не в MMU или UFS.
100. Собран r99: точный r98 DTB плюс единственная новая семантическая замена
    `/soc/usb@a6f8800 status = "okay" -> "disabled"`. UFS остаётся отключён,
    полный 19-range/76-cell RAM map и `rodata=on` сохранены. DTB SHA-256
    `990014cda31d6d6178f72b592216edae88c1bc32c75d524b88cb00bc0022543b`,
    recovery SHA-256
    `bc916691480b8f943413a236b3cfade587db0499d91f4a834cd608e14c0a9b18`;
    boot/AVB/component/helper/DT audit — `AUDIT_RESULT=PASS`.
101. r99 аппаратно дал первый полный headless-boot Linux 6.12. Консоль дошла
    через `Freeing unused kernel memory` и `Run /init as init process` до
    initramfs и интерактивного root prompt `#`. Циклы UFS и DWC3 отсутствуют.
    Android-разделы не монтировались. USB/NCM ожидаемо отсутствует, поскольку
    USB1 отключён: host-side ping/TCP `169.254.77.2:2323` не проходят и USB
    сетевой интерфейс не перечисляется.
102. Текущий следующий блокер — persistent Arch root: initramfs не нашёл
    `/dev/mmcblk0p1`. В deferred-probe списке остался `8804000.mmc`, а выше
    `rpmh 18200000.rsc` завершился с `-110`. Узел SDHCI привязан через
    `power-domains` и `operating-points-v2`/`required-opps` к RPMh, поэтому
    probe карты не начинается. Следующий r100 должен сохранить 25 MHz/3.3 V
    безопасный режим, но удалить только RPMh power-domain/OPP зависимость у
    SDHCI; затем USB/SMMU исправляется отдельно в r101.
103. r100 собран и прошёл полный offline audit. Его normalized semantic diff
    относительно аппаратно подтверждённого r99 содержит ровно удаление
    `power-domains` и `operating-points-v2` из `/soc/mmc@8804000`; остальные
    свойства microSD не менялись. DTB SHA-256
    `d5364d74a8dc37a934fc40e13764bc0f546615b8fdf6cc29a6838c5944869b13`,
    recovery SHA-256
    `e8c1130f2d934b65c39921e26e632357dbe72d4b68ca4cb2ca5aeada841f2a5f`,
    `AUDIT_RESULT=PASS`. Следующий аппаратный критерий: появление
    `/dev/mmcblk0p1` и переход с initramfs на persistent Arch root.
104. r100 аппаратно снова дошёл до initramfs/root prompt, но `8804000.mmc`
    остался deferred и `/dev/mmcblk0p1` не появился. Следовательно, удаление
    только power-domain/OPP связей недостаточно. Проверка phandle показала,
    что оставшиеся `vmmc-supply`, `vqmmc-supply` и третий clock `xo` также
    предоставляются дочерними узлами провалившегося `rsc@18200000`.
105. В том же DT есть независимый fixed clock `xo-board` 38.4 MHz. Для r101
    рациональный следующий тест: сохранить уже включённые первым 4.19 ядром
    линии питания microSD без RPMh regulator consumer-ссылок и заменить только
    MMC `xo` с RPMh clock-controller на `xo-board`. Первый kernel читает эту
    карту вплоть до kexec, поэтому это проверка наследованного питания, а не
    попытка включить неизвестное напряжение.
106. r101 собран и прошёл полный offline audit. В `/soc/mmc@8804000` удалены
    оставшиеся зависимости от провалившегося RPMh RSC: `vmmc-supply` и
    `vqmmc-supply`; третий clock `xo` заменён с RPMh clock-controller на
    независимый fixed `xo-board` 38.4 MHz. Сохранены 25 MHz, 4-bit,
    `no-1-8-v`, card-detect и redriver GPIO. DTB SHA-256
    `b01a4398ef1e43f5a9ef4a07f26f140f63eed64fd733768c7f6f43372ea1d93e`,
    recovery SHA-256
    `f21938add6495043e5cfcc9bcc13bdcc385aa2637541e251b1434fd9f0a746c1`;
    boot/AVB/component/helper/DT audit — `AUDIT_RESULT=PASS`, strict allowlist
    обновлён. Аппаратный критерий: `mmc0`/`mmcblk0` и успешный переход на
    persistent Arch root. USB1 пока намеренно отключён, поэтому после kexec
    результат оценивается по локальной консоли.
107. r101 аппаратно снова дошёл до initramfs/root prompt, но `/dev/mmcblk0p1`
    не появился и `8804000.mmc` остался в deferred list с `reason unknown`.
    Следовательно, RPMh regulator consumer-ссылки и MMC XO не были последним
    блокером. Исходник `sdhci-msm` 6.12 показывает ранние точки возврата
    `-EPROBE_DEFER` при получении GCC reset/`iface`/`core` clocks. Для r102 DT
    и всё аппаратное описание r101 остаются byte-identical; единственная
    диагностическая дельта — `fw_devlink=off`. Она убирает автоматическое
    supplier-gating: карта либо поднимется на унаследованных ресурсах, либо
    драйвер выведет конкретную ошибку отсутствующего reset/clock.
108. r102 собран и прошёл полный offline audit. Recovery SHA-256
    `6a5db342aca363f7dbba3a38dd62da256b1b12e20397706ce9555e50e7e6e6e9`.
    Image и DTB byte-identical r101; command line содержит ровно по одному
    `rodata=on` и `fw_devlink=off`, `rodata=full` отсутствует. Boot header,
    AVB footer, kernel, ramdisk, DTB, recovery_dtbo и helper hashes проверены;
    `AUDIT_RESULT=PASS`, strict allowlist обновлён.
109. r102 аппаратно подтвердил, что `fw_devlink` не является последним
    блокером: `8804000.mmc` всё ещё deferred с `reason unknown`. Чтобы не
    нарушать чувствительную компоновку аппаратно доказанного r70 новой
    линковкой, r103 сохраняет byte-identical Image r70 и DTB r101. Меняется
    только внутренний initramfs: при отсутствии `mmcblk0p1` он выводит вниз
    экрана отфильтрованный полный dmesg по MMC/SDHCI/GCC/clocks/reset/probe,
    `/proc/cmdline`, `devices_deferred` и supplier-ссылки `8804000.mmc`.
110. r103 собран без перелинковки ядра и прошёл полный offline audit. Recovery
    SHA-256
    `df9f0a18a71833da07dd416bef98c95de997df66de6385c5113bb6f23d632330`,
    внутренний диагностический initramfs SHA-256
    `e53c4f96eb6464ef03be460d7c09310a85bef5b14162373ff073a79baeeccec8`.
    Проверены оба ramdisk, exact Image r70, exact DTB r101, recovery_dtbo,
    синтаксис/содержимое диагностического скрипта и command line;
    `AUDIT_RESULT=PASS`, strict allowlist обновлён.
111. Аппаратный вывод r103 выявил две ошибки упаковки, которые прежний аудит
    не ловил. В command line одновременно присутствовали
    `fw_devlink=permissive` и `fw_devlink=off`, поэтому r102/r103 нельзя считать
    чистой проверкой режима `off`. Кроме того, диагностический pipeline
    остановился на `tail: not found`, а жёстко заданный sysfs-путь SDHCI не
    совпал с фактической иерархией. При этом Linux 6.12 снова стабильно дошёл
    до initramfs/root prompt; UFS и USB отключены, Android не монтировался.
112. r104 исправляет упаковку без перелинковки ядра: helper содержит ровно один
    `fw_devlink=off`, полностью исключает `fw_devlink=permissive` и проверяет
    точный SHA-256 внутреннего initramfs. Диагностика использует
    `busybox tail` и динамически ищет `8804000.mmc` под `/sys/devices`, после
    чего печатает supplier/consumer links. Recovery SHA-256
    `7abed067fa40f4e1b1d53859bcb7cbadccde275988bdaa9176e67cbc4479b825`,
    inner-initramfs SHA-256
    `4b9ab65af3c69748eecd5b37c94db948679d8ac763ec63aa4ae6d2e41eb0317d`;
    полный boot/AVB/component/helper/diagnostic audit — `AUDIT_RESULT=PASS`.
    Ошибочный r103 удалён из strict allowlist и заменён r104.
113. Аппаратная диагностика r104 отработала полностью. У platform-device
    `/sys/devices/platform/soc@0/8804000.mmc` отсутствовали `driver` и
    `iommu_group`, а supplier/consumer links были пусты. Следовательно,
    `fw_devlink` больше не блокирует probe; наиболее ранний оставшийся кандидат
    — DMA/IOMMU-конфигурация platform bus до входа в `sdhci_msm_probe`.
114. r105 собран как безопасная проверка этой гипотезы. Только у внешнего
    `/soc/mmc@8804000` удалено `iommus`; свойство `sdhci-caps-mask` установлено
    в `0x00480000`, что маскирует одновременно SDMA (`0x00400000`) и ADMA2
    (`0x00080000`) и принудительно оставляет PIO. UFS и USB1 выключены,
    Android-разделы не монтируются. DTB SHA-256
    `4e34dcbc183be12051e14a80f3c1352acede2a6355c685ee38de758c99415749`,
    recovery SHA-256
    `6145a1ac9d39b1a6d32d3cec7a2ce405e06d809a73e588d6362b42435987f6b2`,
    inner-initramfs SHA-256
    `4f257c93654b7c6778e8683ea0750d0f624ae3b99742f2377ccdd67e3eb2d09d`;
    полный аудит — `AUDIT_RESULT=PASS`.
115. r105 записан в `recovery_b` вместе с ранее проверенным test `vbmeta_b`;
    first-stage recovery поднял USB ACM/COM9. Helper на самом планшете проверил
    хеши и загрузил payload, после чего был отправлен явный kexec в Linux 6.12.
    USB во втором ядре отключён намеренно, поэтому аппаратный результат
    оценивается по локальному блоку `R105 SDHCI DIAGNOSTICS`.
116. r105 аппаратно не изменил результат: `8804000.mmc` остался deferred и не
    получил `driver`, несмотря на отсутствие IOMMU и принудительный PIO.
    Гипотеза раннего IOMMU/DMA-блокера отвергнута. Поскольку драйвер не вывел
    даже сообщения `sdhci_msm_gcc_reset`/`devm_clk_get`, следующий вероятный
    возврат `-EPROBE_DEFER` находится в `mmc_of_parse()` при запросе
    `cd-gpios` либо в автоматическом pinctrl bind до вызова probe.
117. r106 удаляет у `8804000.mmc` `cd-gpios`, `pinctrl-names`, `pinctrl-0`,
    `pinctrl-1` и `redriver-power-gpios`, оставляя рабочее состояние выводов,
    унаследованное от first-stage 4.19. Пустое `broken-cd` включает polling.
    No-IOMMU и PIO mask r105 сохранены. Recovery SHA-256
    `3332921d39fc8790f11afbd39d3605eefd24cab7f7cdcbc4c500e4c642d07d0e`,
    inner-initramfs SHA-256
    `8ce5ebbfe2b2d66f144502b0db155b9472a4b63c7f83c1ae675a6662184b7b78`;
    полный аудит — `AUDIT_RESULT=PASS`.
118. r106 прошит в `recovery_b`, first-stage recovery и COM9 поднялись. Helper
    на планшете подтвердил хеши r106 и был выполнен kexec в Linux 6.12.
    Результат оценивается по локальной консоли: ожидается либо `mmc0`, либо
    первая конкретная ошибка reset/iface/core clock вместо раннего безымянного
    defer.
119. r106 аппаратно дал первый успешный bind SD-контроллера на Linux 6.12:
    `mmc0: SDHCI controller on 8804000.mmc [8804000.mmc] using PIO`.
    В sysfs появились `driver -> .../sdhci_msm` и `mmc_host`; сам
    `8804000.mmc` исчез из deferred probes. Это доказывает, что ранний блокер
    находился в CD/pinctrl GPIO-зависимостях. Карта `mmcblk0` ещё не появилась.
120. Наиболее вероятная причина отсутствия ответа карты — выключенный внешний
    SD signal redriver: r106 убирал `redriver-power-gpios`, а патч
    `0014-mmc-sdhci-msm-add-redriver-power-gpio.patch` включает GPIO при
    `REQ_BUS_ON`. r107 сохраняет весь hardware-proven r106 путь и возвращает
    только `redriver-power-gpios = <&tlmm 75 0>`. Recovery SHA-256
    `1c0af2aacf3d4a197e262850e5952f7e6933af75d6d7edb74af0f91e4491c01c`,
    inner-initramfs SHA-256
    `706c1098e44b62e7d41a51966b36e8979f1deebeed1b00dec9cc5656c30da318`;
    полный аудит — `AUDIT_RESULT=PASS`.
121. r107 записан в `recovery_b` вместе с проверенным test `vbmeta_b`.
    First-stage recovery штатно поднял COM9; helper на планшете проверил
    payload и сообщил `r107: Linux 6.12 payload verified and loaded`.
    Затем выполнен явный kexec через
    `/run/tb371fc-rescue/execute-linux-6.12-r38`; последовательный SSH-канал
    исчез в момент перехода во второе ядро, как и в предыдущих успешных
    запусках. Аппаратный результат r107 теперь определяется по локальной
    консоли: ключевой критерий — появление `mmc0: new ... SD card`,
    `mmcblk0`/`mmcblk0p1` либо конкретной ошибки включения redriver GPIO.
122. Аппаратный результат r107 однозначен: `sdhci_msm: failed to get redriver
    power GPIO`, после чего `8804000.mmc` снова остался без `driver` и попал
    в deferred probes. Следовательно, GPIO-consumer нельзя возвращать в MMC
    node до исправления ранних TLMM/pinctrl зависимостей; r106 остается
    контрольной точкой успешного bind.
123. r108 сохраняет точный dependency-free MMC node r106 и включает внешний
    SD redriver через provider-local `gpio-hog` внутри
    `/soc/pinctrl@f100000`: GPIO 75, active-high, `output-high`. Это не создает
    supplier link от MMC и должно сохранить bind `sdhci_msm`, одновременно
    подав питание на redriver. Recovery SHA-256
    `9dd91af87b708b963f6103881323f8361cdc955c6f5387dc75fe5b5af99e582e`,
    inner-initramfs SHA-256
    `29603dcdd70b98e61b9b07908251244d89dbf3958600673bb1b869d83a680080`;
    полный аудит всех вложенных компонентов — `AUDIT_RESULT=PASS`.
124. r108 успешно записан в `recovery_b` вместе с проверенным test
    `vbmeta_b`; fastboot подтвердил обе записи, recovery поднял COM9. Helper
    на самом планшете проверил payload (`r108: Linux 6.12 payload verified and
    loaded`), после чего выполнен явный kexec. Последовательный канал исчез
    при переходе во второе ядро штатно. Аппаратный критерий r108: одновременно
    сохранить `mmc0: SDHCI controller ... using PIO` и получить ответ карты
    (`mmc0: new ...`, `mmcblk0`, `mmcblk0p1`) без ошибки redriver GPIO.
125. r108 аппаратно сохранил успешный bind: `mmc0: SDHCI controller on
    8804000.mmc [8804000.mmc] using PIO`, sysfs содержит `driver ->
    .../sdhci_msm` и `mmc_host`; ошибки GPIO-hog нет. Карта всё еще не
    ответила (`mmcblk0` отсутствует). Это подтверждает, что GPIO-hog не
    возвращает ранний defer, но требует live-диагностики фактического GPIO,
    power IRQ и команд SD.
126. Для самостоятельного сбора журналов подготовлен r109 поверх r108. USB1
    включен только в `peripheral` mode, у DWC3 `a600000` удалена IOMMU-ссылка,
    которая в r98 вызывала цикл group 8; удалены role-switch/ports зависимости.
    Встроенный NCM rescue должен дать компьютеру shell
    `169.254.77.2:2323`, откуда можно напрямую сохранить полный `dmesg`,
    debugfs GPIO и MMC sysfs. UFS остается disabled, Android не монтируется.
    Recovery SHA-256
    `3335cafcda78a544d765b074b8e8e9ffb051429c49762d083a6b7faa35d7be1e`,
    inner-initramfs SHA-256
    `e17923bf3d4806311204b380a9c046d02e23688dfa61ab368f05f39f883e2602`;
    полный аудит — `AUDIT_RESULT=PASS`.
127. r109 записан в `recovery_b`, recovery поднял COM9, payload проверен на
    планшете и выполнен kexec в Linux 6.12. После перехода Windows в течение
    35 секунд не обнаружил ни NCM-интерфейс, ни новое USB-устройство VID
    `1d6b`; `169.254.77.2` недоступен. Следовательно, одного удаления DWC3
    IOMMU/role-switch зависимостей недостаточно: UDC не зарегистрировался либо
    gadget не смог bind. Для следующего шага требуется локальный USB/DWC3
    фрагмент dmesg; UFS по-прежнему disabled и Android не монтировался.
128. Фото r109 показывает, что ядро продолжает загрузку после диагностического
    warning `early_ioremap leak`; это не panic. USB/DWC3 строки отсутствуют из
    кадра, потому что r109 использовал старый MMC-only фильтр. r110 сохраняет
    exact r109 Image/DTB и меняет только initramfs: последним блоком печатает
    USB/DWC3/PHY/UDC dmesg, UDC/gadget sysfs, DWC3 device paths и GPIO 75,
    предварительно снижая console loglevel для защиты результата от SPMI
    warning-спама. Recovery SHA-256
    `2e8f098def6659c9fe4d44de55ec4cf61ffa4ff2b545ac2849fab46c82ffae3e`,
    inner-initramfs SHA-256
    `c2666909e959b75ee08e41952a6b92240c8252c2338eff63db1c3b31ed0b8df3`;
    полный аудит — `AUDIT_RESULT=PASS`.
129. r110 успешно записан в `recovery_b`, recovery поднял COM9, helper на
    планшете проверил payload и выполнен kexec. После перехода Windows снова
    не увидел USB gadget/NCM, `169.254.77.2` недоступен. Диагностический блок
    r110 теперь остается последним на локальной консоли и содержит точную
    причину отсутствия UDC, DWC3 sysfs и состояние GPIO 75; следующий DT fix
    должен опираться на этот блок, а не на предположение.
130. Фото r110 снова не содержит финального initramfs блока даже через 274 с,
    хотя ядро остается живым. Значит, выполнение блокируется до MMC rescue,
    наиболее вероятно внутри `setup-usb-console`/configfs UDC bind. r111
    сохраняет exact r109 Image/DTB и ограничивает этот helper 12 секундами
    через BusyBox timeout; после него гарантированно продолжает загрузку и
    печатает USB/DWC3/UDC, GPIO 75 и MMC диагностику последним блоком.
    Recovery SHA-256
    `c4d45bb18f0386fcad7601bae338d3ef733effb78331acfbe8edb4004743d490`,
    inner-initramfs SHA-256
    `a44f3226f4351918893b6a44bbedba1d9bb8efb46e19c174ebb5c65889aa668b`;
    полный аудит — `AUDIT_RESULT=PASS`.
131. r111 записан в `recovery_b`, recovery/COM9 и проверка payload прошли,
    затем выполнен kexec. После 12-секундного bounded USB setup и еще 35 с
    наблюдения NCM на Windows не появился, `169.254.77.2` недоступен. В отличие
    от r110, initramfs теперь обязан пройти зависающий helper и оставить
    финальный `R111 USB LIVE-LOG DIAGNOSTICS` блок на локальной консоли.
132. Фото r111 (`IMG_1969`) доказало, что USB1-регрессия останавливает ядро
    после поздних initcalls, но до `Run /init`; userspace timeout не помогает.
    Базой снова назначен r108: USB1 disabled и успешный bind `mmc0`.
133. До kexec через COM9/SSH впервые снято точное состояние microSD в 4.19:
    `mmc0:59b4 ED2S5`, `mmcblk0` 119 GiB и `mmcblk0p1`; GPIO14 показывает
    card-present, GPIO75 включает redriver. `pm8150a_l9=2.950 V`, а SD-I/O
    `pm8150a_l6=1.808 V`. Железо и карта исправны; r108 наследовал 1.8 В от
    SDR104, но одновременно сообщал incoming MMC core свойство `no-1-8-v`.
134. r112 проверяет ровно это противоречие: exact r108 DT, удалено только
    `no-1-8-v`. PIO-only, 25 MHz, broken-CD, GPIO75 hog, UFS/USB1 disabled и
    запрет Android mounts сохранены. DTB SHA-256
    `c4fb4fb3ecb01e3bd40e91d751fb094e9a2e891c394cd35a42c460d7359c256a`,
    recovery SHA-256
    `1fa54ce31d9d9f2c6601be344340c31a6be30ca8cb888a85532e589684b1fb47`,
    inner-initramfs SHA-256
    `1639358758b39132760db8f90c4f64b7aca4a9342191eece1b9d6693404ccdda`.
135. Независимый аудит r112 завершен с `AUDIT_RESULT=PASS`: Android boot
    header, AVB footer, recovery kernel/ramdisk/DTB/recovery_dtbo, exact r70
    Image, r112 DTB, inner initramfs, helper hashes и все UFS/USB/MMC safety
    invariants проверены. r112 добавлен в локальный allowlist контролируемой
    двухраздельной процедуры.
136. r112 записан в `recovery_b` и test `vbmeta_b`; first-stage recovery
    поднял COM9. На планшете helper подтвердил exact Image SHA-256
    `9644d29f...`, DTB `c4fb4fb3...`, inner initramfs `1639358758...`, затем
    выполнен явный kexec. USB1 во втором ядре отключен намеренно. Аппаратный
    критерий: после `mmc0: SDHCI controller ... using PIO` должны появиться
    `mmc0: new ... SD card`, `mmcblk0` и `mmcblk0p1`.
137. Фото r112 (`IMG_1971`) опровергло гипотезу, что достаточно разрешить
    1.8 В во втором ядре. `sdhci_msm` снова успешно привязался и создал
    `mmc0 ... using PIO`, но отсутствуют `mmc0: new ...`, `mmcblk0` и
    `mmcblk0p1`. Значит, сбой находится в повторной инициализации уже
    переключенной в SDR104 карты, а не в probe/bind контроллера.
138. Для r113 изменена противоположная сторона kexec. Во всех трех реальных
    base-DTB первого Lenovo 4.19 свойство
    `/soc/sdhci@8804000/qcom,bus-speed-mode` ограничено значениями `SDR12` и
    `SDR25`; recovery DTBO проверен и SDHCI speed override не содержит. Цель —
    оставить карту и SD-I/O в согласованном 3.3-В legacy-состоянии перед kexec.
    Второе ядро и весь payload сохранены байт-в-байт как в стабильной r108:
    PIO, 25 MHz, `no-1-8-v`, GPIO75 hog, UFS/USB1 disabled, Android не
    монтируется.
139. r113 собран и независимо проверен: Android boot header, AVB footer,
    recovery kernel/ramdisk/DTB/recovery_dtbo и вложенный r108 payload
    совпадают с ожидаемыми; во всех base-DTB подтверждены только SDR12/SDR25.
    Recovery SHA-256
    `509d77fb54927f3326478d697dce257d4978444a6a7814a552b48913ade7d6ba`,
    first-stage DTB SHA-256
    `4fa9ece97e4ceb45bb1f589eaf053687f4223785c38634a6011078069046f63f`;
    `AUDIT_RESULT=PASS`. Образ добавлен в локальный allowlist.
140. r113 аппаратно применил ограничение первого ядра: до kexec live DT
    подтвердил ровно `SDR12 SDR25`, payload r108 прошёл hash-проверку. После
    kexec результат не изменился: `sdhci_msm` создаёт `mmc0 ... using PIO`,
    но карта не отвечает и `mmcblk0` отсутствует (`IMG_1972`). Следовательно,
    гипотеза несогласованного 1.8/3.3-В handoff опровергнута.
141. Следующий тест r114 не меняет hardware DT. Он сохраняет exact r108 и
    добавляет только командную диагностику в initramfs: runtime dynamic-debug
    для MMC/SDHCI, `/sys/kernel/debug/mmc0/ios`, реальные SDCC2 clock rates и
    безопасный unbind/rebind неиспользуемого PIO host. Цель — получить первую
    конкретную ошибку SD-команды и проверить гипотезу неверной частоты SDCLK.
142. r114 собран и прошёл независимый аудит: Android boot header, AVB footer,
    recovery kernel/ramdisk/DTB/recovery_dtbo, exact r70 Image, exact r108 DTB,
    helper hashes, синтаксис и все диагностические маркеры проверены.
    Recovery SHA-256
    `00cd7b4f5ca51f5bc9e3bbe1d7584ea92d15d42977bde2133c272a56cca2c64b`,
    inner-initramfs SHA-256
    `295f04bb0b0326377e869a9444ccbca5976ebec942f9378f63044efa6183351a`;
    `AUDIT_RESULT=PASS`. Образ добавлен в локальный allowlist.
143. r114 записан в `recovery_b` вместе с проверенным test `vbmeta_b`.
    Recovery поднял COM9, helper на планшете подтвердил exact r114 payload и
    загрузил его в память. После явной команды execute COM9 исчез, подтверждая
    переход kexec в Linux 6.12. Ожидаемый итог на локальном экране — блок
    `R114 MMC COMMAND AND CLOCK TEST` с post-rebind dmesg, `mmc0/ios` и
    фактическими SDCC2 clock rates.
144. Фото r114 (`IMG_1973`) впервые локализовало отказ на уровне протокола.
    Хост выставляет 3.3 В и 400 кГц, power IRQ завершается, `CMD0` проходит без
    ошибки. Первый ожидающий ответа `CMD8` и все `CMD55` возвращают `-110`
    (`ETIMEDOUT`). Следовательно, SDHCI/IRQ/clock framework функционируют, но
    карта не возвращает сигнал; наиболее вероятен неинициализированный внешний
    redriver после warm-kexec. Циклическая прокрутка — включённый r114
    dynamic-debug и повторные попытки опроса, а не перезагрузка ядра.
145. r115 заменяет всегда высокий GPIO75 hog на стандартный встроенный
    `mmc-pwrseq-simple`: active-low reset заставляет GPIO75 физически перейти
    low при probe и high в `post_power_on` перед первой SD-командой. Остальная
    hardware-база exact r108 сохранена. Критерий успеха: `CMD8` без `-110`,
    затем `mmc0: new ... ED2S5` и `mmcblk0`.
146. r115 собран и прошёл полный аудит. DTB подтверждает единственный pwrseq
    phandle `0x121`, `reset-gpios = <&tlmm 75 GPIO_ACTIVE_LOW>`, задержку
    post-power-on 10 мс и отсутствие прежнего GPIO-hog. Recovery SHA-256
    `0a9f7dcf8bb5d5e9d4ec59071e94b90828adb5b6a70960f936590e3c91312368`,
    DTB SHA-256
    `6dafc25296e3b4cfa013f7b1fedc8f7f239a5b18adbc3e2c1b9adc6bf6696da7`,
    inner-initramfs SHA-256
    `ddaf43d14213e32607517c06de6871ca1b3e7af10f47ca5cbd9893919e327761`;
    `AUDIT_RESULT=PASS`. Образ добавлен в локальный allowlist.
147. r115 успешно записан в `recovery_b` с test `vbmeta_b`; recovery поднял
    COM9, helper проверил exact r115 payload и загрузил его. После явной команды
    execute COM9 исчез — kexec в Linux 6.12 состоялся. На этой версии нет
    бесконечного dynamic-debug r114; аппаратный результат определяется по
    появлению `mmc0: new ...`, `mmcblk0` либо стабильному R115 failure block.
148. Фото r115 (`IMG_1975`) показало `pwrseq_simple: reset GPIOs not ready`;
    из-за supplier defer не привязались ни pwrseq, ни `8804000.mmc`. Это
    повторяет ограничение r107: TLMM provider способен выполнить локальный hog,
    но внешний GPIO consumer не готов из-за незаведённых зависимостей.
149. Для r116 адреса и биты проверены по `pinctrl-sm8250.c`: GPIO75 использует
    `CTL=0xF14B000`, `IO=0xF14B004`, OE bit 9 и output bit 1. Встроенный
    initramfs содержит `busybox devmem`. r116 возвращает exact r108 GPIO-hog,
    после первоначального failure безопасно unbind-ит пустой SDHCI host,
    изменяет только output bit 1 low на 1 с и high, затем rebind-ит host и
    проверяет `mmcblk0`. Соседние GPIO, mux и drive-strength не меняются.
150. r116 собран и прошёл полный аудит: exact r70 Image и r108 DTB сохранены,
    rescue-script синтаксически проверен, оба MMIO-адреса, маски output bit,
    порядок unbind→low→high→bind и UFS/USB safety закреплены assertions.
    Recovery SHA-256
    `963c7b8e422d20f82b40f47812f8b9419fdcce32390f759d7b68964d89227942`,
    inner-initramfs SHA-256
    `e9e4ee4766cd4d61bd7f97ecfa8cd0a84dc34c79d7028f032f9aa646bae12583`;
    `AUDIT_RESULT=PASS`. Образ добавлен в локальный allowlist.
151. r116 записан в `recovery_b` с проверенным test `vbmeta_b`; recovery поднял
    COM9, helper на планшете подтвердил exact r116 payload и загрузил его.
    После явного execute COM9 исчез — kexec состоялся. Ожидаемый финальный блок
    `R116 GPIO75 MMIO REDRIVER PULSE` обязан показать IO_BEFORE/LOW/HIGH и
    post-pulse результат повторного SDHCI bind.
## 152. Linux 6.12 r117 — direct SDC2 active-pad restoration (2026-08-30)

> Исправление выводов от 2026-09-07: конфигурация r70 отключает
> PINCTRL_MSM; работа GPIO-hog в прошлых пунктах не была доказана.
> GPIO75 расположен в SOUTH, адрес WEST из r116 ошибочен.
> CMD0 не доказывает ответ SD; фото r114 показывает actual clock 0.
> Актуальные доказательства и ограничения: [R118-PINCTRL-CLOCK-REVIEW.md](R118-PINCTRL-CLOCK-REVIEW.md).

- Web and downstream-source review changed the leading hypothesis: r114 proved that SDHCI launches commands at 400 kHz, but CMD8/CMD55 receive no response. Lenovo 4.19 explicitly switches SDC2 pads between active and sleep states, while the stable r108 DT intentionally has no SDC2 pinctrl consumer to avoid supplier deferral.
- The exact downstream Kona active state is CLK no-pull/16 mA, CMD pull-up/16 mA and DATA pull-up/16 mA. In both downstream Kona and upstream SM8250 pinctrl layouts these fields share physical register `0xF9B7000`; bits 0..12 encode the active state as `0x1fff`.
- Built r117 with unchanged r108 Image/DTB. Rescue diagnostics unbind only empty `8804000.mmc`, preserve unrelated register bits, set the SDC2 active fields, rebind SDHCI and report MMC enumeration.
- Recovery: `D:\TB371FC-builds\linux-6.12.30-tb371fc-v56.6-controlled-kexec-r117-transport-r2\tb371fc-v56.6-controlled-linux-6.12-r117-transport-r2-recovery.img`
- SHA-256: `4c5883aab4c348978ce33615a4803332d1669474176a5652740dbfbdb0addc35`
- Inner initramfs SHA-256: `9180d6b8cda68879dbeb7c70237d283ac4d1919523640d5c7ef1360d91dc27be`
- Audit: `AUDIT_RESULT=PASS`. UFS and USB1 stay disabled; Android partitions are never mounted.

## 153. Linux 6.12 r118 — встроенный pinctrl и цепочка CXO (2026-09-07)

Пересобрано ядро из отдельной копии donor-r68: сохранён ранний пул таблиц
страниц, диагностический SMC заменён NOP, включены PINCTRL_MSM и
PINCTRL_SM8250. В DT восстановлены MMC pinctrl default/sleep; GCC и MMC
получают inherited CXO 19,2 МГц через делитель board XO /2, согласно
SM8250 clk-rpmh. Прямые MMIO-эксперименты r116/r117 не включены.

Recovery SHA256: `67e04f7369eccf1118874c7ec0d7aa4f57c9e020002801783d9008f9bd740b8d`.
При доступной microSD выполняется загрузка существующего Arch через
`/sbin/init` в `multi-user.target`. Добавлены снимки диагностики при отказе
и сохранение dmesg на Arch root при успешном монтировании.

После сборки пользователь разрешил прошивку: запись recovery_b и test
vbmeta_b завершилась OKAY. Первый этап V56.6 поднял COM9/SSH; helper
подтвердил проверку и загрузку payload r118, затем вызван execute/kexec.
COM9 исчез, SSH закрылся. Запуск второго ядра и microSD ещё требуют
подтверждения по экрану; исчезновение USB само по себе успехом не считается.
Полный отчёт, первоисточники и пути: [R118-PINCTRL-CLOCK-REVIEW.md](R118-PINCTRL-CLOCK-REVIEW.md).
