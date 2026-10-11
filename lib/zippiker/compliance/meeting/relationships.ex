defmodule Zippiker.Compliance.Meeting.Relationships do
  use Spark.Dsl.Fragment, of: Ash.Resource

  relationships do
    belongs_to :profile, Zippiker.Compliance.CompanyProfile, allow_nil?: false, public?: true

    has_many :resolutions, Zippiker.Compliance.Resolution do
      public? true
      destination_attribute :meeting_id
      sort position: :asc
    end
  end
end
