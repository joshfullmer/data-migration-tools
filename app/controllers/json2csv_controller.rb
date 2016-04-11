class Json2csvController < ApplicationController

	def start
	end

	def convert
		json = JSON.parse(params[:json].read)
		in_array = array_from(json)
		in_array.map! { |x| nils_to_strings x }

		out_array = []
		in_array.each do |row|
			out_array[out_array.length] = flatten(row)
		end

		csv_headers = []
		out_array.each do |row|
			csv_headers = csv_headers | row.keys
		end

		csv_headers.sort_by!(&:downcase)

		final_array = []
		out_array.each do |row|
			hash = {}
			csv_headers.each do |header|
				header.nil? ? hash[header] = '' : hash[header] = row[header]
			end
			final_array << hash
		end

		CSV.open("#{Rails.root}/public/out.csv", 'w', headers:true) do |csv|
			csv << CSV::Row.new(csv_headers,csv_headers,header_row = true)
			final_array.each do |hash|
				row = CSV::Row.new([],[])
				row << hash
				csv << row
			end
		end
	end

	def array_from(json)
		queue, next_item = [], json
		while !next_item.nil?

			return next_item if next_item.is_a? Array

			if next_item.is_a? Hash
				next_item.each do |k, v|
					queue.push next_item[k]
				end
			end

			next_item = queue.shift
		end

		return [json]
	end

	def nils_to_strings(hash)
		hash.each_with_object({}) do |(k,v), object|
			case v
			when Hash
				object[k] = nils_to_strings v
			when nil
				object[k] = ''
			else
				object[k] = v
			end
		end
	end

	def flatten(object, path='')
		scalars = [String, Integer, Fixnum, FalseClass, TrueClass]
		columns = {}

		if object.is_a? Hash
			object.each do |k, v|
				new_columns = flatten(v, "#{path}#{k}/") if object.is_a? Hash
				columns = columns.merge new_columns
			end

			return columns
		elsif object.is_a? Array
			object.each_with_index do |v, i|
				new_columns = flatten(v, "#{path}#{i}/") if object.is_a? Array
				columns = columns.merge new_columns
			end

			return columns
		elsif scalars.include? object.class
			# Remove trailing slash from path
			end_path = path[0, path.length - 1]
			columns[end_path] = object
			return columns
		else
			return {}
		end
	end

end
