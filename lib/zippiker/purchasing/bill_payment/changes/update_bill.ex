defmodule Zippiker.Purchasing.BillPayment.Changes.UpdateBill do
  @moduledoc "Recomputes the bill's paid amount and status after a payment is added or removed."
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.after_action(changeset, fn changeset, payment ->
      opts = [tenant: changeset.tenant, authorize?: false]

      payment.bill_id
      |> Zippiker.Purchasing.get_bill!(opts)
      |> Ash.Changeset.for_update(:apply_payments, %{}, opts)
      |> Ash.update!(authorize?: false)

      {:ok, payment}
    end)
  end
end
