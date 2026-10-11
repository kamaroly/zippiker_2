defmodule Zippiker.HR.Workers.RunAccruals do
  @moduledoc "Daily (Oban cron): credits leave accruals in every workspace with HR switched on."
  use Oban.Worker, queue: :hr, max_attempts: 3

  @impl Oban.Worker
  def perform(%Oban.Job{args: args}) do
    as_of = if date = args["as_of"], do: Date.from_iso8601!(date), else: Date.utc_today()

    for organization <- Zippiker.HR.Workers.workspaces() do
      Zippiker.HR.run_leave_accruals!(%{as_of: as_of}, tenant: organization, authorize?: false)
    end

    :ok
  end
end
