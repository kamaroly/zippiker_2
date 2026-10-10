defmodule Zippiker.Accounts.Invitation.Attributes do
  use Spark.Dsl.Fragment, of: Ash.Resource

  attributes do
    uuid_v7_primary_key :id

    attribute :email, :ci_string, allow_nil?: false, public?: true

    attribute :role, :atom do
      allow_nil? false
      public? true
      default :member
      constraints one_of: [:admin, :member]
    end

    attribute :token, :string, allow_nil?: false, sensitive?: true
    attribute :expires_at, :utc_datetime_usec, allow_nil?: false, public?: true
    attribute :accepted_at, :utc_datetime_usec, public?: true

    timestamps()
  end
end
