defmodule Zippiker.Crm.Dashboard do
  @moduledoc "Read-only CRM reporting, exposed as generic actions."
  use Ash.Resource,
    otp_app: :zippiker,
    domain: Zippiker.Crm,
    authorizers: [Ash.Policy.Authorizer],
    fragments: [Zippiker.Crm.Dashboard.Actions, Zippiker.Crm.Dashboard.Policies]
end
