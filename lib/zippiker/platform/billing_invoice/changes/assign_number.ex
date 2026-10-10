defmodule Zippiker.Platform.BillingInvoice.Changes.AssignNumber do
  @moduledoc """
  Takes the next value of the global `billing_invoice_numbers` sequence
  (gaps are fine for platform invoices).
  """
  use Ash.Resource.Change

  @impl true
  def change(%{valid?: false} = changeset, _opts, _context), do: changeset

  def change(changeset, _opts, _context) do
    %{rows: [[next]]} = Zippiker.Repo.query!("SELECT nextval('billing_invoice_numbers')")
    number = "ZPK-" <> (next |> Integer.to_string() |> String.pad_leading(6, "0"))
    Ash.Changeset.force_change_attribute(changeset, :number, number)
  end
end
