defmodule Zippiker.Reporting.Reports.OpenItems do
  @moduledoc """
  Invoices (who owes you, `:ar`) and bills (what you owe, `:ap`) seen the
  same way: what was open on a date, how overdue, by party, with payments.
  The open amount on a date counts only payments made up to that date.
  """
  import Zippiker.Reporting.Table

  require Ash.Query

  alias Zippiker.Purchasing.{Bill, BillPayment}
  alias Zippiker.Reporting.Context
  alias Zippiker.Sales.{Invoice, Payment}

  @buckets ["Current", "1–30 days", "31–60 days", "61–90 days", "91 days and over"]

  def side(:ar),
    do: %{
      resource: Invoice,
      payment: Payment,
      party: :customer,
      party_label: "Customer",
      document: "Invoice",
      path: "/invoices",
      statuses: [:issued, :paid]
    }

  def side(:ap),
    do: %{
      resource: Bill,
      payment: BillPayment,
      party: :supplier,
      party_label: "Supplier",
      document: "Bill",
      path: "/bills",
      statuses: [:open, :paid]
    }

  @doc "Documents open on `as_of`, each with `:open` and `:days_overdue`."
  def open(ctx, side_key, as_of \\ nil) do
    as_of = as_of || ctx.to
    side = side(side_key)

    side.resource
    |> Ash.Query.filter(status in ^side.statuses and issued_on <= ^as_of)
    |> Context.branch(ctx)
    |> Ash.Query.load([side.party, :payments])
    |> Ash.Query.sort(issued_on: :asc, number: :asc)
    |> Context.read(ctx)
    |> Enum.map(fn document ->
      paid =
        document.payments
        |> Enum.filter(&(Date.compare(&1.paid_on, as_of) != :gt))
        |> Enum.map(& &1.amount)
        |> Context.sum()

      Map.merge(document, %{
        open: Decimal.sub(Context.amount(document.total), paid),
        days_overdue: Context.days_between(document.due_on || document.issued_on, as_of),
        party: Map.get(document, side.party)
      })
    end)
    |> Enum.filter(&Decimal.gt?(&1.open, 0))
  end

  @doc "Documents issued in the period (not drafts)."
  def issued(ctx, side_key, loads \\ []) do
    side = side(side_key)

    side.resource
    |> Ash.Query.filter(status != :draft and issued_on >= ^ctx.from and issued_on <= ^ctx.to)
    |> Context.branch(ctx)
    |> Ash.Query.load([side.party | loads])
    |> Ash.Query.sort(issued_on: :asc, number: :asc)
    |> Context.read(ctx)
    |> Enum.map(&Map.put(&1, :party, Map.get(&1, side.party)))
  end

  @doc "Payments made in the period, with their document and party."
  def payments(ctx, side_key) do
    side = side(side_key)
    document = if side_key == :ar, do: :invoice, else: :bill

    query =
      side.payment
      |> Ash.Query.filter(paid_on >= ^ctx.from and paid_on <= ^ctx.to)
      |> Ash.Query.load([{document, [side.party]}])
      |> Ash.Query.sort(paid_on: :asc)

    query =
      case {ctx.branch_id, side_key} do
        {nil, _} -> query
        {id, :ar} -> Ash.Query.filter(query, invoice.branch_id == ^id)
        {id, :ap} -> Ash.Query.filter(query, bill.branch_id == ^id)
      end

    query
    |> Context.read(ctx)
    |> Enum.map(fn payment ->
      doc = Map.get(payment, document)
      Map.merge(payment, %{document: doc, party: Map.get(doc, side.party)})
    end)
  end

  # Reports

  def ageing_summary(ctx, side_key) do
    side = side(side_key)

    rows =
      ctx
      |> open(side_key)
      |> Enum.group_by(&party_key/1)
      |> Enum.map(fn {_id, documents} ->
        party = hd(documents).party
        amounts = Enum.map(0..4, fn index -> bucket_sum(documents, index) end)
        row([Context.name(party) | amounts] ++ [Context.sum(amounts)], link: party_link(party))
      end)
      |> Enum.sort_by(&hd(&1.cells))

    table(
      [col(side.party_label) | Enum.map(@buckets, &col(&1, :money))] ++ [col("Total", :money)],
      rows ++ footer(rows, 7, [1, 2, 3, 4, 5, 6])
    )
  end

  def ageing_detail(ctx, side_key) do
    side = side(side_key)

    rows =
      ctx
      |> open(side_key)
      |> grouped(
        8,
        fn document ->
          index = bucket(document.days_overdue)
          {index, Enum.at(@buckets, index)}
        end,
        fn document ->
          row(
            [
              document.issued_on,
              side.document,
              document.number,
              Context.name(document.party),
              document.due_on,
              max(document.days_overdue, 0),
              Context.amount(document.total),
              document.open
            ],
            link: "#{side.path}/#{document.id}"
          )
        end,
        [6, 7]
      )

    table(
      [
        col("Date", :date),
        col("Type"),
        col("Number"),
        col(side.party_label),
        col("Due date", :date),
        col("Past due", :days),
        col("Amount", :money),
        col("Open balance", :money)
      ],
      rows
    )
  end

  def open_by_party(ctx, side_key) do
    side = side(side_key)

    rows =
      ctx
      |> open(side_key)
      |> grouped(
        6,
        &party_group/1,
        fn document ->
          row(
            [
              document.issued_on,
              document.number,
              document.due_on,
              max(document.days_overdue, 0),
              Context.amount(document.total),
              document.open
            ],
            link: "#{side.path}/#{document.id}"
          )
        end,
        [4, 5],
        link: &party_link(&1.party)
      )

    table(
      [
        col("Date", :date),
        col("Number"),
        col("Due date", :date),
        col("Past due", :days),
        col("Amount", :money),
        col("Open balance", :money)
      ],
      rows
    )
  end

  def balance_summary(ctx, side_key) do
    side = side(side_key)

    rows =
      ctx
      |> open(side_key)
      |> Enum.group_by(&party_key/1)
      |> Enum.map(fn {_id, documents} ->
        party = hd(documents).party

        row([Context.name(party), length(documents), Context.sum(Enum.map(documents, & &1.open))],
          link: party_link(party)
        )
      end)
      |> Enum.sort_by(&hd(&1.cells))

    table(
      [col(side.party_label), col("Open documents", :number), col("Balance", :money)],
      rows ++ footer(rows, 3, [2])
    )
  end

  def balance_detail(ctx, side_key) do
    side = side(side_key)

    documents =
      ctx
      |> open(side_key)
      |> Enum.group_by(&party_key/1)
      |> Enum.flat_map(fn {_id, documents} ->
        {documents, _} =
          Enum.map_reduce(documents, Decimal.new(0), fn document, balance ->
            balance = Decimal.add(balance, document.open)
            {Map.put(document, :running, balance), balance}
          end)

        documents
      end)

    rows =
      grouped(
        documents,
        7,
        &party_group/1,
        fn document ->
          row(
            [
              document.issued_on,
              side.document,
              document.number,
              document.due_on,
              Context.amount(document.total),
              document.open,
              document.running
            ],
            link: "#{side.path}/#{document.id}"
          )
        end,
        [4, 5],
        link: &party_link(&1.party)
      )

    table(
      [
        col("Date", :date),
        col("Type"),
        col("Number"),
        col("Due date", :date),
        col("Amount", :money),
        col("Open balance", :money),
        col("Balance", :money)
      ],
      rows
    )
  end

  def collections(ctx) do
    rows =
      ctx
      |> open(:ar)
      |> Enum.filter(&(&1.days_overdue > 0))
      |> grouped(
        6,
        fn document ->
          party = document.party

          contact =
            [party && party.phone, party && party.email]
            |> Enum.reject(&(&1 in [nil, ""]))
            |> Enum.map_join(" · ", &to_string/1)

          label = Context.name(party) <> if(contact != "", do: " · #{contact}", else: "")
          {Context.name(party), label}
        end,
        fn document ->
          row(
            [
              document.issued_on,
              document.number,
              document.due_on,
              document.days_overdue,
              Context.amount(document.total),
              document.open
            ],
            link: "/invoices/#{document.id}"
          )
        end,
        [4, 5],
        link: &party_link(&1.party)
      )

    table(
      [
        col("Date", :date),
        col("Number"),
        col("Due date", :date),
        col("Past due", :days),
        col("Amount", :money),
        col("Open balance", :money)
      ],
      rows
    )
  end

  def list(ctx, side_key) do
    side = side(side_key)

    rows =
      ctx
      |> issued(side_key)
      |> Enum.map(fn document ->
        row(
          [
            document.issued_on,
            document.number,
            Context.name(document.party),
            document.due_on,
            Context.humanize(document.status),
            Context.amount(document.total),
            Context.amount(document.amount_paid),
            Decimal.sub(Context.amount(document.total), Context.amount(document.amount_paid))
          ],
          link: "#{side.path}/#{document.id}"
        )
      end)

    table(
      [
        col("Date", :date),
        col("Number"),
        col(side.party_label),
        col("Due date", :date),
        col("Status"),
        col("Amount", :money),
        col("Paid", :money),
        col("Balance", :money)
      ],
      rows ++ footer(rows, 8, [5, 6, 7])
    )
  end

  def with_payments(ctx, side_key) do
    side = side(side_key)

    rows =
      ctx
      |> issued(side_key, [:payments])
      |> Enum.group_by(&party_key/1)
      |> Enum.sort_by(fn {_id, [document | _]} -> Context.name(document.party) end)
      |> Enum.flat_map(fn {_id, documents} ->
        party = hd(documents).party

        lines =
          Enum.flat_map(documents, fn document ->
            [
              row(
                [
                  document.issued_on,
                  side.document,
                  document.number,
                  nil,
                  Context.amount(document.total),
                  nil
                ],
                depth: 1,
                link: "#{side.path}/#{document.id}"
              )
            ] ++
              for payment <- Enum.sort_by(document.payments, & &1.paid_on, Date) do
                row(
                  [
                    payment.paid_on,
                    "Payment",
                    payment.reference || "",
                    Context.humanize(payment.method),
                    nil,
                    Context.amount(payment.amount)
                  ],
                  depth: 2,
                  link: "#{side.path}/#{document.id}"
                )
              end
          end)

        [heading(Context.name(party), link: party_link(party))] ++
          lines ++ [subtotal(totals(lines, 6, [4, 5], "Total #{Context.name(party)}"))]
      end)

    data = Enum.filter(rows, &(&1.kind == :row))

    table(
      [
        col("Date", :date),
        col("Type"),
        col("Number / reference"),
        col("Method"),
        col("Amount", :money),
        col("Paid", :money)
      ],
      rows ++ if(data == [], do: [], else: [total(totals(data, 6, [4, 5], "Total"))])
    )
  end

  def payment_list(ctx, side_key) do
    side = side(side_key)

    rows =
      ctx
      |> payments(side_key)
      |> Enum.map(fn payment ->
        row(
          [
            payment.paid_on,
            payment.document.number,
            Context.name(payment.party),
            Context.humanize(payment.method),
            payment.reference || "",
            Context.amount(payment.amount)
          ],
          link: "#{side.path}/#{payment.document.id}"
        )
      end)

    table(
      [
        col("Date", :date),
        col(side.document),
        col(side.party_label),
        col("Method"),
        col("Reference"),
        col("Amount", :money)
      ],
      rows ++ footer(rows, 6, [5])
    )
  end

  # Helpers

  def bucket(days) when days <= 0, do: 0
  def bucket(days) when days <= 30, do: 1
  def bucket(days) when days <= 60, do: 2
  def bucket(days) when days <= 90, do: 3
  def bucket(_days), do: 4

  defp bucket_sum(documents, index) do
    documents
    |> Enum.filter(&(bucket(&1.days_overdue) == index))
    |> Enum.map(& &1.open)
    |> Context.sum()
  end

  defp party_key(%{party: %{id: id}}), do: id
  defp party_key(_item), do: nil

  defp party_group(document) do
    name = Context.name(document.party)
    {name, name}
  end

  def party_link(party), do: Context.party_path(party)

  def footer([], _width, _indexes), do: []
  def footer(rows, width, indexes), do: [total(totals(rows, width, indexes, "Total"))]
end
