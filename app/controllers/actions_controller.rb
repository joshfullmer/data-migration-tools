require 'smarter_csv'
require 'zip'
require 'fileutils'

class ActionsController < ApplicationController

	def attachments
		#Captures Relationship and Attachments files
	end

	def file_upload

		appname = params[:appname]
		filepath = "#{Rails.root}/public/uploads/#{appname}"
		#Initializes Infusionsoft instance
		Infusionsoft.configure do |config|
			config.api_url = "#{appname}.infusionsoft.com"
			config.api_key = params[:apikey]
		end

		#Saves relationship file to local memory
		@uploaded_file = params[:attachments]
		@filename = "#{appname} - " + @uploaded_file.original_filename
		File.open(Rails.root.join('public', 'uploads', @filename), 'wb') do |file|
			file.write(@uploaded_file.read)
		end

		#Stores uploaded CSV as an array of hashes
		@attachments = SmarterCSV.process(Rails.root.join("public", "uploads", @filename).to_s)

		#Stores uploaded ZIP into uploads folder for access
		@uploaded_directory = params[:files]
		zipfilename = @uploaded_directory.original_filename.split('.')[0]
		File.open(Rails.root.join('public', 'uploads', @uploaded_directory.original_filename), 'wb') do |file|
			file.write(@uploaded_directory.read)
		end

		#Create folder for ZIP extraction
		FileUtils::mkdir_p "#{filepath}/#{zipfilename}"

		#Extract uploaded ZIP into created folder
		Zip::File.open(Rails.root.join("public", "uploads", @uploaded_directory.original_filename).to_s, 'wb') do |zipfile|
			zipfile.each do |file|
				zipfile.extract(file,"#{filepath}/#{file.name}")
			end
		end

		#Attach all items in zipfile to assigned contacts based on the uploaded CSV
		@attachments.each do |row|
			file_contents = File.read("#{filepath}/#{zipfilename}/#{row[:filepath]}")
			encoded_contents = Base64.encode64(file_contents)
			Infusionsoft.file_upload(row[:id],"#{row[:filename]}",encoded_contents)
		end

	end
end