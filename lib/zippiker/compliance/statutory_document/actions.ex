defmodule Zippiker.Compliance.StatutoryDocument.Actions do
  use Spark.Dsl.Fragment, of: Ash.Resource

  actions do
    defaults [:read, :destroy]

    read :library do
      argument :profile_id, :uuid, allow_nil?: false
      filter expr(profile_id == ^arg(:profile_id))
      prepare build(sort: [inserted_at: :desc], load: [:uploaded_by])
    end

    create :create do
      primary? true
      accept [:profile_id, :kind, :name, :issued_on, :file_name, :path, :notes]
      change relate_actor(:uploaded_by)
    end
  end
end
