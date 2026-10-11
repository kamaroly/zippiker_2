defmodule Zippiker.HR.EmployeeChecklist.Actions do
  use Spark.Dsl.Fragment, of: Ash.Resource

  alias Zippiker.HR.EmployeeChecklist.Changes

  actions do
    defaults [:read]

    read :search do
      argument :kind, :atom, constraints: [one_of: [:onboarding, :offboarding]]
      argument :status, :atom, constraints: [one_of: [:in_progress, :completed, :cancelled]]
      argument :employee_id, :uuid
      filter expr(is_nil(^arg(:kind)) or kind == ^arg(:kind))
      filter expr(is_nil(^arg(:status)) or status == ^arg(:status))
      filter expr(is_nil(^arg(:employee_id)) or employee_id == ^arg(:employee_id))

      prepare build(
                sort: [inserted_at: :desc],
                load: [:tasks_count, :done_count, employee: [:name]]
              )
    end

    create :start do
      description "Starts a checklist for an employee from a template."
      accept [:employee_id, :template_id, :base_date]
      change relate_actor(:started_by, allow_nil?: true)
      change Changes.CopyTemplate
    end

    update :cancel do
      validate attribute_equals(:status, :in_progress), message: "already finished"
      change set_attribute(:status, :cancelled)
    end

    update :refresh_status do
      description "Completed when every task is done; back in progress otherwise."
      require_atomic? false
      change Changes.RefreshStatus
    end
  end
end
