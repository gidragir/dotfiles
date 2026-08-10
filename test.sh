#!/usr/bin/env bash

# Впишите сюда ваши репозитории для проверки:
paths=(
  "retail/apps/kube"
  "govtech/vir"
  "retail/mock-apps/tourist"
)

for CI_PROJECT_PATH in "${paths[@]}"; do
  if [[ "$CI_PROJECT_PATH" == */*/* ]]; then
    VALUES_FILE="${CI_PROJECT_PATH#*/}/values.yaml"
  else
    VALUES_FILE="apps/${CI_PROJECT_PATH#*/}/values.yaml"
  fi
  echo "$CI_PROJECT_PATH  =>  $VALUES_FILE"
done
