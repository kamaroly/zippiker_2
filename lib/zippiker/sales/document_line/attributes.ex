defmodule Zippiker.Sales.DocumentLine.Attributes do
  @moduledoc "Fields shared by every document line (quotes, invoices, later purchase orders)."
  use Spark.Dsl.Fragment, of: Ash.Resource

  attributes do
    uuid_v7_primary_key :id

    attribute :position, :integer, allow_nil?: false, public?: true, default: 0

    attribute :description, :string,
      allow_nil?: false,
      public?: true,
      constraints: [max_length: 1_000]

    attribute :quantity, :decimal,
      allow_nil?: false,
      public?: true,
      default: 1,
      constraints: [min: 0]

    attribute :unit, :string, public?: true, constraints: [max_length: 20]

    attribute :unit_price, :decimal,
      allow_nil?: false,
      public?: true,
      default: 0,
      constraints: [min: 0]

    attribute :discount_percent, :decimal do
      allow_nil? false
      public? true
      default 0
      constraints min: 0, max: 100
    end

    attribute :tax_percent, :decimal, allow_nil?: false, public?: true, default: 0
    attribute :subtotal, :decimal, allow_nil?: false, public?: true, default: 0
    attribute :tax_amount, :decimal, allow_nil?: false, public?: true, default: 0
    attribute :total, :decimal, allow_nil?: false, public?: true, default: 0

    timestamps()
  end

  relationships do
    belongs_to :organization, Zippiker.Accounts.Organization do
      allow_nil? false
      domain Zippiker.Accounts
    end

    belongs_to :product, Zippiker.Catalog.Product do
      public? true
      domain Zippiker.Catalog
    end

    belongs_to :tax_rate, Zippiker.Catalog.TaxRate do
      public? true
      domain Zippiker.Catalog
    end
  end
end
