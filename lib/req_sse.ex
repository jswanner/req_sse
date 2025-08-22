defmodule ReqSSE do
  @moduledoc """
  Req plugin for parsing [text/event-stream messages (aka server-sent events)][sse].
  This plugin requires the use of `into: :self` and when a message is received
  in the process mailbox it should be given to `Req.parse_message/2`.

  [sse]: https://developer.mozilla.org/en-US/docs/Web/API/Server-sent_events
  """

  @buffer_key :"$req_sse_buffer"

  defmodule UnsupportedIntoError do
    defexception [:actual, :expected]

    @impl true
    def message(%{expected: expected, actual: actual}) do
      """
      unsupported `:into` option
      expected: #{inspect(expected)}
      actual:   #{inspect(actual)}\
      """
    end
  end

  defmodule Message do
    @moduledoc """
    The message struct.

    Fields:

    * `:data` - the payload of the message sent by the server.

    * `:event` - the type of the event, if specified by the server, otherwise
      will default to `"message"`.

    * `:id` - the unique ID of the message, if specified by the server.

    * `:retry` - the reconnection time, if specified by the server.
    """

    @typedoc "The message struct."
    @type t() :: %ReqSSE.Message{
            data: nil | binary(),
            event: binary(),
            id: nil | binary(),
            retry: nil | integer()
          }
    defstruct [:data, :id, :retry, event: "message"]
  end

  @doc """
  Runs the plugin.

  ## Usage

      iex> resp =
      ...>   Req.new(into: :self)
      ...>   |> ReqSSE.attach()
      ...>   |> Req.get!(url: "https://api.example.com/path")
      iex> Req.parse_message(resp, receive do message -> message end)
      {:ok, data: [%ReqSSE.Message{}]}
  """

  def attach(%Req.Request{} = request, _opts \\ []) do
    request
    |> Req.Request.append_request_steps(ensure_into_self: &ensure_into_self/1)
    |> Req.Request.append_response_steps(parse_sse: &parse_sse/1)
  end

  def ensure_into_self(request) do
    case request.into do
      :self -> request
      other -> {request, UnsupportedIntoError.exception(actual: other, expected: :self)}
    end
  end

  def parse_sse({request, response}) when response.status in 200..299 do
    case Req.Response.get_header(response, "content-type") do
      ["text/event-stream" <> _] ->
        {request,
         update_in(
           response.body.stream_fun,
           &fn ref, chunk -> parse_sse_chunk(&1.(ref, chunk)) end
         )}

      _ ->
        {request, response}
    end
  end

  def parse_sse(other), do: other

  defp parse_sse_chunk({:ok, [data: data]}) do
    {buffer, updates} =
      (Process.get(@buffer_key, "") <> data)
      |> String.split("\n\n")
      |> List.pop_at(-1)

    Process.put(@buffer_key, buffer)

    parsed = updates |> Enum.map(&parse_sse_message(String.split(&1, "\n", trim: true)))
    {:ok, [data: parsed]}
  end

  defp parse_sse_chunk(other), do: other

  defp parse_sse_message(list, message \\ %Message{})

  defp parse_sse_message(["data: " <> data | rest], %{data: nil} = message) do
    parse_sse_message(rest, put_in(message.data, data))
  end

  defp parse_sse_message(["data: " <> data | rest], message) do
    parse_sse_message(rest, update_in(message.data, &(&1 <> "\n" <> data)))
  end

  defp parse_sse_message(["event: " <> event | rest], message) do
    parse_sse_message(rest, put_in(message.event, event))
  end

  defp parse_sse_message(["id: " <> id | rest], message) do
    parse_sse_message(rest, put_in(message.id, id))
  end

  defp parse_sse_message(["retry: " <> retry | rest], message) do
    retry =
      case Integer.parse(retry) do
        {retry, ""} -> retry
        _ -> nil
      end

    parse_sse_message(rest, put_in(message.retry, retry))
  end

  defp parse_sse_message([_other | rest], message), do: parse_sse_message(rest, message)

  defp parse_sse_message([], message), do: message
end
