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

Заміри (Windows + yara-python 4.5.4, бази ClamAV daily v28174): 0 FP на 25 938 чистих файлах; 9k правил = +17 МБ RSS, 1 108 файлів/с у YARA.

## Свідомо НЕ змінено
- **H6/H7** (широкі дефолти `ignore_sigs`, vendor-allowlist DLE за рядком) — прибрання поверне FP; користувач вирішив не чіпати.
- Pin commit для YARA-репозиторіїв (правила — дані; від масового карантину захищає ліміт).

## Що далі
1. **Linux VM** (Debian/Ubuntu + Alma з SELinux): прогнати справжній `orphus-av.sh` — `--setup`, `-u`, скан, `-q`, `-w`, `--restore`; перевірити 0700 тек, `chmod` при restore, busybox awk vs gawk (кількість конвертованих правил має збігтися), `--clamd` зі справжнім clamd.
2. Перевірити, що скан не змінює файли сайтів (маніфест до/після: вміст, права, власник, xattr, ACL, mtime/ctime, atime).
3. Залишок аудиту: H3 (fallback openssl/md5), H5 (пісочниця розпакування), H8 (`-K` довіряє md5sums того ж диска), C3 друга половина (`<?php` всередині `.jpg`), busybox для ARM (URL на busybox.net мертві).

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
