defmodule Zippiker.Inventory.StockOperation.Changes.AssignNumber do
  @moduledoc """
  `MV-…` for receipts and deliveries (their paperwork is the goods received
  note / delivery note), `ADJ-…` for adjustments, `PRD-…` for production;
  gap-free per year.
  """
  use Ash.Resource.Change

  @prefixes %{receipt: "MV", delivery: "MV", adjustment: "ADJ", production: "PRD"}
  @sequences %{
    receipt: :stock_movement,
    delivery: :stock_movement,
    adjustment: :stock_adjustment,
    production: :stock_production
  }

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.before_action(changeset, fn changeset ->
      kind = Ash.Changeset.get_attribute(changeset, :kind)
      entity_id = Ash.Changeset.get_attribute(changeset, :legal_entity_id)

      number =
        Zippiker.Accounts.next_document_number!(
          entity_id,
          Map.fetch!(@sequences, kind),
          Map.fetch!(@prefixes, kind),
          tenant: changeset.tenant,
          authorize?: false
        )

      Ash.Changeset.force_change_attribute(changeset, :number, number)
    end)
  end
end
