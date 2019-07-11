defmodule Wallet do

def append(a,b) do a <> b end

#file i/o
defmodule WFile do

  #need to have functions to save wallet info to disk

  #get a dictionary on disk, open it, turn it into a list of strings
  def get_file_text(str) do
    dir = :code.priv_dir(:project4)
    dir = Path.join(dir, str)
    fstream = File.stream!(dir) |> Stream.map(&String.trim/1)
    Enum.to_list(fstream)
  end

  #save wallet file
  def fout(pvt, pub, dir, fd) do
    fp = Path.join(dir, fd)

      #check if new directory must be made
      result = File.mkdir_p(dir)

      if (result == :ok) do
        result = File.write(fp, pvt) #name private key

        #check if write succesful
        if (result == :ok) do
          File.write("#{fp}.pub", pub) #add public key
        else
          "failed to write file"
        end
      else
        "failed to make directory"
      end #end outer if
  end #end out

  #open wallet file
  def fin(dir, fd) do
    fp = Path.join(dir, fd)

    {:ok, pvt} = File.read(fp)
    {:ok, pub} = File.read("#{fp}.pub")

    {pvt, pub} #return private, public key pair
  end #end in

  #delete files in directory !!!careful
  def delete(dir) do
    with {:ok, f} <- File.rm_rf(dir) do
      f
    else
      {:error, msg, _f} -> output(msg)
    end
  end

  defp output(e), do: :file.format_error(e)

end #end file io

#public and private key generation
defmodule Key do

def gen, do: :crypto.generate_key(:ecdh, :secp256k1)

def genkey() do #generate keypair
  with {pub, pvt} <- :crypto.generate_key(:ecdh, :secp256k1),
  do: {Base.encode16(pub), Base.encode16(pvt)}
  end

defp genkey(pvt) do
  with {pub, _pvt} <- :crypto.generate_key(:ecdh, :secp256k1, pvt),
  do: pub
  end

def pvt2pub(pvt) do #generate public key from private
  x = String.valid?(pvt)
  result = if (x) do Base.decode16!(pvt) else pvt end
  genkey(result)
end

end #end key\

#encryption standard funcs for hashing
defmodule Encrypt do

 #main hash func
  def hash(pub) do
    sh_pk = :crypto.hash(:sha256, pub)
    :crypto.hash(:ripemd160, sh_pk)
  end

  def do_sha512(key \\ "Bitcoin seed", data), do: :crypto.hmac(:sha512, key, data)

    #---code to create seed---#

    #expects phrase and password
    def gen(nem, pw \\ "") do
      pw |> salt() |> init(nem) |> do_pbk(nem) |> enc()
    end

    defp salt(pw), do: "nem" <> pw

    #after 'salting' start first part
    defp init(sd, nem), do: do_sha512(nem, <<sd::binary, 1::integer-32>>)

    defp do_pbk(init, nem), do: it(nem, 2, init, init)

    defp it(_nem, rnd, _prev, res) when rnd > 2048, do: res

    defp it(nem, rnd, prev, res) do
      with next = do_sha512(nem, prev),
      do: it(nem, rnd + 1, next, :crypto.exor(next, res))
    end

    defp enc(res), do: Base.encode16(res, case: :lower)

end #end Encrypt

#make the address / sig of wallet
defmodule Addr do
  @versionid %{
    main: <<0x00>>,
    test: <<0x6F>>
  }

  #generate address from pvt key
  def agen(pvt, net \\ :main) do
    pvt |> Key.pvt2pub() |> Encrypt.hash() |> prepend_vb(net) |> Wallet.Util.validate_enc()
  end

  #adds version byte to end of hash
  defp prepend_vb(pubh, net) do
    @versionid |> Map.get(net) |> Kernel.<>(pubh)
  end

  #generate signature
  @spec gen(binary, String.t()) :: String.t()
  def gen(pvt, msg),
  do: :crypto.sign(:ecdsa, :sha256, msg, [pvt, :secp256k1])

  #check correctness of signature
  @spec validate(binary, binary, String.t()) :: boolean
  def validate(pub, sig, msg) do
    :crypto.verify(:ecdsa, :sha256, msg, sig, [pub, :secp256k1])
  end

end #end address

#utilities for preparing sigs
defmodule Util do
  def validate_enc(i) do i |> validate_f() |> enc_f() end

  def validate_f(h) do
    vh1 = :crypto.hash(:sha256, h)
    vh1 = :crypto.hash(:sha256, vh1)
    csm(vh1) |> Wallet.append(h)
  end

  defp csm(<<csm::bytes-size(4), _::bits>>), do: csm

  def enc_f(input, collect \\ "")
  def enc_f(0, collect), do: collect
  def enc_f(input, collect)
    when is_binary(input) do
      input |> :binary.decode_unsigned() |> enc_f(collect) |> addzero(input)
     end
  def enc_f(input, collect) do
    input |> div(58) |> enc_f(hash_ext(input,collect))
  end

  defp hash_ext(input, collect) do
    "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz" |>
    String.at(rem(input, 58)) |> Wallet.append(collect)
  end

  #add zeros to the beginning of collected string
  defp addzero(collect, input) do
    input |> encz |> Wallet.append(collect)
  end

  #encode by getting index of 0s in front and copying them
  defp encz(input) do
    input |> frontz() |> dupzero()
  end

  #get index of 0s in front
  defp frontz(input) do
    input |> :binary.bin_to_list() |> Enum.find_index(&(&1 != 0))
  end

  #gets first character in encryption alphabet and duplicates it n times
  defp dupzero(n) do
    "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz" |>
    String.first() |> String.duplicate(n)
  end
end #end util


#special phrase needed for getting back a wallet (mnemonic)
defmodule Nem do
  def gen(len) do
    if (len in [128, 160, 192, 224, 256]) do len else {:error, "bad length"} end
  end

  #---basic procedure---#
  #convert from ent data to nem
  def e2n(bin) do
    n = norm(bin)
    n = append_data(n)
    nem(n)
  end

  #convert from nem to ent data
  def n2e(nem) do
    bin = idx(nem)
    bin = bindata(bin)
    ent(bin)
  end

  #get length of data and append it to the end
  def append_data(bin) do
    bin |> cs() |> combine(bin)
  end

  #find size of ent data
  defp cs(ent) do
    with size = cs_len(ent),
    enc = :crypto.hash(:sha256, ent),
    <<cs::bits-size(size), _::bits>> <- enc, do: cs
  end

  #joins 2 words together
  defp combine(cs, ent), do: <<ent::bits, cs::bits>>

  #make the phrase
  defp nem(ent) do
    partitions(ent) |> Enum.join(" ")
  end

  #combine a bunch of words from a dictionary
  def partitions(ent) do
    dict = WFile.get_file_text("dictionary.txt")
    for <<partition::11 <- ent>> do Enum.at(dict, partition) end
  end

  #split into individual strings and map them to position in file
  defp idx(nem) do String.split(nem) |> Enum.map(&dict_idx/1) end
  #find location of string in file
  defp dict_idx(w), do:
  Enum.find_index(WFile.get_file_text("dictionary.txt"), &(&1==w))

  #bit strings of size 11 for every ix in i
  defp bindata(i) do
    for ix <- i, into: <<>> do <<ix::11>> end
  end

  defp ent(hash) do
    with sz = ent_len(hash),
    <<ent::bits-size(sz), _::bits>> <- hash,
    do: ent
    end

  #length of ent data
  defp ent_len(h) do
    sz = bit_size(h)
    byte_sz = sz*32 #might need to use lib here?
    div(byte_sz,33)
  end
  #---end basic procedure layout---#


  #main thing here \/

  #generates random bits
  def rand(len) do
    w = div(len, 8) #convert to bytes
    :crypto.strong_rand_bytes(w)
  end

  #length of bin (binary data)
  def cs_len(bin) do
    bit_size(bin) |> div(32)
  end

  #check if binary data is formatted properly, format it if not
  def norm(bin) do
    x = String.valid?(bin)
    if (x) do
      Base.decode16!(bin, case: :mixed)
    else
      bin
    end
  end

end #end Nem

#internal test cases
def test1() do
  #generate addresses (holds transaction records)
  {pub1,pvt1} = Key.gen() #generate keypair for wallet1
  {pub2,pvt2} = Key.gen() #generate keypair for wallet2

  #get address from private keys
  addr1 = Addr.agen(pvt1)
  addr2 = Addr.agen(pvt2)

  #transaction
  #digital signature from pvt key, receiver, and bitcoin value
  msg = "5"
  sig1 = Addr.gen(pvt1, msg)

  #verify sig1 comes from pub1
  abc = Addr.validate(pub1,sig1,msg)
  IO.puts("#{abc}")
end

end
