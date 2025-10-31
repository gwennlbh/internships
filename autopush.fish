#!/usr/bin/env fish
git checkout -- rapport/main.pdf
git pull --rebase --autostash
while true
	pdfinfo rapport/main.pdf | rg ^Pages: | awk '{print $2}' > pages_count
	set pdf_changes (git diff --exit-code rapport/*.{typ,dot,png} bib.yaml; echo $status)
	git add rapport/*.typ bib.yaml *.fish rapport/*.dot pages_count rapport/*.png
	git commit --quiet -m "Continue rapport"
	if test $pdf_changes -ne 0
		git push --quiet --force
		echo Pushed at (date)
	end
	sleep (math "60 * 30")
end
