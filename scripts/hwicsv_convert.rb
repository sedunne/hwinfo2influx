## hwicsv_convert
## Convert hwinfo-created CSV logs to a format that can be imported into InfluxDB.
##
## NOTE: make sure you remove any characters that might mess with the encoding. In my case, working with the data on macos at least, I had to remove the degree
##  symbol from the csv files, otherwise you'll get encoding errors on load
## In my case, I had to use `LANG=C tr -d '\260' < file.csv` to remove the symbols from the file.
## Also, hwinfo apparently includes a CSV footer, so we need to yeet the last couple lines of that to make the conversions we do easier.
require 'csv'
require 'date'

## open output file, and process our input
fixed = CSV.open('output', 'wb', :headers => true, :return_headers => true)

## load input csv and convert the headers to all lowercase
csv = CSV.table(ARGV[0], :headers => true, :header_converters => lambda { |h| h.to_s.downcase.gsub(' ', '_')})
headers = csv.headers

## write the headers out. ruby csv can do this natively, but I'm probably dumb and it wasn't working well so I just manually do it
discard_columns = ['date']
header_row = headers.delete_if { |h| discard_columns.include?(h) }
fixed << header_row

## because hwinfo csv logging will create duplicate columns, we have to reference them by their index instead, since matching by header would only return
##  the first match. In this case, we just want to convert these yes/no fields to 1 or 0. ultimately there should be better duplicate field handling,
##  since effectively all the data for duplicated points will end up being incorrect right now
csv.each_with_index do |row, i|
  ## merge date and time columns, and yeet the date column
  row['time'] = "#{row['date']} #{row['time']}"
  row.delete('date')

  ## convert the time field to rfc3339 (mostly for influxdb compatibility)
  row['time'] = DateTime.strptime("#{row['time']} -0400", '%d.%m.%Y %H:%M:%S.%L %z').rfc3339

  ## convert yes/no to puesdo-bool, then it and everything else into a float. there may be actual reasons to do this (eg performance of float vs int in influxdb),
  ##  but this is mostly just to heavy handedly convert everything to something useable
  row.each_with_index do |column, i|
    h,f = column[0], column[1]
    next if h == 'time'
    if f.to_s.match(/Yes|No/)
      row[i] = f.to_s.length == 3 ? f = 1.0 : f = 0.0
    else
      row[i] = f.to_s.to_f
    end
  end
  fixed << row
end
