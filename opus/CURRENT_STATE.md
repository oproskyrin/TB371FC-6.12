# Текущее состояние планшета

Срез обновлён 2026-08-29 после аппаратного запуска r81 и сборки r82. r68 два
раза автоматически перезагрузился из checkpoint сразу после
`arm64_memblock_init()`. r70 сохранил полный layout r68 и заменил только
`smc #0` на `nop`; предоставленные владельцем фото показывают широкую зелёную
полосу stage 21 и узкую сине-фиолетовую полосу **stage 30**. Широкая полоса
остаётся потому, что stage 21 красит 256 строк, а после fixmap маркеры stage
22+ красят только 16 строк. Значит r70 доказанно вернулся из `paging_init()` и
завис позднее внутри `setup_arch()`.

Аппаратный r71 сохранял layout r70/r68 без релинковки. Три
равноразмерные бинарные замены вызывают PSCI reset после
`unflatten_device_tree()`, `bootmem_init()`, `request_standard_resources()` и
`early_ioremap_reset()`, прямо перед `psci_dt_init()`. Payload был точно
проверен и запущен (`kexec_loaded=1`, CPU 0-7), но reset не произошёл; COM9
перешёл в подтверждённое состояние error 31. Значит сбой внутри этих четырёх
вызовов.

Аппаратный r72 поставил checkpoint после `unflatten_device_tree()` и
`bootmem_init()`, перед `request_standard_resources()`. Точный payload был
загружен (`kexec_loaded=1`, CPU 0-7), но reset за 50+ секунд не произошёл.
Значит зависание теперь сужено ровно до `unflatten_device_tree()` или
`bootmem_init()`.

Аппаратный r73 поставил checkpoint после `unflatten_device_tree()`, перед
`bootmem_init()`. Точный payload был загружен (`kexec_loaded=1`, CPU 0-7), но
reset за 55+ секунд не произошёл. Следовательно, зависание точно находится
внутри `unflatten_device_tree()`; `bootmem_init()` не начинался.

Аппаратный r74 поставил checkpoint после
`fdt_scan_reserved_mem_reg_nodes()`. Точный payload был загружен, execute дал
`Connection reset`, COM9 переобнаружился, а свежий сеанс подтвердил `up 0
min`, `kexec_loaded=0`, `not-loaded`. Значит reserved-memory scan исправен.

Аппаратный r75 поставил checkpoint после основного
`__unflatten_device_tree()`, перед `of_alias_scan()`. Точный payload был
загружен (`kexec_loaded=1`, CPU 0-7), но reset за 55+ секунд не произошёл.
Значит зависание находится внутри core `__unflatten_device_tree()`;
`of_alias_scan()` не начинался.

Аппаратный r76 поставил checkpoint сразу после первого sizing-only вызова
`unflatten_dt_nodes(blob, NULL, ...)`. Точный payload был загружен, execute
разорвал SSH примерно через 7.8 секунды, COM9 переобнаружился, а свежий сеанс
подтвердил uptime около минуты, `kexec_loaded=0`, `not-loaded`. Значит первый
sizing-проход возвращается чисто.

Аппаратный r77 поставил checkpoint сразу после возврата allocator callback
`early_init_dt_alloc_memory_arch()`. Точный payload был загружен, но reset за
55+ секунд не произошёл; без bridge-процессов COM9 стабильно дал Windows error
31. Значит allocator callback не возвращается.

Аппаратный r78 поставил checkpoint внутри `memblock_alloc_try_nid()`, сразу
после `memblock_alloc_internal()` и до последующего `memset()`. Точный payload
был загружен, COM9 переобнаружился, свежий recovery-сеанс подтвердил uptime
около минуты, `kexec_loaded=0`, `not-loaded`. Значит внутренний поиск и
резервирование memblock возвращаются успешно.

Аппаратный r79 поставил checkpoint сразу после zero-fill выделенной области.
Точный payload был загружен, COM9 переобнаружился, свежий recovery-сеанс
подтвердил uptime 0 минут, `kexec_loaded=0`, `not-loaded`. Значит zero-fill
возвращается; адрес выделенной области доступен.

Аппаратный r80 поставил checkpoint сразу после полного возврата
`memblock_alloc_try_nid()` в `early_init_dt_alloc_memory_arch()`. Точный
payload был загружен, COM9 переобнаружился, свежий recovery-сеанс подтвердил
uptime 0 минут, `kexec_loaded=0`, `not-loaded`. Значит полный вызов
`memblock_alloc_try_nid()` возвращается.

Аппаратный r81 заменил финальный `ret` успешного пути
`early_init_dt_alloc_memory_arch()` после `ldp`/`autiasp`. Точный payload был
загружен, но reset за 55+ секунд не произошёл; COM9 без bridge-процессов дал
Windows error 31. Значит сбой расположен в коротком stack-restore/`autiasp`
epilogue.

Готов r82: `autiasp` после обеих stack-load инструкций и перед `ret` заменён
на checkpoint. r82 Image SHA-256
`425cce7b542320065e5c8622629aa02853003ea8100b5ff7e6b6bbce40aff2c1`,
recovery SHA-256
`99979c175a3f58be10081b2c68f9190f2c1cad3d6b9c109252f990fc2141d8dc`,
offline audit `AUDIT_RESULT=PASS`. Аппаратный тест ещё не выполнен.

Пользовательскую систему V56.5/KDE 4.19 не восстанавливать.
Vendor 4.19 внутри recovery используется только как короткий kexec-загрузчик
из-за ограничений Lenovo ABL; целью остаётся полноценный Linux 6.12. Подробности находятся в
[LINUX612_KEXEC.md](LINUX612_KEXEC.md).

Диагностический r64 recovery полностью offline-аудирован (`AUDIT_RESULT=PASS`, SHA-256
`45d69af926a67582f5f5447c5b063cfeabf07660261efef04003763c5acbe224`),
запущен на железе и дал положительный результат: Linux 6.12 через kexec дошёл
до PSCI checkpoint после `paging_init()`. r64 не является текущим recovery:
guarded controller восстановил V56.5 r2 после теста.

## Историческая контрольная база (не текущая цель)

- Устройство: Lenovo TB371FC, Qualcomm SM8250, Adreno 650.
- Проверенная линия: downstream/vendor Linux `4.19.157`.
- Последний подтверждённый пользовательский runtime: `4.19.157-perf-v56.5+`;
  по решению владельца больше не восстанавливать его между тестами 6.12.
- Проверенный неизменяемый recovery-откат: V56.3 r3.3.
- Persistent root: Arch Linux ARM на microSD.
- Desktop: KDE Plasma 6 Wayland, KWin 6.7.4, Qt 6.11.1.
- Работают: внутренняя панель, touch, магнитная клавиатура/тачпад, QCA6390
  Wi-Fi, SSH, Plasma Keyboard.
- Маркер успешного старта штатной V56-сессии:
  `/run/tb371fc-v56-kde-status`, ожидаемое содержимое `ready`.

Штатно KWin/Plasma используют software rendering (`llvmpipe`). Отдельные
приложения могут использовать Zink -> Vulkan Turnip -> Adreno 650 через KGSL.

## Первая обязательная проверка

Последний тест установил приоритетный launcher:

```text
/usr/local/bin/kwin_wayland
```

Он мог направлять Plasma на экспериментальный KWin:

```text
/opt/tb371fc-kwin-renderloopfix
```

и задавать `KWIN_DRM_RENDERLOOP_REFRESH_RATE_MHZ=60000`. После перезагрузки
получен тёмный экран, а SSH принимал TCP-соединение, но не выдавал shell.

При первом доступе проверить без перезапуска KWin:

```sh
readlink -f /usr/local/bin/kwin_wayland 2>/dev/null || true
sed -n '1,160p' /usr/local/bin/kwin_wayland 2>/dev/null || true
ps -ef | grep -E '[k]win_wayland|[p]lasmashell'
journalctl -b --no-pager -u display-manager -n 300
```

Если launcher существует и активирует `tb371fc-kwin-renderloopfix`, вернуть
штатный `/usr/bin/kwin_wayland`:

```sh
mkdir -p /var/backups/tb371fc
cp -a /usr/local/bin/kwin_wayland \
  /var/backups/tb371fc/kwin_wayland.renderloopfix.disabled 2>/dev/null || true
rm -f /usr/local/bin/kwin_wayland
hash -r
command -v kwin_wayland
```

Ожидаемый результат последней команды: `/usr/bin/kwin_wayland`. Если менялся
KScreen, имеется предполагаемый backup:

```text
/var/backups/tb371fc/kwinoutputconfig.pre-renderloopfix.json
```

Восстанавливать его только после сравнения с текущим файлом. Затем выполнить
обычную полную перезагрузку; не использовать live `kwin_wayland --replace`.

## Почему нельзя делать live replace

На vendor 4.19 выход старого KWin может зависнуть в D-state в пути:

```text
kfree -> sde_crtc_destroy_state -> drm_atomic_state_default_clear
-> msm_atomic_state_clear -> __drm_atomic_state_free
-> sde_kms_lastclose -> msm_lastclose -> drm_lastclose
-> drm_release -> msm_release -> __fput -> do_exit
```

Это downstream DRM lastclose bug. Поэтому смену KWin проверять только через
полный reboot с заранее подготовленным rollback.

## Что не считать текущим релизом

- V56.7 refresh metadata — физически давал розово-фиолетовый шум.
- V56.8 native-clock — regression/bisect image, успех не подтверждён.
- Экспериментальный `kwin-refreshfix` показывал логические 120/60/30, но
  реальный modeset давал шум.
- Экспериментальный `kwin-renderloopfix` оставлял DRM mode 52.539 Гц, но после
  reboot дал тёмный экран.

Первым делом восстановить штатный KWin и записать новый baseline-log, а уже
после этого продолжать графические тесты.

## Актуальный Linux 6.12 прорыв: нулевой RAM в kexec DTB (2026-08-29)

Прежнее заключение r78-r82 о PAC/эпилоге отменено точной проверкой control
flow. r80 убрал исходный `cbz x0`, поэтому доказывал только возврат из
`memblock_alloc_try_nid()`, но не ненулевой результат. Исправленный r83
сохранил `cbz` и поставил reset только на success-path; на железе reset не
произошёл. Значит allocator вернул NULL и вошёл в panic.

Из recovery извлечён именно загружаемый `board.dtb` (SHA-256
`aacb6fbcaf9422912ca766facd9242c39c64def09c39b0c729662da0e785ffb7`).
В нём `/memory@80000000/reg = <0 0x80000000 0 0>` — размер RAM равен нулю.
При cold boot это должен исправлять ABL; при kexec статический DTB передаётся
без ABL fixup. Это полностью объясняет NULL после успешного прохождения ранней
`paging_init()` с отдельным r64 page-table pool.

r84 уже собран и offline-аудирован: он сохраняет точный r83 checkpoint Image и
заменяет только memory `reg` на 19 реальных диапазонов System RAM от V56.6.
Recovery SHA-256:
`22d957cd297b8779fd8b91a87e794a75c5c705b206078eaf02d55f68cab972f5`,
`AUDIT_RESULT=PASS`. Следующий аппаратный PASS — автоматический reset. После
него нужен r85: тот же исправленный DTB плюс layout-preserving full-boot Image
r70 без allocator checkpoint.
