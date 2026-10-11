defmodule Zippiker.Compliance.Charge.Actions do
  use Spark.Dsl.Fragment, of: Ash.Resource

  actions do
    defaults [:read]

    read :register do
      argument :profile_id, :uuid, allow_nil?: false
      filter expr(profile_id == ^arg(:profile_id))
      prepare build(sort: [created_on: :desc], load: [:outstanding?])
    end

    create :create do
      primary? true
      accept [:profile_id, :chargee, :description, :amount_secured, :currency, :created_on]
      change {Zippiker.Compliance.Changes.AddFiling, event: :charge_created}
    end

    update :update do
      primary? true

      accept [
        :chargee,
        :description,
        :amount_secured,
        :currency,
        :registered_on,
        :registration_number
      ]
    end

    update :satisfy do
      require_atomic? false
      accept [:satisfied_on]
      validate present(:satisfied_on)
      change {Zippiker.Compliance.Changes.AddFiling, event: :charge_satisfied}
    end
  end
end
