def initialize_infusionsoft(appname, apikey)

	Infusionsoft.configure do |config|
		config.api_url = "#{appname}.infusionsoft.com"
		config.api_key = apikey
	end

end

def get_table(tablename)

	table = []
	page_index = 0
	while true do
		table_page = Infusionsoft.data_query(@tablename,1000,page_index,{},FIELDS["#{@tablename}"])
		table += table_page
		break if table_page.length < 1000
		page_index += 1
	end
	table

end