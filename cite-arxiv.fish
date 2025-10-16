function cite-arxiv
	set id "$argv[1]"
	set doi (
		echo "$argv[2]" \
			| string replace "https://arxiv.org/pdf/" "" \
			| string replace "https://arxiv.org/abs/" "" \
			| string replace "https://arxiv.org/html/" ""
	)

	set bibtex (uvx arxiv2bib "$doi")

	cite-bibtex "$id" "$bibtex"
end
	
