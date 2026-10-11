defmodule Zippiker.Reporting.Reports.Sales do
  @moduledoc """
  Sales and customers: sales by customer, product and type, profit by
  customer, tag and deal (project), payments, deposits, estimates and
  transaction lists. Sales are invoice lines before tax on issued or paid
  invoices; cost of sales uses each product's current average cost.
  """
  import Zippiker.Reporting.Table

  require Ash.Query

  alias Zippiker.Catalog.Product
  alias Zippiker.Expenses.ExpenseClaim
  alias Zippiker.Reporting.Context
  alias Zippiker.Reporting.Reports.{OpenItems, Payables}
  alias Zippiker.Sales.{Delivery, InvoiceLine, Quote, SalesOrder}

  @cost_note "Cost of sales uses each product's current average cost; services have no cost."

  # Invoice lines

  defp lines(ctx) do
    query =
      InvoiceLine
      |> Ash.Query.filter(
        invoice.status in [:issued, :paid] and invoice.issued_on >= ^ctx.from and
          invoice.issued_on <= ^ctx.to
      )
      |> Ash.Query.load([:product, invoice: [:customer, :deal]])

    query =
      if ctx.branch_id,
        do: Ash.Query.filter(query, invoice.branch_id == ^ctx.branch_id),
        else: query

    query
    |> Context.read(ctx)
    |> Enum.sort_by(&{&1.invoice.issued_on, &1.invoice.number, &1.position})
  end

  defp cost(%{product: %{kind: :goods} = product, quantity: quantity}),
    do: Decimal.mult(quantity, product.average_cost || product.cost_price || Decimal.new(0))

  defp cost(_line), do: Decimal.new(0)

  defp net(lines), do: Context.sum(Enum.map(lines, & &1.subtotal))
  defp costs(lines), do: Context.sum(Enum.map(lines, &cost/1))

  @doc "`[{customer, net sales}]` for the period, biggest first."
  def customer_sales(ctx) do
    ctx
    |> lines()
    |> Enum.group_by(& &1.invoice.customer_id)
    |> Enum.map(fn {_id, lines} -> {hd(lines).invoice.customer, net(lines)} end)
    |> Enum.sort_by(&elem(&1, 1), {:desc, Decimal})
  end

  defp line_row(line, name) do
    row(
      [
        line.invoice.issued_on,
        line.invoice.number,
        name,
        line.quantity,
        line.unit_price,
        Context.amount(line.subtotal)
      ],
      link: "/invoices/#{line.invoice_id}"
    )
  end

  defp line_columns(name) do
    [
      col("Date", :date),
      col("Invoice"),
      col(name),
      col("Quantity", :number),
      col("Rate", :money),
      col("Amount", :money)
    ]
  end

  defp product_name(%{product: %{name: name}}), do: name
  defp product_name(line), do: line.description || "No product"

  defp customer_group(line) do
    name = Context.name(line.invoice.customer)
    {name, name}
  end

  # Sales by customer

  def sales_by_customer_summary(ctx) do
    rows =
      ctx
      |> lines()
      |> Enum.group_by(& &1.invoice.customer_id)
      |> Enum.map(fn {_id, lines} ->
        customer = hd(lines).invoice.customer
        invoices = lines |> Enum.uniq_by(& &1.invoice_id) |> length()
        tax = Context.sum(Enum.map(lines, & &1.tax_amount))
        net = net(lines)

        row([Context.name(customer), Decimal.new(invoices), net, tax, Decimal.add(net, tax)],
          link: Context.party_path(customer)
        )
      end)
      |> Enum.sort_by(&Enum.at(&1.cells, 2), {:desc, Decimal})

    table(
      [
        col("Customer"),
        col("Invoices", :number),
        col("Sales", :money),
        col("Tax", :money),
        col("Total", :money)
      ],
      rows ++ OpenItems.footer(rows, 5, [1, 2, 3, 4])
    )
  end

  def sales_by_customer_detail(ctx) do
    rows =
      ctx
      |> lines()
      |> grouped(6, &customer_group/1, &line_row(&1, product_name(&1)), [3, 5],
        link: &Context.party_path(&1.invoice.customer)
      )

    table(line_columns("Product/service"), rows)
  end

  def sales_by_customer_type(ctx) do
    rows =
      ctx
      |> lines()
      |> grouped(
        6,
        fn line ->
          type = blank(line.invoice.customer && line.invoice.customer.industry, "No type")
          {type, type}
        end,
        &line_row(&1, "#{Context.name(&1.invoice.customer)} · #{product_name(&1)}"),
        [3, 5]
      )

    table(line_columns("Customer · product"), rows,
      note: "The customer type is the company's industry."
    )
  end

  def profit_and_loss_by_customer(ctx) do
    rows =
      ctx
      |> lines()
      |> Enum.group_by(& &1.invoice.customer_id)
      |> Enum.map(fn {_id, lines} ->
        customer = hd(lines).invoice.customer
        sales = net(lines)
        cost = costs(lines)
        profit = Decimal.sub(sales, cost)

        row([Context.name(customer), sales, cost, profit, percent(profit, sales)],
          link: Context.party_path(customer)
        )
      end)
      |> Enum.sort_by(&Enum.at(&1.cells, 3), {:desc, Decimal})

    table(
      [
        col("Customer"),
        col("Sales", :money),
        col("Cost of sales", :money),
        col("Gross profit", :money),
        col("Margin", :percent)
      ],
      rows ++ OpenItems.footer(rows, 5, [1, 2, 3]),
      note: @cost_note
    )
  end

  def income_by_customer(ctx) do
    rows =
      ctx
      |> lines()
      |> Enum.group_by(& &1.invoice.customer_id)
      |> Enum.map(fn {_id, lines} ->
        customer = hd(lines).invoice.customer
        income = net(lines)
        expenses = costs(lines)

        row([Context.name(customer), income, expenses, Decimal.sub(income, expenses)],
          link: Context.party_path(customer)
        )
      end)
      |> Enum.sort_by(&hd(&1.cells))

    table(
      [
        col("Customer"),
        col("Income", :money),
        col("Expenses", :money),
        col("Net income", :money)
      ],
      rows ++ OpenItems.footer(rows, 4, [1, 2, 3]),
      note: @cost_note
    )
  end

  def project_profitability(ctx) do
    rows =
      ctx
      |> lines()
      |> Enum.reject(&is_nil(&1.invoice.deal))
      |> Enum.group_by(& &1.invoice.deal_id)
      |> Enum.map(fn {deal_id, lines} ->
        invoice = hd(lines).invoice
        income = net(lines)
        cost = costs(lines)
        profit = Decimal.sub(income, cost)

        row(
          [
            invoice.deal.title,
            Context.name(invoice.customer),
            income,
            cost,
            profit,
            percent(profit, income)
          ],
          link: "/deals/#{deal_id}"
        )
      end)
      |> Enum.sort_by(&Enum.at(&1.cells, 4), {:desc, Decimal})

    table(
      [
        col("Project (deal)"),
        col("Customer"),
        col("Income", :money),
        col("Cost", :money),
        col("Profit", :money),
        col("Margin", :percent)
      ],
      rows ++ OpenItems.footer(rows, 6, [2, 3, 4]),
      note: "Projects are deals; income is from invoices linked to the deal. " <> @cost_note
    )
  end

  def profit_and_loss_by_tag(ctx) do
    sales =
      ctx
      |> lines()
      |> Enum.flat_map(fn line ->
        for tag <- tags(line.invoice.customer), do: {tag, :sales, Context.amount(line.subtotal)}
      end)

    purchases =
      ctx
      |> OpenItems.issued(:ap)
      |> Enum.flat_map(fn bill ->
        for tag <- tags(bill.supplier), do: {tag, :purchases, Context.amount(bill.subtotal)}
      end)

    rows =
      (sales ++ purchases)
      |> Enum.group_by(&elem(&1, 0))
      |> Enum.map(fn {tag, items} ->
        total = fn kind ->
          items |> Enum.filter(&(elem(&1, 1) == kind)) |> Enum.map(&elem(&1, 2)) |> Context.sum()
        end

        row([
          tag,
          total.(:sales),
          total.(:purchases),
          Decimal.sub(total.(:sales), total.(:purchases))
        ])
      end)
      |> Enum.sort_by(&hd(&1.cells))

    table(
      [
        col("Tag"),
        col("Sales", :money),
        col("Purchases", :money),
        col("Net", :money)
      ],
      rows,
      note:
        "Tags come from the customer or supplier. A contact with several tags counts under each."
    )
  end

  defp tags(nil), do: ["No tag"]
  defp tags(%{tags: [_ | _] = tags}), do: tags
  defp tags(_party), do: ["No tag"]

  # Products

  def product_list(ctx) do
    rows =
      Product
      |> Ash.Query.filter(is_nil(archived_at))
      |> Ash.Query.load([:tax_rate, :on_hand])
      |> Ash.Query.sort(name: :asc)
      |> Context.read(ctx)
      |> Enum.map(fn product ->
        row(
          [
            product.name,
            product.sku || "",
            Context.humanize(product.kind),
            product.unit || "",
            product.unit_price,
            product.average_cost || product.cost_price,
            (product.tax_rate && product.tax_rate.name) || "",
            if(product.track_inventory?, do: product.on_hand),
            if(product.active?, do: "Active", else: "Inactive")
          ],
          link: "/products/#{product.id}/edit"
        )
      end)

    table(
      [
        col("Name"),
        col("SKU"),
        col("Type"),
        col("Unit"),
        col("Sales price", :money),
        col("Cost", :money),
        col("Tax"),
        col("On hand", :number),
        col("Status")
      ],
      rows
    )
  end

  def sales_by_product_summary(ctx) do
    lines = lines(ctx)
    total_sales = net(lines)

    rows =
      lines
      |> Enum.group_by(&product_name/1)
      |> Enum.map(fn {name, lines} ->
        quantity = Context.sum(Enum.map(lines, & &1.quantity))
        sales = net(lines)
        cost = costs(lines)
        margin = Decimal.sub(sales, cost)

        average =
          if Decimal.eq?(quantity, 0),
            do: nil,
            else: Decimal.round(Decimal.div(sales, quantity), 2)

        row([
          name,
          quantity,
          sales,
          percent(sales, total_sales),
          average,
          cost,
          margin,
          percent(margin, sales)
        ])
      end)
      |> Enum.sort_by(&Enum.at(&1.cells, 2), {:desc, Decimal})

    table(
      [
        col("Product/service"),
        col("Quantity", :number),
        col("Sales", :money),
        col("% of sales", :percent),
        col("Average price", :money),
        col("Cost of sales", :money),
        col("Gross margin", :money),
        col("Margin", :percent)
      ],
      rows ++ OpenItems.footer(rows, 8, [2, 5, 6]),
      note: @cost_note
    )
  end

  def sales_by_product_detail(ctx) do
    rows =
      ctx
      |> lines()
      |> grouped(
        6,
        fn line ->
          name = product_name(line)
          {name, name}
        end,
        &line_row(&1, Context.name(&1.invoice.customer)),
        [3, 5]
      )

    table(line_columns("Customer"), rows)
  end

  # Payments

  def payment_transactions(ctx) do
    received =
      for payment <- OpenItems.payments(ctx, :ar) do
        {payment.paid_on,
         row(
           [
             payment.paid_on,
             "Payment received",
             Context.name(payment.party),
             payment.document.number,
             Context.humanize(payment.method),
             Context.amount(payment.amount),
             nil
           ],
           link: "/invoices/#{payment.document.id}"
         )}
      end

    paid =
      for payment <- OpenItems.payments(ctx, :ap) do
        {payment.paid_on,
         row(
           [
             payment.paid_on,
             "Bill payment",
             Context.name(payment.party),
             payment.document.number,
             Context.humanize(payment.method),
             nil,
             Context.amount(payment.amount)
           ],
           link: "/bills/#{payment.document.id}"
         )}
      end

    reimbursed =
      ExpenseClaim
      |> Ash.Query.filter(
        status == :reimbursed and reimbursed_on >= ^ctx.from and reimbursed_on <= ^ctx.to
      )
      |> Context.branch(ctx)
      |> Ash.Query.load(:claimant)
      |> Context.read(ctx)
      |> Enum.map(fn claim ->
        {claim.reimbursed_on,
         row(
           [
             claim.reimbursed_on,
             "Expense reimbursement",
             Context.user_name(claim.claimant),
             claim.number,
             Context.humanize(claim.reimbursed_from),
             nil,
             Context.amount(claim.total)
           ],
           link: "/expenses/#{claim.id}"
         )}
      end)

    rows =
      (received ++ paid ++ reimbursed)
      |> Enum.sort_by(&elem(&1, 0), Date)
      |> Enum.map(&elem(&1, 1))

    money_in = sum_column(rows, 5)
    money_out = sum_column(rows, 6)

    footer =
      if rows == [],
        do: [],
        else: [
          subtotal(["Total", nil, nil, nil, nil, money_in, money_out]),
          total(["Net cash flow", nil, nil, nil, nil, Decimal.sub(money_in, money_out), nil])
        ]

    table(
      [
        col("Date", :date),
        col("Type"),
        col("Name"),
        col("Document"),
        col("Method"),
        col("Money in", :money),
        col("Money out", :money)
      ],
      rows ++ footer
    )
  end

  def deposit_detail(ctx) do
    rows =
      ctx
      |> OpenItems.payments(:ar)
      |> grouped(
        5,
        fn payment ->
          method = Context.humanize(payment.method)
          {method, method}
        end,
        fn payment ->
          row(
            [
              payment.paid_on,
              payment.document.number,
              Context.name(payment.party),
              payment.reference || "",
              Context.amount(payment.amount)
            ],
            link: "/invoices/#{payment.document.id}"
          )
        end,
        [4]
      )

    table(
      [
        col("Date", :date),
        col("Invoice"),
        col("Customer"),
        col("Reference"),
        col("Amount", :money)
      ],
      rows,
      note: "Grouped by how the money was received."
    )
  end

  def payment_methods(ctx) do
    received = Enum.group_by(OpenItems.payments(ctx, :ar), & &1.method)
    paid = Enum.group_by(OpenItems.payments(ctx, :ap), & &1.method)

    rows =
      for method <- [:bank_transfer, :card, :cash, :mobile_money, :cheque, :other] do
        r = Map.get(received, method, [])
        p = Map.get(paid, method, [])

        row([
          Context.humanize(method),
          Decimal.new(length(r)),
          Context.sum(Enum.map(r, & &1.amount)),
          Decimal.new(length(p)),
          Context.sum(Enum.map(p, & &1.amount))
        ])
      end

    table(
      [
        col("Payment method"),
        col("Payments received", :number),
        col("Amount received", :money),
        col("Payments made", :number),
        col("Amount paid", :money)
      ],
      rows ++ OpenItems.footer(rows, 5, [1, 2, 3, 4])
    )
  end

  # Estimates and transactions

  def estimates_by_customer(ctx) do
    rows =
      Quote
      |> Ash.Query.filter(issued_on >= ^ctx.from and issued_on <= ^ctx.to)
      |> Context.branch(ctx)
      |> Ash.Query.load(:customer)
      |> Ash.Query.sort(issued_on: :asc)
      |> Context.read(ctx)
      |> grouped(
        5,
        fn quote ->
          name = Context.name(quote.customer)
          {name, name}
        end,
        fn quote ->
          row(
            [
              quote.issued_on,
              quote.number,
              Context.humanize(quote.status),
              quote.valid_until,
              Context.amount(quote.total)
            ],
            link: "/quotes/#{quote.id}"
          )
        end,
        [4],
        link: &Context.party_path(&1.customer)
      )

    table(
      [
        col("Date", :date),
        col("Number"),
        col("Status"),
        col("Valid until", :date),
        col("Amount", :money)
      ],
      rows
    )
  end

  def transactions_by_customer(ctx) do
    in_period = fn resource ->
      resource
      |> Ash.Query.filter(issued_on >= ^ctx.from and issued_on <= ^ctx.to)
      |> Context.branch(ctx)
      |> Ash.Query.load(:customer)
      |> Context.read(ctx)
    end

    quotes =
      for quote <- in_period.(Quote),
          do: item(quote.customer, quote.issued_on, "Quote", quote, "/quotes", quote.total)

    orders =
      for order <- in_period.(SalesOrder),
          do: item(order.customer, order.issued_on, "Sales order", order, "/orders", order.total)

    deliveries =
      Delivery
      |> Ash.Query.filter(shipped_on >= ^ctx.from and shipped_on <= ^ctx.to)
      |> Ash.Query.load(:customer)
      |> Context.read(ctx)
      |> Enum.map(&item(&1.customer, &1.shipped_on, "Delivery note", &1, "/deliveries", nil))

    {invoices, payments} = invoices_and_payments(ctx, :ar)
    items = quotes ++ orders ++ deliveries ++ invoices ++ payments
    table(Payables.transaction_columns(), Payables.transactions_table(items))
  end

  def transactions_by_tag(ctx) do
    {invoices, receipts} = invoices_and_payments(ctx, :ar)
    {bills, payments} = invoices_and_payments(ctx, :ap)

    items =
      for item <- invoices ++ receipts ++ bills ++ payments, tag <- tags(item.party) do
        Map.put(item, :tag, tag)
      end

    rows = Payables.transactions_table(items, &{&1.tag, &1.tag})

    table(Payables.transaction_columns(), rows,
      note:
        "Tags come from the customer or supplier. A contact with several tags shows under each."
    )
  end

  defp invoices_and_payments(ctx, side) do
    %{document: document, path: path} = OpenItems.side(side)
    payment_type = if side == :ar, do: "Payment received", else: "Bill payment"

    documents =
      for doc <- OpenItems.issued(ctx, side),
          do: item(doc.party, doc.issued_on, document, doc, path, doc.total)

    payments =
      for payment <- OpenItems.payments(ctx, side) do
        %{
          party: payment.party,
          date: payment.paid_on,
          type: payment_type,
          number: payment.reference || payment.document.number,
          status: Context.humanize(payment.method),
          link: "#{path}/#{payment.document.id}",
          amount: Context.amount(payment.amount)
        }
      end

    {documents, payments}
  end

  defp item(party, date, type, document, path, amount) do
    %{
      party: party,
      date: date,
      type: type,
      number: document.number,
      status: Context.humanize(document.status),
      link: "#{path}/#{document.id}",
      amount: amount && Context.amount(amount)
    }
  end

  defp blank(value, fallback) when value in [nil, ""], do: fallback
  defp blank(value, _fallback), do: value
end
