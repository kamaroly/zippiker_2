defmodule Zippiker.Purchasing.Bill.Changes.Approve do
  @moduledoc "Opens the bill: needs a positive total; due date defaults from payment terms."
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    bill = changeset.data

    if is_nil(bill.total) or not Money.positive?(bill.total) do
      Ash.Changeset.add_error(changeset,
        field: :total,
        message: "add at least one priced line before approving"
      )
    else
      entity =
        Zippiker.Accounts.get_legal_entity!(bill.legal_entity_id,
          tenant: changeset.tenant,
          authorize?: false
        )

      Ash.Changeset.force_change_attributes(changeset, %{
        status: :open,
        due_on: bill.due_on || Date.add(bill.issued_on, entity.payment_terms_days),
        amount_paid: Money.new!(bill.currency, 0)
      })
    end
  end
end
