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

    action :default, :struct do
      description "The workspace's default legal entity, created from the workspace on first use."
      constraints instance_of: Zippiker.Accounts.LegalEntity
      run Zippiker.Accounts.LegalEntity.Actions.Default
    end
  end
end
