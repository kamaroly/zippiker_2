defmodule ZippikerWeb.DocumentsBrandingLiveTest do
  use ZippikerWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Zippiker.Fixtures

  alias Zippiker.{Accounts, Parties, Sales}

  setup :register_and_log_in_user

  # 1×1 transparent PNG
  @png Base.decode64!(
         "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg=="
       )

  test "designs documents with a live preview and saves", %{conn: conn, opts: opts} do
    {:ok, view, _html} = live(conn, ~p"/settings/documents")
    assert has_element?(view, "#document-preview #document-paper")

    view
    |> form("#style-form",
      style: %{layout: "modern", accent_color: "#2563eb", font: "serif", logo_size: "large"},
      template: %{title: "Tax invoice", terms: "Pay within 14 days", footer: "Bank: KCB 123"}
    )
    |> render_change()

    assert has_element?(view, "#document-preview", "Tax invoice")
    assert has_element?(view, "#document-preview", "Pay within 14 days")

    view |> element("#style-form") |> render_submit()

    {:ok, entity} = Accounts.default_legal_entity(opts)
    assert entity.document_style.layout == :modern
    assert entity.document_style.accent_color == "#2563eb"
    assert [%{kind: :invoice, title: "Tax invoice"}] = entity.document_style.templates
  end

  test "printed documents use the design", %{conn: conn, opts: opts} do
    {:ok, entity} = Accounts.default_legal_entity(opts)

    Accounts.update_document_style!(
      entity,
      %{
        document_style: %{
          templates: [%{kind: :invoice, title: "Tax invoice", terms: "No refunds"}]
        }
      },
      opts
    )

    customer = Parties.create_party!(%{kind: :organization, name: "Globex"}, opts)

    invoice =
      Sales.create_invoice!(
        %{
          customer_id: customer.id,
          lines: [%{description: "Work", quantity: "1", unit_price: "5"}]
        },
        opts
      )

    {:ok, view, _html} = live(conn, ~p"/invoices/#{invoice}/print")
    assert has_element?(view, "#document-paper", "Tax invoice")
    assert has_element?(view, "#document-paper", "No refunds")
  end

  test "uploads a logo that only workspace people can fetch",
       %{conn: conn, opts: opts, organization: organization} do
    {:ok, view, _html} = live(conn, ~p"/settings/documents")

    logo =
      file_input(view, "#logo-form", :logo, [
        %{name: "logo.png", content: @png, type: "image/png"}
      ])

    render_upload(logo, "logo.png")
    view |> form("#logo-form") |> render_submit()
    assert has_element?(view, "#current-logo")

    {:ok, entity} = Accounts.default_legal_entity(opts)
    assert entity.logo_path =~ "#{organization.id}/logos/"

    path = "/logos/#{organization.id}/#{entity.id}"
    assert response(get(conn, path), 200) == @png

    {stranger, _other} = workspace_fixture()
    assert response(get(log_in_user(build_conn(), stranger), path), 404)
  end

  test "a logo path from another workspace is refused", %{opts: opts} do
    {:ok, entity} = Accounts.default_legal_entity(opts)
    assert {:error, _} = Accounts.set_logo(entity, "someone-else/logos/x.png", opts)
    assert {:error, _} = Accounts.set_logo(entity, "../../etc/passwd", opts)
  end

  test "members need the design permission", %{organization: organization} do
    member = member_fixture(organization)
    conn = log_in_user(build_conn(), member)
    {:ok, view, _html} = live(conn, ~p"/settings/documents")
    refute has_element?(view, "#save-style")
    refute has_element?(view, "#logo-form")
  end
end
