require 'smarter_csv'
require 'zip'
require 'fileutils'
require 'fields_arrays.rb'
require 'base64'
require 'uri'
require 'net/http'
require 'net/https'
require 'basecamp'
require 'closeIO'
require 'json_converter'

class ActionsController < ApplicationController

	def api_test
		initialize_infusionsoft("mj303",MJ303_APIKEY)


	end

	def delete_actions
		initialize_infusionsoft("mj303",MJ303_APIKEY)

		delete_table('Contact')
		delete_table('ContactAction')
		delete_table('Lead')
		delete_table('ProductInterest')

	end

	def attachments
		#Captures Relationship and Attachments files
	end

	def attachments_no_zip
		#Captures relationship CSV and Attachment folder name
	end

	def all_records

		#Generate list of all Infusionsoft tables to create dropdown for user input
		#Key is added twice, once for the value of the option, twice for the name of the selection (for ease of use in Rails)
		@tables = []
		FIELDS.each do |key,value|
			table = []
			table << key
			table << key
			@tables << table
		end

	end

	def get_records
		#Store the user input table name in @tablename for display on the view
		@tablename = params[:tablename]

		#Initializes Infusionsoft instance
		initialize_infusionsoft(params[:appname], params[:apikey])

		#Stores all of the data in array called @data for display on the view
		@data = get_table(params[:tablename])

	end

	def file_upload

		appname = params[:appname]
		filepath = "#{Rails.root}/public/uploads/#{appname}"

		#Initializes Infusionsoft instance
		initialize_infusionsoft(appname,params[:apikey])

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
				zipfile.extract(file,"#{filepath}/#{file.name}") {true}
			end
		end

		#Attach all items in zipfile to assigned contacts based on the uploaded CSV
		@attachments.each do |row|
			Infusionsoft.file_upload(row[:id],"#{row[:filename]}",Base64.encode64(File.open("#{filepath}/#{zipfilename}/#{row[:filepath]}", "rb").read))
		end

	end

	def file_upload_no_zip

		#set variables
		appname = params[:appname]
		filepath = "#{Rails.root}/public/uploads/#{appname}"

		#Initializes Infusionsoft instance
		initialize_infusionsoft(appname,params[:apikey])

		#Saves relationship file to local memory
		@uploaded_file = params[:attachments]
		@filename = "{appname} - " + @uploaded_file.original_filename
		File.open(Rails.root.join('public', 'uploads', @filename), 'wb') do |file|
			file.write(@uploaded_file.read)
		end

		#Stores uploaded CSV as an array of hashes
		@attachments = SmarterCSV.process(Rails.root.join("public", "uploads", @filename).to_s)

		#Attach all items in zipfile to assigned contacts based on the uploaded CSV
		@attachments.each do |row|
			Infusionsoft.file_upload(row[:id],"#{row[:filename]}",Base64.encode64(File.open("#{filepath}/#{params[:files]}/#{row[:filepath]}", "rb").read))
		end

	end

	def appsettings
		@appsettings = Infusionsoft.data_get_app_setting('Templates','defuserid')
		puts @appsettings
	end

	def basecamp
=begin
		response = basecamp_api_call('https://basecamp.com/1934040/api/v1/projects.json')
		projects = JSON.parse(response.body)
		File.open('C:\Users\josh.fullmer\Documents\Data Migration\Basecamp\projects.csv','wb') do |file|
			file.write('Id,Name,SubName' + "\n")
			projects.each do |project|
				file.write("\"{project['id']}\",\"{project['name']}\",\"{project['description']}\"\n")
			end
		end
=end
		contact_projects = [9238691, 5883828, 9377624, 7751701, 1916491, 10822341, 1623504]
		contact_projects = [1623504]
		File.open('C:\Users\josh.fullmer\Documents\Data Migration\Basecamp\contacts.csv','wb') do |file|
			file.write("projectid\tlistid\tlistname\tlistdescription\tcommentid\tcommentcontent\tcommentcreatedat\tcommentupdatedat\tcommentcreator\n")
			contact_projects.each do |projectid|
				response = basecamp_api_call("https://basecamp.com/1934040/api/v1/projects/{projectid}/todolists.json")
				todolists = JSON.parse(response.body)
				todolists.each do |list|
					response = basecamp_api_call(list['url'])
					todolist = JSON.parse(response.body)
					todolist['comments'].each do |comment|
						commentcontent = comment['content'].nil? ? nil : comment['content'].gsub!(/"/,"'")
						file.write("\"#{projectid}\"\t\"#{list['id']}\"\t\"#{list['name']}\"\t\"#{list['description']}\"\t\"#{comment['id']}\"\t\"#{commentcontent}\"\t\"#{comment['created_at']}\"\t\"#{comment['updated_at']}\"\t\"#{comment['creator']['name']}\"\n")
					end
				end
			end
		end

	end

	def closeio
		json_converter = JsonConverter.new
		filenum = 1
		skip = 0
		limit = 100
		#File.open("C:\\Users\\josh.fullmer\\Documents\\Data Migration\\Heather Pettit\\api\\leads.csv",'wb+') do |file|
			#data = {'data' => []}
			#while true do
				#response = JSON.parse(closeio_api_call("https://app.close.io/api/v1/lead/?_skip=#{skip}&_limit=#{limit}"))
				#data['data'] += response['data']
				#break unless response['has_more']
				#skip += limit
			#end
			#file.write(json_converter.generate_csv(data['data'].to_json))
		#end
		data = []
		while true do
			response = closeio_api_call("https://app.close.io/api/v1/activity/call/?_skip=#{skip}&_limit=#{limit}")
			rubyhash = JSON.parse(response)
			rubyhash['data'].each do |hash|
				hash.delete('body_html') unless hash['body_html'].nil?
				hash.delete('body_html_quoted') unless hash['body_html_quoted'].nil?
				data << hash
			end
			break unless rubyhash['has_more']
			skip += limit
			filenum += 1
		end
		File.open("C:\\Users\\josh.fullmer\\Documents\\Data Migration\\Heather Pettit\\api\\calls.json",'wb+') do |file|
			file.write(data.to_json)
		end
	end

	def closeio_json2csv
		json_converter = JsonConverter.new

		File.open('C:\Users\josh.fullmer\Documents\Data Migration\Heather Pettit\api\leads.csv','w') do |outfile|
			File.open('C:\Users\josh.fullmer\Documents\Data Migration\Heather Pettit\api\leads.json','r') do |infile|
				json = JSON.parse(infile.read)
				outfile.write(json_converter.generate_csv(json))
			end
		end
	end

end