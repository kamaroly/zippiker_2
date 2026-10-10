defmodule Zippiker.Sales.Changes.PriceLine do
  @moduledoc """
  Snapshots the tax rate percentage on a document line and computes its
  subtotal, tax and total. Shared by quote and invoice lines.
  """
  use Ash.Resource.Change

  alias Zippiker.Sales.Pricing

  @impl true
  def change(changeset, _opts, _context) do
    changeset = snapshot_tax(changeset)
    get = &Ash.Changeset.get_attribute(changeset, &1)

    amounts =
      Pricing.line(
        get.(:quantity),
        get.(:unit_price),
        get.(:discount_percent),
        get.(:tax_percent)
      )

    Ash.Changeset.force_change_attributes(changeset, amounts)
  end

  defp snapshot_tax(changeset) do
    if Ash.Changeset.changing_attribute?(changeset, :tax_rate_id) do
      percent =
        case Ash.Changeset.get_attribute(changeset, :tax_rate_id) do
          nil ->
            Decimal.new(0)

          id ->
            case Zippiker.Catalog.get_tax_rate(id, tenant: changeset.tenant, authorize?: false) do
              {:ok, rate} -> rate.rate
              _ -> Ash.Changeset.get_attribute(changeset, :tax_percent) || Decimal.new(0)
            end
        end

      Ash.Changeset.force_change_attribute(changeset, :tax_percent, percent)
    else
      changeset
    end
  end
end
