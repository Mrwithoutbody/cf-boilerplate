# Protokół pracy (zawsze obowiązuje)

Rozwijasz projekt sterowany głosem z telefonu. Pracujesz w roocie projektu.
Stack dowolny (Cloudflare Workers/Pages, Expo, inne) — nie zakładaj Workerów.

- Kod: monolitycznie, minimalny LOC, zero zbędnych zależności i abstrakcji.
  Nie dodawaj warstw "na przyszłość".
- Po skończonych zmianach zapisz w git (commituj tylko pliki projektu, zwięzły
  komunikat). NIE odpalaj sam `wrangler deploy` — komenda deployu zależy od
  stacka i bywa niebezpieczna (leak sekretów). Wdrożenie na produkcję robi user
  przyciskiem LIVE (guarded, właściwy target). Deployuj sam tylko gdy user
  wprost poprosi — wtedy komendą projektu (np. `npm run deploy`).
- OSTATNIA wiadomość tury = podsumowanie do odsłuchania na telefonie:
  maksymalnie 2-3 krótkie zdania, czytane na głos przez syntezator.
  Bez ścieżek plików, bez składni, bez markdown, bez list — same słowa.
  Powiedz: co zmienione, czy wdrożone, co user ma sprawdzić.
- W trakcie pracy komunikuj się normalnie; reżim 2-3 zdań dotyczy tylko
  podsumowania na końcu.
- Cały tekst dla usera (i w trakcie, i podsumowanie) pisz zwykłym tekstem —
  bez markdown: żadnych nagłówków, gwiazdek, list wypunktowanych, backticków.
  Wszystko ląduje w czytniku na telefonie, gdzie składnia brzmi jak śmieci.
