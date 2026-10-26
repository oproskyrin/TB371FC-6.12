# Рабочий цикл для Opus

## 1. Перед изменением

```powershell
Set-Location <repo>
git status --short
fastboot.exe devices
```

Если планшет в Linux — сначала подключиться по SSH и сохранить baseline из
[CONNECTION.md](CONNECTION.md). Если тёмный экран — не считать систему
зависшей, пока не проверены DHCP/ARP, порт 2222, USB gadget и fastboot.

## 2. Один тест — одна гипотеза

Нельзя одновременно менять kernel clock metadata, KWin RenderLoop, Mesa и
KScreen. На каждый тест формулировать:

- один предполагаемый механизм;
- минимальный patch;
- наблюдаемый признак успеха/неуспеха;
- timeout;
- точный rollback.

Сначала read-only диагностика. Изменения userspace — через отдельный prefix
в `/opt/tb371fc-*`, а не заменой системных библиотек. Wrapper/launcher должен
удаляться одной командой.

## 3. Сборка в WSL

```powershell
wsl.exe -d Ubuntu-24.04 -- bash -lc `
  "cd <repo> && git status --short"
```

Использовать существующие scripts и release dirs; не перепечатывать длинные
команды вручную. Результаты складывать в новый именованный каталог под
`D:\TB371FC-builds`, а небольшие manifests/logs — в `diagnostics/`.

Для каждого артефакта:

```powershell
Get-FileHash -Algorithm SHA256 -LiteralPath 'D:\TB371FC-builds\...\image'
Get-Item -LiteralPath 'D:\TB371FC-builds\...\image' | Select FullName,Length
```

Kernel/recovery до hardware launch проверять offline: architecture, Image
header, DTB/DTBO, recovery size 100 MiB, AVB footer и component hashes.

## 4. Hardware test

1. Владелец переводит планшет в fastboot.
2. Проверить serial/slot/unlocked/sizes.
3. Запустить guarded controller сначала с `ValidateOnly`, затем `Preflight`.
4. Только после проверки rollback запустить allowlisted recovery.
5. Не уходить от устройства до появления Linux USB/SSH либо fastboot timeout.
6. Скопировать логи сразу после появления доступа.

Не выполнять широкие destructive actions. Разрешённый boot-chain scope —
только `recovery_b` и `vbmeta_b`, в соответствии с существующим контроллером.

## 5. Логи одного теста

Создавать каталог:

```text
diagnostics/YYYYMMDD-short-test-name/
```

Минимальный состав:

```text
README.md                 гипотеза, patch, команды, physical result
SHA256SUMS                точные hashes
fastboot-preflight.txt
uname.txt
cmdline.txt
dmesg.txt
journal-boot.txt
kwin-environment.txt
drm-sysfs.txt
processes.txt
```

В `README.md` явно писать `SUCCESS`, `FAILED`, `INCONCLUSIVE` или
`NOT HARDWARE TESTED`. Не использовать слово release для непроверенного build.

## 6. Graphics-specific ограничения

- Не делать `kwin_wayland --replace` на vendor 4.19.
- Не менять физический DRM mode только ради исправления KWin frame pacing.
- Не включать полный KWin Zink/Turnip как default до отдельного cold-boot test.
- Не заменять system Mesa; использовать `/opt/tb371fc-mesa-zink-patched`.
- Перед reboot проверять, какой `/usr/local/bin/kwin_wayland` будет выбран.
- При шуме/чёрном экране не продолжать blind writes; фиксировать фото, время и
  доступность SSH/USB/fastboot.

## 7. После теста

- Восстановить baseline.
- Повторно загрузить его и подтвердить KDE/SSH.
- Обновить `CURRENT_STATE.md` или основной diagnostic result.
- Не удалять failed artifact до сохранения SHA и причины неуспеха; затем можно
  пометить каталог `.failed-*`, как уже сделано для части V56.7/V56.8.

