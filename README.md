# OlaRadio

Консольный потоковый плеер для Yandex.Radio. Вдохновлен проектом [Yandex Music API](https://yandex-music.readthedocs.io/en/main/).

![image](https://user-images.githubusercontent.com/37439522/220035301-6450f864-9201-401d-af83-aa97b7f4fd10.png)

Сохраняет прослушанные треки в кеш, чтобы не скачивать их повторно.

![image](https://user-images.githubusercontent.com/37439522/220046135-3fcaf642-4d0e-4f89-b951-999fc9324275.png)


## Установка

```
git clone https://github.com/MiklinMA/OlaRadio.git
cd OlaRadio
python3 -m venv env
. env/bin/activate
pip install -r requirements.txt
```

## Настройка

Для нормальной работы, необходимо получить токен [здесь](https://music-yandex-bot.ru).

Добавить переменные окружения (.bashrc OR .profile OR .zprofile OR something)
```
export YANDEX_MUSIC_TOKEN=AQAAAAALe0-1234567890123456789012345678 # this is an example
export YANDEX_MUSIC_CACHE="/Users/pepe/Music/Radio"
```

## Использование

#### Запуск
```
cd OlaRadio
. env/bin/activate
python radio.py
```

#### Управление
```
next (n) - следующий трек
pause (p) - пауза
unpause (u) - снять с паузы
stop (s) - выход
like (l) - поставить лайк треку
dislike (d) - дизлайк и следующий трек (трек будет удален из кеша)
```

## Поддержка

* [Телега](https://t.me/MiklinMA)
* [Почта](MiklinMA@gmail.com)
