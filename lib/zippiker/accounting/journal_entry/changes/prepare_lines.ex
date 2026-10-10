defmodule Zippiker.Accounting.JournalEntry.Changes.PrepareLines do
  @moduledoc """
  Cleans the `lines` argument (drops empty rows, parses amounts, stamps the
  entry date and position) and enforces double entry: every line has an
  account and one positive side, and debits equal credits. Sets `total`.
  """
  use Ash.Resource.Change

  require Ash.Query

  @impl true
  def change(changeset, _opts, _context) do
    date = Ash.Changeset.get_attribute(changeset, :date) || Date.utc_today()

    lines =
      (Ash.Changeset.get_argument(changeset, :lines) || [])
      |> Enum.map(&normalize/1)
      |> Enum.reject(&blank?/1)
      |> Enum.with_index(fn line, index -> Map.merge(line, %{position: index, date: date}) end)

    debits = sum(lines, :debit)
    credits = sum(lines, :credit)

    changeset
    |> Ash.Changeset.force_change_attributes(%{date: date, total: debits})
    |> Ash.Changeset.force_set_argument(:lines, lines)
    |> validate(lines, debits, credits)
  end

  defp validate(changeset, lines, debits, credits) do
    cond do
      Enum.any?(lines, &is_nil(&1.account_id)) ->
        error(changeset, "every line needs an account")

      Enum.any?(lines, &(not one_sided?(&1))) ->
        error(changeset, "each line takes either a debit or a credit, greater than zero")

      length(lines) < 2 ->
        error(changeset, "an entry needs at least two lines")

      not Decimal.eq?(debits, credits) ->
        error(
          changeset,
          "debits (#{Decimal.to_string(debits, :normal)}) must equal credits (#{Decimal.to_string(credits, :normal)})"
        )

      not accounts_exist?(changeset, lines) ->
        error(changeset, "unknown account")

      true ->
        changeset
    end
  end

  defp error(changeset, message),
    do: Ash.Changeset.add_error(changeset, field: :lines, message: message)

  defp normalize(line) do
    %{
      account_id: blank_to_nil(get(line, :account_id)),
      description: blank_to_nil(get(line, :description)),
      party_id: blank_to_nil(get(line, :party_id)),
      debit: amount(get(line, :debit)),
      credit: amount(get(line, :credit))
    }
  end

  defp blank?(line),
    do: is_nil(line.account_id) and Decimal.eq?(line.debit, 0) and Decimal.eq?(line.credit, 0)

  defp one_sided?(%{debit: debit, credit: credit}) do
    (Decimal.gt?(debit, 0) and Decimal.eq?(credit, 0)) or
      (Decimal.gt?(credit, 0) and Decimal.eq?(debit, 0))
  end

  defp accounts_exist?(changeset, lines) do
    ids = lines |> Enum.map(& &1.account_id) |> Enum.uniq()

    Zippiker.Accounting.Account
    |> Ash.Query.filter(id in ^ids)
    |> Ash.count!(tenant: changeset.tenant, authorize?: false)
    |> Kernel.==(length(ids))
  end

  defp sum(lines, side),
    do: Enum.reduce(lines, Decimal.new(0), &Decimal.add(&2, Map.get(&1, side)))

  defp get(map, key), do: Map.get(map, key, Map.get(map, Atom.to_string(key)))

  defp blank_to_nil(value) when value in [nil, ""], do: nil
  defp blank_to_nil(value), do: value

  defp amount(%Decimal{} = value), do: Decimal.round(value, 2)
  defp amount(value) when is_integer(value), do: Decimal.new(value)
  defp amount(value) when is_float(value), do: value |> Decimal.from_float() |> Decimal.round(2)

  defp amount(value) when is_binary(value) do
    case value |> String.replace(",", "") |> String.trim() |> Decimal.parse() do
      {decimal, ""} -> Decimal.round(decimal, 2)
      _ -> Decimal.new(0)
    end
  end

  defp amount(_value), do: Decimal.new(0)
end
