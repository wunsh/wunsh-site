---
title: Эликсир для джавистов. Часть третья 
excerpt: Как перейти с Джавы на Эликсир.
author: nadezhda
source_url: https://medium.com/skyhub-labs/elixir-for-java-developers-episode-iii-e2257c2da17f
source_title: Elixir for Java Developers, Episode III
source_author: Jusabe Guedes
tags: [beginner, overview]
cover: /assets/images/javalixir.png
---

Перевод заключительной части знакомства джавистов с Эликсиром.

## Интерфейсы vs поведения

В Джаве полиморфизм достигается путём использования интерфейсов, абстрактных классов и методов. В Эликсире на уровне модуля этому служат поведения, на уровне функций – протоколы.

Сравнивая два языка, можно провести параллель между интерфейсами Джавы и поведениями и протоколами Эликсира. Остановимся подробнее на поведениях.

```java
// Java
public interface Runner {
    boolean run(MyRunnable runnable);
    boolean stop();
}
```
```elixir
# Elixir
defmodule Runner do
  @callback run(runnable :: term) :: boolean
  @callback stop :: boolean
  
  def call(element) do
    IO.inspect element
  end
end
```

Как видите, они мало чем отличаются друг от друга. Необходимо задать типы входных и выходных данных. Единственное отличие в том, что поведение в Эликсире определено как модуль, но вместо реализации функций внутри объявим их, используя директиву `@callback`. Несмотря на это, определению функции ничего не мешает иметь и реализацию рядом с соответствующей директивой `@callback`. Функция `call` служит отличным примером.

С другой стороны, Джавы сразу обязывает к явному указанию интерфейса с помощью зарезервированного слова `interface`. Кроме того, внутри интерфейсов нельзя осуществлять реализацию методов, если только они не объявлены с ключевым словом default (в Джаве 8 и выше).

В обоих случаях код достаточно прост:

```java
// Java
class JobRunner implements Runner{
  public boolean run(MyRunnable runnable) {
    return true;
  }
  public boolean stop() {
    return true;
  }
}
```
```elixir
# Elixir
defmodule JobRunner do
  @behaviour Runner
  def run(runnable), do: true
  def stop, do: true
end
```

Поведения в Эликсире – это способ задания некоторого количества функций, которые, возможно, будут использованы динамически в зависимости от контекста. С точки зрения компилятора, интерфейсы и поведения имеют одно самое главное отличие. **В Джаве класс не будет скомпилирован, если не реализовать указанный интерфейс.**

```
JobRunner.java:2: error: JobRunner is not abstract and does not override abstract method stop() in Runner
```

В Эликсире на каждую нереализованную функцию, объявленную с помощью поведения, **высветится предупреждение**, и код продолжит выполняться.

```
warning: undefined behaviour function run/1 (for behaviour Runner)
warning: undefined behaviour function stop/0 (for behaviour Runner)
```

## Протоколы

Протоколы в Эликсире – отличный способ достижения полиморфизма на функциональном уровне. А именно, реализацию можно расширять на основе типа без необходимости изменения *интерфейсов*. Для наглядности рассмотрим простенький пример приветствия пользователей:

```elixir
# Elixir
defprotocol Greeting do
  @fallback_to_any true
  def hello(element)
end

defimpl Greeting, for: Integer do
  def hello(number), do: "Hello number #{number}."
end

defimpl Greeting, for: Map do
  def hello(map) do 
    keys = Map.keys(map)
    "Hello map! Your keys are #{inspect(keys)}."
  end
end

defimpl Greeting, for: Any do
  def hello(_any), do: "Hello! You can be anything."
end


# Here are some usage examples
iex(1)> Greeting.hello 5
"Hello number 5."

iex(2)> Greeting.hello %{first_name: "foo", last_name: "bar"}
"Hello map! Your keys are [:first_name, :last_name]"

iex(3)> Greeting.hello "foo"
"Hello! You can be anything."
```

Самый быстрый способ получения той же абстракции в Джаве – перегрузка метода `hello` внутри класса `Greeting`. Ниже можно увидеть, что такой подход может привести к наличию класса внушительного размера, содержащего несколько реализаций. Ещё один способ – создать интерфейс (или абстрактный класс), изначально прописываемый с дефолтной реализацией (a.k.a `Greeting<T>`).

```java
// Java
public class Greeting{
  public static String hello(Integer integer){
    return String.format("Hello number %d.", integer);
  }

  public static String hello(Object obj){
    return "Hello! You can be anything.";
  }
}

// Here are some usage examples
> Greeting.hello(5);
"Hello number 5."

> Greeting.hello("foo");
"Hello! You can be anything."
```

Да, способы получения протоколов в Джаве существуют, но вряд ли им впору тягаться с протоколами Эликсира. Используя интерфейсы, всё равно придётся создать некое подобие фабрики или конкретный класс и инстанцировать его. Протоколы же позволяют решить эту проблему заочно с помощью своей прозрачной реализации.

## Наследование vs композиция

**Прежде всего, наследования как такового в Эликсире не существует.** Правда, это совсем не проблема. В Эликсире существуют эффективные способы построения модулей: их можно создавать из других модулей или сделать так, чтобы **код генерировал сам себя**.

Даже взяв во внимание возможность реализации нескольких интерфейсов, в Джаве никак не получится осуществить наследования от нескольких предков, только от одного единственного класса. Элементарный пример:

```java
// Java
public class Bar {
  String bar(){
    return "bar";
  }
}

public class Foo extends Bar{
}

// Usage
> new Foo().bar();
"bar"
```

Теперь на Эликсире:

```elixir
# Elixir
defmodule Bar do
  defmacro __using__(_opts) do
    quote do
      def bar do
        "bar"
      end
    end
  end
end

defmodule Foo do
  use Bar
end

# Usage
iex(1)> Foo.bar
"bar"
```

Под `use Bar` подразумевается скрытый вызов макроса `__using__`, после чего целый блок будет внедрён в модуль `Foo`. Проще говоря, мы заставляем код создавать код, позволяя макросу `use` расширять модуль `Foo` во время компиляции.

Макросы в Эликсире настолько сильны, что заслуживают отдельной статьи. Конечно, если вам интересна эта тема, можете полистать книгу «Metaprogramming Elixir», где она рассматривается во всех подробностях.

На минутку забудем о макросах. Иногда необходимо сделать некоторые функции доступными внутри контекста, и для достижения этой цели можно импортировать сколько угодно модулей. Перепишем последний пример, заменив слово use на слово `import`, и посмотрим, что из этого выйдет:

```elixir
# Elixir
defmodule Bar do
  def bar do
    "bar"
  end
end

defmodule Foo do
  import Bar

  def call_bar do
    bar()
  end
end
```

Все макросы и функции модуля `Bar` теперь доступны модулю `Foo` без необходимости указания модуля `Bar`. Чтобы добиться того же в Джаве, можно воспользоваться оператором `import static` и представить, что функции в Эликсире – это своего рода статические методы.
