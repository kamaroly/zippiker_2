defmodule Zippiker.Compliance.Shareholder.Actions do
  use Spark.Dsl.Fragment, of: Ash.Resource

  actions do
    defaults [
      :read,
      create: [:profile_id, :name, :kind, :id_number, :nationality, :address, :email, :entered_on],
      update: [:name, :kind, :id_number, :nationality, :address, :email, :ceased_on]
    ]

    read :register do
      argument :profile_id, :uuid, allow_nil?: false
      filter expr(profile_id == ^arg(:profile_id))

      prepare build(
                sort: [entered_on: :asc, name: :asc],
                load: [:shares_held, movements: [:share_class]]
              )
    end
  end
end
