defmodule ZippikerWeb.AccountingLive.Accounts do
  @moduledoc "Chart of accounts grouped by type, with balances; admins add and edit accounts."
  use ZippikerWeb, :live_view

  alias Zippiker.Accounting

  @types [:asset, :liability, :equity, :income, :expense]

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket |> assign(page_title: "Chart of accounts", types: @types) |> load()}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :new, _params) do
    form =
      Accounting.Account
      |> AshPhoenix.Form.for_create(:create,
        as: "account",
        actor: socket.assigns.current_user,
        tenant: socket.assigns.current_organization,
        params: %{"type" => "expense"}
      )
      |> to_form()

    assign(socket, form: form, account: nil)
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    account = Accounting.get_account!(id, ash_opts(socket))

    form =
      account
      |> AshPhoenix.Form.for_update(:update,
        as: "account",
        actor: socket.assigns.current_user,
        tenant: socket.assigns.current_organization
      )
      |> to_form()

    assign(socket, form: form, account: account)
  end

  defp apply_action(socket, :index, _params), do: assign(socket, form: nil, account: nil)

  @impl true
  def handle_event("validate", %{"account" => params}, socket) do
    {:noreply, assign(socket, :form, AshPhoenix.Form.validate(socket.assigns.form, params))}
  end

  def handle_event("save", %{"account" => params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.form, params: params) do
      {:ok, _account} ->
        {:noreply,
         socket
         |> put_flash(:info, "Account saved")
         |> load()
         |> push_patch(to: ~p"/accounting/accounts")}

      {:error, form} ->
        {:noreply, assign(socket, :form, form)}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    opts = ash_opts(socket)

    case id |> Accounting.get_account!(opts) |> Accounting.delete_account(opts) do
      :ok ->
        {:noreply, socket |> put_flash(:info, "Account deleted") |> load()}

      {:error, error} ->
        {:noreply, put_flash(socket, :error, error_message(error))}
    end
  end

  # One stream per type keeps every collection a stream while grouping.
  defp load(socket) do
    accounts = Accounting.list_accounts!(ash_opts(socket))
    grouped = Enum.group_by(accounts, & &1.type)

    socket = assign(socket, :empty?, accounts == [])

    Enum.reduce(@types, socket, fn type, socket ->
      stream(socket, type, Map.get(grouped, type, []), reset: true)
    end)
  end
end
