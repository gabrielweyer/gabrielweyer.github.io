# gabrielweyer.github.io

Source for my [blog][blog].

| CI | Status |
| --- | --- |
| [CircleCI][circle-ci] | [![Build Status][circle-ci-shield]][circle-ci] |

## Development

```powershell
$Env:JEKYLL_VERSION = '4.2.2'
docker run --rm --volume="$($PWD):/srv/jekyll" -p 4000:4000 -it jekyll/builder:$Env:JEKYLL_VERSION jekyll serve --force_polling --incremental --drafts
```

- `--force_polling --incremental` will regenerate the page you're working on.
  - **Note**: this will only regenerate the pages you save (i.e the index will not be regenerated if you modify a post for example)
- You can serve your [drafts][working-with-drafts] by adding the `--drafts` switch.

## Release

- Always work in the `develop` branch
- Once you're done: `git push origin develop`

## Updating

1. Update `Gemfile`, `README.md`, and `.circleci\config.yml` with the new version
1. Set `$Env:JEKYLL_VERSION` with the new version
1. `docker run --rm --volume="$($PWD):/srv/jekyll" -it jekyll/builder:$Env:JEKYLL_VERSION bundle update`
1. Start Jekyll and confirm everything is working as expected
1. Commit, push

[blog]: https://gabrielweyer.net/
[circle-ci]: https://circleci.com/gh/gabrielweyer/gabrielweyer.github.io
[circle-ci-shield]: https://circleci.com/gh/gabrielweyer/gabrielweyer.github.io/tree/develop.svg?style=shield
[working-with-drafts]: https://jekyllrb.com/docs/drafts/
