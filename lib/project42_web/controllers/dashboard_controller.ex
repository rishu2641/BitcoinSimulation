defmodule Project42Web.DashboardController do

  use Project42Web, :controller

  def dashboard(conn,  %{"numWallets" => numWallets,"numTX" => numTX, "iBal" => iBal}) do

    numWallets = String.to_integer(numWallets)
    numTX = String.to_integer(numTX)
    iBal = String.to_integer(iBal)

    out = Project42Web.Project4.Server.setup(4, numWallets, numTX, iBal)

    render(conn, "dashboard.html")

   end

   def index(conn,  _params) do
    render(conn, "dashboard.html")
   end




end
