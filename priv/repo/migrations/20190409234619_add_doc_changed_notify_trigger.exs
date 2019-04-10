defmodule Sweetroll2.Repo.Migrations.AddDocChangedNotifyTrigger do
  use Ecto.Migration

  def change do
    execute "
      CREATE FUNCTION docs_notify() RETURNS trigger AS $$
      BEGIN
        PERFORM pg_notify('doc_changed', NEW.url);
        RETURN NULL;
      END
      $$ LANGUAGE plpgsql;
    ", "
      DROP FUNCTION docs_notify;
    "

    execute "
      CREATE TRIGGER docs_notify_trigger
      BEFORE INSERT OR UPDATE ON docs
      FOR EACH ROW EXECUTE PROCEDURE docs_notify();
    ", "
      DROP TRIGGER docs_notify_trigger ON docs;
    "
  end
end
