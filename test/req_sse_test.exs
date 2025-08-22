defmodule ReqSSETest do
  use ExUnit.Case

  setup %{test: name} do
    Process.register(self(), name)

    plug = fn conn, _opts ->
      conn =
        conn
        |> Plug.Conn.put_resp_content_type("text/event-stream")
        |> Plug.Conn.send_chunked(:ok)

      send(name, {:connected, self()})

      loop = fn conn, loop ->
        receive do
          {:chunk, chunk} ->
            {:ok, conn} = Plug.Conn.chunk(conn, chunk)
            loop.(conn, loop)

          :done ->
            conn
        end
      end

      loop.(conn, loop)
    end

    {:ok, plug: plug}
  end

  test "parsing messages", %{plug: plug, test: name} do
    spawn_link(fn ->
      resp = Req.get!(bandit: true, into: :self, plug: plug, plugins: [ReqSSE, ReqTestBandit])

      loop = fn loop ->
        receive do
          info ->
            send(name, Req.parse_message(resp, info))
            loop.(loop)
        end
      end

      loop.(loop)
    end)

    assert_receive {:connected, server_pid}

    send(
      server_pid,
      {:chunk,
       """
       event: ping
       retry: 5000
       data: 2025-01-01T11:22:33Z

       """}
    )

    assert_receive {:ok,
                    data: [
                      %ReqSSE.Message{data: "2025-01-01T11:22:33Z", event: "ping", retry: 5000}
                    ]}

    send(
      server_pid,
      {:chunk,
       """
       retry: 5000
       data: no event

       """}
    )

    assert_receive {:ok,
                    data: [
                      %ReqSSE.Message{data: "no event", event: "message", retry: 5000}
                    ]}

    send(
      server_pid,
      {:chunk,
       """
       data: data1
       data: data2

       """}
    )

    assert_receive {:ok, data: [%ReqSSE.Message{data: "data1\ndata2", event: "message"}]}

    send(server_pid, {:chunk, "data: split "})

    assert_receive {:ok, data: []}

    send(
      server_pid,
      {:chunk,
       """
       chunks

       """}
    )

    assert_receive {:ok, data: [%ReqSSE.Message{data: "split chunks", event: "message"}]}
  end

  test "unsupported :into" do
    assert {_, exception} = Req.get(into: [], plugins: [ReqSSE])
    assert is_exception(exception, ReqSSE.UnsupportedIntoError)
  end
end
