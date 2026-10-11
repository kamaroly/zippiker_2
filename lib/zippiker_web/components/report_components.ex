defmodule ZippikerWeb.ReportComponents do
  @moduledoc """
  Renders any report from `Zippiker.Reporting` – the same table shape for
  all of them: headings, indented rows, subtotals and a grand total, with
  cells formatted by column type.
  """
  use Phoenix.Component

  alias ZippikerWeb.Format

  @numeric [:money, :number, :percent, :days]

  attr :report, :map, required: true
  attr :id, :string, default: "report-table"

  def report_table(assigns) do
    assigns =
      assign(assigns,
        width: length(assigns.report.columns),
        empty?: not Enum.any?(assigns.report.rows, &(&1.kind != :heading))
      )

    ~H"""
    <div class="overflow-x-auto">
      <table id={@id} class="w-full min-w-max text-sm">
        <thead>
          <tr class="border-b border-line text-xs text-muted">
            <th
              :for={column <- @report.columns}
              class={[
                "px-3 py-2.5 font-medium whitespace-nowrap first:pl-5 last:pr-5",
                numeric?(column) && "text-right",
                !numeric?(column) && "text-left"
              ]}
            >
              {column.label}
            </th>
          </tr>
        </thead>
        <tbody>
          <%= for {row, index} <- Enum.with_index(@report.rows) do %>
            <%= case row.kind do %>
              <% :heading -> %>
                <tr id={"#{@id}-row-#{index}"} class="report-heading">
                  <td
                    colspan={@width}
                    class="bg-canvas/60 px-5 pt-4 pb-1.5 text-xs font-semibold tracking-wide text-ink uppercase"
                    style={"padding-left: #{1.25 + row.depth * 1}rem"}
                  >
                    <.link :if={row.link} navigate={row.link} class="hover:text-brand">
                      {hd(row.cells)}
                    </.link>
                    <span :if={!row.link}>{hd(row.cells)}</span>
                  </td>
                </tr>
              <% kind -> %>
                <tr
                  id={"#{@id}-row-#{index}"}
                  class={[
                    "group transition-colors",
                    kind == :row && "border-b border-line/60 hover:bg-canvas/70",
                    kind == :subtotal && "border-b border-line font-medium text-ink",
                    kind == :total &&
                      "border-t-2 border-ink/80 bg-canvas/40 font-semibold text-ink"
                  ]}
                >
                  <td
                    :for={
                      {{cell, column}, position} <-
                        Enum.with_index(Enum.zip(row.cells, @report.columns))
                    }
                    class={[
                      "px-3 py-2 align-top first:pl-5 last:pr-5",
                      numeric?(column) && "tabular text-right whitespace-nowrap",
                      column.type in [:date, :datetime] && "whitespace-nowrap",
                      kind == :row && !numeric?(column) && "text-ink-soft",
                      negative?(cell, column) && "text-danger"
                    ]}
                    style={if(position == 0, do: "padding-left: #{1.25 + row.depth * 1}rem")}
                  >
                    <%= if position == link_cell(row) do %>
                      <.link
                        navigate={row.link}
                        class="font-medium text-ink hover:text-brand hover:underline"
                      >
                        {cell(cell, column.type)}
                      </.link>
                    <% else %>
                      <span
                        :if={column.type == :blank}
                        class="inline-block h-5 w-28 border-b border-ink/40"
                      />
                      <span :if={column.type != :blank}>{cell(cell, column.type)}</span>
                    <% end %>
                  </td>
                </tr>
            <% end %>
          <% end %>
          <tr :if={@empty?} id={"#{@id}-empty"}>
            <td colspan={@width} class="px-5 py-12 text-center text-sm text-muted">
              Nothing to report for this selection.
            </td>
          </tr>
        </tbody>
      </table>
    </div>
    """
  end

  defp numeric?(%{type: type}), do: type in @numeric

  # The first non-empty text-ish cell of a linked data row carries the link.
  defp link_cell(%{kind: :row, link: link, cells: cells}) when is_binary(link) do
    Enum.find_index(cells, &(&1 not in [nil, ""]))
  end

  defp link_cell(_row), do: nil

  defp negative?(%Decimal{} = value, %{type: type}) when type in [:money, :number],
    do: Decimal.lt?(value, 0)

  defp negative?(_cell, _column), do: false

  @doc "A cell as text."
  def cell(nil, _type), do: ""
  def cell(%Decimal{} = value, :money), do: number(value, 2)
  def cell(%Decimal{} = value, :percent), do: "#{number(value, 1)}%"
  def cell(%Decimal{} = value, :number), do: quantity(value)
  def cell(%Decimal{} = value, _type), do: quantity(value)
  def cell(value, :days) when is_integer(value), do: Format.count(value, "day")
  def cell(%Date{} = date, _type), do: Format.date(date)

  def cell(%DateTime{} = datetime, _type),
    do: Calendar.strftime(datetime, "%b %-d, %Y %H:%M")

  def cell(value, _type), do: to_string(value)

  @doc "1234567.891 -> \"1,234,567.89\"."
  def number(%Decimal{} = value, places) do
    rounded = Decimal.round(value, places)
    negative? = Decimal.lt?(rounded, 0)

    [whole | fraction] =
      rounded |> Decimal.abs() |> Decimal.to_string(:normal) |> String.split(".")

    whole =
      whole
      |> String.reverse()
      |> String.graphemes()
      |> Enum.chunk_every(3)
      |> Enum.map_join(",", &Enum.join/1)
      |> String.reverse()

    fraction = fraction |> List.first("") |> String.pad_trailing(places, "0")
    sign = if negative?, do: "-", else: ""
    if places == 0, do: sign <> whole, else: "#{sign}#{whole}.#{fraction}"
  end

  # Quantities drop trailing zeros: 3.000 -> 3, 2.50 -> 2.5.
  defp quantity(value) do
    places = value |> Decimal.normalize() |> Decimal.to_string(:normal) |> decimals()
    number(value, min(places, 4))
  end

  defp decimals(string) do
    case String.split(string, ".") do
      [_whole, fraction] -> String.length(fraction)
      _ -> 0
    end
  end

  @doc "CSV text of a report: header, then every row (headings and totals included)."
  def to_csv(report) do
    header = Enum.map(report.columns, & &1.label)

    rows =
      Enum.map(report.rows, fn row ->
        cells = Enum.map(row.cells, &csv_cell/1)
        indent = String.duplicate("  ", row.depth)

        case cells do
          [first | rest] -> [indent <> first | rest]
          [] -> []
        end
      end)

    [header | rows]
    |> Enum.map_join("\r\n", fn cells -> Enum.map_join(cells, ",", &escape/1) end)
  end

  defp csv_cell(nil), do: ""
  defp csv_cell(%Decimal{} = value), do: Decimal.to_string(value, :normal)
  defp csv_cell(%Date{} = date), do: Date.to_iso8601(date)
  defp csv_cell(%DateTime{} = datetime), do: DateTime.to_iso8601(datetime)
  defp csv_cell(value), do: to_string(value)

  defp escape(value) do
    if String.contains?(value, [",", "\"", "\n", "\r"]),
      do: "\"" <> String.replace(value, "\"", "\"\"") <> "\"",
      else: value
  end
end
