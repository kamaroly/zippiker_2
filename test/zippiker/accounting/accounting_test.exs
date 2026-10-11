defmodule Zippiker.AccountingTest do
  use Zippiker.DataCase, async: true

  import Zippiker.Fixtures

  alias Zippiker.{Accounting, Catalog, Parties, Sales}

  setup do
    {user, organization} = workspace_fixture()
    opts = [actor: user, tenant: organization]
    customer = Parties.create_party!(%{kind: :organization, name: "Globex"}, opts)
    vat = Catalog.create_tax_rate!(%{name: "VAT", rate: Decimal.new(18)}, opts)
    %{opts: opts, customer: customer, vat: vat, user: user, organization: organization}
  end

  # 1000 net + 180 VAT = 1180
  defp issued_invoice(%{opts: opts, customer: customer, vat: vat}) do
    %{
      customer_id: customer.id,
      lines: [
        %{description: "Consulting", quantity: "10", unit_price: "100", tax_rate_id: vat.id}
      ]
    }
    |> Sales.create_invoice!(opts)
    |> Sales.issue_invoice!(opts)
  end

  defp account(opts, key) do
    Enum.find(Accounting.list_accounts!(opts), &(&1.system_key == key))
  end

  defp d(value), do: Decimal.new(value)

  test "setting up the books creates the default chart once", %{opts: opts} do
    assert %{created: created} = Accounting.setup_books!(opts)
    assert created == length(Accounting.Ledger.Actions.Setup.chart())
    assert %{created: 0} = Accounting.setup_books!(opts)
  end

  test "issuing an invoice posts receivable, revenue and tax", %{opts: opts} = context do
    invoice = issued_invoice(context)

    [entry] = Accounting.list_journal_entries!(%{source: :invoice}, opts)
    entry = Ash.load!(entry, :lines, opts)

    assert entry.source_id == invoice.id
    assert entry.source_label == invoice.number
    assert entry.number =~ ~r/^JE-\d{4}-0001$/
    assert Decimal.eq?(entry.total, d(1180))

    assert Decimal.eq?(account(opts, :receivable).balance, d(1180))
    assert Decimal.eq?(account(opts, :revenue).balance, d(1000))
    assert Decimal.eq?(account(opts, :tax_payable).balance, d(180))
  end

  test "payments move money from receivable to the right account", %{opts: opts} = context do
    invoice = issued_invoice(context)

    payment =
      Sales.record_payment!(
        %{invoice_id: invoice.id, amount: Money.new!(:USD, 500), method: :mobile_money},
        opts
      )

    assert Decimal.eq?(account(opts, :mobile_money).balance, d(500))
    assert Decimal.eq?(account(opts, :receivable).balance, d(680))

    Sales.delete_payment!(payment, opts)

    assert Decimal.eq?(account(opts, :mobile_money).balance, d(0))
    assert Decimal.eq?(account(opts, :receivable).balance, d(1180))
    assert [%{reversal_of_id: id}] = Accounting.list_journal_entries!(%{query: "Reversal"}, opts)
    assert id
  end

  test "voiding an invoice reverses its entry", %{opts: opts} = context do
    invoice = issued_invoice(context)
    Sales.void_invoice!(invoice, opts)

    for key <- [:receivable, :revenue, :tax_payable] do
      assert Decimal.eq?(account(opts, key).balance, d(0))
    end
  end

  test "manual entries must balance", %{opts: opts} do
    Accounting.setup_books!(opts)
    cash = account(opts, :cash)
    equity = account(opts, :equity)

    assert {:error, %Ash.Error.Invalid{}} =
             Accounting.create_journal_entry(
               %{
                 memo: "Owner investment",
                 lines: [
                   %{account_id: cash.id, debit: "100"},
                   %{account_id: equity.id, credit: "90"}
                 ]
               },
               opts
             )

    entry =
      Accounting.create_journal_entry!(
        %{
          memo: "Owner investment",
          lines: [
            %{"account_id" => cash.id, "debit" => "5000", "credit" => ""},
            %{"account_id" => equity.id, "debit" => "", "credit" => "5000"},
            %{"account_id" => "", "debit" => "", "credit" => ""}
          ]
        },
        opts
      )

    assert Decimal.eq?(entry.total, d(5000))
    assert Decimal.eq?(account(opts, :cash).balance, d(5000))

    reversal = Accounting.reverse_journal_entry!(entry.id, opts)
    assert reversal.reversal_of_id == entry.id
    assert Decimal.eq?(account(opts, :cash).balance, d(0))
    assert {:error, _} = Accounting.reverse_journal_entry(entry.id, opts)
  end

  test "members can't post manual entries", %{organization: organization} do
    member = member_fixture(organization)
    member_opts = [actor: member, tenant: organization]
    Accounting.setup_books!(tenant: organization, authorize?: false)
    [cash, bank | _] = Accounting.list_accounts!(member_opts)

    assert {:error, %Ash.Error.Forbidden{}} =
             Accounting.create_journal_entry(
               %{
                 memo: "Transfer",
                 lines: [
                   %{account_id: bank.id, debit: "10"},
                   %{account_id: cash.id, credit: "10"}
                 ]
               },
               member_opts
             )
  end

  test "recording an expense and the financial statements", %{opts: opts} = context do
    invoice = issued_invoice(context)

    Sales.record_payment!(
      %{invoice_id: invoice.id, amount: Money.new!(:USD, 1180), method: :bank_transfer},
      opts
    )

    rent = Enum.find(Accounting.list_accounts!(opts), &(&1.code == "6100"))

    Accounting.record_expense!(
      %{
        memo: "October rent",
        expense_account_id: rent.id,
        paid_from_account_id: account(opts, :bank).id,
        amount: "300"
      },
      opts
    )

    pl = Accounting.profit_and_loss!(nil, nil, opts)
    assert Decimal.eq?(pl.income_total, d(1000))
    assert Decimal.eq?(pl.expense_total, d(300))
    assert Decimal.eq?(pl.net, d(700))

    tb = Accounting.trial_balance!(nil, opts)
    assert Decimal.eq?(tb.debit, tb.credit)

    bs = Accounting.balance_sheet!(nil, opts)
    assert bs.balanced?
    # bank 880 = tax payable 180 + earnings 700
    assert Decimal.eq?(bs.assets_total, d(880))
    assert Decimal.eq?(bs.earnings, d(700))

    overview = Accounting.accounting_overview!(opts)
    assert Decimal.eq?(overview.cash, d(880))
    assert Decimal.eq?(overview.net_this_month, d(700))
  end

  test "expenses must come from an expense account", %{opts: opts} do
    Accounting.setup_books!(opts)

    assert {:error, %Ash.Error.Invalid{}} =
             Accounting.record_expense(
               %{
                 expense_account_id: account(opts, :cash).id,
                 paid_from_account_id: account(opts, :bank).id,
                 amount: "10"
               },
               opts
             )
  end

  test "sync posts sales recorded before the books existed", %{opts: opts} = context do
    invoice = issued_invoice(context)

    Sales.record_payment!(
      %{invoice_id: invoice.id, amount: Money.new!(:USD, 100), method: :cash},
      opts
    )

    # Simulate history from before accounting: drop the entries.
    schema = Zippiker.Accounts.Tenant.schema(opts[:tenant])
    Zippiker.Repo.query!(~s|DELETE FROM "#{schema}".journal_lines|)
    Zippiker.Repo.query!(~s|DELETE FROM "#{schema}".journal_entries|)

    assert %{posted: 2} = Accounting.sync_sales!(opts)
    assert %{posted: 0} = Accounting.sync_sales!(opts)
    assert Decimal.eq?(account(opts, :receivable).balance, d(1080))
  end

  test "system accounts and used accounts can't be deleted", %{opts: opts} do
    Accounting.setup_books!(opts)
    assert {:error, _} = Accounting.delete_account(account(opts, :cash), opts)

    spare = Accounting.create_account!(%{code: "7000", name: "Spare", type: :expense}, opts)
    assert :ok = Accounting.delete_account(spare, opts)
  end
end
