defmodule Zippiker.Purchasing.Bill.Changes.ApplyPayments do
  @moduledoc "Sets `amount_paid` from the payments and flips between open and paid."
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    bill =
      Ash.load!(changeset.data, [:payments_total],
        tenant: changeset.tenant,
        authorize?: false,
        reuse_values?: false
      )

    paid = bill.payments_total || Money.new!(bill.currency, 0)
    fully_paid? = Money.compare!(paid, bill.total) != :lt

    Ash.Changeset.force_change_attributes(changeset, %{
      amount_paid: paid,
      status: if(fully_paid?, do: :paid, else: :open),
      paid_at: if(fully_paid?, do: bill.paid_at || DateTime.utc_now())
    })
  end
end
