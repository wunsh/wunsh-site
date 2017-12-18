---
title: Безболезненная эксплуатация через рефакторинг
excerpt: Эликсир – это не только модули и функции, но также и протоколы с поведениями. О том, как рефакторить код с помощью этих абстракций, читайте в статье.
author: nadezhda
source_url: https://blog.usejournal.com/beyond-functions-in-elixir-refactoring-for-maintainability-5c73daba77f3
source_title: "Beyond Functions in Elixir: Refactoring for Maintainability"
source_author: Dave Lucia
tags: [advanced, refactoring]
cover: /assets/images/refactoring.png
---

Как правило, новичкам рекомендуется организовывать код на Эликсире в модули и функции. Придумывайте хорошее именование функций, а схожие по решаемым проблемам функции группируйте в модули. Вот и вся магия. Но такой подход с ростом кодовой базы, может сильно усложнить код. В статье рассказываются приёмы для избежания подобных проблем на примере использования Феникса.

Рассмотрим создание блога на Эликсире и Фениксе пошагово. Блог состоит из множества постов, каждый из которых содержит заголовок, имя автора и текст.

```elixir
defmodule Blog.Post do
  use Blog.Web, :model
  schema “posts” do
    field :title, :string
    field :author, :string
    field :body, :string
  end
end
```

Создадим EEX-шаблон для рендеринга этих данных.

```html
<article>
  <header>
    <h1><%= @post.title %></h1>
    <address><%= @post.author %></address>
  </header>
  <section>
    <%= @post.body %>
  </section>
</article>
```

Отличное начало! Можно рендерить HTML-код с помощью структуры `%Blog.Post{}`, но чего-то тут явно недостаёт. Зачастую, вкладывая душу в свой пост, хочется в итоге получить что-то большее, чем один сухой абзац текста. А это, собственно, всё, на что мы пока способны. Хорошие новости: сообщество Эликсира усердно поддерживает [Markdown](https://github.com/h4cc/awesome-elixir#markdown) – облегчённый язык разметки, преобразующийся в HTML. Воспользуемся NIF-библиотекой [`cmark`](https://github.com/asaaki/cmark.ex), чтобы конвертировать Markdown в HTML.

```elixir
defmodule Blog.Web.PostView do
  @moduledoc "View for rendering posts"
  use Blog.Web, :view
  
  alias Blog.Markdown
  def render_markdown(binary) do
    Markdown.to_html(binary)
  end
end
defmodule Blog.Markdown do
  @moduledoc "Utility for rendering markdown -> html"
  def to_html(binary) when is_binary(binary) do
    Cmark.to_html(binary)
  end
  def to_html(_other), do: ""
end
```

Нужно изменить в шаблоне ещё кое-что.

```html
<section>
  <%# Convert the markdown -> HTML %>
  <%= render_markdown @post.body %>
</section>
```

Код выглядит довольно неплохо, но при если попробовать вывести первый пост:

![](https://cdn-images-1.medium.com/max/1600/1*CLCnOAFRokW59ZdDpLo53A.png)
    
Получаем экранированный HTML-код :(

Что же произошло? Если вызвать `render` в представлении и проанализировать результат, то можно увидеть кое-что интересное.

```elixir
iex(2)> Phoenix.View.render(Blog.Web.PostView, "show.html", post: post)
{:safe,
 [[[[[[["" | "<article>\n  <header>\n    <h1>"] | "First post"] |
      "</h1>\n    <address>"] | "Dave"] |
    "</address>\n  </header>\n  <section>\n"] |
   "&lt;p&gt;&lt;em&gt;Hello&lt;/em&gt; &lt;strong&gt;World&lt;/strong&gt;!&lt;/p&gt;\n"] |
  "  </section>\n</article>\n"]}
```

Феникс очень умён: вместо рендеринга HTML-кода в шаблоне, он возвращает экранированный HTML, который появляется на веб-странице. К сожалению, то, что рационально для вычислительных машин, не всегда приемлемо для разработчиков. Феникс подчищает вывод на шаблон и экранирует его, защищая от [нежелательных атак](https://en.wikipedia.org/wiki/Code_injection#HTML_script_injection). [Документация `Phoenix.View`](https://hexdocs.pm/phoenix/Phoenix.View.html#module-rendering) раскрывает это поведение следующим способом:

> Кортеж с пометкой `safe` означает, что шаблон безопасен и нет необходимости экранировать его содержимое, так как все данные уже закодированы.

Внешняя часть возвращаемого результата – кортеж `{:safe, iodata}`. Он сигнализирует Фениксу,
что содержимое кортежа было экранировано и выведено в виде
очищенного HTML. Под капотом Феникс вызывает функцию `Phoenix.HTML.html_escape` на приходящее в шаблон значение (если вам действительно интересно покопаться во внутренностях, начать можно [отсюда](https://github.com/phoenixframework/phoenix_html/blob/4dd3e3266d8810c7da05eba8ff9c80ac23163ca5/lib/phoenix_html/engine.ex#L73)).

Для того, чтобы Феникс передал HTML-код напрямую, можно воспользоваться функцией [`Phoenix.HTML.raw`](https://hexdocs.pm/phoenix_html/Phoenix.HTML.html#raw/1), которая обернёт код в кортеж `:safe` за вас. Немного преобразим реализацию функции `render_markdown`:

```elixir
def render_markdown(binary) do
  binary
  |> Markdown.to_html()
  |> Phoenix.HTML.raw() # Конвертирование в кортеж вида {:safe, iodata}
end
```

Теперь при преобразовании из Markdown в HTML текст передаётся в функцию `Phoenix.HTML.raw()`, предотвращающую экранирование этой части входных данных.

![](https://cdn-images-1.medium.com/max/1600/1*Bld7NHNgiO22GU8hpqFZAA.png)

```elixir
iex(2)> Phoenix.View.render(Blog.Web.PostView, "show.html", post: post)
{:safe,
 [[[[[[["" | "<article>\n  <header>\n    <h1>"] | "First post"] |
      "</h1>\n    <address>"] | "Dave"] |
    "</address>\n  </header>\n  <section>\n"] |
   "<p><em>Hello</em> <strong>World</strong>!</p>\n"] |
  "  </section>\n</article>\n"]}
```

Отличное начало Мы получили работающий блог, позволяющий форматировать содержимое постов без написания HTML вручную. Уже можно переносить его в продакшн, на какое-то время забыв о доработках. Эликсирщики уже привыкли к концепции модулей и функций. И в нашем случае она работает безотказно, но есть несколько «но». К примеру, текущая реализация никак не помешает пользователю ввести тег `<script`>. Конечно, для данного сценария использования мы можем допустить, что этого не случится.

В дальнейшем при развитии проекта он будет обрастать дополнительными бизнес-требованиями. Возможно, вам захочется расширить свой блог и добавить описание, поддерживающее Markdown. А может, создать индексную страницу, на которой показывались бы краткие описания постов, и домашнюю страницу, содержащую различные представления имеющихся данных. Продолжая размышлять о нововведениях, вы будете стараться обобщить существующие шаблоны для того, чтобы использовать их повторно для разных нужд.

```html
<section>
  <h1><%= @title %></h1>
  <div class="description">
    <%= @description %> <%# Wait is description markdown? %>
  </div>
</section>
```

Достигнув максимально возможного числа многократных использований шаблонов, подключив контексты и усложнив код до бесконечности,
отследить каждые введённые в шаблон данные становится гораздо сложнее. Вполне возможно, что на входе в `@description` окажется *простой текст* или *текст в формате Markdown*. Вот здесь-то и придётся поразмыслить о наличии иных вариантов, помимо модулей и функций.

## Добавляем протоколы

Из [документации Эликсира](/docs/protocols.html):

> Протоколы – это механизм для реализации полиморфизма в Эликсире. Обращение к протоколу доступно для любого типа данных, если этот тип реализует протокол.

[Понятие полиморфизма](http://bit.ly/2kgUOJg) относится к функциям, имеющим различные реализации для разных типов данных. Протоколы в Эликсире – своеобразное представление
полиморфизма, встроенное в язык. Сочетая такой полиморфизм и структуры, можно по-настоящему познать мощь языка. Функция протокола, получая на входе структуру, позволяет перейти в тело данной структуры.

В Эликсире прямо из коробки доступны несколько протоколов: [Collectable](https://hexdocs.pm/elixir/Collectable.html), [Enumerable](https://hexdocs.pm/elixir/Enumerable.html), [Inspect](https://hexdocs.pm/elixir/Inspect.html), [List.Chars](https://hexdocs.pm/elixir/List.Chars.html) и [String.Chars](https://hexdocs.pm/elixir/String.Chars.html).

Если вызвать `inspect` с каким-нибудь значением, Эликсир перенаправит в соответствующую реализацию протокола `Inspect` для заданного типа. Например, вызвав `inspect %{foo: :bar}`, мы перейдём в реализацию `Map` протокола `Inspect`. Использование протоколов напоминает сопоставление с образцом при наличии нескольких заголовков функций. Фактически, так оно и будет выглядеть, если код на Эликсир скомпилировать в режиме `production`.

Главное отличие протоколов от сопоставления различных значений с образцом – *инверсия управления*. Протоколы позволяют добавить больше [заголовков функций](/docs/modules-and-functions.html#именованные-функции), чтобы разработчики приложений и библиотек могли провести сопоставление нужных типов вне протокола.

Это особенно важно для нашего случая с Markdown-текстом. Феникс определяет собственный протокол – `Phoenix.HTML.Safe`.

> В целях обеспечения безопасности HTML в шаблонах Феникса для конвертации различных типов данных в строки не используется функция `Kernel.to_string/1`. Вместо этого в нём на основе структур данных реализован протокол Phoenix.HTML.Safe, гарантирующий возвращение HTML-код в безопасном виде.

Так это же замечательно! Достаточно создать структуру в модуле `Blog.Markdown` и реализовать под неё протокол `Phoenix.HTML.Safe`. Теперь, если понадобится отрендерить markdown-текст в шаблон, можно просто обернуть строку в структуру `%Blog.Markdown{}`, а всё остальное сделает протокол! Всё, что осталось сделать, – это немного подправить модуль `Markdown`, добавив в него структуру и реализацию протокола.

```elixir
defmodule Blog.Markdown do
  defstruct text: "", html: nil
  def to_html(%__MODULE__{html: html}) when is_binary(html) do
    html
  end
  def to_html(%__MODULE__{text: text}), do: to_html(text)
  def to_html(binary) when is_binary(binary) do
    Cmark.to_html(binary)
  end
  def to_html(_other), do: ""
  defimpl Phoenix.HTML.Safe do    
    def to_iodata(%Blog.Markdown{} = markdown) do
      Blog.Markdown.to_html(markdown)
    end
  end
end
```

После этого все поля `:string`, содежащие Markdown-текст в структуре `%Markdown{}` будут конвертироваться в HTML без лишних движений. Изначальный шаблон блога теперь будет выглядеть так:

```html
<article>
  <header>
    <h1><%= @post.title %></h1>
    <address><%= @post.author %></address>
  </header>
  <section>
    <%= @post.body %>
  </section>
</article>
```
```elixir
Phoenix.View.render(
  Blog.Web.PostView,
  "show.html", 
  post: %{post | body: %Blog.Markdown{text: post.body}}
)
```

Итак, проблема решена. Теперь шаблоны знают, когда стоит рендерить Markdown-текст, а когда нет. Как только шаблон получает входящее значение, Феникс вызывает `to_iodate`. Если это значение оказывается структурой `%Markdown{}`, оно будет автоматически преобразовано в HTML.

*Можно ли сделать лучше?*

Мы решили вопрос для шаблонов, но представления и модели, прежде чем передать данные в шаблон, всё ещё должны конвертировать содержимое поля `:body` в структуру `Markdown`. Что если автоматизировать и этот пункт?

## Поведение `Ecto.Type` спешит на помощь

На данный момент схема `Blog.Post` содержит три поля `:string`, которые представляют собой [примитивные типы `Ecto`](https://hexdocs.pm/ecto/Ecto.Schema.html#module-primitive-types). Ecto предоставляет крайне эффективную возможность: разработчики могут создавать собственные типы через [поведение `Ecto.Type`](https://hexdocs.pm/elixir/behaviours.html). Проще говоря, поведение – это контракт интерфейса. Если в собственном типе, основанном на примитиве, реализованы все колбеки `Ecto.Type`, Ecto преобразует содержимое поля в значение данного типа на входе и выходе базы данных.

Для того, чтобы при извлечении поста из базы данных его тело оборачивалось в структуру `%Markdown{}`, реализуем свой тип Ecto – `Blog.Markdown.Ecto`.

Начнём с обновления схемы `Blog.Post`.

```elixir
defmodule Blog.Post do
  use Blog.Web, :model
  alias Blog.Markdown
  schema “posts” do
    field :title, :string
    field :author, :string
    field :body, Markdown.Ecto # The custom Ecto.Type
  end
end
```

Первый шаг сделан, теперь самое время реализовать поведение, которое будет автоматически конвертировать `:body` в `%Blog.Markdown{}` при выполнении `post = Repo.get(Blog.Post, id)`.

В `Ecto.Type` необходимо реализовать четыре функции: [`cast`](https://hexdocs.pm/ecto/Ecto.Type.html#c:cast/1), [`dump`](https://hexdocs.pm/ecto/Ecto.Type.html#c:dump/1), [`load`](https://hexdocs.pm/ecto/Ecto.Type.html#c:load/1) и [`type`](https://hexdocs.pm/ecto/Ecto.Type.html#c:type/0).

**`Type`** определяет базовый тип поля `Markdown.Ecto`, то есть `:string`.

**`Load`** загружает данные из базы (поле `:body` типа `:string`) и возвращает структуру `%Markdown{}`. Примем допущение, что на этом этапе данные валидны.

**`Dump`** принимает структуру `%Markdown{}`, проверяет данные и возвращает `:string`.

**`Cast`** используется для приведения значений в `Ecto.Changeset` или для передачи аргументов в `Ecto.Query`. Она конвертирует допустимые типы в структуру `%Markdown{}`.

```elixir
defmodule Blog.Markdown.Ecto do
  alias Blog.Markdown
  @behaviour Ecto.Type
  
  @impl Ecto.Type  
  def type, do: :string 
  
  @impl Ecto.Type  
  def cast(binary) when is_binary(binary) do
    {:ok, %Markdown{text: binary}}
  end
  def cast(%Markdown{} = markdown), do: {:ok, markdown}
  def cast(_other), do: :error
  @impl Ecto.Type
  def load(binary) when is_binary(binary) do
    {:ok, %Markdown{text: binary, html: Markdown.to_html(binary)}}
  end
  def load(_other), do: :error
  @impl Ecto.Type
  def dump(%Markdown{text: binary}) when is_binary(bibary) do
    {:ok, binary}
  end
  def dump(binary) when is_binary(binary), do: {:ok, binary}
  def dump(_other), do: :error
end
```

После всех проделанных действий Markdown-текст будет переноситься непосредственно из базы данных в шаблон и превращаться в HTML без необходимости явного вызова функций `render_markdown` или осуществления приведения типов. Неявное поведение такого рода вполне оправданно, поскольку позволяет полностью избежать скрытых ошибок и постоянных проверок данных на соответствие формату Markdown.

Стоит ли усложнять своё приложение до такой степени ради повышения его эргономики? Решение только за вами, и его нужно хорошо обдумать. Помните, в большинстве случаев дублирование кода лучше, чем [неверная абстракция](https://www.sandimetz.com/blog/2016/1/20/the-wrong-abstraction). Поднабравшись опыта и досконально изучив предметную область проблемы, будет легче выбрать правильную абстракцию и принять уже  обоснованное решение.

