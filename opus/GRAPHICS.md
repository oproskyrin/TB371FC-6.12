# Графика: архитектура, результаты и следующий план

## Аппаратная архитектура

На vendor Linux 4.19 графическая система разделена:

```text
display/scanout: downstream Qualcomm SDE DRM
  /dev/dri/card0
  /dev/dri/renderD128

3D rendering: vendor KGSL
  /dev/kgsl-3d0
  Adreno 650
```

Turnip видит Adreno через KGSL, но Vulkan physical device не имеет нормального
DRM render-node соответствия SDE. Поэтому обычный Zink раньше завершался с
`failed to choose pdev`.

Mesa 26.1.7 была изолированно пропатчена:

```text
/opt/tb371fc-mesa-zink-patched
TB371FC_ZINK_KGSL_ALLOW_UNMATCHED=1
```

Patch:
[../patches/mesa-26.1.7-zink-kgsl-unmatched-device.patch](../patches/mesa-26.1.7-zink-kgsl-unmatched-device.patch).

Он выбирает единственный non-CPU Vulkan device только после провала обычного
DRM match. Системная Mesa не заменялась.

## Что доказано

- Vulkan Turnip работает на Adreno 650 через KGSL.
- GBM EGL через Zink создаёт OpenGL 4.6 / GLES 3.2 контекст.
- Исторически вывод через downstream SDE проверялся с
  `MESA_VK_WSI_DEBUG=sw`. Актуальный Turnip в
  `/opt/tb371fc-gpu-turnip-wayland` уже принудительно использует `wl_shm`;
  wrapper `/usr/local/bin/tb371fc-hw-run` поэтому намеренно снимает эту
  переменную. Не смешивать эти два варианта в одном тесте.
- Offscreen `glmark2-es2-wayland` прошёл, score 1118.
- Изолированное ускорение приложений запускается через:
  `/usr/local/bin/tb371fc-hw-run`.
- Chromium безопаснее оставлять software; его Wayland Vulkan path в текущем
  package не является рабочим compositor solution.
- Полное включение Zink/Turnip для KWin на 4.19 ранее приводило к отключению
  DSI и D-state. Это не безопасный default.

## Журнал проверки 2026-08-27

### Что исключено

1. Наблюдавшиеся в обычном `htop` интервалы около 1.5-3 секунд не были
   задержкой физического дисплея. Запущенный как `htop -d 1` процесс обновлял
   секунды без видимой задержки. Значение `-d` задаётся в десятых долях
   секунды; штатное обновление `htop` значительно реже кадров дисплея.
2. `OverlayVirtualKeyboardOnWindows=true` успешно применён в живом KWin.
   Клавиатура стала накладываться на окно и перестала требовать изменения его
   рабочей области, но визуальное чередование кадров сохранилось. Значит
   resize-loop активного окна не является единственной причиной.
3. KWin QPainter снизил нагрузку относительно полного llvmpipe OpenGL, но не
   устранил дрожание клавиатуры/launcher.
4. OpenGL KWin с `KWIN_USE_BUFFER_AGE=0` действительно запустился, однако
   полная программная перерисовка подняла нагрузку `kwin_wayland` примерно до
   138% CPU и не устранила симптом. Этот режим отклонён.
5. QPainter с `KWIN_DRM_DISABLE_TRIPLE_BUFFERING=1` действительно запустился,
   держал KWin примерно на 5% CPU, но не устранил симптом. Ошибка не сводится
   только к нескольким pending DRM frames.
6. Не повторять `KWIN_DRM_RENDERLOOP_REFRESH_RATE_MHZ=60000`, изменение
   сохранённого режима KScreen на 52539/60000 или kernel mode-clock patches:
   эти варианты уже приводили к тёмному экрану, зависанию либо шуму панели.

### Новая положительная контрольная точка

На загруженной V56.5 повторно подтверждены все ступени аппаратного стека:

```text
/dev/kgsl-3d0: Adreno650v3
Vulkan: Turnip Adreno (TM) 650, Mesa 26.1.7
surfaceless EGL: OpenGL 4.6 / GLES 3.2 через Zink
GBM EGL: OpenGL 4.6 / GLES 3.2 через Zink
Wayland window: glmark2-wayland --validate, rc=0
renderer: zink Vulkan 1.3(Turnip Adreno (TM) 650 (MESA_TURNIP))
```

Критические переменные для актуального оконного теста задаёт только wrapper:

```text
/usr/local/bin/tb371fc-hw-run
TB371FC_ZINK_KGSL_ALLOW_UNMATCHED=1
MESA_LOADER_DRIVER_OVERRIDE=zink
GALLIUM_DRIVER=zink
VK_ICD_FILENAMES=/opt/tb371fc-gpu-turnip-wayland/share/vulkan/icd.d/freedreno_icd.aarch64.json
```

Прямая сборка окружения с обычным packaged ICD или без wrapper давала
`EGL_NOT_INITIALIZED: DRI2: failed to setup EGLDevice`. Это не опровергает
рабочий аппаратный путь: проектный Turnip содержит отдельную доработку
Wayland `wl_shm`, и проверенный wrapper выбирает именно её.

### Текущая рабочая гипотеза

Физический scanout работает, аппаратный рендер приложений работает, а
дрожание воспроизводится в Qt Quick поверх software KWin. Следующий наименее
рискованный шаг — не переводить KWin на KGSL, а повторно запустить только
`plasmashell` и `plasma-keyboard` через уже проверенный
`tb371fc-hw-run`, по одному процессу, с автоматическим откатом. Так можно
снять CPU-render bottleneck у launcher/keyboard, не отдавая Turnip владение
DSI/DRM compositor.

### Подготовленный следующий тест

Подготовлено ускорение только виртуальной клавиатуры:

```text
/usr/local/bin/tb371fc-plasma-keyboard-turnip
/root/.local/share/applications/org.kde.plasma.keyboard.turnip.desktop
[Wayland]
InputMethod=/root/.local/share/applications/org.kde.plasma.keyboard.turnip.desktop
```

Исходный конфиг и откат:

```text
/var/backups/tb371fc/20260827-accelerated-keyboard/kwinrc.before
/var/backups/tb371fc/20260827-accelerated-keyboard/rollback.sh
```

KWin не заменялся и не перезапускался live. Его KConfigWatcher не применил
новую команду к уже работающему InputMethod, поэтому текущий PID клавиатуры
оставался software (`LIBGL_ALWAYS_SOFTWARE=1`, без `/dev/kgsl-3d0`). Реальный
тест начнётся только после следующей обычной загрузки KDE. Wrapper запускает
клавиатуру через проверенный `tb371fc-hw-run`; если аппаратный процесс
завершится, wrapper запускает `/usr/bin/plasma-keyboard` с software-профилем.

После загрузки тест считается начавшимся только если у нового
`plasma-keyboard` одновременно присутствуют:

```text
TB371FC_ZINK_KGSL_ALLOW_UNMATCHED=1
MESA_LOADER_DRIVER_OVERRIDE=zink
GALLIUM_DRIVER=zink
открытый FD /dev/kgsl-3d0
```

До этой проверки нельзя делать вывод по внешнему виду клавиатуры.

Подробности:

- [../diagnostics/v56-5-hybrid-gpu-wsi-result-20260818.md](../diagnostics/v56-5-hybrid-gpu-wsi-result-20260818.md)
- [../diagnostics/v56-5-zink-pdev-fix-20260823.md](../diagnostics/v56-5-zink-pdev-fix-20260823.md)
- [../diagnostics/v56-5-kwin-turnip-reboot-test-plan-20260818.md](../diagnostics/v56-5-kwin-turnip-reboot-test-plan-20260818.md)

## Штатный стабильный compositor

Рабочая конфигурация:

```text
KWin 6.7.4 / Plasma Wayland
KWIN_DRM_DEVICES=/dev/dri/card0
KWIN_DRM_NO_DIRECT_SCANOUT=1
LIBGL_ALWAYS_SOFTWARE=1
OpenGL renderer: llvmpipe (Mesa 26.1.7)
output: DSI-1, 2944x1840, scale 1.85
reported/computed refresh: около 52.539 Hz
```

При статичной панели изображение стабильно. При анимации launcher или вводе
на экранной клавиатуре пользователь видит дрожание. Нагрузка CPU возрастает,
но это само по себе не доказывает, что причина только в software rendering.

## Refresh-rate mismatch

Панель объявляет логические режимы:

```text
2944x1840x120x375888vid
2944x1840x60x375888vid
2944x1840x30x375888vid
```

Все используют transport clock `375888`. Downstream mode timing приводит KWin
к расчёту примерно 52.539/26.27/13.14 Гц, тогда как поле `vrefresh` несёт
логические 120/60/30. Панель dual-DSI + DSC; обычное изменение pixel clock как
у стандартного HDMI режима здесь неверно.

### Уже проверенные направления

1. Kernel V56.7 с
   `vendor-kernel/patches/0028-msm-dsi-export-logical-refresh-clock.patch`:
   первый atomic commit давал розово-фиолетовый шум.
2. KWin patch, доверяющий mode `vrefresh`: KScreen увидел 120/60/30 и выбрал
   60.00, но modeset дал шум. После rollback штатный 52.539 вернулся.
3. KWin RenderLoop-only override через
   `KWIN_DRM_RENDERLOOP_REFRESH_RATE_MHZ=60000`, без изменения DRM mode:
   после reboot получен тёмный экран. Перед новыми тестами убрать launcher,
   описанный в `CURRENT_STATE.md`.
4. Live replacement KWin небезопасен из-за downstream SDE lastclose D-state.

Архивы/логи:

- [../diagnostics/v56-7-kwin-sync-live-20260824.txt](../diagnostics/v56-7-kwin-sync-live-20260824.txt)
- [../diagnostics/v56-8-native-clock-regression-bisect-20260824.md](../diagnostics/v56-8-native-clock-regression-bisect-20260824.md)
- [../diagnostics/v56.7-qpainter-noise-20260824/qpainter-noise-and-restore.log](../diagnostics/v56.7-qpainter-noise-20260824/qpainter-noise-and-restore.log)
- `tmp/kwin-v6.7.4/`

## Рациональный следующий план

### Фаза 0: вернуть baseline

Убрать тестовый KWin launcher, загрузить stock KWin, получить чистые
`journalctl`, `dmesg`, process environment и 30-60 секунд видео дрожания.

### Фаза 1: измерять, не modeset-ить

Не менять DRM mode. Сопоставить во времени:

- `kwin_wayland` frame/render timings;
- DRM vblank sequence/timestamps;
- CPU frequency/load и missed frames;
- animation activity launcher/keyboard;
- KWin software backend и buffer age/damage behavior.

Проверить, поддерживает ли downstream driver usable `drmWaitVBlank`; в логах
уже отмечено отсутствие driver support для точного vblank timestamp query.
Главная гипотеза — неверный presentation clock/frame pacing, а не физическая
частота панели сама по себе.

### Фаза 2: минимальный userspace probe

Сделать отдельный маленький DRM/Wayland timing probe либо instrumented KWin,
который только логирует реальные интервалы pageflip/vblank и RenderLoop, не
меняет mode и не заменяет compositor live. Затем один reboot-test.

### Фаза 3: безопасное прикладное ускорение

Сохранить KWin на llvmpipe, а тяжёлые приложения запускать через
`tb371fc-hw-run`. Это уже доказанный гибридный вариант и не требует сводить
SDE/KGSL в один DRM device.

### Фаза 4: полноценный compositor GPU

Основной архитектурно правильный путь — Linux 6.12+ с единым DRM_MSM/Freedreno
и нормальным render node. Текущая ветка 6.12 пока не проходит надёжный boot
handoff; не смешивать её boot-debug с refresh experiments 4.19 в одном тесте.

## 2026-08-27: изолированный Turnip-тест экранной клавиатуры

После холодной загрузки подтверждено, что отдельный `plasma-keyboard`
действительно запускается через аппаратную цепочку, а не через fallback:

```text
MESA_LOADER_DRIVER_OVERRIDE=zink
GALLIUM_DRIVER=zink
VK_ICD_FILENAMES=/opt/tb371fc-gpu-turnip-wayland/share/vulkan/icd.d/freedreno_icd.aarch64.json
TB371FC_ZINK_KGSL_ALLOW_UNMATCHED=1
FD: /dev/kgsl-3d0
FD: /dev/dri/renderD128
```

DSI оставался `enabled`, wrapper не записал ошибку или fallback, а в `dmesg`
не появилось новых KGSL/IOMMU/GPU fault. Сама клавиатура потребляла около
0-3% CPU. Однако KWin оставался на `LIBGL_ALWAYS_SOFTWARE=1` и при обработке
аппаратно отрисованной поверхности клавиатуры постоянно занимал примерно
740-755% CPU по восьми последовательным мгновенным замерам `top`. Load average
поднялся примерно до 9.5. Дрожание пользовательского интерфейса этим способом
не устраняется: узкое место находится в программной композиции/копировании
поверхности KWin, а не в отрисовке самих клавиш.

Вывод: не повторять вариант «KWin llvmpipe + отдельная Turnip-клавиатура» как
кандидат релиза. Он технически доказывает работоспособность Wayland WSI
Zink/Turnip, но непригоден для рабочего стола из-за полной загрузки CPU.

Тест был откачен восстановлением:

```text
/var/backups/tb371fc/20260827-accelerated-keyboard/kwinrc.before
SHA-256: d1d233be4dc516753542505c07d948d2932cd8963ccee094f50b9817a75533f2
InputMethod=/usr/share/applications/org.kde.plasma.keyboard.desktop
```

Текущая сессия продолжает старый процесс до перезагрузки; после следующей
обычной загрузки должен вернуться штатный baseline. Wrapper и desktop-файл
оставлены на диске только как воспроизводимый диагностический артефакт и больше
не выбраны в `kwinrc`.

### Проверка rollback после reboot

После перезагрузки BusyBox 2026-08-28 планшет получил SSH-адрес
`192.168.1.143:2222`. Проверено:

```text
InputMethod=/usr/share/applications/org.kde.plasma.keyboard.desktop
plasma-keyboard environment: LIBGL_ALWAYS_SOFTWARE=1
tb371fc-plasma-keyboard-turnip: не запущен
DSI-1: enabled
GPU/IOMMU/SMMU/DSI/SDE fault: не обнаружены
```

В пяти последовательных секундных замерах в покое `kwin_wayland` и
`plasma-keyboard` показывали 0% CPU. Это подтверждает возврат к baseline и
причинную связь нагрузки 740-755% именно с гибридным Turnip-тестом.

## 2026-08-28: измерение frame pacing

Read-only `DRM_IOCTL_WAIT_VBLANK` probe доказал, что физический scanout панели
стабилен и работает на 120 Гц:

```text
299 полных интервалов
average 8333.57 us
median 8325 us
p95 8495 us
sequence увеличивается на 1
```

Одновременно KWin продолжает считать refresh равным `52539 mHz`. Wayland
presentation probe показал:

```text
feedback mode: median p2p 25.004 ms, median c2p 66 ms
low-latency mode: median p2p 41.663 ms, median c2p 41 ms
presentation MSC/sequence: 0
```

То есть панель/DSI не являются источником трёхсекундной задержки или дрожания.
Проблема локализована в KWin RenderLoop/DRM commit pacing: кадры идут примерно
40 FPS или 24 FPS поверх физического 120 Hz scanout. В low-latency тесте KWin
обычно потреблял лишь 52.9-54.9% одного CPU, поэтому это не CPU saturation.

Сырые данные и статистика:

- [../diagnostics/v56-5-frame-pacing-baseline-20260828/README.md](../diagnostics/v56-5-frame-pacing-baseline-20260828/README.md)
- [../diagnostics/drm-vblank-probe.c](../diagnostics/drm-vblank-probe.c)

Уточнение по старому `KWIN_DRM_RENDERLOOP_REFRESH_RATE_MHZ=60000`: архивный
snapshot подтверждает, что экспериментальный KWin был жив спустя 56 минут и
потреблял около 1.4% CPU в покое. Поэтому прежняя формулировка о доказанном
немедленном dark-screen regression слишком сильна. Повторять значение 60000
без нужды не следует, но причинная связь с тёмным экраном не доказана.

Следующий допустимый reboot-test: только RenderLoop/commit pacing `120000`,
со штатным DRM mode и неизменным KScreen, через launcher с автоматическим
удалением и заранее проверенным rollback.

### Результат one-shot pacing 120000

Тест выполнен без изменения DRM mode/KScreen/DSI clock. KWin запущен из
`/opt/tb371fc-kwin-renderloopfix` с единственным pacing override `120000`.

```text
p2p median: 8334 us (до исправления 25004 / 41663 us)
p2p p95: 8529 us
c2p median: 24 ms (до исправления 66 / 41 ms)
1170/1310 кадров: группа около 8 ms
KWin CPU: обычно 17-37% одного ядра
DSI: enabled
новые GPU/IOMMU/SDE/DSI fault: нет
```

Численно pacing исправлен: KWin presentation теперь практически совпадает с
физическим 120 Hz vblank. Launcher одноразовый и удаляет себя через 300 секунд;
текущая сессия продолжает тест до reboot, а следующий boot использует stock
KWin. До решения о релизе нужна визуальная проверка владельцем launcher и
экранной клавиатуры, затем минимум 15 минут стабильности.

Визуальная проверка владельцем: дрожание осталось без заметного изменения.
Следовательно, scheduler mismatch был реальным и исправленным дефектом, но не
единственной причиной видимых артефактов.

Покадровый просмотр `IMG_1916.mov` показал не простое мерцание, а
прямоугольные области из разных старых кадров: фрагменты клавиатуры, launcher
и обоев чередуются в одном scanout. Это указывает на stale swapchain
buffer/damage restoration или незавершённую синхронизацию, а не на fractional
scale. Следующий изолированный тест: сохранить pacing 120000 и добавить только
`KWIN_USE_BUFFER_AGE=0`, без `glFinish`, QPainter или изменения mode.

### Результат 120000 + полный repaint

One-shot тест с `KWIN_DRM_RENDERLOOP_REFRESH_RATE_MHZ=120000` и
`KWIN_USE_BUFFER_AGE=0` визуально не изменил дрожание launcher и экранной
клавиатуры. Обычная ошибка damage journal/buffer age сама по себе исключена.
Этот вариант не переносить в release.

### Проверка внутренней записи

Авторизованный вызов `org.kde.KWin.ScreenShot2` проходит проверку desktop-file,
но KWin отвечает `org.kde.KWin.ScreenShot2.Error.Cancelled`. Исходники KWin
6.7.4 показывают точную причину: screenshot plugin возвращает кадр только если
`Compositor::backend()` является `EglBackend`; текущий compositor таким не
является. В окружении KWin подтверждено `LIBGL_ALWAYS_SOFTWARE=1`. Это ещё одно
независимое доказательство, что KWin пока не работает через EGL/Mesa path.

`/dev/fb0` доступен как 2944x1840 BGRA, но содержит старую загрузочную консоль,
а не KDE. KDE находится на DRM plane 67/framebuffer 31. `ffmpeg kmsgrab` на
старом msm DRM 4.19 завершается `Failed to get framebuffer 31: Invalid
argument`. PipeWire daemon и GStreamer `pipewiresrc` отсутствуют. Поэтому
корректная внутренняя видеозапись этой сессии штатными средствами пока
недоступна. Для визуального анализа использовать внешнее `IMG_1916.mov`, а для
синхронизации — vblank/presentation/DRM logs.

Артефакты проверки находятся в
`diagnostics/kwin-internal-capture-20260828/`; `fb-test.png` специально
показывает, что legacy fb0 не является активным KDE scanout.

### One-shot DRM dumb-buffer CPU sync (подготовлен 2026-08-28)

Новый основной кандидат получен из характера артефактов в `IMG_1916.mov`:
анимированные прямоугольники периодически показывают содержимое старых кадров,
хотя статичная сцена стабилизируется. Текущий KWin работает через QPainter DRM
и постоянно отображает CPU-mapped dumb buffers. В штатном KWin 6.7.4 вокруг
CPU-записи в эти dma-buf отсутствовал `DMA_BUF_IOCTL_SYNC`.

На ядре планшета отдельный probe подтвердил поддержку обеих операций:

```text
DMA_BUF_SYNC_START | DMA_BUF_SYNC_WRITE: rc=0
DMA_BUF_SYNC_END   | DMA_BUF_SYNC_WRITE: rc=0
```

Собран отдельный KWin 6.7.4 в `/opt/tb371fc-kwin-dumbsync`. В
`DrmQPainterLayer` добавлены START перед рисованием и END перед импортом
framebuffer; изменение включается только через
`KWIN_DRM_DUMB_BUFFER_CPU_SYNC=1`. Патч успешно скомпилирован, установлен и
проверен по строке в `libkwin.so.6.7.4`.

Для следующей загрузки установлен одноразовый launcher
`/usr/local/bin/kwin_wayland`. Он не меняет refresh rate, DRM mode, KScreen,
renderer или Mesa и сам удаляется через 300 секунд. После следующей
перезагрузки автоматически снова используется `/usr/bin/kwin_wayland`.
Тестовая загрузка успешна: активные binary и library подтверждены через
`/proc/PID/maps`, ошибок `DMA_BUF_IOCTL_SYNC` и новых kernel graphics fault
нет. После 30 последовательных анимаций launcher KWin остался работоспособен,
пиковая нагрузка составила около 38% одного CPU. Повторный vblank probe дал
median `8333 us`, p95 `8495 us`, то есть физические 120 Гц стабильны.
One-shot launcher штатно удалился через 300 секунд. Визуальный результат
дрожания требует проверки владельцем у экрана; удалённая диагностика не может
достоверно подтвердить содержимое scanout.

Контроль через 15:19 непрерывной работы: KWin жив, idle CPU `0.5%`, RSS
`235492 KiB`, sync errors `0`; после старта KWin новых DRM/DSI/SDE/KGSL/IOMMU
сообщений нет. Тем самым технические критерии стабильности и rollback пройдены,
кроме визуального критерия отсутствия дрожания.

Архивы и сырые результаты:
`diagnostics/kwin-dumbsync-oneshot-20260828/`.

### Проверка GPU-стека и следующий комбинированный тест (2026-08-28)

Текущая KDE-сессия не является аппаратно ускоренной целиком. У активного
`plasmashell` подтверждены `QT_QUICK_BACKEND=software`,
`QSG_RHI_BACKEND=software` и `LIBGL_ALWAYS_SOFTWARE=1`. Причина найдена:
защитный файл `/etc/tb371fc/disable-turnip-plasmashell`, созданный после
предыдущих нестабильных тестов, отключает guarded Turnip wrapper, а rescue
startup явно запускает программный fallback. Удалять этот файл и переключать
рабочий стол без владельца нельзя.

При этом сам аппаратный userspace-стек исправен. Изолированный surfaceless
EGL-тест, не затрагивающий экран и KWin, успешно получил:

```text
EGL 1.5, vendor Mesa Project
OpenGL renderer: zink Vulkan 1.3(Turnip Adreno (TM) 650 (MESA_TURNIP))
OpenGL 4.6 Core/Compatibility, Mesa 26.1.7
OpenGL ES 3.2, Mesa 26.1.7
```

Следовательно, Turnip видит KGSL/Adreno 650, а Zink умеет создавать поверх
него OpenGL-контексты. Неисправность локализована не в базовой 3D-цепочке, а
в интеграции Plasma/KWin с выводом на downstream SDE DRM 4.19 и его
синхронизацией/планированием кадров.

Подготовлен, но не установлен,
`scripts/tb371fc-kwin-dumbsync-120hz-oneshot.sh`. Он объединяет два уже
отдельно проверенных изменения в одном KWin build:

- `DMA_BUF_IOCTL_SYNC` для CPU-mapped dumb buffers;
- RenderLoop/DRM commit pacing `120000`, соответствующий измеренному vblank.

KMS mode, DSI clock, KScreen, renderer и Mesa не меняются. Launcher удаляет
себя через 300 секунд; активировать только при владельце у экрана, затем
визуально проверить launcher и экранную клавиатуру.

## Acceptance criteria

Графический вариант можно назвать рабочим только если после холодной загрузки
и не менее 15 минут теста одновременно выполняются:

- нет шума, чёрного экрана, DSI reset и DRM/KGSL faults;
- launcher и экранная клавиатура не дрожат в движении;
- touch/input не теряются;
- KWin/Plasma остаются alive;
- SSH продолжает отвечать;
- rollback проверен отдельной загрузкой.
