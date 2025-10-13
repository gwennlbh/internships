#!/usr/bin/env fish
while true
	git add rapport/*.typ rapport/main.pdf bib.yaml *.fish
	git commit --quiet -m "Continue rapport"
	git push --quiet --force
	echo Pushed at (date)
	sleep (math "60 * 30")
end
