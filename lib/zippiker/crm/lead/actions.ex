defmodule Zippiker.Crm.Lead.Actions do
  use Spark.Dsl.Fragment, of: Ash.Resource

  alias Zippiker.Crm.Lead.{Changes, Preparations}

  @fields [
    :first_name,
    :last_name,
    :company_name,
    :job_title,
    :email,
    :phone,
    :notes,
    :source,
    :status,
    :owner_id,
    :custom_fields
  ]

  actions do
    defaults [:read, :destroy]

    read :search do
      argument :query, :string
      argument :status, :atom
      argument :custom_fields, :map

      prepare Preparations.Search
      prepare Zippiker.Extensibility.CustomFields.Preparations.Filter
      prepare build(sort: [inserted_at: :desc], load: [:owner])

      pagination offset?: true, countable: true, default_limit: 25, required?: false
    end

    create :create do
      primary? true
      accept @fields -- [:status]
      change Changes.SetName
    end

    update :update do
      primary? true
      accept @fields
      require_atomic? false
      validate {Zippiker.Crm.Lead.Validations.NotConverted, []}
      change Changes.SetName
    end

    update :convert do
      description "Turns the lead into a contact, a company and optionally a deal."
      require_atomic? false

      argument :create_deal?, :boolean, default: true
      argument :deal_title, :string
      argument :deal_amount, :decimal

      validate {Zippiker.Crm.Lead.Validations.NotConverted, []}
      change Changes.Convert
    end
  end
end
