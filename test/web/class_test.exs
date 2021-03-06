defmodule Web.ClassTest do
  use Data.ModelCase

  alias Data.ClassSkill
  alias Web.Class

  test "creating a class" do
    params = %{
      "name" => "Fighter",
      "description" => "A fighter",
      "regen_health_points" => 1,
      "regen_skill_points" => 1,
      "each_level_stats" => base_stats() |> Poison.encode!(),
    }

    {:ok, class} = Class.create(params)

    assert class.name == "Fighter"
    assert class.each_level_stats.health_points == 50
  end

  test "updating a class" do
    class = create_class(%{name: "Fighter"})

    {:ok, class} = Class.update(class.id, %{name: "Barbarian"})

    assert class.name == "Barbarian"
  end

  describe "class skills" do
    setup do
      %{class: create_class(), skill: create_skill()}
    end

    test "adding skills to a class", %{class: class, skill: skill} do
      assert {:ok, %ClassSkill{}} = Class.add_skill(class, skill.id)
    end

    test "delete a skill from a class", %{class: class, skill: skill} do
      {:ok, class_skill} = Class.add_skill(class, skill.id)

      assert {:ok, _} = Class.remove_skill(class_skill.id)
    end
  end
end
