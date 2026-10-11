defmodule Zippiker.Accounts.PortalAccess.Attributes do
  use Spark.Dsl.Fragment, of: Ash.Resource

  attributes do
    uuid_v7_primary_key :id
    attribute :email, :ci_string, allow_nil?: false, public?: true

    attribute :kind, :atom do
      allow_nil? false
      public? true
      constraints one_of: [:customer, :supplier]
    end

    attribute :party_id, :uuid do
      description "The customer or supplier (in the team's schema) this person acts for."
      allow_nil? false
      public? true
    end

    attribute :party_name, :string, public?: true, constraints: [max_length: 200]

    attribute :status, :atom do
      allow_nil? false
      public? true
      default :invited
      constraints one_of: [:invited, :active, :revoked]
    end

    attribute :token, :string, allow_nil?: false, sensitive?: true
    attribute :accepted_at, :utc_datetime_usec, public?: true
    timestamps()
  end
end
