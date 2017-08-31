---
title: Декорируем функции с помощью макросов
excerpt: Рассказываем об использовании макросов в Эликсире. С их помощью создаём декораторы в функциональном стиле.
author: nadezhda
source_url: https://carlo-colombo.github.io/2017/06/10/Track-functions-call-in-Elixir-applications-with-Google-Analytics/
source_title: Decorate functions using macros in Elixir
source_author: Carlo Colombo
tags: [howto, macros]
cover: /assets/images/metaprogramming.png
---
Однажды передо мной стояла задача запустить в&nbsp;массы Telegram-бота для отслеживания времени прибытия автобусов в&nbsp;Дублине (@dublin_bus_bot). Перед этим я&nbsp;задумался, сколько людей будут им&nbsp;пользоваться (спойлер: почти нисколько), и&nbsp;я&nbsp;решил, что было&nbsp;бы неплохо отследить их&nbsp;количество с&nbsp;помощью Google Analytics.

## О&nbsp;решении

Протокол передачи статистических данных Google Analytics позволяет отслеживать данные не&nbsp;только веб-сайтов, но&nbsp;и&nbsp;мобильных приложений, программных решений для интернета вещей и&nbsp;др. На&nbsp;данный момент для этого протокола не&nbsp;существует Elixir клиента, а&nbsp;когда он&nbsp;появится, то&nbsp;будет представлять собой ни&nbsp;что иное, как обёртку над API. Мой план заключался в&nbsp;том, чтобы посылать запросы на&nbsp;сервер Google Analytics с&nbsp;помощью [HTTPoison](https://github.com/edgurgel/httpoison), но&nbsp;хотелось&nbsp;бы избежать вызова функции отслеживания после каждой новой команды бота.

Что мне нравится в&nbsp;Elixir, так это макросы, позволяющие генерировать код на&nbsp;этапе компиляции. Мне в&nbsp;голову пришла идея написать макрос, использование которого похоже на&nbsp;объявление функции. Этот макрос определял&nbsp;бы функцию с&nbsp;таким&nbsp;же телом и&nbsp;дополнительным вызовом функции отслеживания. Этот подход показался мне более естественным для функциональной модели Elixir в&nbsp;сравнении со&nbsp;стандартным синтаксисом декораторов в&nbsp;других языках (`@decorator` в&nbsp;Python и&nbsp;Javascript).

```elixir
defmetered sample_function(arg1, arg2) do
    IO.inspect([arg1, arg2])
end
# would generate something similar to
def sample_function(arg1, arg2) do
    track(:sample_function, [arg1: arg1, arg2: arg2])
    IO.inspect([arg1, arg2])
end
```

## Реализация

Описанный выше подход был реализован в&nbsp;пакете [meter](https://hex.pm/packages/meter) для использования в&nbsp;созданном мной Telegram-боте.

```elixir
@doc """
Replace a function definition, automatically tracking every call to the function
on google analytics. It also track exception with the function track_error.
This macro intended use is with a set of uniform functions that can be concettualy
mapped to pageviews (eg: messaging bot commands).
Example:
    defmetered function(arg1, arg2), do: IO.inspect({arg1,arg2})
    function(1,2)
    
will call track with this parameters
    
    track(:function, [arg1: 1, arg2: 2])
Additional parameters will be loaded from the configurationd
"""
# A macro definition can use pattern matching to destructure the arguments
defmacro defmetered({function,_,args} = fundef, [do: body]) do
  # arguments are defined in 3 elements tuples
  # this extract the arguments names in a list
  names = Enum.map(args, &elem(&1, 0))
  # meter will contain the body of the function that will be defined by the macro
  metered = quote do
    # quote and unquote allow to switch context,
    # simplyfing a lot quoted code will run when the function is called
    # unquoted code run at compile time (when the macro is called)
    values = unquote(
      args
      |> Enum.map(fn arg ->  quote do
          # allow to access a value at runtime knowing the name
          # elixir macros are hygienic so it's necessary to mark it
          # explicitly
          var!(unquote(arg))
        end
      end)
    )
    # Match argument names with their own values at call time
    map = Enum.zip(unquote(names), values)
    # wrap the original function call with a try to track errors too
    try do
      to_return = unquote(body)
      track(unquote(function), map)
      to_return
    rescue
      e ->
        track_error(unquote(function), map, e)
        raise e
    end
  end
  # define a function with the same name and arguments and with the augmented body
  quote do
    def(unquote(fundef),unquote([do: metered]))
  end
end
```

## Заключение

Макросы Elixir&nbsp;&mdash; мощный инструмент для расширения функциональности приложений и&nbsp;создания DSL. Несмотря на&nbsp;то, что их&nbsp;изучение займёт какое-то время, это полностью оправданно, ведь они помогут вам навести порядок в&nbsp;своём коде.