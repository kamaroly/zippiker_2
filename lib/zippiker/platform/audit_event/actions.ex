defmodule Zippiker.Platform.AuditEvent.Actions do
  use Spark.Dsl.Fragment, of: Ash.Resource

  actions do
    defaults [:read]

    read :recent do
      argument :organization_id, :uuid
      filter expr(is_nil(^arg(:organization_id)) or organization_id == ^arg(:organization_id))
      prepare build(sort: [inserted_at: :desc], load: [:actor, :organization, :target_user])
      pagination offset?: true, default_limit: 20, required?: false
    end

    create :log do
      accept [:action, :summary, :organization_id, :target_user_id]
      change relate_actor(:actor, allow_nil?: true)
    end

    create :request_plan do
      description "A workspace admin asks the platform team to move them to another plan."
      argument :plan_id, :uuid, allow_nil?: false
      change relate_actor(:actor)
      change Zippiker.Platform.AuditEvent.Changes.RequestPlan
    end
  end
end
