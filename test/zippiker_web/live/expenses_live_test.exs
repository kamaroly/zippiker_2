defmodule ZippikerWeb.ExpensesLiveTest do
  use ZippikerWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Zippiker.Fixtures

  alias Zippiker.{Expenses, Workflow}

  setup :register_and_log_in_user

  setup %{opts: opts} do
    %{travel: Expenses.create_expense_category!(%{name: "Travel"}, opts)}
  end

  test "every expenses page renders", %{conn: conn} do
    for path <-
          ~w(/expenses /expenses/all /expenses/new /expenses/approvals /expenses/categories /expenses/categories/new /expenses/workflows /expenses/workflows/new /expenses/groups /expenses/groups/new) do
      assert {:ok, _view, _html} = live(conn, path)
    end
  end

  test "files a claim with several receipts and submits it", %{
    organization: organization,
    travel: travel
  } do
    staff = member_fixture(organization)
    conn = log_in_user(build_conn(), staff)

    {:ok, view, _html} = live(conn, ~p"/expenses/new")
    view |> element("#add-item") |> render_click()

    keys =
      view
      |> render()
      |> LazyHTML.from_fragment()
      |> LazyHTML.query("#claim-items > div")
      |> Enum.map(&(LazyHTML.attribute(&1, "id") |> hd() |> String.replace_prefix("item-", "")))

    assert length(keys) == 2
    [first, second] = keys

    items = %{
      first => %{description: "Taxi", amount: "30", category_id: travel.id},
      second => %{description: "Hotel", amount: "120", category_id: travel.id}
    }

    render_change(view, "change", %{"claim" => %{"title" => "Kigali trip"}, "items" => items})
    assert view |> element("#claim-total") |> render() =~ "150"

    {:error, {:live_redirect, %{to: "/expenses/" <> id}}} =
      render_submit(view, "save", %{
        "intent" => "submit",
        "claim" => %{"title" => "Kigali trip"},
        "items" => items
      })

    claim = Expenses.get_expense_claim!(id, actor: staff, tenant: organization)
    assert claim.status == :submitted
    assert claim.title == "Kigali trip"
  end

  test "the approver approves from their inbox and the admin pays back", %{
    conn: conn,
    organization: organization,
    travel: travel,
    user: owner
  } do
    staff = member_fixture(organization)
    staff_opts = [actor: staff, tenant: organization]

    claim =
      Expenses.create_expense_claim!(
        %{
          title: "Conference",
          items: [%{description: "Ticket", amount: "200", category_id: travel.id}]
        },
        staff_opts
      )
      |> Expenses.submit_expense_claim!(staff_opts)

    {:ok, inbox, _html} = live(conn, ~p"/expenses/approvals")
    assert has_element?(inbox, "#approval-inbox a[href='/expenses/#{claim.id}']")

    {:ok, view, _html} = live(conn, ~p"/expenses/#{claim}")
    assert has_element?(view, "#decision-card")

    # Rejecting needs a reason.
    render_submit(view, "decide", %{"decision" => "reject", "comment" => ""})
    assert Expenses.get_expense_claim!(claim.id, staff_opts).status == :submitted

    render_submit(view, "decide", %{"decision" => "approve", "comment" => "Fine"})
    assert Expenses.get_expense_claim!(claim.id, staff_opts).status == :approved
    assert has_element?(view, "#approval-timeline-step-1")
    refute has_element?(view, "#decision-card")

    {:ok, view, _html} = live(conn, ~p"/expenses/#{claim}/reimburse")

    view
    |> form("#reimburse-form",
      reimburse: %{reimbursed_on: Date.utc_today(), reimbursed_from: "cash"}
    )
    |> render_submit()

    assert Expenses.get_expense_claim!(claim.id, actor: owner, tenant: organization).status ==
             :reimbursed
  end

  test "admins build a multi-step workflow with a group as final approver", %{
    conn: conn,
    organization: organization,
    opts: opts
  } do
    finance_user = member_fixture(organization)

    {:ok, view, _html} = live(conn, ~p"/expenses/groups/new")

    view
    |> form("#group-form", group: %{name: "Finance", member_ids: ["", finance_user.id]})
    |> render_submit()

    [group] = Workflow.list_approval_groups!(opts)
    assert Enum.map(group.members, & &1.id) == [finance_user.id]

    {:ok, view, _html} = live(conn, ~p"/expenses/workflows/new")
    view |> element("#add-step") |> render_click()

    keys =
      view
      |> render()
      |> LazyHTML.from_fragment()
      |> LazyHTML.query("#workflow-steps > li")
      |> Enum.map(&(LazyHTML.attribute(&1, "id") |> hd() |> String.replace_prefix("step-", "")))

    [manager, admins, last] = keys

    steps = %{
      manager => %{"approver_type" => "manager"},
      admins => %{"approver_type" => "admins"},
      last => %{"approver_type" => "group", "group_id" => group.id, "label" => "Finance"}
    }

    # Picking "group" reveals the group select.
    render_change(view, "change", %{"steps" => steps})
    assert has_element?(view, "#step-group-#{last}")

    render_submit(view, "save", %{
      "workflow" => %{"name" => "Big spend", "min_amount" => "500", "active?" => "true"},
      "steps" => steps
    })

    [workflow] = Workflow.list_approval_workflows!(opts)
    assert workflow.name == "Big spend"
    assert Decimal.eq?(workflow.min_amount, 500)
    assert Enum.map(workflow.steps, & &1.approver_type) == [:manager, :admins, :group]
    assert has_element?(view, "#workflow-#{workflow.id}")
  end
end
