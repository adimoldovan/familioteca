require "test_helper"

class SeedsTest < ActiveSupport::TestCase
  test "seeds creates one admin member when run on an empty database" do
    Member.delete_all
    load Rails.root.join("db/seeds.rb")
    admin = Member.find_by!(admin: true)
    assert_equal 1, Member.where(admin: true).count
    assert admin.authenticate("changeme123")
  end

  test "seeds is idempotent" do
    Member.delete_all
    load Rails.root.join("db/seeds.rb")
    load Rails.root.join("db/seeds.rb")
    assert_equal 1, Member.where(admin: true).count
  end
end
