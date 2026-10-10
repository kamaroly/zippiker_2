defmodule Zippiker.ManufacturingTest do
  use Zippiker.DataCase, async: true

  import Zippiker.Fixtures

  alias Zippiker.{Accounting, Catalog, Inventory, Manufacturing}

  setup do
    {owner, organization} = workspace_fixture()
    opts = [actor: owner, tenant: organization]

    product = fn name, cost ->
      Catalog.create_product!(
        %{name: name, kind: :goods, unit: "pcs", track_inventory?: true, cost_price: cost},
        opts
      )
    end

    table = product.("Table", 0)
    top = product.("Table top", 30)
    leg = product.("Leg", 5)

    Inventory.record_stock_operation!(
      %{
        kind: :receipt,
        lines: [
          %{product_id: top.id, quantity: "10", unit_cost: "30"},
          %{product_id: leg.id, quantity: "30", unit_cost: "5"}
        ]
      },
      opts
    )

    assembly = Manufacturing.create_work_center!(%{name: "Assembly", hourly_rate: "12"}, opts)

    bom =
      Manufacturing.create_bom!(
        %{
          product_id: table.id,
          quantity: "1",
          components: [
            %{product_id: top.id, quantity: "1"},
            %{product_id: leg.id, quantity: "4"}
          ],
          operations: [%{name: "Assemble", work_center_id: assembly.id, minutes: "30"}]
        },
        opts
      )

    %{opts: opts, table: table, top: top, leg: leg, bom: bom, organization: organization}
  end

  defp on_hand(product, opts),
    do: Catalog.get_product!(product.id, opts ++ [load: [:on_hand]]).on_hand

  test "bills of materials need stock-tracked components other than the product",
       %{opts: opts, table: table, top: top} do
    service = Catalog.create_product!(%{name: "Design", kind: :service, unit: "h"}, opts)

    assert {:error, %Ash.Error.Invalid{}} =
             Manufacturing.create_bom(
               %{product_id: table.id, components: [%{product_id: service.id, quantity: 1}]},
               opts
             )

    assert {:error, %Ash.Error.Invalid{}} =
             Manufacturing.create_bom(
               %{product_id: table.id, components: [%{product_id: table.id, quantity: 1}]},
               opts
             )

    assert {:error, %Ash.Error.Invalid{}} =
             Manufacturing.create_bom(%{product_id: top.id, components: []}, opts)
  end

  test "produces in runs: consumes components, receives goods at cost, posts overhead",
       %{opts: opts, table: table, top: top, leg: leg, bom: bom} do
    order = Manufacturing.create_production_order!(%{product_id: table.id, quantity: "5"}, opts)
    assert order.number =~ ~r/^MO-\d{4}-\d{4}$/
    assert order.bom_id == bom.id

    # Draft orders can't produce yet.
    assert {:error, %Ash.Error.Invalid{}} = Manufacturing.record_production(order, "1", opts)

    order = Manufacturing.confirm_production_order!(order, opts)
    order = Manufacturing.record_production!(order, "2", opts)

    assert order.status == :in_progress
    assert Decimal.eq?(order.produced_quantity, 2)
    # Per table: top 30 + 4 legs × 5 + 30 min at 12/h = 56.
    assert Decimal.eq?(order.actual_cost, 112)

    assert Decimal.eq?(on_hand(table, opts), 2)
    assert Decimal.eq?(on_hand(top, opts), 8)
    assert Decimal.eq?(on_hand(leg, opts), 22)
    assert Decimal.eq?(Catalog.get_product!(table.id, opts).average_cost, 56)

    [operation] =
      Inventory.list_stock_operations!(%{source: :production_order, source_id: order.id}, opts)

    assert operation.kind == :production
    assert operation.number =~ ~r/^PRD-/

    overhead =
      Accounting.list_accounts!(opts) |> Enum.find(&(&1.system_key == :production_overhead))

    assert Decimal.eq?(
             Accounting.get_account!(overhead.id, opts ++ [load: [:balance]]).balance,
             -12
           )

    # Not enough legs for 6 more tables.
    assert {:error, %Ash.Error.Invalid{}} = Manufacturing.record_production(order, "6", opts)

    order = Manufacturing.record_production!(order, "3", opts)
    assert order.status == :done
    assert order.finished_at
    assert {:error, %Ash.Error.Invalid{}} = Manufacturing.cancel_production_order(order, opts)
  end

  test "partly produced orders can be finished early; untouched ones cancelled",
       %{opts: opts, table: table} do
    order =
      Manufacturing.create_production_order!(%{product_id: table.id, quantity: "4"}, opts)
      |> Manufacturing.confirm_production_order!(opts)
      |> Manufacturing.record_production!("1", opts)

    assert Manufacturing.finish_production_order!(order, opts).status == :done

    other = Manufacturing.create_production_order!(%{product_id: table.id, quantity: "1"}, opts)
    assert Manufacturing.cancel_production_order!(other, opts).status == :cancelled
  end

  test "an order needs a bill of materials for its product", %{opts: opts, top: top} do
    assert {:error, %Ash.Error.Invalid{}} =
             Manufacturing.create_production_order(%{product_id: top.id, quantity: "1"}, opts)
  end
end
