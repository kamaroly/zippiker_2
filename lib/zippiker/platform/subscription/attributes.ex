defmodule Zippiker.Platform.Subscription.Attributes do
  use Spark.Dsl.Fragment, of: Ash.Resource

  attributes do
    uuid_v7_primary_key :id

    attribute :status, :atom do
      allow_nil? false
      public? true
      default :trialing
      constraints one_of: [:trialing, :active, :past_due, :canceled]
    end

    attribute :billing_email, :ci_string, public?: true
    attribute :trial_ends_on, :date, public?: true
    attribute :current_period_start, :date, allow_nil?: false, public?: true
    attribute :current_period_end, :date, allow_nil?: false, public?: true
    attribute :notes, :string, public?: true, constraints: [max_length: 2_000]

    timestamps()
  end
end
