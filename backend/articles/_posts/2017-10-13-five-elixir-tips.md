---
title: Пять хитростей Elixir, о которых должен знать каждый
excerpt: Интересные трюки, овладев которыми вы сможете писать код на Эликсире ещё продуктивнее.
author: nadezhda
source_url: https://dockyard.com/blog/2017/08/15/elixir-tips
source_title: 5 Elixir tricks you should know
source_author: Daniel Xu
tags: [beginner, practical]
cover: /assets/images/tips_tricks.png
---

## Алиас для `__MODULE__`

Комбинация `alias __MODULE__` на первый взгляд кажется замудрённой, но, если познакомиться с ней поближе, всё становится предельно ясно. Директива `alias` позволяет назначать псевдонимы для имени модуля. Например, `alias Foo.Bar` установит псевдоним `Bar` для модуля `Foo.Bar`.

`__MODULE__` — это макрос среды компиляции, представляющий имя модуля в виде атома. Таким образом, с помощью `alias __MODULE__` можно назначать псевдонимы для модулей Elixir, что лучше всего делать со структурой `defstruct`, о которой мы поговорим дальше.

В примере ниже для проверки данных передаётся структура `API.User`. Вместо того, чтобы прописывать полное имя модуля, назначим ему псевдоним `User`, и дальше будем работать уже с ним. Получаем лаконичный и читабельный код.

```elixir
defmodule API.User do
  alias __MODULE__

  defstruct name: nil, age: 0

  def old?(%User{name: name, age: age} = user) do
    ...
  end
end
```

При необходимости смены имени модуля можно сделать следующее:

```elixir
alias __MODULE__, as: SomeOtherName
```

## Макрос `defstruct` с атрибутом модуля `@enforce_keys`

Представить данные в виде словаря можно и с помощью структур, ведь структура — это тегированный словарь, позволяющий проводить проверки по ключам во время компиляции и проверки типа структуры во время выполнения программы.

Например, у вас не получится создать структуру с полем, которое не определено. А теперь посмотрим на пример с псевдонимом:

```elixir
defmodule Fun.Game do
  alias __MODULE__
  defstruct(
    time: nil,
    status: :init
  )

  def new() do
    %Game{step: 1}
  end
end

iex> IO.inspect Fun.Game.new()
iex> ** (KeyError) key :step not found in: %{__struct__: Fun.Game, status: :init, time: nil}
```

При создании новой структуры иногда необходимо убедиться в том, что поля существуют. Специально для этого в Elixir имеется атрибут модуля `@enforce_keys`:

```elixir
defmodule Fun.Game do
  @enforce_keys [:status]

  alias __MODULE__
  defstruct(
    time: nil,
    status: :init
  )

  def new() do
    %Game{}
  end
end

iex> Fun.Game.new()
iex> ** (ArgumentError) the following keys must also be given when building struct Fun.Game: [:status]
```

На основе результата можно заключить, что в данном случае нельзя полагаться на значение `status` по умолчанию, а нужно определить это значение при создании новой структуры `Game`:

```elixir
def new(status) do
  %Game{status: status}
end

iex> Fun.Game.new(:won)
iex> %Fun.Game{status: :won, time: nil}
```

## Функция `v()` в IEx

При создании модуля `GenServer` часто возникает желание запустить сервер и проверить результат в IEx. При этом действительно важно не забывать про сопоставление идентификатора процесса с образцом, как здесь:

```elixir
iex(1)> Metex.Worker.start_link()
{:ok, #PID<0.472.0>}
```

Иначе придётся прописывать эту команду и сопоставление с образцом заново:

```elixir
{:ok, pid} = Metex.Worker.start_link()
```

Чтобы избавить себя от лишней работы, используйте функцию `v()`, возвращающую результат последней команды:

```elixir
iex(1)> Metex.Worker.start_link()
{:ok, #PID<0.472.0>}

iex(2)> {:ok, pid} = v()
{:ok, #PID<0.472.0>}

iex(3)>  pid
#PID<0.472.0>
```

Эта полезная функция позволит вам немного сократить время разработки.

## Отмена нежелательных команд в IEx

Случалось ли у вас подобное при использовании IEx?

```elixir
iex(1)> a = 1 + 1'
...(2)>
...(2)>
...(2)>
BREAK: (a)bort (c)ontinue (p)roc info (i)nfo (l)oaded
       (v)ersion (k)ill (D)b-tables (d)istribution
```

Обычно достаточно дважды нажать `Ctrl + C`, чтобы выйти и создать новый сеанс. Но всё же иной раз, набрав внушительный список команд, не хочется начинать всё с начала. Команда `#iex:break` — вот что можно сделать.

```elixir
iex(2)> a = 1 + 1
iex(2)> b = 1 + 1'
...(2)>
...(2)> #iex:break
** (TokenMissingError) iex:1: incomplete expression

iex(2)> a
2
```

Из приведённого выше кода видно, что после отмены команды сеанс всё ещё продолжается.

## Привязка значения к необязательной переменной

Многие наверняка знают, что можно привязывать значение к необязательным переменным следующим образом:

```elixir
_dont_care = 1
```

Применив этот приём к аргументам функций, можно увеличить читабельность кода:

```elixir
defp accept_move(game, _guess, _already_used = true) do
  Map.put(game, :state, :already_used)
end

defp accept_move(game, guess, _not_used) do
  Map.put(game, :used, MapSet.put(game.used, guess))
  |> score_guess(Enum.member?(game.letters, guess))
end
```
