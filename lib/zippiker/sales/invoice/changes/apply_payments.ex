defmodule Zippiker.Sales.Invoice.Changes.ApplyPayments do
  @moduledoc "Sets `amount_paid` from the payments and flips between issued and paid."
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    invoice =
      Ash.load!(changeset.data, [:payments_total],
        tenant: changeset.tenant,
        authorize?: false,
        reuse_values?: false
      )

    paid = invoice.payments_total || Money.new!(invoice.currency, 0)
    fully_paid? = Money.compare!(paid, invoice.total) != :lt

    Ash.Changeset.force_change_attributes(changeset, %{
      amount_paid: paid,
      status: if(fully_paid?, do: :paid, else: :issued),
      paid_at: if(fully_paid?, do: invoice.paid_at || DateTime.utc_now())
    })
  end
end
