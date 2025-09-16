require 'time'
require 'date'

module DateParserHelper
  # Converts various date formats to Time object for database storage
  # Returns Time object or nil if unparseable
  #
  # Handles:
  # - nil values
  # - Unix timestamps (seconds, milliseconds, microseconds, nanoseconds)
  # - ISO 8601 strings (2023-01-15T10:30:00Z)
  # - Common date strings (2023-01-15, Jan 15 2023, etc.)
  # - Excel serial dates
  # - Relative formats ("yesterday", "tomorrow")
  # - Time and Date objects
  #
  # @param date_input [String, Integer, Float, Date, Time, nil] The date to parse
  # @return [Time, nil] Time object or nil
  def self.to_time(date_input)
    return nil if date_input.nil?

    # Handle empty strings
    if date_input.is_a?(String) && date_input.strip.empty?
      return nil
    end

    # Already a Time object
    if date_input.is_a?(Time)
      return date_input
    end

    # Date object
    if date_input.is_a?(Date)
      return date_input.to_time
    end

    # Numeric values (potential Unix timestamps)
    if date_input.is_a?(Numeric)
      return parse_numeric_timestamp(date_input)
    end

    # String parsing
    if date_input.is_a?(String)
      return parse_string_timestamp(date_input)
    end

    nil
  rescue StandardError => e
    # Log the error if you have logging set up
    # Rails.logger&.warn("Failed to parse date: #{date_input} - #{e.message}")
    nil
  end

  # Convenience method for getting Unix timestamp if needed
  # @param date_input [String, Integer, Float, Date, Time, nil] The date to parse
  # @return [Integer, nil] Unix timestamp or nil
  def self.to_unix_timestamp(date_input)
    time_obj = to_time(date_input)
    time_obj&.to_i
  end

  private

  # Parse numeric timestamps and return Time object
  def self.parse_numeric_timestamp(timestamp)
    timestamp = timestamp.to_f

    # Determine the scale based on the magnitude and convert directly to Time
    case timestamp
    when 0..9_999_999_999 # 1970-2286 (10 digits) - Unix seconds
      Time.at(timestamp)
    when 10_000_000_000..9_999_999_999_999 # 13 digits - Milliseconds
      Time.at(timestamp / 1000)
    when 10_000_000_000_000..9_999_999_999_999_999 # 16 digits - Microseconds
      Time.at(timestamp / 1_000_000)
    when 10_000_000_000_000_000..Float::INFINITY # 19+ digits - Nanoseconds
      Time.at(timestamp / 1_000_000_000)
    else
      # Handle negative timestamps (before 1970) or very small numbers
      if timestamp < 0 && timestamp > -2_147_483_648 # Valid Unix timestamp range
        Time.at(timestamp)
      elsif timestamp > 0 && timestamp < 10_000 # Might be Excel serial date
        parse_excel_serial_date(timestamp)
      else
        nil
      end
    end
  end

  # Parse string timestamps and return Time object
  def self.parse_string_timestamp(date_string)
    date_string = date_string.strip

    # Try parsing as a number first (string containing only digits)
    if date_string.match?(/^\d+(\.\d+)?$/)
      return parse_numeric_timestamp(date_string.to_f)
    end

    # Handle relative dates
    case date_string.downcase
    when 'now', 'today'
      return Time.now
    when 'yesterday'
      return Time.now - 86400
    when 'tomorrow'
      return Time.now + 86400
    end

    # Try various parsing methods in order of preference
    parsers = [
      -> { Time.parse(date_string) },           # Most flexible
      -> { DateTime.parse(date_string).to_time }, # Backup parser
      -> { Date.parse(date_string).to_time },   # Date only
      -> { parse_custom_formats(date_string) }  # Custom formats
    ]

    parsers.each do |parser|
      begin
        result = parser.call
        return result if result
      rescue StandardError
        # Try next parser
        next
      end
    end

    nil
  end

  # Handle custom date formats that might not parse automatically
  def self.parse_custom_formats(date_string)
    custom_formats = [
      '%Y-%m-%d %H:%M:%S',     # 2023-01-15 14:30:00
      '%Y/%m/%d %H:%M:%S',     # 2023/01/15 14:30:00
      '%m/%d/%Y %H:%M:%S',     # 01/15/2023 14:30:00
      '%d/%m/%Y %H:%M:%S',     # 15/01/2023 14:30:00
      '%Y-%m-%d',              # 2023-01-15
      '%Y/%m/%d',              # 2023/01/15
      '%m/%d/%Y',              # 01/15/2023
      '%d/%m/%Y',              # 15/01/2023
      '%Y%m%d',                # 20230115
      '%Y%m%d%H%M%S',          # 20230115143000
      '%a, %d %b %Y %H:%M:%S', # Mon, 15 Jan 2023 14:30:00
      '%d %b %Y',              # 15 Jan 2023
      '%b %d, %Y',             # Jan 15, 2023
    ]

    custom_formats.each do |format|
      begin
        return DateTime.strptime(date_string, format).to_time
      rescue ArgumentError, TypeError
        next
      end
    end

    nil
  end

  # Handle Excel serial dates (days since 1900-01-01) and return Time object
  def self.parse_excel_serial_date(serial_number)
    # Excel counts from 1900-01-01, but has a leap year bug
    # Days since 1900-01-01, accounting for the bug
    base_date = Date.new(1899, 12, 30) # Account for Excel's leap year bug
    date = base_date + serial_number.to_i
    date.to_time
  rescue StandardError
    nil
  end
end
