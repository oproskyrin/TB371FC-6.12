# Подключение к планшету

## SSH

Пользователь: `root`. Порт: `2222`. Пароль не используется: вход только по
ключу.

Приватный ключ уже находится на Windows и не должен копироваться в `opus`:

```text
<repo>\artifacts\tb371fc-development-ssh\id_ed25519
```

Обычное подключение из PowerShell:

```powershell
$key = '<repo>\artifacts\tb371fc-development-ssh\id_ed25519'
$ip = '192.168.1.151' # заменить найденным адресом текущей загрузки
ssh.exe -i $key -p 2222 -o IdentitiesOnly=yes `
  -o StrictHostKeyChecking=accept-new root@$ip
```

Адрес выдаётся DHCP и меняется. В прошлых загрузках встречались
`192.168.1.151`, `.152`, `.153`, `.164`, `.199`. Не принимать старый адрес за
актуальный.

### Поиск адреса

Сначала посмотреть ARP. USB Ethernet MAC начинается с `00-03-7f`, но хвост
может меняться:

```powershell
arp -a | Select-String '00-03-7f'
```

Если записи нет, найти открытый порт 2222 в лабораторной подсети:

```powershell
1..254 | ForEach-Object -Parallel {
  $ip = "192.168.1.$_"
  if (Test-NetConnection $ip -Port 2222 -InformationLevel Quiet -WarningAction SilentlyContinue) {
    $ip
  }
} -ThrottleLimit 32
```

На этом компьютере Windows-сторона USB/NCM ранее имела адрес
`192.168.1.33`. Перед сканированием проверить `Get-NetIPConfiguration`.

Если адрес повторно занят тем же планшетом, но host key изменился, только для
этой изолированной лабораторной сети допустим одноразовый вызов:

```powershell
ssh.exe -i $key -p 2222 -o IdentitiesOnly=yes `
  -o StrictHostKeyChecking=no -o UserKnownHostsFile=NUL root@$ip
```

Передача файла:

```powershell
scp.exe -i $key -P 2222 -o IdentitiesOnly=yes .\local-file root@${ip}:/var/tmp/
```

## Первичный read-only snapshot

После подключения ничего не менять до сохранения состояния:

```sh
date -Ins
uname -a
cat /run/tb371fc-v56-kde-status 2>/dev/null || true
ip -br address
findmnt
ls -l /dev/dri /dev/kgsl-3d0 2>/dev/null
ps -ef | grep -E '[k]win_wayland|[p]lasmashell'
tr '\0' '\n' </proc/$(pgrep -o kwin_wayland)/environ 2>/dev/null | sort
journalctl -b --no-pager > /var/tmp/journal-current-boot.txt
dmesg -T > /var/tmp/dmesg-current-boot.txt
```

Скопировать оба лога на Windows до следующего reboot.

## Fastboot

Установленный executable:

```text
<platform-tools>\fastboot.exe
```

Безопасная read-only проверка:

```powershell
fastboot.exe devices
fastboot.exe -s <serial> getvar current-slot
fastboot.exe -s <serial> getvar unlocked
fastboot.exe -s <serial> getvar partition-size:recovery_b
fastboot.exe -s <serial> getvar partition-size:vbmeta_b
```

Ожидается slot `b`, unlocked `yes`, `recovery_b` 100 MiB и `vbmeta_b` 64 KiB.
Slot A помечен unbootable и не используется. Lenovo ABL не поддерживает
`fastboot boot`, поэтому Linux запускается временной заменой `recovery_b` и
тестовым `vbmeta_b` с обязательным откатом.

Не вводить вручную `fastboot flash` по памяти. Использовать только проверенный
контроллер:

```text
scripts/temporary-vbmeta-recovery-test.ps1
```

Сначала запускать `ValidateOnly`, затем `Preflight`. `Launch` и `Restore`
изменяют разделы и требуют присутствия владельца, проверенного SHA-256,
allowlist и явного разрешения. Контроллер восстанавливает точный stock
`recovery_b` первым, затем подписанный stock `vbmeta_b`.

Полная политика описана в [../RECOVERY.md](../RECOVERY.md),
[../TESTING.md](../TESTING.md) и [../REMOTE_TESTING.md](../REMOTE_TESTING.md).

