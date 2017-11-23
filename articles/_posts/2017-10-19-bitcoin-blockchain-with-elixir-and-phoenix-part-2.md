---
title: Работаем с биткоином на Elixir. Часть 2
excerpt: В данной статье рассматривается создание простейшего обозревателя блокчейна с помощью Phoenix. Поехали!
author: nadezhda
source_url: http://www.east5th.co/blog/2017/09/18/exploring-the-bitcoin-blockchain-with-elixir-and-phoenix/
source_title: Exploring the Bitcoin Blockchain with Elixir and Phoenix
source_author: Pete Corey 
tags: [blockchain, overview, phoenix]
cover: /assets/images/blockchain.png
---

В данной статье рассматривается создание простейшего обозревателя блокчейна с помощью Phoenix. Поехали!

## Кодогенерация проекта

Первым делом, создадим новый проект на Phoenix. Будем работать с [версией 1.3](https://habrahabr.ru/post/332898/) и пользоваться новыми генераторами, появившимися в ней:

```elixir
mix phx.new hello_blockchain --no-ecto
```

После создания приложения, добавим в него парочку новых маршрутов: один для просмотра заголовков блоков, другой — для просмотра блоков целиком:

```elixir
mix phx.gen.html Blockchain Header headers --no-schema
```

```elixir
mix phx.gen.html Blockchain Blocks blocks --no-schema
```

Обратите внимание на опции `--no-ecto` при генерации нового проекта и `--no-schema` при генерации содержимого блока и заголовка. Для просмотра блокчейна `Ecto` не понадобится, так как все данные для рендеринга будут храниться на полной ноде!

## Контекст блокчейна

Создавая заголовок и содержимое блоков, мы также сгенерировали модуль контекста блокчейна. Контекст будет выступать в качестве интерфейса для полной биткоин-ноды.

Ничего не напоминает?

Верно! Именно модуль контекста блокчейна был реализован в предыдущей статье. Удалим автоматически сгенерированное содержимое модуля `Blockchain` и скопируем функцию `bitcoin_rpc`.

```elixir
def bitcoin_rpc(method, params \\ []) do
  with url <- Application.get_env(:hello_bitcoin, :bitcoin_url),
       command <- %{jsonrpc: "1.0", method: method, params: params},
       {:ok, body} <- Poison.encode(command),
       {:ok, response} <- HTTPoison.post(url, body),
       {:ok, metadata} <- Poison.decode(response.body),
       %{"error" => nil, "result" => result} <- metadata do
    {:ok, result}
  else
    %{"error" => reason} -> {:error, reason}
    error -> error
  end
end
```

Обязательно добавим в зависимости `:httpoison` и `:poison` и укажем путь `:bitcoin_url` в файле конфигурации.

После этого добавим в модуль блокчейна четыре хелпера, которые будем использовать для выборки данных, необходимых для рендеринга обозревателя блокчейна:

```elixir
def getbestblockhash, do: bitcoin_rpc("getbestblockhash")
```

```elixir
def getblockhash(height), do: bitcoin_rpc("getblockhash", [height])
```

```elixir
def getblock(hash), do: bitcoin_rpc("getblock", [hash])
```

```elixir
def getblockheader(hash), do: bitcoin_rpc("getblockheader", [hash])
```

Переходим к маршрутам.

## Маршрутизация

Получив свежесгенерированные блоки и заголовки, добавим новые маршруты в маршрутизатор:

```elixir
scope "/", HelloBlockchainWeb do
  pipe_through :browser
  resources "/", PageController, only: [:index]
  resources "/blocks", BlockController, only: [:index, :show]
  resources "/headers", HeaderController, only: [:index, :show]
end
```

В данном случае будем работать с маршрутами `:index` и `:show` для блоков и заголовков.

Указав маршруты, переходим к рефакторингу модулей контроллера. Начнём с `BlockController`.

Нам предстоит удалить все функции контроллера, за исключением `index` и `show`, которые мы почти полностью перепишем.

Маршрут `/blocks/` начинается с функции контроллера `index`. Сделаем так, чтобы она перенаправляла на последние созданные блоки в цепочке:

```elixir
def index(conn, _params) do
  with {:ok, hash} <- Blockchain.getbestblockhash() do
    redirect(conn, to: block_path(conn, :show, hash))
  end
end
```

Воспользуемся `getbestblockhash`, чтобы получить хеш последнего подтверждённого блока, и перенаправим пользователя на маршрут `:show `вместе с итоговым хешем.

Функция контроллера `show` принимает полученный хеш в качестве аргумента, достаёт дополнительную информацию о блоке с полной ноды и рендерит блок, используя шаблон `show.html`:

```elixir
def show(conn, %{"id" => hash}) do
  with {:ok, block} <- Blockchain.getblock(hash) do
    render(conn, "show.html", block: block)
  end
end
```

Функция `index` контроллера `HeaderController` похожим образом перенаправляет пользователя на маршрут `:show` только что проверенного блока:

```elixir
def index(conn, _params) do
  with {:ok, hash} <- Blockchain.getbestblockhash() do
    redirect(conn, to: header_path(conn, :show, hash))
  end
end
```

Функция `show` получает необходимую информацию с помощью `Blockchain.getblockheader` и передаёт её в шаблон `show.html`:

```elixir
def show(conn, %{"id" => hash}) do
  with {:ok, block} <- Blockchain.getblockheader(hash) do
    render(conn, "show.html", block: block)
  end
end
```

Осталось реализовать ещё один маршрут. Когда пользователь запускает наше приложение впервые, он попадает на целевую страницу Phoenix. Сделаем так, чтобы вместо этого на экране появлялся заголовок последнего блока:

```elixir
def index(conn, _params) do
  with {:ok, hash} <- Blockchain.getbestblockhash() do
    redirect(conn, to: header_path(conn, :show, hash))
  end
end
```

Для получения хеша только что верифицированного блока из полной биткоин-ноды снова используем `Blockchain.getbestblockhash`. Хеш нужен для того, чтобы перенаправить пользователя на маршрут `:show` заголовка.

Прописав маршруты должным образом, можно получить данные о любом полном блоке или его заголовке, зная лишь его хеш.

А теперь перейдём к последней части головоломки: рендерингу полученных данных.

## Шаблоны

Реализованный выше обозреватель блокчейна безошибочно направляет пользователя к соответствующему маршруту `:show` запрашиваемого им блока или заголовка и передаёт все связанные с ним данные в шаблон для последующего рендеринга.

Всё, что осталось сделать, — это чуть-чуть перекроить шаблоны!

Чтобы не выходить за рамки данной статьи, интерфейс пользователя оставим настолько простым, насколько это возможно. Наиболее примитивный, но достаточный способ рендеринга блоков и заголовков — это рендеринг данных, полученных от контроллеров в виде блоков кода в формате JSON.

Это проще всего сделать, поместив результат `Poison.encode!` в DOM:

{% raw %}
```elixir
<code><%= Poison.encode!(@block, pretty: true) %></code>
```
{% endraw %}

Опция `pretty: true`, передаваемая в `Poison.encode!`, отвечает за надлежащее форматирование JSON-строки. В файле `app.css` необходимо определить свойство `white-space` для блоков `<code>`, чтобы сохранить форматирование:

{% raw %}
```css
code {
  white-space: pre !important;
}
```
{% endraw %}

Прекрасно.

![](https://s3-us-west-1.amazonaws.com/www.east5th.co/img/blockchain-viewer-01.png)

## Стандартный заголовок блока

Простенько, но со вкусом.

Вставив неструктурированные данные в формате JSON в DOM, мы добились высокой информативности результата, но не особо удобного в использовании интерфейса. Добавим нашему обозревателю блокчейна немного интерактивности.

Получаемые от полной биткоин-ноды блоки и заголовки содержат поля `previousblockhash` и `nextblockhash` (в большинстве случаев). Очевидно, данные хеши указывают на предыдущие и последующие блоки в цепочке соответственно. Превратим эти хеши в ссылки, чтобы пользователям было удобно переключаться с одного блока на другой.

Первое, что нужно сделать, – это создать функцию в соответствующем файле представления, конвертирующую хеши в ссылки. Функция `hash_link` в модуле `HeaderView` выглядит следующим образом:

```elixir
defp hash_link(hash), do: "<a href='/headers/#{hash}'>#{hash}</a>"
```

Используя эту функцию, создадим функцию для изменения заголовков блоков.  Сделаем так, чтобы она заменяла хеши в полях `previousblockhash` и `nextblockhash` на ссылки на блоки и записывала результат в формате JSON:

```elixir
def mark_up_block(block) do
  block
  |> Map.replace("previousblockhash", hash_link(block["previousblockhash"]))
  |> Map.replace("nextblockhash", hash_link(block["nextblockhash"]))
  |> Poison.encode!(pretty: true)
end
```

В HTML-шаблоне заменим содержимое блока `<code>` на результат функции `mark_up_block`:

```elixir
<code><%= raw(mark_up_block(@block)) %></code>
```

Обратите внимание, что `mark_up_block` необходимо обернуть в `raw`, чтобы HTML-код вставился в JSON в виде сырого кода, а не кодировался специальными символами.

Аналогично изменяем шаблоны `BlockView` и HTML, зачищаем шаблон макета и вносим последние штрихи в оформление страницы.
 
![](https://s3-us-west-1.amazonaws.com/www.east5th.co/img/blockchain-viewer-02.png)
 
Готово. Вот мы и получили простейший обозреватель блокчейна!

## И напоследок

Приведённый в статье пример, безусловно, лишь поверхностно иллюстрирует работу обозревателя блоков биткоина.

Проекты, связанные с биткоином, на данный момент представляют огромный интерес для многих разработчиков. При желании копнуть глубже на тему биткоин-разработки обратитесь к книге [«Mastering Bitcoin»](https://www.amazon.com/gp/product/1491954388) Андреаса Антонопулоса, отлично описывающей данный процесс.

Реализованный в данной статье обозреватель блокчейна будет обновляться и пополняться, а также вас ожидают другие проекты, связанные с биткоин. А пока мы этим занимаемся, вы можете подробнее ознакомиться с [нашим проектом на Github](https://github.com/wunsh/el_blocko).

Предыдущая часть серии статей о работе с биткоином на Эликсире [по ссылке](https://wunsh.ru/articles/bitcoin-blockchain-with-elixir-and-phoenix-part-1.html).