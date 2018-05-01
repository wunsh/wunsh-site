---
title: Установка Эликсира на Линукс
update_date: 01-05-2018
elixir_version: 1.6.4
---

{% include install/_linux_header.md page=page %}

Данный способ позволяет держать одновременно одну рабочую копию Эликсира. Он очень прост в осуществлении и подойдёт для начала работы с языком или для установки на сервере.

## 1. Установка Эрланга

Язык Эликсир работает поверх виртуальной машины Эрланга. Следовательно, установка Эрланга является первоочередной задачей.

1. Добавляем в `apt` репозиторий «Erlang Solutions». Данный репозиторий содержит самые свежие версии дистрибутивов Эрланга.

    ```
wget https://packages.erlang-solutions.com/erlang-solutions_1.0_all.deb && sudo dpkg -i erlang-solutions_1.0_all.deb
    ```

1. Обновляем кэш `apt`:

    ```
sudo apt-get update
    ```

1. Устанавливаем Эрланг. Обратите внимание, что следует выбрать пакет `esl-erlang`, который содержит полный сборку `Erlang/OTP`, включая все модули.

    ```
sudo apt-get install esl-erlang
    ```

1. Проверяем установку:

```
erl


Erlang/OTP 20 [erts-9.3] [source] [64-bit] [smp:4:4] [ds:4:4:10] [async-threads:10] [hipe] [kernel-poll:false]

Eshell V9.3  (abort with ^G)
1>
```
    

## 2. Установка Эликсира

Здесь всё просто – нужно лишь установить Эликсир.

1. Устанавливаем Эликсир: 

    ```
sudo apt-get install elixir
    ```

1. Проверяем установку:

```
elixir -v


Erlang/OTP 20 [erts-9.3] [source] [64-bit] [smp:4:4] [ds:4:4:10] [async-threads:10] [hipe] [kernel-poll:false]
    
Elixir {{page.elixir_version}} (compiled with OTP 19)
```

Поздравляем, всё готово!