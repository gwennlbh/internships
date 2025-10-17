#!/usr/bin/env fish
git reset --hard rapport/main.pdf
git pull --rebase --autostash
while true
	pdfinfo rapport/main.pdf | rg ^Pages: | awk '{print $2}' > pages_count
	git add rapport/*.typ bib.yaml *.fish rapport/*.dot pages_count
	git commit --quiet -m "Continue rapport"
	git push --quiet --force
	echo Pushed at (date)
	sleep (math "60 * 30")
end
