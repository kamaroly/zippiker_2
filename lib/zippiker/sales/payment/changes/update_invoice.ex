defmodule Zippiker.Sales.Payment.Changes.UpdateInvoice do
  @moduledoc "Recomputes the invoice's paid amount and status after a payment is added or removed."
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, context) do
    Ash.Changeset.after_action(changeset, fn changeset, payment ->
      opts = [tenant: changeset.tenant, actor: context.actor, authorize?: false]

      payment.invoice_id
      |> Zippiker.Sales.get_invoice!(opts)
      |> Ash.Changeset.for_update(:apply_payments, %{}, opts)
      |> Ash.update!()

      {:ok, payment}
    end)
  end
end
