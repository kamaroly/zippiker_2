defmodule Zippiker.Platform.AuditEvent do
  @moduledoc """
  Append-only log of sensitive platform actions: impersonation, workspace
  access by super admins, plan and module changes, plan requests.
  """
  use Ash.Resource,
    otp_app: :zippiker,
    domain: Zippiker.Platform,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    fragments: [
      Zippiker.Platform.AuditEvent.Attributes,
      Zippiker.Platform.AuditEvent.Relationships,
      Zippiker.Platform.AuditEvent.Actions,
      Zippiker.Platform.AuditEvent.Policies
    ]

  postgres do
    table "platform_audit_events"
    repo Zippiker.Repo

    references do
      reference :actor, on_delete: :nilify
      reference :organization, on_delete: :nilify
      reference :target_user, on_delete: :nilify
    end
  end
end
