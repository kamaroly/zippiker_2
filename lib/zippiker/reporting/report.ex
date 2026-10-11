defmodule Zippiker.Reporting.Report do
  @moduledoc "Standard reports, listed and run through generic actions."
  use Ash.Resource,
    otp_app: :zippiker,
    domain: Zippiker.Reporting,
    authorizers: [Ash.Policy.Authorizer],
    fragments: [Zippiker.Reporting.Report.Actions, Zippiker.Reporting.Report.Policies]
end
