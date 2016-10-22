Create an issue for weekly review

# Usage

```
Usage: github-weekly-review.rb [options]
    -v, --[no-]verbose               Run verbosely
    -a, --ansible [ TYPE ]           type of repositories to fetch issues. either `role` or `project` default is role
    -o, --organization ORGANIZATION  organization name. no default
    -s ORGANIZATION/REPOSITORY,      the repository to submit the weekly report to. no default
        --submit_to
    -d, --dryrun                     Do not submit the report. Just print the list to STDOUT. default is false
```
