defmodule Zippiker.HR.ChecklistTask.Actions do
  use Spark.Dsl.Fragment, of: Ash.Resource

  alias Zippiker.HR.ChecklistTask.{Changes, Validations}

  actions do
    defaults [:read]

    read :assigned_to_me do
      description "Open tasks the actor has to do (HR tasks too, for admins)."
      argument :include_hr?, :boolean, default: false

      filter expr(
               status == :open and checklist.status == :in_progress and
                 (assignee_id == ^actor(:id) or
                    (^arg(:include_hr?) == true and assignee_role == :hr))
             )

      prepare build(
                sort: [due_on: :asc],
                load: [checklist: [employee: [:name]]]
              )
    end

    create :create do
      primary? true

      accept [
        :checklist_id,
        :position,
        :title,
        :description,
        :assignee_role,
        :assignee_id,
        :due_on,
        :requires_attachment?
      ]
    end

    update :complete do
      require_atomic? false
      accept [:note]
      validate attribute_equals(:status, :open), message: "already done"
      validate Validations.AttachmentGiven
      change set_attribute(:status, :done)
      change set_attribute(:done_at, &DateTime.utc_now/0)
      change relate_actor(:done_by)
      change Changes.RefreshChecklist
    end

    update :reopen do
      require_atomic? false
      validate attribute_equals(:status, :done), message: "not done yet"
      change set_attribute(:status, :open)
      change set_attribute(:done_at, nil)
      change set_attribute(:done_by_id, nil)
      change Changes.RefreshChecklist
    end
  end
end
