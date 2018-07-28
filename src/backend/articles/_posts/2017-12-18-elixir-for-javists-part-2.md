---
title: Эликсир для джавистов. Часть вторая 
excerpt: Как перейти с Джавы на Эликсир.
author: nadezhda
source_url: https://medium.com/skyhub-labs/elixir-for-java-developers-episode-ii-a75c368c6e13
source_title: Elixir for Java Developers, Episode II
source_author: Jusabe Guedes
tags: [beginner, overview]
cover: /assets/images/javalixir.png
---

Продолжаем знакомить джавистов с прекрасным Эликсиром.

## Поток управления

В Джаве существуют два основных способа управления ходом выполнения программы – операторы `if`/`else` и `switch`/`case`. Начнём с банального примера:

```java
// Java
if(x > 0){
  System.out.println("greater than zero");
}else if(x < 0){
  System.out.println("less than zero");
}else{
  System.out.println("zero");
}
```
```elixir
# Elixir
if x > 0 do
  IO.puts "greater than zero"
else 
  if x < 0 do
    IO.puts "less than zero"
  else
    IO.puts "zero" 
  end
end
```

Обратите внимание, что в Эликсире не существует конструкции `else if`, поэтому, чтобы связать несколько условий, придётся использовать второй `if` внутри `else`.

Спокойно! Есть и более изящный способ проверки нескольких логических выражений.

```elixir
# Elixir
cond do
 x > 0 ->
  IO.puts "greater than zero"
 x < 0 -> 
  IO.puts "less than zero"
 true ->
  IO.puts "zero" 
end
```

Структура `cond` проверяет каждое условие по порядку и выполняет первый блок, для которого выражение оказалось верным. Используя `true` в качестве последнего условия, получим точно такое же поведение, как у последнего `else` в Джаве, так как следующий после `true` код будет выполняться только тогда, когда все описанные выше условия ложны.

***От переводчиков:** не забывайте про мощное и нужное [средство для обработки потока управления](https://wunsh.ru/docs/mix-otp/docs-tests-and-with.html) в Эликсире под названием `with`.*   

Существует также и более характерный для Эликсира подход для проверки ложных условий – оператор `unless`, соответствующий `if(!expression)`. Чего в Эликсире не хватает, так это тернарного условного оператора (в Джаве он реализуется простейшей конструкцией с `?`). Взгляните на примеры:

```java
// Java
if(!isValid(x)){
  System.out.println("invalid");
}
int y = x > 0 ? x + 1 : x - 1;
```
``` elixir
# Elixir
unless is_valid(x), do: IO.puts "invalid"
if !is_valid(x), do: IO.puts "invalid"
y = if x > 0, do: x + 1, else: x - 1
```

Оператор Джавы `if` поддерживает только булевы выражения, в то время как структуры `if`/`unless`/`cond` Эликсира относят всё что между `nil` и `false` к `true`. Получается, что можно сделать так:

```elixir
# Elixir
x = "foo"
if x do
  IO.puts "bar"
end
y = nil
cond do
  y ->
    IO.puts "will never get here"
  true ->
    IO.puts "will be executed"
end
```

Ещё один спооб изменить поток управления в Джаве – это `switch`/`case`, который помимо непривлекательного формата записи имеет устаревшее поведение. Обычно достаточно выполнить только тот блок, который соответствует поставленному условию, но в Джаве в каждый case нужно добавить `break`, иначе все последующие блоки будут выполнены независимо от условия. Посмотрим, как это будет выглядеть на обоих языках:

```java
// Java
int x = 42;
switch (x) {
case 1:
case 2:
case 3:
  System.out.println("Hi");
  break;
case 4:
  System.out.println("Hello");
  break;
default:
  System.out.println("whatever");
}
```
```elixir
# Elixir
x = 42
case x do
  _ when x in [1, 2, 3]  -> 
    IO.puts "Hi"
  4 -> 
    IO.puts "Hello"
  "bla bla bla" ->
    IO.puts "Talking too much"
  _ ->
    IO.puts "this block will be executed"
end
```

Строго типизированный оператор `switch`/`case` признаёт только определённые типы результатов вычисления выражения: `String`, `char`, `byte`, `short`, `int` или `enum`. Кроме того, все значения, указанные в `case`, должны быть одного типа. Вы наверняка заметили, что в Эликсире такая строгость не приветствуется. Можно провести сопоставление с образцом и соотнести `x` с чем угодно, а если ничего не найдётся, то использовать нижнее подчёркивание. Символ `_` может означать что угодно.

Пиком различий между двумя языками является то, что в Эликсире все четыре оператора `if`/`unless`/`cond`/`case` имеют возвращаемое значение. Как и в функциях результат последней команды возвращается вызывающей функции, а если блок не был выполнен, то возвращается `nil`. Значит, можно записать:

```elixir
# Elixir
y = 
  cond do
    x == "foo" ->
      "bar"
    true ->
      "nothing"
  end
```

## Циклы

В Джаве можно перебирать коллекции или попросту организовать цикл for или `while` до тех пор, пока не выполнится какое-либо логическое выражение. В Эликсире такое невозможно.

В отличие от императивных языков, Эликсир, как функциональный язык, организует циклы полностью на рекурсии. Представьте, что `for`/`while` – это функция, которую нужно будет вызывать снова и снова, пока не выполнится определённое условие. Чтобы проиллюстрировать вышесказанное, создадим положительную функцию pow с помощью циклов:

```java
// Java
public long pow(long number, int times) {
  long acc = 1;
  for(int i = 1; i<=times; i++){
    acc *= number;
  }
  return acc;
}
```
```elixir
# Elixir
def pow(number, times), do:
  do_pow(number, times, 1)
defp do_pow(_, 0, acc), do: acc
defp do_pow(number, times, acc), do:
  do_pow(number, times-1, acc*number)
```

Сейчас сообразительный читатель наверняка подумал об ошибке `java.lang.StackOverflowError`, возникающей в случае необдуманного обращения с рекурсией. Для предотвращения данной ошибки в Эликсире реализуется оптимизация через хвостовой вызов. Данная опция достаточно многогранна, но если попытаться объяснить в одном предложении, то:

> Если последняя команда функции сама по себе является вызовом, то вместо загромождения стека выполнения последний фрейм заменяется новым фреймом.

И напоследок, нельзя не упомянуть о том, что в Эликсире всё же имеется особая форма цикла `for`. Это своеобразный синтаксический сахар: извлечь все значения из коллекции, осуществить из них выборку, а затем сгенерировать новую коллекцию, используя оставшиеся значения (a.k.a операция «`filter` и `map`»).

```elixir
# Elixir
#will produce [4, 9]
for x <- [0, 1, 2, 3], x > 1 do 
  x * x
end

# эквивалентно

[0, 1, 2, 3]
|> Enum.filter_map(&(&1 > 1), &(&1 * &1))
```

## Исключения

Принцип наследования не представлен в Эликсире, однако схема реализации собственных исключений довольно проста. Вместо своего сообщения об ошибке можно использовать сообщение по умолчанию.

```java
// Java
public class CustomException extends Exception{
  public CustomException(String message) {
    super(message);
  }
}
```
```elixir
# Elixir
defmodule CustomException do
  defexception message: "houston we have a problem"
end
```

В Джаве существуют классы `Error` и `Exception`, управлять которыми можно с помощью операторов `try`/`catch`/`finally`. В Эликсире отличий между ошибками и исключениями нет, и обрабатываются они похожим образом через `try`/`rescue`/`after`. **Все исключения в Эликсире можно сравнить с `RuntimeException` (непроверяемое), так как ни одно из них не требует явно реализованной проверки.** При отсутствии исключений дополнительно можно добавить выражение с `else`, соответствующее результату блока `try` (по типу `case`).

```java
// Java
try{
  throw new CustomException("Houston we have a problem");
}catch(NullPointerException | CustomException e){
  System.out.println(e.getMessage());
}catch(Exception e){
  System.out.println(e.getMessage());
}finally{
  System.out.println("finally");
}
```
```elixir
# Elixir
try do 
  #will raise an RuntimeError with the message bellow
  raise "Houston we have a problem"
rescue
  e in [RuntimeError, CustomException] -> 
    IO.puts e.message
  e -> 
    IO.puts e.message
else
  42 -> 
    //some code
  _ ->
    //some other code
after
  IO.puts "finally"
end
```

Есть в Эликсире и конструкция `try`/`throw`/`catch`, но она предназначена, скорее, для возвращения результата блока, а не для обработки исключений. Обычно она не используется, поскольку существуют более простые способы достижения того же результата. Они напоминают навязчивые выражения `break` внутри циклов в Джаве. Приведём пример:

```elixir
# Elixir
try do
  letter = "c"
  Enum.each ["a", "b", "c", "d"], fn(x) ->
    if letter == x, do: throw(x)
  end
catch
  x -> IO.puts x
end
```

Любопытно, что изменение значения переменных или объявление новых переменных внутри `try`/`catch`/`rescue`/`after` в Эликсире никак не влияет на внешний скоуп (как и в случае с функциями). Данный блок также возвращает результат, как и `if`. Для наглядности рассмотрим пример:

```elixir
# Elixir
what = "before try"
try do 
  what = "started try"
  raise "houston we have a problem"
rescue
  e -> 
    what = "rescue"
after
  what = "after"
end

# Выведет "before try"
IO.puts what
```

Чего действительно не хватает в Эликсире, так это конструкции `try-with-resource`. Например, открыв файл, закрыть его возможно только явным способом, как это было в старые-добрые времена до Java 7. Да, после удаления процесса все его файлы будут закрыты, но это явно не лучший метод работы с процессами с длительным временем выполнения.

