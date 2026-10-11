defmodule Zippiker.Accounts.DocumentStyle do
  @moduledoc """
  How a legal entity's printed documents look: layout, accent colour,
  font, logo size, what to show, and per-document-type titles, terms and
  footers (`templates`). Stored on the legal entity.
  """
  use Ash.Resource,
    data_layer: :embedded,
    fragments: [Zippiker.Accounts.DocumentStyle.Attributes]
end
