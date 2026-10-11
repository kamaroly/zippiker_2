defmodule Zippiker.Assistant.AiSettings.Actions do
  use Spark.Dsl.Fragment, of: Ash.Resource

  alias Zippiker.Assistant.AiSettings.{Actions, Validations}

  @fields [:provider, :model, :base_url, :enabled?]

  actions do
    defaults [:read]

    read :current do
      get? true
      filter expr(scope == "workspace")
    end

    create :create do
      accept @fields
      argument :api_key, :string, sensitive?: true, constraints: [max_length: 500]
      validate Validations.BaseUrl
      change Actions.StoreKey
    end

    update :update do
      accept @fields
      argument :api_key, :string, sensitive?: true, constraints: [max_length: 500]
      require_atomic? false
      validate Validations.BaseUrl
      change Actions.StoreKey
    end

    update :remove_key do
      change set_attribute(:encrypted_api_key, nil)
      change set_attribute(:key_hint, nil)
    end

    action :configure, :struct do
      description """
      Saves the workspace's provider, model and (when given) a new API key.
      Without a new key the stored one is kept.
      """

      constraints instance_of: Zippiker.Assistant.AiSettings
      argument :provider, :atom, allow_nil?: false
      argument :model, :string, allow_nil?: false
      argument :base_url, :string
      argument :enabled?, :boolean, default: true
      argument :api_key, :string, sensitive?: true
      run Actions.Configure
    end
  end
end
