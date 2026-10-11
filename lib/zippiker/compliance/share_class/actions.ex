defmodule Zippiker.Compliance.ShareClass.Actions do
  use Spark.Dsl.Fragment, of: Ash.Resource

  actions do
    defaults [
      :read,
      :destroy,
      create: [:profile_id, :name, :nominal_value, :rights],
      update: [:name, :nominal_value, :rights]
    ]

    read :for_profile do
      argument :profile_id, :uuid, allow_nil?: false
      filter expr(profile_id == ^arg(:profile_id))
      prepare build(sort: [name: :asc])
    end
  end
end
