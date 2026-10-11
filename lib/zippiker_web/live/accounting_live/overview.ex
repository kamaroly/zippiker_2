defmodule ZippikerWeb.AccountingLive.Overview do
  @moduledoc "Accounting home: cash, receivables, tax owed, monthly profit, recent entries, expenses."
  use ZippikerWeb, :live_view

  alias Zippiker.Accounting

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket |> assign(:page_title, "Accounting") |> load()}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action)}
  end

  defp apply_action(socket, :expense) do
    opts = ash_opts(socket)
    accounts = Accounting.list_accounts!(%{active_only?: true}, opts)

    form =
      Accounting.JournalEntry
      |> AshPhoenix.Form.for_create(:expense,
        as: "expense",
        actor: socket.assigns.current_user,
        tenant: socket.assigns.current_organization,
        params: %{"date" => Date.to_iso8601(Date.utc_today())}
      )
      |> to_form()

    assign(socket,
      expense_form: form,
      expense_options: options(accounts, [:expense]),
      paid_from_options: options(accounts, [:asset, :liability])
    )
  end

  defp apply_action(socket, :index), do: assign(socket, :expense_form, nil)

  defp options(accounts, types) do
    for account <- accounts,
        account.type in types,
        do: {"#{account.code} · #{account.name}", account.id}
  end

  @impl true
  def handle_event("setup", _params, socket) do
    %{posted: posted} = Accounting.sync_sales!(ash_opts(socket))

    {:noreply,
     socket
     |> put_flash(
       :info,
       "Your books are ready. #{Format.count(posted, "entry")} posted from sales."
     )
     |> load()}
  end

  def handle_event("validate_expense", %{"expense" => params}, socket) do
    {:noreply,
     assign(socket, :expense_form, AshPhoenix.Form.validate(socket.assigns.expense_form, params))}
  end

  def handle_event("save_expense", %{"expense" => params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.expense_form, params: params) do
      {:ok, entry} ->
        {:noreply,
         socket
         |> put_flash(:info, "Expense recorded as #{entry.number}")
         |> load()
         |> push_patch(to: ~p"/accounting")}

      {:error, form} ->
        case change_requested(form) do
          nil ->
            {:noreply, assign(socket, :expense_form, form)}

          number ->
            {:noreply,
             socket
             |> put_flash(:info, change_requested_message(number))
             |> push_patch(to: ~p"/accounting")}
        end
    end
  end

  defp load(socket) do
    opts = ash_opts(socket)

    socket
    |> assign(:overview, Accounting.accounting_overview!(opts))
    |> stream(
      :entries,
      Accounting.list_journal_entries!(%{}, opts ++ [page: [limit: 8]]).results,
      reset: true
    )
  end
end
