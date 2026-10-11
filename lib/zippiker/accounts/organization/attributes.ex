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

    attribute :multi_branch?, :boolean do
      description "The business has several branches: branch pickers and branch reports show."
      allow_nil? false
      public? true
      default false
    end

    attribute :maker_checker?, :boolean do
      description "Maker-checker: changes in `maker_checker_scopes` need a second person's approval."
      allow_nil? false
      public? true
      default false
    end

    attribute :maker_checker_scopes, {:array, :atom} do
      description "Areas whose changes go through change requests when maker-checker is on."
      allow_nil? false
      public? true
      default []
      constraints items: [one_of: [:employees, :contacts, :products, :accounts, :tax_rates]]
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
