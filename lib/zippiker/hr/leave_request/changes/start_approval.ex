defmodule Zippiker.HR.LeaveRequest.Changes.StartApproval do
  @moduledoc """
  Sends a pending request through the leave approval workflow
  (`Zippiker.Workflow`, document type `:leave_request`, amount = days).
  Without a workflow the employee's manager approves, or an admin when
  there's no manager. Requests approved on creation skip this.
  """
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, context) do
    Ash.Changeset.after_action(changeset, fn changeset, request ->
      if request.status == :pending do
        start(request, changeset.tenant, context)
      else
        {:ok, request}
      end
    end)
  end

  defp start(request, tenant, context) do
    opts = [tenant: tenant, actor: context.actor, authorize?: false]
    request = Ash.load!(request, [:leave_type, employee: [:name, :user]], opts)

    params = %{
      document_type: :leave_request,
      document_id: request.id,
      document_label:
        String.slice(
          "#{request.employee.name} · #{request.leave_type.name} · #{Calendar.strftime(request.start_date, "%b %-d, %Y")}",
          0,
          120
        ),
      amount: request.days
    }

    # The approval is requested by the employee (so their manager and the
    # "never your own" rule apply), even when an admin files it for them.
    # Employees without a login have no requester: their admins decide.
    with {:ok, approval} <-
           Zippiker.Workflow.start_approval(
             params,
             Keyword.put(opts, :actor, request.employee.user)
           ) do
      Zippiker.HR.LeaveRequest
      |> Ash.get!(request.id, opts)
      |> Ash.Changeset.for_update(:link_approval, %{approval_request_id: approval.id}, opts)
      |> Ash.update(authorize?: false)
    end
  end
end
