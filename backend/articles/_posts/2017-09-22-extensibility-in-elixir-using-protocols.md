---
title: Протоколы и расширяемость в Elixir
excerpt: В статье речь пойдёт о протоколах – механезме реализации полиморфизма в Elixir.
author: nadezhda
source_url: https://medium.com/everydayhero-engineering/extensibility-in-elixir-using-protocols-2e8fb0a35c48
source_title: Extensibility in Elixir Using Protocols
source_author: Matt Furness
tags: [beginner, practical]
cover: /assets/images/protocols.png
---

В данной статье речь пойдёт о [протоколах](http://elixir-lang.org/getting-started/protocols.html) — особенности Elixir, обеспечивающей расширяемость приложений.

## Протоколы

Согласно [документации](http://elixir-lang.org/getting-started/protocols.html):

> Протоколы — это механизм реализации полиморфизма в Elixir. Диспетчеризация возможна для любого типа данных, если тип указан в реализации протокола.

Другими словами, можно создать функцию, поведение которой будет различно в зависимости от типа её первого аргумента. Реализации протоколов могут существовать для одного из встроенных поддерживаемых псевдонимов типов: `Atom`, `BitString`, `Float`, `Function`, `Integer`, `List`, `Map`, `PID`, `Port`, `Reference`, `Tuple`, `Any`, а также для пользовательских структур. Создадим протокол под названием Countable для подсчёта элементов.

Сначала протокол нужно определить:

```elixir
iex> defprotocol Countable do
...>  def count_items(term)
...> end
```

Заметьте, функция, объявленная в протоколе, не имеет тела. Протоколы поддерживают только заголовки определений; в сущности, они [переопределяют макрос](https://github.com/elixir-lang/elixir/blob/v1.4.2/lib/elixir/lib/protocol.ex#L13) `def`. Заголовки определений имеют больше ограничений. К примеру, определение, содержащее охранное условие, не будет скомпилировано:

```elixir
iex> defprotocol Countable do
...>   def count_items(term) when is_binary(term)
...> end
** (CompileError) iex:4: missing do keyword in def
    iex:4: (module)
```

Такая же ошибка возникнет при попытке компиляции функции сопоставления с литералом:

```elixir
iex> defprotocol Countable do
...>   def count_items("")
...> end
** (CompileError) iex:4: can use only variables and \\ as arguments in definition header
    iex:4: (module)
```

Заголовок функции в объявлении протокола должен содержать хотя бы один аргумент, именно он впоследствии понадобится для обращения к нужной реализации протокола:

```elixir
iex> defprotocol Countable do
...>   def count_items()
...> end
** (ArgumentError) protocol functions expect at least one argument
    (elixir) expanding macro: Protocol.def/1
             iex:19: Countable (module)
```

Определим реализации протокола для подсчёта элементов для типов `List`, `Map` и пользовательского типа `Order`.

Реализация для `List`:

```elixir
iex> defimpl Countable, for: List do
...>   def count_items(list), do: length(list)
...> end
```

Реализация для `Map`:

```elixir
iex> defimpl Countable, for: Map do
...>   def count_items(map), do: map_size(map)
...> end
```

Реализация для `Order`:

```elixir
iex> defmodule Order do
...>   defstruct number: 0, items: []
...>
...>   defimpl Countable do
...>     def count_items(%Order{items: items}) do
...>       Countable.count_items(items)
...>     end
...>   end
...> end
```

Обратите внимание, что при определении реализации внутри модуля, в котором уже определена структура, аргумент `for` может быть опущен.

Несмотря на наличие ограничений на сопоставление при объявлении протокола, в его реализации эти ограничения отсутствуют: можно без опаски использовать сопоставление с образцом и охранные условия. Это означает, что для одного и того же количества аргументов могут существовать несколько тел функции.

Вызовем функцию протокола с указанием аргумента, который совпадает с указанными выше типами:

```elixir
iex> Countable.count_items([:one, :two])
2

iex> Countable.count_items(%{one: 1, two: 2})
2

iex> Countable.count_items(%Order{number: 1, items: [:apple]})
1

iex> Countable.count_items({:one, :two})
** (Protocol.UndefinedError) protocol Countable not implemented for {:one, :two}
    iex:1: Countable.impl_for!/1
    iex:2: Countable.count_items/1
```

Любопытно, что каждая реализация становится подмодулем модуля протокола, а значит, в реализации протокола будут поддерживаться атрибуты модуля. Чтобы убедиться в этом, посмотрим информацию о модуле:

```elixir
iex> Countable.Order.__info__(:functions)
[__impl__: 1, count_items: 1]

iex> Countable.impl_for(%Order{})
Countable.Order
```

## Атрибут модуля @for

Реализации протокола имеют доступ к атрибуту модуля `@for`, который представляет собой псевдоним текущего типа, и атрибуту `@protocol` — псевдониму реализуемого протокола. Это очень удобно во время реализации протокола для различных псевдонимов:

```elixir
iex> defprotocol ToList do
...>   def to_list(term)
...> end

iex> defimpl ToList, for: [Map, Tuple] do
...>   def to_list(term) do
...>     @for.to_list(term)
...>   end
...> end

iex> ToList.to_list({:ok, "Hurray"})
[:ok, "Hurray"]
```

В примере выше оба модуля `Map` и `Tuple` определяют функцию `to_list`, и в зависимости от значения атрибута `@for` будет вызвана правильная реализация.

## Резервная реализация для Any

`Any` — особый псевдоним, который можно использовать в качестве резервной реализации протокола или его реализации по умолчанию. При этом, в объявлении протокола необходимо указать:

```elixir
iex> defprotocol Countable do
...>   @fallback_to_any true
...>   def count_items(term)
...> end

iex> defimpl Countable, for: Any do
...>   def count_items(_), do: :unknown
...> end

iex> Countable.count_items({:one, :two})
:unknown
```

Примечание: можно [обратиться](https://elixir-lang.org/getting-started/protocols.html#deriving) к реализации протокола с Any, если необходимо создать список модулей, которые могут быть восстановлены.

## Встроенные протоколы

Существует некоторое количество встроенных протоколов, которые могут оказаться крайне полезными в практических задачах. На данный момент это такие протоколы, как [Collectable](https://hexdocs.pm/elixir/Collectable.html), [Enumerable](https://hexdocs.pm/elixir/Enumerable.html), [Inspect](https://hexdocs.pm/elixir/Inspect.html), [List.Chars](https://hexdocs.pm/elixir/List.Chars.html) и [String.Chars](https://hexdocs.pm/elixir/String.Chars.html). Каждый из них имеет только одну функцию, за исключением `Enumerable`, у которого их целых три. Стоит отметить, что лучше делать протоколы настолько «лёгкими», насколько это возможно.

К списку выше можно было бы добавить и модуль [Access](https://hexdocs.pm/elixir/Access.html), который из протокола [превратился](https://github.com/elixir-lang/elixir/commit/af7c09e0c19974117b26ec0340b9a2dbb9d36ae9) в [поведение](http://elixir-lang.org/getting-started/typespecs-and-behaviours.html#behaviours).

## Когда их использовать

Одно из значительных преимуществ протоколов заключается в том, что реализация протокола может находиться вне библиотеки/приложения, где он определён. Это пригодится разработчикам библиотек: они смогут создавать точки расширения для пользовательских типов. Вот несколько наглядных примеров из реальных проектов:

- **[Plug.Exception](https://hexdocs.pm/plug/Plug.Exception.html#content)** — протокол, позволяющий исключениям получать код состояния
- **[Phoenix.Para](https://hexdocs.pm/phoenix/Phoenix.Param.html#content)** — протокол, конвертирующий структуры данных в параметры URL
- **[Scrivener.Paginater](https://hexdocs.pm/scrivener/Scrivener.Paginater.html#content)** — протокол, нумерующий типы
- **[Poison.Encoder](https://hexdocs.pm/poison/Poison.Encoder.html#content)** — протокол, кодирующий типы в формат JSON 
- **[Joken.Claims](https://hexdocs.pm/joken/Joken.Claims.html)** — протокол, превращающий данные в запросы.

## Производительность

Согласно документации, существует потенциальная угроза снижения производительности при использовании протоколов:

> Поскольку протокол может работать с любым типом данных, необходимо при каждом вызове проверять, существует ли реализация для данного типа. Производительность при этом может упасть.

В связи с этим [консолидация](https://hexdocs.pm/mix/Mix.Tasks.Compile.Protocols.html#content) протоколов (как часть [компиляции](https://hexdocs.pm/mix/Mix.Tasks.Compile.html)) по умолчанию включена. Консолидация протоколов — это процесс оптимизации диспетчеризации путём поиска всех реализаций в проекте или приложении. Чтобы проверить, включена ли эта опция, запустите следующую команду:

```elixir
iex> Mix.Project.config[:consolidate_protocols]
true
```

## Заключение

Протоколы позволяют с лёгкостью добавлять в код точки расширения, что особенно важно для создателей библиотек. Разумеется, не стоит этим увлекаться. Не используйте протоколы, когда к ним обращаются функции, проводящие сопоставление с образцом. То, что встроенных протоколов всего шесть, только подтверждает эту мысль.
