defmodule Zippiker.Accounting.Ledger do
  @moduledoc """
  Posting rules, exposed as generic actions. Other modules call these from
  their own actions (in the same transaction), e.g. issuing an invoice runs
  `post_invoice`. Every posting is idempotent per source document.

  | Event                   | Debit                                   | Credit                     |
  |-------------------------|-----------------------------------------|----------------------------|
  | Invoice issued          | Accounts receivable                     | Sales revenue, Tax payable |
  | Payment received        | Cash / Bank / Mobile money              | Accounts receivable        |
  | Goods received (PO)     | Inventory                               | Goods received not billed  |
  | Goods delivered         | Cost of sales                           | Inventory                  |
  | Stock adjusted (+ / −)  | Inventory / Inventory adjustments       | the other one              |
  | Bill approved           | GRNI (PO goods), Inventory (other goods), expense accounts, Input tax | Accounts payable |
  | Bill paid               | Accounts payable                        | Cash / Bank / Mobile money |

  Voids, removed payments and reversed stock operations reverse the original entry.
  Price differences between a purchase order and its bill go to cost of sales.
  """
  use Ash.Resource,
    otp_app: :zippiker,
    domain: Zippiker.Accounting,
    authorizers: [Ash.Policy.Authorizer],
    fragments: [Zippiker.Accounting.Ledger.Actions, Zippiker.Accounting.Ledger.Policies]
end
