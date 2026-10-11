defmodule Zippiker.Reporting.Context do
  @moduledoc """
  What every report gets: the tenant, read options, the workspace and its
  currency, the period (`from`/`to`; `to` is the as-of date) and an
  optional branch. Plus small query helpers shared by the reports.
  """
  require Ash.Query

  defstruct [:tenant, :opts, :organization, :currency, :from, :to, :branch_id, :today]

  @doc "The workspace behind a tenant (the struct itself, or looked up by id)."
  def organization(%Zippiker.Accounts.Organization{} = organization), do: organization

  def organization(tenant) do
    Zippiker.Accounts.get_organization!(Ash.ToTenant.to_tenant(tenant, nil), authorize?: false)
  end

  def new(tenant, organization, report, arguments) do
    today = Date.utc_today()
    to = arguments[:to] || today

    from =
      case report.period do
        :range -> arguments[:from] || Date.new!(to.year, 1, 1)
        _ -> nil
      end

    %__MODULE__{
      tenant: tenant,
      opts: [tenant: tenant, authorize?: false],
      organization: organization,
      currency: organization.currency,
      from: from,
      to: to,
      branch_id: arguments[:branch_id],
      today: today
    }
  end

  @doc "Reads a query with the report's options."
  def read(query, %__MODULE__{opts: opts}), do: Ash.read!(query, opts)

  @doc "Narrows a query on a resource with `branch_id` to the chosen branch."
  def branch(query, %__MODULE__{branch_id: nil}), do: query
  def branch(query, %__MODULE__{branch_id: id}), do: Ash.Query.filter(query, branch_id == ^id)

  @doc "Decimal amount of a Money, Decimal or nil."
  def amount(nil), do: Decimal.new(0)
  def amount(%Money{amount: amount}), do: amount
  def amount(%Decimal{} = decimal), do: decimal
  def amount(number) when is_integer(number), do: Decimal.new(number)

  @doc "Sum of amounts."
  def sum(values), do: Enum.reduce(values, Decimal.new(0), &Decimal.add(&2, amount(&1)))

  @doc "Display name of a party (or a fallback)."
  def name(party, fallback \\ "—")
  def name(%{name: name}, _fallback) when is_binary(name) and name != "", do: name
  def name(_party, fallback), do: fallback

  @doc "Net amount of a document line after discount (its `subtotal`)."
  def line_net(line), do: amount(line.subtotal)

  @doc "\"bank_transfer\" -> \"Bank transfer\"."
  def humanize(nil), do: ""
  def humanize(value), do: value |> to_string() |> String.replace("_", " ") |> String.capitalize()

  def format_date(nil), do: ""
  def format_date(date), do: Calendar.strftime(date, "%b %-d, %Y")

  def user_name(nil), do: ""
  def user_name(%{name: name}) when is_binary(name) and name != "", do: name
  def user_name(%{email: email}), do: to_string(email)

  @doc "Path of a party's page."
  def party_path(nil), do: nil
  def party_path(%{kind: :person, id: id}), do: "/contacts/#{id}"
  def party_path(%{id: id}), do: "/companies/#{id}"

  @doc "Days from `date` to `as_of` (positive when `date` is earlier)."
  def days_between(nil, _as_of), do: 0
  def days_between(date, as_of), do: Date.diff(as_of, date)
end
