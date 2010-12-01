#!/usr/bin/env ruby -w
require 'csv'

class NotAvailable < StandardError; end

class Property
  attr_accessor :id, :lat, :lng, :nightly_price

  def initialize(attributes = {})
    attributes.each_pair do |key, value|
      self.send("#{key}=", value) if self.respond_to?("#{key}=")
    end
  end

  # t is for target
  def distance_from(tlat, tlng)
    [@lat - tlat, @lng - tlng]
  end

  # given target coordinates, returns the maximum distance in either dimension
  def max_distance_from(tlat, tlng)
    distance_from(tlat, tlng).map{|d| d.abs}.max
  end
end

calendar = {}
# Build the index
CSV.foreach("calendar.csv") do |row|
  # Initializing local variables is inefficient but more readable.
  # Removing them would be premature, at this point.
  available = (row[2] == "1" ? true : false)
  property_id = row[0].to_i
  date = Date.parse(row[1])
  price = (row[3] ? row[3].to_i : nil)
  calendar[property_id] ||= {}
  calendar[property_id][date] = {:available => available, :price => price}
end
calendar.freeze

properties = []
CSV.foreach("properties.csv") do |row|
  # Initializing local variables is inefficient but more readable.
  # Removing them would be premature, at this point.
  id = row[0].to_i
  lat = row[1].to_f
  lng = row[2].to_f
  nightly_price = row[3].to_i
  properties << Property.new(:id => id, :lat => lat, :lng => lng, :nightly_price => nightly_price)
end
properties.freeze

CSV.open("search_results.csv", "w") do |csv|
  CSV.foreach("searches.csv") do |search|
    search_id = search[0].to_i
    tlat = search[1].to_f
    tlng = search[2].to_f
    checkin = Date.parse(search[3])
    checkout = Date.parse(search[4])
    search_results = []
    properties.each do |property|
      next if property.max_distance_from(tlat, tlng) > 1.0
      total_price = 0
      begin
        checkin.upto([checkin, checkout - 1].max) do |date|
          if calendar[property.id] && calendar[property.id][date]
            raise NotAvailable if calendar[property.id][date][:available] == false
            total_price += calendar[property.id][date][:price]
          else
            # Default to nightly price if there's no date-specific price
            total_price += property.nightly_price
          end
        end
        search_results << [search_id, property.id, total_price]
      rescue NotAvailable
      end
    end

    search_results.sort!{|x, y| x[2] <=> y[2]}
    search_results.slice(0..9).each_with_index do |search_result, index|
      # Set the correct rank (zero-indexed)
      search_result.insert(1, index)
      csv << search_result
    end
  end
end
