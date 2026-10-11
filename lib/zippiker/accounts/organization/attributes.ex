defmodule Zippiker.Accounts.Organization.Attributes do
  use Spark.Dsl.Fragment, of: Ash.Resource

  attributes do
    uuid_v7_primary_key :id

    attribute :name, :string do
      allow_nil? false
      public? true
      constraints min_length: 2, max_length: 120
    end

    attribute :domain, :string do
      description """
      The team's domain (e.g. `acme` or `acme.com`), chosen when the team is
      created; `team_<n>` when left blank. Names the team's database schema.
      """

      allow_nil? false
      public? true
      constraints max_length: 63
    end

    attribute :schema_name, :string do
      description "The Postgres schema holding this team's data (from the domain)."
      allow_nil? false
      public? true
      writable? false
      constraints max_length: 63
    end

    attribute :currency, :string do
      description "ISO 4217 base currency used for reporting."
      allow_nil? false
      public? true
      default "USD"
      constraints match: ~r/^[A-Z]{3}$/
    end

    attribute :enabled_modules, {:array, :atom} do
      description "Business modules switched on for this workspace. Managed by the platform."
      allow_nil? false
      public? true
      default [:crm, :sales, :purchasing, :inventory, :accounting, :hr, :expenses, :manufacturing]

      constraints items: [
                    one_of: [
                      :crm,
                      :sales,
                      :purchasing,
                      :inventory,
                      :accounting,
                      :hr,
                      :expenses,
                      :manufacturing
                    ]
                  ]
    end

    attribute :seat_limit, :integer do
      description "Maximum members (nil = unlimited). Comes from the billing plan."
      public? true
      constraints min: 1
    end

    timestamps()
  end
end
