defmodule ZippikerWeb.AccountingLive.JournalForm do
  @moduledoc "A manual journal entry: lines with debits and credits that must balance."
  use ZippikerWeb, :live_view

  alias Zippiker.Accounting

  @impl true
  def mount(_params, _session, socket) do
    accounts = Accounting.list_accounts!(%{active_only?: true}, ash_opts(socket))
    socket = assign(socket, :branch_options, branch_options(socket.assigns))

    form =
      Accounting.JournalEntry
      |> AshPhoenix.Form.for_create(:create,
        as: "entry",
        actor: socket.assigns.current_user,
        tenant: socket.assigns.current_organization,
        params: %{"date" => Date.to_iso8601(Date.utc_today())}
      )
      |> AshPhoenix.Form.add_form(:lines, params: %{})
      |> AshPhoenix.Form.add_form(:lines, params: %{})

    {:ok,
     socket
     |> assign(page_title: "New journal entry")
     |> assign(:account_options, Enum.map(accounts, &{"#{&1.code} · #{&1.name}", &1.id}))
     |> assign_form(form)}
  end

  @impl true
  def handle_event("validate", %{"entry" => params}, socket) do
    {:noreply, assign_form(socket, AshPhoenix.Form.validate(socket.assigns.form, params))}
  end

  def handle_event("add_line", _params, socket) do
    {:noreply,
     assign_form(socket, AshPhoenix.Form.add_form(socket.assigns.form, :lines, params: %{}))}
  end

  def handle_event("remove_line", %{"path" => path}, socket) do
    {:noreply, assign_form(socket, AshPhoenix.Form.remove_form(socket.assigns.form, path))}
  end

  def handle_event("save", %{"entry" => params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.form, params: params) do
      {:ok, entry} ->
        {:noreply,
         socket
         |> put_flash(:info, "Posted #{entry.number}")
         |> push_navigate(to: ~p"/accounting/journal/#{entry}")}

      {:error, form} ->
        case change_requested(form) do
          nil ->
            {:noreply, assign_form(socket, form)}

          number ->
            {:noreply,
             socket
             |> put_flash(:info, change_requested_message(number))
             |> push_navigate(to: ~p"/accounting/journal")}
        end
    end
  end

  defp assign_form(socket, form) do
    form = to_form(form)
    lines = form |> AshPhoenix.Form.params() |> Map.get("lines", %{}) |> line_params()
    debits = sum(lines, "debit")
    credits = sum(lines, "credit")

    assign(socket,
      form: form,
      debits: debits,
      credits: credits,
      balanced?: Decimal.gt?(debits, 0) and Decimal.eq?(debits, credits)
    )
  end

  defp line_params(lines) when is_map(lines), do: Map.values(lines)
  defp line_params(lines) when is_list(lines), do: lines
  defp line_params(_lines), do: []

  defp sum(lines, key) do
    Enum.reduce(lines, Decimal.new(0), fn line, total ->
      case Decimal.parse(to_string(line[key] || "")) do
        {value, ""} -> Decimal.add(total, value)
        _ -> total
      end
    end)
  end
end
