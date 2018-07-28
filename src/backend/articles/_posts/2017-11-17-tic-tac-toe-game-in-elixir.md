---
title: Делаем крестики-нолики на Эликсире
excerpt: В данной статье рассказывается о создании простой реализации игры крестики-нолики.
author: nadezhda
source_url: https://www.ynonperek.com/2017/10/30/hello-elixir-world/
source_title: Hello Elixir World
source_author: Ynon Perek
tags: [beginner, practical]
cover: /assets/images/ttt.png
---

В игре в крестики-нолики считывается ход каждого игрока, после чего запускается цикл, который прерывается при победе одного из игроков. Представляю свою версию одной партии игры:

```elixir
localhost:elxr ynonperek$ elixir game.elxrs 
. . . 
. . . 
. . . 
Next Move: 0,0
---
X . . 
. . . 
. . . 
Next Move: 0,1
---
X O . 
. . . 
. . . 
Next Move: 1,0
---
X O . 
X . . 
. . . 
Next Move: 1,1
---
X O . 
X O . 
. . . 
Next Move: 2,0
---
X O . 
X O . 
X . . 
Game Over, X Won
localhost:elxr ynonperek$ 
```

Разрабатывая игру на объектно-ориентированном языке, можно представить её в качестве объекта, прописав метод `play`. Состояние игры будет сохраняться в виде переменной экземпляра класса. В Ruby можно сделать, например, так:

```ruby
g = Game.new()
g.play(1, 1)
g.print_board()
```

Elixir – язык функциональный, и хранить данные в изменяемых структурах, увы, не получится. Поэтому, чтобы возвратить значение, в Elixir необходимо заменить метод `g.play` на следующее:

```elixir
g = Game.init
g = Game.play(g, 1, 1)
Game.print_board(g)
```

Иммутабельность – вот на что здесь стоит обратить внимание. Изменение происходит тогда, когда переменные обращаются к новым структурам данных.

## Ход игры

Структура данных игры выглядит как словарь хешей, содержащий информацию о текущем игроке и игровом поле:

```elixir
def init() do
    %{
      board: { ".", ".", ".", ".", ".", "." , ".", ".", "."  },
      player: "X"
    }
  end
```

Знак процента представляет собой хеш, так что те, кому знаком Perl, могут немного расслабиться.

Функция `play` – первое, что мне действительно понравилось в Elixir:

```elixir
 def play(g, idx) do
    cond do
      elem(g.board, idx) == "." ->
        %{
          g |
          player: next(g[:player]),
          board: put_elem(g.board, idx, g[:player])
        }

      true ->
        IO.puts "Sorry, that cell's taken"
        g
    end
  end
```

Поскольку все данные иммутабельны, `play` не сможет изменять структуру данных. Вместо этого она возвратит хеш с новым игроком и новым полем.

Новый игрок и новое поле, разумеется, связаны с предыдущими значениями. После каждого хода в выбранном квадрате появляется обозначение текущего игрока. Затем ход переходит к другому игроку.

В Elixir ключевое слово `cond` позволяет разбить функцию на несколько частей, соответствующих различным случаям (вышеприведённый алгоритм выполнится только если на поле будет свободный квадрат).

## Чья очередь?

Мы могли бы реализовать тернарную условную операцию, чтобы определить следующего игрока. Однако в Elixir можно зациклить список игроков и получить нужное значение:

```elixir
  def next(player) do
    Stream.cycle(["X", "O"]) |>
    Stream.drop_while(&(&1 == player)) |>
    Enum.at(0) 
  end
```

Цикл возвращает поток наподобие этого: `["X", "O", "X", "O", ...]`. Пайп-оператор в последней строке передаёт этот поток следующей по порядку функции, в нашем случае `drop_while`, которая возвращает первый элемент.

## Кто выиграл?

Так как в Elixir можно перегружать функции, нет необходимости придумывать функциям новые имена:

```elixir
def win?(g) do
  win?(g, "X") || win?(g, "O")
end

def win?(g, player) do    
  win?(g, player, 0, 1, 2) ||
  win?(g, player, 3, 4, 5) ||
  win?(g, player, 6, 7, 8) ||
  win?(g, player, 0, 3, 6) ||
  win?(g, player, 1, 4, 7) ||
  win?(g, player, 2, 5, 8) ||
  win?(g, player, 0, 4, 8) ||
  win?(g, player, 2, 4, 6)
end

def win?(g, player, i, j, k) do
  elem(g.board, i) == elem(g.board, j) &&
  elem(g.board, j) == elem(g.board, k) &&
  elem(g.board, i) == player &&
  player
end
```

Обратите внимание, что функции не обмениваются между собой состояниями, потому что все данные иммутабельны. Общие данные посылаются напрямую тем функциям, которым они необходимы.

Функции `elem` передаётся кортеж и значение счётчика, и она возвращает элемент, находящийся под заданным номером. Знак вопроса – допустимый символ в имени функции (привет, Ruby).

## Рекурсивные циклы

Последняя задача разработки – управление циклами. Классические циклы `for/while` в Elixir не представлены, значит, будем использовать рекурсивные вызовы вместо них. При оптимизации хвостовой рекурсии можно не беспокоиться о нехватке ресурсов.

```elixir
def gameloop(g) do
  Game.print_board(g)
  cond do
    winner = win?(g) ->
      IO.puts("Game Over, #{winner} Won")
    true ->
      [row, col] = read_move_from_user()
      g = Game.play(g, row, col)
      IO.puts("---")
      gameloop(g)
  end
end
```

## Полный исходный код

Писать игру на Elixir – очень увлекательное занятие, побуждающее к дальнейшему изучению языка, а также его веб-фреймворка Phoenix.

Далее можно найти полный исходный код описанной выше игры. Надеюсь, он вам пригодится и поможет ответить на некоторые технические вопросы:

```elixir
defmodule Game do

  def init() do
    %{
      board: { ".", ".", ".", ".", ".", "." , ".", ".", "."  },
      player: "X"
    }
  end

  def play(g, row, col) do
    play(g, row * 3 + col)
  end

  def play(g, idx) do
    cond do
      elem(g.board, idx) == "." ->
        %{
          g |
          player: next(g[:player]),
          board: put_elem(g.board, idx, g[:player])
        }

      true ->
        IO.puts "Sorry, that cell's taken"
        g
    end
  end

  def win?(g) do
    win?(g, "X") || win?(g, "O")
  end

  def win?(g, player) do    
    win?(g, player, 0, 1, 2) ||
    win?(g, player, 3, 4, 5) ||
    win?(g, player, 6, 7, 8) ||
    win?(g, player, 0, 3, 6) ||
    win?(g, player, 1, 4, 7) ||
    win?(g, player, 2, 5, 8) ||
    win?(g, player, 0, 4, 8) ||
    win?(g, player, 2, 4, 6)
  end

  def win?(g, player, i, j, k) do
    elem(g.board, i) == elem(g.board, j) &&
      elem(g.board, j) == elem(g.board, k) &&
        elem(g.board, i) == player &&
          player
  end

  def next("X"), do: "O"
  def next("O"), do: "X"
  
  def read_move_from_user do
    IO.gets("Next Move: ") |>
    String.trim |>
    String.split(",") |>
    Enum.map(&String.to_integer(&1))
  end

  def gameloop(g) do
    Game.print_board(g)
    cond do
      winner = win?(g) ->
        IO.puts("Game Over, #{winner} Won")

      true ->
        [row, col] = read_move_from_user()
        g = Game.play(g, row, col)
        IO.puts("---")
        gameloop(g)
    end
  end

  def print_board(g) do
    board = Enum.chunk_every(Tuple.to_list(g[:board]), 3)

    Enum.map board, fn(row) ->
      Enum.map row, fn(cell) ->
        IO.write(cell <> " ")
      end
      IO.puts ""
    end
  end  
end

g = Game.init
Game.gameloop(g)
```
