defmodule Zippiker.Inventory.StockOperation do
  @moduledoc """
  A stock document: a receipt (`GRN-2026-0001`), a delivery (`DO-…`) or an
  adjustment (`ADJ-…`), made of movements. Operations update product average
  costs, post their value to the books, and are undone by reversal.
  """
  use Ash.Resource,
    otp_app: :zippiker,
    domain: Zippiker.Inventory,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    fragments: [
      Zippiker.Inventory.StockOperation.Attributes,
      Zippiker.Inventory.StockOperation.Relationships,
      Zippiker.Inventory.StockOperation.Actions,
      Zippiker.Inventory.StockOperation.Policies
    ]

  postgres do
    table "stock_operations"
    repo Zippiker.Repo

    identity_wheres_to_sql unique_number: "number IS NOT NULL",
                           unique_reversal: "reversal_of_id IS NOT NULL"

    references do
      reference :organization, on_delete: :delete
      reference :legal_entity, on_delete: :restrict
      reference :warehouse, on_delete: :restrict
      reference :party, on_delete: :nilify
      reference :created_by, on_delete: :nilify
      reference :reversal_of, on_delete: :restrict
    end

    custom_indexes do
      index [:organization_id, :source, :source_id]
    end
  end

  multitenancy do
    strategy :attribute
    attribute :organization_id
  end

  identities do
    identity :unique_number, [:legal_entity_id, :number], where: expr(not is_nil(number))
    identity :unique_reversal, [:reversal_of_id], where: expr(not is_nil(reversal_of_id))
  end
end
