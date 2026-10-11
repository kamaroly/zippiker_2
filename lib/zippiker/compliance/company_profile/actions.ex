defmodule Zippiker.Compliance.CompanyProfile.Actions do
  use Spark.Dsl.Fragment, of: Ash.Resource

  @fields [
    :registration_number,
    :company_type,
    :incorporation_date,
    :kra_pin,
    :registered_office,
    :postal_address,
    :email,
    :year_end_month,
    :year_end_day,
    :authorised_capital,
    :auditor,
    :secretary_required?
  ]

  actions do
    defaults [:read]

    read :list do
      prepare build(load: [:legal_entity], sort: [inserted_at: :asc])
    end

    create :create do
      primary? true
      accept [:legal_entity_id | @fields]
      change Zippiker.Compliance.Changes.RefreshCalendar
    end

    update :update do
      primary? true
      require_atomic? false
      accept @fields
      change Zippiker.Compliance.CompanyProfile.Changes.OfficeChangeNotice
      change Zippiker.Compliance.Changes.RefreshCalendar
    end
  end
end
