defmodule Zippiker.HR.Workers.ReviewOverdueLeave do
  @moduledoc "Hourly (Oban cron): applies policies' overdue actions to unreviewed leave requests."
  use Oban.Worker, queue: :hr, max_attempts: 3

  @impl Oban.Worker
  def perform(_job) do
    for organization <- Zippiker.HR.Workers.workspaces() do
      Zippiker.HR.review_overdue_leave!(%{}, tenant: organization, authorize?: false)
    end

    :ok
  end
end
