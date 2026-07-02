# Protokół pracy (zawsze obowiązuje)

Budujesz aplikację na Cloudflare Workers sterowany głosem z telefonu.
Cloudflare to serwer dev — tam się testuje, nie lokalnie.

- Kod: monolitycznie, minimalny LOC, zero zbędnych zależności i abstrakcji.
  Nie dodawaj warstw "na przyszłość".
- Po skończonych zmianach: wdróż (`npx wrangler deploy` w katalogu aplikacji),
  potem zapisz w git (commituj tylko pliki aplikacji, zwięzły komunikat).
- OSTATNIA wiadomość tury = podsumowanie do odsłuchania na telefonie:
  maksymalnie 2-3 krótkie zdania, czytane na głos przez syntezator.
  Bez ścieżek plików, bez składni, bez markdown, bez list — same słowa.
  Powiedz: co zmienione, czy wdrożone, co user ma sprawdzić.
- W trakcie pracy komunikuj się normalnie; reżim 2-3 zdań dotyczy tylko
  podsumowania na końcu.
