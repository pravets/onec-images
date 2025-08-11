#!/usr/bin/env bash
set -euo pipefail

# Обеспечивает единообразное наличие обоих имён: 1cedtcli и 1cedtcli.sh
# В зависимости от того, какой файл существует, создаёт симлинк на другой в той же директории
# Опции:
#   --dir DIR   Рабочая директория (проверяется в первую очередь)
#   --force     Заменять существующие обычные файлы (использовать осторожно)
#   -h|--help   Показать справку

print_usage() {
  cat <<'EOF'
Использование: ensure_edtcli_symlink.sh [--dir DIR] [--force]

Создаёт симлинк так, чтобы были доступны оба имени: 1cedtcli <-> 1cedtcli.sh

Поведение:
- Если существует только один из файлов 1cedtcli или 1cedtcli.sh — создаётся симлинк на отсутствующий рядом с существующим
- Если оба существуют и один уже является симлинком на другой — ничего не делается
- Если оба существуют как обычные файлы — изменений нет (используйте --force, чтобы заменить один из них симлинком)

Опции:
  --dir DIR   Рабочая директория (проверяется раньше PATH). Если задана,
              поиск файлов выполняется в этой директории.
  --force     Заменить существующий не-симлинк в месте назначения
  -h, --help  Показать эту справку и выйти

Примеры:
  ensure_edtcli_symlink.sh
  ensure_edtcli_symlink.sh --dir /usr/local/bin
  sudo ensure_edtcli_symlink.sh --force
EOF
}

OPER_DIR=""
FORCE=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dir)
      [[ $# -ge 2 ]] || { echo "Для --dir требуется значение" >&2; exit 2; }
      OPER_DIR="$2"; shift 2;;
    --force)
      FORCE=true; shift;;
    -h|--help)
      print_usage; exit 0;;
    *)
      echo "Неизвестный аргумент: $1" >&2
      print_usage
      exit 2;;
  esac
done

# Разрешение кандидатов
name_a="1cedtcli"
name_b="1cedtcli.sh"

resolve_path_in_dir() {
  local dir="$1" name="$2"
  if [[ -n "$dir" && -e "$dir/$name" ]]; then
    printf '%s\n' "$dir/$name"
    return 0
  fi
  return 1
}

resolve_path_in_path() {
  local name="$1"
  if command -v "$name" >/dev/null 2>&1; then
    command -v "$name"
    return 0
  fi
  return 1
}

pick_existing() {
  local path
  if path=$(resolve_path_in_dir "$OPER_DIR" "$1"); then
    printf '%s\n' "$path"; return 0
  fi
  if path=$(resolve_path_in_path "$1"); then
    printf '%s\n' "$path"; return 0
  fi
  return 1
}

path_a="" # for 1cedtcli
path_b="" # for 1cedtcli.sh

if path_a=$(pick_existing "$name_a"); then :; fi
if path_b=$(pick_existing "$name_b"); then :; fi

# Определение действия
if [[ -z "$path_a" && -z "$path_b" ]]; then
  echo "Не найден ни $name_a, ни $name_b. Укажите --dir DIR или обеспечьте наличие одного из файлов в PATH." >&2
  exit 1
fi

# Если оба существуют, проверяем, является ли один симлинком на другой; иначе ничего не делаем без --force
if [[ -n "$path_a" && -n "$path_b" ]]; then
  # normalize by resolving symlinks
  norm_a=$(readlink -f "$path_a" || true)
  norm_b=$(readlink -f "$path_b" || true)
  if [[ -n "$norm_a" && -n "$norm_b" && "$norm_a" == "$norm_b" ]]; then
    echo "Оба $name_a и $name_b уже указывают на одну цель: $norm_a"
    exit 0
  fi
  echo "Оба $name_a ($path_a) и $name_b ($path_b) существуют и указывают на разные цели." >&2
  if [[ "$FORCE" == true ]]; then
    # Предпочитаем без .sh в качестве каноничного, если он есть, иначе берём .sh
    if [[ -e "$path_a" ]]; then
      target="$path_a"; link_dir=$(dirname "$path_b"); link_name="$name_b"
    else
      target="$path_b"; link_dir=$(dirname "$path_a"); link_name="$name_a"
    fi
    link_path="$link_dir/$link_name"
    echo "Установлен --force: заменяем $link_path так, чтобы он указывал на $target"
    rm -f "$link_path"
    ln -s "$target" "$link_path"
    exit 0
  fi
  echo "Изменений не внесено. Запустите с --force, чтобы заменить один из файлов симлинком." >&2
  exit 0
fi

# Существует только один; создаём второй рядом с ним
if [[ -n "$path_a" ]]; then
  target="$path_a"
  link_dir="${OPER_DIR:-$(dirname "$path_a")}"; link_name="$name_b"
else
  target="$path_b"
  link_dir="${OPER_DIR:-$(dirname "$path_b")}"; link_name="$name_a"
fi

mkdir -p "$link_dir"
link_path="$link_dir/$link_name"

if [[ -L "$link_path" ]]; then
  current_target=$(readlink "$link_path")
  if [[ "$current_target" == "$target" || "$(readlink -f "$link_path" || true)" == "$(readlink -f "$target" || true)" ]]; then
    echo "Симлинк уже корректен: $link_path -> $target"
    exit 0
  fi
  echo "Обновляем существующий симлинк: $link_path -> $target"
  rm -f "$link_path"
  ln -s "$target" "$link_path"
  exit 0
fi

if [[ -e "$link_path" ]]; then
  if [[ "$FORCE" == true ]]; then
    echo "Установлен --force: заменяем существующий файл $link_path симлинком на $target"
    rm -f "$link_path"
    ln -s "$target" "$link_path"
    exit 0
  fi
  echo "Отказ от перезаписи существующего не-симлинка: $link_path (используйте --force)" >&2
  exit 1
fi

ln -s "$target" "$link_path"
echo "Создан симлинк: $link_path -> $target"