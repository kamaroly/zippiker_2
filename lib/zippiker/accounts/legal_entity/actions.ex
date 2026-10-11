defmodule Zippiker.Accounts.LegalEntity.Actions do
  use Spark.Dsl.Fragment, of: Ash.Resource

  @fields [
    :name,
    :legal_name,
    :tax_id,
    :registration_number,
    :email,
    :phone,
    :line1,
    :line2,
    :city,
    :region,
    :postal_code,
    :country,
    :fiscal_year_start_month,
    :quote_prefix,
    :invoice_prefix,
    :payment_terms_days,
    :invoice_footer
  ]

  actions do
    defaults [:read]

    read :list do
      prepare build(sort: [default?: :desc, name: :asc])
    end

    create :create do
      primary? true
      accept [:currency, :default? | @fields]
    end

    update :update do
      primary? true
      accept @fields
    end

    update :update_document_style do
      description "Changes how this entity's printed documents look."
      accept [:document_style]
    end

    update :set_logo do
      description "Points the entity at a logo already stored for this workspace."
      require_atomic? false
      argument :logo_path, :string, allow_nil?: false
      validate Zippiker.Accounts.LegalEntity.Validations.OwnLogo
      change set_attribute(:logo_path, arg(:logo_path))
    end

    update :remove_logo do
      change set_attribute(:logo_path, nil)
    end

    action :default, :struct do
      description "The workspace's default legal entity, created from the workspace on first use."
      constraints instance_of: Zippiker.Accounts.LegalEntity
      run Zippiker.Accounts.LegalEntity.Actions.Default
    end
  end
end
