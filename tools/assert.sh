#!/usr/bin/env bash

#####################################################################
##
## title: Assert Extension
##
## description:
## Assert extension of shell (bash, ...)
##   with the common assert functions
## Function list based on:
##   http://junit.sourceforge.net/javadoc/org/junit/Assert.html
## Log methods : inspired by
##	- https://natelandau.com/bash-scripting-utilities/
## author: Mark Torok
##
## date: 07. Dec. 2016
##
## license: MIT
##
#####################################################################

if command -v tput &>/dev/null && tty -s; then
  RED=$(tput setaf 1)
  GREEN=$(tput setaf 2)
  MAGENTA=$(tput setaf 5)
  NORMAL=$(tput sgr0)
  BOLD=$(tput bold)
else
  RED=$(echo -en "\e[31m")
  GREEN=$(echo -en "\e[32m")
  MAGENTA=$(echo -en "\e[35m")
  NORMAL=$(echo -en "\e[00m")
  BOLD=$(echo -en "\e[01m")
fi

# Выводит заголовок в терминал жирным пурпурным цветом.
#
# Arguments:
#
# * Текст заголовка для отображения.
#
# Outputs:
#
# * Печатает форматированный заголовок в STDERR.
log_header() {
  printf "\n${BOLD}${MAGENTA}==========  %s  ==========${NORMAL}\n" "$@" >&2
}

# Выводит сообщение об успешном выполнении с зелёной галочкой в стандартный поток ошибок.
#
# Arguments:
#
# * Сообщение об успехе (строка или несколько строк)
#
# Outputs:
#
# * Сообщение с зелёной галочкой в STDERR.
#
# Example:
#
# log_success "Тест успешно пройден"
log_success() {
  printf "${GREEN}✔ %s${NORMAL}\n" "$@" >&2
}

# Выводит сообщение об ошибке с красным крестиком в стандартный поток ошибок.
#
# Arguments:
#
# * Сообщение об ошибке для отображения.
#
# Outputs:
#
# * Сообщение об ошибке с цветовым выделением в STDERR.
#
# Example:
#
# ```bash
# log_failure "Тест не пройден"
# ```
log_failure() {
  printf "${RED}✖ %s${NORMAL}\n" "$@" >&2
}


# Проверяет, равны ли ожидаемое и фактическое значения.
#
# Arguments:
#
# * expected — ожидаемое значение.
# * actual — фактическое значение.
# * msg (необязательно) — сообщение, выводимое при ошибке.
#
# Returns:
#
# * 0, если значения равны; 1, если не равны (и при этом выводится сообщение об ошибке, если оно указано).
#
# Example:
#
# assert_eq "foo" "$result" "Результат не совпадает с ожидаемым"
assert_eq() {
  local expected="$1"
  local actual="$2"
  local msg="${3-}"

  if [ "$expected" == "$actual" ]; then
    return 0
  else
    [ "${#msg}" -gt 0 ] && log_failure "$expected == $actual :: $msg" || true
    return 1
  fi
}

# Проверяет, что значения не равны друг другу.
#
# Возвращает 0, если значения различны; иначе выводит сообщение об ошибке (если указано) и возвращает 1.
#
# Аргументы:
#
# * Ожидаемое значение
# * Фактическое значение
# * Необязательное сообщение для вывода при ошибке
#
# Пример:
#
# ```bash
# assert_not_eq "foo" "bar" "Значения совпадают"
# ```
assert_not_eq() {
  local expected="$1"
  local actual="$2"
  local msg="${3-}"

  if [ ! "$expected" == "$actual" ]; then
    return 0
  else
    [ "${#msg}" -gt 0 ] && log_failure "$expected != $actual :: $msg" || true
    return 1
  fi
}

# Проверяет, равно ли значение строке "true".
#
# Arguments:
#
# * actual — проверяемое значение.
# * msg — необязательное сообщение, выводимое при ошибке.
#
# Returns:
#
# * 0, если значение равно "true"; иначе 1.
assert_true() {
  local actual="$1"
  local msg="${2-}"

  assert_eq true "$actual" "$msg"
  return "$?"
}

# Проверяет, что переданное значение равно "false".
#
# Arguments:
#
# * actual — проверяемое значение.
# * msg — необязательное сообщение, выводимое при ошибке.
#
# Returns:
#
# * 0, если значение равно "false"; иначе 1.
assert_false() {
  local actual="$1"
  local msg="${2-}"

  assert_eq false "$actual" "$msg"
  return "$?"
}

# Проверяет, что два массива равны по длине и содержимому.
#
# Arguments:
#
# * Имя массива с ожидаемыми значениями (передаётся по ссылке)
# * Имя массива с фактическими значениями (передаётся по ссылке)
# * Необязательное сообщение, выводимое при ошибке
#
# Returns:
#
# * 0, если массивы идентичны по длине и значениям; 1 в противном случае.
#
# Example:
#
# ```bash
# arr1=(a b c)
# arr2=(a b c)
# assert_array_eq arr1[@] arr2[@] "Массивы не совпадают"
# ```
assert_array_eq() {

  declare -a expected=("${!1-}")
  # echo "AAE ${expected[@]}"

  declare -a actual=("${!2}")
  # echo "AAE ${actual[@]}"

  local msg="${3-}"

  local return_code=0
  if [ ! "${#expected[@]}" == "${#actual[@]}" ]; then
    return_code=1
  fi

  local i
  for (( i=1; i < ${#expected[@]} + 1; i+=1 )); do
    if [ ! "${expected[$i-1]}" == "${actual[$i-1]}" ]; then
      return_code=1
      break
    fi
  done

  if [ "$return_code" == 1 ]; then
    [ "${#msg}" -gt 0 ] && log_failure "(${expected[*]}) != (${actual[*]}) :: $msg" || true
  fi

  return "$return_code"
}

# Проверяет, что два массива не равны по длине или содержимому.
#
# Arguments:
#
# * Имя переменной ожидаемого массива (по ссылке)
# * Имя переменной фактического массива (по ссылке)
# * Необязательное сообщение для вывода при неудаче
#
# Returns:
#
# * 0 — если массивы различаются по длине или хотя бы одному элементу
# * 1 — если массивы идентичны по длине и содержимому
#
# Example:
#
# ```bash
# arr1=(a b c)
# arr2=(a b d)
# assert_array_not_eq arr1[@] arr2[@] "Массивы не должны совпадать"
# ```
assert_array_not_eq() {

  declare -a expected=("${!1-}")
  declare -a actual=("${!2}")

  local msg="${3-}"

  local return_code=1
  if [ ! "${#expected[@]}" == "${#actual[@]}" ]; then
    return_code=0
  fi

  local i
  for (( i=1; i < ${#expected[@]} + 1; i+=1 )); do
    if [ ! "${expected[$i-1]}" == "${actual[$i-1]}" ]; then
      return_code=0
      break
    fi
  done

  if [ "$return_code" == 1 ]; then
    [ "${#msg}" -gt 0 ] && log_failure "(${expected[*]}) == (${actual[*]}) :: $msg" || true
  fi

  return "$return_code"
}

# Проверяет, является ли переданная строка пустой.
#
# Arguments:
#
# * Строка для проверки.
# * Необязательное сообщение, выводимое при ошибке.
#
# Returns:
#
# * 0, если строка пуста; 1 в противном случае.
#
# Example:
#
# ```bash
# assert_empty "" "Строка должна быть пустой"
# ```
assert_empty() {
  local actual=$1
  local msg="${2-}"

  assert_eq "" "$actual" "$msg"
  return "$?"
}

# Проверяет, что переданная строка не пуста.
#
# Arguments:
#
# * actual — строка для проверки.
# * msg — необязательное сообщение, выводимое при ошибке.
#
# Returns:
#
# * 0, если строка не пуста; 1, если строка пуста.
#
# Example:
#
# ```bash
# assert_not_empty "hello" "Строка не должна быть пустой"
# ```
assert_not_empty() {
  local actual=$1
  local msg="${2-}"

  assert_not_eq "" "$actual" "$msg"
  return "$?"
}

# Проверяет, содержит ли строка подстроку.
#
# Arguments:
#
# * haystack — строка, в которой выполняется поиск.
# * needle — подстрока для поиска.
# * msg — необязательное сообщение, выводимое при неудаче.
#
# Returns:
#
# * 0, если подстрока найдена или needle пустая; 1 в противном случае.
#
# Example:
#
# ```bash
# assert_contain "hello world" "world" # вернёт 0
# assert_contain "hello world" "foo" "Не найдено" # вернёт 1 и выведет сообщение об ошибке
# ```
assert_contain() {
  local haystack="$1"
  local needle="${2-}"
  local msg="${3-}"

  if [ -z "${needle:+x}" ]; then
    return 0;
  fi

  if [ -z "${haystack##*$needle*}" ]; then
    return 0
  else
    [ "${#msg}" -gt 0 ] && log_failure "$haystack doesn't contain $needle :: $msg" || true
    return 1
  fi
}

# Проверяет, что подстрока не содержится в строке.
#
# Arguments:
#
# * haystack — строка, в которой выполняется поиск.
# * needle — подстрока, отсутствие которой проверяется.
# * msg — необязательное сообщение, выводимое при неудаче.
#
# Returns:
#
# * 0, если needle не содержится в haystack или needle пуста.
# * 1, если needle содержится в haystack (и при этом выводится сообщение об ошибке, если оно указано).
#
# Example:
#
# ```bash
# assert_not_contain "abcdef" "gh" # вернёт 0
# assert_not_contain "abcdef" "cd" # вернёт 1
# ```
assert_not_contain() {
  local haystack="$1"
  local needle="${2-}"
  local msg="${3-}"

  if [ -z "${needle:+x}" ]; then
    return 0;
  fi

  if [ "${haystack##*$needle*}" ]; then
    return 0
  else
    [ "${#msg}" -gt 0 ] && log_failure "$haystack contains $needle :: $msg" || true
    return 1
  fi
}

# Проверяет, что первое число больше второго.
#
# Arguments:
#
# * first — первое сравниваемое число
# * second — второе сравниваемое число
# * msg (необязательно) — сообщение, выводимое при неудаче проверки
#
# Returns:
#
# * 0, если first больше second; иначе 1
#
# Example:
#
# ```bash
# assert_gt 5 3 "5 должно быть больше 3"
# ```
assert_gt() {
  local first="$1"
  local second="$2"
  local msg="${3-}"

  if [[ "$first" -gt  "$second" ]]; then
    return 0
  else
    [ "${#msg}" -gt 0 ] && log_failure "$first > $second :: $msg" || true
    return 1
  fi
}

# Проверяет, что первое число больше или равно второму.
#
# Arguments:
#
# * first — первое сравниваемое число.
# * second — второе сравниваемое число.
# * msg (необязательно) — сообщение, выводимое при ошибке.
#
# Returns:
#
# * 0, если first >= second; иначе 1 и сообщение об ошибке.
#
# Example:
#
# assert_ge 10 5 "Ожидалось, что 10 больше или равно 5"
assert_ge() {
  local first="$1"
  local second="$2"
  local msg="${3-}"

  if [[ "$first" -ge  "$second" ]]; then
    return 0
  else
    [ "${#msg}" -gt 0 ] && log_failure "$first >= $second :: $msg" || true
    return 1
  fi
}

# Проверяет, что первое число меньше второго.
#
# Arguments:
#
# * first — первое сравниваемое число.
# * second — второе сравниваемое число.
# * msg (необязательно) — сообщение, выводимое при ошибке.
#
# Returns:
#
# * 0, если first < second; иначе 1 и сообщение об ошибке.
#
# Example:
#
# ```bash
# assert_lt 3 5 "3 должно быть меньше 5"
# ```
assert_lt() {
  local first="$1"
  local second="$2"
  local msg="${3-}"

  if [[ "$first" -lt  "$second" ]]; then
    return 0
  else
    [ "${#msg}" -gt 0 ] && log_failure "$first < $second :: $msg" || true
    return 1
  fi
}

# Проверяет, что первое число меньше или равно второму.
#
# Arguments:
#
# * first — первое сравниваемое число
# * second — второе сравниваемое число
# * msg (необязательно) — сообщение, выводимое при неудаче
#
# Returns:
#
# * 0, если first ≤ second; иначе 1 и сообщение об ошибке (если указано)
#
# Example:
#
# assert_le 3 5 "3 не больше 5" # успешно
# assert_le 7 2 "7 не меньше 2" # завершится с ошибкой и выведет сообщение
assert_le() {
  local first="$1"
  local second="$2"
  local msg="${3-}"

  if [[ "$first" -le  "$second" ]]; then
    return 0
  else
    [ "${#msg}" -gt 0 ] && log_failure "$first <= $second :: $msg" || true
    return 1
  fi
}