defmodule Project42Web.Router do
  use Project42Web, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", Project42Web do
    pipe_through :browser
    get "/", DashboardController, :index

    get "/dashboard", DashboardController, :dashboard
    get "/dashboard/:numWallets/:numTX/:iBal", DashboardController, :dashboard

  end

  # Other scopes may use custom stacks.
  # scope "/api", Project42Web do
  #   pipe_through :api
  # end
end
