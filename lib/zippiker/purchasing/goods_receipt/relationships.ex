defmodule Zippiker.Purchasing.GoodsReceipt.Relationships do
  use Spark.Dsl.Fragment, of: Ash.Resource

  relationships do
    belongs_to :organization, Zippiker.Accounts.Organization do
      allow_nil? false
      domain Zippiker.Accounts
    end

    belongs_to :legal_entity, Zippiker.Accounts.LegalEntity do
      allow_nil? false
      public? true
      domain Zippiker.Accounts
    end

    belongs_to :supplier, Zippiker.Parties.Party do
      allow_nil? false
      public? true
      domain Zippiker.Parties
    end

    belongs_to :purchase_order, Zippiker.Purchasing.PurchaseOrder, public?: true
    belongs_to :bill, Zippiker.Purchasing.Bill, public?: true

    belongs_to :warehouse, Zippiker.Inventory.Warehouse do
      public? true
      domain Zippiker.Inventory
    end

    belongs_to :received_by, Zippiker.Accounts.User do
      public? true
      domain Zippiker.Accounts
    end

    belongs_to :stock_operation, Zippiker.Inventory.StockOperation do
      public? true
      domain Zippiker.Inventory
    end

    has_many :lines, Zippiker.Purchasing.GoodsReceiptLine do
      public? true
      sort position: :asc
    end
  end
end
