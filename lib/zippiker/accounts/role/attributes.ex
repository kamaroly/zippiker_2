defmodule Zippiker.Accounts.Role.Attributes do
  use Spark.Dsl.Fragment, of: Ash.Resource

  attributes do
    uuid_v7_primary_key :id

    attribute :name, :string do
      allow_nil? false
      public? true
      constraints max_length: 60
    end

    attribute :description, :string, public?: true, constraints: [max_length: 300]

    attribute :key, :string do
      description "Set on the built-in roles (e.g. \"sales_rep\"); custom roles have none."
      public? true
      writable? false
    end

    attribute :permissions, {:array, :string} do
      description "Permission keys from `Zippiker.Accounts.Permissions`."
      allow_nil? false
      public? true
      default []
    end

    attribute :default?, :boolean do
      description "Given to people when they join the workspace."
      allow_nil? false
      public? true
      default false
    end

    timestamps()
  end
end
