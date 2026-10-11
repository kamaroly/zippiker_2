defmodule Zippiker.Compliance.Meeting.Actions do
  use Spark.Dsl.Fragment, of: Ash.Resource

  @fields [
    :kind,
    :title,
    :held_on,
    :location,
    :notice_sent_on,
    :agenda,
    :attendees,
    :minutes,
    :status
  ]

  actions do
    defaults [:read]

    read :list do
      argument :profile_id, :uuid, allow_nil?: false
      filter expr(profile_id == ^arg(:profile_id))
      prepare build(sort: [held_on: :desc], load: [:resolutions])
    end

    create :create do
      primary? true
      accept [:profile_id | @fields]
      argument :resolutions, {:array, :map}, default: []
      change manage_relationship(:resolutions, type: :direct_control)
      change Zippiker.Compliance.Meeting.Changes.FileResolutions
    end

    update :update do
      primary? true
      require_atomic? false
      accept @fields
      argument :resolutions, {:array, :map}
      change manage_relationship(:resolutions, type: :direct_control)
      change Zippiker.Compliance.Meeting.Changes.FileResolutions
    end
  end
end
