defmodule Zippiker.Portal.Documents do
  @moduledoc "Portal actions (no table): reads and responses on a party's own documents."
  use Ash.Resource,
    otp_app: :zippiker,
    domain: Zippiker.Portal,
    fragments: [Zippiker.Portal.Documents.Actions]
end
