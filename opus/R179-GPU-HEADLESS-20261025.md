# R179 (тест): Adreno 650 в Linux 6.12 без драйвера дисплея (2026-10-25)

## Что сделано
- Ядро: `mainline-port/patches/0003-drm-msm-adreno-tb371fc-headless-gpu.patch` — GPU с флагом DT
  `tb371fc,headless-gpu` регистрируется отдельно (как imageon), а `msm_use_mmu()` считает MMU
  доступным (у Adreno свой SMMU) — иначе «failed to allocate VRAM» (-12, нет CMA под 16 МБ).
- DT (тест, board-gpu.dtb 9c82b4bf): MDSS `display-subsystem@ae00000` disabled (он и так не
  стартует, -110), у GPU флаг headless.
- Прошивки: в системе были a650_sqe.fw v93 («SQE ucode is too old, need 95»); поставлены
  свежие из linux-firmware (sqe c863ceac, gmu df79fa84), старые сохранены как *.orig-93.
- Результат: /dev/dri/renderD128 (msm), Mesa: **OpenGL ES 3.2 / OpenGL 4.6, FD650**.
- KWin заставили рисовать на GPU (KWIN_DRM_DEVICES = msm-card:simpledrm, без KWIN_COMPOSE=Q):
  supportInformation «OpenGL, FD650», но на экране чёрный фон и шлейф курсора — кадр с GPU не
  попадает в simpledrm (multi-GPU копирование; «Pageflip timed out» от simpledrm). Возвращено
  QPainter. KDE привязан к simpledrm по пути /dev/dri/by-path/platform-9c000000.framebuffer-card.
- Ловушки: перепривязка msm при открытом KWin → oops в msm_postclose (KWin умер); `pkill -f`
  с шаблоном kwin убил собственную SSH-сессию; старый kwin_wayland_wrapper переживает stop.

## Вывод
GPU рабочий, но ускорение рабочего стола и 120 Гц требуют родного драйвера дисплея (DPU + два
DSI + DSC + NT36532) — кандидат для 7.1.8 (r6, max_linewidth 1880, parallel SSPP) не проверен на
железе; его нужно перенести на 6.12 или перейти на 7.x. R179 не прошивался (без вывода на экран
выгоды нет). Ядро smith-dog/kernel-tb371fc (v1.2–v2.1) — Android vendor 4.19 + KernelSU,
полезно лишь как справка (зарядка, 144 Гц).
