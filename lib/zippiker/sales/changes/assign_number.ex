defmodule Zippiker.Sales.Changes.AssignNumber do
  @moduledoc """
  Allocates the document number from the legal entity's sequence inside the
  action's transaction. `document_type: :quote | :invoice | …`; quotes and
  invoices use the legal entity's prefixes, others pass `prefix:`. Options
  `number_field:` (default `:number`) and `yearly?: false` (one running
  sequence, `EMP-0042`).
  """
  use Ash.Resource.Change

  @impl true
  def change(changeset, opts, _context) do
    Ash.Changeset.before_action(changeset, fn changeset ->
      field = Keyword.get(opts, :number_field, :number)

      if Ash.Changeset.get_attribute(changeset, field) do
        changeset
      else
        tenant_opts = [tenant: changeset.tenant, authorize?: false]
        entity_id = Ash.Changeset.get_attribute(changeset, :legal_entity_id)
        entity = Zippiker.Accounts.get_legal_entity!(entity_id, tenant_opts)
        type = Keyword.fetch!(opts, :document_type)

        prefix =
          case type do
            :invoice -> entity.invoice_prefix
            :quote -> entity.quote_prefix
            _other -> Keyword.fetch!(opts, :prefix)
          end

        number =
          Zippiker.Accounts.next_document_number!(
            entity_id,
            type,
            prefix,
            %{yearly?: Keyword.get(opts, :yearly?, true)},
            tenant_opts
          )

        Ash.Changeset.force_change_attribute(changeset, field, number)
      end
    end)
  end
end
