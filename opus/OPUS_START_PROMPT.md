# Готовое стартовое задание для Opus

Скопируйте текст ниже в начало задачи агента.

---

Ты работаешь над Lenovo TB371FC (SM8250, Adreno 650) в проекте
`<repo>`. Полностью прочитай все
файлы в `opus/`, затем только связанные с выбранной гипотезой исходные
diagnostics и scripts. Не очищай dirty workspace и не перезаписывай чужие
изменения.

Ближайшая цель: вернуть стабильный KDE baseline и устранить дрожание launcher
и Plasma Keyboard без шума/чёрного экрана. На vendor Linux 4.19 display идёт
через downstream SDE DRM, а Adreno 650 — через отдельный KGSL. Прикладной
Zink -> Turnip -> Adreno уже доказан; полный KWin на Turnip небезопасен.

Первым делом проверь `opus/CURRENT_STATE.md`: последний тест мог оставить
`/usr/local/bin/kwin_wayland`, который включает
`/opt/tb371fc-kwin-renderloopfix`. Не запускай live KWin replacement. При
доступе к root сначала собери read-only snapshot, затем убери этот launcher и
полной перезагрузкой подтверди штатный `/usr/bin/kwin_wayland`.

После восстановления baseline исследуй frame pacing. Не выполняй новый DRM
modeset: попытки экспортировать/выбрать логические 60/120 Гц уже давали шум.
Сначала инструментируй реальные интервалы vblank/pageflip/RenderLoop без
изменения mode. Один тест должен проверять одну гипотезу и иметь заранее
подготовленный rollback.

Сборки выполняй только в WSL `Ubuntu-24.04`; Windows workspace виден там как
`<repo>`, крупные outputs —
`/mnt/d/TB371FC-builds`. Для SSH используй существующий ключ по пути из
`opus/CONNECTION.md`; не копируй приватный ключ. Для fastboot используй
`scripts/temporary-vbmeta-recovery-test.ps1`, сначала `ValidateOnly` и
`Preflight`. Не используй slot A или `fastboot boot`; не прошивай разделы
вручную.

Перед любой правкой сообщи: текущие факты, гипотезу, минимальный patch,
ожидаемую диагностику и rollback. После теста сохрани exact commands, SHA-256,
полные логи и физический результат в новом каталоге `diagnostics/`.

---

