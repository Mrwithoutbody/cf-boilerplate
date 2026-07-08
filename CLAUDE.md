# Zasady pracy

## Prostota pierwsza

Mniej pytań, mniej kroków, mniej flag. Auto-wykrywaj zamiast pytać.
Pytaj usera TYLKO gdy intencja naprawdę niejednoznaczna i nie da się wywnioskować
ze stanu (pliki, katalogi, .env). Domyślne wartości > interaktywne prompty.

## Boilerplate jest PRIMARY

To repo (`futurestack`) jest źródłem prawdy dla payloadu w `.fs/`
(`.fs/control/`, `.fs/scripts/`, `.fs/setup.sh`). Root repo = tylko docs
(README, LICENSE, CLAUDE.md) + folder `.fs/`. Payload wysyła się do usera przez
`npx degit .../futurestack/.fs .fs` — ląduje jako `.fs/` WEWNĄTRZ jego projektu
(degit = kopia plików bez `.git`/historii/remote, nie git clone).
Projekty pochodne (np. `/home/dadmor/projekty/znany-biuro`) to konsumenci —
osobne gity, bez remote, futurestack odizolowany w `.fs/` (gitignore).

- Feature'y do .fs/control i .fs/scripts rozwijaj TUTAJ, potem kopiuj do projektów.
  `.fs/` jest generyczny (zero rzeczy per-projekt) — kopiuje się 1:1.
- Stack jest podmienialny przez providery w `.fs/targets/` (styl MCP: każdy sam
  wykrywa projekt, deklaruje deploy/preview/dev/needs_cf; pierwszy trafiony wygrywa).
  deploy.sh/preview.sh/guard.sh/setup.sh NIE hardcodują Cloudflare — czytają target.
  Nowy stack = nowy plik w targets/, nie edycja skryptów rdzenia.
- Gdy zmiana powstała w projekcie — zrób backport tutaj zanim uznasz temat
  za zamknięty.
- Przed nadpisaniem czegokolwiek w którymkolwiek repo: diffuj oba kierunki.
  Projekt może mieć nowszy kod (2026-07-02: sesje/QR powstały w znany-biuro
  i wróciły backportem w b590d8a).
