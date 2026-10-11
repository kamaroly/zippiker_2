# Team schemas are pre-built once (see Zippiker.TenantPool) before the
# sandbox takes over.
Zippiker.TenantPool.setup!()

ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(Zippiker.Repo, :manual)
