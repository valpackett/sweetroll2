defmodule Sweetroll2.Repo.Migrations.AddDocs do
  use Ecto.Migration

  def change do
    create table("docs", primary_key: false) do
      add :url, :text, null: false, primary_key: true
      add :type, :text, null: false
      add :deleted, :boolean, null: false, default: false
      add :published, :utc_datetime
      add :acl, {:array, :text}, null: false, default: "{*}"
      add :props, :map, null: false
      add :children, {:array, :map}
      add :tsv, :tsvector
    end

    create constraint("docs", "url_must_be_http_or_relative",
      check: "ascii(url) = 47 OR starts_with(url, 'https://') OR starts_with(url, 'http://')")

    create index("docs", ["url text_pattern_ops"], where: "ascii(url) = 47")
    create index("docs", [:published], where: "ascii(url) = 47")
    create index("docs", [:tsv], using: "GIN")

    execute "
      CREATE FUNCTION docs_set_tsv() RETURNS trigger AS $$
      BEGIN
        NEW.tsv :=
           setweight(to_tsvector(NEW.props->>'name'), 'A')
        || setweight(to_tsvector(coalesce(NEW.props->'summary'->>'markdown',
            NEW.props->'summary'->>'text', NEW.props->'summary'->>'html', NEW.props->>'summary')), 'B')
        || setweight(to_tsvector(coalesce(NEW.props->'content'->>'markdown',
            NEW.props->'content'->>'text', NEW.props->'content'->>'html', NEW.props->>'content')), 'B')
        ;
        RETURN NEW;
      END
      $$ LANGUAGE plpgsql;
    ", "
      DROP FUNCTION docs_set_tsv;
    "

    execute "
      CREATE TRIGGER docs_set_tsv_trigger
      BEFORE INSERT OR UPDATE ON docs
      FOR EACH ROW EXECUTE PROCEDURE docs_set_tsv();
    ", "
      DROP TRIGGER docs_set_tsv_trigger ON docs;
    "
  end
end
