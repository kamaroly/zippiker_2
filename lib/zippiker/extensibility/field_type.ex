defmodule Zippiker.Extensibility.FieldType do
  @moduledoc "The kinds of value a custom field can hold."
  use Ash.Type.Enum,
    values: [
      text: [label: "Short text"],
      long_text: [label: "Long text"],
      number: [label: "Number"],
      boolean: [label: "Yes / No"],
      date: [label: "Date"],
      select: [label: "Dropdown"],
      multi_select: [label: "Multi-select"],
      url: [label: "URL"],
      email: [label: "Email"]
    ]

  @doc "Types whose values come from the definition's `options` list."
  def with_options, do: [:select, :multi_select]
end
