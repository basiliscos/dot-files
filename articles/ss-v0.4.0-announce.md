Выпуск открытой P2P-системы синхронизации файлов syncspirit 0.4.0, совместимой с Synthing.

Доступен релиз системы [syncspirit](https://github.com/basiliscos/syncspirit) v0.4.0, позволяющей организовать автоматическую непрерывную синхронизацию файлов пользователя на нескольких устройствах, решая задачи сходные с проприетарной системой [BitTorrent Sync](https://www.opennet.ru/opennews/art.shtml?num=36778). [Syncspirit](https://github.com/basiliscos/syncspirit) представляет собой независимую реализацию протокола синхронизации [BEP](https://docs.syncthing.net/specs/bep-v1.html), предложенной проектом [Synthing](https://.syncthing.net). Синхронизированные данные не загружаются в сторонние облачные хранилища, а напрямую реплицируются между системами пользователя при их одновременном появлении в online.

В отличие от [Synthing](https://.syncthing.net), который написан на языке Go и использует клиент-серверную архитектуру, где в качестве клиента выступает веб-браузер, [syncspirit](https://github.com/basiliscos/syncspirit/) является классическим монолитным декстопным приложением, что ведёт к минимальным накладным расходам по использованию оперативной памяти.

[syncspirit](https://github.com/basiliscos/syncspirit/) написан на языке C++; графический интерфейс построен с использованием библиотеки [FLTK](https://www.fltk.org/); в качестве базы данных используется отечественная встраиваемая СУБД [MBDX](https://www.opennet.ru/opennews/art.shtml?num=62403); в качестве системы сообщений используется акторный фрейморк [rotor](https://github.com/basiliscos/cpp-rotor/).

![syncspirit v0.4.0](https://notabug.org/basiliscos/syncspirit/raw/v0.4.0-dev/docs/different-uis.gif)

Готовые сборки доступны для [Linux x86_64](https://link) (в формате [AppImage](https://appimage.org/)), [Windows](https://link), [Windows XP](https://link) и [Mac OS X](https://link).

Код проекта [распространяется](https://github.com/basiliscos/syncspirit/) под лицензией GPLv3. 

================

I’m glad to announce v0.4.0 release!

The major feature of the new release is [fltk-frontend](https://link) and improvements [BEP](https://docs.syncthing.net/specs/bep-v1.html) protocol implementation.

![syncspirit v0.4.0](https://notabug.org/basiliscos/syncspirit/raw/v0.4.0-dev/docs/different-uis.gif)

You can download ready-to-use binaries for [Linux x86_64](https://link) and [Windows](https://link), [Windows XP](https://link) и [Mac OS X](https://link).  as well as the source code.

Syncspirit is a syncthing-compatible synchronization program that implements BEP-protocol. Syncspirit is a syncthing-compatible is written from the scratch software in C++, which had different technical decisions on its foundation to overcome syncthing limitations.

Syncspirt [source code](https://github.com/basiliscos/syncspirit) uses GPLv3 license.

Any feedback is welcome!

WBR, basiliscos.