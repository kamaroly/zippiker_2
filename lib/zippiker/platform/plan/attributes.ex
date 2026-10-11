defmodule Zippiker.Platform.Plan.Attributes do
  use Spark.Dsl.Fragment, of: Ash.Resource

  attributes do
    uuid_v7_primary_key :id

    attribute :code, :string do
      allow_nil? false
      public? true
      constraints match: ~r/^[a-z0-9_-]+$/, max_length: 40
    end

    attribute :name, :string, allow_nil?: false, public?: true, constraints: [max_length: 60]
    attribute :description, :string, public?: true, constraints: [max_length: 280]

    attribute :price_per_seat, :decimal do
      description "Monthly price per member."
      allow_nil? false
      public? true
      default Decimal.new(0)
      constraints min: 0
    end

    attribute :currency, :string do
      allow_nil? false
      public? true
      default "USD"
      constraints match: ~r/^[A-Z]{3}$/
    end

    attribute :seat_limit, :integer do
      description "Maximum members; empty means unlimited."
      public? true
      constraints min: 1
    end

    attribute :modules, {:array, :atom} do
      allow_nil? false
      public? true

      default [
        :crm,
        :sales,
        :purchasing,
        :inventory,
        :accounting,
        :hr,
        :expenses,
        :manufacturing,
        :compliance
      ]

      constraints items: [
                    one_of: [
                      :crm,
                      :sales,
                      :purchasing,
                      :inventory,
                      :accounting,
                      :hr,
                      :expenses,
                      :manufacturing,
                      :compliance
                    ]
                  ]
    end

    attribute :trial_days, :integer do
      allow_nil? false
      public? true
      default 14
      constraints min: 0
    end

    attribute :default?, :boolean do
      description "New workspaces start on this plan."
      allow_nil? false
      public? true
      default false
    end

    attribute :active?, :boolean, allow_nil?: false, public?: true, default: true
    attribute :position, :integer, allow_nil?: false, public?: true, default: 0

    timestamps()
  end
end
