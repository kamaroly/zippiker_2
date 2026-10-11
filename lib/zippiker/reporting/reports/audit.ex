defmodule Zippiker.Reporting.Reports.Audit do
  @moduledoc """
  The audit log: every create, change and delete recorded by paper trail on
  contacts, leads, deals, quotes, orders, invoices, payments, purchase
  orders, bills, employees and expense claims.
  """
  import Zippiker.Reporting.Table

  require Ash.Query

  alias Zippiker.Reporting.Context

  # {resource, label, path prefix}
  @tracked [
    {Zippiker.Parties.Party, "Contact", "/contacts"},
    {Zippiker.Crm.Lead, "Lead", "/leads"},
    {Zippiker.Crm.Deal, "Deal", "/deals"},
    {Zippiker.Sales.Quote, "Quote", "/quotes"},
    {Zippiker.Sales.SalesOrder, "Sales order", "/orders"},
    {Zippiker.Sales.Invoice, "Invoice", "/invoices"},
    {Zippiker.Sales.Payment, "Payment", nil},
    {Zippiker.Purchasing.PurchaseOrder, "Purchase order", "/purchase-orders"},
    {Zippiker.Purchasing.Bill, "Bill", "/bills"},
    {Zippiker.HR.Employee, "Employee", "/hr/employees"},
    {Zippiker.Expenses.ExpenseClaim, "Expense claim", "/expenses"}
  ]

  @hidden ~w(id organization_id custom_fields position)

  def audit_log(ctx) do
    from = DateTime.new!(ctx.from, ~T[00:00:00], "Etc/UTC")
    to = DateTime.new!(Date.add(ctx.to, 1), ~T[00:00:00], "Etc/UTC")

    rows =
      @tracked
      |> Enum.flat_map(fn {resource, label, path} ->
        Module.concat(resource, Version)
        |> Ash.Query.filter(version_inserted_at >= ^from and version_inserted_at < ^to)
        |> Ash.Query.load([:user, :version_source])
        |> Context.read(ctx)
        |> Enum.map(&{&1, label, path})
      end)
      |> Enum.sort_by(fn {version, _, _} -> version.version_inserted_at end, {:desc, DateTime})
      |> Enum.map(fn {version, label, path} ->
        source = version.version_source

        row(
          [
            version.version_inserted_at,
            Context.user_name(version.user),
            action(version),
            label,
            record_label(source, version.changes),
            fields(version.changes)
          ],
          link:
            if(path && source && version.version_action_type != :destroy,
              do: link(path, source)
            )
        )
      end)

    table(
      [
        col("When", :datetime),
        col("User"),
        col("Event"),
        col("Type"),
        col("Record"),
        col("Changed fields")
      ],
      rows
    )
  end

  defp action(%{version_action_type: :create}), do: "Created"
  defp action(%{version_action_type: :destroy}), do: "Deleted"

  defp action(%{version_action_name: name}) when name not in [nil, :update],
    do: Context.humanize(name)

  defp action(_version), do: "Edited"

  defp record_label(source, changes) do
    record = source || %{}
    changes = changes || %{}

    Enum.find_value([:number, :name, :title, :employee_number], "—", fn key ->
      case Map.get(record, key) || Map.get(changes, to_string(key)) do
        value when value in [nil, ""] -> nil
        %Ash.NotLoaded{} -> nil
        value -> to_string(value)
      end
    end)
  end

  defp fields(changes) when is_map(changes) do
    changes
    |> Map.keys()
    |> Enum.map(&to_string/1)
    |> Enum.reject(&(&1 in @hidden or String.ends_with?(&1, "_id")))
    |> Enum.sort()
    |> Enum.map_join(", ", &Context.humanize/1)
  end

  defp fields(_changes), do: ""

  defp link("/contacts", %{kind: :organization, id: id}), do: "/companies/#{id}"
  defp link(path, %{id: id}), do: "#{path}/#{id}"
end
