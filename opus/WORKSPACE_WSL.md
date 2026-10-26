# Рабочая среда, WSL и расположение файлов

## Windows workspace

Основной проект:

```text
<repo>
```

В WSL этот же каталог доступен как:

```text
<repo>
```

В каталоге много незакоммиченных пользовательских наработок. Не выполнять
`git reset --hard`, `git clean`, массовое удаление или перезапись чужих
изменений. Перед правкой делать `git status --short` и менять только файлы,
относящиеся к конкретному тесту.

## WSL

Нужный дистрибутив — `Ubuntu-24.04` (WSL2). `docker-desktop` для сборок не
использовать. Всегда указывать дистрибутив явно:

```powershell
wsl.exe -l -v
wsl.exe -d Ubuntu-24.04 -- bash -lc 'uname -a; pwd'
wsl.exe -d Ubuntu-24.04
```

WSL — воспроизводимый build host: AArch64 cross compiler, kernel tools, dtc,
cpio, boot-image assembly, QEMU preflight. Сам планшет не является build host.

## Крупные файлы и сборки

Windows-выходы:

```text
D:\TB371FC-builds
```

В WSL:

```text
/mnt/d/TB371FC-builds
```

Проверенные и экспериментальные release trees в WSL:

```text
/root/tb371fc-desktop-v56-1-kde-wlan-safe-release
/root/tb371fc-desktop-v56-2-kde-wlan-fhandle-release
/root/tb371fc-desktop-v56-3-kexec-release
/root/tb371fc-desktop-v56-3-r3-release
/root/tb371fc-desktop-v56-4-kexec-drm-shutdown-release
/root/tb371fc-desktop-v56-5-kexec-cpu-hotplug-release
/root/tb371fc-desktop-v56-6-watchdog-kexec-release
/root/tb371fc-desktop-v56-7-refresh-metadata-release
/root/tb371fc-desktop-v56-8-native-clock-release
/root/tb371fc-v56-3-r3-3-kexec-failsafe-release
/root/tb371fc-v56-5-retained-stage-reader-release
```

Наличие каталога `release` не означает физический успех. Статусы V56.7 и
V56.8 приведены в [GRAPHICS.md](GRAPHICS.md).

Persistent Arch build/rootfs:

```text
/root/arch-tb371fc
/root/arch-tb371fc/tb371fc-arch-development-v2-12g.raw
```

Список и назначение пакетов среды описаны в
[../DEVELOPMENT_ENVIRONMENT.md](../DEVELOPMENT_ENVIRONMENT.md) и
[../PERSISTENT_DEVELOPMENT.md](../PERSISTENT_DEVELOPMENT.md).

## Ключевые каталоги репозитория

- `scripts/` — сборка, упаковка, guarded fastboot, диагностика.
- `vendor-kernel/` — downstream 4.19 patches/configuration.
- `patches/` — Mesa и прочие изолированные patches.
- `diagnostics/` — исходные результаты физических тестов; это первичный
  источник фактов.
- `artifacts/` — небольшие проверенные артефакты, manifests, stock backups и
  стабильный V56.3 r3.3 recovery.
- `tmp/kwin-v6.7.4/` — локальное дерево KWin 6.7.4 с последними
  экспериментами; не считать upstream-clean.
- `D:\TB371FC-builds` — крупные kernels/recoveries, не предназначенные для Git.

## Главные исходники и patches графики

```text
patches/mesa-26.1.7-zink-kgsl-unmatched-device.patch
vendor-kernel/patches/0028-msm-dsi-export-logical-refresh-clock.patch
scripts/build-v56-7-refresh-metadata-community-kernel.sh
scripts/package-v56-7-refresh-metadata-recovery.sh
scripts/build-v56-8-native-clock-community-kernel.sh
scripts/package-v56-8-native-clock-recovery.sh
tmp/kwin-v6.7.4/
tmp/kwin-v6.7.4-tb371fc-refreshfix.tar.gz
```

## Быстрый поиск перед работой

```powershell
Set-Location <repo>
git status --short
rg -n "V56\.5|V56\.7|refreshRate|KWIN_DRM|ZINK|Turnip|KGSL" `
  diagnostics scripts patches vendor-kernel tmp
```

В WSL путь с пробелом обязательно заключать в кавычки.

