defmodule ZippikerWeb.ManufacturingLiveTest do
  use ZippikerWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Zippiker.{Catalog, Inventory, Manufacturing}

  setup :register_and_log_in_user

  setup %{opts: opts} do
    product = fn name, cost ->
      Catalog.create_product!(
        %{name: name, kind: :goods, unit: "pcs", track_inventory?: true, cost_price: cost},
        opts
      )
    end

    chair = product.("Chair", 0)
    seat = product.("Seat", 10)
    leg = product.("Chair leg", 2)

    Inventory.record_stock_operation!(
      %{
        kind: :receipt,
        lines: [
          %{product_id: seat.id, quantity: "5", unit_cost: "10"},
          %{product_id: leg.id, quantity: "20", unit_cost: "2"}
        ]
      },
      opts
    )

    work_center = Manufacturing.create_work_center!(%{name: "Workshop", hourly_rate: "6"}, opts)
    %{chair: chair, seat: seat, leg: leg, work_center: work_center}
  end

  defp row_keys(view, selector, prefix) do
    view
    |> render()
    |> LazyHTML.from_fragment()
    |> LazyHTML.query(selector)
    |> Enum.map(&(LazyHTML.attribute(&1, "id") |> hd() |> String.replace_prefix(prefix, "")))
  end

  test "every manufacturing page renders", %{conn: conn} do
    for path <-
          ~w(/manufacturing/orders /manufacturing/orders/new /manufacturing/boms /manufacturing/boms/new /manufacturing/work-centers /manufacturing/work-centers/new) do
      assert {:ok, _view, _html} = live(conn, path)
    end
  end

  test "builds a bill of materials, plans, produces and prints a job card", %{
    conn: conn,
    opts: opts,
    chair: chair,
    seat: seat,
    leg: leg,
    work_center: work_center
  } do
    {:ok, view, _html} = live(conn, ~p"/manufacturing/boms/new")
    view |> element("#add-component") |> render_click()
    view |> element("#add-operation") |> render_click()

    [first, second] = row_keys(view, "#bom-components > div", "component-")
    [operation] = row_keys(view, "#bom-operations > div", "operation-")

    params = %{
      "bom" => %{"product_id" => chair.id, "reference" => "Standard", "quantity" => "1"},
      "components" => %{
        first => %{"product_id" => seat.id, "quantity" => "1"},
        second => %{"product_id" => leg.id, "quantity" => "4"}
      },
      "operations" => %{
        operation => %{
          "name" => "Assemble",
          "work_center_id" => work_center.id,
          "minutes" => "20"
        }
      }
    }

    render_change(view, "change", params)

    assert {:error, {:live_redirect, %{to: "/manufacturing/boms"}}} =
             render_submit(view, "save", params)

    [bom] = Manufacturing.list_boms!(opts)
    assert length(bom.components) == 2

    {:ok, view, _html} = live(conn, ~p"/manufacturing/orders/new?product_id=#{chair.id}")

    {:error, {:live_redirect, %{to: "/manufacturing/orders/" <> id}}} =
      view
      |> form("#production-order-form", order: %{product_id: chair.id, quantity: "3"})
      |> render_submit()

    {:ok, view, _html} = live(conn, ~p"/manufacturing/orders/#{id}")
    assert has_element?(view, "#requirement-#{leg.id}")
    view |> element("#confirm-production-order") |> render_click()

    {:ok, view, _html} = live(conn, ~p"/manufacturing/orders/#{id}/produce")

    view
    |> form("#produce-form", produce: %{quantity: "2", date: Date.utc_today()})
    |> render_submit()

    order = Manufacturing.get_production_order!(id, opts)
    assert order.status == :in_progress
    assert Decimal.eq?(order.produced_quantity, 2)
    assert has_element?(view, "#production-runs li[id^='run-']")

    # Only 3 seats left: asking for 4 more fails with a shortage message.
    {:ok, view, _html} = live(conn, ~p"/manufacturing/orders/#{id}/produce")

    view
    |> form("#produce-form", produce: %{quantity: "4", date: Date.utc_today()})
    |> render_submit()

    assert Decimal.eq?(Manufacturing.get_production_order!(id, opts).produced_quantity, 2)

    {:ok, card, _html} = live(conn, ~p"/manufacturing/orders/#{id}/print")
    assert has_element?(card, "#job-card")
  end

  test "manages work centers", %{conn: conn, opts: opts} do
    {:ok, view, _html} = live(conn, ~p"/manufacturing/work-centers/new")

    view
    |> form("#work-center-form", work_center: %{name: "Paint shop", hourly_rate: "15"})
    |> render_submit()

    assert Enum.any?(Manufacturing.list_work_centers!(opts), &(&1.name == "Paint shop"))
  end
end
