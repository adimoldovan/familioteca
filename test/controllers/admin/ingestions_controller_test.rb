require "test_helper"

class Admin::IngestionsControllerTest < ActionDispatch::IntegrationTest
  test "unauthenticated visitor is redirected to sign_in" do
    post admin_ingestions_path
    assert_redirected_to sign_in_path
  end

  test "non-admin gets 404" do
    sign_in_as members(:ana)
    post admin_ingestions_path
    assert_response :not_found
  end

  test "admin enqueues IngestBookJob and gets turbo stream replacing the button" do
    sign_in_as members(:admin)
    assert_enqueued_with(job: IngestBookJob) do
      post admin_ingestions_path, headers: { "Accept" => "text/vnd.turbo-stream.html" }
    end
    assert_response :success
    assert_select "turbo-stream[action='replace'][target='admin-scan-button']" do
      assert_select ".scan-button__status", text: I18n.t("admin.ingestions.scanning")
    end
  end

  test "admin html fallback redirects with queued notice" do
    sign_in_as members(:admin)
    assert_enqueued_with(job: IngestBookJob) do
      post admin_ingestions_path
    end
    assert_redirected_to admin_members_path
    assert_equal I18n.t("admin.ingestions.queued"), flash[:notice]
  end
end
