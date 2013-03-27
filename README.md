##iclouddav
A Ruby library for interacting with iCloud's CalDAV/CardDAV services.

Requires the `ri_cal` Ruby module for iCal parsing.

###Current Status
Completed functionality:
- Fetching the list of calendars
- Fetching iCal data for each calendar
- iCal-to-[Remind](http://www.roaringpenguin.com/products/remind) conversion

TODO:
- Figure out why external calendars (like subscribed US Holidays) are listed but have no `sync-collection` hrefs
- Remind-to-iCal syncing
- CardDAV functionality to export names and e-mail addresses to a mutt-style aliases file

###Example

A short example of fetching the list of calendars and writing out remind(1) calendar files for each one:

    require './lib/iclouddav'

    client = ICloud::Client.new("user@example.com", "password")
    client.calendars.each do |name,cal|
      if (remind = cal.to_remind).present?
        File.write("" << ENV["HOME"] << "/.calendars/" <<
          name.gsub(/[^A-Za-z0-9]/, "_") << ".rem", "BANNER %\n" << remind)
      end
    end

###License

3-clause BSD.
