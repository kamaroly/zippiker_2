defmodule Zippiker.Accounts.User.Attributes do
  use Spark.Dsl.Fragment, of: Ash.Resource

  attributes do
    uuid_primary_key :id

    attribute :email, :ci_string do
      allow_nil? false
      public? true
    end

    attribute :hashed_password, :string do
      allow_nil? false
      sensitive? true
    end

    attribute :confirmed_at, :utc_datetime_usec

    attribute :name, :string do
      public? true
      constraints max_length: 120
    end

    attribute :super_admin?, :boolean do
      description "Platform operator: sees every workspace, impersonates users, manages billing."
      allow_nil? false
      default false
      public? true
    end

    create_timestamp :inserted_at
  end
end
