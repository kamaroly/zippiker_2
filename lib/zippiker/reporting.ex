defmodule Zippiker.Reporting do
  @moduledoc """
  The report center: every standard report (business overview, receivables,
  payables, sales, inventory, tax, employees, accountant) behind two generic
  actions. Reports read the other domains' data; they never write.
  """
  use Ash.Domain, otp_app: :zippiker, extensions: [AshAdmin.Domain]

  admin do
    show? true
  end

  resources do
    resource Zippiker.Reporting.Report do
      define :report_catalog, action: :catalog
      define :run_report, action: :run, args: [:key]
    end
  end
end
