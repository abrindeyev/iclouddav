require "net/https"
require "rexml/document"

module Net
  class HTTP
    class Report < HTTPRequest
      METHOD = "REPORT"
      REQUEST_HAS_BODY = true
      RESPONSE_HAS_BODY = true
    end
  end
end

module ICloud
  class Client
    attr_accessor :server, :port, :email, :password, :debug
    attr_reader :principal, :calendars

    DEFAULT_SERVER = "p01-caldav.icloud.com"

    def initialize(email, password, server = DEFAULT_SERVER)
      @email = email
      @password = password
      @server = server
      @port = 443

      @debug = false
      @_http_cons = {}
    end

    def principal
      @principal ||= fetch_principal
    end

    def calendars
      @calendars ||= fetch_calendars
    end

    def get(url, headers = {})
      http_fetch(Net::HTTP::Get, url, headers)
    end

    def propfind(url, headers = {}, xml)
      http_fetch(Net::HTTP::Propfind, url, headers, xml)
    end

    def report(url, headers = {}, xml)
      http_fetch(Net::HTTP::Report, url, headers, xml)
    end

    def fetch_calendar_data(url)
      xml = self.report(url, { "Depth" => 1 }, <<END
        <d:sync-collection xmlns:d="DAV:">
          <d:sync-token/>
          <d:prop>
            <d:getcontenttype/>
          </d:prop>
        </d:sync-collection>
END
        )

      # gather the separate .ics urls for each event in this calendar
      hrefs = []
      REXML::XPath.each(xml, "//response") do |resp|
        href = resp.elements["href"].text
        if href.present?
          hrefs.push href
        end
      end

      # bundle them all in one multiget
      xml = self.report(url, { "Depth" => 1 }, <<END
        <c:calendar-multiget xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:caldav">
          <d:prop>
            <c:calendar-data />
          </d:prop>
          <c:filter>
            <c:comp-filter name="VCALENDAR" />
          </c:filter>
          #{hrefs.map{|h| '<d:href>' << h << '</d:href>'}.join}
        </c:calendar-multiget>
END
        )

      REXML::XPath.each(xml,
        "//multistatus/response/propstat/prop/calendar-data").map{|e| e.text }.
        join
    end

  private
    def http_fetch(req_type, url, headers = {}, data = nil)
      # keep the connection alive since we're probably sending all requests to
      # it anyway and we'll gain some speed by not reconnecting every time
      if !(host = @_http_cons["#{self.server}:#{self.port}"])
        host = Net::HTTP.new(self.server, self.port)
        host.use_ssl = true
        host.verify_mode = OpenSSL::SSL::VERIFY_PEER

        if self.debug
          host.set_debug_output $stdout
        end

        # if we don't call start ourselves, host.request will, but it will do
        # it in a block that will call finish when exiting request, closing the
        # connection even though we're specifying keep-alive
        host.start

        @_http_cons["#{self.server}:#{self.port}"] = host
      end

      req = req_type.new(url)
      req.basic_auth self.email, self.password

      req["Connection"] = "keep-alive"
      req["Content-Type"] = "text/xml; charset=\"UTF-8\""

      headers.each do |k,v|
        req[k] = v
      end

      if data
        req.body = data
      end

      res = host.request(req)
      REXML::Document.new(res.body)
    end

    def fetch_principal
      xml = self.propfind("/", { "Depth" => 1 },
        '<d:propfind xmlns:d="DAV:"><d:prop><d:current-user-principal />' <<
        '</d:prop></d:propfind>')

      REXML::XPath.first(xml,
        "//response/propstat/prop/current-user-principal/href").text
    end

    def fetch_calendars
      # this is supposed to propfind "calendar-home-set" but icloud doesn't
      # seem to support that, so we skip that lookup and hard-code to
      # "/[principal user id]/calendars/" which is what calendar-home-set would
      # probably return anyway

      xml = self.propfind("/#{self.principal.split("/")[1]}/calendars/",
        { "Depth" => 1 }, '<d:propfind xmlns:d="DAV:"><d:prop>' <<
        '<d:displayname/></d:prop></d:propfind>')

      cals = {}

      REXML::XPath.each(xml, "//multistatus/response") do |cal|
        path = cal.elements["href"].text
        name = cal.elements["propstat"].elements["prop"].
          elements["displayname"].text

        cals[name] = Calendar.new(self, path, name)
      end

      cals
    end
  end
end
