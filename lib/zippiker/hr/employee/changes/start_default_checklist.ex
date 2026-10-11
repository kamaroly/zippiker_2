defmodule Zippiker.HR.Employee.Changes.StartDefaultChecklist do
  @moduledoc """
  On hiring (`kind: :onboarding`) or leaving (`kind: :offboarding`), starts
  the team's default active template of that kind, if there is one.
  """
  use Ash.Resource.Change

  require Ash.Query

  @impl true
  def init(opts), do: {:ok, opts}

  @impl true
  def change(changeset, opts, context) do
    kind = Keyword.fetch!(opts, :kind)

    Ash.Changeset.after_action(changeset, fn changeset, employee ->
      tenant_opts = [tenant: changeset.tenant, authorize?: false]

      template =
        Zippiker.HR.ChecklistTemplate
        |> Ash.Query.filter(kind == ^kind and default? == true and active? == true)
        |> Ash.read_one!(tenant_opts)

      base =
        case kind do
          :onboarding -> employee.hire_date
          :offboarding -> employee.termination_date
        end || Date.utc_today()

      if template do
        Zippiker.HR.EmployeeChecklist
        |> Ash.Changeset.for_create(
          :start,
          %{employee_id: employee.id, template_id: template.id, base_date: base},
          tenant_opts ++ [actor: context.actor]
        )
        |> Ash.create!(authorize?: false)
      end

      {:ok, employee}
    end)
  end
end
