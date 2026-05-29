defmodule TeslaMate.Repo.Migrations.AddCarIdDateIndexToPositions do
  use Ecto.Migration

  # CREATE INDEX CONCURRENTLY must run outside a transaction and without the
  # migration lock so concurrent writes on the (potentially huge) positions
  # table keep flowing.
  @disable_ddl_transaction true
  @disable_migration_lock true

  def change do
    # `get_latest_position(%Car{id: id})` does
    #   SELECT ... FROM positions WHERE car_id = $1 ORDER BY date DESC LIMIT 1
    # which is called once per car on Vehicle start. The existing indexes are
    # either single-column (car_id) — leading to a sort over millions of rows
    # per car — or a partial (car_id, date) one gated by
    # `WHERE ideal_battery_range_km IS NOT NULL`, which the planner cannot
    # use for this query. On large fleets (e.g. 36 cars, 100M+ positions)
    # this falls back to a parallel seq scan, taking 30+ seconds per call
    # and saturating the buffer pool when every car boots at once.
    create index(:positions, [:car_id, :date], concurrently: true)
  end
end
