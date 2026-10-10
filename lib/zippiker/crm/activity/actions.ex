defmodule Zippiker.Crm.Activity.Actions do
  use Spark.Dsl.Fragment, of: Ash.Resource

  actions do
    defaults [:read, :destroy]

    read :timeline do
      description "Newest-first history for a record. A company includes its people's history."
      argument :party_id, :uuid
      argument :deal_id, :uuid
      argument :lead_id, :uuid
      argument :limit, :integer, default: 50

      prepare Zippiker.Crm.Activity.Preparations.Timeline
      prepare build(sort: [occurred_at: :desc], load: [:author, :party, :deal])
    end

    create :create do
      primary? true
      accept [:kind, :subject, :body, :occurred_at, :party_id, :deal_id, :lead_id]
      change relate_actor(:author, allow_nil?: true)
      validate present([:party_id, :deal_id, :lead_id], at_least: 1)
    end

    update :reassign do
      description "Moves history from a converted lead onto its contact."
      accept [:party_id]
    end
  end
end
