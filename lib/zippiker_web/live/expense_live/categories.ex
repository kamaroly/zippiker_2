defmodule ZippikerWeb.ExpenseLive.Categories do
  @moduledoc "Expense categories and the expense account each one is booked to."
  use ZippikerWeb, :live_view

  alias Zippiker.{Accounting, Expenses}

  @impl true
  def mount(_params, _session, socket) do
    accounts =
      ash_opts(socket)
      |> Accounting.list_accounts!()
      |> Enum.filter(&(&1.type == :expense and &1.active?))

    {:ok, socket |> assign(page_title: "Expense categories", accounts: accounts) |> load()}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :new, _params) do
    form =
      Expenses.ExpenseCategory
      |> AshPhoenix.Form.for_create(:create, form_opts(socket))
      |> to_form()

    assign(socket, form: form, category: nil)
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    category = Expenses.get_expense_category!(id, ash_opts(socket))

    form =
      category
      |> AshPhoenix.Form.for_update(:update, form_opts(socket))
      |> to_form()

    assign(socket, form: form, category: category)
  end

  defp apply_action(socket, :index, _params), do: assign(socket, form: nil, category: nil)

  defp form_opts(socket) do
    [
      as: "category",
      actor: socket.assigns.current_user,
      tenant: socket.assigns.current_organization
    ]
  end

  @impl true
  def handle_event("validate", %{"category" => params}, socket) do
    {:noreply, assign(socket, :form, AshPhoenix.Form.validate(socket.assigns.form, params))}
  end

  def handle_event("save", %{"category" => params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.form, params: params) do
      {:ok, _category} ->
        {:noreply,
         socket
         |> put_flash(:info, "Category saved")
         |> load()
         |> push_patch(to: ~p"/expenses/categories")}

      {:error, form} ->
        {:noreply, assign(socket, :form, form)}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    category = Expenses.get_expense_category!(id, ash_opts(socket))

    case Expenses.delete_expense_category(category, ash_opts(socket)) do
      :ok ->
        {:noreply, socket |> put_flash(:info, "Category deleted") |> load()}

      {:error, _error} ->
        {:noreply,
         put_flash(socket, :error, "This category is used on claims; make it inactive instead")}
    end
  end

  defp load(socket),
    do:
      stream(socket, :categories, Expenses.list_expense_categories!(ash_opts(socket)),
        reset: true
      )
end
