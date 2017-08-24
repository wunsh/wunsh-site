---
title: Оптимизация Elixir- и Phoenix-приложений с помощью ETS
excerpt: Статья про оптимизацию кода на Эликсире с помощью инструмента под названием ETS.
author: nadezhda
source_url: https://dockyard.com/blog/2017/05/19/optimizing-elixir-and-phoenix-with-ets
source_title: Optimizing Your Elixir and Phoenix Projects with ETS
source_author: Chris McCord
tags: [ets]
cover: /assets/images/ets.png
---
Многие Elixir-разработчики наверняка слышали о&nbsp;&laquo;ETS&raquo; или встречали в&nbsp;коде вызовы Erlang-модуля `:ets`, но, скорее всего, большинство из&nbsp;них всё ещё никогда не&nbsp;применяли этот подход на&nbsp;практике. Настало время это изменить.

**ETS (Erlang Term Storage)**&nbsp;&mdash; один из&nbsp;инструментов Erlang, который всё это время прятался на&nbsp;видном месте. Такие проекты, как `Phoenix.PubSub`, `Phoenix.Presence` и&nbsp;`Registry`, наряду с&nbsp;многочисленными Elixir- и&nbsp;Erlang-модулями пользуются преимуществами ETS. В&nbsp;двух словах: ETS&nbsp;&mdash; это хранилище данных с&nbsp;быстрым доступом для объектов Elixir и&nbsp;Erlang, главной особенностью которого является возможность получения состояния за&nbsp;пределами процесса и&nbsp;без передачи сообщений. Прежде чем перейти к&nbsp;вопросу об&nbsp;уместности использования ETS, пробежимся по&nbsp;основам основ, запустив `iex`.

Сначала создадим ETS-таблицу с&nbsp;помощью команды `:ets.new/2`:

```elixir
iex> tab = :ets.new(:my_table, [:set])
8211
```

Ничего сложного. Мы&nbsp;создали таблицу типа `:set`, которая позволит связывать уникальные ключи со&nbsp;значениями подобно обычному хранилищу &laquo;ключ-значение&raquo;. Добавим в&nbsp;неё парочку строк:

```elixir
iex> :ets.insert(tab, {:key1, "value1"})
true
iex> :ets.insert(tab, {:key2, "value1"})
true
```

Теперь, имея несколько значений, осуществим поиск: `elixir iex> :ets.lookup(tab, :key1) [key1: "value1"]`

Заметьте, что повторного связывания таблицы с&nbsp;новым значением после вставки элементов не&nbsp;происходит. ETS-таблицами управляет виртуальная машина, и&nbsp;их&nbsp;существование зависит от&nbsp;процесса, в&nbsp;котором они были созданы. На&nbsp;практике это можно увидеть, уничтожив текущий процесс `iex`:

```elixir
iex> Process.exit(self(), :kill)
** (EXIT from #PID<0.88.0>) killed

Interactive Elixir (1.4.4) - press Ctrl+C to exit (type h() ENTER for help)
iex> :ets.insert(8211, {:key1, "value1"})
** (ArgumentError) argument error
    (stdlib) :ets.insert(12307, {:key1, "value1"})
```

Как только это произойдет, прежние связи будут утеряны, но&nbsp;можно будет передать функции `:ets.new/2` возвращаемый вызовом идентификатор таблицы. Можно заметить, что когда мы&nbsp;запросили доступ к&nbsp;таблице, после того как её&nbsp;процесс-создатель был остановлен, возникла ошибка `ArgumentError`. Такая автоматическая чистка таблиц и&nbsp;данных после аварийного завершения процесса-создателя&nbsp;&mdash; одна из&nbsp;главных особенностей ETS. Незачем беспокоиться об&nbsp;утечках памяти, если процесс завершается после создания таблиц и&nbsp;ввода данных. Здесь вы&nbsp;столкнетесь с&nbsp;мистическим API `:ets` и&nbsp;его зачастую неинформативными ошибками (в&nbsp;нашем случае `ArgumentError`), не&nbsp;содержащими каких-либо намеков на&nbsp;то, что могло их&nbsp;породить. Но&nbsp;чем чаще вы&nbsp;будете работать с&nbsp;модулем `:ets`, тем лучше познакомитесь с&nbsp;этими досадными ошибками и&nbsp;изучите документацию `:ets` вдоль и&nbsp;поперёк.

Функции, которые мы&nbsp;использовали,&nbsp;&mdash; лишь малая часть того, что предлагает ETS. Помните, что основное его преимущество в&nbsp;быстром чтении и&nbsp;записи в&nbsp;хранилище &laquo;ключ-значение&raquo; и&nbsp;возможности сопоставления большинства содержащихся в&nbsp;таблице объектов, за&nbsp;исключением объектов типа map. В&nbsp;рамках этой статьи мы&nbsp;рассмотрим только простейшие пары &laquo;ключ-значение&raquo; и&nbsp;несколько основных операций поиска, поэтому для получения более подробной информации о&nbsp;возможностях ETS лучше обратиться к&nbsp;документации.

## Оптимизация доступа к&nbsp;GenServer с&nbsp;помощью ETS-таблицы

Оптимизация кода приносит свои плоды, особенно, когда не&nbsp;нужно менять публичный интерфейс. Рассмотрим один из&nbsp;часто используемых способов применения ETS для оптимизации доступа к&nbsp;состоянию, обёрнутому в&nbsp;`GenServer`.

Предположим, нужно разработать `GenServer` с&nbsp;ограничением скорости&nbsp;&mdash; процесс в&nbsp;приложении, который будет подсчитывать количество запросов пользователя и&nbsp;закрывать доступ к&nbsp;данным, если пользователем превышено определённое количество запросов в&nbsp;минуту. Очевидно, что состояние подсчета запросов пользователей и&nbsp;процесс, подчищающий это состояние раз в&nbsp;минуту, нужно будет где-то хранить. Наброски простейшего кода с&nbsp;`GenServer` выглядят примерно так:

```elixir
defmodule RateLimiter do
  use GenServer
  require Logger

  @max_per_minute 5
  @sweep_after :timer.seconds(60)

  ## Client

  def start_link do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def log(uid) do
    GenServer.call(__MODULE__, {:log, uid})
  end

  ## Server
  def init(_) do
    schedule_sweep()
    {:ok, %{requests: %{}}}
  end

  def handle_info(:sweep, state) do
    Logger.debug("Sweeping requests")
    schedule_sweep()
    {:noreply, %{state | requests: %{}}}
  end

  def handle_call({:log, uid}, _from, state) do
    case state.requests[uid] do
      count when is_nil(count) or count < @max_per_minute ->
        {:reply, :ok, put_in(state, [:requests, uid], (count || 0) + 1)}
      count when count >= @max_per_minute ->
        {:reply, {:error, :rate_limited}, state}
    end
  end

  defp schedule_sweep do
    Process.send_after(self(), :sweep, @sweep_after)
  end
end
```

Сначала определим функцию `start_link/0`, которая запустит `GenServer`, используя модуль `RateLimiter` в&nbsp;качестве модуля обратного вызова. Сервер назовём так&nbsp;же, как и&nbsp;модуль, чтобы впоследствии ссылаться на&nbsp;него при обращении к&nbsp;функции `log/1`. Теперь определим функцию `log/1`, осуществляющую синхронный вызов к&nbsp;`GenServer` и&nbsp;производящую логирование запросов пользователя. На&nbsp;выходе ожидаем получить либо `:ok`, сигнализирующее о&nbsp;том, что пользователь не&nbsp;превысил допустимое количество запросов и&nbsp;может продолжать свои действия, либо `{:error, :rate_limited}` в&nbsp;противном случае.

Далее в&nbsp;`init/1` вызываем функцию `schedule_sweep/0`, которая раз в&nbsp;минуту посылает серверу сообщения для удаления всех данных запросов. После этого определяем условие `handle_info/2`, чтобы перехватить событие `:sweep` и&nbsp;сбросить состояние запроса. И&nbsp;напоследок определяем условие `handle_call/3`, которое будет отслеживать состояние запроса пользователя и&nbsp;возвращать `:ok` или `{:error, :rate_limited}` вызывающей функции `log/2`.

Попробуем выполнить это в&nbsp;`iex`:

```elixir
iex> RateLimiter.start_link()
{:ok, #PID<0.126.0>}
iex> RateLimiter.log("user1")
:ok
iex> RateLimiter.log("user1")
:ok
iex> RateLimiter.log("user1")
:ok
iex> RateLimiter.log("user1")
:ok
iex> RateLimiter.log("user1")
:ok
iex> RateLimiter.log("user1")
{:error, :rate_limited}

13:55:44.803 [debug] Sweeping requests
iex(9)> RateLimiter.log("user1")
:ok
```

Работает! Если количество запросов пользователя в&nbsp;минуту превысит&nbsp;5, то&nbsp;сервер возвратит ожидаемое сообщение об&nbsp;ошибке. По&nbsp;прошествии некоторого времени вывод отладчика покажет сброс состояния, и&nbsp;счетчик количества запросов обнулится. Вроде неплохо, да? К&nbsp;сожалению, в&nbsp;приведённой выше реализации присутствуют серьёзные проблемы производительности. Давайте-ка разберёмся.

Поскольку нашей целью было ограничение количества запросов в&nbsp;единицу времени, *все запросы пользователя* должны проходить через заданный сервер. Сообщения обрабатываются последовательно, что сводит наше приложение в&nbsp;однопоточное, и&nbsp;этот единственный процесс превращается в&nbsp;узкое место программы.

## ETS спешит на&nbsp;помощь

К&nbsp;счастью, Erlang-разработчики уже придумали решение этой проблемы за&nbsp;нас. Можно провести рефакторинг кода, чтобы сервер использовал общедоступную ETS-таблицу и&nbsp;клиенты могли вводить свои запросы напрямую в&nbsp;ETS, а&nbsp;процесс-создатель отвечал&nbsp;бы только за&nbsp;очистку таблицы. Это позволит производить чтение и&nbsp;запись конкурентно и&nbsp;избавит от&nbsp;необходимости упорядочивания вызовов на&nbsp;сервере. Что&nbsp;ж, реализуем всё вышесказанное:

```elixir
defmodule RateLimiter do
  use GenServer
  require Logger

  @max_per_minute 5
  @sweep_after :timer.seconds(60)
  @tab :rate_limiter_requests

  ## Client

  def start_link do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def log(uid) do
    case :ets.update_counter(@tab, uid, {2, 1}, {uid, 0}) do
      count when count > @max_per_minute -> {:error, :rate_limited}
      _count -> :ok
    end
  end

  ## Server
  def init(_) do
    :ets.new(@tab, [:set, :named_table, :public, read_concurrency: true,
                                                 write_concurrency: true])
    schedule_sweep()
    {:ok, %{}}
  end

  def handle_info(:sweep, state) do
    Logger.debug("Sweeping requests")
    :ets.delete_all_objects(@tab)
    schedule_sweep()
    {:noreply, state}
  end

  defp schedule_sweep do
    Process.send_after(self(), :sweep, @sweep_after)
  end
end
```

Во-первых, сделаем так, чтобы функция `init/1` создавала ETS-таблицу с&nbsp;опциями `:named_table` и `:public`, тогда вызывающие функции вне процесса смогут получить к&nbsp;ней доступ. Также для оптимизации доступа воспользуемся функциями `read_concurrency` и&nbsp;`write_concurrency`. Далее, поправим функцию `log/1`, чтобы она записывала количество запросов напрямую в `:ets`, а&nbsp;не&nbsp;через `GenServer`. Таким образом, запросы сами будут отслеживать, не&nbsp;превышен&nbsp;ли на&nbsp;них лимит. Кроме этого будем использовать свойство ETS `update_counter/4`, что позволит нам обновлять счетчик быстро и&nbsp;атомарно. После проверки предельного значения в&nbsp;вызывающую функцию будет передано то&nbsp;же число, что и&nbsp;раньше. И&nbsp;последнее, в&nbsp;обратном вызове `:sweep` для очистки таблицы будем использовать `:ets.delete_all_objects/1`.

Ну, что, попробуем?

```elixir
iex> RateLimiter.start_link
{:ok, #PID<0.124.0>}
iex> RateLimiter.log("user1")
:ok
iex> RateLimiter.log("user1")
:ok
iex> RateLimiter.log("user1")
:ok
iex> RateLimiter.log("user1")
:ok
iex> RateLimiter.log("user1")
:ok
iex> RateLimiter.log("user1")
{:error, :rate_limited}
iex> :ets.tab2list(:rate_limiter_requests)
[{"user1", 7}]
iex> RateLimiter.log("user2")
:ok
iex> :ets.tab2list(:rate_limiter_requests)
[{"user2", 1}, {"user1", 7}]

14:27:19.082 [debug] Sweeping requests

iex> :ets.tab2list(:rate_limiter_requests)
[]
iex> RateLimiter.log("user1")
:ok
```

И&nbsp;снова всё работает. Для отслеживания данных в&nbsp;таблице можно использовать `:ets.tab2list/1`. Можно видеть, что механизмы подсчета запросов пользователей и&nbsp;очистки таблицы работают верно.

Вот, пожалуй, и&nbsp;всё. Публичный интерфейс остался нетронутым, а&nbsp;производительность важнейшей функции в&nbsp;приложении значительно возросла. Здорово, правда?

## TERRA INCOGNITA

В&nbsp;данной статье мы&nbsp;затронули лишь часть необозримых возможностей ETS. Но&nbsp;прежде чем эти возможности затуманят ваш разум и&nbsp;вы&nbsp;решите перенести весь код с&nbsp;последовательным доступом к&nbsp;данным из&nbsp;`GenServer` и&nbsp;`Agent` в&nbsp;ETS, хорошенько подумайте о&nbsp;том, какие действия в&nbsp;ваших приложениях атомарны, а&nbsp;какие требуют последовательной обработки. В&nbsp;погоне за&nbsp;производительностью, разрешив конкурентные чтение и&nbsp;запись, можно с&nbsp;лёгкостью заполучить состояние гонки.

Одна из&nbsp;выигрышных особенностей процессной модели Elixir&nbsp;&mdash; это последовательная обработка сообщений, позволяющая избежать состояния гонки путём упорядочивания доступа к&nbsp;состоянию, требующему атомарных операций. В&nbsp;случае с&nbsp;нашим примером, каждый пользователь производит запись в&nbsp;ETS с&nbsp;помощью атомарной операции `update_counter`, поэтому конкурентная запись не&nbsp;вызывает проблем. Для определения возможности перехода от&nbsp;последовательного доступа к&nbsp;ETS пользуйтесь следующими правилами:

* Операции должны быть атомарными. Если клиенты осуществляют чтение данных из&nbsp;ETS в&nbsp;одной операции, то, записывая напрямую в&nbsp;ETS, вы&nbsp;получите состояние гонки, и&nbsp;выходом из&nbsp;этой ситуации будет последовательный доступ к&nbsp;данным на&nbsp;сервере.

* Если операции не&nbsp;атомарные, сделайте так, чтобы разные процессы производили запись в&nbsp;разные ключевые поля. Например, реестр Elixir в&nbsp;качестве ключей использует PID и&nbsp;позволяет изменять данные только текущему процессу. Таким образом, в&nbsp;системе гарантированно не&nbsp;возникнет состояния гонки, т.&nbsp;к. каждый процесс будет обрабатывать разные строки ETS-таблицы.

* Если первые два подхода неприменимы, стоит рассматривать последовательное выполнение операций. Конкурентное считывание и&nbsp;последовательная запись&nbsp;&mdash; основная модель работы с&nbsp;ETS.

Если вам интересна тема применения ETS для свободного от&nbsp;зависимостей хранящегося в&nbsp;памяти кэша, обратите внимание на&nbsp;библиотеку [ConCache](https://github.com/sasa1977/con_cache).