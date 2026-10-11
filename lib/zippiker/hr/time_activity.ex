defmodule Zippiker.HR.TimeActivity do
  @moduledoc """
  Time an employee worked: a date, hours and a pay type, optionally for a
  customer and a deal (project). Billable time carries an hourly rate and
  counts as unbilled until it is linked to an invoice.
  """
  use Ash.Resource,
    otp_app: :zippiker,
    domain: Zippiker.HR,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    fragments: [
      Zippiker.HR.TimeActivity.Attributes,
      Zippiker.HR.TimeActivity.Relationships,
      Zippiker.HR.TimeActivity.Actions,
      Zippiker.HR.TimeActivity.Policies
    ]

  postgres do
    table "time_activities"
    repo Zippiker.Repo

    references do
      reference :employee, on_delete: :delete
      reference :customer, on_delete: :nilify
      reference :deal, on_delete: :nilify
      reference :product, on_delete: :nilify
      reference :invoice, on_delete: :nilify
    end

    custom_indexes do
      index [:date]
      index [:employee_id, :date]
    end
  end

  multitenancy do
    strategy :context
  end
end
