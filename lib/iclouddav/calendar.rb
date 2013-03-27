module ICloud
  class Calendar
    attr_reader :client, :path, :name

    def initialize(client, path, name)
      @client = client
      @path = path
      @name = name
    end

    def data
      self.client.fetch_calendar_data(self.path)
    end

    def url
      "https://#{self.client.server}:443#{path}"
    end
  end
end
