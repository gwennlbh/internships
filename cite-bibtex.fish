function cite-bibtex
	set id $argv[1]

	if test (count $argv) = 1
		set contents ""(wl-paste)""
	else
		set contents ""(echo $argv[2..-1])""
	end

	echo Adding $id

	echo "$contents" \
		| hayagriva --format bibtex /dev/stdin \
		| yq -Y "with_entries(.key = \"$id\")" \
		>> bib.yaml


	echo >> bib.yaml
end
