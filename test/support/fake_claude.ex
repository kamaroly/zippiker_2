defmodule Zippiker.FakeClaude do
  @moduledoc """
  Scripts Claude API responses for tests: `script/1` queues responses and
  `requests/0` returns the request bodies sent, in order.
  """

  def script(responses) do
    {:ok, agent} = Agent.start_link(fn -> %{responses: responses, requests: []} end)

    Req.Test.stub(Zippiker.Assistant.Claude, fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)
      request = Jason.decode!(body)

      response =
        Agent.get_and_update(agent, fn %{responses: [next | rest], requests: requests} ->
          {next, %{responses: rest, requests: requests ++ [{conn.req_headers, request}]}}
        end)

      Req.Test.json(conn, response)
    end)

    Process.put(:fake_claude, agent)
    agent
  end

  def requests(agent \\ Process.get(:fake_claude)),
    do: Agent.get(agent, & &1.requests)

  def text(text),
    do: %{"content" => [%{"type" => "text", "text" => text}], "stop_reason" => "end_turn"}

  def tool(id, name, input, text \\ nil) do
    %{
      "content" =>
        if(text, do: [%{"type" => "text", "text" => text}], else: []) ++
          [%{"type" => "tool_use", "id" => id, "name" => name, "input" => input}],
      "stop_reason" => "tool_use"
    }
  end
end
