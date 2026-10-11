defmodule Zippiker.Compliance.BeneficialOwner.Actions do
  use Spark.Dsl.Fragment, of: Ash.Resource

  @fields [
    :name,
    :nationality,
    :id_number,
    :kra_pin,
    :date_of_birth,
    :address,
    :email,
    :phone,
    :shares_percent,
    :voting_percent,
    :appoints_directors?,
    :significant_influence?
  ]

  actions do
    defaults [:read]

    read :register do
      argument :profile_id, :uuid, allow_nil?: false
      filter expr(profile_id == ^arg(:profile_id))
      prepare build(sort: [ceased_on: :desc, became_owner_on: :asc])
    end

    create :create do
      primary? true
      accept [:profile_id, :became_owner_on | @fields]
      change {Zippiker.Compliance.Changes.AddFiling, event: :owner_added}
    end

    update :update do
      primary? true
      require_atomic? false
      accept @fields
      change {Zippiker.Compliance.Changes.AddFiling, event: :owner_changed}
    end

    update :cease do
      require_atomic? false
      accept [:ceased_on]
      validate present(:ceased_on)
      change {Zippiker.Compliance.Changes.AddFiling, event: :owner_ceased}
    end
  end
end
