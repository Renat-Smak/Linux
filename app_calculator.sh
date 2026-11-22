#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo 'Ошибка: не переданы аргументы' >&2
  exit 1
fi

num1=$1
num2=$2
if [[ ! $num1 =~ ^-?(0|[1-9][0-9]*)$ || ! $num2 =~ ^-?(0|[1-9][0-9]*)$ ]]; then
  echo 'Ошибка: ожидаются два целых числа' >&2
  exit 1
fi

echo "Сумма: $((num1 * num2))"
