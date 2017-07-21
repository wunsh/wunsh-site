---
title: Способы замены строк в Elixir и их производительность
excerpt: Статья про производительность замены символов в строках на Elixir.
author: nadezhda
source_url: http://minhajuddin.com/2017/06/19/performance-variations-of-string-substitution-in-elixir/
source_author: Khaja Minhajuddin
tags: [advanced, overview]
cover: /assets/images/string_substitution.png
---
Однажды мне пришлось повозиться со&nbsp;строками в&nbsp;приложении, для производительности которого важны были доли секунды. Я&nbsp;решил протестировать несколько решений и&nbsp;сравнить их&nbsp;скоростные характеристики. Результаты получились *достаточно предсказуемые*.

```elixir
path = "/haha/index.html"
subdomain_rx = ~r(^\/[^\/]+)

Benchee.run(%{
  "pattern_match_bytes" => fn ->
    len = byte_size("/haha")
    <<_::bytes-size(len), rest :: binary >> = path
    rest
  end,
  "pattern_match" => fn -> "/haha" <> rest = path; rest end,
  "slice" => fn -> String.slice(path, String.length("/haha")..-1) end,
  "replace_prefix" => fn -> String.replace_prefix(path, "/haha", "") end,
  "split" => fn -> String.splitter(path, "/") |> Enum.drop(1) |> Enum.join("/") end,
  "regex" => fn -> String.replace(path, subdomain_rx, "") end,
})
```

Результаты бенчмарка:

```elixir
bench [master] $ mix run lib/bench.exs
Operating System: Linux
CPU Information: Intel(R) Core(TM) i7-4700MQ CPU @ 2.40GHz
Number of Available Cores: 8
Available memory: 12.019316 GB
Elixir 1.4.4
Erlang 20.0-rc2
Benchmark suite executing with the following configuration:
warmup: 2.00 s
time: 5.00 s
parallel: 1
inputs: none specified
Estimated total run time: 42.00 s

Benchmarking pattern_match...
Warning: The function you are trying to benchmark is super fast, making measures more unreliable! See: https://github.com/PragTob/benchee/wiki/Benchee-Warnings#fast-execution-warning
You may disable this warning by passing print: [fast_warning: false] as configuration options.

Benchmarking pattern_match_bytes...
Warning: The function you are trying to benchmark is super fast, making measures more unreliable! See: https://github.com/PragTob/benchee/wiki/Benchee-Warnings#fast-execution-warning
You may disable this warning by passing print: [fast_warning: false] as configuration options.

Benchmarking regex...

Benchmarking replace_prefix...
Warning: The function you are trying to benchmark is super fast, making measures more unreliable! See: https://github.com/PragTob/benchee/wiki/Benchee-Warnings#fast-execution-warning
You may disable this warning by passing print: [fast_warning: false] as configuration options.

Benchmarking slice...

Benchmarking split...

Name                          ips        average  deviation         median
pattern_match_bytes       24.05 M      0.0416 μs  ±1797.73%      0.0300 μs
pattern_match             22.37 M      0.0447 μs  ±1546.59%      0.0400 μs
replace_prefix             3.11 M        0.32 μs   ±204.05%        0.22 μs
slice                      1.25 M        0.80 μs  ±6484.21%        1.00 μs
split                      0.75 M        1.34 μs  ±3267.35%        1.00 μs
regex                      0.42 M        2.37 μs  ±1512.77%        2.00 μs

Comparison:
pattern_match_bytes       24.05 M
pattern_match             22.37 M - 1.08x slower
replace_prefix             3.11 M - 7.73x slower
slice                      1.25 M - 19.30x slower
split                      0.75 M - 32.18x slower
regex                      0.42 M - 57.00x slower
```

Так что когда вы&nbsp;в&nbsp;следующий раз захотите удалить символы в&nbsp;начале строки, используйте сопоставление с&nbsp;образцом :)

## Продолжаем

Прочитав комментарии, я&nbsp;провёл небольшой тест кода для замены конца строки:

```elixir
path = "/haha/index.html"
ext_rx = ~r/\.[^\.]+$/

Benchee.run(%{
  "reverse_pattern_match_bytes" => fn ->
    len = byte_size(".html")
    <<_::bytes-size(len), rest :: binary >> = String.reverse(path)
    rest |> String.reverse
  end,
  "reverse_pattern_match" => fn -> "lmth." <> rest = String.reverse(path); String.reverse(rest) end,
  "slice" => fn -> String.slice(path, 0..(String.length(".html") * (-1))) end,
  "replace_suffix" => fn -> String.replace_suffix(path, ".html", "") end,
  "split" => fn -> String.splitter(path, ".") |> Enum.slice(0..-2) |> Enum.join(".") end,
  "regex" => fn -> String.replace(path, ext_rx, "") end,
})
```

И получил интересный результат.

Это подтолкнуло меня посмотреть на&nbsp;[исходный код](https://github.com/elixir-lang/elixir/blob/master/lib/elixir/lib/string.ex#L752) функций `replace_prefix` и&nbsp;`replace_suffix` в&nbsp;Elixir:

```elixir
def replace_prefix(string, match, replacement)
    when is_binary(string) and is_binary(match) and is_binary(replacement) do
  prefix_size = byte_size(match)
  suffix_size = byte_size(string) - prefix_size
  
  case string do
    <<prefix::size(prefix_size)-binary, suffix::size(suffix_size)-binary>> when prefix == match ->
      replacement <> suffix
    _ ->
      string
  end
end

def replace_suffix(string, match, replacement)
    when is_binary(string) and is_binary(match) and is_binary(replacement) do
  suffix_size = byte_size(match)
  prefix_size = byte_size(string) - suffix_size
  
  case string do
    <<prefix::size(prefix_size)-binary, suffix::size(suffix_size)-binary>> when suffix == match ->
      prefix <> replacement
    _ ->
      string
  end
end
```

Я&nbsp;слегка подкорректировал код бенчмарка, сделав так, чтобы каждая замена проделывалась по&nbsp;1000 раз и&nbsp;предупреждающее сообщение задерживалось.

```elixir
defmodule Bench do
  def run(fun), do: fun.()
  def no_run(_fun), do: :ok
  def times(n \\ 1000, fun), do: fn -> Enum.each(1..n, fn _ -> fun.() end) end
end

# match beginning of string
Bench.run(fn ->
  path = "/haha/index.html"
  subdomain_rx = ~r(^\/[^\/]+)
  
  Benchee.run(%{
    "pattern_match_bytes" => Bench.times(fn ->
      len = byte_size("/haha")
      <<_::bytes-size(len), rest :: binary >> = path
      rest
    end),
    "pattern_match" => Bench.times(fn -> "/haha" <> rest = path; rest end),
    "slice" => Bench.times(fn -> String.slice(path, String.length("/haha")..-1) end),
    "replace_prefix" => Bench.times(fn -> String.replace_prefix(path, "/haha", "") end),
    "split" => Bench.times(fn -> String.splitter(path, "/") |> Enum.drop(1) |> Enum.join("/") end),
    "regex" => Bench.times(fn -> String.replace(path, subdomain_rx, "") end),
  })
end)

# match end of string string
Bench.run(fn ->
  path = "/haha/index.html"
  ext_rx = ~r/\.[^\.]+$/
  
  Benchee.run(%{
    "reverse_pattern_match_bytes" => Bench.times(fn ->
      len = byte_size(".html")
      <<_::bytes-size(len), rest :: binary >> = String.reverse(path)
      rest |> String.reverse
    end),
    "reverse_pattern_match" => Bench.times(fn -> "lmth." <> rest = String.reverse(path); String.reverse(rest) end),
    "slice" => Bench.times(fn -> String.slice(path, 0..(String.length(".html") * (-1))) end),
    "replace_suffix" => Bench.times(fn -> String.replace_suffix(path, ".html", "") end),
    "split" => Bench.times(fn -> String.splitter(path, ".") |> Enum.slice(0..-2) |> Enum.join(".") end),
    "regex" => Bench.times(fn -> String.replace(path, ext_rx, "") end),
  })
end)
```

Результаты бенчмарка:

```shell
elixir_benchmarks [master *] $ mix run lib/bench.exs

  Operating System: Linux
  CPU Information: Intel(R) Core(TM) i7-4700MQ CPU @ 2.40GHz
  Number of Available Cores: 8
  Available memory: 12.019316 GB
  Elixir 1.4.4
  Erlang 20.0-rc2
  Benchmark suite executing with the following configuration:
  warmup: 2.00 s
  time: 5.00 s
  parallel: 1
  inputs: none specified
  Estimated total run time: 42.00 s
  
  Benchmarking pattern_match...
  Benchmarking pattern_match_bytes...
  Benchmarking regex...
  Benchmarking replace_prefix...
  Benchmarking slice...
  Benchmarking split...
  
  Name                          ips        average  deviation         median
  pattern_match_bytes       15.17 K      0.0659 ms    ±18.05%      0.0610 ms
  pattern_match             14.60 K      0.0685 ms    ±17.41%      0.0640 ms
  replace_prefix             2.52 K        0.40 ms    ±21.46%        0.38 ms
  slice                      0.83 K        1.20 ms    ±21.95%        1.11 ms
  split                      0.58 K        1.72 ms    ±16.76%        1.63 ms
  regex                      0.45 K        2.24 ms     ±7.42%        2.22 ms
  
  Comparison:
  pattern_match_bytes       15.17 K
  pattern_match             14.60 K - 1.04x slower
  replace_prefix             2.52 K - 6.01x slower
  slice                      0.83 K - 18.24x slower
  split                      0.58 K - 26.10x slower
  regex                      0.45 K - 33.98x slower
  Operating System: Linux
  CPU Information: Intel(R) Core(TM) i7-4700MQ CPU @ 2.40GHz
  Number of Available Cores: 8
  Available memory: 12.019316 GB
  Elixir 1.4.4
  Erlang 20.0-rc2
  Benchmark suite executing with the following configuration:
  warmup: 2.00 s
  time: 5.00 s
  parallel: 1
  inputs: none specified
  Estimated total run time: 42.00 s
  
  Benchmarking regex...
  Benchmarking replace_suffix...
  Benchmarking reverse_pattern_match...
  Benchmarking reverse_pattern_match_bytes...
  Benchmarking slice...
  Benchmarking split...
  
  Name                                  ips        average  deviation         median
  replace_suffix                    2633.75        0.38 ms    ±21.15%        0.36 ms
  split                              618.06        1.62 ms    ±13.56%        1.57 ms
  regex                              389.25        2.57 ms     ±6.54%        2.54 ms
  slice                              324.19        3.08 ms    ±19.06%        2.88 ms
  reverse_pattern_match_bytes        275.45        3.63 ms    ±12.08%        3.48 ms
  reverse_pattern_match              272.06        3.68 ms    ±11.99%        3.54 ms
  
  Comparison:
  replace_suffix                    2633.75
  split                              618.06 - 4.26x slower
  regex                              389.25 - 6.77x slower
  slice                              324.19 - 8.12x slower
  reverse_pattern_match_bytes        275.45 - 9.56x slower
  reverse_pattern_match              272.06 - 9.68x slower
  elixir_benchmarks [master *] $
```

Очевидно, для удаления символов с&nbsp;конца `replace_suffix` подойдёт как нельзя лучше, тогда как с&nbsp;началом строки быстрее всего работает `pattern_match_bytes`. Но&nbsp;на&nbsp;самом деле всё не&nbsp;совсем так. Потому что в&nbsp;моём случае, я&nbsp;точно знаю, что у&nbsp;строки есть префикс. Второе место занимает `Pattern_match`, который оказался в&nbsp;6&nbsp;раз быстрее текущей реализации `String.replace_prefix`.

Быть может, это потому, что я&nbsp;использую OTP 20? Что&nbsp;ж, попробуем запустить всё это в&nbsp;других версиях OTP и&nbsp;сравнить результаты. А&nbsp;если они окажутся одинаковыми, придёт время изменить стандартную реализацию.