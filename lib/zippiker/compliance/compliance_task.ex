defmodule Zippiker.Compliance.ComplianceTask do
  @moduledoc """
  An obligation on the filing calendar: an annual return, a notice to the
  Registrar after a change, an AGM… with its due date, and when it was done
  (with the filing reference). Recurring ones carry a `period` so each is
  created once.
  """
  use Ash.Resource,
    otp_app: :zippiker,
    domain: Zippiker.Compliance,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    fragments: [
      Zippiker.Compliance.ComplianceTask.Attributes,
      Zippiker.Compliance.ComplianceTask.Relationships,
      Zippiker.Compliance.ComplianceTask.Actions,
      Zippiker.Compliance.Policies
    ]

  postgres do
    table "compliance_tasks"
    repo Zippiker.Repo

    references do
      reference :profile, on_delete: :delete
    end
  end

  multitenancy do
    strategy :context
  end

  identities do
    identity :one_per_period, [:profile_id, :period]
  end
end
