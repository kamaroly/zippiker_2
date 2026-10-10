defmodule ZippikerWeb.AccountingLive.Reports do
  @moduledoc "Profit & loss, balance sheet and trial balance, with date pickers and print."
  use ZippikerWeb, :live_view

  alias Zippiker.Accounting

  @reports ~w(profit_and_loss balance_sheet trial_balance)

  @impl true
  def mount(_params, _session, socket), do: {:ok, assign(socket, :page_title, "Reports")}

  @impl true
  def handle_params(params, _url, socket) do
    today = Date.utc_today()
    report = if params["report"] in @reports, do: params["report"], else: "profit_and_loss"
    from = date(params["from"], Date.new!(today.year, 1, 1))
    to = date(params["to"], today)
    opts = ash_opts(socket)

    data =
      case report do
        "profit_and_loss" -> Accounting.profit_and_loss!(from, to, opts)
        "balance_sheet" -> Accounting.balance_sheet!(to, opts)
        "trial_balance" -> Accounting.trial_balance!(to, opts)
      end

    {:noreply,
     assign(socket,
       report: report,
       from: from,
       to: to,
       data: data,
       page_title: title(report)
     )}
  end

  @impl true
  def handle_event("dates", params, socket) do
    {:noreply,
     push_patch(socket,
       to: report_path(socket.assigns.report, params["from"], params["to"])
     )}
  end

  defp date(value, default) do
    case Date.from_iso8601(value || "") do
      {:ok, date} -> date
      _ -> default
    end
  end

  defp report_path(report, from, to),
    do: query_path(~p"/accounting/reports", %{report: report, from: from, to: to})

  defp title("profit_and_loss"), do: "Profit & loss"
  defp title("balance_sheet"), do: "Balance sheet"
  defp title("trial_balance"), do: "Trial balance"
end
