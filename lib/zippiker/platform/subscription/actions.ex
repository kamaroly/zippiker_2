defmodule Zippiker.Platform.Subscription.Actions do
  use Spark.Dsl.Fragment, of: Ash.Resource

  alias Zippiker.Platform.Subscription.Changes

  actions do
    defaults [:read]

    read :list do
      argument :status, :atom, constraints: [one_of: [:trialing, :active, :past_due, :canceled]]

      argument :organization_ids, {:array, :uuid}

      filter expr(
               (is_nil(^arg(:status)) or status == ^arg(:status)) and
                 (is_nil(^arg(:organization_ids)) or organization_id in ^arg(:organization_ids))
             )

      prepare build(load: [:plan, organization: [:members_count]], sort: [inserted_at: :desc])
    end

    action :ensure, :struct do
      description "The workspace's subscription, starting one on the default plan if missing."
      constraints instance_of: Zippiker.Platform.Subscription
      argument :organization_id, :uuid, allow_nil?: false
      run Zippiker.Platform.Subscription.Actions.Ensure
    end

    create :start do
      accept [:organization_id, :plan_id, :billing_email]
      change Changes.StartPeriod
      change Changes.ApplyPlanLimits
    end

    update :change_plan do
      description "Super admin: switch plan or status, extend a trial, adjust the period."
      accept [:plan_id, :status, :trial_ends_on, :current_period_end, :notes]
      require_atomic? false
      change Changes.ApplyPlanLimits
    end

    update :update_billing_details do
      accept [:billing_email]
    end

    update :advance_period do
      description "Moves to the next monthly period after it has been invoiced."
      require_atomic? false
      change Changes.AdvancePeriod
    end
  end
end
