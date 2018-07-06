---
title: Как связать Феникс c Вебпаком
excerpt: Работая над приложением, большое внимание в котором уделено фронтенду, можно облегчить себе жизнь с помощью Webpack, особенно если вам хочется добавить в проект React.
author: nadezhda
source_url: http://whatdidilearn.info/2018/05/20/how-to-use-webpack-and-react-with-phoenix-1-3.html
source_title: How to use Webpack and React with Phoenix 1.3
source_author: Vitaly Tatarintsev
tags: [howto, phoenix]
cover: /assets/images/phoenix.png
---

> Переведено в [**Докдоге**](https://docdog.io) – системе перевода технических текстов.

Работая над приложением, большое внимание в котором уделено фронтенду, можно облегчить себе жизнь с помощью [Webpack](https://webpack.js.org/concepts/), особенно если вам хочется добавить в проект [React](https://reactjs.org/).


Webpack - довольно популярный на сегодняшний день инструмент, и Феникс, начиная с версии 1.4, будет поддерживать его прямо из коробки.



Но что делать, если хочется воспользоваться им уже сейчас, до выхода новой версии Феникса? Решение есть: заменить [Brunch](http://brunch.io/) на Webpack.


Давайте посмотрим, как это можно сделать.


## Настройка Webpack



Для начала целиком удалим конфигурацию Brunch из своего проекта.


В качестве наглядного примера будем рассматривать стандартное Феникс-приложение, использующее Brunch.


Поехали!


Первым делом удалим из зависимостей файла `assets/package.json` следующие библиотеки:


```
"babel-brunch"
"brunch"
"clean-css-brunch"
"uglify-js-brunch"
```


Теперь установим необходимые зависимости:


```
→ cd assets → npm install –save-dev babel-core babel-loader babel-preset-env 
→ npm install –save-dev webpack webpack-cli 
→ npm install –save-dev copy-webpack-plugin css-loader mini-css-extract-plugin optimize-css-assets-webpack-plugin uglifyjs-webpack-plugin 
→ cd ..
```


Команда `--save-dev` добавит все вышеперечисленные зависимости в файл `assets/package.json`.


Откроем файл ещё раз и внесём изменения:


```json
"deploy": "brunch build --production",
"watch": "brunch watch --stdin"
```


заменим на:


```json
"deploy": "webpack --mode production",
"watch": "webpack --mode development --watch"
```


Это понадобится нам далее.


Теперь удалим файл `assets/brunch-config.js`.


Вместо него нужно будет создать `assets/webpack.config.js`, содержащий следующий код:


```js
const path = require('path');
const MiniCssExtractPlugin = require('mini-css-extract-plugin');
const UglifyJsPlugin = require('uglifyjs-webpack-plugin');
const OptimizeCSSAssetsPlugin = require('optimize-css-assets-webpack-plugin');
const CopyWebpackPlugin = require('copy-webpack-plugin');

module.exports = (env, options) => ({
    optimization: {
        minimizer: [
            new UglifyJsPlugin({ cache: true, parallel: true, sourceMap: false }),
            new OptimizeCSSAssetsPlugin({})
        ]
    },
    entry: './js/app.js',
    output: {
        filename: 'app.js',
        path: path.resolve(__dirname, '../priv/static/js')
    },
    module: {
        rules: [
            {
                test: /\.js$/,
                exclude: /node_modules/,
                use: {
                    loader: 'babel-loader'
                }
            },
            {
                test: /\.css$/,
                use: [MiniCssExtractPlugin.loader, 'css-loader']
            }
        ]
    },
    plugins: [
        new MiniCssExtractPlugin({ filename: '../css/app.css' }),
        new CopyWebpackPlugin([{ from: 'static/', to: '../' }])
    ]
});
```


Добавим `import css from "../css/app.css"` в начало файла `assets/js/app.js`.


В `config/dev.exs` заменим


```elixir
watchers: [node: ["node_modules/brunch/bin/brunch", "watch", "--stdin",
```


на


```elixir
watchers: [node: ["node_modules/webpack/bin/webpack.js", "--mode", "development", "--watch-stdin",
```


Создадим файл `assets/.babelrc` со следующим содержимым:


```elixir
{"presets": ["env"]}
```


Сюда можно добавить любую другую необходимую вам опцию. Их можно найти на [странице библиотеки](https://github.com/babel/babel/tree/master/packages/babel-preset-env#install).


### Примечание


Обратите внимание, что подключение файла  `assets/css/phoenix.css` отсутствует в файле `assets/css/app.css` намеренно.


Это сделано по той причине, что стили Феникса 1.3 по умолчанию используют набор иконок “glyphicons”, шрифт для которых не включён в сам Феникс. Ранее ошибки не возникало, если не пытаться использовать данные символы, но с Webpack дела обстоят иначе. При обработке файла он пытается построить граф зависимостей и не может найти шрифты, вследствие чего мы получаем ошибку.



Не так-то просто выкинуть из файла правила CSS, где эти шрифты используются, так как большая его часть минифицирована.


Скорее всего, в своем Феникс-приложении вы уже заменили стандартные стили на свои или что-то вроде [Bootstrap](http://whatdidilearn.info/2018/02/11/how-to-use-bootstrap-4-with-phoenix.html), или [Material Design](http://whatdidilearn.info/2018/05/13/how-to-use-materialize-css-with-phoenix.html).


В любом случае, в нашем примере мы не будем с этим заморачиваться.


Ну вот и всё. Теперь, если запустить веб-сервер, то проект, все стили и JavaScript должны работать как прежде.


Следующий шаг - настройка React.


## Настройка React


Сначала установим дополнительные зависимости:


```
→ cd assets
→ npm install --save react react-dom
→ npm install --save-dev babel-preset-react
→ cd ..
```


“react” и “react-dom” нужны для работы самого React, а “babel-preset-react” - для того, чтобы появилась возможность использовать JSX в файлах JavaScript.


Допишем пресеты `assets/.babelrc`, чтобы они тоже содержали `"react"`:


```
{"presets": ["env", "react"]}
```


Пока ни один стиль не задействован, добавим одно правило CSS для примера.
(`assets/css/app.css`):


```css
.jumbotron {
background: #eee;
text-align: center;
padding: 50px 0 50px;
}
```


Создадим `assets/js/components/Jumbotron.js`:


```js
import React from "react";

const Jumbotron = () => {
    return (
        <div className="jumbotron">
            <h2>Welcome to Phoenix with Webpack and React</h2>
            <p className="lead">
                A productive web framework that<br />
                does not compromise speed and maintainability.
            </p>
        </div>
    )
};

export default Jumbotron;
```


Добавим в `assets/js/app.js` следующие строки:


```js
import React from "react";
import ReactDOM from "react-dom";

import Jumbotron from './components/Jumbotron';

ReactDOM.render(<Jumbotron />, document.getElementById("react-app"));
```


И наконец, добавим элемент “react-app” на страницу.


В `lib/<project_name>_web/templates/page/index.html.eex` заменим всё на:


```html
<div id="react-app"></div>
```


Готово. Запустите Феникс-сервер снова, и на странице должно появиться сообщение: “Welcome to Phoenix with Webpack and React”. Это значит, что компонент React подключён.


## Заключение


Вот таким образом проводится настройка Webpack и React для проектов на Фениксе. Теперь вы сможете использовать React в своих приложениях, не дожидаясь релиза Феникса 1.4.


Рассмотренный пример можно найти [по ссылке](https://phoenix-webpack-example.herokuapp.com/), а все его изменения - на [GitHub](https://github.com/ck3g/phoenix-webpack-example).
