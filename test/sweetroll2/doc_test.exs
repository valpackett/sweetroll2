defmodule Sweetroll2.DocTest do
  use ExUnit.Case, async: true
  alias Sweetroll2.Doc
  doctest Sweetroll2.Doc

  describe "matches_filter?" do
    test "true when matches" do
      assert Doc.matches_filter?(%Doc{props: %{"category" => "test", "x" => "y"}}, %{
               "category" => "test"
             })

      assert Doc.matches_filter?(%Doc{props: %{"category" => "test", "x" => "y"}}, %{
               "category" => ["test"]
             })

      assert Doc.matches_filter?(%Doc{props: %{"category" => ["test"], "x" => "y"}}, %{
               "category" => "test"
             })

      assert Doc.matches_filter?(%Doc{props: %{"category" => ["test"], "x" => "y"}}, %{
               "category" => ["test"]
             })
    end

    test "false when doesn't match" do
      assert not Doc.matches_filter?(%Doc{props: %{"category" => [], "x" => "y"}}, %{
               "category" => "test"
             })

      assert not Doc.matches_filter?(%Doc{props: %{"category" => [], "x" => "y"}}, %{
               "category" => ["test"]
             })

      assert not Doc.matches_filter?(%Doc{props: %{"x" => "y"}}, %{"category" => "test"})
      assert not Doc.matches_filter?(%Doc{props: %{"x" => "y"}}, %{"category" => ["test"]})
    end
  end
end
