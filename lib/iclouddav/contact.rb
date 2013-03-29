require "vcard"
require "date"

module ICloud
  class Contact
    attr_reader :client, :vcard_data

    def initialize(client, vcard_data)
      @client = client
      @vcard_data = vcard_data
    end

    def vcard
      @vcard ||= Vcard::Vcard.decode(self.vcard_data).first
    end

    def name
      vcard.name.fullname
    end

    def email
      vcard.email
    end

    def address
      vcard.address
    end
  end
end
