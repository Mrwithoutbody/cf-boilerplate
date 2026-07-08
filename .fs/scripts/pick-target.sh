#!/usr/bin/env bash
# Wybór targetu deployu — RAZ, przy setup. Zapisuje FS_TARGET do .fs/target.env,
# więc deploy z telefonu (i kolejne setupy) już NIE pytają. Domyślny = wykryty
# z providerów; user potwierdza Enterem albo wybiera inny szablon. Lista szablonów
# = providery w .fs/targets/ (dodanie stacka = nowy plik, pojawia się tu sam).
set -euo pipefail
DIR="$(dirname "$0")"
FS="$(cd "$DIR/.." && pwd)"
PROJECT="$(cd "$FS/.." && pwd)"; export PROJECT
ask(){ local p="$1" d="${2:-}"; local a; read -rp "$(printf '\033[1;33m? %s%s: \033[0m' "$p" "${d:+ [$d]}")" a; echo "${a:-$d}"; }

# Już wybrany (FS_TARGET/FS_DEPLOY w target.env)? Nie pytaj — uszanuj wybór.
if [ -f "$FS/target.env" ] && grep -qE '^[[:space:]]*(FS_TARGET|FS_DEPLOY)=' "$FS/target.env"; then
  echo "Target już ustawiony w .fs/target.env — pomijam wybór."
  exit 0
fi

# Wykryj domyślny provider.
. "$DIR/target.sh"                    # → T_NAME (best guess), T_DEPLOY
DEFAULT="${T_NAME:-}"

# Zbierz szablony (name + label z komentarza).
names=(); labels=()
for p in "$FS"/targets/*.sh; do
  [ -f "$p" ] || continue
  nm="$(basename "$p" .sh | sed 's/^[0-9]*-//')"
  lb="$(sed -n 's/^# label:[[:space:]]*//p' "$p" | head -1)"
  names+=("$nm"); labels+=("${lb:-$nm}")
done

printf '\n\033[1;36m▶ Target deployu (Enter = wykryty)\033[0m\n'
def_i=0
for i in "${!names[@]}"; do
  mark=""
  if [ "${names[$i]}" = "$DEFAULT" ]; then mark="  \033[1;32m← wykryto ($T_DEPLOY)\033[0m"; def_i=$((i+1)); fi
  printf "  %d) %s${mark}\n" "$((i+1))" "${labels[$i]}"
done
printf "  0) auto — wykrywaj przy każdym deployu, nic nie zapisuj\n"
[ "$def_i" = 0 ] && def_i=0    # nic nie wykryto → domyślnie auto

sel="$(ask 'numer' "$def_i")"
if [ "$sel" = 0 ]; then
  echo "Auto — bez zapisu (deploy.sh wykrywa za każdym razem)."
  exit 0
fi
idx=$((sel-1))
if [ "$idx" -lt 0 ] || [ "$idx" -ge "${#names[@]}" ]; then
  echo "Zły numer — zostaję na auto."; exit 0
fi
pick="${names[$idx]}"
printf 'FS_TARGET=%s\n' "$pick" >> "$FS/target.env"
printf "\033[1;32m✔ Zapisano FS_TARGET=%s → .fs/target.env (deploy będzie tego używał)\033[0m\n" "$pick"
echo "  Zmiana później: edytuj .fs/target.env (FS_TARGET / FS_DEPLOY / FS_NEEDS_CF)."
