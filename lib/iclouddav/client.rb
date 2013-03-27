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
    attr_accessor :server, :port, :email, :password
    attr_reader :principal, :calendars

    DEFAULT_SERVER = "p01-caldav.icloud.com"

    def initialize(email, password, server = DEFAULT_SERVER)
      @email = email
      @password = password
      @server = server
      @port = 443

      @principal = fetch_principal
      @calendars = fetch_calendars
    end

    def propfind(url, headers = {}, xml)
      http_fetch(Net::HTTP::Propfind, url, headers, xml)
    end

    def report(url, headers = {}, xml)
      http_fetch(Net::HTTP::Report, url, headers, xml)
    end

    def fetch_calendar_data(url)
      xml = self.report(url, { "Depth" => 1 }, <<END
        <sync-collection xmlns="DAV:">
          <sync-token/>
          <prop>
            <getcontenttype/>
          </prop>
        </sync-collection>
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

      cal_datas = []
      hrefs.each do |href|
        xml = self.report(href, { "Depth" => 1 }, <<END
          <c:calendar-query xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:caldav">
            <d:prop>
              <d:getetag />
              <c:calendar-data />
            </d:prop>
            <c:filter>
              <c:comp-filter name="VCALENDAR" />
            </c:filter>
          </c:calendar-query>
END
          )

        cal_datas.push REXML::XPath.first(xml,
          "//multistatus/response/propstat/prop/calendar-data").text
      end

      cal_datas.join
    end

  private
    def http_fetch(req_type, url, headers = {}, data = nil)
      host = Net::HTTP.new(self.server, self.port)
      host.use_ssl = true
      host.verify_mode = OpenSSL::SSL::VERIFY_PEER
      #host.set_debug_output $stdout

      req = req_type.new(url)
      req.basic_auth self.email, self.password

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
      # this is supposed to propfind "calendar-home-set" but icloud doesn't seem
      # to support that, so we skip that lookup and hard-code to
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

        # assuming urls are unique and names might not be
        cals[name] = ICloudCalendar.new(self, path, name)
      end

      cals
    end
  end
end
