# gabrielweyer.github.io

Source for my [blog][blog].

| CI | Status |
| --- | --- |
| [CircleCI][circle-ci] | [![Build Status][circle-ci-shield]][circle-ci] |

## Development

```posh
docker run --rm --volume="$($PWD):/srv/jekyll" -p 4000:4000 -it jekyll/jekyll:3.8.5 jekyll serve --force_polling --incremental --drafts
```

- `--force_polling --incremental` will regenerate the page you're working on.
  - **Note**: this will only regenerate the pages you save (i.e the index will not be regenerated if you modify a post for example)
- You can serve your [drafts][working-with-drafts] by adding the `--drafts` switch.

## Release

- Always work in the `develop` branch
- Once you're done: `git push origin develop`

[blog]: https://gabrielweyer.net/
[circle-ci]: https://circleci.com/gh/gabrielweyer/gabrielweyer.github.io
[circle-ci-shield]: https://circleci.com/gh/gabrielweyer/gabrielweyer.github.io/tree/develop.svg?style=shield
[working-with-drafts]: https://jekyllrb.com/docs/drafts/
