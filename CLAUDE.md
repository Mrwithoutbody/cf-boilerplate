# Zasady pracy

## Boilerplate jest PRIMARY

To repo (`futurestack`) jest źródłem prawdy dla `control/`, `scripts/`, README.
Projekty pochodne (np. `/home/dadmor/projekty/znany-biuro`) to konsumenci —
osobne gity, bez remote, tworzone przez `setup.sh`.

- Feature'y do control/scripts rozwijaj TUTAJ, potem kopiuj do projektów.
  `control/` jest generyczny (zero rzeczy per-projekt) — kopiuje się 1:1.
- Gdy zmiana powstała w projekcie — zrób backport tutaj zanim uznasz temat
  za zamknięty.
- Przed nadpisaniem czegokolwiek w którymkolwiek repo: diffuj oba kierunki.
  Projekt może mieć nowszy kod (2026-07-02: sesje/QR powstały w znany-biuro
  i wróciły backportem w b590d8a).
