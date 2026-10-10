defmodule Zippiker.ExpensesTest do
  use Zippiker.DataCase, async: true

  import Zippiker.Fixtures

  alias Zippiker.{Accounting, Expenses, HR, Workflow}

  setup do
    {owner, organization} = workspace_fixture()
    opts = [actor: owner, tenant: organization]
    Accounting.setup_books!(opts)

    travel_account =
      Accounting.list_accounts!(opts) |> Enum.find(&(&1.name == "Travel"))

    travel =
      Expenses.create_expense_category!(%{name: "Travel", account_id: travel_account.id}, opts)

    meals = Expenses.create_expense_category!(%{name: "Meals"}, opts)

    %{
      owner: owner,
      organization: organization,
      opts: opts,
      travel: travel,
      meals: meals,
      travel_account: travel_account
    }
  end

  defp claim(opts, items) do
    Expenses.create_expense_claim!(%{title: "Client visit", items: items}, opts)
  end

  defp items(travel, meals) do
    [
      %{description: "Taxi", amount: "40", category_id: travel.id, merchant: "City Cabs"},
      %{description: "Lunch", amount: "25.50", category_id: meals.id}
    ]
  end

  defp balance(opts, key) do
    account = Accounting.list_accounts!(opts) |> Enum.find(&(&1.system_key == key))
    Accounting.get_account!(account.id, opts ++ [load: [:balance]]).balance
  end

  test "claims are numbered, totalled and editable until submitted",
       %{organization: organization, travel: travel, meals: meals} do
    staff = member_fixture(organization)
    staff_opts = [actor: staff, tenant: organization]

    draft = claim(staff_opts, items(travel, meals))
    assert draft.number =~ ~r/^EXP-\d{4}-\d{4}$/
    assert Money.equal?(draft.total, Money.new!(draft.currency, "65.50"))
    assert draft.claimant_id == staff.id

    updated =
      Expenses.update_expense_claim!(
        draft,
        %{items: [%{description: "Taxi", amount: "10", category_id: travel.id}]},
        staff_opts
      )

    assert Money.equal?(updated.total, Money.new!(draft.currency, 10))

    # Someone else (not an admin) can't touch it.
    other = member_fixture(organization)

    assert {:error, %Ash.Error.Forbidden{}} =
             Expenses.update_expense_claim(updated, %{title: "Mine now"},
               actor: other,
               tenant: organization
             )

    empty = claim(staff_opts, [])
    assert {:error, %Ash.Error.Invalid{}} = Expenses.submit_expense_claim(empty, staff_opts)
  end

  test "multi-step workflow: manager, then a group, then a specific user (final approver)",
       %{organization: organization, opts: opts, travel: travel, meals: meals} do
    staff = member_fixture(organization)
    manager_user = member_fixture(organization)
    finance_a = member_fixture(organization)
    finance_b = member_fixture(organization)
    cfo = member_fixture(organization)

    manager = HR.hire_employee!(%{first_name: "Mia", user_id: manager_user.id}, opts)
    HR.hire_employee!(%{first_name: "Sam", user_id: staff.id, manager_id: manager.id}, opts)

    finance =
      Workflow.create_approval_group!(
        %{name: "Finance", member_ids: [finance_a.id, finance_b.id]},
        opts
      )

    Workflow.create_approval_workflow!(
      %{
        name: "Expenses",
        document_type: :expense_claim,
        steps: [
          %{approver_type: :manager, label: "Line manager"},
          %{approver_type: :group, group_id: finance.id, label: "Finance"},
          %{approver_type: :user, user_id: cfo.id, label: "CFO"}
        ]
      },
      opts
    )

    as = &[actor: &1, tenant: organization]

    submitted =
      claim(as.(staff), items(travel, meals)) |> Expenses.submit_expense_claim!(as.(staff))

    assert submitted.status == :submitted

    request =
      Workflow.get_approval_request!(submitted.approval_request_id, opts ++ [load: [:steps]])

    assert Enum.map(request.steps, & &1.status) == [:pending, :waiting, :waiting]

    # Only the current step's approvers can decide, and the inbox shows it to them.
    assert [%{id: id}] = Workflow.approval_inbox!(as.(manager_user))
    assert id == request.id
    assert Workflow.approval_inbox!(as.(finance_a)) == []

    assert {:error, %Ash.Error.Invalid{}} =
             Workflow.decide_approval(request, :approve, as.(finance_a))

    assert {:error, %Ash.Error.Invalid{}} =
             Workflow.decide_approval(request, :approve, as.(staff))

    request = Workflow.decide_approval!(request, :approve, as.(manager_user))
    assert request.current_position == 2

    # Anyone in the group can take the group step.
    request = Workflow.decide_approval!(request, :approve, as.(finance_b))
    assert request.current_position == 3
    assert Expenses.get_expense_claim!(submitted.id, opts).status == :submitted

    request =
      Workflow.decide_approval!(request, :approve, %{comment: "OK"}, as.(cfo))

    assert request.status == :approved

    approved = Expenses.get_expense_claim!(submitted.id, opts)
    assert approved.status == :approved
    assert approved.approved_at

    # Expenses booked by category; the business owes the employee.
    assert Decimal.eq?(balance(opts, :reimbursements), "65.50")

    paid =
      Expenses.reimburse_expense_claim!(
        approved,
        %{reimbursed_on: Date.utc_today(), reimbursed_from: :bank},
        opts
      )

    assert paid.status == :reimbursed
    assert Decimal.eq?(balance(opts, :reimbursements), 0)
  end

  test "a rejection sends the claim back for edits and resubmission",
       %{organization: organization, opts: opts, travel: travel, meals: meals, owner: owner} do
    staff = member_fixture(organization)
    staff_opts = [actor: staff, tenant: organization]

    # No workflow configured: any workspace admin approves.
    submitted =
      claim(staff_opts, items(travel, meals)) |> Expenses.submit_expense_claim!(staff_opts)

    request = Workflow.get_approval_request!(submitted.approval_request_id, opts)

    Workflow.decide_approval!(request, :reject, %{comment: "Receipt missing"},
      actor: owner,
      tenant: organization
    )

    rejected = Expenses.get_expense_claim!(submitted.id, opts)
    assert rejected.status == :rejected

    resubmitted =
      rejected
      |> Expenses.update_expense_claim!(%{notes: "Receipt attached"}, staff_opts)
      |> Expenses.submit_expense_claim!(staff_opts)

    assert resubmitted.status == :submitted
    assert resubmitted.approval_request_id != request.id

    cancelled = Expenses.cancel_expense_claim!(resubmitted, staff_opts)
    assert cancelled.status == :cancelled

    assert Workflow.get_approval_request!(resubmitted.approval_request_id, opts).status ==
             :cancelled
  end

  test "amount thresholds pick the workflow and steps with nobody to ask are skipped",
       %{organization: organization, opts: opts, owner: owner, travel: travel} do
    staff = member_fixture(organization)
    staff_opts = [actor: staff, tenant: organization]

    Workflow.create_approval_workflow!(
      %{name: "Small", steps: [%{approver_type: :user, user_id: owner.id}]},
      opts
    )

    Workflow.create_approval_workflow!(
      %{
        name: "Large",
        min_amount: "1000",
        steps: [
          # Staff has no employee record, so there's no manager to ask.
          %{approver_type: :manager},
          %{approver_type: :admins}
        ]
      },
      opts
    )

    big =
      claim(staff_opts, [%{description: "Flights", amount: "1500", category_id: travel.id}])
      |> Expenses.submit_expense_claim!(staff_opts)

    request =
      Workflow.get_approval_request!(big.approval_request_id, opts ++ [load: [:workflow, :steps]])

    assert request.workflow.name == "Large"
    assert Enum.map(request.steps, & &1.status) == [:skipped, :pending]

    # The owner alone submitting: their own approval step is skipped, so it's approved.
    own =
      claim(opts, [%{description: "Taxi", amount: "12", category_id: travel.id}])
      |> Expenses.submit_expense_claim!(opts)

    assert own.status == :approved
  end
end
