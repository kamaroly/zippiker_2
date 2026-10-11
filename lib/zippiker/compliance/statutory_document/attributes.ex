defmodule Zippiker.Compliance.StatutoryDocument.Attributes do
  use Spark.Dsl.Fragment, of: Ash.Resource

  attributes do
    uuid_v7_primary_key :id

    attribute :kind, :atom do
      allow_nil? false
      public? true
      default :other

      constraints one_of: [
                    :incorporation_certificate,
                    :articles,
                    :cr12,
                    :annual_return,
                    :minutes,
                    :resolution,
                    :share_certificate,
                    :beneficial_ownership,
                    :tax,
                    :other
                  ]
    end

    attribute :name, :string, allow_nil?: false, public?: true, constraints: [max_length: 200]
    attribute :issued_on, :date, public?: true

    attribute :file_name, :string,
      allow_nil?: false,
      public?: true,
      constraints: [max_length: 255]

    attribute :path, :string, allow_nil?: false, public?: true, constraints: [max_length: 500]
    attribute :notes, :string, public?: true, constraints: [max_length: 500]
    create_timestamp :inserted_at
  end
end
