---
title: Валидация URL на Elixir
excerpt: Открываем рубрику статей-сниппетов. В каждой из них описан небольшой фрагмент кода для решения конкретной задачи, который можно взять и сразу же добавить в своё приложение. Сегодня мы посмотрим на функцию для валидации URL.
author: jaroslav
source_url: https://sergiotapia.me/validate-valid-url-in-elixir-d5f8aef5964c
source_title: Validate valid URL in Elixir
source_author: Sergio Tapia
tags: [beginner, phoenix, snippet]
cover: /assets/images/url.png
---
Вместо полноценной статьи сегодня будет небольшой, но очень полезный фрагмент кода. Иногда бывает нужно понять валиден ли URL или нет.

Простой вариант решения этой задачи – использовать [функцию `URI.parse/1`](https://hexdocs.pm/elixir/URI.html#parse/1).

```elixir
defmodule MyApp.Helpers.UrlValidator do
  def valid_url(url) do
    case URI.parse(url) do
      %URI{scheme: nil} -> {:error, "No scheme"}
      %URI{host: nil} -> {:error, "No host"}
      _ -> {:ok, url}
    end
  end
end
```

Воспользоваться ей очень просто:

```elixir
MyApp.Helpers.UrlValidator.valid_url("https://google.com")
```

Функция вернёт либо `{:ok, "https://google.com"}`, либо `{:error, error_string}`.

Надеюсь это поможет!
