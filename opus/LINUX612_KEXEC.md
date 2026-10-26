# Linux 6.12: состояние kexec-перехода

Срез: 2026-08-29. Этот документ относится только к загрузке Linux 6.12 через
`kexec` из V56.6/Linux 4.19. Графические эксперименты 4.19 описаны отдельно в
[GRAPHICS.md](GRAPHICS.md).

## Что уже доказано

- Один и тот же Image Linux 6.12.30 и DTB успешно проходят раннюю загрузку
  при холодном запуске через ABL (r48).
- Через `kexec` из V56.6 тот же Image доходит до `paging_init()` и зависает в
  первом вызове `__map_memblock()` внутри `map_mem()`.
- Поэтому перенос ядра, EL2/EL1-переход, разбор DTB и большая часть
  `setup_arch()` исправны. Ошибка специфична для живого handoff от 4.19.
- `flush_tlb_all()` перед `map_mem()` (r49) не помог.
- Исключение известных PIL/reserved-memory областей не помогло; r62 показал,
  что первый адрес вообще не принадлежит прежнему списку кандидатов.
- QCA6390/WLAN действительно оставался `ONLINE`; явный `cnss2` unbind перед
  `kexec -e` корректен и сохранён, но одного его недостаточно.

## Live-срез планшета 2026-08-29

Подключение выполнено через USB ACM `COM9` и локальный serial-SSH bridge на
`127.0.0.1:22364`. Никакой образ не прошивался, `kexec` не загружался и
планшет не перезагружался.

```text
Linux tb371fc-arch-dev 4.19.157-perf-v56.6+
/sys/kernel/kexec_loaded = 0
/proc/kcore отсутствует (CONFIG_PROC_KCORE=n)
MemTotal = 7861524 kB
MemAvailable ~= 7.4 GiB
```

Ключевая карта памяти:

```text
80600000-806fffff : System RAM
80894000-808fffff : System RAM
85e00000-861fffff : System RAM
...
ffc20000-1ffffffff : System RAM
200000000-27fffffff : дополнительные System RAM диапазоны с разрывами
```

Это подтверждает адрес r63: первый диапазон, который пытается отобразить
6.12, начинается с `0x80600000`.

Дополнительный факт: `/proc/kpageflags` для всех 256 страниц диапазона
`0x80600000-0x806fffff` в исходящем 4.19 содержит `0x80` (`KPF_SLAB`), а
`/proc/kpagecount` равен нулю. То есть новый ранний allocator 6.12 начинает
строить постоянные таблицы страниц поверх памяти, которая непосредственно до
прыжка содержит slab-объекты старого ядра. Само по себе это допустимо после
идеального shutdown, но опасно при продолжающемся DMA.

Оба Qualcomm SMMU в live-логе сообщают `non-coherent table walk`. Вместе с
уже доказанным неполным shutdown WLAN это делает повреждение новых page table
страниц старым DMA более сильной гипотезой, чем конфликт с самим физическим
диапазоном: `__map_memblock()` записывает таблицы, но не читает содержимое
отображаемой RAM.

## Отличия поколений

```text
V56.6 / Linux 4.19:  4 KiB pages, VA_BITS=39, PGTABLE_LEVELS=3, KASLR=y
Linux 6.12 payload:  4 KiB pages, VA_BITS=48, PGTABLE_LEVELS=4, KASLR=n
```

Разный размер VA сам по себе поддерживается архитектурой, но исходящий 4.19
использует старую arm64 kexec-схему: MMU выключается до физического relocation.
Upstream в 2021 году полностью переработал этот путь, добавив отдельную копию
linear map и relocation с включённым MMU. Полный backport этой серии в vendor
4.19 возможен, но значительно рискованнее одного изолированного теста.

## Аппаратно подтверждённый тест: r64

r64 не исключает очередной адрес RAM. Он заменяет только источник ранних
page-table страниц:

- `early_pgtable_alloc()` получает страницы из отдельного выровненного пула
  1 MiB внутри BSS/Image входящего 6.12;
- пул входит в переносимый Image и уже зарезервирован как часть ядра;
- эти страницы не берутся из обычной RAM, где только что находились slab и
  DMA-буферы 4.19;
- после успешного возврата из `paging_init()` выполняется PSCI `SYSTEM_RESET`.

Ожидаемая интерпретация была однозначна:

- автоматический warm reset обратно в V56.6 — гипотеза подтверждена и найден
  рабочий путь мимо раннего повреждения таблиц;
- зависание с диагностическим кадром — гипотеза опровергнута, следующий билд
  должен ставить checkpoints внутрь `alloc_init_p4d/pud/pmd`, а не менять
  адреса памяти.

Скрипты:

```text
scripts/build-linux-6.12-r64-embedded-pgtable-pool.sh
scripts/build-v56-6-controlled-linux-6.12-r64-transport-r2.sh
scripts/audit-r64-transport-r2.sh
```

Сборка и offline-аудит завершены 2026-08-29:

```text
D:\TB371FC-builds\linux-6.12.30-tb371fc-v56.6-controlled-kexec-r64-transport-r2\tb371fc-v56.6-controlled-linux-6.12-r64-transport-r2-recovery.img
size    = 104857600 bytes
sha256  = 45d69af926a67582f5f5447c5b063cfeabf07660261efef04003763c5acbe224
audit   = AUDIT_RESULT=PASS
```

Аудит подтвердил boot header, AVB footer, recovery kernel, ramdisk и DTB
побайтно.

## Результат r64 на железе

Тест выполнен 2026-08-29 через guarded controller, только на `recovery_b` и
`vbmeta_b`. До исполнения:

```text
first stage     = 4.19.157-perf-v56.6+
uptime          ~= 1287 s
kexec_loaded    = 1
CPU online      = 0-7
watchdog gate   = 0
WLAN subsystem  = ONLINE
```

SSH-соединение оборвалось непосредственно на `kexec -e`. Затем планшет
**самостоятельно перезагрузился** и снова поднял V56.6:

```text
kernel          = 4.19.157-perf-v56.6+
new uptime      = 126.92 s
kexec_loaded    = 0
loader state    = not-loaded
```

Это именно положительный сигнал r64: checkpoint после `paging_init()` вызвал
PSCI `SYSTEM_RESET`. Следовательно, выделенный 1 MiB pool устранил прежнее
зависание в первом `__map_memblock()`, и Linux 6.12 впервые через kexec прошёл
полную `paging_init()`. Гипотеза повреждения ранних таблиц страниц старым
slab/DMA состоянием подтверждена аппаратно.

После сбора доказательств guarded controller восстановил проверенный V56.5 r2
recovery и совместимый test vbmeta. Контрольный runtime после отката:

```text
kernel       = 4.19.157-perf-v56.5+
uptime       = 54.57 s
kexec_loaded = 0
```

Следующий рациональный билд должен сохранить r64 page-table pool и перенести
единственный PSCI checkpoint дальше — после возврата из `setup_arch()`. Если
он сработает, следующий билд уже должен убрать checkpoint и продолжить полную
загрузку диагностического userspace 6.12. Возвращаться к перебору физических
адресов или убирать pool нельзя.

## Уточнённая причина r86/r92: ёмкость пула при `rodata_full`

Последующие r87-r92 показали, что отдельный pool устраняет stale DMA/slab
повреждение, но его 256 страниц недостаточно для полной карты памяти при
текущей политике ARM64. Точный config содержит 4 KiB pages, 48-bit VA и
`CONFIG_RODATA_FULL_DEFAULT_ENABLED=y`. Точный исходник 6.12 при
`rodata_full` запрещает block/contiguous mappings linear map.

Расчёт:

```text
1 PTE-table page maps 2 MiB RAM
r92 2 GiB group:       >= 1024 PTE pages
full 0x1cacf9000 RAM:  >= 3679 PTE pages + upper levels
embedded r64 pool:        256 pages
minimum full-map deficit: 3423 pages
```

Поэтому r91 PASS и r92 FAIL не требуют поиска «плохой» RAM-банки. Рабочий
bring-up путь — сохранить embedded pool и передать `rodata=on`: защита
read-only секций ядра остаётся, а linear map снова может использовать block
mappings. Позднее, если нужен именно page-granular `rodata_full`, пул можно
увеличить минимум до 4096 страниц (16 MiB), но для первой полной загрузки это
лишний риск и расход Image/BSS.

## Аппаратное подтверждение r95

r95 оставил точный r64 checkpoint сразу после `paging_init()`, вернул полный
r84 DTB и добавил только `rodata=on`. В атомарном load+execute-сеансе helper
подтвердил `kexec_loaded=1`; через 8,5 секунды соединение оборвалось и планшет
автоматически перезапустился. Свежий recovery показал:

```text
uptime        = 42.91 s
kexec_loaded  = 0
loader state  = not-loaded
Image SHA     = f94392343bc245c572895628c894a720f924a42a30c10f22ab4983ef8bd531b6
DTB SHA       = c954a4d36e5bf25c2884bc83293222fd866697556c2fa2fc9f67dbcd85fbfcae
```

Это окончательный PASS полной карты RAM через `paging_init()`. r96 может
безопасно убрать checkpoint и продолжить штатную загрузку initramfs 6.12.
