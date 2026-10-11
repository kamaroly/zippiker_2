defmodule Zippiker.Inventory.StockOperation.Relationships do
  use Spark.Dsl.Fragment, of: Ash.Resource

  relationships do
    belongs_to :legal_entity, Zippiker.Accounts.LegalEntity do
      allow_nil? false
      public? true
      domain Zippiker.Accounts
    end

    belongs_to :warehouse, Zippiker.Inventory.Warehouse, allow_nil?: false, public?: true

    belongs_to :party, Zippiker.Parties.Party do
      description "Supplier on a receipt, customer on a delivery."
      public? true
      domain Zippiker.Parties
    end

    belongs_to :created_by, Zippiker.Accounts.User do
      public? true
      domain Zippiker.Accounts
    end

    belongs_to :reversal_of, Zippiker.Inventory.StockOperation, public?: true

    has_one :reversal, Zippiker.Inventory.StockOperation do
      public? true
      destination_attribute :reversal_of_id
    end

    has_many :movements, Zippiker.Inventory.StockMovement do
      public? true
      destination_attribute :operation_id
      sort position: :asc
    end
  end
end
