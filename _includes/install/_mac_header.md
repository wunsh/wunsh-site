{% include install/_menu.html page=page %}

Привет, друг! Мы рады, что ты решил установить свеженькую версию Эликсира **{{page.elixir_version}}** на свой Мак.

Для того, чтобы проследовать этой инструкции и в результате получить систему с работающим Эликсиром, тебе необходимо иметь систему ***MacOS 10.13 High Sierra*** и ***15 минут свободного времени***.

> Я хочу установить Эликсир через
> {% if page.path == "install/mac-asdf.md" %} - менеджер версий `asdf` **(рекомендуется)** {% else %} - [менеджер версий `asdf`](/install/mac-asdf) **(рекомендуется)** {% endif %}
> {% if page.path == "install/mac-brew.md" %} - менеджер пакетов `brew` {% else %} - [менеджер пакетов `brew`](/install/mac-brew){% endif %}