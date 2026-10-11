defmodule Zippiker.Reporting.Reports.Time do
  @moduledoc "Time activities: by customer and employee, timesheets, pay types and unbilled time."
  import Zippiker.Reporting.Table

  require Ash.Query

  alias Zippiker.HR.TimeActivity
  alias Zippiker.Reporting.Context

  @pay_types [:regular, :overtime, :weekend, :holiday, :sick, :vacation, :unpaid]

  defp activities(ctx, filter \\ & &1) do
    TimeActivity
    |> Ash.Query.filter(date >= ^ctx.from and date <= ^ctx.to)
    |> filter.()
    |> branch(ctx)
    |> Ash.Query.load([:customer, :deal, employee: [:name]])
    |> Ash.Query.sort(date: :asc, inserted_at: :asc)
    |> Context.read(ctx)
  end

  defp branch(query, %{branch_id: nil}), do: query
  defp branch(query, %{branch_id: id}), do: Ash.Query.filter(query, employee.branch_id == ^id)

  defp amount(%{billable?: true, hourly_rate: %Decimal{} = rate, hours: hours}),
    do: Decimal.mult(rate, hours)

  defp amount(_activity), do: nil

  defp employee(activity), do: activity.employee.name || "Employee"
  defp project(%{deal: %{title: title}}), do: title
  defp project(_activity), do: ""
  defp link(activity), do: "/hr/time?employee=#{activity.employee_id}"

  def unbilled_time(ctx) do
    rows =
      ctx
      |> activities(&Ash.Query.filter(&1, billable? and is_nil(invoice_id)))
      |> grouped(
        7,
        fn activity ->
          name = Context.name(activity.customer, "No customer")
          {name, name}
        end,
        fn activity ->
          row(
            [
              activity.date,
              employee(activity),
              project(activity),
              activity.description,
              activity.hours,
              activity.hourly_rate,
              amount(activity)
            ],
            link: link(activity)
          )
        end,
        [4, 6],
        link: &Context.party_path(&1.customer)
      )

    table(
      [
        col("Date", :date),
        col("Employee"),
        col("Project"),
        col("Description"),
        col("Hours", :number),
        col("Rate", :money),
        col("Amount", :money)
      ],
      rows
    )
  end

  def by_customer(ctx) do
    rows =
      ctx
      |> activities()
      |> grouped(
        7,
        fn activity ->
          name = Context.name(activity.customer, "No customer")
          {name, name}
        end,
        fn activity ->
          row(
            [
              activity.date,
              employee(activity),
              project(activity),
              Context.humanize(activity.pay_type),
              activity.description,
              activity.hours,
              amount(activity)
            ],
            link: link(activity)
          )
        end,
        [5, 6],
        link: &Context.party_path(&1.customer)
      )

    table(
      [
        col("Date", :date),
        col("Employee"),
        col("Project"),
        col("Pay type"),
        col("Description"),
        col("Hours", :number),
        col("Billable amount", :money)
      ],
      rows
    )
  end

  def by_employee(ctx) do
    rows =
      ctx
      |> activities()
      |> grouped(
        7,
        &{employee(&1), employee(&1)},
        fn activity ->
          row(
            [
              activity.date,
              Context.name(activity.customer, ""),
              project(activity),
              Context.humanize(activity.pay_type),
              activity.description,
              activity.hours,
              amount(activity)
            ],
            link: link(activity)
          )
        end,
        [5, 6],
        link: &"/hr/employees/#{&1.employee_id}"
      )

    table(
      [
        col("Date", :date),
        col("Customer"),
        col("Project"),
        col("Pay type"),
        col("Description"),
        col("Hours", :number),
        col("Billable amount", :money)
      ],
      rows
    )
  end

  def recent(ctx) do
    from = DateTime.new!(ctx.from, ~T[00:00:00], "Etc/UTC")
    to = DateTime.new!(Date.add(ctx.to, 1), ~T[00:00:00], "Etc/UTC")

    rows =
      TimeActivity
      |> Ash.Query.filter(updated_at >= ^from and updated_at < ^to)
      |> branch(ctx)
      |> Ash.Query.load([:customer, :deal, employee: [:name]])
      |> Ash.Query.sort(updated_at: :desc)
      |> Context.read(ctx)
      |> Enum.map(fn activity ->
        edited? = DateTime.diff(activity.updated_at, activity.inserted_at) > 1

        row(
          [
            activity.updated_at,
            if(edited?, do: "Edited", else: "Created"),
            activity.date,
            employee(activity),
            Context.name(activity.customer, ""),
            activity.description,
            activity.hours
          ],
          link: link(activity)
        )
      end)

    table(
      [
        col("Changed", :datetime),
        col("Change"),
        col("Activity date", :date),
        col("Employee"),
        col("Customer"),
        col("Description"),
        col("Hours", :number)
      ],
      rows
    )
  end

  def timesheets(ctx) do
    rows =
      ctx
      |> activities()
      |> Enum.group_by(&{&1.employee_id, &1.date})
      |> Enum.map(fn {{_employee_id, date}, [first | _] = day} ->
        hours = fn types ->
          day |> Enum.filter(&(&1.pay_type in types)) |> Enum.map(& &1.hours) |> Context.sum()
        end

        %{
          employee: employee(first),
          employee_id: first.employee_id,
          date: date,
          regular: hours.([:regular]),
          overtime: hours.([:overtime, :weekend, :holiday]),
          leave: hours.([:sick, :vacation, :unpaid]),
          total: Context.sum(Enum.map(day, & &1.hours))
        }
      end)
      |> Enum.sort_by(& &1.date, Date)
      |> grouped(
        6,
        &{&1.employee, &1.employee},
        fn day ->
          row([
            day.date,
            Calendar.strftime(day.date, "%A"),
            day.regular,
            day.overtime,
            day.leave,
            day.total
          ])
        end,
        [2, 3, 4, 5],
        link: &"/hr/employees/#{&1.employee_id}"
      )

    table(
      [
        col("Date", :date),
        col("Day"),
        col("Regular", :number),
        col("Overtime", :number),
        col("Leave", :number),
        col("Total hours", :number)
      ],
      rows,
      note:
        "Overtime includes weekend and holiday hours; leave includes sick, vacation and unpaid."
    )
  end

  def by_pay_type(ctx) do
    rows =
      ctx
      |> activities()
      |> Enum.group_by(& &1.employee_id)
      |> Enum.map(fn {id, [first | _] = items} ->
        by_type =
          for type <- @pay_types do
            items |> Enum.filter(&(&1.pay_type == type)) |> Enum.map(& &1.hours) |> Context.sum()
          end

        row([employee(first) | by_type] ++ [Context.sum(Enum.map(items, & &1.hours))],
          link: "/hr/employees/#{id}"
        )
      end)
      |> Enum.sort_by(&hd(&1.cells))

    width = length(@pay_types) + 2

    table(
      [col("Employee") | Enum.map(@pay_types, &col(Context.humanize(&1), :number))] ++
        [col("Total", :number)],
      if(rows == [],
        do: [],
        else: rows ++ [total(totals(rows, width, Enum.to_list(1..(width - 1)), "Total"))]
      )
    )
  end
end
