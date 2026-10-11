defmodule Zippiker.Reporting.Table do
  @moduledoc """
  The shape every report returns, and builders for it:

      %{columns: [%{label, type}], rows: [%{kind, cells, link, depth}], note: nil}

  Row kinds: `:row` (data), `:heading` (a group title), `:subtotal` and
  `:total`. Cells line up with columns. Column types: `:text`, `:date`,
  `:money`, `:number`, `:percent` and `:days`. Money cells are Decimals in
  the workspace currency; empty cells are nil.
  """

  @doc "A column."
  def col(label, type \\ :text), do: %{label: label, type: type}

  def row(cells, opts \\ []),
    do: %{kind: :row, cells: cells, link: opts[:link], depth: opts[:depth] || 0}

  def heading(label, opts \\ []),
    do: %{kind: :heading, cells: [label], link: opts[:link], depth: opts[:depth] || 0}

  def subtotal(cells, opts \\ []),
    do: %{kind: :subtotal, cells: cells, link: nil, depth: opts[:depth] || 0}

  def total(cells), do: %{kind: :total, cells: cells, link: nil, depth: 0}

  @doc "Builds the report map."
  def table(columns, rows, opts \\ []) do
    %{columns: columns, rows: rows, note: opts[:note]}
  end

  @doc """
  Sums the given column indexes over data rows; other cells are nil and
  cell 0 is the label.
  """
  def totals(rows, width, indexes, label) do
    data = Enum.filter(rows, &(&1.kind == :row))

    for index <- 0..(width - 1) do
      cond do
        index == 0 -> label
        index in indexes -> sum_column(data, index)
        true -> nil
      end
    end
  end

  def sum_column(rows, index) do
    Enum.reduce(rows, Decimal.new(0), fn row, acc ->
      case Enum.at(row.cells, index) do
        %Decimal{} = value -> Decimal.add(acc, value)
        _ -> acc
      end
    end)
  end

  @doc """
  Groups items into heading / rows / subtotal blocks and a grand total.

    * `group_by` – fn item -> {sort_key, label}
    * `to_row` – fn item -> row
    * `sum` – column indexes to total
  """
  def grouped(items, width, group_by, to_row, sum, opts \\ []) do
    blocks =
      items
      |> Enum.group_by(group_by)
      |> Enum.sort_by(fn {{sort, _label}, _items} -> sort end)
      |> Enum.flat_map(fn {{_sort, label}, group} ->
        rows = Enum.map(group, to_row)

        [heading(label, link: opts[:link] && opts[:link].(hd(group)))] ++
          Enum.map(rows, &%{&1 | depth: 1}) ++
          [subtotal(totals(rows, width, sum, "Total #{label}"))]
      end)

    data = Enum.filter(blocks, &(&1.kind == :row))

    if data == [] do
      []
    else
      blocks ++ [total(totals(data, width, sum, opts[:total_label] || "Total"))]
    end
  end

  @doc "Percentage of part over whole as a Decimal (nil when whole is zero)."
  def percent(part, whole) do
    if Decimal.eq?(whole, 0),
      do: nil,
      else: part |> Decimal.mult(100) |> Decimal.div(whole) |> Decimal.round(1)
  end
end
