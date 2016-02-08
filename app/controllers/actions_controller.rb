require 'smarter_csv'

class ActionsController < ApplicationController

	def file_upload

		#Initializes Infusionsoft instance
		Infusionsoft.configure do |config|
			config.api_url = "qj154.infusionsoft.com"
			config.api_key = "1979978dc08730f121747d50003c8513"
		end

		@csv = SmarterCSV.process('C:\Users\josh.fullmer\Desktop\Attachments.csv')

		uploaded_file = params[:attachments]

=begin
		@csv.each do |row|
			file_contents = File.read("C:\\Users\\josh.fullmer\\Desktop\\File Upload Test\\#{row[:filename]}")
			encoded_contents = Base64.encode64(file_contents)
			Infusionsoft.file_upload(row[:id],"#{row[:filename]}",encoded_contents)
		end
=end

	end
end
