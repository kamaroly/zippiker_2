defmodule Zippiker.Sales.Pricing do
  @moduledoc """
  The one place line and document amounts are calculated.

      net   = quantity × unit price − discount%
      tax   = net × tax%
      total = net + tax

  Amounts are rounded to 2 decimals per line, then summed.
  """

  @zero Decimal.new(0)
  @hundred Decimal.new(100)

  def line(quantity, unit_price, discount_percent, tax_percent) do
    gross = Decimal.mult(dec(quantity), dec(unit_price))
    discount = gross |> Decimal.mult(dec(discount_percent)) |> Decimal.div(@hundred)
    subtotal = gross |> Decimal.sub(discount) |> Decimal.round(2)
    tax = subtotal |> Decimal.mult(dec(tax_percent)) |> Decimal.div(@hundred) |> Decimal.round(2)

    %{subtotal: subtotal, tax_amount: tax, total: Decimal.add(subtotal, tax)}
  end

  @doc "Sums `%{subtotal, tax_amount, total}` maps."
  def totals(lines) do
    Enum.reduce(lines, %{subtotal: @zero, tax_amount: @zero, total: @zero}, fn line, acc ->
      %{
        subtotal: Decimal.add(acc.subtotal, dec(line.subtotal)),
        tax_amount: Decimal.add(acc.tax_amount, dec(line.tax_amount)),
        total: Decimal.add(acc.total, dec(line.total))
      }
    end)
  end

  @doc "Lenient decimal cast for form input: blanks and garbage become 0."
  def dec(%Decimal{} = value), do: value
  def dec(value) when is_integer(value), do: Decimal.new(value)
  def dec(value) when is_float(value), do: Decimal.from_float(value)

  def dec(value) when is_binary(value) do
    case Decimal.parse(String.replace(value, ",", "")) do
      {decimal, ""} -> decimal
      _ -> @zero
    end
  end

  def dec(_value), do: @zero
end
