defmodule Zippiker.Compliance.Officer.Actions do
  use Spark.Dsl.Fragment, of: Ash.Resource

  @fields [
    :name,
    :role,
    :nationality,
    :id_number,
    :kra_pin,
    :date_of_birth,
    :occupation,
    :email,
    :phone,
    :residential_address,
    :service_address
  ]

  actions do
    defaults [:read]

    read :register do
      argument :profile_id, :uuid, allow_nil?: false
      argument :active_only?, :boolean, default: false
      filter expr(profile_id == ^arg(:profile_id))
      filter expr(^arg(:active_only?) == false or is_nil(ceased_on))
      prepare build(sort: [ceased_on: :desc, appointed_on: :asc], load: [:active?])
    end

    create :appoint do
      primary? true
      accept [:profile_id, :appointed_on | @fields]
      change {Zippiker.Compliance.Changes.AddFiling, event: :appointed}
    end

    update :update do
      primary? true
      accept @fields
    end

    update :cease do
      require_atomic? false
      accept [:ceased_on, :cessation_reason]
      validate present(:ceased_on)
      change {Zippiker.Compliance.Changes.AddFiling, event: :ceased}
    end
  end
end
