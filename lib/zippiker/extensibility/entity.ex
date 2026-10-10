defmodule Zippiker.Extensibility.Entity do
  @moduledoc """
  Every record type that can carry custom fields. Add a value here and
  `custom_fields do entity :value end` on the resource to make it extensible.
  """
  use Ash.Type.Enum,
    values: [
      person: [label: "Contacts"],
      organization: [label: "Companies"],
      lead: [label: "Leads"],
      deal: [label: "Deals"],
      product: [label: "Products"],
      quote: [label: "Quotes"],
      invoice: [label: "Invoices"],
      employee: [label: "Employees"]
    ]
end
