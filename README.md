# gabrielweyer.github.io

Source for my [blog][blog].

| CI | Status |
| --- | --- |
| [GitHub Actions][github-actions] | [![Build Status][github-actions-shield]][github-actions] |

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

1. Update `Gemfile`, `README.md`, and `.github/workflows/build.yml` with the new version
1. Set `$Env:JEKYLL_VERSION` with the new version
1. `docker run --rm --volume="$($PWD):/srv/jekyll" -it jekyll/builder:$Env:JEKYLL_VERSION bundle update`
1. Start Jekyll and confirm everything is working as expected
1. Commit, push

[blog]: https://gabrielweyer.net/
[github-actions]: https://github.com/gabrielweyer/gabrielweyer.github.io/actions/workflows/build.yml
[github-actions-shield]: https://github.com/gabrielweyer/gabrielweyer.github.io/actions/workflows/build.yml/badge.svg
[working-with-drafts]: https://jekyllrb.com/docs/drafts/
