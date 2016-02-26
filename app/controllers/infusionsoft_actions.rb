def initialize_infusionsoft(appname, apikey)

	Infusionsoft.configure do |config|
		config.api_url = "#{appname}.infusionsoft.com"
		config.api_key = apikey
		config.api_logger = Logger.new("#{Rails.root}/log/infusionsoft_api.log")
	end

end

def get_table(tablename)

	table = []
	page_index = 0
	while true do
		table_page = Infusionsoft.data_query(tablename,1000,page_index,{},FIELDS["#{tablename}"])
		table += table_page
		break if table_page.length < 1000
		page_index += 1
	end
	table

end

def create_custom_field(fieldname,headerid=0,tablename='Contact',fieldtype='Text')

	#Check to see if custom field exists
	field_exists = Infusionsoft.data_query('DataFormField',1000,0,{ Label: "#{fieldname}" },['Id'])

	#gets first headerid if headerid isn't passed, else sets custom_field_header_id to passed value
	headerid == 0 ? custom_field_header_id = get_table('DataFormGroup')[0]['Id'] : custom_field_header_id = headerid

	#creates custom field if it doesn't exist
	Infusionsoft.data_add_custom_field(tablename,fieldname,fieldtype,custom_field_header_id) if field_exists == []

	#Returns Database Name of Custom Field
	"_" + Infusionsoft.data_query('DataFormField',1000,0,{ Label: "#{fieldname}" },['Name'])[0]['Name']

end