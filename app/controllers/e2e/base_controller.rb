module E2e
  class BaseController < ApplicationController
    allow_unauthenticated_access
    skip_forgery_protection

    before_action :guard_env

    private

    # Defense-in-depth: the route constraint in config/routes.rb already
    # prevents these actions from being reachable outside e2e, so this guard
    # should never fire. Kept in case the route is ever exposed by mistake.
    def guard_env
      head :not_found unless Rails.env.e2e?
    end
  end
end
