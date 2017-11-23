---
title: Работаем с биткоином на Elixir. Часть 1
excerpt: В данной статье рассматривается создание простейшего обозревателя блокчейна с помощью Phoenix. Поехали!
author: nadezhda
source_url: https://medium.com/@east5th/controlling-a-bitcoin-node-with-elixir-6dd36e3adf3d
source_title: Controlling a Bitcoin Node with Elixir
source_author: Pete Corey 
tags: [blockchain, overview, phoenix]
cover: /assets/images/blockchain.png
---
Недавно меня с головой захватил волшебный [мир биткоин](https://bitcoin.org/ru/). Жажде знаний не было предела, и утолить её помогла замечательная книга [«Mastering Bitcoin»](https://www.amazon.com/gp/product/1449374042/) Андреаса Антонопулоса и полное погружение в биткоин-разработку. Книга подробно освещает технические основы биткоин, но ничто так не помогает в изучении нового дела, как практика.

Простенькое приложение на Эликсире для управления полной биткоин-нодой и связи с ней через [интерфейс JSON-RPC](https://en.bitcoin.it/wiki/API_reference_%28JSON-RPC%29), по-моему, -- отличный «Hello, World!». Поехали!

## Где взять полную ноду


Чтобы установить соединение с полной нодой Bitcoin Core, нужно сначала где-то её раздобыть. Достаточно просто [запустить свою ноду локально](https://bitcoin.org/en/full-node), ведь общедоступные ноды с открытым JSON-RPC интерфейсом можно пересчитать по пальцам.

[Установим демона `bitcoind`](https://bitcoin.org/en/full-node#osx-daemon) и настроим его в файле `bitcoin.config`:

```
rpcuser=<username>
rpcpassword=<password>
```

Определяемые значения `<username>` и `<password>` будем использовать для аутентификации при отправке запросов к биткоин-ноде.

По завершении настройки самое время запустить полную ноду:

```
bitcoind -conf=<path to bitcoin.config> -daemon
```

Запустившись, демон полной ноды начнёт подключаться к пирам, загружать и верифицировать транзакции в блоках.

Убедимся, что всё работает как нужно:

```
bitcoin-cli getinfo
```

Данная команда возвратит основную информацию о ноде, включая её версию и количество полученных и верифицированных блоков. Загрузка и верификация всего блокчейна может занять несколько дней, ну а мы пока продолжим работать над нашим проектом.

## Интерфейс JSON-RPC


Биткоин-нода работает через интерфейс JSON-RPC, который можно использовать для извлечения информации о блокчейне и взаимодействия с нодой.

Любопытно, что инструмент `bitcoin-cli`, который мы использовали ранее для получения информации о ноде работает поверх JSON-RPC API. Список всех возможных RPC-команд ноды можно увидеть, вызвав `bitcoin-cli help` или полистав [Bitcoin Wiki](https://en.bitcoin.it/wiki/Original_Bitcoin_client/API_calls_list).

Протокол JSON-RPC получает входящие команды через HTTP-сервер, а значит, можно обойтись без `bitcoin-cli` и прописать эти RPC-команды самостоятельно.

Например, [`запустим getinfo вручную с помощью`curl`](https://bitcoin.stackexchange.com/a/19839):

```
curl --data-binary '{"jsonrpc":"1.0","method":"getinfo","params":[]}'\
     http://<user>:<pass>@localhost:8332/
```

Аналогичным образом можно выполнять такие команды в любой среде программирования с HTTP-клиентом, например, в Эликсире!

## Разработка Эликсир-приложения


Продумав стратегию взаимодействия с полной биткоин-нодой, займёмся Эликсир-приложением.

Создадим новый проект и обновим `mix.exs`, чтобы добавить в зависимости библиотеку [`poison`](https://hex.pm/packages/poison), которая понадобится для шифрования и расшифровки JSON-объектов, и [`httpoison`](https://hex.pm/packages/httpoison) -- один из лучших HTTP-клиентов для Эликсира.

```elixir
defp deps do
  [
    {:httpoison, "~> 0.13"},
    {:poison, "~> 3.1"}
  ]
end
```

Теперь, когда мы закончили с частью, отвечающей за кодогенерацию, перейдём к реализации взаимодействия с биткоин-нодой.

Начнём работать с модулем `HelloBitcoin` и первым делом поставим заглушку для функции `getinfo`:

```elixir
defmodule HelloBitcoin do

  def getinfo do
    raise "TODO: Implement getinfo"
  end

end
```

Для простоты будем взаимодействовать с этим модулем через `iex -S mix`. Прежде чем приступить к следующему шагу, давайте убедимся, что всё работает правильно.

Вызов заглушки `HelloBitcoin.getinfo` должен повлечь за собой исключение времени выполнения:

```elixir
iex(1)> HelloBitcoin.getinfo
HelloBitcoin.getinfo
** (RuntimeError) TODO: Implement getinfo
    (hello_bitcoin) lib/hello_bitcoin.ex:4: HelloBitcoin.getinfo/0
```

Отлично. Ошибка. Как и должно быть.

## Построение команды `GetInfo`


Теперь наполним функцию `getinfo` содержимым.

Повторюсь: нам необходимо послать HTTP-запрос методом `POST` к HTTP-серверу биткоин-ноды (обычно слушающему по `http://localhost:8332`) и передать JSON-объект, содержащий команду `GetInfo` и необходимые параметры.

Оказалось, что `httpoison` справляется с таким заданием в два счёта:

```elixir
def getinfo do
  with url     <- Application.get_env(:hello_bitcoin, :bitcoin_url),
       command <- %{jsonrpc: "1.0", method: "getinfo", params: []},
       body    <- Poison.encode!(command),
       headers <- [{"Content-Type", "application/json"}] do
    HTTPoison.post!(url, body, headers)
  end
end
```

Сначала получим `url` из ключа `bitcoin_url` в конфигурации приложения. Адрес должен находиться в файле `config/config.exs` и указывать на локальную ноду:

```elixir
config :hello_bitcoin, bitcoin_url: "http://<user>:<password>@localhost:8332"
```

Далее, создадим словарь, представляющий нашу JSON-RPC-команду. В данном случае в поле `method` прописываем `"getinfo"`, а поле `params` оставляем пустым. И последнее, сформируем тело запроса, преобразовав команду в формат JSON с помощью `Poison.encode!`.

Вызов `HelloBitcoin.getinfo` должен возвратить успешный ответ от биткоин-ноды с кодом состояния `200`, а также результат команды `getinfo` в формате JSON:

```elixir
%HTTPoison.Response{
  body: "{\"result\":{\"version\":140200,\"protocolversion\":70015,\"walletversion\":130000,\"balance\":0.00000000,\"blocks\":482864,\"timeoffset\":-1,\"connections\":8,\"proxy\":\"\",\"difficulty\":888171856257.3206,\"testnet\":false,\"keypoololdest\":1503512537,\"keypoolsize\":100,\"paytxfee\":0.00000000,\"relayfee\":0.00001000,\"errors\":\"\"},\"error\":null,\"id\":null}\n",
  headers: [{"Content-Type", "application/json"}, {"Date", "Thu, 31 Aug 2017 21:27:02 GMT"}, {"Content-Length", "328"}],
  request_url: "http://localhost:8332",
  status_code: 200
}
```

Прекрасно.

Расшифруем полученный JSON-текст в `body` и получим результат:

```elixir
HTTPoison.post!(url, body)
|> Map.get(:body)
|> Poison.decode!
```

Теперь результаты вызова `HelloBitcoin.getinfo`, полученные от `bitcoind`, будут представлены в более удобном виде:

```elixir
%{"error" => nil, "id" => nil,
  "result" => %{"balance" => 0.0, "blocks" => 483001, "connections" => 8,
    "difficulty" => 888171856257.3206, "errors" => "",
    "keypoololdest" => 1503512537, "keypoolsize" => 100, "paytxfee" => 0.0,
    "protocolversion" => 70015, "proxy" => "", "relayfee" => 1.0e-5,
    "testnet" => false, "timeoffset" => -1, "version" => 140200,
    "walletversion" => 130000}}
```

Обратите внимание, что необходимые нам данные (`"result"`), обернуты в словарь, содержащий метаданные о самом запросе. Эти метаданные содержат строку с возможной ошибкой и идентификатор запроса.

Перепишем функцию `getinfo` так, чтобы она включала обработку ошибок и возвращала фактические данные в случае безошибочного выполнения запроса:

```elixir
with url <- Application.get_env(:hello_bitcoin, :bitcoin_url),
     command <- %{jsonrpc: "1.0", method: "getinfo", params: []},
     {:ok, body} <- Poison.encode(command),
     {:ok, response} <- HTTPoison.post(url, body),
     {:ok, metadata} <- Poison.decode(response.body),
     %{"error" => nil, "result" => result} <- metadata do
  result
else
  %{"error" => reason} -> {:error, reason}
  error -> error
end
```

Теперь при отсутствии ошибок функция `getinfo` будет возвращать кортеж `{:ok, result}`, содержащий результат RPC-вызова, а в обратном случае мы получим кортеж `{:error, reason}` с описанием ошибки.

## Обобщение команд

В похожей манере можно реализовать и другие RPC-команды блокчейна, например, `getblockhash`:

```elixir
def getblockhash(index) do
  with url <- Application.get_env(:hello_bitcoin, :bitcoin_url),
       command <- %{jsonrpc: "1.0", method: "getblockhash", params: [index]},
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

Вызвав `getblockhash` с нулевым индексом, получим [первый блок цепочки](https://en.bitcoin.it/wiki/Genesis_block).

```elixir
HelloBitcoin.getblockhash(0)

{:ok, "000000000019d6689c085ae165831e934ff763ae46a2a6c172b3f1b60a8ce26f"}
```

Функция `getblockhash` работает верно, и она практически идентична функции `getinfo`.

Чтобы избежать дублирования кода, выделим общую функциональную часть в новую вспомогательную функцию `bitcoin_rpc`:

```elixir
defp bitcoin_rpc(method, params \\ []) do
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

Теперь переопределим функции `getinfo` и `getblockhash` в соответствии с функцией `bitcoin_rpc`:

```elixir
def getinfo, do: bitcoin_rpc("getinfo")

def getblockhash(index), do: bitcoin_rpc("getblockhash", [index])
```

Можно видеть, что `bitcoin_rpc` представляет собой полноценный RPC-интерфейс для биткоин, позволяющий с лёгкостью выполнять любые RPC-команды.

Если вам интересно попробовать осуществить всё вышеперечисленное на своей машине, то исходники проекта можно [найти на GitHub](https://github.com/pcorey/hello_bitcoin).

## Заключение

Ну вот и подошла к концу достаточно длинная статья, объясняющая относительно простую идею. Полная нода биткоин предоставляет интерфейс JSON-RPC, доступ к которому можно получить, используя любой язык (например, Эликсир) или стек. Биткоин-разработка -- удивительно занимательная вещь, в которую интересно углубиться ещё сильнее.

Следующая часть серии статей о работе с биткоином на Эликсире [по ссылке](https://wunsh.ru/articles/bitcoin-blockchain-with-elixir-and-phoenix-part-2.html).