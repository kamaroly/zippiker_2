defmodule Zippiker.Crm.Task.Actions do
  use Spark.Dsl.Fragment, of: Ash.Resource

  @fields [:title, :notes, :due_on, :priority, :assignee_id, :party_id, :deal_id, :lead_id]

  actions do
    defaults [:read, :destroy]

    read :list do
      argument :view, :atom,
        default: :open,
        constraints: [one_of: [:open, :today, :overdue, :upcoming, :completed, :all]]

      argument :assignee_id, :uuid
      argument :party_id, :uuid
      argument :deal_id, :uuid
      argument :lead_id, :uuid

      prepare Zippiker.Crm.Task.Preparations.List
      prepare build(load: [:assignee, :party, :deal, :lead, :done?, :overdue?])

      pagination offset?: true, countable: true, default_limit: 50, required?: false
    end

    create :create do
      primary? true
      accept @fields
      change Zippiker.Crm.Task.Changes.DefaultAssignee
    end

    update :update do
      primary? true
      accept @fields
    end

    update :complete do
      change set_attribute(:completed_at, &DateTime.utc_now/0)
    end

    update :reopen do
      change set_attribute(:completed_at, nil)
    end

    update :reassign do
      description "Moves tasks from a converted lead onto its contact."
      accept [:party_id]
    end
  end
end
