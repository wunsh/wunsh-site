---
title: Установка Эликсира на Виндоуз
update_date: 21-06-2018
elixir_version: 1.6.6
---

{% include install/_windows_header.md page=page %}

Работа с пакетным менеджером на Виндоуз не сложнее, чем на Юникс-подобных операционных системах.

## 1. Установка менеджера пакетов Чоколейти

Для начала давай установим [менеджер пакетов Чоколейти](https://chocolatey.org), если он ещё не установлен. Для этого открой командную строку *от имени администратора* и выполни команду:

```
@"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -InputFormat None -ExecutionPolicy Bypass -Command "iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))" && SET "PATH=%PATH%;%ALLUSERSPROFILE%\chocolatey\bin"
```

Альтернативный вариант установки через Повершелл можно найти [по ссылке](https://chocolatey.org/install).

## 2. Установка Эликсира

Хоть Эликсир и основан на Эрланге, мы можем начать установку сразу с Эликсира. Всё дело в том, что Чоколейти сможет подтянуть Эрланг в качестве зависимости автоматически.

1. Устанавливаем Эликсир, выполнив команду в запущенной от имени администратора командной строке:

    ```
choco install elixir
    ```
    
1. Перезапускаем командную строку и проверяем установку:

```
elixir -v


Erlang/OTP 20 [erts-9.3] [source] [64-bit] [smp:4:4] [ds:4:4:10] [async-threads:10] [hipe] [kernel-poll:false]
    
Elixir {{page.elixir_version}} (compiled with OTP 19)
```

Поздравляем, всё готово!