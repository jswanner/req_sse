# ReqSSE

Req plugin for parsing [text/event-stream messages (aka server-sent events)][sse].
This plugin requires the use of `into: :self` and when a message is received
in the process mailbox it should be given to `Req.parse_message/2`.

[sse]: https://developer.mozilla.org/en-US/docs/Web/API/Server-sent_events

```elixir
iex> resp =
...>   Req.new(into: :self)
...>   |> ReqSSE.attach()
...>   |> Req.get!(url: "https://api.example.com/path")
iex> Req.parse_message(resp, receive do message -> message end)
{:ok, data: [%ReqSSE.Message{}]}
```
