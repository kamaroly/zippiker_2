defmodule Zippiker.Platform.Reports do
  @moduledoc "Super admin headline numbers, exposed as a generic action."
  use Ash.Resource,
    otp_app: :zippiker,
    domain: Zippiker.Platform,
    authorizers: [Ash.Policy.Authorizer],
    fragments: [Zippiker.Platform.Reports.Actions, Zippiker.Platform.Reports.Policies]
end
