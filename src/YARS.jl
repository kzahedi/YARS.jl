module YARS

export yars_start, yars_send_reset, yars_send_quit, yars_send_message
export yars_send_actuator_commands, yars_read_sensors

export yars_read_float,  yars_send_float
export yars_read_string, yars_send_string
export yars_read_int,    yars_send_int

export yars_read_float_vector, yars_send_float_vector
export yars_read_int_vector,   yars_send_int_vector

function print_yars(st)
  while true
    print(readline(st))
  end
end

###########################################################################
#                        basic data types - float                         #
###########################################################################

function yars_send_float_vector(hd, mv::Vector{Float64})
  c = bytes_of_size_int(length(mv))
  s = vcat(convert(Vector{Uint8}, ['D']), convert(Vector{Uint8}, c))
  write(hd,s)
  for f in mv
    write(hd, f)
  end
end
send_float_vector(hd, mv) = yars_send_float_vector(hd, mv)

function yars_read_float_vector(hd)
  s = []
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
read_float_vector(hd) = yars_read_float_vector(hd)

function yars_send_float(hd, value::Float64)
  write(hd, value)
end
send_float(hd, value) = yars_send_float(hd, value)

function yars_read_float(hd)
  read(hd, Float64)
end
read_float(hd) = yars_read_float(hd)

###########################################################################
#                         basic data types - int                          #
###########################################################################

function yars_send_int_vector(hd, mv::Vector{Int64})
  c = bytes_of_size_int(length(mv))
  s = vcat(convert(Vector{Uint8}, ['D']), convert(Vector{Uint8}, c))
  write(hd,s)
  for f in mv
    write(hd, f)
  end
end
send_int_vector(hd, mv) = yars_send_int_vector(hd, mv)

function yars_read_int_vector(hd)
  s = []
  s = readbytes(hd, 1)
  s = convert(Char, s[1])
  if s != 'D'
    println("expected 'D' but received '", s, "'")
  end
  nr = read(hd,Int32)
  data = zeros(nr)
  for i=1:nr
    data[i] = read(hd, Int64)
  end
  data
end
read_int_vector(hd) = yars_read_int_vector(hd)

function yars_send_int(hd, value::Int64)
  write(hd, value)
end
send_int(hd, value) = yars_send_int(hd, value)

function yars_read_int(hd)
  read(hd, Int64)
end
read_int(hd) = yars_read_int(hd)

###########################################################################
#                         communication functions                         #
###########################################################################

function yars_start(working_dir::String, options::Vector{ASCIIString})
  hd = nothing
  pr = nothing
  opened = false
  while opened == false
    try
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
      port = int(s[end])
      cd("$current_dir")
      sleep(1)
      hd = connect(port)
      sleep(1)
      r = @spawn print_yars(st)
      opened = true
    catch
      opened = false
    end
  end
  return hd, pr
end
start(working_dir::String, options::Vector{ASCIIString}) = yars_start(working_dir, options)

function bytes_of_size_int(i::Int64)
  [(i >> (j * 8)) & 0xFF for j=0:3]
end

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
  yars_send_string(hd, "SENSORS")
  yars_read_float_vector(hd)
end
sensors(hd) = yars_read_sensors(hd)

function yars_send_actuator_commands(hd, mv::Vector{Float64})
  yars_send_string(hd, "ACTUATORS")
  yars_send_float_vector(hd, mv)
end
actuators(hd, mv) = yars_send_actuator_commands(hd, mv)

function yars_read_string(hd)
  s = readbytes(hd, 1)
  s = convert(Char, s[1])
  if s != 's'
    println("expected 's' but received '", s, "'")
  end
  nr = read(hd,Int32)
  r = ""
  for i = 1:nr
    r = string(r, read(hd, Char))
  end
  return r
end
read_string(hd) = yars_read_string(hd)

type Entity
  name::String
  dimension::Int64
  internal::Vector{(Float64, Float64)}
  external::Vector{(Float64, Float64)}
end

type Robot
  sensors::Vector{Entity}
  actuators::Vector{Entity}
  sensor_dim::Int64
  actuator_dim::Int64
end

function parse_configuration_strings(strings::Array{ASCIIString,1})

  sensors   = []
  actuators = []

  current   = nothing

  for str in strings
    if contains(str, "BEGIN SENSOR") || contains(str, "BEGIN ACTUATOR")
      current = Entity("", 0, [(0.0, 0.0)], [(0.0, 0.0)])
    end

    if contains(str, "END SENSOR")
      sensors = [sensors, current]
      current = nothing
    end

    if contains(str, "END ACTUATOR")
      actuators = [actuators, current]
      current   = nothing
    end

    if contains(str,"NAME") && current != nothing
      current.name = strip(str[5:end])
    end

    if contains(str,"DIMENSION") && current != nothing
      values            = split(str)
      current.dimension = int64(values[2])
    end

    if contains(str,"INTERNAL DOMAIN")
      values           = split(str)
      v1               = float(values[end-1])
      v2               = float(values[end])
      current.internal = [current.internal, (v1, v2)]
    end

    if contains(str,"EXTERNAL DOMAIN")
      values           = split(str)
      v1               = float(values[end-1])
      v2               = float(values[end])
      current.external = [current.external, (v1, v2)]
    end
  end

  s = 0
  for sen in sensors
    s = s + sen.dimension
  end

  a = 0
  for act in actuators
    a = a + act.dimension
  end

  return Robot(sensors, actuators, s, a)
end

function yars_get_configuration(hd)
  configuration_strings = []
  yars_send_string(hd, "CONFIGURATION")
  s = ""
  while s != "END CONFIGURATION"
    s = yars_read_string(hd)
    configuration_strings = [configuration_strings, s]
  end
  return parse_configuration_strings(configuration_strings)
end
configuration(hd) = yars_get_configuration(hd)

end # module
