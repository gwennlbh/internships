function cite-bibtex
	set id $argv[1]

	if test (count $argv) = 1
		set contents ""(wl-paste)""
	else
		set contents ""(echo $argv[2..-1])""
	end

	echo Adding $id

	set now (date --iso-8601)

	echo "$contents" \
		| hayagriva --format bibtex /dev/stdin \
		| yq -y "with_entries(.key = \"$id\")" \
		| yq -y ".[\"$id\"].url = { value: .[\"$id\"].url, date: \"$now\" }" \
		>> bib.yaml


	echo >> bib.yaml
end
