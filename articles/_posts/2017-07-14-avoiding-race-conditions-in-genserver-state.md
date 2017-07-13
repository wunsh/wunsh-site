---
title: Как избежать состояния гонки при использовании GenServer
excerpt: В этой статье пойдёт речь о том, как избежать состояния гонки при использовании GenServer на примере многопользовательской игры.
author: nadezhda
source_url: https://bhelx.simst.im/articles/avoiding-race-conditions-in-genserver-state/
source_author: Benjamin Eckel
tags: [advanced, genserver, practical]
cover: /assets/images/race_conditions.png
---

Предположим, вам необходимо разработать многопользовательскую игру, и&nbsp;состояние игры вы&nbsp;решили хранить в&nbsp;структуре `Game`. Планируется запускать игру без игроков: они будут присоединяться к&nbsp;ней в&nbsp;индивидуальном порядке. Введём максимальное количество игроков `@max_players`, а&nbsp;список игроков представим в&nbsp;виде списка строк (ников игроков).

```elixir
defmodule Game do
  @max_players 4
  defstruct players: []

  def add_player(game, nick) do
    Map.update!(game, :players, &([nick | &1]))
  end

  def max_players?(%{players: ps}) when length(ps) < @max_players, do: false
  def max_players?(_game), do: true
end
```

Попробуем выполнить это в&nbsp;iex.

```elixir
iex(1)> game = %Game{}
%Game{players: []}
iex(2)> game = Game.add_player(game, "ben")
%Game{players: ["ben"]}
iex(3)> game = Game.add_player(game, "harry")
%Game{players: ["harry", "ben"]}
iex(4)> game = Game.add_player(game, "ralph")
%Game{players: ["ralph", "harry", "ben"]}
iex(5)> Game.max_players?(game)
false
iex(6)> game = Game.add_player(game, "tom")
%Game{players: ["tom", "ralph", "harry", "ben"]}
iex(7)> Game.max_players?(game)
true
```

Кажется, работает! Теперь хорошо&nbsp;бы обернуть всё это в&nbsp;процесс. OTP предоставляет несколько способов для решения этой задачи. Один из&nbsp;них&nbsp;&mdash; это GenServer. Для каждой игры организуем свой процесс, идентифицировать который будем по&nbsp;PID. Создадим свой GenServer и&nbsp;назовём его `GameServer`.

```elixir
defmodule GameServer do
  use GenServer

  def start_link do
    GenServer.start_link(__MODULE__, %Game{})
  end

  def get_state(pid) do
    GenServer.call(pid, :get_state)
  end

  def add_player(pid, nick) do
    game = get_state(pid)
    if Game.max_players?(game) do
      {:error, :max_players}
    else
      GenServer.call(pid, {:add_player, nick})
    end
  end

  # Callbacks

  def handle_call(:get_state,  _from, game) do
    {:reply, game, game}
  end

  def handle_call({:add_player, nick}, _from, game) do
    {:reply, :ok, Game.add_player(game, nick)}
  end
end
```

У&nbsp;нас будет две функции:

1. Функция `get_state`, которая возвращает текущее состояние игры;

2. Функция `add_player`, которая возвращает `{:error, reason}`, если игрока невозможно добавить в&nbsp;игру и `:ok` в&nbsp;противном случае.

Снова запустим `iex`:

```elixir
iex(1)> {:ok, pid} = GameServer.start_link
{:ok, #PID<0.91.0>}
iex(2)> GameServer.add_player(pid, "ben")
:ok
iex(3)> GameServer.add_player(pid, "harry")
:ok
iex(4)> GameServer.add_player(pid, "ralph")
:ok
iex(5)> GameServer.add_player(pid, "tom")
:ok
iex(6)> GameServer.add_player(pid, "richard")
{:error, :max_players}
```


## Скрытое состояние гонки

В&nbsp;интерактивной оболочке это работает, но&nbsp;при развёртывании в&nbsp;продакшн вы&nbsp;можете столкнуться с&nbsp;тем, что время от&nbsp;времени каждый 5-й или 6-й игрок будет входить в&nbsp;игру вне очереди. А&nbsp;вот и&nbsp;состояние гонки! Докажем это, реализовав временную функцию в&nbsp;GameServer, которая добавляет n&nbsp;игроков одновременно:

```elixir
defmodule GameServer do
  # ...
  def add_players_simultaneously(pid, nicks) do
    Enum.each(nicks, fn nick ->
      Task.async(fn ->
        GameServer.add_player(pid, nick)
      end)
    end)
  end
  # ...
end
```

Данная функция обращается к&nbsp;списку ников и&nbsp;параллельно с&nbsp;этим вызывает `add_player`, используя отдельный процесс для каждого ника. Предположим, пятеро игроков пытаются присоединиться к&nbsp;игре.

```elxiir
iex(1)> {:ok, pid} = GameServer.start_link
{:ok, #PID<0.100.0>}
iex(2)> nicks =  ["ben", "harry", "ralph", "tom", "richard"]
["ben", "harry", "ralph", "tom", "richard"]
iex(3)> GameServer.add_players_simultaneously(pid, nicks)
:ok
iex(4)> GameServer.get_state(pid)
%Game{players: ["richard", "tom", "ralph", "harry", "ben"]}
```

Подождите, каким образом в&nbsp;список попал `richard`?

Модель процессов Erlang прекрасно справится с&nbsp;конкурентными операциями над состоянием, и, если всё сделать правильно, ошибки практически исключены. При выполнении операций для модифицирования состояния, вам просто нужно мыслями находиться на&nbsp;шаг впереди.

Чтобы увидеть, как это работает, добавим несколько операторов puts в&nbsp;функцию `GameServer.add_player`.

```elixir
defmodule GameServer do
  # ...
  def add_player(pid, nick) do
    game = get_state(pid)
    IO.puts("Players in game: #{inspect game.players}")
    if Game.max_players?(game) do
      {:error, :max_players}
    else
      IO.puts("Add player #{nick}")
      GenServer.call(pid, {:add_player, nick})
    end
  end
  # ...
end
```

А&nbsp;теперь снова запустим.

```elixir
iex(1)> {:ok, pid} = GameServer.start_link
{:ok, #PID<0.119.0>}
iex(2)> nicks =  ["ben", "harry", "ralph", "tom", "richard"]
["ben", "harry", "ralph", "tom", "richard"]
iex(3)> GameServer.add_players_simultaneously(pid, nicks)
Players in game: []
Players in game: []
Players in game: []
Players in game: []
Players in game: []
:ok
Add player ben
Add player harry
Add player ralph
Add player tom
Add player richard
```

Это типичное состояние гонки **&laquo;проверь-затем-действуй&raquo;** (check-then-act). Важно помнить, что GenServer обрабатывает по&nbsp;одному сообщению из&nbsp;почтового ящика в&nbsp;порядке их&nbsp;получения. Например, приходят пять сообщений `get_state`, GenServer обрабатывает их&nbsp;и&nbsp;возвращает текущее состояние. При этом игроки видят устаревшее состояние, каждый из&nbsp;них пытается войти в&nbsp;игру, и&nbsp;поступают ещё пять сообщений.

Чтобы это исправить, нужно превратить операцию `add_player` в&nbsp;[атомарную](http://wiki.osdev.org/Atomic_operation). С&nbsp;GenServer это сделать достаточно просто, так как всё, что происходит в&nbsp;функции обратного вызова, в&nbsp;нём по&nbsp;умолчанию атомарно! Всё, что нам остаётся сделать,&nbsp;&mdash; это перенести эту логику в&nbsp;функцию обратного вызова `add_player`.

```elixir
defmodule GameServer do
  # ...

  # Removed the max_players? check
  def add_player(pid, nick) do
    GenServer.call(pid, {:add_player, nick})
  end

  # ...

  # Checking inside the callback now
  def handle_call({:add_player, nick}, _from, game) do
    if Game.max_players?(game) do
      {:reply, {:error, :max_players}, game}
    else
      {:reply, :ok, Game.add_player(game, nick)}
    end
  end

  # ...
end
```

Попробуем ещё раз.

```elixir
iex(1)> {:ok, pid} = GameServer.start_link
{:ok, #PID<0.137.0>}
iex(2)> nicks =  ["ben", "harry", "ralph", "tom", "richard"]
["ben", "harry", "ralph", "tom", "richard"]
iex(3)> GameServer.add_players_simultaneously(pid, nicks)
:ok
iex(4)> GameServer.get_state(pid)
%Game{players: ["ralph", "tom", "harry", "ben"]}
```

Получаем устойчивое состояние, как и&nbsp;ожидалось! Если&nbsp;бы `richard` попытался присоединиться к&nbsp;игре, он&nbsp;бы получил ошибку max_players. В&nbsp;семантике `GenServer` примечательно&nbsp;то, что можно представить свой код в&nbsp;виде клиента и&nbsp;сервера. Все открытые API-функции, перечисленные в&nbsp;начале модуля, находятся в&nbsp;вызывающем процессе, то&nbsp;есть **на&nbsp;стороне клиента**, а&nbsp;все функции обратного вызова `handle_*` &mdash; в&nbsp;процессе GenServer или **на&nbsp;стороне сервера**. Если держать в&nbsp;голове такую модель, то&nbsp;сразу становится понятно, к&nbsp;какой стороне принадлежит ваш код.

## Узкие места

Конечно, есть искушение в&nbsp;целях безопасности скинуть всё на&nbsp;сервер, но&nbsp;не&nbsp;стоит забывать, что это скажется на&nbsp;производительности. Создавая функции обратного вызова, вы&nbsp;должны задать себе вопрос:

&laquo;Каково минимально возможное количество операций, которые мне необходимо выполнить, чтобы определить следующее состояние?&raquo;

Помните, что несколько обратных вызовов не&nbsp;могут происходить одновременно, что вполне может стать узким местом программы. Подумайте также, можно&nbsp;ли выполнить длительные операции (в&nbsp;частности сетевые операции) не&nbsp;в&nbsp;функциях обратного вызова, а&nbsp;где-то в&nbsp;другом месте.

## Комплексное решение

Несмотря на&nbsp;то, что в&nbsp;приведённом примере всё прекрасно работало, при разработке структуры Game была допущена ошибка. Создавая новую структуру данных, хорошо&nbsp;бы подумать о&nbsp;том, как предотвратить возможность приведения её&nbsp;в&nbsp;недопустимое состояние. Для обеспечения устойчивости состояния логика должна прослеживаться на&nbsp;уровне модуля. Работая с&nbsp;новой структурой, следует использовать только такой интерфейс для работы со&nbsp;структурами и&nbsp;возвращать ошибку, если что-то пошло не&nbsp;так. Можно изменить интерфейс модуля `Game` примерно следующим образом:

```elixir
defmodule Game do
  @max_players 4
  defstruct players: []

  def add_player(game, nick) do
    if max_players?(game) do
      {:error, :max_players}
    else
      {:ok, Map.update!(game, :players, &([nick | &1]))}
    end
  end

  defp max_players?(%{players: ps}) when length(ps) < @max_players, do: false
  defp max_players?(_game), do: true
end
```

Серверы скинут немного кода, но, думаю, это даже к&nbsp;лучшему. Можно почистить их&nbsp;ещё больше, например, с&nbsp;помощью [exactor](https://github.com/sasa1977/exactor).

*Изображение взято из игры [Cosmic Race](https://play.google.com/store/apps/details?id=com.nanoo.cosmoracer&hl=ru).*