defmodule ZippikerWeb.AccountingLive.Ledger do
  @moduledoc "One account's ledger: every posting with a running balance."
  use ZippikerWeb, :live_view

  alias Zippiker.Accounting

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    opts = ash_opts(socket)
    account = Accounting.get_account!(id, opts ++ [load: [:balance]])
    lines = Accounting.account_lines!(account.id, opts)

    {:ok,
     socket
     |> assign(page_title: account.name, account: account, count: length(lines))
     |> stream(:lines, with_running_balance(account, lines))}
  end

  # Balance on the account's normal side after each posting.
  defp with_running_balance(account, lines) do
    sign = if account.type in [:asset, :expense], do: 1, else: -1

    {lines, _balance} =
      Enum.map_reduce(lines, Decimal.new(0), fn line, balance ->
        change = Decimal.mult(Decimal.sub(line.debit, line.credit), sign)
        balance = Decimal.add(balance, change)
        {Ash.Resource.put_metadata(line, :running, balance), balance}
      end)

    lines
  end
end
