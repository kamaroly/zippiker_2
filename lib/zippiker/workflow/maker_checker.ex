defmodule Zippiker.Workflow.MakerChecker do
  @moduledoc """
  Maker-checker (four eyes): when a workspace switches it on in its global
  settings, changes in the chosen areas aren't applied directly. They
  become a `Zippiker.Workflow.ChangeRequest` that another person approves
  through the workflow engine; only then is the change applied, as the
  person who made it. Resources opt in per action with
  `change {Zippiker.Workflow.Changes.MakerChecker, scope: :employees}`.
  """

  @scopes [
    %{
      key: :employees,
      label: "Employees",
      description: "Hiring, edits (incl. pay), leaving, rehiring"
    },
    %{key: :contacts, label: "Contacts & companies", description: "Edits and archiving"},
    %{
      key: :products,
      label: "Products & prices",
      description: "New products, price changes, archiving"
    },
    %{
      key: :accounts,
      label: "Chart of accounts",
      description: "New, changed or deleted accounts"
    },
    %{key: :tax_rates, label: "Tax rates", description: "New, changed or archived rates"},
    %{
      key: :journal_entries,
      label: "Journal postings",
      description: "Manual journal entries and recorded expenses post only once approved"
    }
  ]

  def scopes, do: @scopes
  def scope_label(key), do: Enum.find_value(@scopes, to_string(key), &(&1.key == key && &1.label))

  @doc "Whether changes in `scope` need approval in the tenant's workspace."
  def enabled?(tenant, scope) do
    case Zippiker.Accounts.Tenant.organization_id(tenant) do
      nil ->
        false

      id ->
        case Zippiker.Accounts.get_organization(id, authorize?: false) do
          {:ok, %{maker_checker?: true, maker_checker_scopes: scopes}} -> scope in scopes
          _ -> false
        end
    end
  end

  @doc "Makes action input storable as JSON (dates, decimals, money…)."
  def to_json(%Decimal{} = value), do: Decimal.to_string(value, :normal)
  def to_json(%Date{} = value), do: Date.to_iso8601(value)
  def to_json(%DateTime{} = value), do: DateTime.to_iso8601(value)

  def to_json(%Money{} = value),
    do: %{"amount" => to_json(value.amount), "currency" => to_string(value.currency)}

  def to_json(%{__struct__: _} = value), do: to_string(value)

  def to_json(value) when is_map(value),
    do: Map.new(value, fn {k, v} -> {to_string(k), to_json(v)} end)

  def to_json(value) when is_list(value), do: Enum.map(value, &to_json/1)
  def to_json(value) when is_atom(value) and value not in [nil, true, false], do: to_string(value)
  def to_json(value), do: value

  @doc "A short display value for the diff."
  def display(nil), do: nil
  def display(%Ash.NotLoaded{}), do: nil
  def display(value) when is_binary(value), do: String.slice(value, 0, 200)

  def display(value),
    do:
      value |> to_json() |> then(&if(is_binary(&1), do: &1, else: Jason.encode!(&1))) |> display()
end
