defmodule Zippiker.TenantPool do
  @moduledoc """
  Pre-built team schemas for tests. Building a schema runs every tenant
  migration (seconds), so tests check one out instead: each test's data is
  rolled back by the SQL sandbox, leaving the schema empty for the next
  test. Schemas return to the pool when the process that took them exits.
  Enabled with `config :zippiker, :tenant_pool, Zippiker.TenantPool`.
  """
  use GenServer

  @size 80

  @doc "Builds (or migrates) the pool schemas, outside the sandbox. Call from test_helper."
  def setup! do
    schemas = for n <- 1..@size, do: "test_pool_#{String.pad_leading("#{n}", 3, "0")}"
    # One short-lived process per schema: in sandbox auto mode a process
    # keeps its connection until it exits.
    Enum.each(schemas, fn schema ->
      Task.async(fn -> Zippiker.Accounts.Tenant.migrate!(schema) end) |> Task.await(:infinity)
    end)

    {:ok, _pid} = GenServer.start_link(__MODULE__, schemas, name: __MODULE__)
    :ok
  end

  @doc "A free schema for the calling process (waits if all are taken)."
  def checkout, do: GenServer.call(__MODULE__, {:checkout, self()}, :infinity)

  @impl true
  def init(schemas), do: {:ok, %{free: schemas, held: %{}, waiting: :queue.new()}}

  @impl true
  def handle_call({:checkout, pid}, from, state) do
    case state.free do
      [schema | rest] -> {:reply, schema, hold(%{state | free: rest}, pid, schema)}
      [] -> {:noreply, %{state | waiting: :queue.in({from, pid}, state.waiting)}}
    end
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    {schemas, held} = Map.pop(state.held, pid, [])
    state = Enum.reduce(schemas, %{state | held: held}, &release/2)
    {:noreply, state}
  end

  defp hold(state, pid, schema) do
    unless Map.has_key?(state.held, pid), do: Process.monitor(pid)
    %{state | held: Map.update(state.held, pid, [schema], &[schema | &1])}
  end

  defp release(schema, state) do
    case :queue.out(state.waiting) do
      {{:value, {from, pid}}, waiting} ->
        GenServer.reply(from, schema)
        hold(%{state | waiting: waiting}, pid, schema)

      {:empty, _} ->
        %{state | free: [schema | state.free]}
    end
  end
end
