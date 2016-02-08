require "fields_arrays.rb"
require "base64"

class AddContactController < ApplicationController

	def AddContact
		Infusionsoft.configure do |config|
			config.api_url = "qj154.infusionsoft.com"
			config.api_key = "1979978dc08730f121747d50003c8513"
		end

		@custom_fields = []
		@custom_fields += Infusionsoft.data_query("DataFormField",1000,0,{},DATAFORMFIELD_FIELDS)

		page_index = 0
		@contacts = []
		while true do
			contact_page = Infusionsoft.data_query("Contact",1000,page_index,{},CONTACT_FIELDS)
			@contacts += contact_page
			break if contact_page.length < 1000
			page_index += 1
		end

		file_contents = File.read('C:\Users\josh.fullmer\Downloads\notes.csv')

		encoded_contents = Base64.encode64(file_contents)

		Infusionsoft.file_upload(4,"notes.csv",encoded_contents)

	end

end
