defmodule Project42Web.Project4 do
  @gvalue 4 #the difficulty of the mining problem

  def getip() do
    #get network info
    {:ok, ifx} = :inet.getif

    #extract ip from if
    ip = Enum.map(ifx, fn {ip,_,_} -> ip end)
    ip = Enum.at(ip, 0)

    #make sure ip is not local, if not fix it
    ip = if (ip == {127,0,0,1}) do
      #xtract 2nd arg
      ipx = Enum.map(ifx, fn {n,_,_} -> n end)
      Enum.at(ipx,1)
    else
      ip
    end

    iparr = Tuple.to_list(ip)
    #make string from ip values
    ipstr = Enum.join(iparr,".")

    #concatenate server name to ip string
    "serv@#{ipstr}"
  end

  def start_network(nodename) do
      unless Node.alive?() do
          try do
            ip = getip()
            serv = String.to_atom(nodename <> ip)
            Node.start(serv)
            Node.set_cookie(serv,:nom)
          rescue
            _ ->
            IO.puts "Offline mode (no net)"
          end
      end
  end

  #receives a list and formats it
  def format(gvalue,pid,block0) do
    [gvalue,0,[block0],pid]
  end

  #generate hash of a block
  def hashBlock(data) do
    data = Enum.join(data)
    :crypto.hash(:sha256, data) |> Base.encode16
  end

  #hash transaction data
  def hashTX(data) do
    data = Enum.join(data) <> rand()
    :crypto.hash(:sha256, data) |> Base.encode16 |> String.downcase
  end

  #returns initialization block
  def initBlock() do
    time = NaiveDateTime.utc_now
    {[],"","","",time,""}
  end

  #block =
  def genBlock(prev, utx) do
    prv_hash = elem(prev,1)
    [amt,to,from,sig,time] = utx
    hash = hashBlock(utx)
    txdata = [amt,to]
    {txdata,prv_hash,hash,sig,time,from}
  end

  #verify if hash meets requirements for bitcoin discovery
  def verify(hash,g) do
    if (String.slice(hash,0,g) == String.duplicate("0",g)) do
      true
    else
      false
    end
  end

  #generate random code
  def rand() do
    :crypto.strong_rand_bytes(9) |> Base.url_encode64 |>
    binary_part(0,9) |> String.downcase()
  end

  defmodule BlockChain do

    def check(hash, data, i) when i >= 0 do
      blk = Enum.at(data,i)
      other = elem(blk,2)
      if (other == hash) do
        true
      else
        check(hash,data,i-1)
      end
    end

    def check(_,_,_) do false end

    def loop(data) do
      receive do
        {:f_block, [pid, block]} ->
          send(pid, {:last_block, block})
          loop(data)

        {:add_block, utx} ->
          #check that it was completed first
          hash = Project42Web.Project4.hashBlock(utx)

          data = if (check(hash,data,length(data) - 1) == false) do
            block = Project42Web.Project4.genBlock(Enum.at(data,length(data)-1),utx)

            #print here
            IO.puts("New Block")
            IO.inspect(block)

            serv = :global.whereis_name(:serv)
            send(serv, {:incr})

            data ++ [block]
          else
            data
          end

          loop(data)
      end
    end

  end

  defmodule WalletObj do
    #create transaction data, send to server
    def genTransaction(amt, from, to, sig) do
      time = NaiveDateTime.utc_now
      [amt,to,from,sig,time]
    end

    #transaction process
    #1. send transaction data to network
    #2. a miner eventually solves transaction
    #3. miner turns it into a block
    #4. miner broadcasts block
    #5. block added to network blockchain

    def loop(serv, data) do
      receive do
        #begin a transaction
        {:makeTX, [to,mybalance]} ->
          {pub,pvt} = data
          #addr = Wallet.Addr.agen(pvt)
          sig = Wallet.Addr.gen(pvt, "message")
          utxo = genTransaction(mybalance, pub, to, sig)
          send(serv, {:add_utxo, utxo})
          loop(serv,data)

          #ask target for money
          {:relayTX, [target, iBal]} ->
            {_,pvt} = data
            addr = Wallet.Addr.agen(pvt)
            send(target, {:makeTX, [addr, iBal]})
            loop(serv,data)
      end
    end

  end

  defmodule Server do

    #set up server (initialization)
    def setup(gv, numWallets, numTX, iBal) do
      Project42Web.Project4.start_network("serv@")

      #initialize bitcoin stuff (blockchain, etc.)
      block0 = Project42Web.Project4.initBlock()

      #start master --gvalue can be replaced with a parameter as needed
      sid = spawn_link(fn() -> server_msg([gv,nil,nil,nil,nil],[0,0,numTX]) end)
      :global.register_name(:serv,sid)

      #init serverside miner supervisor
      {:ok, pid} = Task.Supervisor.start_link()

      #send supervisor id to host
      send(sid, {:set_super, pid})

      #Wallets
      blockid = spawn_link(fn() -> BlockChain.loop([block0]) end)
      wlist = for _ <- 1..numWallets do
        Task.Supervisor.async(pid, fn() ->
          WalletObj.loop(sid,Wallet.Key.gen()) end)
      end

      send(sid, {:set_chain, blockid})
      send(sid, {:set_wallets, wlist})

      #start mining task for nodes
      l = 2*System.schedulers_online()
      mlist = for _ <- 1..l do
        Task.Supervisor.async(pid,fn() -> mine(sid,Project42Web.Project4.format(gv,nil,blockid)) end)
      end
      Enum.each(mlist,fn(n)-> send(n.pid,{:mine}) end)

      send(sid, {:set_mlist, mlist})

      serv = :global.whereis_name(:serv)
      send(serv, {:initTX, [numTX, iBal]})

      wait(numTX,iBal)

      receive do: (_ -> :ok)
    end

    def wait(numTX,iBal) do
      serv = :global.whereis_name(:serv)
      send(serv, {:main,self()})

      receive do
        {:numtx, [n,x]} ->
          IO.puts("#{n} complete")
          if (n==x) do
            System.halt(0)
          else
            serv = :global.whereis_name(:serv)
            send(serv, {:initTX, [numTX,iBal]})
          end
      end

      wait(numTX,iBal)
    end

    def server_msg(data,params) do
      receive do
        #getters
        #setters
        {:initTX, [numTX, iBal]} ->
          w = Enum.at(data,3)

          for _ <- 1..2 do
          task = Enum.at(w,:rand.uniform( length(w)-1 ))
          task2 = Enum.at(w,:rand.uniform( length(w) - 1))
          send(task.pid, {:relayTX, [task2.pid,iBal]} )
          end

          server_msg(data,params)

        {:set_wallets, w} ->
          data = List.replace_at(data,3,w) #3
          server_msg(data,params)

        #set supervisor for reference
        {:set_super, pid} ->
          data = List.replace_at(data,1,pid)
          server_msg(data,params)

        {:set_chain, blockid} ->
          data = List.replace_at(data,2,blockid)
          server_msg(data,params)

        {:finished_block, utxo} ->
          #verify block
          pub1 = Enum.at(utxo,2)
          sig1 = Enum.at(utxo,3)
          Wallet.Addr.validate(pub1,sig1,"message")

          #send to blockchain
          chain = Enum.at(data,2)
          send(chain, {:add_block, utxo})

        {:set_mlist, m} ->
          data = List.replace_at(data,4,m) #4
          server_msg(data,params)

        {:add_utxo, utxo} ->
          miners = Enum.at(data,4)
          Enum.each(miners, fn(n)-> send(n.pid,{:get_utxo,utxo}) end)

        {:main,pid} ->
          data = data ++ [pid]
          server_msg(data,params)

        {:incr} ->
          x = Enum.at(params,1)
          tx = Enum.at(params,2)
          params = List.replace_at(params,1,x+1)
          main = Enum.at(data,length(data)-1)
          send(main,{:numtx,[x+1,tx]})
          server_msg(data,params)

        #if just receiving a message, only print if enabled
        str -> if (Enum.at(params,0) == 1) do IO.puts(str) end
      end
      server_msg(data,params)
    end

    #list [g,btc,block]
    def mine_utxo(serv,utxo,l) do
        hash = Project42Web.Project4.hashTX(utxo)
        if (Project42Web.Project4.verify(hash,4)) do
          send(serv,{:finished_block,utxo})
          mine(serv,l)
        else
          mine_utxo(serv,utxo,l)
        end
    end

    def mine_utxo_test(utxo) do
        hash = Project42Web.Project4.hashTX(utxo)
        if (Project42Web.Project4.verify(hash,4)) do
          hash
        else
          mine_utxo_test(utxo)
        end
    end

    def mine_utxo_test2(utxo) do
        hash = Project42Web.Project4.hashTX(utxo)
        if (Project42Web.Project4.verify(hash,4)) do
          utxo
        else
          mine_utxo_test2(utxo)
        end
    end

    def mine(serv, l) do
      receive do
        {:get_utxo, utxo} ->
          mine_utxo(serv,utxo,l)
          send(self(), {:mine})

        {:mine} ->
          g = Enum.at(l,0)
          btc = Enum.at(l,1)

          code = "x" <> Project42Web.Project4.rand()
          hash = :crypto.hash(:sha256, code) |> Base.encode16 |> String.downcase

          x = if (Project42Web.Project4.verify(hash,g)) do
            #found a bitcoin
            send(serv, code <> "\n" <> hash)
            1
          else
            0
          end

          #change value in list
          l = List.replace_at(l,1,btc + x)
          send(self(), {:mine})
          mine(serv,l)
      end

    end
  end

  #gvalue can be changed to parameter if needed
  defmodule Unit do

      def testx() do

        IO.puts("Generate genesis block")
          z = Project42Web.Project4.initBlock()
          x = elem(z,2) == ""
          IO.puts("#{x}")

        IO.puts("check if wallet generated key validates signature")
          #generate addresses (holds transaction records)
          {pub1,pvt1} = Wallet.Key.gen() #generate keypair for wallet1
          {pub2,pvt2} = Wallet.Key.gen() #generate keypair for wallet2

          #get address from private keys
          addr1 = Wallet.Addr.agen(pvt1)
          addr2 = Wallet.Addr.agen(pvt2)

          #transaction
          #digital signature from pvt key, receiver, and bitcoin value
          msg = "5"
          sig1 = Wallet.Addr.gen(pvt1, msg)

          #verify sig1 comes from pub1
          x = Wallet.Addr.validate(pub1,sig1,msg) == true
          IO.puts("#{x}")

         IO.puts("create private key and check if properly gets the public")
          {pub1,pvt1} = Wallet.Key.gen()

          pubx = Wallet.Key.pvt2pub(pvt1)

          x = pub1 == pubx
          IO.puts("#{x}")

          IO.puts("verify mining of block with a transaction (difficulty value of 4)")
          {pub1,pvt1} = Wallet.Key.gen()
          {pub2,pvt2} = Wallet.Key.gen()

          msg = "message"
          sig1 = Wallet.Addr.gen(pvt1, msg)
          to = Wallet.Addr.agen(pvt2)
          utxo = WalletObj.genTransaction(5, pub1, to, sig1)
          hash = Server.mine_utxo_test(utxo)
          x = (String.slice(hash,0,4) == String.duplicate("0",4))
          IO.puts("#{x}")

          IO.puts("verify block")
          {pub1,pvt1} = Wallet.Key.gen()
          {pub2,pvt2} = Wallet.Key.gen()

          msg = "message"
          sig1 = Wallet.Addr.gen(pvt1, msg)
          to = Wallet.Addr.agen(pvt2)
          utxo = WalletObj.genTransaction(5, pub1, to, sig1)
          utxo = Server.mine_utxo_test2(utxo)
          init = Project42Web.Project4.initBlock()
          block = Project42Web.Project4.genBlock(init,utxo)
          hashval = elem(block,2)
          x = hashval == Project42Web.Project4.hashBlock(utxo)
          IO.puts("#{x}")
      end
  end

  def start(_,_) do
      args = System.argv()

      if (length(args) == 0) do
        IO.puts("No args given, Performing test cases...")
        Unit.testx()
        IO.puts("finally generate a block chain of 3
        transactions\n(genesis block not shown)")
        Server.setup(@gvalue, 3,3,3)
      else
      [numWallets, numTX, iBal] = args
      Server.setup(@gvalue, numWallets, numTX, iBal)
      end

      {:ok,self()}
  end

end
