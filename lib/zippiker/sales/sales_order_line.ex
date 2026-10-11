defmodule Zippiker.Sales.SalesOrderLine do
  @moduledoc "A line on a sales order; tracks how much has been delivered."
  use Ash.Resource,
    otp_app: :zippiker,
    domain: Zippiker.Sales,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    fragments: [
      Zippiker.Sales.DocumentLine.Attributes,
      Zippiker.Sales.DocumentLine.Actions,
      Zippiker.Sales.SalesOrderLine.Attributes,
      Zippiker.Sales.SalesOrderLine.Relationships,
      Zippiker.Sales.SalesOrderLine.Actions,
      Zippiker.Sales.DocumentLine.Policies
    ]

  postgres do
    table "sales_order_lines"
    repo Zippiker.Repo

    references do
      reference :sales_order, on_delete: :delete
      reference :product, on_delete: :nilify
      reference :tax_rate, on_delete: :nilify
    end
  end

  multitenancy do
    strategy :context
  end

  @doc "Quantity still to deliver."
  def remaining(line), do: Decimal.sub(line.quantity, line.delivered_quantity)

  @doc "Adds `{line, quantity}` deliveries to each line's `delivered_quantity`."
  def add_delivered(items, opts) do
    Enum.reduce_while(items, :ok, fn {line, quantity}, :ok ->
      line
      |> Ash.Changeset.for_update(
        :set_delivered,
        %{delivered_quantity: Decimal.add(line.delivered_quantity, quantity)},
        opts
      )
      |> Ash.update(authorize?: false)
      |> case do
        {:ok, _line} -> {:cont, :ok}
        error -> {:halt, error}
      end
    end)
  end
end
