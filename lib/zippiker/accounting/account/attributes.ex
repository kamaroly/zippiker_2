defmodule Zippiker.Accounting.Account.Attributes do
  use Spark.Dsl.Fragment, of: Ash.Resource

  @system_keys [
    :cash,
    :bank,
    :mobile_money,
    :receivable,
    :payable,
    :tax_payable,
    :equity,
    :retained_earnings,
    :revenue,
    :expense,
    :inventory,
    :tax_receivable,
    :grni,
    :cost_of_sales,
    :inventory_adjustment
  ]

  attributes do
    uuid_v7_primary_key :id

    attribute :code, :string do
      allow_nil? false
      public? true
      constraints max_length: 20, match: ~r/^[A-Za-z0-9.\-]+$/
    end

    attribute :name, :string, allow_nil?: false, public?: true, constraints: [max_length: 120]

    attribute :type, :atom do
      description "Assets and expenses grow with debits; the others with credits."
      allow_nil? false
      public? true
      constraints one_of: [:asset, :liability, :equity, :income, :expense]
    end

    attribute :system_key, :atom do
      description "Set on accounts that automatic postings rely on."
      public? true
      constraints one_of: @system_keys
    end

    attribute :description, :string, public?: true, constraints: [max_length: 500]
    attribute :active?, :boolean, allow_nil?: false, public?: true, default: true

    timestamps()
  end
end
