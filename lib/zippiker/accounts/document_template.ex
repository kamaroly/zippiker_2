defmodule Zippiker.Accounts.DocumentTemplate do
  @moduledoc """
  One document type's wording: its title (e.g. "Tax invoice", "LPO"), terms
  printed under the lines, and a footer. Blank fields use the defaults.
  """
  use Ash.Resource,
    data_layer: :embedded,
    fragments: [Zippiker.Accounts.DocumentTemplate.Attributes]

  @kinds [
    :quote,
    :sales_order,
    :invoice,
    :delivery_note,
    :rfq,
    :purchase_order,
    :goods_receipt,
    :stock_note,
    :job_card
  ]

  def kinds, do: @kinds
end
