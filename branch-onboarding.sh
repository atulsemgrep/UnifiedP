# Loop through branches and trigger CI scans
for branch in $(git branch -r | grep -v HEAD); do
    git checkout $branch
    semgrep ci
done
