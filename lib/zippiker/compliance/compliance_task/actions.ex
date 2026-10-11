defmodule Zippiker.Compliance.ComplianceTask.Actions do
  use Spark.Dsl.Fragment, of: Ash.Resource

  actions do
    defaults [:read]

    read :calendar do
      argument :profile_id, :uuid, allow_nil?: false
      argument :open_only?, :boolean, default: false
      filter expr(profile_id == ^arg(:profile_id))
      filter expr(^arg(:open_only?) == false or is_nil(completed_on))
      prepare build(sort: [completed_on: :desc, due_on: :asc], load: [:state])
    end

    create :create do
      primary? true
      accept [:profile_id, :kind, :title, :description, :due_on, :notes, :period]
      upsert? true
      upsert_identity :one_per_period
      upsert_fields []
    end

    update :complete do
      accept [:completed_on, :reference, :notes]
      validate present(:completed_on)
    end

    update :reopen do
      change set_attribute(:completed_on, nil)
    end
  end
end
