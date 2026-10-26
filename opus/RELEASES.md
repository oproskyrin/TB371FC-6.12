# Релизы, образы и откат

## Release 1: проверенная рабочая база

Основной локальный стабильный комплект:

```text
<repo>\artifacts\arch-development-loader-v56-3-r3-3-community-simplefb-qca6390-kde-kexec-safe
```

Recovery:

```text
tb371fc-arch-development-loader-v56-3-r3-3-community-simplefb-qca6390-kde-kexec-safe-recovery.img
size: 104857600 bytes
SHA-256: 2f31f5e76702e2a5c6b72204ca98dc7c67fd88ef593b7fdf45da2b88a1f7db24
kernel: 4.19.157-perf-v56.3+
```

В комплекте также находятся `Image`, DTB, recovery DTBO, initramfs,
`wlan.ko`, kernel config, `SHA256SUMS` и unpack metadata. Этот комплект
физически загрузил persistent Arch, Wi-Fi, SSH и KDE со статусом `ready`.

Важно: hash V56.3 r3.3 подтверждён локально, но на дату этого handoff ещё не
внесён в allowlist guarded controller. Не обходить проверку. Для немедленного
защищённого развёртывания использовать allowlisted V56.3 r2 либо сначала
провести отдельный audit r3.3 и добавить hash осознанным изменением controller.

Исходное описание: [../WORKING_BASELINE_V56.md](../WORKING_BASELINE_V56.md) и
[../diagnostics/v56-3-r3-3-stable-kde-result-20260815.md](../diagnostics/v56-3-r3-3-stable-kde-result-20260815.md).

Ещё более неизменяемая база V56.3 r2:

```text
D:\TB371FC-builds\arch-development-loader-v56-3-r2-community-simplefb-qca6390-kde-kexec-safe\tb371fc-arch-development-loader-v56-3-r2-community-simplefb-qca6390-kde-kexec-safe-recovery.img
SHA-256: 39a088020bb69a8e44636603b1379160d89a6996aeb9e73605c2f602025ea666
```

## Текущая development-линия

V56.5 добавила kexec CPU-hotplug workaround и стала базой последних GPU/WSI
экспериментов. Проверенный recovery V56.5 r2:

```text
D:\TB371FC-builds\arch-development-loader-v56-5-r2-community-simplefb-qca6390-kde-kexec-cpu-hotplug-safe\tb371fc-arch-development-loader-v56-5-r2-community-simplefb-qca6390-kde-kexec-cpu-hotplug-safe-recovery.img
SHA-256: c08efccc1f94d0c3da9ce0689b668c4640cc27523e64c97e81bde767eef1ab3b
```

Наблюдавшийся живой desktop использовал `4.19.157-perf-v56.5+`, но его
пользовательское состояние на microSD менялось между экспериментами. Поэтому
recovery SHA и состояние persistent root нужно фиксировать отдельно.

## Неудачные/диагностические образы

- V56.7 refresh metadata: kernel patch менял экспортируемый refresh metadata;
  физически получен шум. Не релиз и не rollback target.
- V56.8 native clock: строгий regression image без patch 0028; физический
  успех не зафиксирован. Не релиз.
- Linux 6.12 direct/controlled recovery r5-r43: исследовательская серия
  загрузочного handoff. Ни один образ не заменяет V56 release 1.

## Подтверждённый диагностический этап Linux 6.12

- r64, SHA-256
  `45d69af926a67582f5f5447c5b063cfeabf07660261efef04003763c5acbe224`,
  прошёл аппаратный тест 2026-08-29: kexec-ядро завершило `paging_init()` и
  выполнило запланированный PSCI reset. Это не пользовательский релиз и не
  rollback target; после теста восстановлен V56.5 r2. Полный протокол:
  `diagnostics/20260829-linux612-r64-hardware/README.md`.

## Stock boot-chain backups

Точные backup-файлы:

```text
artifacts/device-backup/lun0-recovery_b.bin
SHA-256: 94649360140db672e861729927011984e9714459b4e19c9aab02b7ab79466668

artifacts/device-backup/lun4-vbmeta_b.bin
SHA-256: 58f6a16ac40bed13555f9b8b0e67319b9921b9b9759d6dba5275053bbac53c05
```

Test vbmeta:

```text
artifacts/tb371fc-vbmeta_b-verification-disabled.img
SHA-256: 5faf802f3d821512505c42a9fa0dba5b969f135fd5ec3bf6686e8448e741a169
```

## Правило развёртывания

1. Проверить SHA-256 образа и наличие его hash в allowlist
   `scripts/temporary-vbmeta-recovery-test.ps1`.
2. Выполнить `ValidateOnly` и `Preflight`.
3. Проверить serial `<serial>`, slot B, unlocked state и размеры разделов.
4. Подготовить точный recovery rollback **до** записи теста.
5. Только с владельцем у планшета выполнить guarded `Launch`.
6. Собрать логи до следующего reboot.
7. Для stock restore всегда сначала писать exact `recovery_b`, затем exact
   signed `vbmeta_b`.

Не использовать `fastboot boot`: Lenovo ABL отвечает `unknown command`. Не
использовать slot A. Не добавлять новый hash в allowlist до offline audit
boot image, размеров, footer и компонентов.

### Пример: только offline validation V56.3 r2

Эта команда ничего не запрашивает у устройства и ничего не записывает:

```powershell
Set-Location <repo>
$pt = '<platform-tools>'
$v563r2 = 'D:\TB371FC-builds\arch-development-loader-v56-3-r2-community-simplefb-qca6390-kde-kexec-safe\tb371fc-arch-development-loader-v56-3-r2-community-simplefb-qca6390-kde-kexec-safe-recovery.img'

.\scripts\temporary-vbmeta-recovery-test.ps1 `
  -Action ValidateOnly `
  -PlatformToolsDir $pt `
  -RecoveryImage $v563r2
```

Если планшет уже в fastboot, hardware launch выполняется action
`LaunchFastboot`, а не `Preflight`; этот action намеренно пропускает Android
ADB/battery preflight. Он должен запускаться только при владельце после
read-only fastboot проверок, с `-TwoPartitionWriteApproved` и обычным
PowerShell подтверждением `ShouldProcess`. Не вставлять такую write-команду в
автоматический unattended workflow.
