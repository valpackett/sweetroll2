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
           setweight(props->'name', 'A')
        || setweight(coalesce(props->'summary'->>'markdown', props->'summary'->>'text', props->'summary'->>'html', props->>'summary'), 'B')
        || setweight(coalesce(props->'content'->>'markdown', props->'content'->>'text', props->'content'->>'html', props->>'content'), 'B')
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
