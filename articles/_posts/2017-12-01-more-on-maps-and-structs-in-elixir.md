---
title: Словари и структуры для новичков 
excerpt: Ещё немного про словари и структуры для новичков, которым оказалось мало документации.
author: nadezhda
source_url: http://whatdidilearn.info/2017/11/06/more-on-maps-and-structs-in-elixir.html
source_title: More on Maps and Structs in Elixir
source_author: Vitaly Tatarintsev
tags: [beginner]
cover: /assets/images/engine.png
---
Полагаем, вы уже прочитали раздел о [**Словарях**](/docs/keywords-and-maps.html) и [**Структурах**](/docs/structs.html) в документации. Настало время заглянуть немного дальше и научиться обновлять словари и добавлять в них новые значения.

## Словари

Допустим, есть следующий словарь:

```elixir
iex> john = %{ "first_name" => "John", "last_name" => "Doe", "age" => 35 }
%{"age" => 35, "first_name" => "John", "last_name" => "Doe"}
```

Представим, что у нашего Джона недавно был день рождения, а значит, необходимо обновить данные о его возрасте.

## Обновление словарей

Обновить словарь можно следующим образом:

```elixir
new_map = %{ old_map | key => value, ... }
```

Теоретически словарь в Elixir не может быть обновлён по причине иммутабельности данных. Значит, просто заменим словарь на новый.

```elixir
iex> john = %{ john | "age" => 36 }
%{"age" => 36, "first_name" => "John", "last_name" => "Doe"}
```

Недостаток (а может, и преимущество) данного метода состоит в том, что если указать несуществующий ключ, новое значение не будет добавлено в словарь.

```elixir
iex> john = %{ john | "title" => "Mr." }
** (KeyError) key "title" not found in: %{"age" => 36, "first_name" => "John", "last_name" => "Doe"}
    (stdlib) :maps.update("title", "Mr.", %{"age" => 36, "first_name" => "John", "last_name" => "Doe"})
    (stdlib) erl_eval.erl:255: anonymous fn/2 in :erl_eval.expr/5
    (stdlib) lists.erl:1263: :lists.foldl/3
```

## Добавление новых элементов

Для добавления новых элементов в словарь служит функция `Map.put_new/3`.

```elixir
iex> john = Map.put_new(john, "title", "Mr.")
%{"age" => 36, "first_name" => "John", "last_name" => "Doe", "title" => "Mr."}
```

Повторюсь, она не вносит изменения в текущий словарь, а создаёт совершенно новый. Работая с Elixir, не стоит забывать об иммутабельности. Итак, нам необходимо присвоить результат функции новой переменной. Кстати говоря, «присвоить» – не совсем верный термин для Elixir, если вы понимаете, о чём я.

Есть ещё одна функция, с помощью которой можно добавить новые значения в словарь – `Map.put/3`.

Стоит отметить, что она не только вставляет новые значения, но и обновляет уже существующие.

```elixir
iex> john = %{"age" => 35, "first_name" => "John", "last_name" => "Doe"}
%{"age" => 35, "first_name" => "John", "last_name" => "Doe"}

iex> john = Map.put(john, "title", "Mr.")
%{"age" => 35, "first_name" => "John", "last_name" => "Doe", "title" => "Mr."}

iex> john = Map.put(john, "age", "36")
%{"age" => "36", "first_name" => "John", "last_name" => "Doe", "title" => "Mr."}
```

В зависимости от поставленных задач, для добавления новых элементов в словарь можно использовать как `Map.put_new/3`, так и `Map.put/3`.

Разобравшись с обновлением и добавлением элементов, перейдём к вопросу об удалении из словаря определённых ключей.

## Удаление ключей

Функция `Map.delete/2` предназначена специально для этого.

```elixir
iex> john
%{"age" => 36, "first_name" => "John", "last_name" => "Doe", "title" => "Mr."}

iex> john = Map.delete(john, "title")
%{"age" => 36, "first_name" => "John", "last_name" => "Doe"}
```

Отлично. Теперь вы знаете, как работать со словарями. Отличная база для следующего пункта.

## Структуры

Структуры – что-то вроде оболочки над словарями, предоставляющей им дополнительную функциональность.

Возьмём тот же пример с Джоном и перепишем его, используя структуры: Чтобы объявить структуру, необходимо определить модуль, имя которого она позаимствует. Затем, используя ключевое слово `defstruct`, перечисляем доступные ключи.

```elixir
iex> defmodule Person do
...>   defstruct first_name: "", last_name: "", age: nil, adult: true
...> end
{:module, Person,
 <<70, 79, 82, 49, 0, 0, 8, 92, 66, 69, 65, 77, 65, 116, 85, 56, 0, 0, 0, 234,
   0, 0, 0, 22, 13, 69, 108, 105, 120, 105, 114, 46, 80, 101, 114, 115, 111,
   110, 8, 95, 95, 105, 110, 102, 111, 95, 95, ...>>,
 %Person{adult: true, age: nil, first_name: "", last_name: ""}}

iex> john = %Person{first_name: "John", last_name: "Doe", age: 35}
%Person{adult: true, age: 35, first_name: "John", last_name: "Doe"}

iex> bob = %Person{first_name: "Bob", age: 40}
%Person{adult: true, age: 40, first_name: "Bob", last_name: ""}
```

Объявив структуру в таком виде, мы определим поля, которые она будет иметь. Теперь у нас есть определённая структура атрибутов, и неуказанные ключи не могут быть использованы.

```elixir
iex> alice = %Person{first_name: "Alice", address: "White Hall Str. 503"}
** (KeyError) key :address not found in: %Person{adult: true, age: nil, first_name: "Alice", last_name: ""}
    (stdlib) :maps.update(:address, "White Hall Str. 503", %Person{adult: true, age: nil, first_name: "Alice", last_name: ""})
    iex: anonymous fn/2 in Person.__struct__/1
    (elixir) lib/enum.ex:1811: Enum."-reduce/3-lists^foldl/2-0-"/3
    expanding struct: Person.__struct__/1
    iex: (file)
```

## Обновление структур

Поскольку структура по сути представляет собой словарь, можно воспользоваться тем же способом:

```elixir
iex> john
%Person{adult: true, age: 35, first_name: "John", last_name: "Doe"}

iex> john = %Person{ john | age: 36 }
%Person{adult: true, age: 36, first_name: "John", last_name: "Doe"}
```

Следующий код тоже рабочий, хотя и выглядит немного непривычно:

```elixir
iex> john = Map.put(john, :age, 37)
%Person{adult: true, age: 37, first_name: "John", last_name: "Doe"}
```

Однако, если здесь попробовать использовать `Map.put_new/3` или `Map.delete/2` (что в принципе возможно), получим такой результат:

```elixir
iex> Map.put_new(john, :title, "Mr.")
%{__struct__: Person, adult: true, age: 37, first_name: "John",
  last_name: "Doe", title: "Mr."}
  
iex> Map.delete(john, :adult)
%{__struct__: Person, age: 37, first_name: "John", last_name: "Doe"}
```

## Определение структур
Ещё одно преимущество структур перед словарями состоит в том, можно определять функции внутри структур. Возможно, поэтому они и обёрнуты в модуль.

```elixir
iex> defmodule Person do
...>   defstruct first_name: "", last_name: "", age: nil
...>
...>   def has_discount?(person) do
...>     person.age != nil && person.age < 18
...>   end
...>
...>   def full_name(person) do
...>     "#{person.first_name} #{person.last_name}"
...>   end
...> end
{:module, Person,
 <<70, 79, 82, 49, 0, 0, 11, 192, 66, 69, 65, 77, 65, 116, 85, 56, 0, 0, 1, 89,
   0, 0, 0, 35, 13, 69, 108, 105, 120, 105, 114, 46, 80, 101, 114, 115, 111,
   110, 8, 95, 95, 105, 110, 102, 111, 95, 95, ...>>, {:full_name, 1}}

iex> john = %Person{first_name: "John", last_name: "Doe", age: 35}
%Person{age: 35, first_name: "John", last_name: "Doe"}

iex> Person.has_discount?(john)
false

iex> Person.full_name(john)
"John Doe"
```

## Заключение

Теперь ваш багаж знаний пополнился ещё немного. Что именно использовать в своих программах – структуры или словари – решать только вам. Если необходим чётко описанный тип с предопределённым набором атрибутов, выбирайте структуры. Хотите нечто анонимное с коротким жизненным циклом? Тогда используйте словари.

