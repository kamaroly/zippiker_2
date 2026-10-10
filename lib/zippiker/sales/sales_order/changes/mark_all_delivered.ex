defmodule Zippiker.Sales.SalesOrder.Changes.MarkAllDelivered do
  @moduledoc "Every line counts as delivered (the invoice shipped what was left)."
  use Ash.Resource.Change

  alias Zippiker.Sales.SalesOrderLine

  @impl true
  def change(changeset, _opts, _context) do
    changeset
    |> Ash.Changeset.force_change_attributes(%{
      status: :delivered,
      delivered_at: DateTime.utc_now()
    })
    |> Ash.Changeset.after_action(fn changeset, order ->
      opts = [tenant: changeset.tenant, authorize?: false]
      lines = Ash.load!(order, :lines, opts).lines
      items = for line <- lines, do: {line, SalesOrderLine.remaining(line)}

      with :ok <- SalesOrderLine.add_delivered(items, opts), do: {:ok, order}
    end)
  end
end
