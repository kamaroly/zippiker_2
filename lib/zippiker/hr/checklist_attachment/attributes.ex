defmodule Zippiker.HR.ChecklistAttachment.Attributes do
  use Spark.Dsl.Fragment, of: Ash.Resource

  attributes do
    uuid_v7_primary_key :id
    attribute :name, :string, allow_nil?: false, public?: true, constraints: [max_length: 255]

    attribute :path, :string do
      description "Where the file is stored, relative to the uploads directory."
      allow_nil? false
      public? true
      constraints max_length: 500
    end

    create_timestamp :inserted_at
  end
end
