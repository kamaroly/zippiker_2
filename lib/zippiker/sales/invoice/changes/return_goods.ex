defmodule Zippiker.Sales.Invoice.Changes.ReturnGoods do
  @moduledoc "Voiding an invoice puts back the goods it shipped (not those shipped by its order)."
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, context) do
    Ash.Changeset.after_action(changeset, fn changeset, invoice ->
      opts = [tenant: changeset.tenant, actor: context.actor, authorize?: false]

      case Zippiker.Sales.Shipping.return(:invoice, invoice.id, opts) do
        :ok -> {:ok, invoice}
        error -> error
      end
    end)
  end
end
