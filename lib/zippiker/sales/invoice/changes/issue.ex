defmodule Zippiker.Sales.Invoice.Changes.Issue do
  @moduledoc "Sets status, issue date and due date (from payment terms). Requires a positive total."
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    invoice = changeset.data

    if is_nil(invoice.total) or not Money.positive?(invoice.total) do
      Ash.Changeset.add_error(changeset,
        field: :total,
        message: "add at least one priced line before issuing"
      )
    else
      entity =
        Zippiker.Accounts.get_legal_entity!(invoice.legal_entity_id,
          tenant: changeset.tenant,
          authorize?: false
        )

      issued_on = invoice.issued_on || Date.utc_today()

      Ash.Changeset.force_change_attributes(changeset, %{
        status: :issued,
        issued_on: issued_on,
        due_on: invoice.due_on || Date.add(issued_on, entity.payment_terms_days),
        amount_paid: Money.new!(invoice.currency, 0)
      })
    end
  end
end
