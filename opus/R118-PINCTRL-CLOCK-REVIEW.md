# Linux 6.12 r118 — проверка накопленных результатов, 2026-09-07

Статус: ядро и recovery собраны; по запросу пользователя прошиты recovery_b
и test vbmeta_b. Первый этап V56.6 поднял COM9, SSH вернул
`4.19.157-perf-v56.6+`. Helper проверил и загрузил payload r118; следующей
командой вызван execute/kexec, после чего SSH и COM9 исчезли. Это ещё
не доказательство успешного запуска 6.12: ждём результат на экране.
Цель: обнаружение microSD и запуск существующего Arch в multi-user.target.

## Первый аппаратный результат

Пользователь сообщил: консоль появилась/прокрутилась, затем перезагрузка.
После неё SSH на COM9 подтвердил V56.6/4.19, uptime около двух минут.
В журнале первого ядра PMIC SID0 сообщает PS_HOLD/MSM Controlled Shutdown.
Это не устанавливает инициатора reset. `/proc/last_kmsg` отсутствует,
pstore не доступен в этом первом ядре; файлов `tb371fc-r118*` в `/var/log`
текущего Arch root не найдено.

В командной строке второго ядра обнаружен `panic=-1`: по kernel/panic.c
отрицательный timeout ведёт к немедленному emergency_restart, тогда как
`panic=0` оставляет panic на экране. Поэтому выполнен повторный диагностический
запуск того же payload с единственной заменой `panic=-1` на `panic=0` в
RAM-копии load helper. Флеш-образ не изменён. Helper снова подтвердил
проверку и загрузку r118, затем вызван execute. Ожидается фото результата;
kernel panic пока гипотеза, не установленная причина первого reset.

Фото IMG_2013 и повторное SSH-чтение подтвердили возврат в первый этап
после теста с panic=0: uname `4.19.157-perf-v56.6+`, uptime 178 секунд,
boot_id `aeef8b50-5242-4f43-96a4-68d46663d77d`. RAM-копия helper снова
содержит исходный panic=-1, что согласуется с новым запуском recovery.
Файлов r118 в /var/log нет. PS_HOLD/SOFT повторяется в PMIC boot reason.
Таким образом, panic=0 не предотвратил наблюдаемый reset; обычный panic
после разбора этой командной строки не является достаточным объяснением.
Нужно локализовать reset до/после разбора cmdline и инициализации pinctrl.
Строка V56.5/r38 на фото — исторический баннер first-stage, не версия
фактически работающего ядра; 6.12 и microSD второго этапа не подтверждены.

## Что действительно найдено

1. Конфигурация сохранённого r70 Image, использованного в r99–r117,
   содержит `# CONFIG_PINCTRL_MSM is not set`. Соответственно, SM8250 TLMM
   не мог обслуживать pinctrl/GPIO. Утверждения старого PROGRESS.md о том,
   что GPIO hog уже работал, не подтверждены и противоречат конфигурации.
2. GPIO75 находится в SOUTH tile. При имеющейся карте регистров адреса
   CTL/IO — `0xF54B000/0xF54B004`. В r116 были адреса WEST
   `0xF14B000/0xF14B004`; результат того эксперимента нельзя считать
   проверкой redriver. В r118 прямых записей devmem нет.
3. В фото r114 `Setting clock at rate 0` означает результат
   `clk_get_rate(core_clk)`, а не требуемые 400 кГц. CMD0 не ожидает
   ответа карты, поэтому его завершение не доказывало работоспособность шины.
4. GCC имел родителей bi_tcxo/bi_tcxo_ao от RPMh, который не инициализировался.
   В SM8250 драйвер RPMh предоставляет CXO как `bi_tcxo_div2`.
   Прямая подстановка board XO 38,4 МГц вместо этого сигнала неверна.
   Предположение об orphan clock согласуется с нулевой частотой на фото;
   физический сигнал до новой аппаратной проверки не измерен.
5. Ограничение SDR12/SDR25 в r113 не доказывало фактическое напряжение
   перед kexec. Гипотеза о питании остаётся открытой.

## Что изменено

- Отдельная копия исходников r68, сохранён встроенный ранний пул таблиц страниц.
- Диагностический `smc #0` в setup.c заменён на `nop` в исходнике.
- Встроены `CONFIG_PINCTRL_MSM=y`, `CONFIG_PINCTRL_SM8250=y`; Kconfig
  также включает IRQ_FASTEOI_HIERARCHY_HANDLERS.
- База DT r108: восстановлены штатные MMC default/sleep pinctrl-состояния.
  GPIO75 output-high hog оставлен и теперь получает настоящий драйвер.
- Для GCC и MMC добавлена модель унаследованного CXO: fixed-factor 38,4/2
  = 19,2 МГц. Это обход отсутствующего RPMh после kexec, а не починка RPMh.
- Initramfs проверяет существующий Arch image marker и запускает `/sbin/init`
  с `systemd.unit=multi-user.target`. Старый KDE runtime не запускается.
- При ошибке сохраняются dmesg, deferred probes, GPIO и clocks в `/run/r118`.
  Это RAM: без доступного транспорта логи исчезнут при перезагрузке.
- При успешном монтировании Arch dmesg записывается в
  `/var/log/tb371fc-r118-kernel.log`, cmdline — в соседний файл.

## Артефакты и воспроизведение

- Исходники WSL Ubuntu-24.04: `/root/tb371fc/linux-6.12-donor-r118`.
- Каталог компиляции: `/root/tb371fc/build-6.12-r118-pinctrl`.
- Payload: `D:\TB371FC-builds\linux-6.12.30-tb371fc-r118-pinctrl`.
- Recovery: `D:\TB371FC-builds\linux-6.12.30-tb371fc-v56.6-controlled-kexec-r118-transport-r2\tb371fc-v56.6-controlled-linux-6.12-r118-transport-r2-recovery.img`.
- Recovery SHA256: `67e04f7369eccf1118874c7ec0d7aa4f57c9e020002801783d9008f9bd740b8d`.
- Image SHA256: `dbcffeead9750aa41228269f2101c32c76cbde42d1bea554db1132ad30eac11d`.
- Скрипты проекта: `scripts/build-linux-6.12-r118-pinctrl.sh`,
  `scripts/package-linux-6.12-r118.py`, `scripts/audit-linux-6.12-r118.sh`.
  Сборка и упаковка требуют новых выходных каталогов и не перезаписывают
  старые r99/r108/r117.

## Границы проверки и следующий тест

Это двухступенчатый recovery: первый этап V56.6/4.19, затем явный kexec
через load-linux-6.12-r38 и execute-linux-6.12-r38. Сам recovery не означает
автоматический запуск второго ядра. Названия r38 у помощников исторические.
Для установки нужен проверенный workflow recovery_b + test vbmeta_b.
Прошивка выполнена в следующем ходе по явному запросу пользователя.

Новая линковка меняет расположение ядра в памяти — раннюю загрузку надо
повторно проверить на устройстве. Старое r70 достигало `/init`, r118 пока
подтверждено только сборкой и статическими проверками. Графика, USB и сеть
в этой версии не заявлены рабочими. USB1 и UFS отключены, SD использует PIO,
питание карты пока наследуется от первого ядра. Модули для нового kernel
release не поставляются; boot-critical драйверы встроены.

Критерии: `uname` содержит r118; есть GPIO provider; MMC actual_clock > 0;
появляются `mmc0: new ... SD card`, `mmcblk0p1`; затем Arch multi-user.
Если карта снова не отвечает — снять ios/clk_summary и состояние питания,
проверить реальное напряжение и handoff. Не объявлять CMD0 успехом карты.

## Сверка с первоисточниками в интернете

- [Linux v6.12 Qualcomm Kconfig](https://raw.githubusercontent.com/torvalds/linux/v6.12/drivers/pinctrl/qcom/Kconfig): зависимости PINCTRL_MSM.
- [SM8250 pinctrl](https://kernel.googlesource.com/pub/scm/linux/kernel/git/stable/linux-stable/+/53c7db5c1916afcecc8683ae01ff8415c708a883/drivers/pinctrl/qcom/pinctrl-sm8250.c): tiles и SD pad fields; также сверено с точным локальным donor-r68.
- [Linux v6.12 GCC SM8250](https://raw.githubusercontent.com/torvalds/linux/v6.12/drivers/clk/qcom/gcc-sm8250.c): родители bi_tcxo и таблица SDCC2 400 кГц.
- [Linux v6.12 RPMh clocks](https://raw.githubusercontent.com/torvalds/linux/v6.12/drivers/clk/qcom/clk-rpmh.c): SM8250 CXO div2.

Первоисточники подтверждают устройство драйверов, но не гарантируют загрузку
конкретного планшета после нашего warm-kexec.
