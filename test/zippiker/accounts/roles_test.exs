defmodule Zippiker.Accounts.RolesTest do
  use Zippiker.DataCase, async: true

  import Zippiker.Fixtures

  alias Zippiker.{Accounts, Catalog, HR, Parties, Purchasing, Sales}
  alias Zippiker.Accounts.Permissions

  @monday ~D[2030-01-07]

  setup do
    {owner, organization} = workspace_fixture()
    opts = [actor: owner, tenant: organization]
    customer = Parties.create_party!(%{kind: :organization, name: "Globex"}, opts)
    supplier = Parties.create_party!(%{kind: :organization, name: "Acme Supplies"}, opts)
    roles = Map.new(Accounts.list_roles!(opts), &{&1.key, &1})

    %{
      owner: owner,
      organization: organization,
      opts: opts,
      customer: customer,
      supplier: supplier,
      roles: roles
    }
  end

  # A member holding exactly the given built-in roles.
  defp member_with(%{organization: organization, roles: roles, opts: opts}, keys) do
    user = member_fixture(organization)
    [membership] = Ash.load!(user, :memberships, authorize?: false).memberships
    Accounts.set_member_roles!(membership, Enum.map(keys, &roles[&1].id), opts)
    [actor: Ash.load!(user, [memberships: :roles], authorize?: false), tenant: organization]
  end

  defp invoice_params(customer),
    do: %{
      customer_id: customer.id,
      lines: [%{description: "Work", quantity: "1", unit_price: "100"}]
    }

  test "every workspace starts with the built-in roles", %{roles: roles} do
    assert Map.keys(roles) |> Enum.sort() ==
             Permissions.default_roles() |> Enum.map(& &1.key) |> Enum.sort()

    assert roles["team_member"].default?
    assert "invoices.create" in roles["team_member"].permissions
    refute "invoices.void" in roles["team_member"].permissions
  end

  test "new members get the default role", %{organization: organization, roles: roles} do
    user = member_fixture(organization)
    [membership] = Ash.load!(user, [memberships: :roles], authorize?: false).memberships
    assert Enum.map(membership.roles, & &1.id) == [roles["team_member"].id]
  end

  test "an employee can't invoice but still serves themselves", context do
    %{opts: opts, customer: customer} = context
    employee_opts = member_with(context, ["employee"])

    assert {:error, %Ash.Error.Forbidden{}} =
             Sales.create_invoice(invoice_params(customer), employee_opts)

    # Leave for themselves stays open to everyone.
    annual = HR.create_leave_type!(%{name: "Annual", allowance_days: Decimal.new(20)}, opts)
    HR.hire_employee!(%{first_name: "Eve", user_id: employee_opts[:actor].id}, opts)

    assert %{status: :pending} =
             HR.request_leave!(
               %{leave_type_id: annual.id, start_date: @monday, end_date: @monday},
               employee_opts
             )
  end

  test "a sales rep invoices but can't void", context do
    %{customer: customer} = context
    rep_opts = member_with(context, ["sales_rep"])

    invoice =
      invoice_params(customer)
      |> Sales.create_invoice!(rep_opts)
      |> Sales.issue_invoice!(rep_opts)

    assert invoice.status == :issued
    assert {:error, %Ash.Error.Forbidden{}} = Sales.void_invoice(invoice, rep_opts)

    assert {:error, %Ash.Error.Forbidden{}} =
             Catalog.create_tax_rate(%{name: "VAT", rate: 16}, rep_opts)
  end

  test "a role can open up admin-only actions", context do
    %{opts: opts, supplier: supplier} = context

    bill =
      Purchasing.create_bill!(
        %{
          supplier_id: supplier.id,
          lines: [%{description: "Paper", quantity: "1", unit_price: "10"}]
        },
        opts
      )

    team_member = member_with(context, ["team_member"])
    assert {:error, %Ash.Error.Forbidden{}} = Purchasing.approve_bill(bill, team_member)

    accountant = member_with(context, ["accountant"])
    assert %{status: :open} = Purchasing.approve_bill!(bill, accountant)
  end

  test "roles add up", context do
    %{customer: customer} = context
    both = member_with(context, ["employee", "sales_rep"])
    assert %{} = Sales.create_invoice!(invoice_params(customer), both)
  end

  test "custom roles: known permissions only; built-in roles can't be deleted but reset",
       %{opts: opts, roles: roles} do
    assert {:error, _} = Accounts.create_role(%{name: "Odd", permissions: ["nope.nope"]}, opts)

    cashier =
      Accounts.create_role!(
        %{name: "Cashier", permissions: ["view.sales", "payments.record"]},
        opts
      )

    assert :ok = Accounts.delete_role(cashier, opts)

    assert {:error, _} = Accounts.delete_role(roles["sales_rep"], opts)

    changed = Accounts.update_role!(roles["sales_rep"], %{permissions: ["view.sales"]}, opts)
    assert changed.permissions == ["view.sales"]
    reset = Accounts.reset_role!(changed, opts)
    assert "invoices.create" in reset.permissions
  end

  test "only admins and role managers change roles", context do
    %{roles: roles} = context
    member = member_with(context, ["team_member"])

    assert {:error, %Ash.Error.Forbidden{}} =
             Accounts.update_role(roles["employee"], %{permissions: Permissions.keys()}, member)

    assert {:error, _} =
             Accounts.create_role(%{name: "Mine", permissions: Permissions.keys()}, member)
  end

  test "roles can't come from another workspace", context do
    %{opts: opts} = context
    {_other_owner, other} = workspace_fixture()
    [foreign | _] = Accounts.list_roles!(tenant: other, authorize?: false)
    user = member_fixture(context.organization)
    [membership] = Ash.load!(user, :memberships, authorize?: false).memberships
    assert {:error, _} = Accounts.set_member_roles(membership, [foreign.id], opts)
  end

  test "every catalogued action exists and the levels are consistent" do
    for %{actions: actions} <- Permissions.all(), {resource, names} <- actions, name <- names do
      assert Ash.Resource.Info.action(resource, name),
             "#{inspect(resource)}.#{name} doesn't exist"
    end

    for %{key: key, actions: [_ | _] = actions} <- Permissions.all() do
      levels =
        for {resource, names} <- actions,
            name <- names,
            uniq: true,
            do: Permissions.level(resource, name)

      assert length(levels) == 1, "#{key} mixes #{inspect(levels)}"
    end
  end
end
