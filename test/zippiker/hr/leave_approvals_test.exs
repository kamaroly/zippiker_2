defmodule Zippiker.HR.LeaveApprovalsTest do
  use Zippiker.DataCase, async: true

  import Zippiker.Fixtures

  alias Zippiker.{HR, Workflow}

  @monday ~D[2026-11-02]

  setup do
    {owner, organization} = workspace_fixture()
    opts = [actor: owner, tenant: organization]
    annual = HR.create_leave_type!(%{name: "Annual"}, opts)

    manager_user = member_fixture(organization)
    staff_user = member_fixture(organization)
    hr_user = member_fixture(organization)
    manager = HR.hire_employee!(%{first_name: "Mia", user_id: manager_user.id}, opts)

    staff =
      HR.hire_employee!(
        %{first_name: "Sam", user_id: staff_user.id, manager_id: manager.id},
        opts
      )

    as = &[actor: &1, tenant: organization]

    %{
      opts: opts,
      as: as,
      annual: annual,
      owner: owner,
      manager_user: manager_user,
      staff_user: staff_user,
      hr_user: hr_user,
      staff: staff
    }
  end

  defp request(opts, type, days \\ 1) do
    HR.request_leave!(
      %{leave_type_id: type.id, start_date: @monday, end_date: Date.add(@monday, days - 1)},
      opts
    )
  end

  test "without a workflow the manager approves, through the engine",
       %{as: as, annual: annual, staff_user: staff_user, manager_user: manager_user} do
    req = request(as.(staff_user), annual)
    assert req.status == :pending
    assert req.approval_request_id

    assert [%{document_type: :leave_request, document_id: id}] =
             Workflow.approval_inbox!(as.(manager_user))

    assert id == req.id
    assert {:error, %Ash.Error.Forbidden{}} = HR.approve_leave(req, as.(staff_user))

    approved = HR.approve_leave!(req, %{decision_note: "Enjoy"}, as.(manager_user))
    assert approved.status == :approved
    assert approved.decided_by_id == manager_user.id

    approval = Workflow.get_approval_request!(req.approval_request_id, as.(manager_user))
    assert approval.status == :approved
  end

  test "a multi-step leave workflow: manager, then HR group; long leave only",
       %{
         opts: opts,
         as: as,
         annual: annual,
         staff_user: staff_user,
         manager_user: manager_user,
         hr_user: hr_user
       } do
    hr = Workflow.create_approval_group!(%{name: "HR", member_ids: [hr_user.id]}, opts)

    Workflow.create_approval_workflow!(
      %{
        name: "Long leave",
        document_type: :leave_request,
        min_amount: "3",
        steps: [
          %{approver_type: :manager},
          %{approver_type: :group, group_id: hr.id, label: "HR"}
        ]
      },
      opts
    )

    # 1 day: default (manager only).
    short = request(as.(staff_user), annual, 1)
    assert HR.approve_leave!(short, as.(manager_user)).status == :approved

    # 5 days: manager, then HR.
    long =
      HR.request_leave!(
        %{
          leave_type_id: annual.id,
          start_date: Date.add(@monday, 7),
          end_date: Date.add(@monday, 11)
        },
        as.(staff_user)
      )

    after_manager = HR.approve_leave!(long, as.(manager_user))
    assert after_manager.status == :pending
    assert [%{document_id: id}] = Workflow.approval_inbox!(as.(hr_user))
    assert id == long.id

    assert HR.reject_leave!(after_manager, %{decision_note: "Busy week"}, as.(hr_user)).status ==
             :rejected
  end

  test "people without a login: admins decide; cancelling withdraws the approval",
       %{opts: opts, as: as, annual: annual, staff_user: staff_user} do
    ada = HR.hire_employee!(%{first_name: "Ada"}, opts)

    req =
      HR.request_leave!(
        %{employee_id: ada.id, leave_type_id: annual.id, start_date: @monday, end_date: @monday},
        opts
      )

    assert req.status == :pending
    assert HR.approve_leave!(req, opts).status == :approved

    mine = request(as.(staff_user), annual)
    HR.cancel_leave!(mine, as.(staff_user))
    assert Workflow.get_approval_request!(mine.approval_request_id, opts).status == :cancelled
  end

  test "overdue auto-decisions close the approval",
       %{opts: opts, as: as, annual: annual, staff_user: staff_user} do
    HR.create_leave_policy!(
      %{
        name: "Annual",
        leave_type_id: annual.id,
        default?: true,
        category: :unlimited,
        review_threshold_days: 1,
        overdue_action: :approve
      },
      opts
    )

    req = request(as.(staff_user), annual)

    assert %{decided: 1} =
             HR.review_overdue_leave!(%{now: DateTime.add(DateTime.utc_now(), 2, :day)}, opts)

    assert HR.get_leave_request!(req.id, opts).status == :approved
    assert Workflow.get_approval_request!(req.approval_request_id, opts).status == :cancelled
  end
end
