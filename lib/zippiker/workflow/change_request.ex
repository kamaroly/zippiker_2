defmodule Zippiker.Workflow.ChangeRequest do
  @moduledoc """
  A change held for approval under maker-checker: which record, which
  action, the input to replay, and a before/after diff. It goes through
  the workflow engine (`:change_request`); once approved it's applied as
  the maker (applied, or failed with the reason), rejected otherwise.
  """
  use Ash.Resource,
    otp_app: :zippiker,
    domain: Zippiker.Workflow,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    fragments: [
      Zippiker.Workflow.ChangeRequest.Attributes,
      Zippiker.Workflow.ChangeRequest.Relationships,
      Zippiker.Workflow.ChangeRequest.Actions,
      Zippiker.Workflow.ChangeRequest.Policies
    ]

  postgres do
    table "change_requests"
    repo Zippiker.Repo

    references do
      reference :legal_entity, on_delete: :restrict
      reference :approval_request, on_delete: :nilify
    end

    custom_indexes do
      index [:status]
    end
  end

  multitenancy do
    strategy :context
  end
end
