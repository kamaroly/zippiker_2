defmodule Zippiker.Accounts.LegalEntity.Attributes do
  use Spark.Dsl.Fragment, of: Ash.Resource

  attributes do
    uuid_v7_primary_key :id

    attribute :name, :string, allow_nil?: false, public?: true, constraints: [max_length: 120]
    attribute :legal_name, :string, public?: true, constraints: [max_length: 200]
    attribute :tax_id, :string, public?: true, constraints: [max_length: 60]
    attribute :registration_number, :string, public?: true, constraints: [max_length: 60]
    attribute :email, :ci_string, public?: true
    attribute :phone, :string, public?: true, constraints: [max_length: 40]
    attribute :line1, :string, public?: true, constraints: [max_length: 200]
    attribute :line2, :string, public?: true, constraints: [max_length: 200]
    attribute :city, :string, public?: true, constraints: [max_length: 120]
    attribute :region, :string, public?: true, constraints: [max_length: 120]
    attribute :postal_code, :string, public?: true, constraints: [max_length: 20]
    attribute :country, :string, public?: true, constraints: [match: ~r/^[A-Z]{2}$/]

    attribute :currency, :string do
      description "Currency of documents this entity issues. Matches the workspace currency for now."
      allow_nil? false
      public? true
      constraints match: ~r/^[A-Z]{3}$/
    end

    attribute :fiscal_year_start_month, :integer do
      allow_nil? false
      public? true
      default 1
      constraints min: 1, max: 12
    end

    attribute :quote_prefix, :string,
      allow_nil?: false,
      public?: true,
      default: "QUO",
      constraints: [max_length: 10]

    attribute :invoice_prefix, :string,
      allow_nil?: false,
      public?: true,
      default: "INV",
      constraints: [max_length: 10]

    attribute :payment_terms_days, :integer do
      description "Default days between invoice issue and due date."
      allow_nil? false
      public? true
      default 30
      constraints min: 0, max: 365
    end

    attribute :invoice_footer, :string do
      description "Printed on every invoice, e.g. bank details."
      public? true
      constraints max_length: 1_000
    end

    attribute :default?, :boolean, allow_nil?: false, public?: true, default: false

    timestamps()
  end
end
