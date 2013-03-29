##iclouddav
A Ruby library for interacting with iCloud's CalDAV/CardDAV services.

Requires the `ri_cal` Ruby module for iCal parsing.
Requires the `vcard` Ruby module for vCard parsing.

###Current Status
Completed functionality:
- Fetching the list of calendars
- Fetching iCal data for each calendar
- iCal-to-[Remind](http://www.roaringpenguin.com/products/remind) conversion
- Fetching vCards for each contact

TODO:
- Figure out why external calendars (like subscribed US Holidays) are listed but have no `sync-collection` hrefs
- Some vCards on CardDAV server are there twice but with different UIDs; should these be eliminated?
- Remind-to-iCal sync back
- Tests

###Example

A short example of fetching the list of calendars and writing out remind(1) calendar files for each one:

    require './lib/iclouddav'

    client = ICloud::Client.new("user@example.com", "password")
    client.calendars.each do |cal|
      next if !(remind = cal.to_remind).present?

      File.write("" << ENV["HOME"] << "/.calendars/" <<
        cal.name.gsub(/[^A-Za-z0-9]/, "_") << ".rem", "BANNER %\n" << remind)
    end

Writing out a mutt-style aliases file for each contact with an e-mail address:

    contacts = {}
	client.contacts.each do |contact|
      next if !contact.email.present?

      key = contact.name.gsub(/[^A-Za-z]/, "")
      try = nil
      while contacts["#{key}#{try}"]
        try = (try ? try + 1 : 2)
      end
      contacts["#{key}#{try}"] = "#{contact.name} <#{contact.email}>"
    end

    File.write("" << ENV["HOME"] << "/.aliases",
      contacts.map{|k,v| "#{k} #{v}" }.join("\n"))

###License

3-clause BSD.
