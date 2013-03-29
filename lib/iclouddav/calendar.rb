require "ri_cal"
require "date"

module ICloud
  class Calendar
    attr_reader :client, :path, :name, :ical, :ical_data

    def initialize(client, path, name)
      @client = client
      @path = path
      @name = name
    end

    def ical
      @ical ||= RiCal.parse_string(self.ical_data).first
    end

    def to_remind
      out = ""

      ical.events.each do |ev|
        start = ev.dtstart.to_time.getlocal
        finish = ev.dtend.to_time.getlocal

        out << "REM "

        # remind doesn't support * operator for months or years, so rather than
        # repeat those below, we repeat them here by omitting the month and
        # year (monthly) or year to let remind repeat them
        if ev.rrule.any? && ev.rrule_property[0].freq == "MONTHLY"
          out << start.strftime("%-d %Y")
        elsif ev.rrule.any? && ev.rrule_property[0].freq == "YEARLY"
          out << start.strftime("%b %-d")
        else
          out << start.strftime("%b %-d %Y")
        end

        # to repeat events, remind needs an end date
        if ev.bounded?
          last = ev.occurrences.last.dtend

          if start.strftime("%Y%m%d") != last.strftime("%Y%m%d")
            out << " UNTIL " << last.strftime("%b %-d %Y")
          end

          # TODO: even if it's not bounded, we can manually repeat it in the
          # remind file for a reasonable duration, assuming we're getting
          # rebuilt every so often
        end

        if ev.rrule.any?
          # rrule_property
          # => [:FREQ=MONTHLY;UNTIL=20110511;INTERVAL=2;BYMONTHDAY=12]

          interval = ev.rrule_property.first.interval.to_i
          case ev.rrule_property.first.freq
          when "DAILY"
            out << " *#{interval}"
          when "WEEKLY"
            out << " *#{interval * 7}"
          when "MONTHLY", "YEARLY"
            # handled above
          else
            STDERR.puts "need to support #{ev.rrule_property.first.freq} freq"
          end
        end

        if ev.dtstart.class == DateTime
          out << " AT " << start.strftime("%H:%M")

          if (secs = finish.to_i - start.to_i) > 0
            hours = secs / 3600
            mins = (secs - (hours * 3600)) / 60
            out << " DURATION #{hours}:#{mins}"
          end
        end

        if ev.alarms.any? &&
        m = ev.alarms.first.trigger.match(/^([-\+])PT?(\d+)([WDHMS])/)
          tr_mins = m[2].to_i
          tr_mins *= case m[3]
            when "W"
              60 * 60 * 24 * 7
            when "D"
              60 * 60 * 24
            when "H"
              60 * 60
            when "S"
              (1.0 / 60)
            else
              1
            end

          tr_mins = tr_mins.ceil

          # remind only supports advance warning in days, so if it's smaller
          # than that, don't bother
          if tr_mins >= (60 * 60 * 24)
            days = tr_mins / (60 * 60 * 24)

            # remind syntax is flipped
            if m[1] == "-"
              out << " +#{days}"
            else
              out << " -#{days}"
            end
          end
        end

        out << " MSG "

        # show date, time, and location outside of %" quotes so that clients
        # like tkremind don't also include them on their default view

        # Monday the 1st
        out << "%w the %d%s"

        # at 12:34
        if ev.dtstart.class == DateTime
          out << " %3"
        end

        out << ": %\"" << ev.summary.gsub("%", "%%") << "%\""

        if ev.location.present?
          out << " (at " << ev.location << ")"
        end

        # suppress extra blank line
        out << "%\n"
      end

      out
    end

    def url
      "https://#{self.client.caldav_server}:#{self.client.port}#{path}"
    end

    def ical_data
      # try to combine all separate calendars into one by removing VCALENDAR
      # headers
      @ical_data ||= "BEGIN:VCALENDAR\n" <<
        self.client.fetch_calendar_data(self.path).split("\n").map{|line|
          if line.strip == "BEGIN:VCALENDAR" || line.strip == "END:VCALENDAR"
            next
          else
            line + "\n"
          end
        }.join <<
      "END:VCALENDAR\n"

      @ical_data
    end
  end
end
