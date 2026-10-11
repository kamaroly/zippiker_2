defmodule Zippiker.Reporting.Reports.Contacts do
  @moduledoc """
  Contact and phone lists for customers, suppliers and employees. A
  customer is a contact with the customer role or one you have invoiced or
  quoted; a supplier has the supplier role or has billed you.
  """
  import Zippiker.Reporting.Table

  require Ash.Query

  alias Zippiker.HR.Employee
  alias Zippiker.Parties.Party
  alias Zippiker.Purchasing.{Bill, PurchaseOrder}
  alias Zippiker.Reporting.Context
  alias Zippiker.Sales.{Invoice, Quote}

  def customer_contacts(ctx), do: contacts(parties(ctx, :customer))
  def customer_phones(ctx), do: phones(parties(ctx, :customer))
  def supplier_contacts(ctx), do: contacts(parties(ctx, :supplier))
  def supplier_phones(ctx), do: phones(parties(ctx, :supplier))

  defp parties(ctx, role) do
    used =
      case role do
        :customer -> used_ids(ctx, [{Invoice, :customer_id}, {Quote, :customer_id}])
        :supplier -> used_ids(ctx, [{Bill, :supplier_id}, {PurchaseOrder, :supplier_id}])
      end

    Party
    |> Ash.Query.filter(is_nil(archived_at))
    |> Ash.Query.load([:employer, :addresses])
    |> Ash.Query.sort(name: :asc)
    |> Context.read(ctx)
    |> Enum.filter(&(role in (&1.roles || []) or MapSet.member?(used, &1.id)))
  end

  defp used_ids(ctx, sources) do
    for {resource, field} <- sources,
        record <- resource |> Ash.Query.select([field]) |> Context.read(ctx),
        id = Map.get(record, field),
        into: MapSet.new(),
        do: id
  end

  defp contacts(parties) do
    rows =
      Enum.map(parties, fn party ->
        row(
          [
            Context.name(party),
            if(party.kind == :person, do: Context.name(party.employer, ""), else: ""),
            party.email && to_string(party.email),
            party.phone || "",
            address(party.addresses),
            party.tax_id || ""
          ],
          link: Context.party_path(party)
        )
      end)

    table(
      [
        col("Name"),
        col("Company"),
        col("Email"),
        col("Phone"),
        col("Address"),
        col("Tax ID")
      ],
      rows
    )
  end

  defp phones(parties) do
    rows =
      for party <- parties do
        row([Context.name(party), party.phone || "—"], link: Context.party_path(party))
      end

    table([col("Name"), col("Phone")], rows)
  end

  defp address(addresses) do
    address =
      Enum.find(addresses, &(&1.kind == :billing)) || Enum.find(addresses, &(&1.kind == :main)) ||
        List.first(addresses)

    if address do
      [address.line1, address.line2, address.city, address.region, address.country]
      |> Enum.reject(&(&1 in [nil, ""]))
      |> Enum.join(", ")
    else
      ""
    end
  end

  def employee_contacts(ctx) do
    rows =
      Employee
      |> Ash.Query.filter(status == :active)
      |> Context.branch(ctx)
      |> Ash.Query.load([:name, :email, :phone, :department])
      |> Context.read(ctx)
      |> Enum.sort_by(&(&1.name || ""))
      |> Enum.map(fn employee ->
        row(
          [
            employee.name,
            employee.employee_number || "",
            employee.job_title || "",
            (employee.department && employee.department.name) || "",
            employee.email && to_string(employee.email),
            employee.phone || "",
            [employee.emergency_contact_name, employee.emergency_contact_phone]
            |> Enum.reject(&(&1 in [nil, ""]))
            |> Enum.join(" · ")
          ],
          link: "/hr/employees/#{employee.id}"
        )
      end)

    table(
      [
        col("Name"),
        col("Number"),
        col("Job title"),
        col("Department"),
        col("Email"),
        col("Phone"),
        col("Emergency contact")
      ],
      rows
    )
  end
end
