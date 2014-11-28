module YARS

export yars_start, yars_send_reset, yars_send_quit, yars_send_message
export yars_send_actuator_commands, yars_read_sensors

function print_yars(st)
  while true
    print(readline(st))
  end
end


#function yars_start(working_dir::String, xml_file::String, options::Vector{ASCIIString})
function yars_start(working_dir::String, options::Vector{ASCIIString})
  current_dir = pwd()
  cd("$working_dir")
  st = []
  pr = []
  (st, pr) = open(`yars $options`,"r")
  s = "ABC"
  while ismatch(r"port",s) == false && length(s) > 0
    s = readline(st)
  end
  if length(s) == 0
    println("error opening yars")
    exit(-1)
  end
  s    = split(s)
  port = int(s[4])
  println("opened yars on port ", port)
  cd("$current_dir")
  sleep(1)
  hd = connect(port)
  sleep(1)
  r = @spawn print_yars(st)
  return hd
end
start(working_dir::String, options::Vector{ASCIIString}) = yars_start(working_dir, options)


function bytes_of_size_int(i::Int64)
  [(i >> (j * 8)) & 0xFF for j=0:3]
end

#= function int_of_str(v::Vector{Uint8}) =#
  #= o = 0 =#
  #= for i=0:3 =#
    #= o += (v[i+1] << (i*8)) =#
  #= end =#
  #= return o =#
#= end =#


function yars_send_string(hd, str::String)
  c = bytes_of_size_int(length(str))
  s = vcat(convert(Vector{Uint8}, ['s']),
           convert(Vector{Uint8}, c),
           convert(Vector{Uint8}, str))
  write(hd, s)
end
send_string(hd, str::String) = yars_send_string(hd, str)

function yars_send_reset(hd)
  yars_send_string(hd, "RESET")
end
reset(hd) = yars_send_reset(hd)

function yars_send_quit(hd)
  yars_send_string(hd, "QUIT")
end
quit(hd) = yars_send_quit(hd)

function yars_send_message(hd, str)
  yars_send_string(hd, "MESSAGE")
  yars_send_string(hd, str)
end
message(hd, str) = yars_send_message(hd, str)

function yars_read_sensors(hd)
  s = []
  yars_send_string(hd, "SENSORS")
  s = readbytes(hd, 1)
  s = convert(Char, s[1])
  if s != 'D'
    println("expected 'D' but received '", s, "'")
  end
  nr = read(hd,Int32)
  data = zeros(nr)
  for i=1:nr
    data[i] = read(hd, Float64)
  end
  data
end
sensors(hd) = yars_read_sensors(hd)

function yars_send_actuator_commands(hd, mv::Vector{Float64})
  c = bytes_of_size_int(length(mv))
  s = vcat(convert(Vector{Uint8}, ['D']), convert(Vector{Uint8}, c))
  yars_send_string(hd, "ACTUATORS")
  write(hd,s)
  for f in mv
    write(hd, f)
  end
end
actuators(hd, mv) = yars_send_actuator_commands(hd, mv)

end # module
