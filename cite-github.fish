function cite-github
	set id $argv[1]
	set owner $argv[2]
	set repo $argv[3]

	set query '
	  query ($owner: String!, $repo: String!) {
	    repository(owner: $owner, name: $repo) {
	      name
	      owner { login, ...on Organization { name } }
	      createdAt
	      url
	    }
	  }'

	set citation '{ $id: { 
	  type: "web", 
	  title: .name,
	  publisher: "GitHub", 
	  author: .owner.name, 
	  url: { date: $today, value: .url }, 
	  date: .createdAt | sub("T.+$"; "")
	} }' 


	set data (
		gh api graphql -F owner=$owner -F repo=$repo -f query="$query" | jq .data.repository
	)

	echo "Adding $data"

	echo "$data" | yq -Y "$citation" \
		--arg today (date --iso-8601) \
		--arg id $id \
	>> bib.yaml

	# Add a blank line
	echo >> bib.yaml 
end
