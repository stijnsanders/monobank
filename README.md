# monobank

Something quickly whipped up over a weekend.
Nothing fancy, just a little tool to concurrently keep track of the balance per player and transactions between them, on each player's handheld device with a HTML-client, for the duration of a game's session. [(You can probably guess which.)](https://shop.hasbro.com/en-us/product/monopoly-game/7EABAF97-5056-9047-F577-8F4663C79E75)

Created with [xxm](https://github.com/stijnsanders/xxm#xxm). Based on the EventSource object and a `text/event-stream` connection, which uses xxm's `IXxmContextSuspend.Suspend` call intensively to free up worker threads on the server.

Enjoy.