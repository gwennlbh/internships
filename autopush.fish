#!/usr/bin/env fish
git checkout -- rapport/main.pdf
git pull --rebase --autostash
while true
	pdfinfo rapport/main.pdf | rg ^Pages: | awk '{print $2}' > pages_count
	git add rapport/*.typ bib.yaml *.fish rapport/*.dot pages_count rapport/*.png
	set typst_changed (git diff --exit-code rapport/*.{typ,dot,png} bib.yaml)
	git commit --quiet -m "Continue rapport"
	if $typst_changed
		git push --quiet --force
		echo Pushed at (date)
	end
	sleep (math "60 * 30")
end
