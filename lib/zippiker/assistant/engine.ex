defmodule Zippiker.Assistant.Engine do
  @moduledoc """
  The assistant's turn loop. History is the Messages API conversation
  (string-keyed maps), only ever appended to: assistant content goes back
  exactly as Claude returned it.

  A turn calls Claude, runs read tools straight away and loops until Claude
  answers. When Claude asks for a write tool, the turn stops with status
  `"confirm"` and the pending calls; `resolve/4` runs the approved ones (or
  tells Claude they were declined) and carries on.
  """

  alias Zippiker.Assistant.{LLM, Tools}

  @max_rounds 8

  @doc "Adds the user's message and runs the turn."
  def reply(history, text, ctx) do
    run(history ++ [%{"role" => "user", "content" => text}], ctx, 0)
  end

  @doc "Approves or declines the pending write calls, then continues the turn."
  def resolve(history, %{"calls" => calls, "results" => results}, approved?, ctx) do
    write_results =
      for call <- calls do
        if approved?,
          do: tool_result(call, Tools.run(call["name"], call["input"], ctx)),
          else: %{
            "type" => "tool_result",
            "tool_use_id" => call["id"],
            "content" => "The user declined this action. Don't retry it unless they ask."
          }
      end

    # All results of one assistant turn go back in a single user message.
    ordered = order_results(history, results ++ write_results)
    run(history ++ [%{"role" => "user", "content" => ordered}], ctx, 0)
  end

  defp run(history, _ctx, round) when round >= @max_rounds do
    done(history, "I stopped after several steps. Ask me to continue if you need more.")
  end

  defp run(history, ctx, round) do
    case LLM.create(ctx.llm, system_prompt(ctx), Tools.definitions(), history) do
      {:ok, response} ->
        content = response["content"] || []
        history = history ++ [%{"role" => "assistant", "content" => content}]
        calls = Enum.filter(content, &(&1["type"] == "tool_use"))

        case response["stop_reason"] do
          "tool_use" when calls != [] ->
            {writes, reads} = Enum.split_with(calls, &Tools.write?(&1["name"]))

            read_results =
              Enum.map(reads, &tool_result(&1, Tools.run(&1["name"], &1["input"], ctx)))

            if writes == [] do
              run(history ++ [%{"role" => "user", "content" => read_results}], ctx, round + 1)
            else
              {:ok,
               %{
                 status: "confirm",
                 history: history,
                 pending: %{
                   "calls" => writes,
                   "results" => read_results,
                   "summaries" => Enum.map(writes, &Tools.describe(&1["name"], &1["input"], ctx))
                 }
               }}
            end

          "refusal" ->
            done(history, "I can't help with that request.")

          "max_tokens" ->
            done(history, "My answer was cut short. Ask me to continue.")

          _end_turn ->
            done(history, nil)
        end

      {:error, :not_configured} ->
        {:error, :not_configured}

      {:error, message} ->
        {:error, message}
    end
  end

  defp done(history, note),
    do: {:ok, %{status: "done", history: history, pending: nil, note: note}}

  defp tool_result(call, {:ok, result}),
    do: %{
      "type" => "tool_result",
      "tool_use_id" => call["id"],
      "content" => Jason.encode!(result)
    }

  defp tool_result(call, {:error, message}),
    do: %{
      "type" => "tool_result",
      "tool_use_id" => call["id"],
      "content" => message,
      "is_error" => true
    }

  # Results in the order Claude made the calls.
  defp order_results(history, results) do
    %{"content" => content} = List.last(history)
    ids = for %{"type" => "tool_use", "id" => id} <- content, do: id
    Enum.sort_by(results, &Enum.find_index(ids, fn id -> id == &1["tool_use_id"] end))
  end

  @doc "The system prompt: who the user is, their workspace, and how to behave."
  def system_prompt(ctx) do
    user = ctx.actor
    organization = ctx.organization

    """
    You are the assistant inside Zippiker, an ERP and CRM used by #{organization.name}.
    You help #{user_name(user)} (#{ctx.role}) get work done: find customers, invoices,
    deals and stock, answer questions from the standard reports, and prepare records.

    Today is #{Date.utc_today() |> Date.to_iso8601()}. Amounts are in #{organization.currency}
    unless a document says otherwise.

    How to work:
    - Use the tools to look things up; never invent records, numbers or ids. If a search finds
      nothing, say so.
    - For figures (sales, profit, who owes what, stock, VAT...), call list_reports then
      run_report, and quote the numbers from it.
    - To create something, call the write tool directly with your best values; the app asks
      the user to approve it before anything is saved, so don't ask for confirmation in text
      first. Find ids with search_records before using them.
    - Drafts only: you can't issue, send, pay, approve or delete anything. Tell the user where
      to do that and use open_page to link the page.
    - If a tool says the user's role doesn't allow something, explain that an admin can give
      them a role that does.
    - Reply in short paragraphs or "- " bullet lists of plain text. No tables, no headings,
      no bold. Mention record numbers and names so the user can find them.
    """
  end

  defp user_name(%{name: name}) when is_binary(name) and name != "", do: name
  defp user_name(%{email: email}), do: to_string(email)
end
