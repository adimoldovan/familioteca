class SessionsController < ApplicationController
  allow_unauthenticated_access only: %i[new create]

  def new
    head :ok
  end

  def create
    head :ok
  end

  def destroy
    head :ok
  end
end
