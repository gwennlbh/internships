function cite-web
	set id $argv[1]
	set url $argv[2]

	# horrible mdr
	set full_url (https -F --print h --debug $url 2>&1 | rg "^\\s*'url': '(.*$url.*)'}\\)" | sd "^\\s*'url': '(.+)'}\\)" '$1')

	set title (https -F $url | htmlq --text 'head title')

	echo "Adding $title"

	set citation '{ $id: { 
	  type: "web", 
	  title: $title,
	  url: { date: $today, value: $url }, 
	} }' 


	echo '{}' | yq -Y "$citation" \
		--arg today (date --iso-8601) \
		--arg id $id \
		--arg title "$title" \
		--arg url "$full_url" \
	>> bib.yaml

	# Add a blank line
	echo >> bib.yaml 
	echo >> bib.yaml
end
