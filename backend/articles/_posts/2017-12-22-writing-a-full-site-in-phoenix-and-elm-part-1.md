---
title: Создание веб-приложения на Фениксе и Элме
excerpt: Создание веб-приложения на Фениксе и Элме
author: community
source_url: https://medium.com/@diamondgfx/writing-a-full-site-in-phoenix-and-elm-a100804c9499
source_title: Writing A Full Site in Phoenix and Elm
source_author: Brandon Richey
tags: [elm, phoenix, practical]
cover: /assets/images/phoenix_elm.png
---

## Вступление

Эликсир – классный функциональный язык, а в связке с Фениксом появляется возможность создавать крутые бэкенды для  веб-приложений. Однако, проблема в том, что всё больше сайты превращаются в Джаваскрипт-монстров, а мы пишем всё меньше серверного кода на классном функциональном языке. Какие есть варианты, если хочется использовать функциональное программирование и на сервере, и на клиенте?

Один из вариантов, который мы можем выбрать – это Элм. Он быстрый, чистый, но больше всего подкупает то, что Элм фактически не даёт ошибкам времени выполнения просочиться в ваш фронтенд, оставляя вас с беспрецедентно быстрым и чрезвычайно безопасным пользовательским интерфейсом.

### Используемые версии

- Эликсир: v1.2.6;
- Феникс: v1.1.6;
- Элм: v0.17.

## Создаём сайт на Фениксе

Начнём с создания базового приложения на Фениксе, чтобы отдавать пользователю фронтенд на Элме и предоставлять API для него. Запустите следующую команду:

```
$ mix phoenix.new elm_articles
```

Ответьте `Y` на вопрос о загрузке/установке зависимостей. Настроим Феникс позже, а пока достаточно и этого.

## Добавляем Элм в Brunch

Начнём с добавления пакета `brunch-elm` из Npm, который позволит работать Элму вместе с приложением на Фениксе:

```
$ npm install --save-dev elm-brunch
```

Теперь нужно настроить `elm-brunch`. Откройте `brunch-config.js` и добавьте конфигурацию для `elmBrunch`. Предположим, что у нас будет одно главное приложение на Элме, и мы собираемся забросить его к остальному фронтенд-коду на Джаваскрипте. Вот пример измененного файла `brunch-config`:

```
// Configure your plugins
  plugins: {
    babel: {
      // Do not use ES6 compiler in vendor code
      ignore: [/web\/static\/vendor/]
    },
    elmBrunch: {
      elmFolder: 'web/elm',
      mainModules: ['Main.elm'],
      outputFolder: '../static/js',
    }
  },
```

А также нужно обновить ключ `watched`, чтобы изменения Элм-файлов отслеживались внутри `web/elm`:

```
watched: [
  'web/static',
  'test/static',
  'web/elm',
],
```

Наконец, откройте файл `app.js` и добавьте:

```
import Elm from './main';
const elmDiv = document.querySelector('#elm-target');
if (elmDiv) {
  Elm.Main.embed(elmDiv);
}
```

Затем выполните:

```
$ mkdir web/elm
$ cd web/elm
$ elm package install elm-lang/html
```

## Создаём сайт на Элме

Пришло время написать первый код в рамках нашего первого погружения в Элм. Выполните следующую команду:

```
$ touch web/elm/Main.elm
```

Затем добавьте в файл `web/elm/Main.elm` код:

```
module Main exposing (..)
import Html exposing (text, Html)
main : Html a
main =
  text "Hello Foo"
```

И измените шаблон страниц, чтобы Элм-приложение могло быть отображено. Допишите в файл `web/templates/page/index.html.eex`:

```
<div id="elm-target"></div>
```

Теперь, когда страница обновится, вы должны увидеть, что всё корректно отображается в браузере! Мы будем использовать Феникс в качестве бэкенда, поэтому возьмём его основной шаблон. Всё остальное, что относится к фронтенду, будет на Элме!

Теперь давайте создадим директорию `Components`, которая будет отвечать за хранение разных отдельных компонетов, кроме `Main`, и добавим компонент `ArticleList`.

```
$ mkdir web/elm/Components
$ touch web/elm/Components/ArticleList.elm
```

Теперь нам нужно настроить Элм, чтобы он исопользовал новую директорию `Components`. Откройте файл `elm-package.json`, найдите там ключ `"source-directories"`, и измените его, чтобы он выглядел следующим образом:

```
"source-directories": [
    ".",
    "./Components"
],
```

Теперь можно собрать небольшой образец компонента, чтобы сделать первый шаг. Откройте файл `web/elm/Components/ArticleList.elm`:

```
module Components.ArticleList exposing (view)
import Html exposing (Html, text, ul, li, div, h2)
import Html.Attributes exposing (class)
view : Html a
view =
  div [ class "article-list" ] [
    h2 [] [ text "Article List" ],
      ul []
        [ li [] [ text "Article 1" ]
        , li [] [ text "Article 2" ]
        , li [] [ text "Article 3" ] ] ]
```

Затем проследуем обратно в файл `web/elm/Main.elm` и подключим `ArticleList` внутри компонента `Main`:

```
module Main exposing (..)
import Html exposing (Html, text, div)
import Html.Attributes exposing (class)
import Components.ArticleList as ArticleList
main : Html a
main =
  div [ class "elm-app" ] [ ArticleList.view ]
```

Теперь, когда страница обновится, вы должны увидеть заголовок `Article List` сверху и список из трёх статей, с которым мы начали. Это достаточно хороший старт и хороший способ показать, как разбивать вашу логику на компоненты и модули в Элме, чтобы с кодом было проще работать. Однако то, что мы написали в `ArticleList.elm` всё ещё достаточно неуклюже. Давайте отрефакторим отображение статей, разделив функции. Измените файл `web/elm/Components/ArticleList.elm`:

```
module Components.ArticleList exposing (view)
import Html exposing (Html, text, ul, li, div, h2)
import Html.Attributes exposing (class)
renderArticles : List (Html a)
renderArticles =
  [ li [] [ text "Article 1" ]
  , li [] [ text "Article 2" ]
  , li [] [ text "Article 3" ] ]
view : Html a
view =
  div [ class "article-list" ] [
    h2 [] [ text "Article List" ]
    , ul [] renderArticles ]
```

Будет гораздо легче делать рефакторинг рендера статьи, когда есть отдельный компонент `Article`. Давайте реализуем его. Создайте и откройте файл `web/elm/Components/Article.elm`:

```
module Article exposing (view, Model)
import Html exposing (Html, span, strong, em, a, text)
import Html.Attributes exposing (class, href)
type alias Model =
  { title : String, url : String, postedBy : String, postedOn: String }
view : Model -> Html a
view model =
  span [ class "article" ] 
    [a [ href model.url ] [ strong [ ] [ text model.title ] ]
    , span [ ] [ text (" Posted by: " ++ model.postedBy) ]
    , em [ ] [ text (" (posted on: " ++ model.postedOn ++ ")") ]
    ]
```

Этот компонент немного сложнее. Мы добавили внутреннее представление модели, чтобы иметь возможность создавать объекты `Article` в будущем. Для начала статья будет содержать атрибуты `title`, `url`, `postedBy` и `postedOn`, которые дадут нам некоторую информацию о каждом объекте. Кроме того, мы определили функцию `view`, которая принимает модель и возвращает HTML. Остальной код - просто шаблон на Элме, поэтому нет смысла тратить много времени на него, но алиас типа вверху достаточно интересен, поэтому на нём ненадолго остановимся. 

```
type alias Model =
  { title : String, url : String, postedBy : String, postedOn: String }
```

Здесь говорится, чтобы Элм, встречая модель в нашем коде, в действительности понимал это как тип записи с четырьмя ключами `String`: `title`, `url`, `postedBy`, `postedOn`. А в определении типа для функции представления как раз принимается `Model` и возвращается HTML, подходящий для этой модели!

Наверху компонента `Article` раскрываются `view` и `Model` любому импортёру так, чтобы они могли работать с определёнными здесь структурами данных!

Давайте вернёмся к файлу ` web/elm/Components/ArticleList.elm` и добавим в него взаимодействие с компонентом `Article`:

```
module Components.ArticleList exposing (view)
import Html exposing (Html, text, ul, li, div, h2)
import Html.Attributes exposing (class)
import List
import Article
articles : List Article.Model
articles =
  [ { title = "Article 1", url = "http://google.com", postedBy = "Author", postedOn = "06/20/16" }
  , { title = "Article 2", url = "http://google.com", postedBy = "Author 2", postedOn = "06/20/16" }
  , { title = "Article 3", url = "http://google.com", postedBy = "Author 3", postedOn = "06/20/16" }
  ]
renderArticle : Article.Model -> Html a
renderArticle article =
  li [ ] [ Article.view article ]
renderArticles : List (Html a)
renderArticles =
  List.map renderArticle articles
view : Html a
view =
  div [ class "article-list" ]
    [ h2 [] [ text "Article List" ]
    , ul [] renderArticles ]
```

Теперь мы начинаем с импорта двух новых модулей `List` и `Article` в `ArticleList`. `List` - встроен в Элм, а `Article` мы только что создали. Нам нужен `List` для вызова функции` List.map`.

Затем мы реализовали функцию `articles`, которая просто возвращает три статьи-болванки, не используя никакого источника. Тип функции `articles` - `List` из объектов типа `Article.Model`. Затем мы определили две функции функции для рендера: первая для одиночной статьи (`renderArticle`) и вторая для вызова `renderArticle` для каждой статьи из нашего ресурса-заглушки.

Функция `renderArticle` оборачивает открытую функцию `Article.view` (которая принимает тип `Article.Model`) и возвращает `Html` этой статьи. Затем функция `renderArticles` проходит по списку статей и вызывает функцию `renderArticle` на каждой из них).

Наконец, функция `view` немного изменена так, что неупорядочный список лишь вызывает функцию `renderArticles`, вместо определени] списка потомков (так как функция `renderArticles`, основанная на просмотре определения типа, возвращает список HTML-элементов).


## Приводим `ArticleList.elm` в порядок

Компонент `ArticleList` работает, но он полностью отделён от любого значимого взаимодействия с пользователем. Если мы хотим, чтобы он имел возможность действительно реагировать на какие-либо взаимодействия или события, необходимо сделать код более идиоматичным Элму. Для этого определим исходную моделль, инициализатор, функцию представления, функцию обновления и объединённый тип `Msg`. Определение модели сойдёт в текущем виде. 

Откройте файл `web/elm/Components/ArticleList.elm` и добавьте в него:

```
module Components.ArticleList exposing (..)
```

Достанем из компонента `Components.ArticleList` все функции с помощью `(..)`.

Затем давайте изменим импорты, так как наш компонент явно делает намного больше:

```
import Html exposing (Html, text, ul, li, div, h2, button)
import Html.Attributes exposing (class)
import Html.Events exposing (onClick)
import List
import Article
```

Нам нужно предоставить текущему компоненту также кнопку `button` из модуля `Html` и добавить импорт функции `onClick` из модуля `Html.Events`. Затем нужно сделать определение типа модели записью с ключами:

```
type alias Model =
  { articles: List Article.Model }
```

А также нужно заставить старую функцию `articles` работать с новым определением модели:

```
articles : Model
articles =
  { articles =
    [ { title = "Article 1", url = "http://google.com", postedBy = "Author", postedOn = "06/20/16" }
    , { title = "Article 2", url = "http://google.com", postedBy = "Author 2", postedOn = "06/20/16" }
    , { title = "Article 3", url = "http://google.com", postedBy = "Author 3", postedOn = "06/20/16" } ] }
```

Вот как выглядит объединённый тип `Msg`:

```
type Msg
  = NoOp
  | Fetch
```

Использование сообщения `NoOp` для каждого объединённого типа `Msg` – хороший способ отслеживать случаи, когда приходит событие, которое ничего не делает. Переходим к функции `update`:

```
update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
  case msg of
    NoOp ->
      (model, Cmd.none)
    Fetch ->
      (articles, Cmd.none)
```

Наконец, реализуем функцию `initialModel`:

```
initialModel : Model
initialModel =
  { articles = [] }
```

Это позволит `ArticleList` начинать работу с пустым списком статей. Следом добавим в компонент `ArticleList` кнопку, которая при срабатывании будет отправлять сообщение `Fetch`, определённое в `Msg`:


```
view : Model -> Html Msg
view model =
  div [ class "article-list" ]
    [ h2 [] [ text "Article List" ]
    , button [ onClick Fetch, class "btn btn-primary" ] [ text "Fetch Articles" ]
    , ul [] (renderArticles model) ]
```

И наконец, давайте изменим функцию `renderArticles`, чтобы она принимала модель и рендерила список статей, основанный на ключе `articles` из модели:

```
renderArticles : Model -> List (Html a)
renderArticles model =
  List.map renderArticle model.articles
```


## Приводим `ArticleList.elm` в порядок

Вероятно, вы заметили, что в `Main.elm` особо нет стандартного кода, встречающегося в больших приложениях на Элме, и в целом он спроектирован не по стандартной архитектуре Элма, что делает встраивание приложений, которые имеют какое-либо отношение к взаимодействию с пользователем значительно сложнее! Кроме того, предыдущий компонент, который теперь более идиоматичен, не работает из-за существенного рефакторинга!

Чтобы это исправить, нужно сделать структуру основного приложения в стиле Элма. Опять же, нам нужно определить начальную модель, инициализатор, функцию представления, функцию обновления и функцию подписки. Начнём с определения модели, чтобы иметь концепцию некоторых её дочерних компонентов и их моделей. Откройте файл `web/elm/Main.elm` и давайте начнём его изменять:

```
type alias Model =
  { articleListModel: ArticleList.Model }
```

Это говорит о том, что модель будет содержать модели дочерних компоненов. Далее, определим начальное состояние основной модели:

```
initialModel : Model
initialModel =
  { articleListModel = ArticleList.initialModel }
```
Здесь мы также говорим, что любые данные, связанные с `articleListModel` должны быть с самого начала спроецированы в функции `initialModel`. Далее напишем инициализатор для модуля:

```
init : (Model, Cmd Msg)
init =
  ( initialModel, Cmd.none )
```

Инициализатор возвращает `initialModel` и команду ничего не делать. Далее рассмотрим такое определение:

```
type Msg
  = ArticleListMsg ArticleList.Msg
```

Здесь говорится, что любые сообщения, транслируемые из компонента `ArticleList` могут быть обёрнуты в родительский компонент (`Main.elm`) в качестве сообщения `Msg` типа `ArticleListMsg`. Далее рассмотрим функцию обновления:

```
update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
  case msg of
    ArticleListMsg articleMsg ->
      let (updatedModel, cmd) = ArticleList.update articleMsg model.articleListModel
      in ( { model | articleListModel = updatedModel }, Cmd.map ArticleListMsg cmd )
```

Здесь немного посложнее, но по сути принятое сообщение `Msg` просто сопоставляется с образцом. Если это `ArticleListMsg` (сообщение, полученное из компонента `ArticleList`), то вызывается функция обновления, определённая в компоненте `ArticleList` и возвращается обновлённая часть модели (сообщения `ArticleListMsg` могут обновлять только часть модели `articleListModel`). Затем мы сопоставим любые дополнительные `Msgs` из компонента `ArticleList` как тип `ArticleListMsg`.

Затем необхоидмо написать обработчик подписок, который сейчас будет просто шаблонным кодом:

```
subscriptions : Model -> Sub Msg
subscriptions model =
  Sub.none
```

Прямо сейчас у нас нет подписчиков, так что не будем беспокоиться о том, как оно работает. Теперь пришло время перейти к рассмотрению функции представления. Мы будем использовать `Html.App`, который отобразит сообщения от потомков в сообщение, которые будет включено нашим родительским приложением, поэтому добавьте следующую строку наверх:

```
import Html.App
```

И затем измените функцию `view`:

```
view : Model -> Html Msg
view model =
  div [ class "elm-app" ]
    [ Html.App.map ArticleListMsg (ArticleList.view model.articleListModel) ]
```

Поскольку наша функция представления в компоненте `ArticleList` определяется как модель представления, нам необходимо предоставить их обе. Кроме того, нам нужно сказать компоненту `ArticleList`, что модель будет изменяться с помощью обновлений из родительского компонента.

Наконец, посмотрите на функцию `main`:

```
main : Program Never
main =
  Html.App.program
    { init = init
    , view = view
    , update = update
    , subscriptions = subscriptions
    }
```

Теперь, когда мы запускаем наше приложение, мы должны увидеть красивую синюю кнопку с надписью «Получить статьи». После нажатия этой кнопки у вас должен появиться список статей. Ура! Взаимодействие с пользователем и правильная разбивка компонентов!

## Весь код

Файл `web/elm/Components/ArticleList.elm`:

```
module Components.ArticleList exposing (..)
import Html exposing (Html, text, ul, li, div, h2, button)
import Html.Attributes exposing (class)
import Html.Events exposing (onClick)
import List
import Article
type alias Model =
  { articles: List Article.Model }
type Msg
  = NoOp
  | Fetch
update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
  case msg of
    NoOp ->
      (model, Cmd.none)
    Fetch ->
      (articles, Cmd.none)
articles : Model
articles =
  { articles =
    [ { title = "Article 1", url = "http://google.com", postedBy = "Author", postedOn = "06/20/16" }
    , { title = "Article 2", url = "http://google.com", postedBy = "Author 2", postedOn = "06/20/16" }
    , { title = "Article 3", url = "http://google.com", postedBy = "Author 3", postedOn = "06/20/16" } ] }
renderArticle : Article.Model -> Html a
renderArticle article =
  li [ ] [ Article.view article ]
renderArticles : Model -> List (Html a)
renderArticles articles =
  List.map renderArticle articles.articles
initialModel : Model
initialModel =
  { articles = [] }
view : Model -> Html Msg
view model =
  div [ class "article-list" ]
    [ h2 [] [ text "Article List" ]
    , button [ onClick Fetch, class "btn btn-primary" ] [ text "Fetch Articles" ]
    , ul [] (renderArticles model) ]
```

Файл `web/elm/Components/Article.elm`:

```
module Article exposing (view, Model)
import Html exposing (Html, span, strong, em, a, text)
import Html.Attributes exposing (class, href)
type alias Model =
  { title : String, url : String, postedBy : String, postedOn: String }
view : Model -> Html a
view model =
  span [ class "article" ] [
    a [ href model.url ] [ strong [ ] [ text model.title ] ]
    , span [ ] [ text (" Posted by: " ++ model.postedBy) ]
    , em [ ] [ text (" (posted on: " ++ model.postedOn ++ ")")
    ]
  ]
```

Файл: `web/elm/Main.elm`:

```
module Main exposing (..)
import Html exposing (Html, text, div)
import Html.App
import Html.Attributes exposing (class)
import Components.ArticleList as ArticleList
-- MODEL
type alias Model =
  { articleListModel : ArticleList.Model }
initialModel : Model
initialModel =
  { articleListModel = ArticleList.initialModel }
init : (Model, Cmd Msg)
init =
  ( initialModel, Cmd.none )
-- UPDATE
type Msg
  = ArticleListMsg ArticleList.Msg
update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
  case msg of
    ArticleListMsg articleMsg ->
      let (updatedModel, cmd) = ArticleList.update articleMsg model.articleListModel
      in ( { model | articleListModel = updatedModel }, Cmd.map ArticleListMsg cmd )
subscriptions : Model -> Sub Msg
subscriptions model =
  Sub.none
-- VIEW
view : Model -> Html Msg
view model =
  div [ class "elm-app" ]
    [ Html.App.map ArticleListMsg (ArticleList.view model.articleListModel) ]
-- MAIN
main : Program Never
main =
  Html.App.program
    { init = init
    , view = view
    , update = update
    , subscriptions = subscriptions
    }
```

## Следующие шаги

Как-то многовато для начала, поэтому остановимся здесь и продолжим в следующей статье этой серии, где мы будем получать данные по API и начнём соединять работающий сайт и SPA.

Если вы хотите посмотреть готовый исходный код этого учебника, то переходите в [Гитхаб-репозиторий](https://github.com/Diamond/elm_articles).
