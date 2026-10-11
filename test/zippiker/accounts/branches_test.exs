defmodule Zippiker.Accounts.BranchesTest do
  use Zippiker.DataCase, async: true

  import Zippiker.Fixtures

  alias Zippiker.{Accounting, Accounts, Expenses, HR, Inventory}

  setup do
    {owner, organization} = workspace_fixture()
    opts = [actor: owner, tenant: organization]
    %{opts: opts, owner: owner, organization: organization}
  end

  test "every team has a default branch; records get it unless one is chosen", %{opts: opts} do
    hq = Accounts.default_branch!(opts)
    assert hq.code == "HQ" and hq.default?

    nairobi = Accounts.create_branch!(%{name: "Nairobi", code: "nbo"}, opts)
    assert nairobi.code == "NBO"

    assert HR.hire_employee!(%{first_name: "Ada"}, opts).branch_id == hq.id

    assert HR.hire_employee!(%{first_name: "Bo", branch_id: nairobi.id}, opts).branch_id ==
             nairobi.id

    warehouse =
      Inventory.create_warehouse!(%{name: "Depot", code: "DEP", branch_id: nairobi.id}, opts)

    assert warehouse.branch_id == nairobi.id

    # Only one default.
    Accounts.update_branch!(nairobi, %{default?: true}, opts)
    refute Accounts.get_branch!(hq.id, opts).default?
  end

  test "journal entries follow their document's branch; reports filter by branch", %{opts: opts} do
    Accounting.setup_books!(opts)
    nairobi = Accounts.create_branch!(%{name: "Nairobi", code: "NBO"}, opts)
    travel = Expenses.create_expense_category!(%{name: "Travel"}, opts)

    claim =
      Expenses.create_expense_claim!(
        %{
          title: "Trip",
          branch_id: nairobi.id,
          items: [%{description: "Taxi", amount: "40", category_id: travel.id}]
        },
        opts
      )
      |> Expenses.submit_expense_claim!(opts)

    # The owner is the only admin, so it's approved straight away and posted.
    assert claim.status == :approved

    [entry] = Accounting.list_journal_entries!(%{}, opts ++ [page: [limit: 10]]).results
    assert entry.branch_id == nairobi.id

    hq = Accounts.default_branch!(opts)

    assert Decimal.eq?(
             Accounting.profit_and_loss!(nil, nil, %{branch_id: nairobi.id}, opts).expense_total,
             40
           )

    assert Decimal.eq?(
             Accounting.profit_and_loss!(nil, nil, %{branch_id: hq.id}, opts).expense_total,
             0
           )

    assert Accounting.balance_sheet!(nil, %{branch_id: nairobi.id}, opts).balanced?
  end

  test "turning on multiple branches is a team setting", %{
    owner: owner,
    organization: organization
  } do
    refute organization.multi_branch?

    assert Accounts.set_multi_branch!(organization, %{multi_branch?: true}, actor: owner).multi_branch?
  end
end
