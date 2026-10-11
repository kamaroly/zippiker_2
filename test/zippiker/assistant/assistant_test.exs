defmodule Zippiker.AssistantTest do
  use Zippiker.DataCase, async: true

  import Zippiker.Fixtures

  alias Zippiker.{Accounts, Assistant, Crm, Parties}
  alias Zippiker.FakeClaude

  setup do
    {owner, organization} = workspace_fixture()
    opts = [actor: owner, tenant: organization]

    globex =
      Parties.create_party!(%{kind: :organization, name: "Globex", roles: [:customer]}, opts)

    %{opts: opts, organization: organization, globex: globex}
  end

  test "read tools run straight away and their results go back to Claude", %{opts: opts} do
    FakeClaude.script([
      FakeClaude.tool("t1", "search_records", %{"type" => "customers", "query" => "glob"}),
      FakeClaude.text("Globex is your customer.")
    ])

    result = Assistant.assistant_reply!([], "Is Globex a customer?", opts)
    assert result.status == "done"
    assert %{"content" => [%{"text" => "Globex is your customer."}]} = List.last(result.history)

    [{headers, first}, {_headers, second}] = FakeClaude.requests()
    assert first["model"] == "claude-opus-5-5"
    assert first["fallbacks"] == "default"
    assert first["output_config"] == %{"effort" => "medium"}
    assert {"anthropic-beta", "server-side-fallback-2026-07-01"} in headers
    assert Enum.any?(first["tools"], &(&1["name"] == "run_report"))

    [_user, _assistant, %{"role" => "user", "content" => [tool_result]}] = second["messages"]
    assert tool_result["tool_use_id"] == "t1"
    assert tool_result["content"] =~ "Globex"
  end

  test "write tools wait for approval, then run as the user", %{opts: opts, globex: globex} do
    FakeClaude.script([
      FakeClaude.tool("t1", "create_task", %{"title" => "Call Globex", "party_id" => globex.id}),
      FakeClaude.text("Done, the task is on your list.")
    ])

    pending = Assistant.assistant_reply!([], "Remind me to call Globex", opts)
    assert pending.status == "confirm"
    assert [summary] = pending.pending["summaries"]
    assert summary =~ "Call Globex"
    assert Crm.list_tasks!(opts) == []

    done = Assistant.assistant_resolve!(pending.history, pending.pending, true, opts)
    assert done.status == "done"
    assert [%{title: "Call Globex"}] = Crm.list_tasks!(%{view: :all}, opts)
  end

  test "declined writes don't run", %{opts: opts} do
    FakeClaude.script([
      FakeClaude.tool("t1", "create_lead", %{"first_name" => "Ann"}),
      FakeClaude.text("Okay, I won't.")
    ])

    pending = Assistant.assistant_reply!([], "Add Ann as a lead", opts)
    done = Assistant.assistant_resolve!(pending.history, pending.pending, false, opts)

    assert done.status == "done"
    assert Crm.list_leads!(opts) == []
    [_first, {_h, second}] = FakeClaude.requests()
    assert List.last(second["messages"])["content"] |> hd() |> Map.get("content") =~ "declined"
  end

  test "drafts a quote with lines", %{opts: opts, globex: globex} do
    FakeClaude.script([
      FakeClaude.tool("t1", "create_draft_quote", %{
        "customer_id" => globex.id,
        "lines" => [%{"description" => "Consulting", "quantity" => 10, "unit_price" => 50}]
      }),
      FakeClaude.text("Here's the draft.")
    ])

    pending = Assistant.assistant_reply!([], "Quote Globex 10h consulting at 50", opts)
    assert hd(pending.pending["summaries"]) =~ "500"
    Assistant.assistant_resolve!(pending.history, pending.pending, true, opts)

    assert [%{status: :draft} = quote] = Zippiker.Sales.list_quotes!(opts)
    assert Decimal.eq?(quote.subtotal.amount, 500)
  end

  test "reports are limited to what the user's role can see",
       %{organization: organization, opts: owner_opts} do
    roles = Map.new(Accounts.list_roles!(owner_opts), &{&1.key, &1})
    user = member_fixture(organization)
    [membership] = Ash.load!(user, :memberships, authorize?: false).memberships

    Accounts.set_member_roles!(
      membership,
      [roles["employee"].id],
      owner_opts
    )

    user = Ash.load!(user, [memberships: :roles], authorize?: false)
    opts = [actor: user, tenant: organization]

    FakeClaude.script([
      FakeClaude.tool("t1", "run_report", %{"key" => "profit-and-loss"}),
      FakeClaude.text("I can't see that.")
    ])

    Assistant.assistant_reply!([], "What's our profit?", opts)
    [_first, {_h, second}] = FakeClaude.requests()
    result = second["messages"] |> List.last() |> Map.get("content") |> hd()
    assert result["is_error"]
  end

  test "people without the permission can't use it", %{
    organization: organization,
    opts: owner_opts
  } do
    roles = Map.new(Accounts.list_roles!(owner_opts), &{&1.key, &1})
    user = member_fixture(organization)
    [membership] = Ash.load!(user, :memberships, authorize?: false).memberships
    Accounts.set_member_roles!(membership, [roles["viewer"].id], owner_opts)
    user = Ash.load!(user, [memberships: :roles], authorize?: false)

    assert {:error, %Ash.Error.Forbidden{}} =
             Assistant.assistant_reply([], "hi", actor: user, tenant: organization)
  end

  test "API errors come back as a message", %{opts: opts} do
    Req.Test.stub(Zippiker.Assistant.Claude, fn conn ->
      conn
      |> Plug.Conn.put_status(401)
      |> Req.Test.json(%{"error" => %{"message" => "invalid x-api-key"}})
    end)

    result = Assistant.assistant_reply!([], "hi", opts)
    assert result.status == "error"
    assert result.error =~ "API key was rejected"
  end
end
