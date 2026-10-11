defmodule Zippiker.Workflow.MakerCheckerTest do
  use Zippiker.DataCase, async: true

  import Zippiker.Fixtures

  alias Zippiker.{Accounts, Catalog, HR, Workflow}
  alias Zippiker.Workflow.Errors.ChangeRequested

  setup do
    {owner, organization} = workspace_fixture()
    checker = member_fixture(organization, :admin)
    maker = member_fixture(organization, :admin)
    opts = [actor: owner, tenant: organization]
    product = Catalog.create_product!(%{name: "Widget", unit_price: "10"}, opts)

    organization =
      Accounts.set_maker_checker!(
        organization,
        %{maker_checker?: true, maker_checker_scopes: [:products, :employees]},
        actor: owner
      )

    as = &[actor: &1, tenant: organization]
    %{owner: owner, checker: checker, maker: maker, product: product, as: as}
  end

  defp requested(%{errors: errors}), do: Enum.find(errors, &match?(%ChangeRequested{}, &1))

  test "a change is held until a checker approves it, then applied as the maker",
       %{maker: maker, checker: checker, product: product, as: as} do
    assert {:error, error} = Catalog.update_product(product, %{unit_price: "12"}, as.(maker))
    assert %ChangeRequested{change_request_id: id, number: "CR-" <> _} = requested(error)

    # Nothing changed yet.
    assert Decimal.eq?(Catalog.get_product!(product.id, as.(maker)).unit_price, 10)

    request = Workflow.get_change_request!(id, as.(checker))
    assert request.status == :pending
    assert [%{"field" => "unit_price", "from" => "10", "to" => "12"}] = request.changes

    # The maker can't approve their own change; the checker can.
    approval = Workflow.get_approval_request!(request.approval_request_id, as.(checker))
    assert {:error, _} = Workflow.decide_approval(approval, :approve, as.(maker))
    Workflow.decide_approval!(approval, :approve, as.(checker))

    assert Workflow.get_change_request!(id, as.(checker)).status == :applied
    assert Decimal.eq?(Catalog.get_product!(product.id, as.(maker)).unit_price, 12)
  end

  test "new records and rejections", %{maker: maker, checker: checker, as: as} do
    assert {:error, error} =
             HR.hire_employee(
               %{first_name: "Grace", last_name: "Hopper", salary: "9000"},
               as.(maker)
             )

    %ChangeRequested{change_request_id: id} = requested(error)
    assert HR.list_employees!(%{}, as.(maker)) == []

    request = Workflow.get_change_request!(id, as.(checker))
    approval = Workflow.get_approval_request!(request.approval_request_id, as.(checker))
    Workflow.decide_approval!(approval, :approve, as.(checker))
    assert [%{name: "Grace Hopper"}] = HR.list_employees!(%{}, as.(maker))

    {:error, error} = Catalog.create_product(%{name: "Gadget"}, as.(maker))
    %ChangeRequested{change_request_id: rejected_id} = requested(error)
    rejected = Workflow.get_change_request!(rejected_id, as.(checker))

    rejected.approval_request_id
    |> Workflow.get_approval_request!(as.(checker))
    |> Workflow.decide_approval!(:reject, %{comment: "Duplicate"}, as.(checker))

    assert Workflow.get_change_request!(rejected_id, as.(checker)).status == :rejected
    refute Enum.any?(Catalog.list_products!(as.(maker)), &(&1.name == "Gadget"))
  end

  test "areas not covered, and the maker withdrawing", %{maker: maker, as: as, product: product} do
    # Tax rates aren't covered: applied straight away.
    assert {:ok, _} = Catalog.create_tax_rate(%{name: "VAT", rate: "18"}, as.(maker))

    {:error, error} = Catalog.archive_product(product, as.(maker))
    %ChangeRequested{change_request_id: id} = requested(error)
    request = Workflow.get_change_request!(id, as.(maker))
    assert Workflow.cancel_change_request!(request, as.(maker)).status == :cancelled
    assert Catalog.get_product!(product.id, as.(maker))
  end
end
