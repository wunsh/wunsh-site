---
title: Установка Эликсира на МакОC
update_date: 01-05-2018
elixir_version: 1.6.4
---

{% include install/_mac_header.md page=page %}

Ты решил воспользоваться [менеджером версий `asdf`](https://github.com/asdf-vm/asdf) для установки Эликсира, отличный выбор! Благодаря ему ты сможешь использовать разные версии Эликсира для разных проектов на одной машине. 

## 1. Подготовка к установке

Для начала давайте установим менеджер пакетов Брю, если он у вас до сих пор не установлен:

```
ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
```

Чтобы установка прошла гладко, давайте добавим в систему необходимые пакеты, как того [рекомендует документация](https://github.com/asdf-vm/asdf-erlang#before-asdf-install) `asdf`:

```
brew install wxmac
```

Этот пакет потребуется для запуска модулей `observer` и `debugger`.

Также мы не сможем продвинуться дальше без Гита, так что давайте поскорее установим и его:

```
brew install git
```

## 2. Установка менеджера версий `asdf`

Начнём с установки менеджера версий `asdf`. Это наиболее удобный и поддерживаемый менеджер версий. 

1. Сначала скачиваем `asdf` к себе на машину:

    ```
git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch v0.4.3
    ```

1. Затем добавляем скрипты инициализации `asdf` в свою оболочку:

```
# Пользователи Bash должны добавить `asdf` в `.bashrc`
echo -e '\n. $HOME/.asdf/asdf.sh' >> ~/.bashrc
echo -e '\n. $HOME/.asdf/completions/asdf.bash' >> ~/.bashrc

# Пользователи Zsh должны добавить `asdf` в `.zshrc`
echo -e '\n. $HOME/.asdf/asdf.sh' >> ~/.zshrc
echo -e '\n. $HOME/.asdf/completions/asdf.bash' >> ~/.zshrc
```

## 3. Установка Эрланга

Язык Эликсир работает поверх виртуальной машины Эрланга. Следовательно, установка Эрланга является первоочередной задачей.

1. Подключаем к `asdf` плагин Эрланга:

    ```
asdf plugin-add erlang
    ```

1. Устанавливаем Эрланг через `asdf`:

    ```
asdf install erlang 20.3
    ```

1. Делаем данную версию Эрланга глобальной:

    ```
asdf global erlang 20.3
    ```

1. Проверяем установку:

```
erl


Erlang/OTP 20 [erts-9.3] [source] [64-bit] [smp:4:4] [ds:4:4:10] [async-threads:10] [hipe] [kernel-poll:false]

Eshell V9.3  (abort with ^G)
1>
```
    

## 4. Установка Эликсира

1. Подключаем к `asdf` плагин Эликсира: 

    ```
asdf plugin-add elixir
    ```

1. Устанавливаем Эликсир через `asdf`:

    ```
asdf install elixir {{page.elixir_version}}
    ```
    
1. Делаем данную версию Эликсира глобальной:

    ```
asdf global elixir {{page.elixir_version}}
    ```

1. Проверяем установку:

```
elixir -v


Erlang/OTP 20 [erts-9.3] [source] [64-bit] [smp:4:4] [ds:4:4:10] [async-threads:10] [hipe] [kernel-poll:false]
    
Elixir {{page.elixir_version}} (compiled with OTP 19)
```

Поздравляем, всё готово!