require "test_helper"

class RackAttackTest < ActionDispatch::IntegrationTest
  setup do
    @original_cache_store = Rack::Attack.cache.store
    Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new
    Rack::Attack.enabled = true
  end

  teardown do
    Rack::Attack.enabled = false
    Rack::Attack.cache.store = @original_cache_store
  end

  test "11th failed login from the same IP is throttled" do
    10.times do |i|
      post session_path, params: { email: "ana@example.com", password: "wrong#{i}" },
        env: { "REMOTE_ADDR" => "203.0.113.42" }
      assert_response :unprocessable_entity, "attempt #{i + 1} should not be throttled"
    end

    post session_path, params: { email: "ana@example.com", password: "wrong_final" },
      env: { "REMOTE_ADDR" => "203.0.113.42" }
    assert_response :too_many_requests
    assert_equal "Prea multe încercări. Așteaptă 10 minute.", response.body
    assert response.headers["Retry-After"].to_i.positive?
  end

  test "different IPs are tracked independently" do
    10.times do
      post session_path, params: { email: "ana@example.com", password: "wrong" },
        env: { "REMOTE_ADDR" => "203.0.113.42" }
    end

    post session_path, params: { email: "ana@example.com", password: "wrong" },
      env: { "REMOTE_ADDR" => "203.0.113.99" }
    assert_response :unprocessable_entity
  end
end
