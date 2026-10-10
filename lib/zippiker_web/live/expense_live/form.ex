defmodule ZippikerWeb.ExpenseLive.Form do
  @moduledoc """
  New or edit an expense claim: a title and one row per receipt (date,
  category, description, merchant, amount). Rows live in the socket until
  the claim is saved as a draft, or saved and submitted for approval.
  """
  use ZippikerWeb, :live_view

  alias Zippiker.Expenses

  @impl true
  def mount(params, _session, socket) do
    opts = ash_opts(socket)
    categories = Expenses.list_expense_categories!(%{active_only?: true}, opts)

    socket =
      assign(socket,
        categories: categories,
        currency: Zippiker.Accounts.default_legal_entity!(opts).currency,
        errors: []
      )

    {:ok, load(socket, socket.assigns.live_action, params)}
  end

  defp load(socket, :new, _params) do
    assign(socket,
      claim: nil,
      page_title: "New expense claim",
      title: "",
      notes: "",
      items: [blank_item(socket.assigns.categories)]
    )
  end

  defp load(socket, :edit, %{"id" => id}) do
    claim = Expenses.get_expense_claim!(id, ash_opts(socket) ++ [load: [:items]])

    if claim.status in [:draft, :rejected] do
      assign(socket,
        claim: claim,
        currency: claim.currency,
        page_title: "Edit #{claim.number}",
        title: claim.title,
        notes: claim.notes || "",
        items: Enum.map(claim.items, &item_row/1)
      )
    else
      socket
      |> put_flash(:error, "Only draft or rejected claims can be edited")
      |> push_navigate(to: ~p"/expenses/#{claim}")
    end
  end

  defp item_row(item) do
    %{
      "key" => item.id,
      "id" => item.id,
      "spent_on" => Date.to_iso8601(item.spent_on),
      "category_id" => item.category_id,
      "description" => item.description,
      "merchant" => item.merchant || "",
      "amount" => Decimal.to_string(item.amount, :normal)
    }
  end

  defp blank_item(categories) do
    %{
      "key" => Ash.UUID.generate(),
      "spent_on" => Date.to_iso8601(Date.utc_today()),
      "category_id" => (List.first(categories) || %{id: ""}).id,
      "description" => "",
      "merchant" => "",
      "amount" => ""
    }
  end

  @impl true
  def handle_event("change", params, socket) do
    {:noreply, socket |> assign_params(params) |> assign(:errors, [])}
  end

  def handle_event("add_item", _params, socket) do
    {:noreply, update(socket, :items, &(&1 ++ [blank_item(socket.assigns.categories)]))}
  end

  def handle_event("remove_item", %{"key" => key}, socket) do
    {:noreply, update(socket, :items, fn items -> Enum.reject(items, &(&1["key"] == key)) end)}
  end

  def handle_event("save", params, socket) do
    socket = assign_params(socket, params)
    submit? = params["intent"] == "submit"

    with {:ok, claim} <- save(socket),
         {:ok, claim} <- maybe_submit(claim, submit?, socket) do
      {:noreply,
       socket
       |> put_flash(:info, if(submit?, do: submitted_message(claim), else: "Claim saved"))
       |> push_navigate(to: ~p"/expenses/#{claim}")}
    else
      {:error, error} ->
        {:noreply, assign(socket, :errors, [error_message(error)])}
    end
  end

  defp submitted_message(%{status: :approved}), do: "Claim approved (no other approver needed)"
  defp submitted_message(_claim), do: "Claim submitted for approval"

  defp assign_params(socket, params) do
    claim = Map.get(params, "claim", %{})
    rows = Map.get(params, "items", %{})

    items =
      Enum.map(socket.assigns.items, fn item ->
        Map.merge(item, Map.take(Map.get(rows, item["key"], %{}), editable_fields()))
      end)

    assign(socket,
      title: Map.get(claim, "title", socket.assigns.title),
      notes: Map.get(claim, "notes", socket.assigns.notes),
      items: items
    )
  end

  defp editable_fields, do: ~w(spent_on category_id description merchant amount)

  defp save(socket) do
    items =
      socket.assigns.items
      |> Enum.reject(&blank?/1)
      |> Enum.with_index()
      |> Enum.map(fn {item, index} ->
        item
        |> Map.take(["id" | editable_fields()])
        |> Map.put("position", index)
      end)

    params = %{title: socket.assigns.title, notes: socket.assigns.notes, items: items}

    case socket.assigns.claim do
      nil -> Expenses.create_expense_claim(params, ash_opts(socket))
      claim -> Expenses.update_expense_claim(claim, params, ash_opts(socket))
    end
  end

  defp blank?(item), do: String.trim(item["description"]) == "" and item["amount"] in ["", nil]

  defp maybe_submit(claim, false, _socket), do: {:ok, claim}

  defp maybe_submit(claim, true, socket),
    do: Expenses.submit_expense_claim(claim, ash_opts(socket))

  @doc false
  def total(items) do
    Enum.reduce(items, Decimal.new(0), fn item, sum ->
      case Decimal.parse(item["amount"] || "") do
        {amount, ""} -> Decimal.add(sum, amount)
        _ -> sum
      end
    end)
  end
end
