defmodule Zippiker.Compliance.StatutoryDocument do
  @moduledoc """
  A statutory document kept on file: certificate of incorporation, articles,
  CR12, filing receipts, signed minutes, share certificates…
  """
  use Ash.Resource,
    otp_app: :zippiker,
    domain: Zippiker.Compliance,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    fragments: [
      Zippiker.Compliance.StatutoryDocument.Attributes,
      Zippiker.Compliance.StatutoryDocument.Relationships,
      Zippiker.Compliance.StatutoryDocument.Actions,
      Zippiker.Compliance.Policies
    ]

  postgres do
    table "statutory_documents"
    repo Zippiker.Repo

    references do
      reference :profile, on_delete: :delete
      reference :uploaded_by, on_delete: :nilify
    end
  end

  multitenancy do
    strategy :context
  end
end
