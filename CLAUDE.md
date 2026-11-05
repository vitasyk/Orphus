# Orphus AV — робочі нотатки для Claude Code

Bash-антивірус для Linux-хостингу (`orphus-av.sh`, ~6.4k рядків). Форк https://github.com/FartGarfild/Orphus,
наш репо — https://github.com/vitasyk/Orphus, робоча гілка **`audit-fixes`**. Мова спілкування з користувачем — українська.

## Цілі користувача
- Продукт для Linux (99% випадків), shared-хостинг з PHP-сайтами.
- **Хибні спрацювання недопустимі** — будь-яка зміна, що може додати FP, тільки після явного погодження.
- Ponytail-стиль: мінімальна зміна, що повністю вирішує задачу; кожне твердження — з тестом.

## Як влаштований скрипт
- Один файл: main + вбудовані модулі між маркерами `#__SETUP_MODULE_START__/_END__` (setup) і `#__WORKER_START__/_END__` (воркер, витягується у `WORK_DIR/worker.sh`; ~44 позиційні аргументи, нові опції передаємо через `export ORPHUS_*`).
- `compile_signatures` → кеш у `signatures/.cache`, ключ = `$VERSION clamwin=$CLAM_WINDOWS`.
- ClamAV `.ndb/.ldb` → YARA через awk (`clam_hex2yara`, `clam_target`, `clam_offset`, `clam_platform_ok` у блоці `ndb2yara_fn`). Працює в **busybox awk** — без gawk-розширень і без `\{` у регулярках.
- Скрипт має бути LF (`.gitattributes`); на Windows `core.autocrlf=true`.

## Зроблено (гілка audit-fixes)
C1 temp-шляхи `mktemp -d` · C2 flush real-time за 2 с · C3 polyglot GIF+PHP · C4 карантин (лише сигнатурні знахідки, без symlink/системних шляхів, `--quarantine-max`, маніфест з uid:gid:mode+sha256, `--restore`) · C5 pinned SHA256 (`verify_pinned`, `--yara-url-sha256`, `ORPHUS_ALLOW_UNPINNED`) · C6 новий конвертер ClamAV (Linux/веб ~9k правил за замовчуванням, `--clam-windows`, `--clamd`, валідація по правилу, `.ign2`) · H1 великі скрипти · H2/H10 хеш-пакет · H4 ключ кешу ctime:dev:inode · H9 exit 1 · YARA self-test · LICENSE.

Листопад 2026 (v0.3.2): H3 fallback openssl/md5 (`_hash_each`) · H5 sandbox розпакування (проба режиму → fallback `simple`, приватна копія архіву `cp -P`, chown замість 0777, bwrap `--tmpfs /tmp` до bind) · аудит ponytail, 20 пунктів: real-time (тека через `mv`, змінені файли, файли під час базового скану, flush при потоці подій, падіння inotifywait, імена з `\n`/`\t`) · нормалізація шляхів `-d/-s/-X/-o` (symlink-корінь, `-prune`, `-X` symlink не виводить за межі) · валідація числових опцій · коди виходу **0 чисто / 1 загрози / 2 помилка або INCOMPLETE / 130** · завантаження: system wget/curl перед busybox wget (без TLS-перевірки) · звіт у `$SCRIPT_DIR/reports/` (noclobber) · `--setup` отримує env · інкрементальний кеш скидається після компіляції сигнатур, не кешує впалі пули і шляхи з `|` · YARA: відносні include, відкидання файлів з дублікатами імен правил (раніше вся YARA була мертва з дефолтними джерелами) · rfxn.ndb ({HEX}php…) більше не відкидається фільтром платформ · пріоритет YARA-файлів (вебшели/PHP першими, без deprecated/index/Windows-тек) · архіви: hex-only хеші, імена з `\`/`\n`, kill бомби в усіх режимах · merged-/usr FP (SUID, `-K`, Debian 13 модулі, initrd) · ліміт пам'яті yara `ORPHUS_YARA_MEM_MB` (1536) + пропуск/падіння yara = INCOMPLETE · розділ звіту `NOT FULLY SCANNED` · консольний UX (сесія orphus-21: банер, прогрес без TTY, коротка `-h`, рядкові сигнатури без yara).

Заміри (Docker ubuntu 24.04, yara 4.5.0, дефолтні джерела, v0.3.2): 17 616 правил; **0 загроз на 72 662 чистих файлах** (WordPress + 12 плагінів, Joomla, Drupal, phpMyAdmin, Laravel); tennc/webshell 1 263/1 764; пік yara 82 МБ на чистих, ≤1.5 ГБ на «напханих» тегами файлах.

## Свідомо НЕ змінено
- **H6/H7** (широкі дефолти `ignore_sigs`, vendor-allowlist DLE за рядком) — прибрання поверне FP; користувач вирішив не чіпати.
- Pin commit для YARA-репозиторіїв (правила — дані; від масового карантину захищає ліміт).

## Що далі
1. **Linux VM** (Alma з SELinux, справжні user namespaces): `--setup`, `-q`, `--restore`, bwrap/unshare на живому ядрі, `--clamd` зі справжнім clamd. Docker-тести цього не покривають (немає userns, немає SELinux).
2. Перевірити, що скан не змінює файли сайтів (маніфест до/після: вміст, права, власник, xattr, ACL, mtime/ctime, atime).
3. Залишок: H8 (`-K` довіряє md5sums того ж диска), C3 друга половина (`<?php`/ASP всередині справжнього `.jpg` — 3 вебшели tennc пропускаються через `skip_deep`), busybox для ARM (URL на busybox.net мертві), real-time не застосовує `-X`/самовиключення, busybox-poll не бачить імен з `\n`, thor-webshells.yar відкидається цілим файлом через дублікати імен (дедуп по правилах зберіг би більше).

## Як тестувати в Docker (на цьому ПК)
Docker Desktop доступний; запуск з Git Bash з `MSYS_NO_PATHCONV=1`. Образи: `orphus-h5` (debian + unzip/bwrap/busybox), `sigs-base` (ubuntu + yara 4.5.0) з томом `sigs-data` (сигнатури `/data/m/sigs`, чистий корпус, tennc вебшели — лише в контейнері), `wk-kern-*` (ядра для `-K`), `rt-ubuntu`/`rt-alpine` (real-time). Тест-скрипти агентів лежали в scratchpad сесії (тимчасово). Сценарій: старий код `git show <base>:orphus-av.sh` проти нового, тест має падати на старому. Захисник Windows блокує файли з `eval(base64_decode` — шкідливі зразки тримати лише в контейнері.

## Як тестувати без Linux
Функції витягуються з файлу й ганяються на реальних даних:
```bash
eval "$(awk '/^process_hash_batch\(\) \{/{f=1} f{print} f&&/^}/{f=0}' orphus-av.sh)"
```
YARA: `py -m venv yv && yv/Scripts/python -m pip install yara-python psutil` (libyara 4.5, як `--setup`).
Бази: `curl -A Mozilla/5.0 -O https://packages.microsoft.com/clamav/{main,daily}.cvd`, розпакувати `dd bs=512 skip=1 | tar -xz`.
Bash-tool у Claude Code злипає `\\` у heredoc — патчі з бекслешами пиши у `.py`-файл через Write, а не heredoc.

## Локальні (не в git) файли
`Orphus-AV-audit.md`, `Orphus-AV-agent-prompt.md`, `evidence/` — повний аудит, промпт для агента, докази. Переносити окремо.
