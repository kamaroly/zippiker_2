defmodule ZippikerWeb.ComplianceLiveTest do
  use ZippikerWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Zippiker.Compliance

  setup :register_and_log_in_user

  test "set up the company, keep its registers and file on time", %{conn: conn, opts: opts} do
    # Before setup every register points to company details.
    {:ok, view, _html} = live(conn, ~p"/compliance/officers")
    assert has_element?(view, "#setup-company")

    {:ok, view, _html} = live(conn, ~p"/compliance")

    view
    |> form("#company-form",
      company: %{
        registration_number: "PVT-XY12345",
        incorporation_date: "2020-05-20",
        kra_pin: "P051111111A",
        registered_office: "Kilimani, Nairobi"
      }
    )
    |> render_submit()

    [profile] = Compliance.list_company_profiles!(opts)
    assert profile.registration_number == "PVT-XY12345"

    for path <-
          ~w(/compliance /compliance/filings /compliance/officers /compliance/members /compliance/beneficial-owners /compliance/charges /compliance/meetings /compliance/documents) do
      assert {:ok, _view, _html} = live(conn, path)
    end

    # Appoint a director.
    {:ok, view, _html} = live(conn, ~p"/compliance/officers?modal=appoint")

    view
    |> form("#officer-form",
      officer: %{name: "Achieng Otieno", role: "director", nationality: "Kenyan"}
    )
    |> render_submit()

    assert has_element?(view, "#officers", "Achieng Otieno")

    # A share class, a member, an allotment.
    {:ok, view, _html} = live(conn, ~p"/compliance/members?modal=class")

    view
    |> form("#class-form", class: %{name: "Ordinary", nominal_value: "100"})
    |> render_submit()

    {:ok, view, _html} = live(conn, ~p"/compliance/members?modal=member")
    view |> form("#member-form", member: %{name: "Achieng Otieno"}) |> render_submit()

    [class] = Compliance.share_classes!(profile.id, opts)
    [member] = Compliance.member_register!(profile.id, opts)
    {:ok, view, _html} = live(conn, ~p"/compliance/members?modal=allot")

    view
    |> form("#allot-form",
      allot: %{shareholder_id: member.id, share_class_id: class.id, quantity: "1000"}
    )
    |> render_submit()

    assert has_element?(view, "#members", "1000 Ordinary")

    # The filing calendar has the annual return, the director notice and the allotment return.
    {:ok, view, _html} = live(conn, ~p"/compliance/filings")
    assert has_element?(view, "#filings", "Annual return")
    assert has_element?(view, "#filings", "Return of allotment")

    notice = Enum.find(Compliance.filing_calendar!(profile.id, opts), &(&1.title =~ "appointed"))
    {:ok, view, _html} = live(conn, ~p"/compliance/filings?modal=complete&task=#{notice.id}")
    view |> form("#complete-filing-form", filing: %{reference: "BRS-2026-001"}) |> render_submit()
    assert Compliance.get_compliance_task!(notice.id, opts).reference == "BRS-2026-001"

    {:ok, print, _html} = live(conn, ~p"/compliance/print/officers")
    assert has_element?(print, "#register-print", "Achieng Otieno")
  end

  test "meetings with a special resolution and a statutory document", %{conn: conn, opts: opts} do
    entity = Zippiker.Accounts.default_legal_entity!(opts)
    profile = Compliance.create_company_profile!(%{legal_entity_id: entity.id}, opts)

    {:ok, view, _html} = live(conn, ~p"/compliance/meetings?modal=new")
    view |> element("#add-resolution") |> render_click()

    [key] =
      view
      |> render()
      |> LazyHTML.from_fragment()
      |> LazyHTML.query("[id^='resolution-']")
      |> Enum.map(&(LazyHTML.attribute(&1, "id") |> hd()))
      |> Enum.filter(&String.match?(&1, ~r/^resolution-[0-9a-f-]{36}$/))
      |> Enum.map(&String.replace_prefix(&1, "resolution-", ""))

    render_submit(view, "save", %{
      "meeting" => %{
        "kind" => "egm",
        "title" => "Adopt new articles",
        "held_on" => "2026-10-01",
        "status" => "held"
      },
      "resolutions" => %{
        key => %{
          "text" => "That the new articles be adopted",
          "kind" => "special",
          "passed?" => "true"
        }
      }
    })

    assert [%{resolutions: [%{kind: :special}]}] = Compliance.list_meetings!(profile.id, opts)

    assert Enum.any?(
             Compliance.filing_calendar!(profile.id, opts),
             &(&1.kind == :resolution_filing)
           )

    {:ok, view, _html} = live(conn, ~p"/compliance/documents?modal=upload")

    file =
      file_input(view, "#document-upload-form", :file, [
        %{name: "certificate.pdf", content: "%PDF cert", type: "application/pdf"}
      ])

    render_upload(file, "certificate.pdf")

    view
    |> form("#document-upload-form", document: %{kind: "incorporation_certificate"})
    |> render_submit()

    [document] = Compliance.statutory_documents!(profile.id, opts)
    assert response(get(conn, ~p"/compliance/documents/#{document.id}/file"), 200) == "%PDF cert"
  end
end
