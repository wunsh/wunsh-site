---
title: Установка Эликсира на Виндоуз
update_date: 21-06-2018
elixir_version: 1.6.6
---

{% include install/_windows_header.md page=page %}

Если ты решил немного «поиграться» с Эликсиром, этот вариант установки отлично подойдёт.

## Установка Эликсира

Приготовься...

1. Скачай установщик [по ссылке](https://repo.hex.pm/elixir-websetup.exe) и запусти его

1. Нажимай «Next», пока не увидишь кнопку «Finish»

1. Нажми на «Finish»

1. Проверяем установку:

```
elixir -v


Erlang/OTP 20 [erts-9.3] [source] [64-bit] [smp:4:4] [ds:4:4:10] [async-threads:10] [hipe] [kernel-poll:false]
    
Elixir {{page.elixir_version}} (compiled with OTP 19)
```

Поздравляем, всё готово!