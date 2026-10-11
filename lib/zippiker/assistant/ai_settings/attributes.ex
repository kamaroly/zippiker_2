defmodule Zippiker.Assistant.AiSettings.Attributes do
  use Spark.Dsl.Fragment, of: Ash.Resource

  attributes do
    uuid_v7_primary_key :id

    attribute :scope, :string do
      description "Always \"workspace\": keeps it to one row."
      allow_nil? false
      default "workspace"
      writable? false
    end

    attribute :provider, :atom do
      allow_nil? false
      public? true
      default :anthropic
      constraints one_of: [:anthropic, :openai, :xai, :gemini, :custom]
    end

    attribute :model, :string, allow_nil?: false, public?: true, constraints: [max_length: 120]

    attribute :base_url, :string do
      description "For \"Other\": the OpenAI-compatible API base, e.g. https://openrouter.ai/api/v1."
      public? true
      constraints max_length: 300
    end

    attribute :encrypted_api_key, :string do
      sensitive? true
      writable? false
    end

    attribute :key_hint, :string do
      description "Last four characters of the key, to recognise it."
      public? true
      writable? false
    end

    attribute :enabled?, :boolean do
      description "Use this provider. Off falls back to the server's default."
      allow_nil? false
      public? true
      default true
    end

    timestamps()
  end
end
