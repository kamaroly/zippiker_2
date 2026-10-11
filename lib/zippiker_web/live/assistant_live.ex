defmodule ZippikerWeb.AssistantLive do
  @moduledoc """
  Chat with the AI assistant. The conversation lives in this LiveView (it
  starts fresh on reload); each turn runs asynchronously. Write actions the
  assistant proposes wait for the user's Approve / Decline.
  """
  use ZippikerWeb, :live_view

  alias Zippiker.Assistant

  @suggestions [
    "Who owes us the most money right now?",
    "How did sales this month compare with last month?",
    "Which invoices are overdue by more than 30 days?",
    "What's our profit so far this year?",
    "Add a follow-up task to call Globex next Monday",
    "Draft an invoice for 10 hours of consulting at 50 per hour"
  ]

  @impl true
  def mount(params, _session, socket) do
    status = Assistant.assistant_status!(ash_opts(socket))

    socket =
      assign(socket,
        page_title: "Assistant",
        configured?: status.configured?,
        model: status.model,
        provider: status.provider,
        history: [],
        pending: nil,
        busy?: false,
        error: nil,
        note: nil,
        suggestions: @suggestions,
        form: to_form(%{"text" => ""})
      )

    socket =
      case params["q"] do
        q when is_binary(q) and q != "" and status.configured? ->
          if connected?(socket), do: send_message(socket, q), else: socket

        _ ->
          socket
      end

    {:ok, socket}
  end

  @impl true
  def handle_event("send", %{"text" => text}, socket) do
    text = String.trim(text)

    if text == "" or socket.assigns.busy? or socket.assigns.pending,
      do: {:noreply, socket},
      else: {:noreply, send_message(socket, text)}
  end

  def handle_event("suggest", %{"text" => text}, socket),
    do: handle_event("send", %{"text" => text}, socket)

  def handle_event("decide", %{"approved" => approved}, socket) do
    %{history: history, pending: pending} = socket.assigns
    opts = ash_opts(socket)
    approved? = approved == "true"

    {:noreply,
     socket
     |> assign(busy?: true, error: nil, note: nil)
     |> start_async(:turn, fn ->
       Assistant.assistant_resolve!(history, pending, approved?, opts)
     end)}
  end

  def handle_event("reset", _params, socket) do
    {:noreply, assign(socket, history: [], pending: nil, error: nil, note: nil)}
  end

  defp send_message(socket, text) do
    history = socket.assigns.history
    opts = ash_opts(socket)

    socket
    |> assign(
      busy?: true,
      error: nil,
      note: nil,
      history: history ++ [%{"role" => "user", "content" => text}],
      form: to_form(%{"text" => ""})
    )
    |> start_async(:turn, fn -> Assistant.assistant_reply!(history, text, opts) end)
  end

  @impl true
  def handle_async(:turn, {:ok, result}, socket) do
    socket = assign(socket, busy?: false)

    case result.status do
      "not_configured" ->
        {:noreply, assign(socket, configured?: false)}

      "error" ->
        {:noreply, assign(socket, error: result.error)}

      _status ->
        {:noreply,
         assign(socket,
           history: result.history,
           pending: result.pending,
           note: Map.get(result, :note)
         )}
    end
  end

  def handle_async(:turn, {:exit, reason}, socket) do
    {:noreply,
     assign(socket, busy?: false, error: "Something went wrong (#{inspect(reason, limit: 3)}).")}
  end

  # What to show: the user's words, the assistant's text, tool activity and
  # the outcome of approved actions.
  defp items(history) do
    results =
      for %{"role" => "user", "content" => content} when is_list(content) <- history,
          %{"type" => "tool_result"} = result <- content,
          into: %{},
          do: {result["tool_use_id"], result}

    Enum.flat_map(history, fn
      %{"role" => "user", "content" => text} when is_binary(text) ->
        [{:user, text}]

      %{"role" => "assistant", "content" => content} ->
        Enum.flat_map(content, fn
          %{"type" => "text", "text" => text} when text != "" ->
            [{:assistant, text}]

          %{"type" => "tool_use"} = call ->
            [{:tool, call, Map.get(results, call["id"])}]

          _other ->
            []
        end)

      _ ->
        []
    end)
  end

  defp tool_label(%{"name" => "search_records", "input" => input}) do
    query = input["query"]

    "Searched #{input["type"]}" <>
      if(query in [nil, ""], do: "", else: " for “#{query}”")
  end

  defp tool_label(%{"name" => "get_record", "input" => input}),
    do: "Opened a #{singular(input["type"])}"

  defp tool_label(%{"name" => "list_reports"}), do: "Looked up the reports"

  defp tool_label(%{"name" => "run_report", "input" => input}),
    do: "Ran the #{humanize_key(input["key"])} report"

  defp tool_label(%{"name" => name}), do: Format.humanize(name)

  defp tool_icon(%{"name" => "search_records"}), do: "hero-magnifying-glass-micro"
  defp tool_icon(%{"name" => "get_record"}), do: "hero-document-text-micro"

  defp tool_icon(%{"name" => name}) when name in ["list_reports", "run_report"],
    do: "hero-chart-bar-micro"

  defp tool_icon(_call), do: "hero-bolt-micro"

  defp singular(type) when is_binary(type), do: String.trim_trailing(type, "s")
  defp singular(_), do: "record"

  defp humanize_key(key) when is_binary(key), do: key |> String.replace("-", " ")
  defp humanize_key(_), do: ""

  # Outcome of a tool call: {:ok, map} | {:error, text} | :pending.
  defp outcome(nil), do: :pending
  defp outcome(%{"is_error" => true, "content" => message}), do: {:error, message}

  defp outcome(%{"content" => content}) when is_binary(content) do
    case Jason.decode(content) do
      {:ok, %{} = map} -> {:ok, map}
      _ -> {:declined, content}
    end
  end

  defp outcome(_result), do: :pending

  defp write?(%{"name" => name}), do: Zippiker.Assistant.Tools.write?(name)

  defp safe_path("/" <> rest = path) do
    if String.starts_with?(rest, "/") or String.contains?(rest, "://"), do: nil, else: path
  end

  defp safe_path(_), do: nil
end
